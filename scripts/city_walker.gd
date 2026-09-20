class_name CityWalker
extends CharacterBody3D
## A minimal first-person walker for the standalone city block scene
## (scenes/city_block.tscn) -- just enough to walk around and look at it.
## Deliberately NOT the survival Player class: that script assumes a
## VoxelWorld (block break/place raycasts, hunger, inventory, hotbar), none
## of which apply here, and coupling this scene to it would risk
## null-reference crashes on those assumptions. Real city gameplay
## (interiors, NPCs, actions) is B3+ and will need its own purpose-built
## controller -- this is only a look-around demo, wired in ahead of the
## formal B5 integration card at Ryann's direct request.

const WALK_SPEED := 4.5
const RUN_SPEED := 7.5
const JUMP_SPEED := 6.0
const GRAVITY := 22.0
const MOUSE_SENS := 0.0025
const EYE_HEIGHT := 1.5

var _pitch := 0.0

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera.current = true
	_camera.position = Vector3(0, EYE_HEIGHT, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.4, 1.4)
		_camera.rotation.x = _pitch
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_physical_key_pressed(KEY_SPACE):
		velocity.y = JUMP_SPEED

	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input.x += 1.0
	input = input.normalized()

	var speed := RUN_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) else WALK_SPEED
	var dir := (global_basis * Vector3(input.x, 0, input.y))
	dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	move_and_slide()
