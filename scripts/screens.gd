class_name Screens
extends CanvasLayer
## Full-screen menus: title, pause, death. Built from plain Controls in
## code. Each button just emits a signal; main.gd decides what happens.

const WARDROBE_CATALOG = preload("res://scripts/wardrobe_catalog.gd")

signal continue_pressed
signal new_game_pressed(seed_text: String)
signal quit_pressed
signal resume_pressed
signal save_pressed
signal to_title_pressed
signal respawn_pressed
signal sfx_volume_changed(value: float)
signal person_confirmed
signal creator_cancelled

var _title: Control
var _pause: Control
var _death: Control
var _continue_button: Button
var _seed_edit: LineEdit
var _volume: HSlider
var _creator: Control
var _creator_profile: PersonProfile
var _creator_name: LineEdit
var _creator_summary: Label
var _creator_selects: Dictionary = {}
var _creator_axes: Dictionary = {}
var _preview_stage: Node3D
var _preview_avatar: Node3D


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
	ng.text = "Start a New Life"
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

	_build_creator()

	hide_all()


func _process(delta: float) -> void:
	if _creator != null and _creator.visible and _preview_avatar != null:
		_preview_avatar.rotation.y += delta * 0.35


# ---------------------------------------------------------------- create a person

func _build_creator() -> void:
	_creator = Control.new()
	_creator.name = "CreateAPerson"
	_creator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_creator)
	var background := ColorRect.new()
	# Creator is intentionally a calm, light workspace: the game can be messy,
	# but making a person should be legible and welcoming.
	background.color = Color("f5f3ef")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_creator.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 28)
	_creator.add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style(Color("fbfaf7"), Color("c9c9c6")))
	margin.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "CREATE A PERSON"
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", Color("292d33"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var subheading := Label.new()
	subheading.text = "Build a person. The city decides what happens next."
	subheading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subheading.modulate = Color("5f666f")
	column.add_child(subheading)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	column.add_child(body)

	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(490, 0)
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left_scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 10)
	left_scroll.add_child(form)
	_section(form, "IDENTITY")
	_creator_name = LineEdit.new()
	_creator_name.placeholder_text = "Name"
	_creator_name.custom_minimum_size = Vector2(0, 38)
	_creator_name.text_changed.connect(func(value: String):
		if _creator_profile != null:
			_creator_profile.data["identity"]["name"] = value
			_sync_creator_summary())
	form.add_child(_creator_name)
	_add_identity_select(form, "Pronouns", "pronouns", ["she/her", "he/him", "they/them", "any pronouns"])
	_add_identity_select(form, "Background", "background", ["New arrival", "Local", "Former student", "Care worker", "Ex-union organizer"])
	_add_identity_select(form, "Neighborhood", "neighborhood", ["Hollowmark Central", "Riverside", "Old Works", "Northside"])
	_add_identity_select(form, "Starting work", "job", ["Looking for work", "Corner store clerk", "Factory trainee", "Cafe cook", "Street artist"])

	_section(form, "APPEARANCE · SHARED 3D ASSETS")
	for key in ["body", "skin", "hair", "hair_color", "outfit", "accent"]:
		_add_appearance_select(form, key)
	_section(form, "WARDROBE · ONE ITEM PER SLOT")
	# The catalog is the same stable-ID source used by the preview and future
	# player actor. T-shirt is the first visual slice; the remaining controls
	# use the same safe one-slot replacement seam.
	for slot in WARDROBE_CATALOG.SLOTS:
		_add_wardrobe_select(form, slot)

	_section(form, "BEHAVIORAL TENDENCIES")
	for axis in PersonProfile.AXES:
		_add_axis(form, axis)

	_section(form, "DEEP VALUES")
	for slot in range(3):
		_add_value_select(form, slot)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(440, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	var preview_label := Label.new()
	preview_label.text = "LIVE 3D AVATAR"
	preview_label.add_theme_font_size_override("font_size", 15)
	preview_label.add_theme_color_override("font_color", Color("75602d"))
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(preview_label)
	_build_preview(right)
	_creator_summary = Label.new()
	_creator_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_creator_summary.add_theme_stylebox_override("normal", _card_style(Color("eeeeea"), Color("c9c9c6")))
	_creator_summary.add_theme_constant_override("outline_size", 1)
	_creator_summary.custom_minimum_size = Vector2(0, 100)
	right.add_child(_creator_summary)
	var randomize := Button.new()
	randomize.text = "Randomize appearance"
	randomize.pressed.connect(func():
		_creator_profile.randomize_visuals()
		_sync_creator())
	right.add_child(randomize)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(150, 42)
	back.pressed.connect(func(): creator_cancelled.emit())
	actions.add_child(back)
	var begin := Button.new()
	begin.text = "Enter Hollowmark"
	begin.custom_minimum_size = Vector2(240, 42)
	begin.add_theme_font_size_override("font_size", 18)
	begin.pressed.connect(func(): person_confirmed.emit())
	actions.add_child(begin)


func _build_preview(parent: Control) -> void:
	var frame := SubViewportContainer.new()
	frame.custom_minimum_size = Vector2(420, 390)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.stretch = true
	parent.add_child(frame)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(560, 520)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	frame.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	_preview_stage = stage
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("e7e2db")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d9d3ca")
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.light_color = Color("fff0d8")
	key.light_energy = 1.6
	key.rotation_degrees = Vector3(-48, -28, 0)
	stage.add_child(key)
	var fill := OmniLight3D.new()
	fill.light_color = Color("b8cce0")
	fill.light_energy = 2.0
	fill.omni_range = 8.0
	fill.position = Vector3(-2.0, 2.5, 2.0)
	stage.add_child(fill)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(8, 8)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("d5d1cb")
	floor_material.roughness = 1.0
	floor.material_override = floor_material
	stage.add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(3.4, 2.35, 5.4)
	camera.fov = 38.0
	stage.add_child(camera)
	camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)


func show_creator(profile: PersonProfile) -> void:
	hide_all()
	_creator_profile = profile
	_sync_creator()
	_creator.visible = true


func _add_identity_select(parent: Container, title: String, key: String, values: Array) -> void:
	var select := _labelled_select(parent, title, values)
	_creator_selects["identity_" + key] = select
	select.item_selected.connect(func(index: int):
		_creator_profile.data["identity"][key] = values[index]
		_sync_creator_summary())


func _add_appearance_select(parent: Container, key: String) -> void:
	var values: Array = PersonProfile.APPEARANCE_OPTIONS[key]
	var select := _labelled_select(parent, key.capitalize().replace("_", " "), values)
	_creator_selects["appearance_" + key] = select
	select.item_selected.connect(func(index: int):
		_creator_profile.set_appearance(key, values[index])
		_refresh_preview())


func _add_wardrobe_select(parent: Container, slot: String) -> void:
	var choices: Array = WARDROBE_CATALOG.items_for_slot(slot)
	var labels: Array = []
	for choice in choices:
		labels.append(choice["name"])
	var select := _labelled_select(parent, slot.capitalize(), labels)
	_creator_selects["wardrobe_" + slot] = select
	select.item_selected.connect(func(index: int):
		if index >= 0 and index < choices.size():
			_creator_profile.set_wardrobe(slot, str(choices[index]["id"]))
			_refresh_preview())


func _add_axis(parent: Container, axis: String) -> void:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.add_theme_color_override("font_color", Color("454b53"))
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = -100
	slider.max_value = 100
	slider.step = 5
	slider.value_changed.connect(func(value: float):
		_creator_profile.set_axis(axis, value)
		label.text = "%s  %s" % [axis.capitalize(), _axis_words(axis, int(value))]
		_sync_creator_summary())
	row.add_child(slider)
	parent.add_child(row)
	_creator_axes[axis] = {"slider": slider, "label": label}


func _add_value_select(parent: Container, slot: int) -> void:
	var select := _labelled_select(parent, "Value %d" % (slot + 1), PersonProfile.VALUE_OPTIONS)
	_creator_selects["value_%d" % slot] = select
	select.item_selected.connect(func(index: int):
		_creator_profile.set_value(slot, PersonProfile.VALUE_OPTIONS[index])
		_sync_creator_summary())


func _labelled_select(parent: Container, title: String, values: Array) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(148, 0)
	label.add_theme_color_override("font_color", Color("454b53"))
	row.add_child(label)
	var select := OptionButton.new()
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for value in values:
		select.add_item(str(value))
	row.add_child(select)
	parent.add_child(row)
	return select


func _section(parent: Container, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("75602d"))
	label.add_theme_constant_override("outline_size", 2)
	parent.add_child(label)


func _sync_creator() -> void:
	if _creator_profile == null:
		return
	_creator_name.text = str(_creator_profile.data["identity"]["name"])
	for key in ["pronouns", "background", "neighborhood", "job"]:
		var button: OptionButton = _creator_selects["identity_" + key]
		button.select(_find_text(button, str(_creator_profile.data["identity"][key])))
	for key in PersonProfile.APPEARANCE_OPTIONS:
		var appearance_button: OptionButton = _creator_selects["appearance_" + key]
		appearance_button.select(_find_text(appearance_button, _creator_profile.appearance(key)))
	for slot in WARDROBE_CATALOG.SLOTS:
		var wardrobe_button: OptionButton = _creator_selects["wardrobe_" + slot]
		var selected_id := _creator_profile.wardrobe_id(slot)
		var choices: Array = WARDROBE_CATALOG.items_for_slot(slot)
		for index in choices.size():
			if str(choices[index]["id"]) == selected_id:
				wardrobe_button.select(index)
				break
	for slot in range(3):
		var value_button: OptionButton = _creator_selects["value_%d" % slot]
		value_button.select(_find_text(value_button, str(_creator_profile.data["values"][slot])))
	for axis in PersonProfile.AXES:
		var entry: Dictionary = _creator_axes[axis]
		var slider: HSlider = entry["slider"]
		slider.set_value_no_signal(_creator_profile.axis(axis))
		(entry["label"] as Label).text = "%s  %s" % [axis.capitalize(), _axis_words(axis, _creator_profile.axis(axis))]
	_sync_creator_summary()
	_refresh_preview()


func _find_text(button: OptionButton, value: String) -> int:
	for index in button.item_count:
		if button.get_item_text(index) == value:
			return index
	return 0


func _refresh_preview() -> void:
	if _preview_avatar != null:
		_preview_avatar.queue_free()
	_preview_avatar = PersonAppearance.make_preview(_creator_profile.to_dict())
	_preview_stage.add_child(_preview_avatar)


func _sync_creator_summary() -> void:
	if _creator_profile == null or _creator_summary == null:
		return
	var p := _creator_profile.data
	_creator_summary.text = "%s · %s\n%s from %s\nValues: %s, %s, %s\nThe simulation will use this profile for needs, relationships, memories and goals." % [str(p["identity"]["name"]).strip_edges(), p["identity"]["pronouns"], p["identity"]["background"], p["identity"]["neighborhood"], p["values"][0], p["values"][1], p["values"][2]]


func _axis_words(axis: String, value: int) -> String:
	var words := {
		"ambition": ["Content", "Ambitious"], "sociability": ["Solitary", "Social"],
		"risk": ["Cautious", "Risk-taking"], "cooperation": ["Competitive", "Cooperative"],
		"convention": ["Rebellious", "Conventional"], "empathy": ["Self-interested", "Empathetic"],
	}
	return words[axis][1 if value >= 0 else 0] + " (%+d)" % value


func _card_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


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
	if _creator != null:
		_creator.visible = false


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
