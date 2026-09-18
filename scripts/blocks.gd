class_name Blocks
extends RefCounted
## The block registry: every block type the game knows about.
##
## A block in the world is just a number (its ID). This file is the lookup
## table that says what each number means: its name and its colors.
## No textures yet — every block is a flat colored cube, which is the
## chunky low-poly look we want.

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


static func hardness(id: int) -> float:
	return HARDNESS.get(id, 1.0)


static func tool_class(id: int) -> String:
	return TOOL_CLASS.get(id, "")


static func drop_for(id: int) -> int:
	return DROP_OF.get(id, id)


static func is_block(id: int) -> bool:
	return id in BLOCKS

## Blocks you can pick with keys 1-9 and place.
const HOTBAR := [GRASS, DIRT, STONE, SAND, LOG, LEAVES, PLANKS, SNOW, WORKBENCH]

## Colors per block: [top face, side faces, bottom face].
const COLORS := {
	GRASS:  [Color(0.44, 0.78, 0.30), Color(0.50, 0.40, 0.25), Color(0.55, 0.38, 0.24)],
	DIRT:   [Color(0.55, 0.38, 0.24), Color(0.52, 0.36, 0.22), Color(0.48, 0.33, 0.20)],
	STONE:  [Color(0.58, 0.58, 0.60), Color(0.52, 0.52, 0.55), Color(0.45, 0.45, 0.48)],
	SAND:   [Color(0.92, 0.86, 0.60), Color(0.88, 0.80, 0.55), Color(0.82, 0.75, 0.50)],
	LOG:    [Color(0.62, 0.48, 0.30), Color(0.42, 0.29, 0.16), Color(0.62, 0.48, 0.30)],
	LEAVES: [Color(0.28, 0.62, 0.26), Color(0.24, 0.55, 0.22), Color(0.20, 0.48, 0.20)],
	SNOW:   [Color(0.96, 0.97, 1.00), Color(0.86, 0.90, 0.96), Color(0.80, 0.84, 0.90)],
	PLANKS: [Color(0.78, 0.62, 0.38), Color(0.72, 0.56, 0.34), Color(0.65, 0.50, 0.30)],
	MEAT:   [Color(0.88, 0.40, 0.42), Color(0.80, 0.32, 0.35), Color(0.70, 0.28, 0.30)],
	WORKBENCH: [Color(0.76, 0.56, 0.32), Color(0.55, 0.38, 0.22), Color(0.45, 0.30, 0.18)],
	STICK:  [Color(0.55, 0.40, 0.22), Color(0.55, 0.40, 0.22), Color(0.55, 0.40, 0.22)],
	WOOD_PICKAXE:  [Color(0.72, 0.52, 0.30), Color(0.72, 0.52, 0.30), Color(0.72, 0.52, 0.30)],
	WOOD_AXE:      [Color(0.66, 0.47, 0.27), Color(0.66, 0.47, 0.27), Color(0.66, 0.47, 0.27)],
	STONE_PICKAXE: [Color(0.58, 0.58, 0.62), Color(0.58, 0.58, 0.62), Color(0.58, 0.58, 0.62)],
	STONE_AXE:     [Color(0.50, 0.50, 0.54), Color(0.50, 0.50, 0.54), Color(0.50, 0.50, 0.54)],
	COAL_ORE: [Color(0.36, 0.36, 0.38), Color(0.32, 0.32, 0.34), Color(0.28, 0.28, 0.30)],
	IRON_ORE: [Color(0.66, 0.54, 0.44), Color(0.60, 0.49, 0.40), Color(0.52, 0.42, 0.34)],
	COAL:     [Color(0.14, 0.14, 0.15), Color(0.14, 0.14, 0.15), Color(0.14, 0.14, 0.15)],
	IRON:     [Color(0.80, 0.70, 0.60), Color(0.80, 0.70, 0.60), Color(0.80, 0.70, 0.60)],
	IRON_PICKAXE: [Color(0.82, 0.80, 0.78), Color(0.82, 0.80, 0.78), Color(0.82, 0.80, 0.78)],
	IRON_AXE:     [Color(0.76, 0.74, 0.72), Color(0.76, 0.74, 0.72), Color(0.76, 0.74, 0.72)],
}


static func is_solid(id: int) -> bool:
	return id != AIR


## face: 0 +X, 1 -X, 2 +Y (top), 3 -Y (bottom), 4 +Z, 5 -Z  (see Chunk.FACES)
static func face_color(id: int, face: int) -> Color:
	var set: Array = COLORS[id]
	if face == 2:
		return set[0]
	if face == 3:
		return set[2]
	return set[1]
