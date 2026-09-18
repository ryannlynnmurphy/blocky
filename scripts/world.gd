class_name VoxelWorld
extends Node3D
## Owns all chunks. Streams them in around the player and answers
## "what block is at (x, y, z)?" for everyone else.

const SIZE := Chunk.SIZE
const HEIGHT := Chunk.HEIGHT

@export var world_seed := 1337
@export var view_radius := 4        # chunks loaded in each direction
@export var chunks_per_frame := 2   # how many meshes to build per frame

var gen: WorldGen
var chunk_data := {}    # Vector2i -> PackedByteArray (kept forever, so edits survive)
var chunk_max_y := {}   # Vector2i -> int
var chunk_tints := {}   # Vector2i -> PackedColorArray (grass color per column)
var chunks := {}        # Vector2i -> Chunk node (only the ones near the player)
var mesh_queue: Array[Vector2i] = []
var player: Node3D

var _last_player_chunk := Vector2i(1 << 20, 1 << 20)

# ---- creatures ----
const MAX_CREATURES := 40
const CREATURE_SCENE := preload("res://scenes/creature.tscn")
## Chance that a freshly built chunk gets a group of animals, per biome.
const SPAWN_CHANCE := [0.35, 0.25, 0.08, 0.2]   # Plains, Forest, Desert, Tundra
const COAT_COLORS := [
	Color(0.85, 0.70, 0.50),   # Plains: tan
	Color(0.55, 0.38, 0.25),   # Forest: brown
	Color(0.90, 0.80, 0.55),   # Desert: sandy
	Color(0.92, 0.92, 0.95),   # Tundra: white
]
var _creatures := Node3D.new()
var _populated := {}   # Vector2i -> true once a chunk has rolled for animals


func _ready() -> void:
	gen = WorldGen.new(world_seed)
	_creatures.name = "Creatures"
	add_child(_creatures)


func _process(_delta: float) -> void:
	if player == null:
		return
	var pc := chunk_coord_of(player.global_position)
	if pc != _last_player_chunk:
		_last_player_chunk = pc
		update_chunks(pc)

	# Build a few queued meshes per frame so the game never freezes.
	var budget := chunks_per_frame
	while budget > 0 and mesh_queue.size() > 0:
		var cpos: Vector2i = mesh_queue.pop_front()
		if chunks.has(cpos) and chunks[cpos].dirty:
			chunks[cpos].build_mesh()
			budget -= 1
			# Only now is there ground to stand on, so spawn animals here.
			if not _populated.has(cpos):
				_populated[cpos] = true
				_populate_chunk(cpos)


# ---------------------------------------------------------------- lookups

func chunk_coord_of(world_pos: Vector3) -> Vector2i:
	# ">> 4" is integer division by 16 that also works for negatives.
	return Vector2i(int(floor(world_pos.x)) >> 4, int(floor(world_pos.z)) >> 4)


func height_at(x: int, z: int) -> int:
	return gen.height_at(x, z)


func biome_name_at(x: int, z: int) -> String:
	return gen.biome_name_at(x, z)


func get_block(wx: int, wy: int, wz: int) -> int:
	if wy < 0 or wy >= HEIGHT:
		return Blocks.AIR
	var cpos := Vector2i(wx >> 4, wz >> 4)
	if not chunk_data.has(cpos):
		return Blocks.AIR
	var d: PackedByteArray = chunk_data[cpos]
	# "& 15" keeps only the low 4 bits = position inside the chunk (0-15).
	return d[(wx & 15) + SIZE * ((wz & 15) + SIZE * wy)]


func set_block(wx: int, wy: int, wz: int, id: int) -> void:
	if wy < 0 or wy >= HEIGHT:
		return
	var cpos := Vector2i(wx >> 4, wz >> 4)
	if not chunk_data.has(cpos):
		return
	var d: PackedByteArray = chunk_data[cpos]
	d[(wx & 15) + SIZE * ((wz & 15) + SIZE * wy)] = id
	chunk_data[cpos] = d
	if id != Blocks.AIR and wy > chunk_max_y[cpos]:
		chunk_max_y[cpos] = wy

	_rebuild_now(cpos)
	# A block on a chunk edge changes which faces the neighbour shows.
	var lx := wx & 15
	var lz := wz & 15
	if lx == 0:
		_rebuild_now(cpos + Vector2i(-1, 0))
	elif lx == 15:
		_rebuild_now(cpos + Vector2i(1, 0))
	if lz == 0:
		_rebuild_now(cpos + Vector2i(0, -1))
	elif lz == 15:
		_rebuild_now(cpos + Vector2i(0, 1))


# ---------------------------------------------------------------- streaming

## Make sure the block data for a chunk exists (generating it if needed).
func ensure_data(cpos: Vector2i) -> void:
	if chunk_data.has(cpos):
		return
	var result := gen.fill_chunk(cpos)
	chunk_data[cpos] = result[0]
	chunk_max_y[cpos] = result[1]
	chunk_tints[cpos] = result[2]


## Load chunks near the player, unload far ones.
func update_chunks(pc: Vector2i) -> void:
	for cpos in chunks.keys():
		var d: Vector2i = (cpos - pc).abs()
		if max(d.x, d.y) > view_radius + 2:
			chunks[cpos].queue_free()
			chunks.erase(cpos)
			_populated.erase(cpos)   # animals may return when you come back

	# Animals that wandered (or were left) too far away are removed.
	var despawn_dist := float((view_radius + 2) * SIZE)
	for c in _creatures.get_children():
		if c.global_position.distance_to(player.global_position) > despawn_dist:
			c.queue_free()

	var wanted: Array[Vector2i] = []
	for dz in range(-view_radius, view_radius + 1):
		for dx in range(-view_radius, view_radius + 1):
			wanted.append(pc + Vector2i(dx, dz))
	# Nearest chunks first, so the ground under your feet appears first.
	wanted.sort_custom(func(a, b): return (a - pc).length_squared() < (b - pc).length_squared())

	for cpos in wanted:
		if chunks.has(cpos):
			continue
		# Neighbour data must exist so edge faces cull correctly.
		ensure_data(cpos)
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			ensure_data(cpos + n)
		var chunk := Chunk.new()
		chunk.setup(self, cpos)
		add_child(chunk)
		chunks[cpos] = chunk
		mesh_queue.append(cpos)


## Build one chunk's mesh right now instead of waiting for the queue.
func _rebuild_now(cpos: Vector2i) -> void:
	if chunks.has(cpos):
		chunks[cpos].build_mesh()


func build_chunk_now(cpos: Vector2i) -> void:
	_rebuild_now(cpos)


# ---------------------------------------------------------------- creatures

## Rolls the dice for a small group of animals in a chunk.
func _populate_chunk(cpos: Vector2i) -> void:
	var biome := gen.biome_at(cpos.x * SIZE + 8, cpos.y * SIZE + 8)
	if randf() > SPAWN_CHANCE[biome]:
		return
	for i in randi_range(1, 3):
		var wx := cpos.x * SIZE + randi_range(0, SIZE - 1)
		var wz := cpos.y * SIZE + randi_range(0, SIZE - 1)
		spawn_creature(wx, wz)


## Puts one animal on the ground at world column (wx, wz), if there's
## room. Returns it, or null.
func spawn_creature(wx: int, wz: int) -> Creature:
	if _creatures.get_child_count() >= MAX_CREATURES:
		return null
	var h := gen.height_at(wx, wz)
	if h <= WorldGen.SEA_LEVEL + 1:
		return null   # beach or under water
	if get_block(wx, h + 1, wz) != Blocks.AIR or get_block(wx, h + 2, wz) != Blocks.AIR:
		return null   # something (a tree?) is in the way
	var c: Creature = CREATURE_SCENE.instantiate()
	c.world = self
	c.body_color = COAT_COLORS[gen.biome_at(wx, wz)]
	_creatures.add_child(c)
	c.global_position = Vector3(wx + 0.5, h + 1.5, wz + 0.5)
	return c


func creature_count() -> int:
	return _creatures.get_child_count()
