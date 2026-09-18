class_name Creature
extends CharacterBody3D
## A wandering animal. Its whole "brain" is two states:
##   idle   - stand still for a moment
##   wander - walk in a random direction for a moment
## and a timer that flips between them. It hops up 1-block steps and
## refuses to walk off cliffs or into water.

const GRAVITY := 22.0
const WALK_SPEED := 2.0
const JUMP_SPEED := 6.5

var world: VoxelWorld
var body_color := Color(0.85, 0.70, 0.50)

var _wandering := false
var _timer := 0.0
var _dir := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

@onready var _model: Node3D = $Model


func _ready() -> void:
	_rng.randomize()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	mat.roughness = 1.0
	$Model/Body.material_override = mat
	$Model/Head.material_override = mat
	_go_idle()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	_timer -= delta
	if _timer <= 0.0:
		if _wandering:
			_go_idle()
		else:
			_go_wander()

	if _wandering:
		if _path_blocked():
			_go_wander()   # pick another direction
		velocity.x = _dir.x * WALK_SPEED
		velocity.z = _dir.z * WALK_SPEED
		# Walked into a block? Hop.
		if is_on_floor() and is_on_wall():
			velocity.y = JUMP_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

	move_and_slide()

	if _wandering:
		var target := atan2(-_dir.x, -_dir.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target, 8.0 * delta)


func _go_idle() -> void:
	_wandering = false
	_timer = _rng.randf_range(1.0, 3.0)


func _go_wander() -> void:
	_wandering = true
	var angle := _rng.randf_range(0.0, TAU)
	_dir = Vector3(sin(angle), 0.0, cos(angle))
	_timer = _rng.randf_range(1.5, 4.0)


## Peeks one block ahead: is there ground there that's not under water?
func _path_blocked() -> bool:
	if world == null:
		return false
	var ahead := global_position + _dir * 0.9
	var x := int(floor(ahead.x))
	var z := int(floor(ahead.z))
	var y0 := int(floor(global_position.y))
	# Accept ground from one block up (a step) down to two blocks below.
	for y in range(y0 + 1, y0 - 3, -1):
		if Blocks.is_solid(world.get_block(x, y, z)):
			return y < WorldGen.SEA_LEVEL   # found ground; blocked only if it's under water
	return true   # no ground at all = a cliff
