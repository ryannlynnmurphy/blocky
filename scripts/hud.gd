extends CanvasLayer
## On-screen overlay: crosshair, hotbar, health/hunger/XP bars, messages.
## Drawn with _draw() calls, texturing itself from the vendored UI art
## (res://blocky/textures/ui/) where that exists; everything else (labels,
## the crosshair, the break bar) is still plain shapes/text.

var _clock_label: Label
var _message_label: Label
var _pickup_label: Label
var _pickup_timer := 0.0
var _crosshair: Crosshair
var _inventory_ui: InventoryUI
var _health_bar: IconBar
var _hunger_bar: IconBar
var _hotbar: HotbarView
var _damage_flash: ColorRect
var _underwater_tint: ColorRect
var _underwater_target := 0.0   # WATER-07: eases toward this each frame, doesn't snap
var _stroke_timer := 0.0        # WATER-07: seconds since the last stroke sound
const STROKE_INTERVAL := 1.1    # "a restrained stroke cadence", not a footstep-fast tempo
var _day_night: DayNight
var _world: VoxelWorld
var _player: Player
var _message_timer := 0.0


## A crosshair in the centre, with a small progress bar under it while
## you're breaking a block.
class Crosshair extends Control:
	const CROSSHAIR_TEX := preload("res://blocky/textures/ui/crosshair.png")
	const BAR_TEX := preload("res://blocky/textures/ui/break_bar.png")
	## break_bar.png is one 64x8 snapshot with both looks baked in at fixed
	## pixel columns: 2..39 solid fill color, 40..63 the empty track (with
	## its own border) — not a 0..1 template you can width-clip directly,
	## so each piece is sourced separately and recomposed at any progress.
	const BAR_TRACK_SRC := Rect2(40, 0, 24, 8)
	const BAR_FILL_SRC := Rect2(2, 0, 38, 8)
	var progress := 0.0

	func _ready() -> void:
		resized.connect(queue_redraw)

	func set_progress(p: float) -> void:
		progress = p
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		draw_texture_rect(CROSSHAIR_TEX, Rect2(c - Vector2(15, 15), Vector2(30, 30)), false)
		if progress > 0.0:
			var bar := Rect2(c + Vector2(-30, 16), Vector2(60, 8))
			draw_texture_rect_region(BAR_TEX, bar, BAR_TRACK_SRC)
			var fill := Rect2(bar.position, Vector2(60 * progress, 8))
			draw_texture_rect_region(BAR_TEX, fill, BAR_FILL_SRC)


## A row of heart/drumstick-style icons, full/half/empty per icon, 2 points
## of `value` each (matches the vendored art, which has a half state).
## Grows leftward from centre (side = -1) or rightward (side = +1).
class IconBar extends Control:
	const CELL := 20.0
	const GAP := 3.0
	var value := 10
	var max_value := 10
	var full_tex: Texture2D
	var half_tex: Texture2D
	var empty_tex: Texture2D
	var side := -1

	func _ready() -> void:
		resized.connect(queue_redraw)

	func set_value(v: int, m: int) -> void:
		value = v
		max_value = m
		queue_redraw()

	func _draw() -> void:
		var n := int(ceil(max_value / 2.0))
		var total := n * CELL + (n - 1) * GAP
		var x0 := size.x / 2.0 - 10.0 - total if side < 0 else size.x / 2.0 + 10.0
		for i in n:
			var remaining := value - i * 2
			var tex := full_tex if remaining >= 2 else (half_tex if remaining == 1 else empty_tex)
			draw_texture_rect(tex, Rect2(x0 + i * (CELL + GAP), 0, CELL, CELL), false)


## The hotbar: the first 9 inventory slots, whatever is in them, with the
## selected slot outlined. Blocks, tools and food all live here.
class HotbarView extends Control:
	const SLOT := 44.0
	const GAP := 6.0
	const SLOT_TEX := preload("res://blocky/textures/ui/hotbar_slot.png")
	const SELECTED_TEX := preload("res://blocky/textures/ui/slot_selected.png")
	var ids: Array[int] = []
	var counts: Array[int] = []
	var durability: Array[float] = []   # 0..1 remaining; 1.0 = full or doesn't wear out
	var selected := 0

	func _ready() -> void:
		resized.connect(queue_redraw)

	func refresh(player: Player) -> void:
		ids.clear()
		counts.clear()
		durability.clear()
		for i in Inventory.HOTBAR:
			var id := player.inventory.id_at(i)
			ids.append(id)
			counts.append(player.inventory.count_at(i))
			var max_d := Blocks.max_durability(id)
			durability.append(float(player.tool_durability_left(id)) / max_d if max_d > 0 else 1.0)
		selected = player.selected
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var n := Inventory.HOTBAR
		var total := n * SLOT + (n - 1) * GAP
		var x0 := (size.x - total) / 2.0
		for i in n:
			var r := Rect2(x0 + i * (SLOT + GAP), 0, SLOT, SLOT)
			draw_texture_rect(SLOT_TEX, r, false)
			var id: int = ids[i] if i < ids.size() else Blocks.AIR
			if id != Blocks.AIR:
				draw_texture_rect(Blocks.icon(id), r.grow(-8), false)
			var d: float = durability[i] if i < durability.size() else 1.0
			if id != Blocks.AIR and d < 1.0:
				var bar_w := SLOT - 12.0
				var bar_pos := r.position + Vector2(6, SLOT - 10)
				draw_rect(Rect2(bar_pos, Vector2(bar_w, 3)), Color(0, 0, 0, 0.6))
				var fill_col := Color(0.85, 0.2, 0.2).lerp(Color(0.3, 0.85, 0.3), d)
				draw_rect(Rect2(bar_pos, Vector2(bar_w * d, 3)), fill_col)
			# hotbar_slot.png already bakes in its own border via edge
			# shading; slot_selected.png is a separate hollow-centre frame
			# (transparent middle, opaque gold ring) drawn a bit larger so
			# the highlight reads as an outward "pop" around the icon.
			if i == selected:
				draw_texture_rect(SELECTED_TEX, r.grow(4), false)
			draw_string(font, r.position + Vector2(4, 12), str(i + 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.85, 0.85))
			var count: int = counts[i] if i < counts.size() else 0
			if count > 1:
				draw_string(font, r.position + Vector2(0, SLOT - 5), str(count),
					HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 4, 14, Color.WHITE)


func _ready() -> void:
	# Red screen flash when hurt (drawn first so everything else sits on top).
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(0.8, 0.0, 0.0, 0.0)
	_damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_damage_flash)

	# WATER-07: a translucent blue wash while actually swimming (not while
	# merely wading — the spec's "Presentation" section ties this to
	# head-submerged, and Wade never submerges the head). Same screen-tint
	# technique as _damage_flash, deliberately not touching WorldEnvironment
	# fog, which day_night.gd already drives every frame — a second system
	# fighting over the same resource for a cosmetic tint isn't worth it.
	_underwater_tint = ColorRect.new()
	_underwater_tint.color = Color(0.1, 0.35, 0.55, 0.0)
	_underwater_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_underwater_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_underwater_tint)

	_crosshair = Crosshair.new()
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)

	# "+1 Dirt" popup just above the health row.
	_pickup_label = _make_label()
	_pickup_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_pickup_label.offset_top = -112
	_pickup_label.offset_bottom = -88
	_pickup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pickup_label.visible = false
	add_child(_pickup_label)

	# Bottom stack, from the bottom up: hotbar, then health + hunger row.
	_hotbar = HotbarView.new()
	_add_bottom_wide(_hotbar, -58, -14)

	_health_bar = IconBar.new()
	_health_bar.side = -1
	_health_bar.full_tex = preload("res://blocky/textures/ui/heart_full.png")
	_health_bar.half_tex = preload("res://blocky/textures/ui/heart_half.png")
	_health_bar.empty_tex = preload("res://blocky/textures/ui/heart_empty.png")
	_add_bottom_wide(_health_bar, -86, -66)

	_hunger_bar = IconBar.new()
	_hunger_bar.side = 1
	_hunger_bar.full_tex = preload("res://blocky/textures/ui/drumstick_full.png")
	_hunger_bar.half_tex = preload("res://blocky/textures/ui/drumstick_half.png")
	_hunger_bar.empty_tex = preload("res://blocky/textures/ui/drumstick_empty.png")
	_add_bottom_wide(_hunger_bar, -86, -66)

	_message_label = _make_label()
	_message_label.add_theme_font_size_override("font_size", 48)
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_message_label.visible = false
	add_child(_message_label)

	_inventory_ui = InventoryUI.new()
	add_child(_inventory_ui)

	var hint := _make_label()
	hint.text = "WASD move   Space jump   Shift run   LMB punch / hold to break   RMB place held block   1-9 / wheel pick slot   E eat   V camera view   Tab inventory   Esc pause   F5 save   T fast-forward"
	hint.add_theme_font_size_override("font_size", 14)
	# Wraps instead of running under the clock label (top-right, starts
	# 400px from the right edge) at normal window widths.
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.offset_left = 12
	hint.offset_top = 10
	hint.offset_right = -420
	add_child(hint)

	_clock_label = _make_label()
	_clock_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_clock_label.offset_left = -400
	_clock_label.offset_right = -12
	_clock_label.offset_top = 8
	_clock_label.offset_bottom = 34
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_clock_label)


func _add_bottom_wide(c: Control, top: float, bottom: float) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	c.offset_top = top
	c.offset_bottom = bottom
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)


func bind_player(player: Player) -> void:
	_player = player
	player.hotbar_changed.connect(func(_i: int): _hotbar.refresh(player))
	player.inventory.changed.connect(func(): _hotbar.refresh(player))
	player.durability_changed.connect(func(): _hotbar.refresh(player))
	player.inventory.added.connect(_show_pickup)
	player.break_progress_changed.connect(_crosshair.set_progress)
	player.health_changed.connect(_health_bar.set_value)
	player.hunger_changed.connect(_hunger_bar.set_value)
	player.damaged.connect(func(_amount: int): _damage_flash.color.a = 0.35)
	player.water_state_changed.connect(_on_water_state_changed)
	_health_bar.set_value(player.health, player.max_health)
	_hunger_bar.set_value(player.hunger, Player.MAX_HUNGER)
	_hotbar.refresh(player)
	_inventory_ui.bind_player(player)


func is_inventory_open() -> bool:
	return _inventory_ui.visible


func set_inventory_open(open: bool, mode: String = "pocket") -> void:
	if open:
		_inventory_ui.open(mode)
	else:
		_inventory_ui.close()


func inventory_ui() -> InventoryUI:
	return _inventory_ui


## WATER-07: presentation only, consumes Player.water_state_changed rather
## than re-deriving any water query itself. Wade never counts as
## "submerged" (see _underwater_tint's comment); Swim/Sprint-swim both do,
## since this game has no separate head-tracking, and swimming at all
## implies the torso -- and, in practice, the head -- is under the surface.
func _on_water_state_changed(state: int) -> void:
	var submerged := state == Player.WaterState.SWIM or state == Player.WaterState.SPRINT_SWIM
	var was_submerged := _underwater_target > 0.0
	_underwater_target = 0.45 if submerged else 0.0
	Sfx.set_underwater(submerged)
	if submerged and not was_submerged:
		Sfx.play("splash_in", _player.global_position)
	elif was_submerged and not submerged:
		Sfx.play("splash_out", _player.global_position)


func _show_pickup(id: int, amount: int) -> void:
	_pickup_label.text = "+%d %s" % [amount, Blocks.NAMES[id]]
	_pickup_label.modulate.a = 1.0
	_pickup_label.visible = true
	_pickup_timer = 1.5


## Big centred text for a couple of seconds.
func show_message(text: String) -> void:
	_message_label.text = text
	_message_label.visible = true
	_message_timer = 2.0


func bind_day_night(day_night: DayNight) -> void:
	_day_night = day_night


func bind_world(world: VoxelWorld, player: Player) -> void:
	_world = world
	_player = player


func _process(delta: float) -> void:
	# Fade the hurt flash and the message.
	_damage_flash.color.a = move_toward(_damage_flash.color.a, 0.0, 1.2 * delta)
	_underwater_tint.color.a = move_toward(_underwater_tint.color.a, _underwater_target, 1.5 * delta)

	# WATER-07: a stroke sound on a slow, steady cadence while actually
	# swimming and actually moving -- mirrors _footstep()'s "only while
	# moving" rule in player.gd, just driven from here instead, since this
	# is presentation, not movement logic. Resets whenever not swimming so
	# surfacing and diving back in doesn't fire one immediately.
	if _player != null and (_player.water_state == Player.WaterState.SWIM
			or _player.water_state == Player.WaterState.SPRINT_SWIM) \
			and Vector2(_player.velocity.x, _player.velocity.z).length() > 0.5:
		_stroke_timer += delta
		if _stroke_timer >= STROKE_INTERVAL:
			_stroke_timer = 0.0
			Sfx.play("stroke", _player.global_position, 0.15, -4.0)
	else:
		_stroke_timer = 0.0

	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_label.visible = false
	if _pickup_timer > 0.0:
		_pickup_timer -= delta
		_pickup_label.modulate.a = clampf(_pickup_timer / 0.5, 0.0, 1.0)   # fade in the last half second
		if _pickup_timer <= 0.0:
			_pickup_label.visible = false

	var parts: PackedStringArray = []
	if _player != null and not _player.person_name().is_empty():
		parts.append(_player.person_name())
	if _world != null and _player != null:
		var p := _player.global_position
		parts.append(_world.biome_name_at(int(floor(p.x)), int(floor(p.z))))
	if _day_night != null:
		parts.append(_day_night.clock_text())
	_clock_label.text = "   ".join(parts)


func _make_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l
