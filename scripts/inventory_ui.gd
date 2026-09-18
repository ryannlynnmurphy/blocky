class_name InventoryUI
extends PanelContainer
## The Tab screen: a grid of item slots (like a Minecraft inventory) and
## the recipe list drawn as icons: ingredients -> result, plus a Craft
## button. Everything is drawn with _draw(); no image files.

const COLUMNS := 9
const MIN_SLOTS := 18

var player: Player
var bench_mode := false   # opened from a Workbench: tool recipes available

var _grid: GridContainer
var _title: Label
var _bench_label: Label
var _rows := []   # [recipe, row, button, [ingredient icons], result icon] per recipe


## One inventory slot: a coloured square for the item, count in the
## corner. In recipes it shows have/need and dims when you're short.
class SlotIcon extends Control:
	var id := -1
	var count := 0
	var need := 0
	var ok := true

	func _init() -> void:
		custom_minimum_size = Vector2(42, 42)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func set_item(item_id: int, have: int, needed: int = 0) -> void:
		id = item_id
		count = have
		need = needed
		ok = needed == 0 or have >= needed
		tooltip_text = Blocks.NAMES[id] if id >= 0 else ""
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.08, 0.08, 0.1, 0.85))
		draw_rect(r, Color(0, 0, 0, 0.6), false, 2.0)
		if id < 0:
			return
		var c := Blocks.face_color(id, 2)
		if not ok:
			c.a = 0.35
		draw_rect(r.grow(-8), c)
		var font := ThemeDB.fallback_font
		var text := ("%d/%d" % [count, need]) if need > 0 else (str(count) if count > 1 else "")
		if text != "":
			draw_string(font, Vector2(0, size.y - 5), text, HORIZONTAL_ALIGNMENT_RIGHT,
				size.x - 4, 12, Color.WHITE if ok else Color(1, 0.5, 0.5))


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(660, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	_title = _heading("Inventory")
	vbox.add_child(_title)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_grid)

	vbox.add_child(HSeparator.new())
	var crafting_row := HBoxContainer.new()
	crafting_row.add_child(_heading("Crafting"))
	_bench_label = Label.new()
	_bench_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bench_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	crafting_row.add_child(_bench_label)
	vbox.add_child(crafting_row)

	for recipe in Recipes.LIST:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var icons := []
		for id in recipe["in"]:
			var icon := SlotIcon.new()
			row.add_child(icon)
			icons.append([id, icon])
		var arrow := Label.new()
		arrow.text = "  →  "
		arrow.add_theme_font_size_override("font_size", 20)
		row.add_child(arrow)
		var result := SlotIcon.new()
		row.add_child(result)
		var name := Label.new()
		var out_id: int = recipe["out"].keys()[0]
		name.text = "  %s" % Blocks.NAMES[out_id]
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var button := Button.new()
		button.text = "Craft"
		button.custom_minimum_size = Vector2(80, 0)
		button.pressed.connect(_on_craft.bind(recipe))
		row.add_child(button)
		vbox.add_child(row)
		_rows.append([recipe, row, button, icons, result])

	var hint := Label.new()
	hint.text = "Hover a slot for its name.   Esc to close."
	hint.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(hint)


func bind_player(p: Player) -> void:
	player = p
	p.inventory.changed.connect(func(): if visible: refresh())


func open(at_bench: bool = false) -> void:
	bench_mode = at_bench
	visible = true
	refresh()


func close() -> void:
	visible = false


func refresh() -> void:
	# Inventory grid: blocks first, then items, then empty slots to pad.
	for child in _grid.get_children():
		child.queue_free()
	var shown := 0
	for id in Blocks.BLOCKS + Blocks.ITEMS:
		var n := player.inventory.count(id)
		if n > 0:
			var icon := SlotIcon.new()
			icon.set_item(id, n)
			_grid.add_child(icon)
			shown += 1
	var pad := maxi(MIN_SLOTS, ceili(float(shown) / COLUMNS) * COLUMNS)
	for i in range(shown, pad):
		_grid.add_child(SlotIcon.new())

	# Crafting rows. At a Workbench every recipe shows; from your pockets
	# (Tab) only the simple ones do.
	_title.text = "Workbench" if bench_mode else "Inventory"
	_bench_label.text = "" if bench_mode else "Right-click a Workbench for tools"
	_bench_label.modulate = Color(1, 1, 1, 0.6)
	for row in _rows:
		var recipe: Dictionary = row[0]
		var row_control: Control = row[1]
		var button: Button = row[2]
		row_control.visible = bench_mode or not recipe["bench"]
		for pair in row[3]:
			var id: int = pair[0]
			var icon: SlotIcon = pair[1]
			icon.set_item(id, player.inventory.count(id), recipe["in"][id])
		var out_id: int = recipe["out"].keys()[0]
		var result: SlotIcon = row[4]
		result.set_item(out_id, recipe["out"][out_id])
		button.disabled = not Recipes.can_craft(player.inventory, recipe, bench_mode)


func _on_craft(recipe: Dictionary) -> void:
	if Recipes.can_craft(player.inventory, recipe, bench_mode):
		Recipes.craft(player.inventory, recipe)
	refresh()


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	return l
