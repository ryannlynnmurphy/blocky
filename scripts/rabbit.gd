class_name Rabbit
extends Creature
## A passive critter that looks like an actual rabbit (blocky/models/rabbit.glb)
## instead of the generic tinted-box placeholder. Behavior is all inherited
## from Creature; only the look changes (see Creature's GLB-model helpers).

const RABBIT_GLB := preload("res://blocky/models/rabbit.glb")


func _build_model() -> void:
	# Already authored at roughly the same ~0.9m height as the box
	# placeholder it replaces, so no rescale is needed.
	_instantiate_glb_rig(RABBIT_GLB)


func _set_flash_color(color: Color) -> void:
	_flash_glb(color)
