class_name InventoryUI
extends PanelContainer
## The inventory screen, Minecraft-style: a crafting grid (2x2 from your
## pockets, 3x3 at a Workbench) with a result slot, your 27 main slots,
## and the 9 hotbar slots. Click to pick up and drop stacks; right-click
## to split or place one; shift-click the result to craft into your bag.
## A Furnace swaps the shaped grid for two fixed slots (ore, fuel) — see
## open()/_build_layout()/_redraw_slots()/take_result().

var player: Player
var mode := "pocket"   # "pocket", "bench" or "furnace"
var grid: Inventory          # the crafting grid (w*w shaped, or 2 for a furnace)
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
	const SLOT_TEX := preload("res://blocky/textures/ui/slot_frame.png")
	const SELECTED_TEX := preload("res://blocky/textures/ui/slot_selected.png")
	var inv: Inventory       # which container (null for the result slot)
	var index := 0
	var ui: InventoryUI
	var is_result := false
	var result_id := Blocks.AIR
	var result_count := 0

	func _init() -> void:
		custom_minimum_size = Vector2(56, 56)
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
		draw_texture_rect(SLOT_TEX, r, false)
		var id := shown_id()
		if id != Blocks.AIR:
			draw_texture_rect(Blocks.icon(id), r.grow(-11), false)
			var n := shown_count()
			if n > 1:
				draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 6), str(n),
					HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4, 15, Color.WHITE)
		# slot_selected.png is a hollow-centre frame (see the hotbar), safe
		# to draw last; marks the result slot the same way the hotbar marks
		# the selected one.
		if is_result:
			draw_texture_rect(SELECTED_TEX, r.grow(3), false)


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
		draw_texture_rect(Blocks.icon(ui.cursor_id), Rect2(p, Vector2(32, 32)), false)
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
	# A PanelContainer draws nothing on its own without a panel stylebox —
	# without this the whole screen was just loose text and slot squares
	# floating directly over the 3D world, no different from a rendering
	# glitch. Same dark-navy/border palette as the rest of the chunky UI
	# (hotbar_slot.png's edge tone, etc.), with room to breathe around
	# the grids.
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.055, 0.09, 0.94)
	panel_style.border_color = Color(0.15, 0.13, 0.2, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", panel_style)
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


func open(new_mode: String = "pocket") -> void:
	mode = new_mode
	if mode == "furnace":
		grid = Inventory.new(2)   # 0 = ore, 1 = fuel
	else:
		grid_w = 3 if mode == "bench" else 2
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

	if mode == "furnace":
		_build_furnace_section()
	else:
		_build_crafting_section()

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
	# Word-wrap instead of a single unbroken line — otherwise its full
	# unwrapped width forces the whole panel wider than the slot grids,
	# stranding them on the left with dead space to the right.
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_column.add_child(hint)


## The shaped crafting grid (2x2 from your pockets, 3x3 at a Workbench).
func _build_crafting_section() -> void:
	_column.add_child(_heading("Workbench" if mode == "bench" else "Crafting"))
	var craft_row := HBoxContainer.new()
	craft_row.add_theme_constant_override("separation", 12)
	var grid_box := GridContainer.new()
	grid_box.columns = grid_w
	grid_box.add_theme_constant_override("h_separation", 4)
	grid_box.add_theme_constant_override("v_separation", 4)
	for i in grid_w * grid_w:
		grid_box.add_child(_slot(grid, i))
	craft_row.add_child(grid_box)
	craft_row.add_child(_result_arrow())
	_recipe_label = Label.new()
	_recipe_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_recipe_label.modulate = Color(1, 1, 1, 0.75)
	craft_row.add_child(_recipe_label)
	_column.add_child(craft_row)

	if mode != "bench":
		var tip := Label.new()
		tip.text = "Lay items out in a pattern. Tools need a Workbench (right-click one)."
		tip.modulate = Color(1, 1, 1, 0.6)
		_column.add_child(tip)


## Two fixed slots (ore, fuel) instead of a shaped grid — smelting isn't
## a pattern, it's just "the right two ingredients".
func _build_furnace_section() -> void:
	_column.add_child(_heading("Furnace"))
	var craft_row := HBoxContainer.new()
	craft_row.add_theme_constant_override("separation", 12)
	var input_col := VBoxContainer.new()
	input_col.add_theme_constant_override("separation", 4)
	input_col.add_child(_slot(grid, 0))
	input_col.add_child(_slot(grid, 1))
	craft_row.add_child(input_col)
	craft_row.add_child(_result_arrow())
	_column.add_child(craft_row)
	var tip := Label.new()
	tip.text = "Ore, then Fuel (Coal). Iron Ore + Coal → Iron."
	tip.modulate = Color(1, 1, 1, 0.6)
	_column.add_child(tip)


## The arrow + result slot shared by both crafting and smelting.
func _result_arrow() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var arrow := Label.new()
	arrow.text = "  →  "
	arrow.add_theme_font_size_override("font_size", 26)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(arrow)
	_result_view = SlotView.new()
	_result_view.ui = self
	_result_view.is_result = true
	_result_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(_result_view)
	return box


func _slot(inv: Inventory, index: int) -> SlotView:
	var v := SlotView.new()
	v.inv = inv
	v.index = index
	v.ui = self
	_slot_views.append(v)
	return v


func _redraw_slots() -> void:
	if mode == "furnace":
		if _can_smelt():
			_result_view.result_id = Blocks.IRON
			_result_view.result_count = 1
		else:
			_result_view.result_id = Blocks.AIR
			_result_view.result_count = 0
	else:
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
	# CursorView only redraws itself every frame while it's holding
	# something (to track the mouse); the moment a click drops cursor_count
	# to 0 nothing asks it to redraw again, so its last-painted icon stays
	# cached on screen — a stuck "ghost" copy of whatever you just placed.
	# One explicit redraw here, right when the cursor's contents change,
	# lets _draw()'s cursor_count == 0 early-out actually run and clear it.
	_cursor_view.queue_redraw()


## Furnace grid: slot 0 = ore, slot 1 = fuel. The only recipe right now
## is Iron Ore + Coal -> Iron (see take_result()'s furnace branch).
func _can_smelt() -> bool:
	return grid.id_at(0) == Blocks.IRON_ORE and grid.count_at(0) > 0 \
		and grid.id_at(1) == Blocks.COAL and grid.count_at(1) > 0


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


## Click the result slot: craft/smelt once onto the cursor. Shift: as
## many as possible straight into the inventory.
func take_result(shift: bool) -> void:
	if mode == "furnace":
		_take_smelted(shift)
		return
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


func _take_smelted(shift: bool) -> void:
	if not _can_smelt():
		return
	if shift:
		for k in 64:
			if not _can_smelt():
				break
			if player.inventory.add(Blocks.IRON, 1) > 0:
				break
			grid.take_from_slot(0, 1)
			grid.take_from_slot(1, 1)
	else:
		if cursor_count > 0 and (cursor_id != Blocks.IRON or cursor_count + 1 > Inventory.MAX_STACK):
			return
		grid.take_from_slot(0, 1)
		grid.take_from_slot(1, 1)
		cursor_id = Blocks.IRON
		cursor_count += 1
	_redraw_slots()


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	return l
