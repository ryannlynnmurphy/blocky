class_name Goblin
extends Hostile
## A night hunter that looks like blocky/models/goblin.glb instead of the
## Shade's box placeholder. All AI (chase/bite/burn-at-dawn) and stats are
## inherited from Hostile unchanged — only the look changes (see Creature's
## GLB-model helpers).

const GOBLIN_GLB := preload("res://blocky/models/goblin.glb")


func _build_model() -> void:
	# Already authored at a believable ~1.4m height, no rescale needed.
	_instantiate_glb_rig(GOBLIN_GLB)


func _set_flash_color(color: Color) -> void:
	_flash_glb(color)
