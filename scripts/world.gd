class_name VoxelWorld
extends Node3D
## Owns all chunks. Streams them in around the player and answers
## "what block is at (x, y, z)?" for everyone else.

const SIZE := Chunk.SIZE
const HEIGHT := Chunk.HEIGHT

@export var world_seed := 1337
@export var view_radius := 8        # chunks loaded (drawn) in each direction
@export var collision_radius := 3   # chunks with collision in each direction
## How many chunk meshes may be building on worker threads at once.
var max_jobs := maxi(2, OS.get_processor_count() - 2)
## Main-thread work per frame is capped so streaming never causes a hitch.
var max_shapes_per_frame := 2      # collision shapes built (the expensive bit)
var max_dispatches_per_frame := 3  # chunks handed to threads


## One chunk's meshing work, handed to a worker thread. It owns
## snapshots of everything it needs, so it never touches the world.
class MeshJob extends RefCounted:
	var cpos: Vector2i
	var version: int
	var generation: int
	var data: PackedByteArray
	var max_y: int
	var tints: PackedColorArray
	var nb: Dictionary
	var mesh: ArrayMesh
	var task_id := -1
	var usec := 0

	func run() -> void:
		var t0 := Time.get_ticks_usec()
		mesh = Chunk.make_mesh(Chunk.build_arrays(data, max_y, tints, nb))
		usec = Time.get_ticks_usec() - t0


## One chunk's terrain generation, handed to a worker thread.
class GenJob extends RefCounted:
	var cpos: Vector2i
	var generation: int
	var gen: WorldGen
	var result: Array
	var task_id := -1

	func run() -> void:
		result = gen.fill_chunk(cpos)


const MAX_GEN_JOBS := 8
const GEN_LOOKAHEAD := 8   # start generating data for this many queued chunks ahead

var _jobs: Array[MeshJob] = []
var _gen_jobs := {}    # Vector2i -> GenJob
var _generation := 0   # bumped by reset_chunks() so in-flight jobs get dropped
var _collision_queue: Array[Vector2i] = []   # chunks that need a shape, nearest first

var gen: WorldGen
var chunk_data := {}    # Vector2i -> PackedByteArray (kept forever, so edits survive)
var chunk_max_y := {}   # Vector2i -> int
var chunk_tints := {}   # Vector2i -> PackedColorArray (grass color per column)
var chunk_props := {}   # Vector2i -> Array of {type, lx, lz, y, rot} (see WorldGen.fill_chunk)
## Every block the player changed: Vector2i chunk -> {block index: id}.
## Terrain is regenerated from the seed on load; only this diff is saved.
var edits := {}
# ---- torches ----
## Vector3i (world block pos) -> OmniLight3D, one per placed Torch block.
## Lives for the whole session once created, same as the torch edit
## itself — not tied to chunk streaming, so it doesn't need re-creating
## every time its chunk comes back into view.
var _torch_lights := {}
const TORCH_LIGHT_RANGE := 7.0
const TORCH_LIGHT_ENERGY := 1.4
const TORCH_LIGHT_COLOR := Color(1.0, 0.65, 0.32)
## Night hunters won't consider a spawn point this close to a lit torch.
const TORCH_HOSTILE_AVOID_RADIUS := 10.0
var chunks := {}        # Vector2i -> Chunk node (only the ones near the player)
var mesh_queue: Array[Vector2i] = []
var player: Node3D

var _last_player_chunk := Vector2i(1 << 20, 1 << 20)

# ---- perf counters (printed with `-- --perf`) ----
var perf_enabled := false
var _gen_usec := 0
var _gen_count := 0
var _mesh_usec := 0      # time spent in build_arrays (on worker threads)
var _mesh_count := 0
var _apply_usec := 0     # time spent putting meshes on nodes (main thread)
var _shape_usec := 0     # ...of which building collision shapes
var _apply_count := 0
var _worst_frame_usec := 0
var _worst_frame_note := ""
var _perf_frames := 0

# ---- environment props ----
## GLB decoration named in WorldGen.PROPS by these same keys.
const PROP_SCENES := {
	"rock_small": preload("res://blocky/models/rock_small.glb"),
	"boulder": preload("res://blocky/models/boulder.glb"),
	"grass_tuft": preload("res://blocky/models/grass_tuft.glb"),
	"flower_patch": preload("res://blocky/models/flower_patch.glb"),
	"mushroom_cluster": preload("res://blocky/models/mushroom_cluster.glb"),
}
## What breaking the block a prop stands on pops out, for the prop types
## that are worth picking up. Rocks/boulders/flowers are left alone for
## now — purely decorative, no item defined for them yet.
const PROP_DROP := {
	"mushroom_cluster": Blocks.MUSHROOM,
	"reeds": Blocks.REEDS,
	"grass_tuft": Blocks.TALL_GRASS,
}
var _props_placed := {}   # Vector2i -> true once a chunk's props are queued/instantiated
## World position (the block it rests on, +1 in y) -> instantiated prop
## node, so breaking that block can find and remove the prop standing on
## it instead of leaving it floating with nothing underneath.
var _prop_nodes := {}   # Vector3i -> Node3D
## Chunks whose props still need instantiating, budgeted a few per frame
## (see _process_prop_queue) so a burst of finished chunks at load time
## can't spike a frame the way an unthrottled loop over all of them would.
var _prop_queue: Array[Vector2i] = []
## Chunks' worth of props instantiated per frame.
var max_props_per_frame := 4

# ---- creatures ----
const MAX_CREATURES := 40
## Wildlife species that can be picked for a given spawn.
const WILDLIFE_SCENES := [
	preload("res://scenes/rabbit.tscn"),
	preload("res://scenes/deer.tscn"),
	preload("res://scenes/fox.tscn"),
	preload("res://scenes/boar.tscn"),
	preload("res://scenes/bird.tscn"),
]
## Relative spawn weight per [biome][species], same order as
## WILDLIFE_SCENES (rabbit, deer, fox, boar, bird); 0 = never shows up
## there. Overall density per biome is still SPAWN_CHANCE below — this
## only shapes which of the 5 you see once something does spawn.
const WILDLIFE_WEIGHTS := [
	[5, 3, 2, 1, 4],   # Plains: open field — a bit of everything
	[2, 4, 4, 3, 3],   # Forest: woodland animals, less open-field rabbit
	[3, 0, 1, 0, 2],   # Desert: only the hardy small ones
	[2, 1, 3, 0, 1],   # Tundra: foxes fare best in the cold, no boar
]
## Chance that a freshly built chunk gets a group of animals, per biome.
const SPAWN_CHANCE := [0.16, 0.12, 0.04, 0.1]   # Plains, Forest, Desert, Tundra
## Set by the `--species=name` testing aid (matched against each scene's
## file name) to force every wildlife spawn to one species; null = full pool.
var _forced_species: PackedScene = null
var _creatures := Node3D.new()
var _drops := Node3D.new()
var _populated := {}   # Vector2i -> true once a chunk has rolled for animals

# ---- hostiles (night only) ----
const MAX_HOSTILES := 6
## Night-hunter kinds that can be picked for a given spawn. Every entry
## gets an equal shot for now; the original box "Shade" is still in here.
const HOSTILE_SCENES := [
	preload("res://scenes/hostile.tscn"),
	preload("res://scenes/goblin.tscn"),
	preload("res://scenes/wisp.tscn"),
	preload("res://scenes/witch.tscn"),
]
const HOSTILE_SPAWN_SECONDS := 4.0
var day_night: DayNight   # set by main; hostiles need to know if it's night
var _hostiles := Node3D.new()
var _hostile_timer := 0.0
## Set by the `--hostile=name` testing aid (matched against each scene's
## file name) to force every hostile spawn to one kind; null = full pool.
var _forced_hostile: PackedScene = null


func _ready() -> void:
	gen = WorldGen.new(world_seed)
	_creatures.name = "Creatures"
	add_child(_creatures)
	_drops.name = "Drops"
	add_child(_drops)
	_hostiles.name = "Hostiles"
	add_child(_hostiles)
	# Testing aid: `-- --species=deer` forces every wildlife spawn to one kind.
	# `-- --hostile=goblin` does the same for night hunters.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--species="):
			var species_name := arg.get_slice("=", 1)
			for scene in WILDLIFE_SCENES:
				if scene.resource_path.get_file().get_basename() == species_name:
					_forced_species = scene
		elif arg.begins_with("--hostile="):
			var hostile_name := arg.get_slice("=", 1)
			for scene in HOSTILE_SCENES:
				if scene.resource_path.get_file().get_basename() == hostile_name:
					_forced_hostile = scene


## Worker tasks must never outlive the world: wait for them on the way out.
func _exit_tree() -> void:
	for job in _jobs:
		WorkerThreadPool.wait_for_task_completion(job.task_id)
	_jobs.clear()
	for cpos in _gen_jobs.keys():
		WorkerThreadPool.wait_for_task_completion(_gen_jobs[cpos].task_id)
	_gen_jobs.clear()


func _process(_delta: float) -> void:
	if player == null:
		return
	var frame_start := Time.get_ticks_usec()
	var pc := chunk_coord_of(player.global_position)
	if pc != _last_player_chunk:
		_last_player_chunk = pc
		update_chunks(pc)
	var t_update := Time.get_ticks_usec()

	_collect_gen_jobs()
	var shapes := _collect_finished_jobs(pc)
	var t_collect := Time.get_ticks_usec()
	shapes += _process_collision_queue(max_shapes_per_frame - shapes)
	var t_shapes := Time.get_ticks_usec()
	_process_prop_queue(max_props_per_frame)
	var t_props := Time.get_ticks_usec()
	var dispatched := _dispatch_jobs()
	var t_dispatch := Time.get_ticks_usec()

	_tick_hostile_spawns(_delta)

	if perf_enabled:
		var frame_usec := t_dispatch - frame_start
		if frame_usec > _worst_frame_usec:
			_worst_frame_usec = frame_usec
			_worst_frame_note = "update %.1f ms, applies %.1f ms, shapes(%d) %.1f ms, props %.1f ms, %d dispatches %.1f ms" % [
				(t_update - frame_start) / 1000.0, (t_collect - t_update) / 1000.0,
				shapes, (t_shapes - t_collect) / 1000.0,
				(t_props - t_shapes) / 1000.0,
				dispatched, (t_dispatch - t_props) / 1000.0]
		_perf_frames += 1
		if _perf_frames % 60 == 0:
			print_perf()


## Pulls results back from worker threads and turns them into meshes.
## Returns how many collision shapes were built (the capped cost).
func _collect_finished_jobs(pc: Vector2i) -> int:
	var shapes := 0
	for job in _jobs.duplicate():
		if not WorkerThreadPool.is_task_completed(job.task_id):
			continue
		var near := _is_near(job.cpos, pc, collision_radius)
		if near and shapes >= max_shapes_per_frame:
			continue   # leave it for next frame; the shape is the expensive part
		WorkerThreadPool.wait_for_task_completion(job.task_id)
		_jobs.erase(job)
		_mesh_usec += job.usec
		_mesh_count += 1
		# Drop results that are out of date.
		if job.generation != _generation or not chunks.has(job.cpos):
			continue
		var chunk: Chunk = chunks[job.cpos]
		if chunk.version != job.version:
			continue   # edited meanwhile; the edit already rebuilt it
		var t0 := Time.get_ticks_usec()
		chunk.collision_enabled = near
		chunk.apply_mesh(job.mesh)
		chunk.dirty = false
		_apply_usec += Time.get_ticks_usec() - t0
		_shape_usec += chunk.last_shape_usec
		_apply_count += 1
		# Props are pure decoration (no collision needed), so — unlike
		# animals — they don't wait on the near-only collision queue. They
		# still go through their own budgeted queue (_process_prop_queue),
		# since a burst of chunks finishing in the same frame could
		# otherwise spike it with GLB instantiation.
		_queue_props_if_new(job.cpos)
		if near:
			shapes += 1
			_populate_if_new(job.cpos)
	return shapes


## Adds collision to queued nearby chunks, a few per frame.
func _process_collision_queue(budget: int) -> int:
	var done := 0
	while done < budget and _collision_queue.size() > 0:
		var cpos: Vector2i = _collision_queue.pop_front()
		if not chunks.has(cpos) or chunks[cpos].dirty:
			continue   # no mesh yet; apply_mesh will add the shape when it lands
		var chunk: Chunk = chunks[cpos]
		chunk.set_collision_enabled(true)
		_shape_usec += chunk.last_shape_usec
		done += 1
		_populate_if_new(cpos)
	return done


## Once a chunk has ground you can stand on, roll for animals (once).
func _populate_if_new(cpos: Vector2i) -> void:
	if not _populated.has(cpos):
		_populated[cpos] = true
		_populate_chunk(cpos)


## Once a chunk's mesh exists, instantiate its rocks/grass/flowers/
## mushrooms/reeds right away (once) — WorldGen.fill_chunk already
## decided where. Used for single-chunk edits, where there's no burst
## of chunks to throttle against.
func _place_props_if_new(cpos: Vector2i) -> void:
	if _props_placed.has(cpos) or not chunks.has(cpos) or not chunk_props.has(cpos):
		return
	_props_placed[cpos] = true
	_instantiate_props(chunks[cpos], chunk_props[cpos])


## Same as _place_props_if_new, but queues the chunk instead of
## instantiating immediately — for the bulk-load path, where many
## chunks can finish meshing in the same frame.
func _queue_props_if_new(cpos: Vector2i) -> void:
	if _props_placed.has(cpos) or not chunk_props.has(cpos):
		return
	_props_placed[cpos] = true
	_prop_queue.append(cpos)


## Instantiates a few queued chunks' worth of props per frame.
func _process_prop_queue(budget: int) -> void:
	var done := 0
	while done < budget and _prop_queue.size() > 0:
		var cpos: Vector2i = _prop_queue.pop_front()
		if chunks.has(cpos) and chunk_props.has(cpos):
			_instantiate_props(chunks[cpos], chunk_props[cpos])
		done += 1


func _instantiate_props(chunk: Chunk, props: Array) -> void:
	for p in props:
		var scene: PackedScene = PROP_SCENES.get(p["type"])
		if scene == null:
			continue
		var inst: Node3D = scene.instantiate()
		chunk.add_child(inst)
		# Each environment prop is one block wide, so +0.5 centers it.
		inst.position = Vector3(p["lx"] + 0.5, p["y"], p["lz"] + 0.5)
		inst.rotation.y = p["rot"]
		var wpos := Vector3i(chunk.cpos.x * SIZE + int(p["lx"]), int(p["y"]),
			chunk.cpos.y * SIZE + int(p["lz"]))
		_prop_nodes[wpos] = inst


func _is_near(cpos: Vector2i, pc: Vector2i, radius: int) -> bool:
	var d := (cpos - pc).abs()
	return maxi(d.x, d.y) <= radius


## Hands queued chunks to worker threads while there are free slots.
## Returns how many were dispatched.
func _dispatch_jobs() -> int:
	# Look ahead: start generating block data for the next few chunks in
	# line (and their neighbours) so it's ready when their turn comes.
	for k in mini(GEN_LOOKAHEAD, mesh_queue.size()):
		var c: Vector2i = mesh_queue[k]
		_request_gen(c)
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			_request_gen(c + n)

	var dispatched := 0
	while _jobs.size() < max_jobs and mesh_queue.size() > 0 and dispatched < max_dispatches_per_frame:
		var cpos: Vector2i = mesh_queue[0]
		if not chunks.has(cpos) or not chunks[cpos].dirty:
			mesh_queue.pop_front()
			continue
		if not _data_ready(cpos):
			break   # still generating on a thread; try again next frame
		mesh_queue.pop_front()
		dispatched += 1
		var job := MeshJob.new()
		job.cpos = cpos
		job.version = chunks[cpos].version
		job.generation = _generation
		job.data = chunk_data[cpos]
		job.max_y = chunk_max_y[cpos]
		job.tints = chunk_tints[cpos]
		job.nb = chunks[cpos]._neighbour_snapshot()
		job.task_id = WorkerThreadPool.add_task(job.run)
		_jobs.append(job)
	return dispatched


## Does this chunk and its four neighbours have block data yet?
func _data_ready(cpos: Vector2i) -> bool:
	if not chunk_data.has(cpos):
		return false
	for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not chunk_data.has(cpos + n):
			return false
	return true


## Starts generating a chunk's data on a worker thread, if needed.
func _request_gen(cpos: Vector2i) -> void:
	if chunk_data.has(cpos) or _gen_jobs.has(cpos) or _gen_jobs.size() >= MAX_GEN_JOBS:
		return
	var job := GenJob.new()
	job.cpos = cpos
	job.generation = _generation
	job.gen = gen
	job.task_id = WorkerThreadPool.add_task(job.run)
	_gen_jobs[cpos] = job


func _collect_gen_jobs() -> void:
	for cpos in _gen_jobs.keys():
		var job: GenJob = _gen_jobs[cpos]
		if not WorkerThreadPool.is_task_completed(job.task_id):
			continue
		WorkerThreadPool.wait_for_task_completion(job.task_id)
		_gen_jobs.erase(cpos)
		if job.generation != _generation:
			continue
		_store_generated(cpos, job.result)
		_gen_count += 1


func print_perf() -> void:
	var gen_avg := (_gen_usec / 1000.0 / _gen_count) if _gen_count > 0 else 0.0
	var mesh_avg := (_mesh_usec / 1000.0 / _mesh_count) if _mesh_count > 0 else 0.0
	var apply_avg := (_apply_usec / 1000.0 / _apply_count) if _apply_count > 0 else 0.0
	var shape_avg := (_shape_usec / 1000.0 / _apply_count) if _apply_count > 0 else 0.0
	var with_collision := 0
	for c in chunks.values():
		if c.collision_enabled:
			with_collision += 1
	print("perf: radius %d | generated %d chunks (sync avg %.1f ms) | meshed %d on threads, avg %.1f ms | applied %d, avg %.1f ms (shape %.1f) | worst world frame %.1f ms (%s) | queue %d | in flight %d mesh / %d gen | loaded %d, %d with collision"
		% [view_radius, _gen_count, gen_avg, _mesh_count, mesh_avg, _apply_count, apply_avg, shape_avg,
			_worst_frame_usec / 1000.0, _worst_frame_note, mesh_queue.size(), _jobs.size(), _gen_jobs.size(),
			chunks.size(), with_collision])


# ---------------------------------------------------------------- lookups

func chunk_coord_of(world_pos: Vector3) -> Vector2i:
	# ">> 4" is integer division by 16 that also works for negatives.
	return Vector2i(int(floor(world_pos.x)) >> 4, int(floor(world_pos.z)) >> 4)


func height_at(x: int, z: int) -> int:
	return gen.height_at(x, z)


## Water belongs to a deterministic terrain table, not the voxel block grid.
## These queries work before a chunk is streamed and do not create collision
## or rendering.  A column whose generated ground reaches the surface is dry.
func water_surface_y_at(x: int, z: int) -> float:
	return gen.water_surface_y_at(x, z)


## Returns the vertical water remaining above this point, or zero when the
## point is on/above the surface, inside generated terrain, or in a dry column.
func water_depth_at(world_position: Vector3) -> float:
	var x := floori(world_position.x)
	var z := floori(world_position.z)
	var surface := water_surface_y_at(x, z)
	var ground_top := float(gen.height_at(x, z) + 1)
	# Surface callers commonly reuse the returned float. Allow a tiny epsilon so
	# float representation never classifies the exact surface as submerged.
	if ground_top >= surface or world_position.y < ground_top or world_position.y >= surface - 0.001:
		return 0.0
	return surface - world_position.y


func is_water_at(world_position: Vector3) -> bool:
	return water_depth_at(world_position) > 0.0


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
	var i := (wx & 15) + SIZE * ((wz & 15) + SIZE * wy)
	var old_id := d[i]
	d[i] = id
	chunk_data[cpos] = d
	if id != Blocks.AIR and wy > chunk_max_y[cpos]:
		chunk_max_y[cpos] = wy
	if not edits.has(cpos):
		edits[cpos] = {}
	edits[cpos][i] = id

	var pos := Vector3i(wx, wy, wz)
	if id == Blocks.TORCH and old_id != Blocks.TORCH:
		_add_torch_light(pos)
	elif old_id == Blocks.TORCH and id != Blocks.TORCH:
		_remove_torch_light(pos)

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

	if old_id != id:
		_remove_prop_above(wx, wy, wz, cpos)


## A prop (grass tuft, mushroom, reeds, ...) resting on this block loses
## its footing when the block underneath changes — remove it instead of
## leaving it floating with nothing underneath, and pop out an item for
## the prop types worth picking up (see PROP_DROP).
func _remove_prop_above(wx: int, wy: int, wz: int, cpos: Vector2i) -> void:
	var wpos := Vector3i(wx, wy + 1, wz)
	if not _prop_nodes.has(wpos):
		return
	var node: Node3D = _prop_nodes[wpos]
	_prop_nodes.erase(wpos)
	if is_instance_valid(node):
		node.queue_free()
	if not chunk_props.has(cpos):
		return
	var arr: Array = chunk_props[cpos]
	var lx := wx & 15
	var lz := wz & 15
	for i in arr.size():
		var p: Dictionary = arr[i]
		if int(p["lx"]) == lx and int(p["lz"]) == lz and int(p["y"]) == wy + 1:
			arr.remove_at(i)
			var drop_id: int = PROP_DROP.get(p["type"], -1)
			if drop_id != -1:
				spawn_drop(Vector3(wpos) + Vector3(0.5, 0.1, 0.5), drop_id)
			break


func _add_torch_light(pos: Vector3i) -> void:
	if _torch_lights.has(pos):
		return
	var light := OmniLight3D.new()
	light.light_color = TORCH_LIGHT_COLOR
	light.light_energy = TORCH_LIGHT_ENERGY
	light.omni_range = TORCH_LIGHT_RANGE
	add_child(light)
	light.global_position = Vector3(pos) + Vector3(0.5, 0.5, 0.5)
	_torch_lights[pos] = light


func _remove_torch_light(pos: Vector3i) -> void:
	var light: Node = _torch_lights.get(pos)
	if light != null:
		light.queue_free()
	_torch_lights.erase(pos)


## True if a lit torch is close enough that a night hunter shouldn't
## spawn here.
func _near_a_torch(pos: Vector3) -> bool:
	for p in _torch_lights:
		if Vector3(p).distance_to(pos) < TORCH_HOSTILE_AVOID_RADIUS:
			return true
	return false


# ---------------------------------------------------------------- streaming

## Make sure the block data for a chunk exists (generating it if needed).
func ensure_data(cpos: Vector2i) -> void:
	if chunk_data.has(cpos):
		return
	var t0 := Time.get_ticks_usec()
	var result := gen.fill_chunk(cpos)
	_gen_usec += Time.get_ticks_usec() - t0
	_gen_count += 1
	_store_generated(cpos, result)


## Keeps freshly generated chunk data, re-applying any saved edits.
func _store_generated(cpos: Vector2i, result: Array) -> void:
	if chunk_data.has(cpos):
		return   # generated twice (thread + sync path); first one wins
	var d: PackedByteArray = result[0]
	var max_y: int = result[1]
	# Re-apply anything the player changed here in an earlier session.
	if edits.has(cpos):
		for i in edits[cpos]:
			var id: int = edits[cpos][i]
			d[i] = id
			var idx := int(i)
			var y := idx / (SIZE * SIZE)
			if id != Blocks.AIR and y > max_y:
				max_y = y
			if id == Blocks.TORCH:
				var lx := idx % SIZE
				var lz := (idx / SIZE) % SIZE
				_add_torch_light(Vector3i(cpos.x * SIZE + lx, y, cpos.y * SIZE + lz))
	chunk_data[cpos] = d
	chunk_max_y[cpos] = max_y
	chunk_tints[cpos] = result[2]
	chunk_props[cpos] = result[3]


## Load chunks near the player, unload far ones.
func update_chunks(pc: Vector2i) -> void:
	for cpos in chunks.keys():
		var d: Vector2i = (cpos - pc).abs()
		if max(d.x, d.y) > view_radius + 2:
			chunks[cpos].queue_free()
			chunks.erase(cpos)
			_populated.erase(cpos)   # animals may return when you come back
			_props_placed.erase(cpos)   # re-instantiated (same layout) when you come back
			if chunk_props.has(cpos):
				for p in chunk_props[cpos]:
					_prop_nodes.erase(Vector3i(cpos.x * SIZE + int(p["lx"]), int(p["y"]),
						cpos.y * SIZE + int(p["lz"])))

	# Collision follows the player: nearby chunks get shapes (queued,
	# nearest first), far ones drop theirs.
	_collision_queue.clear()
	for cpos in chunks.keys():
		var chunk: Chunk = chunks[cpos]
		var near := _is_near(cpos, pc, collision_radius)
		if near and not chunk.collision_enabled:
			_collision_queue.append(cpos)
		elif not near and chunk.collision_enabled:
			chunk.set_collision_enabled(false)
	_collision_queue.sort_custom(func(a, b): return (a - pc).length_squared() < (b - pc).length_squared())

	# Animals outside the collision area would fall through the world,
	# so they freeze in place until you come back. Far ones are removed.
	var freeze_dist := float(collision_radius * SIZE)
	var despawn_dist := float((view_radius + 2) * SIZE)
	for c in _creatures.get_children() + _hostiles.get_children():
		var dist: float = c.global_position.distance_to(player.global_position)
		if dist > despawn_dist:
			c.queue_free()
		else:
			c.set_physics_process(dist <= freeze_dist)
	for d in _drops.get_children():
		if d.global_position.distance_to(player.global_position) > despawn_dist:
			d.queue_free()

	var wanted: Array[Vector2i] = []
	for dz in range(-view_radius, view_radius + 1):
		for dx in range(-view_radius, view_radius + 1):
			wanted.append(pc + Vector2i(dx, dz))
	# Nearest chunks first, so the ground under your feet appears first.
	wanted.sort_custom(func(a, b): return (a - pc).length_squared() < (b - pc).length_squared())

	for cpos in wanted:
		if chunks.has(cpos):
			continue
		# Block data is generated later, just before the chunk is meshed,
		# so a big move doesn't generate hundreds of chunks in one frame.
		var chunk := Chunk.new()
		chunk.setup(self, cpos)
		add_child(chunk)
		chunks[cpos] = chunk
		mesh_queue.append(cpos)


## Neighbour data must exist so edge faces cull correctly.
func _ensure_data_with_neighbours(cpos: Vector2i) -> void:
	ensure_data(cpos)
	for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		ensure_data(cpos + n)


## Build one chunk's mesh right now (on this thread) instead of waiting
## for the worker threads. Used for edits, where a delay would feel laggy.
func _rebuild_now(cpos: Vector2i) -> void:
	if chunks.has(cpos):
		_ensure_data_with_neighbours(cpos)
		var chunk: Chunk = chunks[cpos]
		chunk.version += 1
		# Anything you can edit is next to you, so it needs collision.
		chunk.collision_enabled = true
		chunk.build_mesh()
		_place_props_if_new(cpos)
		_populate_if_new(cpos)


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
	if get_block(wx, h + 1, wz) != Blocks.AIR or get_block(wx, h + 2, wz) != Blocks.AIR:
		return null   # something (a tree?) is in the way
	return spawn_creature_at(Vector3(wx + 0.5, h + 1.5, wz + 0.5))


## Puts one animal at an exact position, no questions asked (tests use this).
func spawn_creature_at(pos: Vector3) -> Creature:
	var biome := gen.biome_at(int(floor(pos.x)), int(floor(pos.z)))
	var scene: PackedScene = _forced_species if _forced_species != null else _pick_wildlife(biome)
	var c: Creature = scene.instantiate()
	c.world = self
	_creatures.add_child(c)
	c.global_position = pos
	return c


## Weighted random pick from WILDLIFE_WEIGHTS[biome].
func _pick_wildlife(biome: int) -> PackedScene:
	var weights: Array = WILDLIFE_WEIGHTS[biome]
	var total := 0
	for w in weights:
		total += int(w)
	var roll := randi_range(1, total)
	var acc := 0
	for i in weights.size():
		acc += int(weights[i])
		if roll <= acc:
			return WILDLIFE_SCENES[i]
	return WILDLIFE_SCENES[0]   # unreachable; keeps the return type honest


func creature_count() -> int:
	return _creatures.get_child_count()


## At night, every few seconds, a Shade appears somewhere out of sight.
func _tick_hostile_spawns(delta: float) -> void:
	if day_night == null or day_night.sun_elevation() > -0.1 or get_tree().paused:
		return
	_hostile_timer += delta
	if _hostile_timer < HOSTILE_SPAWN_SECONDS:
		return
	_hostile_timer = 0.0
	if _hostiles.get_child_count() >= MAX_HOSTILES:
		return
	var angle := randf() * TAU
	var dist := randf_range(14.0, 26.0)
	var wx := int(floor(player.global_position.x + cos(angle) * dist))
	var wz := int(floor(player.global_position.z + sin(angle) * dist))
	var h := gen.height_at(wx, wz)
	if get_block(wx, h + 1, wz) != Blocks.AIR or get_block(wx, h + 2, wz) != Blocks.AIR:
		return
	var spawn_pos := Vector3(wx + 0.5, h + 1.5, wz + 0.5)
	if _near_a_torch(spawn_pos):
		return   # shelter: a lit torch keeps night hunters from spawning this close
	spawn_hostile_at(spawn_pos)


func spawn_hostile_at(pos: Vector3) -> Hostile:
	var scene: PackedScene = _forced_hostile if _forced_hostile != null else HOSTILE_SCENES[randi() % HOSTILE_SCENES.size()]
	var s: Hostile = scene.instantiate()
	s.world = self
	_hostiles.add_child(s)
	s.global_position = pos
	return s


func hostile_count() -> int:
	return _hostiles.get_child_count()


## True if any live hostile is within `radius` blocks of `pos` — used to
## block sleeping with a monster nearby (see main._try_sleep).
func hostile_near(pos: Vector3, radius: float) -> bool:
	for c in _hostiles.get_children():
		if c is Node3D and c.global_position.distance_to(pos) <= radius:
			return true
	return false


## Removes every creature, drop and hostile (New Game).
func clear_entities() -> void:
	for group in [_creatures, _drops, _hostiles]:
		for c in group.get_children():
			c.queue_free()
	_populated.clear()


## Leaves an item on the ground at a world position.
func spawn_drop(pos: Vector3, item_id: int) -> Drop:
	var d := Drop.new()
	d.item_id = item_id
	d.player = player
	_drops.add_child(d)
	d.global_position = pos
	return d


func drop_count() -> int:
	return _drops.get_child_count()


# ---------------------------------------------------------------- saving

func get_save_data() -> Dictionary:
	var e := {}
	for cpos in edits.keys():
		var inner := {}
		for i in edits[cpos].keys():
			inner[str(i)] = edits[cpos][i]
		e["%d,%d" % [cpos.x, cpos.y]] = inner
	return {"seed": world_seed, "edits": e}


## Restores the seed and edits, then throws away every generated chunk
## so they come back with the edits applied.
func load_save_data(d: Dictionary) -> void:
	world_seed = int(d.get("seed", world_seed))
	gen = WorldGen.new(world_seed)
	edits.clear()
	var e: Dictionary = d.get("edits", {})
	for key in e.keys():
		var parts: PackedStringArray = key.split(",")
		var cpos := Vector2i(int(parts[0]), int(parts[1]))
		var inner := {}
		for k in e[key].keys():
			inner[int(k)] = int(e[key][k])
		edits[cpos] = inner
	reset_chunks()


## Forgets all generated chunks and meshes; they regenerate on demand.
func reset_chunks() -> void:
	_generation += 1   # any mesh job still running belongs to the old world
	for c in chunks.values():
		c.queue_free()
	chunks.clear()
	chunk_data.clear()
	chunk_max_y.clear()
	chunk_tints.clear()
	chunk_props.clear()
	mesh_queue.clear()
	_collision_queue.clear()
	_populated.clear()
	_props_placed.clear()
	_prop_nodes.clear()
	for light in _torch_lights.values():
		light.queue_free()
	_torch_lights.clear()
	_last_player_chunk = Vector2i(1 << 20, 1 << 20)
