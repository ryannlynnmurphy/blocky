class_name CityRenderPack
extends RefCounted
## The render-side catalogue for Hollowmark's reusable city props.  The OBJ
## files are ordinary Godot-imported Mesh resources, so a street can reuse one
## bench, lamp or car mesh hundreds of times without generating geometry.

const PROP_PATHS := {
	"bench": "res://blocky/models/city/bench.obj",
	"bus_stop": "res://blocky/models/city/bus_stop.obj",
	"dumpster": "res://blocky/models/city/dumpster.obj",
	"fire_hydrant": "res://blocky/models/city/fire_hydrant.obj",
	"hot_dog_cart": "res://blocky/models/city/hot_dog_cart.obj",
	"imbiss": "res://blocky/models/city/imbiss.obj",
	"market_stall": "res://blocky/models/city/market_stall.obj",
	"police_car": "res://blocky/models/city/police_car.obj",
	"sedan": "res://blocky/models/city/sedan.obj",
	"taxi": "res://blocky/models/city/taxi.obj",
	"traffic_light": "res://blocky/models/city/traffic_light.obj",
	"vending_machine": "res://blocky/models/city/vending_machine.obj",
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
