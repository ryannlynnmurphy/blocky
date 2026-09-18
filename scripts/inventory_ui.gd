class_name InventoryUI
extends PanelContainer
## The inventory screen, Minecraft-style: a crafting grid (2x2 from your
## pockets, 3x3 at a Workbench) with a result slot, your 27 main slots,
## and the 9 hotbar slots. Click to pick up and drop stacks; right-click
## to split or place one; shift-click the result to craft into your bag.

var player: Player
var bench_mode := false
var grid: Inventory          # the crafting grid, w*w slots
var grid_w := 2

var cursor_id := Blocks.AIR   # what you're holding on the mouse
var cursor_count := 0

var _column: VBoxContainer
var _slot_views: Array[SlotView] = []
var _result_view: SlotView
var _recipe_label: Label
var _cursor_view: Control


## One slot. Draws its contents; clicks go to the screen.
class SlotView extends Control:
	var inv: Inventory       # which container (null for the result slot)
	var index := 0
	var ui: InventoryUI
	var is_result := false
	var result_id := Blocks.AIR
	var result_count := 0

	func _init() -> void:
		custom_minimum_size = Vector2(44, 44)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			var e := event as InputEventMouseButton
			if e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_RIGHT:
				ui.slot_clicked(self, e.button_index, e.shift_pressed)
				accept_event()

	func shown_id() -> int:
		return result_id if is_result else inv.id_at(index)

	func shown_count() -> int:
		return result_count if is_result else inv.count_at(index)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.08, 0.08, 0.1, 0.85))
		draw_rect(r, Color(0.9, 0.85, 0.5, 0.9) if is_result else Color(0, 0, 0, 0.6), false, 2.0)
		var id := shown_id()
		if id == Blocks.AIR:
			return
		draw_rect(r.grow(-9), Blocks.face_color(id, 2))
		var n := shown_count()
		if n > 1:
			draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 5), str(n),
				HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4, 13, Color.WHITE)


## Draws the stack you're carrying, following the mouse, above everything.
class CursorView extends Control:
	var ui: InventoryUI

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if ui.cursor_count > 0:
			queue_redraw()

	func _draw() -> void:
		if ui.cursor_count == 0:
			return
		var p := get_local_mouse_position() - Vector2(16, 16)
		draw_rect(Rect2(p, Vector2(32, 32)), Blocks.face_color(ui.cursor_id, 2))
		draw_rect(Rect2(p, Vector2(32, 32)), Color(0, 0, 0, 0.6), false, 2.0)
		if ui.cursor_count > 1:
			draw_string(ThemeDB.fallback_font, p + Vector2(0, 30), str(ui.cursor_count),
				HORIZONTAL_ALIGNMENT_RIGHT, 30, 13, Color.WHITE)


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 10)
	add_child(_column)
	_cursor_view = CursorView.new()
	_cursor_view.ui = self
	_cursor_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_cursor_view)


func bind_player(p: Player) -> void:
	player = p
	p.inventory.changed.connect(func(): if visible: _redraw_slots())


func open(at_bench: bool = false) -> void:
	bench_mode = at_bench
	grid_w = 3 if at_bench else 2
	grid = Inventory.new(grid_w * grid_w)
	grid.changed.connect(_redraw_slots)
	_build_layout()
	visible = true
	_redraw_slots()


## Anything left in the grid or on the cursor goes back in your bag.
func close() -> void:
	if grid != null:
		for i in grid.size:
			if grid.count_at(i) > 0:
				_give_back(grid.id_at(i), grid.count_at(i))
		grid.clear()
	if cursor_count > 0:
		_give_back(cursor_id, cursor_count)
		cursor_id = Blocks.AIR
		cursor_count = 0
	visible = false


func _give_back(id: int, n: int) -> void:
	var left := player.inventory.add(id, n)
	if left > 0 and player.world != null:
		for k in left:
			player.world.spawn_drop(player.global_position + Vector3(0, 0.5, 0), id)


# ---------------------------------------------------------------- layout

func _build_layout() -> void:
	for child in _column.get_children():
		child.queue_free()
	_slot_views.clear()

	_column.add_child(_heading("Workbench" if bench_mode else "Crafting"))

	# Crafting area: grid -> result.
	var craft_row := HBoxContainer.new()
	craft_row.add_theme_constant_override("separation", 12)
	var grid_box := GridContainer.new()
	grid_box.columns = grid_w
	grid_box.add_theme_constant_override("h_separation", 4)
	grid_box.add_theme_constant_override("v_separation", 4)
	for i in grid_w * grid_w:
		grid_box.add_child(_slot(grid, i))
	craft_row.add_child(grid_box)
	var arrow := Label.new()
	arrow.text = "  →  "
	arrow.add_theme_font_size_override("font_size", 26)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	craft_row.add_child(arrow)
	_result_view = SlotView.new()
	_result_view.ui = self
	_result_view.is_result = true
	_result_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	craft_row.add_child(_result_view)
	_recipe_label = Label.new()
	_recipe_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_recipe_label.modulate = Color(1, 1, 1, 0.75)
	craft_row.add_child(_recipe_label)
	_column.add_child(craft_row)

	if not bench_mode:
		var tip := Label.new()
		tip.text = "Lay items out in a pattern. Tools need a Workbench (right-click one)."
		tip.modulate = Color(1, 1, 1, 0.6)
		_column.add_child(tip)

	_column.add_child(HSeparator.new())
	_column.add_child(_heading("Inventory"))
	var main_box := GridContainer.new()
	main_box.columns = Inventory.HOTBAR
	main_box.add_theme_constant_override("h_separation", 4)
	main_box.add_theme_constant_override("v_separation", 4)
	for i in range(Inventory.HOTBAR, player.inventory.size):
		main_box.add_child(_slot(player.inventory, i))
	_column.add_child(main_box)

	var hotbar_box := GridContainer.new()
	hotbar_box.columns = Inventory.HOTBAR
	hotbar_box.add_theme_constant_override("h_separation", 4)
	for i in Inventory.HOTBAR:
		hotbar_box.add_child(_slot(player.inventory, i))
	_column.add_child(hotbar_box)

	var hint := Label.new()
	hint.text = "Click: pick up / drop a stack.   Right-click: split / place one.   Shift-click result: craft into bag.   Esc to close."
	hint.modulate = Color(1, 1, 1, 0.6)
	_column.add_child(hint)


func _slot(inv: Inventory, index: int) -> SlotView:
	var v := SlotView.new()
	v.inv = inv
	v.index = index
	v.ui = self
	_slot_views.append(v)
	return v


func _redraw_slots() -> void:
	var recipe := Recipes.match_grid(grid, grid_w)
	if recipe.is_empty():
		_result_view.result_id = Blocks.AIR
		_result_view.result_count = 0
		_recipe_label.text = ""
	else:
		_result_view.result_id = recipe["out"][0]
		_result_view.result_count = recipe["out"][1]
		_recipe_label.text = Blocks.NAMES[recipe["out"][0]]
	_result_view.queue_redraw()
	for v in _slot_views:
		v.queue_redraw()


# ---------------------------------------------------------------- clicks

func slot_clicked(view: SlotView, button: int, shift: bool) -> void:
	if view.is_result:
		take_result(shift)
		return
	var inv := view.inv
	var i := view.index
	var sid := inv.id_at(i)
	var sc := inv.count_at(i)
	if button == MOUSE_BUTTON_LEFT:
		if cursor_count == 0:
			if sc > 0:   # pick the stack up
				cursor_id = sid
				cursor_count = sc
				inv.set_slot(i, Blocks.AIR, 0)
		elif sc == 0 or sid == cursor_id:   # put the stack down (as much as fits)
			var put := mini(Inventory.MAX_STACK - sc, cursor_count)
			inv.set_slot(i, cursor_id, sc + put)
			cursor_count -= put
		else:   # swap
			inv.set_slot(i, cursor_id, cursor_count)
			cursor_id = sid
			cursor_count = sc
	elif button == MOUSE_BUTTON_RIGHT:
		if cursor_count == 0:
			if sc > 0:   # take half
				var half := ceili(sc / 2.0)
				cursor_id = sid
				cursor_count = half
				inv.set_slot(i, sid, sc - half)
		elif (sc == 0 or sid == cursor_id) and sc < Inventory.MAX_STACK:   # place one
			inv.set_slot(i, cursor_id, sc + 1)
			cursor_count -= 1
	if cursor_count == 0:
		cursor_id = Blocks.AIR
	_redraw_slots()


## Click the result slot: craft once onto the cursor. Shift: craft as
## many as possible straight into the inventory.
func take_result(shift: bool) -> void:
	var recipe := Recipes.match_grid(grid, grid_w)
	if recipe.is_empty():
		return
	var out_id: int = recipe["out"][0]
	var out_n: int = recipe["out"][1]
	if shift:
		for k in 64:
			if Recipes.match_grid(grid, grid_w) != recipe:
				break
			if player.inventory.add(out_id, out_n) > 0:
				break
			Recipes.consume(grid)
	else:
		if cursor_count > 0 and (cursor_id != out_id or cursor_count + out_n > Inventory.MAX_STACK):
			return
		Recipes.consume(grid)
		cursor_id = out_id
		cursor_count += out_n
	_redraw_slots()


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	return l
