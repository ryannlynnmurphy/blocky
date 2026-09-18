extends CanvasLayer
## On-screen overlay: crosshair, hotbar, health/hunger/XP bars, messages.
## Everything is drawn with _draw() calls — no image files — to keep the
## same chunky look as the world.

var _clock_label: Label
var _message_label: Label
var _health_bar: SquareBar
var _hunger_bar: SquareBar
var _hotbar: HotbarView
var _damage_flash: ColorRect
var _day_night: DayNight
var _world: VoxelWorld
var _player: Player
var _message_timer := 0.0


## A Control that just draws a crosshair in its centre.
class Crosshair extends Control:
	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var c := size / 2.0
		draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), Color.WHITE, 2.0)
		draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color.WHITE, 2.0)


## A row of chunky squares: filled = what you have, dark = what you lost.
## Grows leftward from centre (side = -1) or rightward (side = +1).
class SquareBar extends Control:
	const CELL := 18.0
	const GAP := 4.0
	var value := 10
	var max_value := 10
	var color := Color(0.9, 0.2, 0.25)
	var side := -1

	func _ready() -> void:
		resized.connect(queue_redraw)

	func set_value(v: int, m: int) -> void:
		value = v
		max_value = m
		queue_redraw()

	func _draw() -> void:
		var total := max_value * CELL + (max_value - 1) * GAP
		var x0 := size.x / 2.0 - 10.0 - total if side < 0 else size.x / 2.0 + 10.0
		for i in max_value:
			# Right-growing bars fill from the left; left-growing from the right.
			var slot := i if side > 0 else max_value - 1 - i
			var r := Rect2(x0 + slot * (CELL + GAP), 0, CELL, CELL)
			var col := color if i < value else Color(0.1, 0.1, 0.12, 0.6)
			draw_rect(r, col)
			draw_rect(r, Color(0, 0, 0, 0.5), false, 2.0)


## The hotbar: one square per placeable block in its own colour, with the
## count in the corner; the selected slot is outlined. Items you can carry
## but not place (meat) get their own slots to the right.
class HotbarView extends Control:
	const SLOT := 44.0
	const GAP := 6.0
	var counts: Array[int] = []
	var item_counts := {}
	var selected := 0

	func _ready() -> void:
		resized.connect(queue_redraw)

	func refresh(player: Player) -> void:
		counts.clear()
		for id in Blocks.HOTBAR:
			counts.append(player.inventory.count(id))
		item_counts.clear()
		for id in Blocks.ITEMS:
			item_counts[id] = player.inventory.count(id)
		selected = player.selected
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var n := Blocks.HOTBAR.size()
		var total := n * SLOT + (n - 1) * GAP
		var x0 := (size.x - total) / 2.0
		for i in n:
			var id: int = Blocks.HOTBAR[i]
			var count: int = counts[i] if i < counts.size() else 0
			_draw_slot(font, Rect2(x0 + i * (SLOT + GAP), 0, SLOT, SLOT),
				Blocks.face_color(id, 2), count, str(i + 1), i == selected)
		# Items, after a gap.
		var x := x0 + total + 18.0
		for id in Blocks.ITEMS:
			var count: int = item_counts.get(id, 0)
			if count > 0:
				_draw_slot(font, Rect2(x, 0, SLOT, SLOT), Blocks.face_color(id, 1), count,
					"E", false)
				x += SLOT + GAP

	func _draw_slot(font: Font, r: Rect2, color: Color, count: int, label: String,
			is_selected: bool) -> void:
		draw_rect(r, Color(0.08, 0.08, 0.1, 0.75))
		if count == 0:
			color.a = 0.3   # dimmed: you don't have any
		draw_rect(r.grow(-8), color)
		if is_selected:
			draw_rect(r, Color.WHITE, false, 3.0)
		else:
			draw_rect(r, Color(0, 0, 0, 0.6), false, 2.0)
		draw_string(font, r.position + Vector2(4, 12), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.85, 0.85))
		if count > 0:
			draw_string(font, r.position + Vector2(0, SLOT - 5), str(count),
				HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 4, 14, Color.WHITE)


func _ready() -> void:
	# Red screen flash when hurt (drawn first so everything else sits on top).
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(0.8, 0.0, 0.0, 0.0)
	_damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_damage_flash)

	var cross := Crosshair.new()
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cross)

	# Bottom stack, from the bottom up: hotbar, then health + hunger row.
	_hotbar = HotbarView.new()
	_add_bottom_wide(_hotbar, -58, -14)

	_health_bar = SquareBar.new()
	_health_bar.side = -1
	_add_bottom_wide(_health_bar, -84, -66)

	_hunger_bar = SquareBar.new()
	_hunger_bar.side = 1
	_hunger_bar.color = Color(0.95, 0.6, 0.2)
	_add_bottom_wide(_hunger_bar, -84, -66)

	_message_label = _make_label()
	_message_label.add_theme_font_size_override("font_size", 48)
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_message_label.visible = false
	add_child(_message_label)

	var hint := _make_label()
	hint.text = "WASD move   Space jump   Shift run   LMB punch / break   RMB place   1-8 / wheel pick block   E eat   F5 save   T fast-forward   Esc free mouse"
	hint.add_theme_font_size_override("font_size", 14)
	hint.position = Vector2(12, 10)
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
	player.health_changed.connect(_health_bar.set_value)
	player.hunger_changed.connect(_hunger_bar.set_value)
	player.damaged.connect(func(_amount: int): _damage_flash.color.a = 0.35)
	player.died.connect(func(): show_message("You died"))
	_health_bar.set_value(player.health, player.max_health)
	_hunger_bar.set_value(player.hunger, Player.MAX_HUNGER)
	_hotbar.refresh(player)


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
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_label.visible = false

	var parts: PackedStringArray = []
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
