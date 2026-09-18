class_name Fox
extends Creature
## A passive critter built from blocky/models/fox.glb. Behavior is all
## inherited from Creature; only the look changes (see Creature's GLB-model
## helpers).

const FOX_GLB := preload("res://blocky/models/fox.glb")


func _build_model() -> void:
	# Already authored at a believable ~1m-to-the-ears height for this
	# game's scale (a bit taller than the rabbit, well under the deer), so
	# no rescale is needed.
	_instantiate_glb_rig(FOX_GLB)


func _set_flash_color(color: Color) -> void:
	_flash_glb(color)
