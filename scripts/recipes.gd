class_name Recipes
extends RefCounted
## Crafting recipes, Minecraft-style. A "shape" is the pattern you lay
## out in the grid (0 = empty cell); it matches anywhere in the grid.
## A "shapeless" recipe only cares which items are present.
## "out" is [item id, how many].

const P := Blocks.PLANKS
const S := Blocks.STICK

const LIST := [
	{"shapeless": [Blocks.LOG], "out": [Blocks.PLANKS, 4]},
	{"shape": [[P], [P]], "out": [Blocks.STICK, 4]},
	{"shape": [[P, P], [P, P]], "out": [Blocks.WORKBENCH, 1]},
	{"shape": [[P, P, P], [0, S, 0], [0, S, 0]], "out": [Blocks.WOOD_PICKAXE, 1]},
	{"shape": [[P, P], [P, S], [0, S]], "out": [Blocks.WOOD_AXE, 1]},
	{"shape": [[Blocks.STONE, Blocks.STONE, Blocks.STONE], [0, S, 0], [0, S, 0]], "out": [Blocks.STONE_PICKAXE, 1]},
	{"shape": [[Blocks.STONE, Blocks.STONE], [Blocks.STONE, S], [0, S]], "out": [Blocks.STONE_AXE, 1]},
	{"shape": [[Blocks.IRON, Blocks.IRON, Blocks.IRON], [0, S, 0], [0, S, 0]], "out": [Blocks.IRON_PICKAXE, 1]},
	{"shape": [[Blocks.IRON, Blocks.IRON], [Blocks.IRON, S], [0, S]], "out": [Blocks.IRON_AXE, 1]},
]


## The recipe the grid currently spells out, or {} if none.
## `w` is the grid's width (2 for pockets, 3 for a workbench).
static func match_grid(grid: Inventory, w: int) -> Dictionary:
	# Find the box of cells that have something in them.
	var min_r := w
	var min_c := w
	var max_r := -1
	var max_c := -1
	for i in w * w:
		if grid.count_at(i) > 0:
			var r := i / w
			var c := i % w
			min_r = mini(min_r, r)
			max_r = maxi(max_r, r)
			min_c = mini(min_c, c)
			max_c = maxi(max_c, c)
	if max_r < 0:
		return {}
	# Copy that box out, so a pattern matches wherever it was placed.
	var cells := []
	var present := []
	for r in range(min_r, max_r + 1):
		var row := []
		for c in range(min_c, max_c + 1):
			var id := grid.id_at(r * w + c)
			row.append(id)
			if id != Blocks.AIR:
				present.append(id)
		cells.append(row)
	present.sort()

	for recipe in LIST:
		if recipe.has("shapeless"):
			var want: Array = recipe["shapeless"].duplicate()
			want.sort()
			if want == present:
				return recipe
		else:
			if cells == recipe["shape"]:
				return recipe
	return {}


## Uses up one of everything in the grid (after taking the result).
static func consume(grid: Inventory) -> void:
	for i in grid.size:
		if grid.count_at(i) > 0:
			grid.take_from_slot(i, 1)


## Does this recipe fit in a grid this wide?
static func fits(recipe: Dictionary, w: int) -> bool:
	if recipe.has("shapeless"):
		return recipe["shapeless"].size() <= w * w
	var shape: Array = recipe["shape"]
	return shape.size() <= w and shape[0].size() <= w


## Ingredient totals: {id: count}.
static func ingredients(recipe: Dictionary) -> Dictionary:
	var out := {}
	if recipe.has("shapeless"):
		for id in recipe["shapeless"]:
			out[id] = out.get(id, 0) + 1
	else:
		for row in recipe["shape"]:
			for id in row:
				if id != 0:
					out[id] = out.get(id, 0) + 1
	return out


# ---- convenience for tests and future NPCs: craft without a grid ----

static func can_craft(inv: Inventory, recipe: Dictionary, at_bench: bool) -> bool:
	if not fits(recipe, 3 if at_bench else 2):
		return false
	var need := ingredients(recipe)
	for id in need:
		if inv.count(id) < need[id]:
			return false
	return true


static func craft(inv: Inventory, recipe: Dictionary) -> void:
	var need := ingredients(recipe)
	for id in need:
		inv.take(id, need[id])
	inv.add(recipe["out"][0], recipe["out"][1])


## "1 Log -> 4 Planks"
static func describe(recipe: Dictionary) -> String:
	var parts: PackedStringArray = []
	var need := ingredients(recipe)
	for id in need:
		parts.append("%d %s" % [need[id], Blocks.NAMES[id]])
	return "%s  →  %d %s" % [" + ".join(parts), recipe["out"][1], Blocks.NAMES[recipe["out"][0]]]
