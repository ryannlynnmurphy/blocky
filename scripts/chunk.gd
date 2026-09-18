class_name Chunk
extends StaticBody3D
## One 16x64x16 column of the world, turned into a single mesh.
##
## This is the core trick of every voxel game: we do NOT draw 16,000 cubes.
## We walk through the blocks, and for each solid block we only emit the
## faces that touch air. A face buried between two solid blocks can never
## be seen, so we skip it. The result is one mesh per chunk.
##
## Performance notes (this is the hottest code in the game):
## - Blocks live in a flat PackedByteArray. A neighbour is just the same
##   index plus a fixed stride, so checking "is the block above me air?"
##   is one array read with no function call.
## - Most blocks are buried (stone under the surface). One combined test
##   throws them out before any per-face work.
## - Every face is a quad with the same 6-index pattern, so indices come
##   from a precomputed table sliced to size instead of being appended.

const SIZE := 16
const HEIGHT := 64
const STRIDE_X := 1
const STRIDE_Z := SIZE
const STRIDE_Y := SIZE * SIZE

## The 6 directions a face can point, and the 4 corners of that face.
## Corners are listed counter-clockwise when viewed from outside the block.
const FACES := [
	[Vector3(1, 0, 0),  [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)]],   # 0 +X
	[Vector3(-1, 0, 0), [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)]],   # 1 -X
	[Vector3(0, 1, 0),  [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]],   # 2 +Y top
	[Vector3(0, -1, 0), [Vector3(0, 0, 1), Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)]],   # 3 -Y bottom
	[Vector3(0, 0, 1),  [Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 0, 1)]],   # 4 +Z
	[Vector3(0, 0, -1), [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)]],   # 5 -Z
]

## One material shared by every chunk. Colors come from the vertices.
static var MATERIAL: StandardMaterial3D = _make_material()
## FACE_COLORS[block id][face] -> Color, built once.
static var FACE_COLORS: Array = _make_face_colors()
## Index pattern for N quads, built once and sliced per chunk.
static var INDEX_TABLE: PackedInt32Array = _make_index_table(24000)

var world              # the VoxelWorld that owns us (untyped to avoid a script cycle)
var cpos: Vector2i     # which chunk we are, in chunk units
var dirty := true      # true = mesh needs (re)building

var _mesh_instance := MeshInstance3D.new()
var _collision := CollisionShape3D.new()


static func _make_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	return m


static func _make_face_colors() -> Array:
	var table := []
	for id in Blocks.NAMES.size():
		var row := []
		for f in 6:
			row.append(Blocks.face_color(id, f) if Blocks.COLORS.has(id) else Color.MAGENTA)
		table.append(row)
	return table


static func _make_index_table(quads: int) -> PackedInt32Array:
	var t := PackedInt32Array()
	t.resize(quads * 6)
	for q in quads:
		var b := q * 4
		var o := q * 6
		# Godot wants front faces wound clockwise; corners are CCW, so reverse.
		t[o] = b
		t[o + 1] = b + 2
		t[o + 2] = b + 1
		t[o + 3] = b
		t[o + 4] = b + 3
		t[o + 5] = b + 2
	return t


func setup(owner_world, chunk_pos: Vector2i) -> void:
	world = owner_world
	cpos = chunk_pos
	position = Vector3(cpos.x * SIZE, 0, cpos.y * SIZE)
	add_child(_mesh_instance)
	add_child(_collision)


## Rebuilds the mesh and the collision shape from the block data.
func build_mesh() -> void:
	dirty = false
	var result := build_arrays(
		world.chunk_data[cpos], world.chunk_max_y[cpos], world.chunk_tints[cpos],
		_neighbour_snapshot())
	apply_arrays(result)


## The four neighbouring chunks' block data, so edge faces cull correctly.
func _neighbour_snapshot() -> Dictionary:
	var nb := {}
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = cpos + d
		if world.chunk_data.has(n):
			nb[d] = world.chunk_data[n]
	return nb


## Turns the arrays into a mesh + collision shape on this node.
func apply_arrays(result: Dictionary) -> void:
	var mesh := ArrayMesh.new()
	var verts: PackedVector3Array = result["verts"]
	if verts.size() > 0:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = result["normals"]
		arrays[Mesh.ARRAY_COLOR] = result["colors"]
		arrays[Mesh.ARRAY_INDEX] = result["indices"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, MATERIAL)
		_collision.shape = mesh.create_trimesh_shape()
	else:
		_collision.shape = null
	_mesh_instance.mesh = mesh


## Pure function: block data in, mesh arrays out. Touches no nodes, so it
## can run on any thread. `nb` maps a direction (Vector2i) to that
## neighbour chunk's data; a missing neighbour counts as air.
static func build_arrays(data: PackedByteArray, max_y: int, tints: PackedColorArray,
		nb: Dictionary) -> Dictionary:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var quads := 0

	var leaf_tints := PackedColorArray()
	leaf_tints.resize(SIZE * SIZE)
	for i in SIZE * SIZE:
		leaf_tints[i] = tints[i].darkened(0.25)

	var nb_px: PackedByteArray = nb.get(Vector2i(1, 0), PackedByteArray())
	var nb_nx: PackedByteArray = nb.get(Vector2i(-1, 0), PackedByteArray())
	var nb_pz: PackedByteArray = nb.get(Vector2i(0, 1), PackedByteArray())
	var nb_nz: PackedByteArray = nb.get(Vector2i(0, -1), PackedByteArray())
	var top := mini(max_y, HEIGHT - 1)

	for y in range(0, top + 1):
		var y_off := y * STRIDE_Y
		for z in SIZE:
			var zy_off := y_off + z * STRIDE_Z
			for x in SIZE:
				var i := zy_off + x
				var id := data[i]
				if id == 0:
					continue

				# Which of the six neighbours is open (air or off the edge)?
				# Inside the chunk this is a plain array read; on the edge
				# we look into the neighbour chunk's data.
				var open_px: bool
				var open_nx: bool
				var open_pz: bool
				var open_nz: bool
				if x < SIZE - 1:
					open_px = data[i + STRIDE_X] == 0
				else:
					open_px = nb_px.is_empty() or nb_px[i - (SIZE - 1)] == 0
				if x > 0:
					open_nx = data[i - STRIDE_X] == 0
				else:
					open_nx = nb_nx.is_empty() or nb_nx[i + (SIZE - 1)] == 0
				if z < SIZE - 1:
					open_pz = data[i + STRIDE_Z] == 0
				else:
					open_pz = nb_pz.is_empty() or nb_pz[i - (SIZE - 1) * STRIDE_Z] == 0
				if z > 0:
					open_nz = data[i - STRIDE_Z] == 0
				else:
					open_nz = nb_nz.is_empty() or nb_nz[i + (SIZE - 1) * STRIDE_Z] == 0
				var open_py := y == HEIGHT - 1 or data[i + STRIDE_Y] == 0
				var open_ny := y > 0 and data[i - STRIDE_Y] == 0   # never draw the world's underside

				if not (open_px or open_nx or open_py or open_ny or open_pz or open_nz):
					continue   # fully buried

				var origin := Vector3(x, y, z)
				var row: Array = FACE_COLORS[id]
				var col_idx := x + SIZE * z
				if open_px:
					_emit(verts, normals, colors, origin, 0,
						leaf_tints[col_idx] if id == Blocks.LEAVES else row[0])
					quads += 1
				if open_nx:
					_emit(verts, normals, colors, origin, 1,
						leaf_tints[col_idx] if id == Blocks.LEAVES else row[1])
					quads += 1
				if open_py:
					var top_col: Color
					if id == Blocks.GRASS:
						top_col = tints[col_idx]
					elif id == Blocks.LEAVES:
						top_col = leaf_tints[col_idx]
					else:
						top_col = row[2]
					_emit(verts, normals, colors, origin, 2, top_col)
					quads += 1
				if open_ny:
					_emit(verts, normals, colors, origin, 3,
						leaf_tints[col_idx] if id == Blocks.LEAVES else row[3])
					quads += 1
				if open_pz:
					_emit(verts, normals, colors, origin, 4,
						leaf_tints[col_idx] if id == Blocks.LEAVES else row[4])
					quads += 1
				if open_nz:
					_emit(verts, normals, colors, origin, 5,
						leaf_tints[col_idx] if id == Blocks.LEAVES else row[5])
					quads += 1

	var indices: PackedInt32Array
	if quads * 6 <= INDEX_TABLE.size():
		indices = INDEX_TABLE.slice(0, quads * 6)
	else:
		indices = _make_index_table(quads)   # absurdly detailed chunk; build ad hoc
	return {"verts": verts, "normals": normals, "colors": colors, "indices": indices}


## Appends one quad (4 vertices) for face f of the block at origin.
static func _emit(verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, origin: Vector3, f: int, col: Color) -> void:
	var n: Vector3 = FACES[f][0]
	var corners: Array = FACES[f][1]
	verts.append(origin + corners[0])
	verts.append(origin + corners[1])
	verts.append(origin + corners[2])
	verts.append(origin + corners[3])
	normals.append(n)
	normals.append(n)
	normals.append(n)
	normals.append(n)
	colors.append(col)
	colors.append(col)
	colors.append(col)
	colors.append(col)
