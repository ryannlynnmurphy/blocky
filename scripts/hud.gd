extends CanvasLayer
## On-screen overlay: crosshair, hotbar, and control hints.

var _hotbar_label: Label
var _clock_label: Label
var _death_label: Label
var _health_bar: HealthBar
var _damage_flash: ColorRect
var _day_night: DayNight
var _world: VoxelWorld
var _player: Player
var _death_timer := 0.0


## A Control that just draws a crosshair in its centre.
class Crosshair extends Control:
	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var c := size / 2.0
		draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), Color.WHITE, 2.0)
		draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color.WHITE, 2.0)


## A row of chunky squares: red = health you have, dark = health you lost.
class HealthBar extends Control:
	const CELL := 18.0
	const GAP := 4.0
	var health := 10
	var max_health := 10

	func _ready() -> void:
		resized.connect(queue_redraw)

	func set_health(h: int, m: int) -> void:
		health = h
		max_health = m
		queue_redraw()

	func _draw() -> void:
		var total := max_health * CELL + (max_health - 1) * GAP
		var x0 := (size.x - total) / 2.0
		for i in max_health:
			var r := Rect2(x0 + i * (CELL + GAP), 0, CELL, CELL)
			var col := Color(0.9, 0.2, 0.25) if i < health else Color(0.1, 0.1, 0.12, 0.6)
			draw_rect(r, col)
			draw_rect(r, Color(0, 0, 0, 0.5), false, 2.0)


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

	_health_bar = HealthBar.new()
	_health_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_health_bar.offset_top = -74
	_health_bar.offset_bottom = -56
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_health_bar)

	_death_label = _make_label()
	_death_label.text = "You died"
	_death_label.add_theme_font_size_override("font_size", 48)
	_death_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_death_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_death_label.visible = false
	add_child(_death_label)

	var hint := _make_label()
	hint.text = "WASD move   Space jump   Shift run   LMB punch / break   RMB place   1-8 pick block   E eat   T fast-forward   Esc free mouse"
	hint.position = Vector2(12, 8)
	add_child(hint)

	_clock_label = _make_label()
	_clock_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_clock_label.offset_left = -400
	_clock_label.offset_right = -12
	_clock_label.offset_top = 8
	_clock_label.offset_bottom = 34
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_clock_label)

	_hotbar_label = _make_label()
	_hotbar_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hotbar_label.offset_top = -44
	_hotbar_label.offset_bottom = -12
	_hotbar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hotbar_label)
	_refresh_hotbar(0)


func bind_player(player: Player) -> void:
	_player = player
	player.hotbar_changed.connect(_refresh_hotbar)
	player.inventory.changed.connect(func(): _refresh_hotbar(player.selected))
	player.health_changed.connect(_health_bar.set_health)
	player.damaged.connect(func(_amount: int): _damage_flash.color.a = 0.35)
	player.died.connect(func():
		_death_label.visible = true
		_death_timer = 2.0)
	_health_bar.set_health(player.health, Player.MAX_HEALTH)
	_refresh_hotbar(player.selected)


func bind_day_night(day_night: DayNight) -> void:
	_day_night = day_night


func bind_world(world: VoxelWorld, player: Player) -> void:
	_world = world
	_player = player


func _process(delta: float) -> void:
	# Fade the hurt flash and the death message.
	_damage_flash.color.a = move_toward(_damage_flash.color.a, 0.0, 1.2 * delta)
	if _death_timer > 0.0:
		_death_timer -= delta
		if _death_timer <= 0.0:
			_death_label.visible = false

	var parts: PackedStringArray = []
	if _world != null and _player != null:
		var p := _player.global_position
		parts.append(_world.biome_name_at(int(floor(p.x)), int(floor(p.z))))
	if _day_night != null:
		parts.append(_day_night.clock_text())
	_clock_label.text = "   ".join(parts)


func _refresh_hotbar(selected: int) -> void:
	var parts: PackedStringArray = []
	for i in Blocks.HOTBAR.size():
		var id: int = Blocks.HOTBAR[i]
		var entry := "%d %s" % [i + 1, Blocks.NAMES[id]]
		if _player != null:
			entry += " ×%d" % _player.inventory.count(id)
		if i == selected:
			entry = "[ %s ]" % entry
		parts.append(entry)
	var text := "    ".join(parts)
	# Items you carry but can't place go after a divider.
	if _player != null:
		for id in Blocks.ITEMS:
			var n := _player.inventory.count(id)
			if n > 0:
				text += "    |    %s ×%d" % [Blocks.NAMES[id], n]
	_hotbar_label.text = text


func _make_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l
