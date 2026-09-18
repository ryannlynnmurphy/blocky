class_name Wisp
extends Hostile
## A night hunter that looks like blocky/models/wisp.glb instead of the
## Shade's box placeholder. All AI (chase/bite/burn-at-dawn) and stats are
## inherited from Hostile unchanged — only the look changes (see Creature's
## GLB-model helpers).

const WISP_GLB := preload("res://blocky/models/wisp.glb")
## The raw rig is ~2.1m tall (it's meant to loom); scaled down to fit the
## same ~2-block spawn clearance the other hostiles use.
const MODEL_HEIGHT := 1.75


func _build_model() -> void:
	_instantiate_glb_rig(WISP_GLB, MODEL_HEIGHT)


func _set_flash_color(color: Color) -> void:
	_flash_glb(color)
