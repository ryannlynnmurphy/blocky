class_name Screens
extends CanvasLayer
## Full-screen menus: title, pause, death. Built from plain Controls in
## code. Each button just emits a signal; main.gd decides what happens.

signal continue_pressed
signal new_game_pressed(seed_text: String)
signal quit_pressed
signal resume_pressed
signal save_pressed
signal to_title_pressed
signal respawn_pressed
signal sfx_volume_changed(value: float)

var _title: Control
var _pause: Control
var _death: Control
var _continue_button: Button
var _seed_edit: LineEdit
var _volume: HSlider


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS   # menus keep working while the game is paused

	# ---- title ----
	var t := _panel_with_logo(Color(0, 0, 0, 0.35))
	_title = t[0]
	var tv: VBoxContainer = t[1]
	var sub := Label.new()
	sub.text = "an original voxel RPG"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.75)
	tv.add_child(sub)
	tv.add_child(_spacer(16))
	_continue_button = _button(tv, "Continue", func(): continue_pressed.emit())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "seed (blank = random)"
	_seed_edit.custom_minimum_size = Vector2(220, 0)
	row.add_child(_seed_edit)
	var ng := Button.new()
	ng.text = "New Game"
	ng.custom_minimum_size = Vector2(150, 44)
	ng.pressed.connect(func(): new_game_pressed.emit(_seed_edit.text))
	row.add_child(ng)
	tv.add_child(row)
	_button(tv, "Quit", func(): quit_pressed.emit())

	# ---- pause ----
	var p := _panel("Paused", 48, Color(0, 0, 0, 0.55))
	_pause = p[0]
	var pv: VBoxContainer = p[1]
	_button(pv, "Resume", func(): resume_pressed.emit())
	_button(pv, "Save", func(): save_pressed.emit())
	var vol_row := HBoxContainer.new()
	vol_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var vol_label := Label.new()
	vol_label.text = "Sound  "
	vol_row.add_child(vol_label)
	_volume = HSlider.new()
	_volume.min_value = 0.0
	_volume.max_value = 1.0
	_volume.step = 0.05
	_volume.value = 1.0
	_volume.custom_minimum_size = Vector2(220, 24)
	_volume.value_changed.connect(func(v: float): sfx_volume_changed.emit(v))
	vol_row.add_child(_volume)
	pv.add_child(vol_row)
	_button(pv, "Quit to Title", func(): to_title_pressed.emit())

	# ---- death ----
	var d := _panel("You died", 64, Color(0.3, 0, 0, 0.6))
	_death = d[0]
	var dv: VBoxContainer = d[1]
	_button(dv, "Respawn", func(): respawn_pressed.emit())
	_button(dv, "Quit to Title", func(): to_title_pressed.emit())

	hide_all()


func show_title(has_save: bool) -> void:
	hide_all()
	_continue_button.visible = has_save
	_title.visible = true


func show_pause() -> void:
	hide_all()
	_pause.visible = true


func show_death() -> void:
	hide_all()
	_death.visible = true


func hide_all() -> void:
	_title.visible = false
	_pause.visible = false
	_death.visible = false


func set_volume_slider(v: float) -> void:
	_volume.set_value_no_signal(v)


## A dimmed full-screen backdrop with a big title and a centred column
## for buttons. Returns [root control, the column].
func _panel(title: String, title_size: int, dim: Color) -> Array:
	var shell := _panel_shell(dim)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", title_size)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	var column: VBoxContainer = shell[1]
	column.add_child(label)
	column.add_child(_spacer(8))
	return shell


## Same as _panel(), but heads the column with the game's real logo
## instead of a text title. Title-screen only.
func _panel_with_logo(dim: Color) -> Array:
	var shell := _panel_shell(dim)
	var logo := TextureRect.new()
	logo.texture = preload("res://blocky/textures/ui/logo.png")
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(336, 96)   # 2x the source art
	var column: VBoxContainer = shell[1]
	column.add_child(logo)
	column.add_child(_spacer(8))
	return shell


func _panel_shell(dim: Color) -> Array:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := ColorRect.new()
	bg.color = dim
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(column)
	return [root, column]


func _button(column: VBoxContainer, text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(on_pressed)
	column.add_child(b)
	return b


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
