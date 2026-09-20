class_name CityRenderPack
extends RefCounted
## The render-side catalogue for Hollowmark's reusable city props.  The OBJ
## files are ordinary Godot-imported Mesh resources, so a street can reuse one
## bench, lamp or car mesh hundreds of times without generating geometry.

## NOTE (B1/B2, 2026-09-20): this catalogue existed before the board picked
## up B0-B2 but pointed at the wrong folder (res://blocky/models/city/,
## which does not exist) and included `police_car`, which
## docs/lab/CITY_BLOCK_LAYOUT.md's "Vendored asset note" excludes along with
## pistol_prop/rifle_prop. Fixed both here: correct path prefix, dropped
## police_car, added the two legitimate models (box_van, street_lamp) that
## were missing from the original list. See docs/lab/CITY_ASSET_MANIFEST.md
## for the full audit this catalogue is built from.
const PROP_PATHS := {
	"bench": "res://blocky/city/models/bench.obj",
	"box_van": "res://blocky/city/models/box_van.obj",
	"bus_stop": "res://blocky/city/models/bus_stop.obj",
	"dumpster": "res://blocky/city/models/dumpster.obj",
	"fire_hydrant": "res://blocky/city/models/fire_hydrant.obj",
	"hot_dog_cart": "res://blocky/city/models/hot_dog_cart.obj",
	"imbiss": "res://blocky/city/models/imbiss.obj",
	"market_stall": "res://blocky/city/models/market_stall.obj",
	"sedan": "res://blocky/city/models/sedan.obj",
	"street_lamp": "res://blocky/city/models/street_lamp.obj",
	"taxi": "res://blocky/city/models/taxi.obj",
	"traffic_light": "res://blocky/city/models/traffic_light.obj",
	"vending_machine": "res://blocky/city/models/vending_machine.obj",
}


static func instantiate_prop(id: String) -> Node3D:
	if not PROP_PATHS.has(id):
		push_error("Unknown city prop: %s" % id)
		return Node3D.new()
	var asset := load(PROP_PATHS[id])
	if asset is PackedScene:
		return (asset as PackedScene).instantiate() as Node3D
	var result := MeshInstance3D.new()
	result.name = id.capitalize().replace("_", " ")
	result.mesh = asset as Mesh
	return result


static func available_props() -> PackedStringArray:
	return PackedStringArray(PROP_PATHS.keys())
