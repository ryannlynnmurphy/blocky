class_name Recipes
extends RefCounted
## Crafting recipes: what goes in, what comes out, and whether you need
## to be standing near a workbench. No grid — just a list.

const LIST := [
	{"in": {Blocks.LOG: 1}, "out": {Blocks.PLANKS: 4}, "bench": false},
	{"in": {Blocks.PLANKS: 2}, "out": {Blocks.STICK: 4}, "bench": false},
	{"in": {Blocks.PLANKS: 4}, "out": {Blocks.WORKBENCH: 1}, "bench": false},
	{"in": {Blocks.PLANKS: 3, Blocks.STICK: 2}, "out": {Blocks.WOOD_PICKAXE: 1}, "bench": true},
	{"in": {Blocks.PLANKS: 3, Blocks.STICK: 2}, "out": {Blocks.WOOD_AXE: 1}, "bench": true},
	{"in": {Blocks.STONE: 3, Blocks.STICK: 2}, "out": {Blocks.STONE_PICKAXE: 1}, "bench": true},
	{"in": {Blocks.STONE: 3, Blocks.STICK: 2}, "out": {Blocks.STONE_AXE: 1}, "bench": true},
]


static func can_craft(inv: Inventory, recipe: Dictionary, near_bench: bool) -> bool:
	if recipe["bench"] and not near_bench:
		return false
	for id in recipe["in"]:
		if inv.count(id) < recipe["in"][id]:
			return false
	return true


## Spends the ingredients and adds the result. Check can_craft first.
static func craft(inv: Inventory, recipe: Dictionary) -> void:
	for id in recipe["in"]:
		inv.take(id, recipe["in"][id])
	for id in recipe["out"]:
		inv.add(id, recipe["out"][id])


## "1 Log + 2 Sticks -> 4 Planks"
static func describe(recipe: Dictionary) -> String:
	return "%s  →  %s" % [_list(recipe["in"]), _list(recipe["out"])]


static func _list(items: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id in items:
		parts.append("%d %s" % [items[id], Blocks.NAMES[id]])
	return " + ".join(parts)
