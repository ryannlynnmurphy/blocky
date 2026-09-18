class_name Boar
extends Creature
## A passive critter built from blocky/models/boar.glb. Behavior is all
## inherited from Creature; only the look changes (see Creature's GLB-model
## helpers).

const BOAR_GLB := preload("res://blocky/models/boar.glb")
## Back-bristle height, in meters, the raw ~1.4m-tall rig gets scaled down
## to: low and stocky, clearly smaller than the deer.
const MODEL_HEIGHT := 0.85


func _build_model() -> void:
	_instantiate_glb_rig(BOAR_GLB, MODEL_HEIGHT)


func _set_flash_color(color: Color) -> void:
	_flash_glb(color)
