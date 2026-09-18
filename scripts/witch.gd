class_name Witch
extends Hostile
## A night hunter that looks like blocky/models/witch.glb instead of the
## Shade's box placeholder. All AI (chase/bite/burn-at-dawn) and stats are
## inherited from Hostile unchanged — only the look changes (see Creature's
## GLB-model helpers).

const WITCH_GLB := preload("res://blocky/models/witch.glb")
## The raw rig is ~3.2m tall (the hat's cone tip stretches way up); scaled
## down to a human-ish height with a still-tall pointed hat.
const MODEL_HEIGHT := 1.6


func _build_model() -> void:
	_instantiate_glb_rig(WITCH_GLB, MODEL_HEIGHT)


func _set_flash_color(color: Color) -> void:
	_flash_glb(color)
