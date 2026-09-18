class_name WorldGen
extends RefCounted
## Procedural terrain. Given a chunk position, fills it with blocks.
##
## Height: for every (x, z) column a noise function says "how tall is the
## ground here?" Noise is smooth randomness — nearby points get similar
## values — so you get hills instead of static. Same seed = same world.
##
## Biomes: two more, much slower noises give each column a temperature
## and a moisture. Those pick a biome (plains / forest / desert / tundra),
## which decides the ground blocks and how many trees grow. The same two
## numbers also tint the grass, smoothly, so colors drift across the map
## instead of jumping at biome borders.

const SIZE := Chunk.SIZE
const HEIGHT := Chunk.HEIGHT

const SEA_LEVEL := 19    # columns at/under this get sand + water
const SNOW_LINE := 44    # columns at/over this get snow, whatever the biome

enum { PLAINS, FOREST, DESERT, TUNDRA }

## tree_chance = "one tree per N columns" (0 = no trees).
const BIOMES := [
	{"name": "Plains", "surface": Blocks.GRASS, "under": Blocks.DIRT, "tree_chance": 350},
	{"name": "Forest", "surface": Blocks.GRASS, "under": Blocks.DIRT, "tree_chance": 28},
	{"name": "Desert", "surface": Blocks.SAND,  "under": Blocks.SAND, "tree_chance": 0},
	{"name": "Tundra", "surface": Blocks.SNOW,  "under": Blocks.DIRT, "tree_chance": 500},
]

## Grass colors at the four corners of the temperature/moisture square.
const GRASS_COLD_DRY := Color(0.58, 0.72, 0.52)   # pale
const GRASS_HOT_DRY := Color(0.72, 0.72, 0.30)    # yellow, scrubby
const GRASS_COLD_WET := Color(0.34, 0.68, 0.46)   # teal
const GRASS_HOT_WET := Color(0.28, 0.70, 0.20)    # lush

## Trees may stand up to this many blocks outside a chunk and still reach in.
const TREE_MARGIN := 2

var continent := FastNoiseLite.new()   # big slow hills
var hills := FastNoiseLite.new()       # small bumps on top
var temperature := FastNoiseLite.new()
var moisture := FastNoiseLite.new()
# Underground: 3D noises. Caves are carved where `caves` is close to zero
# (a thin sheet through 3D space = winding tunnels), but only where
# `cave_gate` is positive, so tunnels come in regions rather than everywhere.
var caves := FastNoiseLite.new()
var cave_gate := FastNoiseLite.new()
var coal := FastNoiseLite.new()
var iron := FastNoiseLite.new()

const CAVE_WIDTH := 0.07       # bigger = fatter tunnels
const CAVE_FLOOR := 4          # never carve below this y (world floor)
const COAL_THRESHOLD := 0.60   # noise above this in stone = coal ore
const IRON_THRESHOLD := 0.71
const IRON_MAX_Y := 22         # iron only this deep or lower


func _init(seed_value: int) -> void:
	continent.seed = seed_value
	continent.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	continent.frequency = 0.006
	continent.fractal_octaves = 3

	hills.seed = seed_value + 1
	hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	hills.frequency = 0.03
	hills.fractal_octaves = 2

	temperature.seed = seed_value + 2
	temperature.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	temperature.frequency = 0.004
	temperature.fractal_octaves = 2

	moisture.seed = seed_value + 3
	moisture.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moisture.frequency = 0.005
	moisture.fractal_octaves = 2

	caves.seed = seed_value + 4
	caves.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	caves.frequency = 0.045
	caves.fractal_octaves = 1

	cave_gate.seed = seed_value + 5
	cave_gate.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cave_gate.frequency = 0.012
	cave_gate.fractal_octaves = 1

	coal.seed = seed_value + 6
	coal.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	coal.frequency = 0.11
	coal.fractal_octaves = 1

	iron.seed = seed_value + 7
	iron.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	iron.frequency = 0.12
	iron.fractal_octaves = 1


## Ground height (the y of the top block) at world column (x, z).
func height_at(x: int, z: int) -> int:
	var c := continent.get_noise_2d(x, z)   # -1 .. 1
	var h := hills.get_noise_2d(x, z)       # -1 .. 1
	var height := 24.0 + c * 16.0 + h * 5.0
	return clampi(int(height), 3, HEIGHT - 10)


## Which biome (index into BIOMES) is at world column (x, z).
func biome_at(x: int, z: int) -> int:
	var t := temperature.get_noise_2d(x, z)
	var m := moisture.get_noise_2d(x, z)
	if t < -0.3:
		return TUNDRA
	if t > 0.3 and m < -0.1:
		return DESERT
	if m > 0.15:
		return FOREST
	return PLAINS


func biome_name_at(x: int, z: int) -> String:
	return BIOMES[biome_at(x, z)]["name"]


## Grass/leaf color at world column (x, z): a smooth blend of the four
## corner colors based on how warm and how wet it is here.
func tint_at(x: int, z: int) -> Color:
	var warm := clampf(temperature.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
	var wet := clampf(moisture.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
	var dry := GRASS_COLD_DRY.lerp(GRASS_HOT_DRY, warm)
	var moist := GRASS_COLD_WET.lerp(GRASS_HOT_WET, warm)
	return dry.lerp(moist, wet)


## Returns [PackedByteArray data, int max_y, PackedColorArray tints].
## max_y is the highest non-air block, so meshing can skip the empty sky.
## tints is one grass color per column (16x16).
func fill_chunk(cpos: Vector2i) -> Array:
	var data := PackedByteArray()
	data.resize(SIZE * SIZE * HEIGHT)   # new bytes are 0 = AIR
	var tints := PackedColorArray()
	tints.resize(SIZE * SIZE)
	var max_y := 0

	# Heights and biomes for this chunk PLUS a margin around it, so trees
	# rooted just outside can still put their leaves inside.
	var w := SIZE + 2 * TREE_MARGIN
	var heights := PackedInt32Array()
	heights.resize(w * w)
	var biomes := PackedByteArray()
	biomes.resize(w * w)
	for bz in w:
		for bx in w:
			var wx := cpos.x * SIZE + bx - TREE_MARGIN
			var wz := cpos.y * SIZE + bz - TREE_MARGIN
			heights[bx + w * bz] = height_at(wx, wz)
			biomes[bx + w * bz] = biome_at(wx, wz)

	# Ground.
	for lz in SIZE:
		for lx in SIZE:
			var bi := (lx + TREE_MARGIN) + w * (lz + TREE_MARGIN)
			var h := heights[bi]
			var biome: Dictionary = BIOMES[biomes[bi]]
			var wx := cpos.x * SIZE + lx
			var wz := cpos.y * SIZE + lz
			tints[lx + SIZE * lz] = tint_at(wx, wz)
			if h > max_y:
				max_y = h

			var surface: int = biome["surface"]
			var under: int = biome["under"]
			if h <= SEA_LEVEL + 1:
				surface = Blocks.SAND
				under = Blocks.SAND
			elif h >= SNOW_LINE:
				surface = Blocks.SNOW
				under = Blocks.DIRT

			# Caves are allowed where the gate noise is positive; they may
			# only break the surface (a cave mouth) where it's strongly so.
			var gate := cave_gate.get_noise_2d(wx, wz)
			var gated := gate > 0.0
			var mouths := gate > 0.45
			for y in range(0, h + 1):
				var id := Blocks.STONE
				if y == h:
					id = surface
				elif y > h - 3:
					id = under
				elif y > 0:
					# Ore veins inside stone.
					if y <= IRON_MAX_Y and iron.get_noise_3d(wx, y, wz) > IRON_THRESHOLD:
						id = Blocks.IRON_ORE
					elif coal.get_noise_3d(wx, y, wz) > COAL_THRESHOLD:
						id = Blocks.COAL_ORE
				# Carve caves through anything above the world floor.
				if gated and y >= CAVE_FLOOR and (y < h - 2 or mouths) \
						and absf(caves.get_noise_3d(wx, y, wz)) < CAVE_WIDTH:
					id = Blocks.AIR
				data[lx + SIZE * (lz + SIZE * y)] = id

	# Trees: decided per world column, so the same tree is placed
	# identically by every chunk it touches.
	for bz in w:
		for bx in w:
			var bi := bx + w * bz
			var h := heights[bi]
			var chance: int = BIOMES[biomes[bi]]["tree_chance"]
			if chance == 0 or h <= SEA_LEVEL + 1 or h >= SNOW_LINE:
				continue
			var wx := cpos.x * SIZE + bx - TREE_MARGIN
			var wz := cpos.y * SIZE + bz - TREE_MARGIN
			# hash() gives a fixed pseudo-random number for this column.
			if hash(Vector2i(wx, wz)) % chance != 0:
				continue
			var trunk_h := 4 + hash(Vector2i(wz, wx)) % 2
			var top := _place_tree(data, bx - TREE_MARGIN, h, bz - TREE_MARGIN, trunk_h)
			if top > max_y:
				max_y = top

	return [data, max_y, tints]


## Writes a block if (x, y, z) is inside this chunk; ignores it otherwise.
func _set_block(data: PackedByteArray, x: int, y: int, z: int, id: int, only_if_air: bool) -> void:
	if x < 0 or x >= SIZE or z < 0 or z >= SIZE or y < 0 or y >= HEIGHT:
		return
	var i := x + SIZE * (z + SIZE * y)
	if only_if_air and data[i] != Blocks.AIR:
		return
	data[i] = id


## Stamps a tree whose trunk base is at local (lx, ground, lz). Parts that
## fall outside the chunk are simply skipped. Returns the tree's top y.
func _place_tree(data: PackedByteArray, lx: int, ground: int, lz: int, trunk_h: int) -> int:
	var top := ground + trunk_h
	for y in range(ground + 1, top + 1):
		_set_block(data, lx, y, lz, Blocks.LOG, false)
	# Canopy: two wide layers, one narrow layer, one block on the tip.
	for dy in range(-1, 2):
		var radius := 2 if dy <= 0 else 1
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if radius == 2 and abs(dx) == 2 and abs(dz) == 2:
					continue   # knock the corners off so it looks rounder
				_set_block(data, lx + dx, top + dy, lz + dz, Blocks.LEAVES, true)
	_set_block(data, lx, top + 2, lz, Blocks.LEAVES, true)
	return min(top + 2, HEIGHT - 1)
