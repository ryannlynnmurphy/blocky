class_name Blocks
extends RefCounted
## The block registry: every block type the game knows about.
##
## A block in the world is just a number (its ID). This file is the lookup
## table that says what each number means: its name, its world texture
## (see BlockAtlas / atlas_faces()) and its icon (see ICON / icon()).

## Blocks (things that exist in the world) and items (things you can only
## carry) share one ID space, because they share the inventory. New IDs
## are always appended at the end so old save files keep meaning the same.
enum { AIR, GRASS, DIRT, STONE, SAND, LOG, LEAVES, SNOW, PLANKS, MEAT,
	WORKBENCH, STICK, WOOD_PICKAXE, WOOD_AXE, STONE_PICKAXE, STONE_AXE,
	COAL_ORE, IRON_ORE, COAL, IRON, IRON_PICKAXE, IRON_AXE }

const NAMES := ["Air", "Grass", "Dirt", "Stone", "Sand", "Log", "Leaves", "Snow", "Planks", "Meat",
	"Workbench", "Stick", "Wooden Pickaxe", "Wooden Axe", "Stone Pickaxe", "Stone Axe",
	"Coal Ore", "Iron Ore", "Coal", "Iron", "Iron Pickaxe", "Iron Axe"]

## Everything that can exist in the world as a block.
const BLOCKS := [GRASS, DIRT, STONE, SAND, LOG, LEAVES, SNOW, PLANKS, WORKBENCH, COAL_ORE, IRON_ORE]

## Items (not blocks) worth listing on the HUD.
const ITEMS := [MEAT, STICK, COAL, IRON, WOOD_PICKAXE, WOOD_AXE, STONE_PICKAXE, STONE_AXE,
	IRON_PICKAXE, IRON_AXE]

## Seconds of holding the button it takes to break each block by hand.
const HARDNESS := {
	GRASS: 0.6, DIRT: 0.5, STONE: 3.0, SAND: 0.5,
	LOG: 1.0, LEAVES: 0.25, SNOW: 0.3, PLANKS: 0.9, WORKBENCH: 1.0,
	COAL_ORE: 3.5, IRON_ORE: 4.5,
}

## Which kind of tool speeds up which block. "" = hands are as good as anything.
const TOOL_CLASS := {
	STONE: "pickaxe", COAL_ORE: "pickaxe", IRON_ORE: "pickaxe",
	LOG: "axe", PLANKS: "axe", WORKBENCH: "axe",
}

## Tools by class: [item, speed multiplier, tier]. Wood 1, stone 2, iron 3.
const TOOLS := {
	"pickaxe": [[WOOD_PICKAXE, 2.5, 1], [STONE_PICKAXE, 4.0, 2], [IRON_PICKAXE, 6.0, 3]],
	"axe": [[WOOD_AXE, 2.5, 1], [STONE_AXE, 4.0, 2], [IRON_AXE, 6.0, 3]],
}

## Blocks that drop nothing unless broken with at least this tool tier.
const NEEDS_TOOL := {
	STONE: ["pickaxe", 1], COAL_ORE: ["pickaxe", 1], IRON_ORE: ["pickaxe", 2],
}

## What a block turns into when you break it (default: itself).
const DROP_OF := {COAL_ORE: COAL, IRON_ORE: IRON}

## Which BlockAtlas.FACES family (see blocky/scripts/block_atlas.gd) a
## world block's texture comes from. Blocks with no entry aren't drawn
## with the atlas (nothing here is meant to be one right now).
const ATLAS_FAMILY := {
	GRASS: "grass", DIRT: "dirt", STONE: "stone", SAND: "sand",
	LOG: "log", LEAVES: "leaves", SNOW: "snow", PLANKS: "planks",
	WORKBENCH: "workbench", COAL_ORE: "coal_ore", IRON_ORE: "iron_ore",
}


static func hardness(id: int) -> float:
	return HARDNESS.get(id, 1.0)


static func tool_class(id: int) -> String:
	return TOOL_CLASS.get(id, "")


static func drop_for(id: int) -> int:
	return DROP_OF.get(id, id)


static func is_block(id: int) -> bool:
	return id in BLOCKS


## [top, side, bottom] face names into BlockAtlas.uv(), or [] if this
## block has no atlas texture.
static func atlas_faces(id: int) -> Array:
	var family: String = ATLAS_FAMILY.get(id, "")
	return BlockAtlas.FACES[family] if family != "" else []


## Icon per block/item, for the hotbar, inventory slots, the cursor
## stack and dropped-item cubes. Reuses one existing 16x16 face texture
## per id — no separate icon art needed, and no per-frame loading
## (preload resolves these once, at parse time).
const ICON := {
	GRASS: preload("res://blocky/textures/blocks/grass_side.png"),
	DIRT: preload("res://blocky/textures/blocks/dirt.png"),
	STONE: preload("res://blocky/textures/blocks/stone.png"),
	SAND: preload("res://blocky/textures/blocks/sand.png"),
	LOG: preload("res://blocky/textures/blocks/log_side.png"),
	LEAVES: preload("res://blocky/textures/blocks/leaves.png"),
	SNOW: preload("res://blocky/textures/blocks/snow.png"),
	PLANKS: preload("res://blocky/textures/blocks/planks.png"),
	WORKBENCH: preload("res://blocky/textures/blocks/workbench_top.png"),
	COAL_ORE: preload("res://blocky/textures/blocks/coal_ore.png"),
	IRON_ORE: preload("res://blocky/textures/blocks/iron_ore.png"),
	MEAT: preload("res://blocky/textures/items/meat.png"),
	STICK: preload("res://blocky/textures/items/stick.png"),
	COAL: preload("res://blocky/textures/items/coal.png"),
	IRON: preload("res://blocky/textures/items/iron.png"),
	WOOD_PICKAXE: preload("res://blocky/textures/items/wooden_pickaxe.png"),
	WOOD_AXE: preload("res://blocky/textures/items/wooden_axe.png"),
	STONE_PICKAXE: preload("res://blocky/textures/items/stone_pickaxe.png"),
	STONE_AXE: preload("res://blocky/textures/items/stone_axe.png"),
	IRON_PICKAXE: preload("res://blocky/textures/items/iron_pickaxe.png"),
	IRON_AXE: preload("res://blocky/textures/items/iron_axe.png"),
}


static func icon(id: int) -> Texture2D:
	return ICON.get(id)


static func is_solid(id: int) -> bool:
	return id != AIR
