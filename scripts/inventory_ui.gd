class_name InventoryUI
extends PanelContainer
## The Tab screen: what you're carrying, and the crafting list with a
## Craft button per recipe. Built from plain Control nodes in code.

var player: Player

var _items_label: Label
var _rows := []   # [recipe, button, label] per recipe


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(600, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	vbox.add_child(_heading("Inventory"))
	_items_label = Label.new()
	_items_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_items_label)

	vbox.add_child(HSeparator.new())
	vbox.add_child(_heading("Crafting"))
	for recipe in Recipes.LIST:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button := Button.new()
		button.text = "Craft"
		button.pressed.connect(_on_craft.bind(recipe))
		row.add_child(label)
		row.add_child(button)
		vbox.add_child(row)
		_rows.append([recipe, button, label])

	var hint := Label.new()
	hint.text = "Tool recipes need a Workbench within 3 blocks.   Tab or Esc to close."
	hint.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(hint)


func bind_player(p: Player) -> void:
	player = p
	p.inventory.changed.connect(func(): if visible: refresh())


func open() -> void:
	visible = true
	refresh()


func close() -> void:
	visible = false


func refresh() -> void:
	_items_label.text = player.inventory.summary()
	var near_bench := player.near_workbench()
	for row in _rows:
		var recipe: Dictionary = row[0]
		var button: Button = row[1]
		var label: Label = row[2]
		label.text = Recipes.describe(recipe) + ("     (workbench)" if recipe["bench"] else "")
		button.disabled = not Recipes.can_craft(player.inventory, recipe, near_bench)


func _on_craft(recipe: Dictionary) -> void:
	if Recipes.can_craft(player.inventory, recipe, player.near_workbench()):
		Recipes.craft(player.inventory, recipe)
	refresh()


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	return l
