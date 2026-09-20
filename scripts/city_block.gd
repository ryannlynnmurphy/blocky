class_name CityBlock
extends Node3D
## Layer 4 (B1): Hollowmark's first city block — a small, dense street with
## the five locations B0 named in docs/lab/CITY_BLOCK_LAYOUT.md (apartment,
## street, park, cafe, workplace).
##
## Deliberately self-contained and NOT wired into main.gd's state machine —
## that integration is B5's job, a separate future card. This scene has its
## own flat/paved ground (not the procedural voxel terrain) and builds
## itself entirely from code in _ready(), the same "generate the mesh, don't
## hand-author it" approach scripts/chunk.gd uses for the voxel world. That
## keeps the layout tunable without hand-editing a large .tscn.
##
## Every walkable/solid surface gets real collision (StaticBody3D +
## CollisionShape3D): the ground slab, every building shell, and every
## placed prop (collision box sized from the prop's own mesh AABB). That is
## B1's literal acceptance check — "player can traverse the block" — and is
## verified standalone by tools/city_block_check.gd, since this scene isn't
## reachable through the existing --selftest flow yet.
##
## Assets: block textures load directly from blocky/city/textures/blocks/
## and props come from CityRenderPack (scripts/city_render_pack.gd). Every
## path used here is in docs/lab/CITY_ASSET_MANIFEST.md (B2). The three
## content-boundary-excluded models (police_car, pistol_prop, rifle_prop)
## are never referenced.

const TEX_DIR := "res://blocky/city/textures/blocks/"

## Where each B0 location's building/area is centered, exposed for later
## cards (B3 interiors, B4 nav path) so they don't have to re-derive layout
## coordinates by reading this whole file.
var location_positions := {}

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260920
	_build_ground()
	_build_street_and_sidewalks()
	_build_park()
	_build_apartment()
	_build_cafe()
	_build_workplace()
	_build_street_furniture()
	_build_overview_camera()


## A dev-only overview camera so this standalone scene always has something
## sensible to render (screenshots, tools/city_block_check.gd) without
## needing main.gd's player camera. Not meant to survive B5's integration —
## whoever wires the city into real play will use the player's own camera
## instead, same as scenes/main.tscn does.
func _build_overview_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "OverviewCamera"
	cam.position = Vector3(0.0, 30.0, -26.0)
	cam.fov = 60.0
	add_child(cam)
	cam.look_at(Vector3(0.0, 0.0, 4.0), Vector3.UP)
	cam.current = true


# --------------------------------------------------------------- materials

static func _texture(name: String) -> Texture2D:
	return load(TEX_DIR + name + ".png")


static func _material(tex_name: String, tile: Vector2 = Vector2(1, 1)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _texture(tex_name)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_scale = Vector3(tile.x, tile.y, 1.0)
	m.roughness = 1.0
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


static func _flat_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


# ------------------------------------------------------------- primitives

## A solid box: visual mesh + matching collision, both `size` in world units,
## centered at `center`. Used for the ground slab and every building shell.
func _add_solid_box(name: String, center: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = center
	add_child(body)

	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	body.add_child(mi)

	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	return body


## A visual-only box (no collision) for thin overlay dressing — pavement
## strips, door/window decals, roofs, sign boards — that sits on a surface
## already covered by another collider (usually the ground slab).
func _add_visual_box(name: String, center: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.position = center
	mi.mesh = mesh
	mi.material_override = material
	add_child(mi)
	return mi


func _add_label(text: String, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 56
	l.outline_size = 10
	l.no_depth_test = false
	l.pixel_size = 0.008
	l.modulate = Color(1.0, 0.97, 0.9)
	add_child(l)
	return l


## A sign_board plaque plus a Label3D naming the location, mounted above a
## building's front face.
func _add_sign(display_name: String, pos: Vector3) -> void:
	_add_visual_box("Sign_" + display_name, pos, Vector3(1.8, 0.6, 0.08),
		_material("sign_board"))
	_add_label(display_name, pos + Vector3(0, 0.55, 0))


## Instances a CityRenderPack prop, wraps it in a collision box sized from
## its own mesh AABB (so collision roughly matches whatever the model's
## actual footprint is, without hand-guessed dimensions per prop), and
## places it at `pos` with an optional Y rotation.
func _add_prop(id: String, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Prop_" + id
	holder.position = pos
	holder.rotation.y = rot_y
	add_child(holder)

	var visual := CityRenderPack.instantiate_prop(id)
	holder.add_child(visual)

	var aabb := _prop_aabb(visual)
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	# Guard against a degenerate/empty AABB (e.g. an unexpected import
	# shape) so a prop can never end up with zero-size, useless collision.
	shape.size = Vector3(max(aabb.size.x, 0.2), max(aabb.size.y, 0.2), max(aabb.size.z, 0.2))
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = aabb.get_center()
	body.add_child(cs)
	holder.add_child(body)
	return holder


static func _prop_aabb(visual: Node3D) -> AABB:
	if visual is MeshInstance3D and (visual as MeshInstance3D).mesh:
		return (visual as MeshInstance3D).mesh.get_aabb()
	for child in visual.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh:
			return (child as MeshInstance3D).mesh.get_aabb()
	return AABB(Vector3(-0.3, 0.0, -0.3), Vector3(0.6, 1.0, 0.6))


# ------------------------------------------------------------------ ground

## One continuous walkable slab under the whole block. Street/sidewalk/park
## textures are thin non-colliding overlays on top of it, so there is never
## a seam or gap in collision between them.
func _build_ground() -> void:
	_add_solid_box("Ground", Vector3(0.0, -0.2, 2.0), Vector3(60.0, 0.4, 34.0),
		_material("cobblestone", Vector2(60, 34)))


func _build_street_and_sidewalks() -> void:
	_add_visual_box("Street", Vector3(0.0, 0.02, 0.0), Vector3(46.0, 0.06, 6.0),
		_material("cobble_road", Vector2(46, 6)))
	_add_visual_box("SidewalkSouth", Vector3(0.0, 0.015, -4.25), Vector3(46.0, 0.05, 2.5),
		_material("flagstone", Vector2(46, 2.5)))
	_add_visual_box("SidewalkNorth", Vector3(0.0, 0.015, 4.25), Vector3(46.0, 0.05, 2.5),
		_material("flagstone", Vector2(46, 2.5)))
	location_positions["street"] = Vector3(0.0, 0.0, 0.0)


func _build_park() -> void:
	var center := Vector3(0.0, 0.015, 11.5)
	_add_visual_box("Park", center, Vector3(28.0, 0.05, 12.0), _flat_material(Color(0.36, 0.58, 0.28)))
	_add_visual_box("ParkPath", center, Vector3(3.0, 0.06, 12.0), _material("cobblestone", Vector2(3, 12)))
	_add_sign("Hollowmark Park", center + Vector3(-9.0, 1.4, -5.5))
	location_positions["park"] = center


# ---------------------------------------------------------------- shells

## The apartment (home, private, one entrance) gets a real assembled door
## from the four door_* textures — the only building that gets one, since
## it's the location B0 calls out as the private single-entrance one.
func _build_apartment() -> void:
	var center := Vector3(-16.0, 0.0, -8.5)
	var size := Vector3(8.0, 4.0, 6.0)
	_add_solid_box("Apartment", center + Vector3(0, size.y * 0.5, 0), size,
		_material("brick", Vector2(size.x, size.y)))
	_add_visual_box("ApartmentRoof", center + Vector3(0, size.y + 0.2, 0), Vector3(8.8, 0.4, 6.8),
		_material("roof_tile", Vector2(8.8, 6.8)))

	var front_z := center.z + size.z * 0.5 + 0.03
	_add_visual_box("ApartmentDoorLower", Vector3(center.x, 0.55, front_z), Vector3(0.9, 1.1, 0.06),
		_material("door_lower"))
	_add_visual_box("ApartmentDoorUpper", Vector3(center.x, 1.65, front_z), Vector3(0.9, 1.1, 0.06),
		_material("door_upper"))
	_add_visual_box("ApartmentDoorFrameL", Vector3(center.x - 0.55, 1.1, front_z), Vector3(0.15, 2.2, 0.07),
		_material("door_frame"))
	_add_visual_box("ApartmentDoorFrameR", Vector3(center.x + 0.55, 1.1, front_z), Vector3(0.15, 2.2, 0.07),
		_material("door_side"))

	_add_sign("The Player's Apartment", Vector3(center.x, size.y + 0.9, front_z))
	location_positions["apartment"] = Vector3(center.x, 0.0, front_z + 1.0)


func _build_cafe() -> void:
	var center := Vector3(0.0, 0.0, -8.5)
	var size := Vector3(8.0, 3.6, 6.0)
	_add_solid_box("Cafe", center + Vector3(0, size.y * 0.5, 0), size,
		_material("plaster", Vector2(size.x, size.y)))
	_add_visual_box("CafeRoof", center + Vector3(0, size.y + 0.2, 0), Vector3(8.8, 0.4, 6.8),
		_material("roof_tile", Vector2(8.8, 6.8)))

	var front_z := center.z + size.z * 0.5 + 0.03
	_add_visual_box("CafeWindow", Vector3(center.x, 1.8, front_z), Vector3(4.0, 1.8, 0.06),
		_material("shop_window", Vector2(4, 1.8)))
	# Café's outdoor deck: tavern_floor re-purposed as decking, not a tavern
	# floor (see CITY_ASSET_MANIFEST.md's README-mismatch note).
	_add_visual_box("CafeDeck", Vector3(center.x, 0.02, front_z + 1.1), Vector3(6.0, 0.05, 2.2),
		_material("tavern_floor", Vector2(6, 2.2)))

	_add_sign("The Corner Cafe", Vector3(center.x, size.y + 0.9, front_z))
	location_positions["cafe"] = Vector3(center.x, 0.0, front_z + 1.0)

	_add_prop("imbiss", Vector3(center.x + size.x * 0.5 + 1.4, 0.0, front_z + 0.6))
	_add_prop("bench", Vector3(center.x - size.x * 0.5 - 1.2, 0.0, front_z + 0.6), PI * 0.5)


func _build_workplace() -> void:
	var center := Vector3(16.0, 0.0, -8.5)
	var size := Vector3(9.0, 4.2, 6.0)
	_add_solid_box("Workplace", center + Vector3(0, size.y * 0.5, 0), size,
		_material("brick", Vector2(size.x, size.y)))
	_add_visual_box("WorkplaceRoof", center + Vector3(0, size.y + 0.2, 0), Vector3(9.8, 0.4, 6.8),
		_material("slate_roof", Vector2(9.8, 6.8)))

	var front_z := center.z + size.z * 0.5 + 0.03
	_add_visual_box("WorkplaceWindow", Vector3(center.x, 1.9, front_z), Vector3(4.4, 1.6, 0.06),
		_material("shop_window", Vector2(4.4, 1.6)))

	_add_sign("Hollowmark Workshop", Vector3(center.x, size.y + 0.9, front_z))
	location_positions["workplace"] = Vector3(center.x, 0.0, front_z + 1.0)

	_add_prop("vending_machine", Vector3(center.x - size.x * 0.5 - 1.0, 0.0, front_z - 0.2))
	_add_prop("dumpster", Vector3(center.x + 2.0, 0.0, center.z - size.z * 0.5 - 1.5))
	_add_prop("box_van", Vector3(center.x + 4.0, 0.0, -3.3))
	_add_visual_box("WorkplaceCrates", Vector3(center.x - size.x * 0.5 - 1.0, 0.35, front_z - 1.6),
		Vector3(0.8, 0.7, 0.8), _material("crate"))


# ---------------------------------------------------------- street dressing

func _build_street_furniture() -> void:
	for x in [-20.0, -6.0, 6.0, 20.0]:
		_add_prop("street_lamp", Vector3(x, 0.0, -4.25))
	_add_prop("fire_hydrant", Vector3(-12.0, 0.0, -3.4))
	_add_prop("traffic_light", Vector3(6.0, 0.0, 3.4))
	_add_prop("bus_stop", Vector3(18.0, 0.0, 4.6), PI)
	_add_prop("market_stall", Vector3(-6.0, 0.0, 6.2))
	_add_prop("hot_dog_cart", Vector3(6.0, 0.0, 10.0))
	_add_prop("bench", Vector3(-8.0, 0.0, 9.0))
	_add_prop("bench", Vector3(8.0, 0.0, 13.0))
	_add_prop("sedan", Vector3(-10.0, 0.0, -3.3), PI * 0.5)
	_add_prop("taxi", Vector3(10.0, 0.0, 3.3), PI * 0.5)
