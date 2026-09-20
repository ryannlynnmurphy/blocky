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
##
## 2026-09-20, ahead of B5: reachable directly from the title screen
## ("Visit Hollowmark (preview)", scripts/screens.gd) via a full
## get_tree().change_scene_to_file() swap, at Ryann's direct request to be
## able to walk around it -- NOT the formal B5 integration. spawn_walker()
## (below) adds a CityWalker (scripts/city_walker.gd, a minimal first-person
## controller, deliberately not the survival Player class) so the scene has
## someone to look through; Esc returns to scenes/main.tscn. This standalone
## path (`standalone = true`, the default) is UNCHANGED by B5 below and
## still behaves exactly this way when loaded as its own scene root.
##
## 2026-09-20, B5: main.gd's "Visit Hollowmark" (title screen AND pause
## menu, now real gameplay, not just a preview) instead embeds an instance
## of this scene inside the live voxel game via State.CITY -- see
## `standalone` just below.
##
## B4 (route markers): `route_markers` is a named waypoint graph (the five
## locations plus a few street/park connector points) and `get_route()`
## returns an ordered path between any two of them via a small BFS. This is
## for scripts/debug_actor.gd (a non-player-controlled walker) and, later,
## Layer 5's resident home/work/food routines -- not for the player, who
## just walks freely on the open ground.
##
## B5 (`standalone`): true (default) is this scene exactly as B1-B4 built
## and verified it -- its own WorldEnvironment/Sun/overview-camera, and it
## spawns its own walker. main.gd sets this false before add_child()-ing an
## instance for State.CITY: it embeds this scene inside the live voxel
## game's own tree instead of loading it as a separate scene root, so it
## must not silently fight that scene's WorldEnvironment or hijack the
## viewport on its own -- main.gd drives spawning/camera activation itself.

const TEX_DIR := "res://blocky/city/textures/blocks/"

## Where each B0 location's building/area is centered, exposed for later
## cards (B3 interiors, B4 nav path) so they don't have to re-derive layout
## coordinates by reading this whole file.
var location_positions := {}

## Where each B0 building's own front door sits (world position, at the
## door itself, not the "stand outside" spot `location_positions` gives).
## B3 uses this to place the entry trigger; interiors keep their own
## matching exit point so leaving puts you back exactly here.
var _entrances := {}

var _rng := RandomNumberGenerator.new()

## B4: named waypoints (the five locations plus street/park connector
## points) a debug/resident actor can walk between. Built in
## _build_route_markers() once every location's outside point is known.
var route_markers := {}
var _route_edges := {}

## See the class doc comment above. main.gd sets this false before
## add_child()-ing an instance for State.CITY.
var standalone := true


func _ready() -> void:
	_rng.seed = 20260920
	if not standalone:
		# Embedded in the running voxel game: rely on that scene's own
		# WorldEnvironment/DayNight sun instead of this scene's standalone
		# ones. Godot does not reliably support two active WorldEnvironment
		# nodes in one tree, and the voxel game's is already the trusted,
		# tested one -- freeing these immediately (before this frame's
		# render, and before any of this scene's own code has referenced
		# them) avoids gambling on undefined multi-WorldEnvironment
		# behavior. Real, deliberate cost: the city's look no longer
		# matches its standalone screenshots exactly (day/night now follows
		# whatever time it already is in the voxel game).
		var env_node := get_node_or_null("WorldEnvironment")
		if env_node:
			env_node.free()
		var sun_node := get_node_or_null("Sun")
		if sun_node:
			sun_node.free()
	_build_ground()
	_build_street_and_sidewalks()
	_build_park()
	_build_apartment()
	_build_cafe()
	_build_workplace()
	_build_street_furniture()
	_build_interiors()
	_build_route_markers()
	if standalone:
		_build_overview_camera()
		spawn_walker()


## A CityWalker (see scripts/city_walker.gd) at the named location (default
## "street" -- the open 46x6 band along X/Z centered at the origin, clear of
## every building and prop; default facing (-Z) already looks toward the
## building row at z=-8.5), camera made current -- Godot only ever treats
## the most-recently-activated Camera3D as current. Public and returns the
## walker: the standalone flow above calls this itself; main.gd's State.CITY
## calls it too when embedding (after setting standalone = false), then
## connects the returned walker's own signals/flags itself.
func spawn_walker(at: String = "street") -> CityWalker:
	var walker := CharacterBody3D.new()
	walker.set_script(load("res://scripts/city_walker.gd"))
	walker.name = "Walker"
	walker.position = route_markers.get(at, location_positions.get("street", Vector3.ZERO)) + Vector3(0, 0.1, 0)

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.1   # see the board's 2026-09-20 CORRECTION entry: this IS the total height
	var col := CollisionShape3D.new()
	col.shape = capsule
	col.position = Vector3(0, 0.55, 0)   # half of total height, centers the capsule on the origin/feet
	walker.add_child(col)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	walker.add_child(camera)

	add_child(walker)
	return walker


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

## A real assembled door from the four door_* textures, offset sideways
## from the building's own center line by `x_offset` so it can sit beside
## a shop window instead of through it (cafe/workplace both have one).
func _add_door(prefix: String, x_offset: float, front_z: float) -> void:
	_add_visual_box(prefix + "DoorLower", Vector3(x_offset, 0.55, front_z), Vector3(0.9, 1.1, 0.06),
		_material("door_lower"))
	_add_visual_box(prefix + "DoorUpper", Vector3(x_offset, 1.65, front_z), Vector3(0.9, 1.1, 0.06),
		_material("door_upper"))
	_add_visual_box(prefix + "DoorFrameL", Vector3(x_offset - 0.55, 1.1, front_z), Vector3(0.15, 2.2, 0.07),
		_material("door_frame"))
	_add_visual_box(prefix + "DoorFrameR", Vector3(x_offset + 0.55, 1.1, front_z), Vector3(0.15, 2.2, 0.07),
		_material("door_side"))


## The apartment (home, private, one entrance) gets a real assembled door
## from the four door_* textures — the only building with nothing else on
## its front face, so its door sits centered.
func _build_apartment() -> void:
	var center := Vector3(-16.0, 0.0, -8.5)
	var size := Vector3(8.0, 4.0, 6.0)
	_add_solid_box("Apartment", center + Vector3(0, size.y * 0.5, 0), size,
		_material("brick", Vector2(size.x, size.y)))
	_add_visual_box("ApartmentRoof", center + Vector3(0, size.y + 0.2, 0), Vector3(8.8, 0.4, 6.8),
		_material("roof_tile", Vector2(8.8, 6.8)))

	var front_z := center.z + size.z * 0.5 + 0.03
	_add_door("Apartment", center.x, front_z)

	_add_sign("The Player's Apartment", Vector3(center.x, size.y + 0.9, front_z))
	location_positions["apartment"] = Vector3(center.x, 0.0, front_z + 1.0)
	_entrances["apartment"] = Vector3(center.x, 0.0, front_z)


func _build_cafe() -> void:
	var center := Vector3(0.0, 0.0, -8.5)
	var size := Vector3(8.0, 3.6, 6.0)
	_add_solid_box("Cafe", center + Vector3(0, size.y * 0.5, 0), size,
		_material("plaster", Vector2(size.x, size.y)))
	_add_visual_box("CafeRoof", center + Vector3(0, size.y + 0.2, 0), Vector3(8.8, 0.4, 6.8),
		_material("roof_tile", Vector2(8.8, 6.8)))

	var front_z := center.z + size.z * 0.5 + 0.03
	_add_visual_box("CafeWindow", Vector3(center.x - 0.6, 1.8, front_z), Vector3(3.0, 1.8, 0.06),
		_material("shop_window", Vector2(3, 1.8)))
	var door_x := center.x + size.x * 0.5 - 0.9
	_add_door("Cafe", door_x, front_z)
	# Café's outdoor deck: tavern_floor re-purposed as decking, not a tavern
	# floor (see CITY_ASSET_MANIFEST.md's README-mismatch note).
	_add_visual_box("CafeDeck", Vector3(center.x, 0.02, front_z + 1.1), Vector3(6.0, 0.05, 2.2),
		_material("tavern_floor", Vector2(6, 2.2)))
	_entrances["cafe"] = Vector3(door_x, 0.0, front_z)

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
	_add_visual_box("WorkplaceWindow", Vector3(center.x + 0.7, 1.9, front_z), Vector3(3.4, 1.6, 0.06),
		_material("shop_window", Vector2(3.4, 1.6)))
	var door_x := center.x - size.x * 0.5 + 0.9
	_add_door("Workplace", door_x, front_z)
	_entrances["workplace"] = Vector3(door_x, 0.0, front_z)

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


# ---------------------------------------------------------------- interiors (B3)

## Interiors are real 3D rooms built the same "generate the mesh" way as
## the exterior, not menus -- but they'd overlap the street's own geometry
## if placed at street level, so each one is a "pocket" far below its own
## building (same X/Z as its door, offset only in Y) reached purely by
## teleport. B3's literal acceptance check is "every location is
## enterable" — walking into a building's front door teleports you inside;
## walking to the interior's own doorway teleports you back outside to
## exactly the spot `location_positions` already gives every other card.
const INTERIOR_Y := -30.0
const WALL_HEIGHT := 3.0


func _build_interiors() -> void:
	_build_apartment_interior()
	_build_cafe_interior()
	_build_workplace_interior()


## Floor + 4 walls, no ceiling, plus one warm ceiling-height light. The
## scene's own DirectionalLight3D does technically reach in (no ceiling to
## block it), but at its low angle (see the WorldEnvironment sun) a small
## room's own walls shadow most of the floor -- confirmed by an actual
## screenshot looking too dim to read, not assumed.
func _build_room_shell(prefix: String, center: Vector3, size: Vector2, wall_material: Material, floor_material: Material) -> void:
	_add_solid_box(prefix + "Floor", center + Vector3(0, -0.1, 0), Vector3(size.x, 0.2, size.y), floor_material)
	var t := WALL_HEIGHT * 0.5
	_add_solid_box(prefix + "WallN", center + Vector3(0, t, -size.y * 0.5), Vector3(size.x, WALL_HEIGHT, 0.2), wall_material)
	_add_solid_box(prefix + "WallS", center + Vector3(0, t, size.y * 0.5), Vector3(size.x, WALL_HEIGHT, 0.2), wall_material)
	_add_solid_box(prefix + "WallE", center + Vector3(size.x * 0.5, t, 0), Vector3(0.2, WALL_HEIGHT, size.y), wall_material)
	_add_solid_box(prefix + "WallW", center + Vector3(-size.x * 0.5, t, 0), Vector3(0.2, WALL_HEIGHT, size.y), wall_material)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.92, 0.78)
	light.light_energy = 2.2
	light.omni_range = maxf(size.x, size.y) * 1.1
	light.position = center + Vector3(0, WALL_HEIGHT - 0.3, 0)
	add_child(light)


## A trigger volume that teleports any body with a `teleport_to(pos, yaw)`
## method (CityWalker; guarded so an unrelated physics body could never
## crash this) to `target`, facing `target_yaw`.
func _add_transition(pos: Vector3, target: Vector3, target_yaw: float = 0.0) -> void:
	var area := Area3D.new()
	area.position = pos
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 2.2, 0.8)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(body: Node3D):
		if body.has_method("teleport_to"):
			body.teleport_to(target, target_yaw))


func _build_apartment_interior() -> void:
	var door: Vector3 = _entrances["apartment"]
	var out: Vector3 = location_positions["apartment"]
	var size := Vector2(6.0, 5.0)
	var center := Vector3(door.x, INTERIOR_Y, door.z)
	_build_room_shell("ApartmentInterior", center, size,
		_material("plaster", Vector2(size.x, WALL_HEIGHT)), _material("flagstone", size))

	# Bed in the back corner: a frame plus a two-tone mattress/pillow.
	var bed := center + Vector3(-1.7, 0.0, -1.5)
	_add_solid_box("Bed", bed + Vector3(0, 0.25, 0), Vector3(1.0, 0.5, 2.0), _flat_material(Color(0.42, 0.28, 0.2)))
	_add_visual_box("BedMattress", bed + Vector3(0, 0.52, 0.1), Vector3(0.9, 0.12, 1.7), _flat_material(Color(0.75, 0.72, 0.62)))
	_add_visual_box("BedPillow", bed + Vector3(0, 0.6, -0.75), Vector3(0.8, 0.16, 0.4), _flat_material(Color(0.92, 0.9, 0.85)))
	# A small bedside table, reusing the crate material already used outside.
	_add_solid_box("ApartmentTable", center + Vector3(1.5, 0.35, 1.3), Vector3(0.9, 0.7, 0.9), _material("crate"))

	_add_transition(door + Vector3(0, 1.0, 0.1), center + Vector3(0, 0, -0.8), 0.0)
	_add_transition(center + Vector3(0, 1.0, size.y * 0.5 - 0.4), out, PI)


func _build_cafe_interior() -> void:
	var door: Vector3 = _entrances["cafe"]
	var out: Vector3 = location_positions["cafe"]
	var size := Vector2(7.0, 5.5)
	var center := Vector3(door.x, INTERIOR_Y, door.z)
	_build_room_shell("CafeInterior", center, size,
		_material("plaster", Vector2(size.x, WALL_HEIGHT)), _material("tavern_floor", size))

	# A counter along the back wall, plus two bench-seated tables (reusing
	# the same bench prop already used for café/park/street seating).
	_add_solid_box("CafeCounter", center + Vector3(0, 0.5, -size.y * 0.5 + 0.6), Vector3(3.5, 1.0, 0.8),
		_material("brick", Vector2(3.5, 1)))
	for x in [-1.8, 1.8]:
		_add_solid_box("CafeTable%d" % int(x), center + Vector3(x, 0.35, 1.0), Vector3(0.8, 0.7, 0.8), _material("crate"))
		_add_prop("bench", center + Vector3(x, 0.0, 1.9), PI)

	_add_transition(door + Vector3(0, 1.0, 0.1), center + Vector3(0, 0, -0.8), 0.0)
	_add_transition(center + Vector3(0, 1.0, size.y * 0.5 - 0.4), out, PI)


func _build_workplace_interior() -> void:
	var door: Vector3 = _entrances["workplace"]
	var out: Vector3 = location_positions["workplace"]
	var size := Vector2(7.0, 5.5)
	var center := Vector3(door.x, INTERIOR_Y, door.z)
	_build_room_shell("WorkplaceInterior", center, size,
		_material("brick", Vector2(size.x, WALL_HEIGHT)), _material("cobblestone", size))

	# A long workbench, and stacked crates as shelving against the back wall.
	_add_solid_box("Workbench", center + Vector3(0.5, 0.45, -size.y * 0.5 + 0.6), Vector3(3.0, 0.9, 0.8),
		_flat_material(Color(0.35, 0.24, 0.16)))
	for i in 3:
		_add_visual_box("Shelf%d" % i, center + Vector3(-2.6, 0.35 + i * 0.72, -size.y * 0.5 + 0.5),
			Vector3(0.7, 0.6, 0.7), _material("crate"))

	_add_transition(door + Vector3(0, 1.0, 0.1), center + Vector3(0, 0, -0.8), 0.0)
	_add_transition(center + Vector3(0, 1.0, size.y * 0.5 - 0.4), out, PI)


# ---------------------------------------------------------------- routes (B4)

## Apartment/cafe/workplace each connect to the open street (the z=0 band
## `spawn_walker()`'s own comment already documents as "clear of every
## building and prop") via a short straight hop from their door-out point to
## a spine marker at their own X; the spine markers connect to each other and
## to the park entry along that same clear band. The park entry then runs
## north along `ParkPath` (the visual strip `_build_park()` lays down
## specifically as a walkway) to the park itself. Every segment here follows
## ground already built clear of props/buildings -- checked against
## `_build_street_furniture()`'s and each location's own prop placements,
## not just assumed.
func _build_route_markers() -> void:
	route_markers["apartment"] = location_positions["apartment"]
	route_markers["apartment_spine"] = Vector3(-16.0, 0.0, 0.0)
	route_markers["street"] = location_positions["street"]
	route_markers["cafe"] = location_positions["cafe"]
	route_markers["workplace_spine"] = Vector3(16.0, 0.0, 0.0)
	route_markers["workplace"] = location_positions["workplace"]
	route_markers["park_entry"] = Vector3(0.0, 0.0, 5.5)
	route_markers["park"] = location_positions["park"]

	_route_edges = {
		"apartment": ["apartment_spine"],
		"apartment_spine": ["apartment", "street"],
		"street": ["apartment_spine", "cafe", "workplace_spine", "park_entry"],
		"cafe": ["street"],
		"workplace_spine": ["street", "workplace"],
		"workplace": ["workplace_spine"],
		"park_entry": ["street", "park"],
		"park": ["park_entry"],
	}


## Returns an ordered list of world positions from one named location
## ("apartment", "street", "cafe", "workplace", "park") to another, walking
## the route-marker graph with a breadth-first search (the graph is small
## and tree-shaped, so BFS always finds the unique path). Returns an empty
## array for an unknown key; a single-point array if `from_key == to_key`.
func get_route(from_key: String, to_key: String) -> Array:
	if not (route_markers.has(from_key) and route_markers.has(to_key)):
		return []
	if from_key == to_key:
		return [route_markers[from_key]]

	var came_from := {from_key: from_key}   # self-maps the start; walking parents stops when we hit it
	var frontier := [from_key]
	var reached := false
	while frontier.size() > 0:
		var current: String = frontier.pop_front()
		if current == to_key:
			reached = true
			break
		for neighbor in _route_edges.get(current, []):
			if not came_from.has(neighbor):
				came_from[neighbor] = current
				frontier.append(neighbor)
	if not reached:
		return []

	var keys: Array[String] = [to_key]
	var node: String = to_key
	while node != from_key:
		node = came_from[node]
		keys.push_front(node)

	var path: Array[Vector3] = []
	for k in keys:
		path.append(route_markers[k])
	return path
