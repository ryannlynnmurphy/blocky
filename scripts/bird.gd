class_name Bird
extends Creature
## A passive critter built from blocky/models/bird.glb. Unlike every other
## wildlife, it actually flies: no gravity, hovers at a height above the
## ground it spawned over, and wanders/flees in full 3D. Overrides
## _physics_process entirely rather than reusing Creature's (which is all
## about gravity, hopping and ground-cliff checks), but still shares
## its idle/wander timer state and take_hit/_die/flash machinery.

const BIRD_GLB := preload("res://blocky/models/bird.glb")
const FLY_SPEED := 2.2
const FLEE_FLY_SPEED := 5.0
const HOVER_HEIGHT := 3.0   # blocks above the ground it spawned over
const HEIGHT_LERP := 2.0    # how eagerly it corrects back to that height

## Ground level under the spawn point; captured lazily on the first
## physics tick, since _ready() runs before world.gd positions us.
var _base_y := INF


func _build_model() -> void:
	# Already authored small (~0.67m), no rescale needed.
	_instantiate_glb_rig(BIRD_GLB)


func _set_flash_color(color: Color) -> void:
	_flash_glb(color)


func _physics_process(delta: float) -> void:
	if _base_y == INF:
		_base_y = global_position.y

	_timer -= delta
	_flee_timer = maxf(_flee_timer - delta, 0.0)
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_set_flash_color(body_color)

	if _timer <= 0.0:
		if _wandering:
			_go_idle()
		else:
			_go_wander()

	velocity.y = (_base_y + HOVER_HEIGHT - global_position.y) * HEIGHT_LERP

	if _wandering:
		var speed := FLEE_FLY_SPEED if _flee_timer > 0.0 else FLY_SPEED
		velocity.x = _dir.x * speed
		velocity.z = _dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)

	velocity.x += _knock.x
	velocity.z += _knock.z
	_knock = _knock.move_toward(Vector3.ZERO, 25.0 * delta)

	move_and_slide()

	if _wandering:
		var target := atan2(-_dir.x, -_dir.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target, 8.0 * delta)
