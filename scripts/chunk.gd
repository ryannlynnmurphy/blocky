class_name Chunk
extends StaticBody3D
## One 16x64x16 column of the world, turned into a single mesh.
##
## This is the core trick of every voxel game: we do NOT draw 16,000 cubes.
## We walk through the blocks, and for each solid block we only emit the
## faces that touch air. A face buried between two solid blocks can never
## be seen, so we skip it. The result is one mesh per chunk.

const SIZE := 16
const HEIGHT := 64

## The 6 directions a face can point, and the 4 corners of that face.
## Corners are listed counter-clockwise when viewed from outside the block.
const FACES := [
	[Vector3(1, 0, 0),  [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)]],   # +X
	[Vector3(-1, 0, 0), [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)]],   # -X
	[Vector3(0, 1, 0),  [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]],   # +Y top
	[Vector3(0, -1, 0), [Vector3(0, 0, 1), Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)]],   # -Y bottom
	[Vector3(0, 0, 1),  [Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 0, 1)]],   # +Z
	[Vector3(0, 0, -1), [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)]],   # -Z
]

## One material shared by every chunk. Colors come from the vertices.
static var MATERIAL: StandardMaterial3D = _make_material()

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


func setup(owner_world, chunk_pos: Vector2i) -> void:
	world = owner_world
	cpos = chunk_pos
	position = Vector3(cpos.x * SIZE, 0, cpos.y * SIZE)
	add_child(_mesh_instance)
	add_child(_collision)


## Rebuilds the mesh and the collision shape from the block data.
func build_mesh() -> void:
	dirty = false
	var data: PackedByteArray = world.chunk_data[cpos]
	var max_y: int = world.chunk_max_y[cpos]
	var tints: PackedColorArray = world.chunk_tints[cpos]

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var vi := 0

	for y in range(0, max_y + 1):
		for z in SIZE:
			for x in SIZE:
				var id := data[x + SIZE * (z + SIZE * y)]
				if id == Blocks.AIR:
					continue
				var origin := Vector3(x, y, z)
				for f in 6:
					var n: Vector3 = FACES[f][0]
					if _is_covered(data, x + int(n.x), y + int(n.y), z + int(n.z)):
						continue
					# Grass tops and leaves take the biome tint of their column.
					var col: Color
					if id == Blocks.GRASS and f == 2:
						col = tints[x + SIZE * z]
					elif id == Blocks.LEAVES:
						col = tints[x + SIZE * z].darkened(0.25)
					else:
						col = Blocks.face_color(id, f)
					var corners: Array = FACES[f][1]
					for c in 4:
						verts.append(origin + corners[c])
						normals.append(n)
						colors.append(col)
					# Two triangles per face. Godot wants front faces wound
					# clockwise, so we reverse the counter-clockwise corners.
					indices.append_array([vi, vi + 2, vi + 1, vi, vi + 3, vi + 2])
					vi += 4

	var mesh := ArrayMesh.new()
	if verts.size() > 0:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, MATERIAL)
		_collision.shape = mesh.create_trimesh_shape()
	else:
		_collision.shape = null
	_mesh_instance.mesh = mesh


## Is the block at local (x, y, z) solid? Looks into neighbour chunks
## when the position is outside this one.
func _is_covered(data: PackedByteArray, x: int, y: int, z: int) -> bool:
	if y < 0:
		return true    # bottom of the world: never draw the underside
	if y >= HEIGHT:
		return false
	if x >= 0 and x < SIZE and z >= 0 and z < SIZE:
		return data[x + SIZE * (z + SIZE * y)] != Blocks.AIR
	return world.get_block(cpos.x * SIZE + x, y, cpos.y * SIZE + z) != Blocks.AIR
