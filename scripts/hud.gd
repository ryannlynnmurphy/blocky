extends CanvasLayer
## On-screen overlay: crosshair, hotbar, and control hints.

var _hotbar_label: Label


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
	hint.text = "WASD move   Space jump   Shift run   LMB break   RMB place   1-7 pick block   Esc free mouse"
	hint.position = Vector2(12, 8)
	add_child(hint)

	_hotbar_label = _make_label()
	_hotbar_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hotbar_label.offset_top = -44
	_hotbar_label.offset_bottom = -12
	_hotbar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hotbar_label)
	_refresh_hotbar(0)


func bind_player(player: Player) -> void:
	player.hotbar_changed.connect(_refresh_hotbar)
	_refresh_hotbar(player.selected)


func _refresh_hotbar(selected: int) -> void:
	var parts: PackedStringArray = []
	for i in Blocks.HOTBAR.size():
		var name: String = Blocks.NAMES[Blocks.HOTBAR[i]]
		if i == selected:
			parts.append("[ %d %s ]" % [i + 1, name])
		else:
			parts.append("%d %s" % [i + 1, name])
	_hotbar_label.text = "     ".join(parts)


func _make_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l
