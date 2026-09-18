class_name Deer
extends Creature
## A passive critter built from blocky/models/deer.glb. Behavior is all
## inherited from Creature; only the look changes (see Creature's GLB-model
## helpers).

const DEER_GLB := preload("res://blocky/models/deer.glb")
## Antler-tip height, in meters, that the raw ~2.4m-tall rig gets scaled
## down to. Puts its shoulders roughly chest-high on the 1.3m player and
## its antlers a bit above their head.
const MODEL_HEIGHT := 1.7


func _build_model() -> void:
	_instantiate_glb_rig(DEER_GLB, MODEL_HEIGHT)


func _set_flash_color(color: Color) -> void:
	_flash_glb(color)
