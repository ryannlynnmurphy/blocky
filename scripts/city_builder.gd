class_name CityBuilder
extends RefCounted
## First milestone of the New York-inspired block city (Ryann's direction,
## 2026-09-20, replacing the deleted Hollowmark Sims-style city): a real
## voxel-block tower standing at real open-world coordinates, built through
## the same VoxelWorld data VoxelWorld.set_block() itself edits -- not a
## separate embedded scene, no new block types added (only Blocks.STONE,
## already in the palette).
##
## This is a first shell, not the whole city: one tower + its street-level
## plaza. More blocks (a street grid, more buildings, material variety) are
## follow-up milestones once this one is confirmed to actually look right.
##
## Deliberately does NOT call world.set_block() per block: that triggers a
## full synchronous chunk.build_mesh() on every single call (see
## world.gd's own doc comment on _rebuild_now()), and this tower is ~600+
## blocks -- hundreds of back-to-back full rebuilds inside main.gd's
## _ready(), before the renderer has drawn a first frame, reliably crashed
## a headless verification run (signal 11 inside the dummy renderer).
## Instead this pokes world.chunk_data/edits/chunk_max_y directly (the
## exact same three writes set_block() itself does, minus its per-call
## rebuild and its torch-light hook, irrelevant here since nothing placed
## here is a torch) and rebuilds each touched chunk's mesh exactly once,
## after every block is already in place.


const TOWER_WIDTH := 7
const TOWER_DEPTH := 7
const TOWER_HEIGHT := 14
## Blocks of flat stone plaza beyond the tower's own footprint, so it reads
## as a building on a sidewalk, not a block floating over grass.
const PLAZA_MARGIN := 3


## Places one tower with a street-level plaza whose near corner is at
## world columns (origin.x, origin.y), door facing -Z. Forces every chunk
## the footprint touches to be generated first (world.update_chunks()/
## build_chunk_now() -- the same pattern main.gd's own
## _build_ground_under_player() already uses), so this is safe to call
## right after boot, before normal streaming would otherwise reach it.
static func build_tower(world: VoxelWorld, origin: Vector2i) -> void:
	var min_x := origin.x - PLAZA_MARGIN
	var max_x := origin.x + TOWER_WIDTH - 1 + PLAZA_MARGIN
	var min_z := origin.y - PLAZA_MARGIN
	var max_z := origin.y + TOWER_DEPTH - 1 + PLAZA_MARGIN
	_ensure_chunks_loaded(world, min_x, max_x, min_z, max_z)

	var touched := {}

	# Flat plaza level: the tallest real terrain point under the whole
	# footprint (tower + plaza margin), so the base never sits on a slope.
	var base_y := 0
	for x in range(min_x, max_x + 1):
		for z in range(min_z, max_z + 1):
			base_y = maxi(base_y, world.height_at(x, z))

	# Plaza: a flat stone apron, filling from each column's own real
	# terrain height up to base_y -- nothing floats, nothing clips a hill.
	for x in range(min_x, max_x + 1):
		for z in range(min_z, max_z + 1):
			var h := world.height_at(x, z)
			for y in range(h, base_y + 1):
				_poke(world, x, y, z, Blocks.STONE, touched)

	# Tower shell: hollow walls only (a real building silhouette, not a
	# solid block) -- a grid of window gaps, and a door gap centered on
	# the south (plaza-facing) wall.
	var x0 := origin.x
	var z0 := origin.y
	var x1 := origin.x + TOWER_WIDTH - 1
	var z1 := origin.y + TOWER_DEPTH - 1
	var door_x := origin.x + TOWER_WIDTH / 2
	for floor_i in range(TOWER_HEIGHT):
		var y := base_y + 1 + floor_i
		for x in range(x0, x1 + 1):
			for z in range(z0, z1 + 1):
				var on_wall := x == x0 or x == x1 or z == z0 or z == z1
				if not on_wall:
					continue   # hollow interior
				var is_door := z == z0 and x == door_x and floor_i < 2
				var is_window := not is_door and floor_i % 3 in [1, 2] and (
					((x == x0 or x == x1) and z % 2 == 1) or
					((z == z0 or z == z1) and x % 2 == 1))
				_poke(world, x, y, z, Blocks.AIR if (is_door or is_window) else Blocks.STONE, touched)

	# Roof cap.
	var roof_y := base_y + 1 + TOWER_HEIGHT
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			_poke(world, x, roof_y, z, Blocks.STONE, touched)

	for cpos in touched:
		world.build_chunk_now(cpos)


static func _ensure_chunks_loaded(world: VoxelWorld, min_x: int, max_x: int, min_z: int, max_z: int) -> void:
	var touched := {}
	for x in [min_x, max_x]:
		for z in [min_z, max_z]:
			touched[world.chunk_coord_of(Vector3(x, 0, z))] = true
	for cpos in touched:
		world.update_chunks(cpos)
		world.build_chunk_now(cpos)


## The data-only half of world.set_block(): writes the voxel byte, the
## edits record (so it saves/loads and survives re-streaming), and
## chunk_max_y -- everything set_block() does except the per-call mesh
## rebuild (batched by the caller instead) and the torch-light hook.
static func _poke(world: VoxelWorld, wx: int, wy: int, wz: int, id: int, touched: Dictionary) -> void:
	if wy < 0 or wy >= VoxelWorld.HEIGHT:
		return
	var cpos := Vector2i(wx >> 4, wz >> 4)
	if not world.chunk_data.has(cpos):
		return
	var d: PackedByteArray = world.chunk_data[cpos]
	var i := (wx & 15) + VoxelWorld.SIZE * ((wz & 15) + VoxelWorld.SIZE * wy)
	d[i] = id
	world.chunk_data[cpos] = d
	if id != Blocks.AIR and wy > world.chunk_max_y[cpos]:
		world.chunk_max_y[cpos] = wy
	if not world.edits.has(cpos):
		world.edits[cpos] = {}
	world.edits[cpos][i] = id
	touched[cpos] = true
