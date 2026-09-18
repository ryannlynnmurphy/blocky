class_name WorldGen
extends RefCounted
## Procedural terrain. Given a chunk position, fills it with blocks.
##
## The idea: for every (x, z) column we ask a noise function "how tall is
## the ground here?" Noise is like a smooth random landscape — nearby
## points get similar values, so you get hills instead of static.
## Same seed = same world every time.

const SIZE := Chunk.SIZE
const HEIGHT := Chunk.HEIGHT

const SEA_LEVEL := 19    # columns at/under this get sand + water
const SNOW_LINE := 44    # columns at/over this get snow

var continent := FastNoiseLite.new()   # big slow hills
var hills := FastNoiseLite.new()       # small bumps on top


func _init(seed_value: int) -> void:
	continent.seed = seed_value
	continent.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	continent.frequency = 0.006
	continent.fractal_octaves = 3

	hills.seed = seed_value + 1
	hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	hills.frequency = 0.03
	hills.fractal_octaves = 2


## Ground height (the y of the top block) at world column (x, z).
func height_at(x: int, z: int) -> int:
	var c := continent.get_noise_2d(x, z)   # -1 .. 1
	var h := hills.get_noise_2d(x, z)       # -1 .. 1
	var height := 24.0 + c * 16.0 + h * 5.0
	return clampi(int(height), 3, HEIGHT - 10)


## Returns [PackedByteArray data, int max_y]. max_y is the highest
## non-air block, so meshing can skip the empty sky above it.
func fill_chunk(cpos: Vector2i) -> Array:
	var data := PackedByteArray()
	data.resize(SIZE * SIZE * HEIGHT)   # new bytes are 0 = AIR
	var max_y := 0
	var heights := PackedInt32Array()
	heights.resize(SIZE * SIZE)

	for lz in SIZE:
		for lx in SIZE:
			var wx := cpos.x * SIZE + lx
			var wz := cpos.y * SIZE + lz
			var h := height_at(wx, wz)
			heights[lx + SIZE * lz] = h
			if h > max_y:
				max_y = h

			var surface := Blocks.GRASS
			var under := Blocks.DIRT
			if h <= SEA_LEVEL + 1:
				surface = Blocks.SAND
				under = Blocks.SAND
			elif h >= SNOW_LINE:
				surface = Blocks.SNOW

			for y in range(0, h + 1):
				var id := Blocks.STONE
				if y == h:
					id = surface
				elif y > h - 3:
					id = under
				data[lx + SIZE * (lz + SIZE * y)] = id

	# Trees. Kept 2 blocks away from chunk edges so a canopy never has to
	# reach into a neighbouring chunk.
	for lz in range(2, SIZE - 2):
		for lx in range(2, SIZE - 2):
			var h := heights[lx + SIZE * lz]
			if h <= SEA_LEVEL + 1 or h >= SNOW_LINE:
				continue
			var wx := cpos.x * SIZE + lx
			var wz := cpos.y * SIZE + lz
			# hash() gives a fixed pseudo-random number for this column.
			if hash(Vector2i(wx, wz)) % 140 != 0:
				continue
			var top := _place_tree(data, lx, h, lz, 4 + hash(Vector2i(wz, wx)) % 2)
			if top > max_y:
				max_y = top

	return [data, max_y]


func _place_tree(data: PackedByteArray, lx: int, ground: int, lz: int, trunk_h: int) -> int:
	var top := ground + trunk_h
	for y in range(ground + 1, top + 1):
		data[lx + SIZE * (lz + SIZE * y)] = Blocks.LOG
	# Canopy: two wide layers, one narrow layer, one block on the tip.
	for dy in range(-1, 2):
		var radius := 2 if dy <= 0 else 1
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if radius == 2 and abs(dx) == 2 and abs(dz) == 2:
					continue   # knock the corners off so it looks rounder
				var i := (lx + dx) + SIZE * ((lz + dz) + SIZE * (top + dy))
				if data[i] == Blocks.AIR:
					data[i] = Blocks.LEAVES
	data[lx + SIZE * (lz + SIZE * (top + 2))] = Blocks.LEAVES
	return top + 2
