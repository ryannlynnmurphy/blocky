class_name Bird
extends Creature
## A passive critter built from blocky/models/bird.glb. Ground-walking for
## now, same as every other wildlife (no flight behavior yet) — behavior is
## all inherited from Creature; only the look changes (see Creature's
## GLB-model helpers).

const BIRD_GLB := preload("res://blocky/models/bird.glb")


func _build_model() -> void:
	# Already authored small (~0.67m), no rescale needed.
	_instantiate_glb_rig(BIRD_GLB)


func _set_flash_color(color: Color) -> void:
	_flash_glb(color)
