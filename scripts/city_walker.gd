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

## When true (the default -- e.g. the title-screen preview's standalone
## scene swap), Esc reloads scenes/main.tscn directly, same as before B4/B5.
## When false (main.gd's State.CITY embeds this walker in the running
## game), Esc only emits exit_requested; reloading the whole scene there
## would discard the live voxel game instead of just leaving the city.
var standalone := true

## Emitted on Esc regardless of `standalone`, so an embedding caller (like
## main.gd) always has a clean hook without needing to know this class's
## internal exit behavior.
signal exit_requested

## S2: true while standing near CityBlock's workbench (polled every
## physics frame in _check_triggers() -- see the CORRECTION comment on
## CityBlock._add_transition() for why this isn't an Area3D signal).
## Gates whether E does anything here.
var near_workbench := false

## Fired on E while near_workbench is true. main.gd (embedded mode) is the
## only listener for now -- the standalone preview has no PersonActions
## profile to apply this to, so it's a harmless no-op signal there.
signal work_requested

## L2: the nearest resident within CityBlock.TALK_RADIUS (polled every
## physics frame in _check_triggers(), same reasoning as near_workbench),
## or null. Unlike near_workbench (a fixed point), residents move on their
## own routine, so this is a live query, not a static trigger zone.
var near_resident: DebugActor = null

## Fired on F while near_resident is set. Passes the resident so the
## listener (main.gd) knows which PersonProfile to apply PersonActions.talk()
## to -- this walker has no PersonProfile of its own to reason about.
signal talk_requested(resident: DebugActor)

## L3: fired on I while near_resident is set -- the "resident debug
## inspector" this card asks for, reusing near_resident's same live
## proximity query rather than building a second one just for this.
signal inspect_requested(resident: DebugActor)

## L4: true while standing near the cafe's own outdoor point (polled every
## physics frame in _check_triggers(), same pattern as near_workbench).
var near_shop := false

## Fired on B while near_shop is true.
signal buy_requested

var _pitch := 0.0

@onready var _camera: Camera3D = $Camera3D
## The CityBlock this walker was spawned into (spawn_walker() always
## add_child()s it directly under the CityBlock instance), used to poll
## door/work triggers every physics frame. See the CORRECTION comment on
## CityBlock._add_transition().
@onready var _block: CityBlock = get_parent()


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera.current = true
	_camera.position = Vector3(0, EYE_HEIGHT, 0)


## Called by _check_triggers() when within CityBlock.TRANSITION_RADIUS of a
## registered transition point. Zeroing velocity matters: without it,
## whatever speed carried you into the trigger keeps being applied for a
## frame or two on the other side, which reads as a jarring shove out of a
## doorway rather than a clean cut.
func teleport_to(pos: Vector3, yaw: float = 0.0) -> void:
	global_position = pos
	rotation.y = yaw
	velocity = Vector3.ZERO


## Polled every physics frame (not Area3D signals -- see the CORRECTION
## comment on CityBlock._add_transition() for why): teleports through the
## first door/interior transition within range, else updates
## near_workbench from CityBlock.near_workbench_at().
func _check_triggers() -> void:
	if _block == null:
		return
	for t in _block.transitions:
		# transitions[].pos/target are stored in CityBlock's own LOCAL space
		# (the same values _add_transition() was called with while building
		# the scene, before any embedding offset existed) -- must go
		# through _block.to_global()/to_local(), not be compared/used
		# directly against this walker's own global_position.
		if global_position.distance_to(_block.to_global(t["pos"])) < CityBlock.TRANSITION_RADIUS:
			teleport_to(_block.to_global(t["target"]), t["yaw"])
			return
	near_workbench = _block.near_workbench_at(global_position)
	near_resident = _block.nearest_resident_to(global_position)
	near_shop = _block.near_shop_at(global_position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.4, 1.4)
		_camera.rotation.x = _pitch
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		exit_requested.emit()
		if standalone:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
	elif event is InputEventKey and event.pressed and event.keycode == KEY_E and near_workbench:
		work_requested.emit()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F and near_resident != null:
		talk_requested.emit(near_resident)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_I and near_resident != null:
		inspect_requested.emit(near_resident)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_B and near_shop:
		buy_requested.emit()


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
	_check_triggers()
