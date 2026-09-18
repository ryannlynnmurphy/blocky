extends CanvasLayer
## On-screen overlay: crosshair, hotbar, and control hints.

var _hotbar_label: Label
var _clock_label: Label
var _day_night: DayNight
var _world: VoxelWorld
var _player: Player


## A Control that just draws a crosshair in its centre.
class Crosshair extends Control:
	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var c := size / 2.0
		draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), Color.WHITE, 2.0)
		draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color.WHITE, 2.0)


func _ready() -> void:
	var cross := Crosshair.new()
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cross)

	var hint := _make_label()
	hint.text = "WASD move   Space jump   Shift run   LMB break   RMB place   1-8 pick block   T fast-forward time   Esc free mouse"
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
	_refresh_hotbar(player.selected)


func bind_day_night(day_night: DayNight) -> void:
	_day_night = day_night


func bind_world(world: VoxelWorld, player: Player) -> void:
	_world = world
	_player = player


func _process(_delta: float) -> void:
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
	_hotbar_label.text = "    ".join(parts)


func _make_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l
