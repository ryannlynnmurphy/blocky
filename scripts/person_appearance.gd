class_name PersonAppearance
extends RefCounted
## A small, data-driven render kit for the game's shared blocky human rig.
## The source GLB supplies the geometry; this class supplies interchangeable
## colours, hair silhouettes, outfits and body proportions.

const PLAYER_GLB := preload("res://blocky/models/player.glb")
const WARDROBE_CATALOG = preload("res://scripts/wardrobe_catalog.gd")

const SKIN := {
	"Porcelain": Color("f1c8ad"), "Warm": Color("c9875d"),
	"Umber": Color("8c503a"), "Deep": Color("55332d"), "Copper": Color("b96e48"),
}
const HAIR := {
	"Ink": Color("252033"), "Chestnut": Color("5e392e"), "Honey": Color("b87b3b"),
	"Copper": Color("a64732"), "Silver": Color("aeb4be"),
}
const OUTFIT := {
	"Casual": [Color("587a93"), Color("273948"), Color("d3b06d")],
	"Workwear": [Color("6b7550"), Color("404b34"), Color("d6a84e")],
	"Nightlife": [Color("39294f"), Color("1f1b2a"), Color("c95c7b")],
	"Utility": [Color("665c46"), Color("39372d"), Color("d7d0bd")],
}
const ACCENT := {
	"Ochre": Color("db9e43"), "Teal": Color("3d9c98"), "Violet": Color("8d65b9"),
	"Crimson": Color("bc4d4e"), "None": Color("8d8b87"),
}
const HAIR_PARTS := ["hair_cap", "hair_shard_main", "hair_shard_side", "hair_shard_bang",
	"hair_brow", "hair_lock_front", "hair_back", "hair_side_L", "hair_side_R"]


static func make_preview(profile: Dictionary) -> Node3D:
	var avatar := Node3D.new()
	avatar.name = "PreviewAvatar"
	var rig: Node3D = PLAYER_GLB.instantiate()
	avatar.add_child(rig)
	# The source is human-scale; this makes it read as a chunky two-voxel person.
	rig.scale = Vector3(1.08, 1.08, 1.08)
	apply_to(avatar, profile)
	return avatar


static func apply_to(root: Node, profile: Dictionary) -> void:
	var look: Dictionary = profile.get("appearance", {})
	var skin: Color = SKIN.get(str(look.get("skin", "Warm")), SKIN["Warm"])
	var hair: Color = HAIR.get(str(look.get("hair_color", "Chestnut")), HAIR["Chestnut"])
	var outfit: Array = OUTFIT.get(str(look.get("outfit", "Casual")), OUTFIT["Casual"])
	var accent: Color = ACCENT.get(str(look.get("accent", "Teal")), ACCENT["Teal"])
	# Catalog IDs select reusable rig parts.  Keep legacy preset colours as a
	# fallback so profiles made before wardrobe IDs still render correctly.
	var raw_wardrobe: Dictionary = look.get("wardrobe", {})
	var wardrobe: Dictionary = WARDROBE_CATALOG.sanitize(raw_wardrobe)
	var shirt_color := _wardrobe_color(wardrobe["tshirt"], outfit[0])
	var pants_color := _wardrobe_color(wardrobe["pants"], outfit[1])
	var belt_color := _wardrobe_color(wardrobe["belt"], accent)
	var shoes_color := _wardrobe_color(wardrobe["shoes"], outfit[1])
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var part := mesh.name.to_lower()
		if part in HAIR_PARTS:
			mesh.visible = _hair_part_visible(part, str(look.get("hair", "Sweep")))
			_tint(mesh, hair)
		elif part == "head" or part.begins_with("hand"):
			_tint(mesh, skin)
		elif part.begins_with("arm") or part == "torso":
			_tint(mesh, shirt_color)
		elif part.begins_with("leg"):
			_tint(mesh, pants_color)
		elif part.begins_with("boot"):
			_tint(mesh, shoes_color)
		elif part == "belt" or part == "buckle":
			_tint(mesh, belt_color)
	_apply_bracelet(root, wardrobe, accent)
	_apply_body_shape(root, str(look.get("body", "Balanced")))


static func _hair_part_visible(part: String, style: String) -> bool:
	match style:
		"Buzz": return part == "hair_cap"
		"Crop": return part in ["hair_cap", "hair_shard_main", "hair_shard_side"]
		"Long": return part in ["hair_cap", "hair_back", "hair_side_L", "hair_side_R", "hair_lock_front"]
		_: return part in ["hair_cap", "hair_shard_main", "hair_shard_bang", "hair_brow", "hair_lock_front"]


static func _apply_body_shape(root: Node, body: String) -> void:
	var body_scale := Vector3.ONE
	if body == "Tall":
		body_scale = Vector3(0.96, 1.10, 0.96)
	elif body == "Broad":
		body_scale = Vector3(1.12, 0.96, 1.12)
	for part_name in ["torso", "arm_L", "arm_R", "leg_L", "leg_R", "head"]:
		var part := root.find_child(part_name, true, false) as Node3D
		if part != null:
			part.scale = body_scale


## Bracelets have no dedicated art yet (see docs/lab/WARDROBE_CATALOG.md), so
## this hangs a plain ring off the left hand's own wrist joint instead of
## claiming a mesh that doesn't exist. Sized from the hand's own AABB (the
## established pattern in this codebase, e.g. player.gd's limb pivots and
## sword scale) rather than a hand-copied number, so it fits any future
## rescale of the shared rig. Idempotent: reuses the same child node across
## repeated apply_to() calls (player.gd calls this on the live player model,
## not just the one-shot creator preview) instead of stacking duplicates.
static func _apply_bracelet(root: Node, wardrobe: Dictionary, fallback: Color) -> void:
	var hand := root.find_child("hand_L", true, false) as MeshInstance3D
	if hand == null:
		return
	var bracelet := hand.get_node_or_null("bracelet_wrist") as MeshInstance3D
	if bracelet == null:
		# hand_L's own local origin sits at the wrist joint -- the same
		# convention `_sword` already relies on (player.gd attaches it to
		# hand_R with no position offset at all) -- so this needs no AABB
		# placement math, only a size reference. Three torus copies cover
		# all three axis orientations since a rigged part's local basis
		# isn't guaranteed to have any particular axis point "up the arm"
		# (joint rotation is baked into the glTF node matrix); exactly one
		# will actually ring the wrist, the other two are degenerate
		# (edge-on or off to the side) and cost nothing extra to leave in.
		var size := hand.get_aabb().size
		var wrist_radius: float = (size.x + size.y + size.z) / 3.0 * 0.55
		bracelet = MeshInstance3D.new()
		bracelet.name = "bracelet_wrist"
		var torus := TorusMesh.new()
		torus.inner_radius = wrist_radius * 0.65
		torus.outer_radius = wrist_radius
		torus.rings = 16
		torus.ring_segments = 10
		bracelet.mesh = torus
		hand.add_child(bracelet)
	_tint(bracelet, _wardrobe_color(wardrobe.get("bracelet", ""), fallback))


static func _tint(mesh: MeshInstance3D, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh.material_override = material


static func _wardrobe_color(item_id: String, fallback: Color) -> Color:
	var item: Dictionary = WARDROBE_CATALOG.item(item_id)
	if item.has("color"):
		return Color(str(item["color"]))
	return fallback
