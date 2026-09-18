class_name Blocks
extends RefCounted
## The block registry: every block type the game knows about.
##
## A block in the world is just a number (its ID). This file is the lookup
## table that says what each number means: its name and its colors.
## No textures yet — every block is a flat colored cube, which is the
## chunky low-poly look we want.

## IDs up to PLANKS are blocks that exist in the world. IDs after that
## are items: things you can carry but not place (they share the same
## inventory, so they share this list).
enum { AIR, GRASS, DIRT, STONE, SAND, LOG, LEAVES, SNOW, PLANKS, MEAT }

const NAMES := ["Air", "Grass", "Dirt", "Stone", "Sand", "Log", "Leaves", "Snow", "Planks", "Meat"]

## Items (not blocks) worth listing on the HUD.
const ITEMS := [MEAT]

## Seconds of holding the button it takes to break each block by hand.
const HARDNESS := {
	GRASS: 0.6, DIRT: 0.5, STONE: 1.5, SAND: 0.5,
	LOG: 1.0, LEAVES: 0.25, SNOW: 0.3, PLANKS: 0.9,
}


static func hardness(id: int) -> float:
	return HARDNESS.get(id, 1.0)

## Blocks you can pick with keys 1-8 and place.
const HOTBAR := [GRASS, DIRT, STONE, SAND, LOG, LEAVES, PLANKS, SNOW]

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
