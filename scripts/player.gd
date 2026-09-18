class_name Player
extends CharacterBody3D
## The character you control: movement, jumping, camera, and block editing.

signal hotbar_changed(index: int)
signal health_changed(health: int, max_health: int)
signal damaged(amount: int)
signal died
signal xp_changed(xp: int, xp_needed: int, level: int)
signal leveled_up(level: int)

const WALK_SPEED := 4.5
const RUN_SPEED := 7.5
const JUMP_SPEED := 7.5
const GRAVITY := 22.0
const MOUSE_SENS := 0.0025
const REACH := 6.0   # how far you can break/place, in blocks
const PUNCH_RANGE := 3.0
const PUNCH_DAMAGE := 1
const PUNCH_COOLDOWN := 0.35

var _punch_cooldown := 0.0

const BASE_HEALTH := 10
const HEALTH_PER_LEVEL := 2
const SAFE_FALL := 3.0    # blocks you can drop without getting hurt
const MEAT_HEAL := 4

var world: VoxelWorld
var selected := 0    # index into Blocks.HOTBAR
var inventory := Inventory.new()
var level := 1
var xp := 0
var max_health := BASE_HEALTH
var health := BASE_HEALTH
var spawn_point := Vector3.ZERO   # where you come back to life

var _was_on_floor := true
var _peak_y := 0.0   # highest point of the current fall

var _yaw := 0.0
var _pitch := -0.3
var _no_input := false   # dev: ignore mouse/keys so recordings are repeatable

@onready var _pivot: Node3D = $CameraPivot
@onready var _arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var _camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var _model: Node3D = $Model
@onready var _highlight: MeshInstance3D = $Highlight


func _ready() -> void:
	_setup_input_actions()
	_arm.add_excluded_object(get_rid())   # camera arm ignores our own body
	_pivot.rotation.y = _yaw
	_arm.rotation.x = _pitch
	# Testing aid: `-- --no-input` locks the camera and ignores clicks/keys.
	_no_input = "--no-input" in OS.get_cmdline_user_args()
	if not _no_input:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Points the camera. Used by tests; the mouse handler does the same thing.
func set_look(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = clampf(pitch, -1.3, 0.8)
	_pivot.rotation.y = _yaw
	_arm.rotation.x = _pitch


## Registers keyboard actions in code. (The usual Godot way is
## Project > Project Settings > Input Map; this does the same thing.)
func _setup_input_actions() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("jump", KEY_SPACE)
	_add_key("run", KEY_SHIFT)


func _add_key(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if _no_input:
		return
	if event.is_action_pressed("ui_cancel"):   # Esc
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseButton and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.3, 0.8)
		_pivot.rotation.y = _yaw
		_arm.rotation.x = _pitch

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_attack_or_break()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_place_block()

	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		var n := int(key.keycode) - int(KEY_1)
		if n >= 0 and n < Blocks.HOTBAR.size():
			selected = n
			hotbar_changed.emit(selected)
		elif key.keycode == KEY_E:
			eat()


func _physics_process(delta: float) -> void:
	_punch_cooldown = maxf(_punch_cooldown - delta, 0.0)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif not _no_input and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_SPEED

	# Movement is relative to where the camera is looking.
	var input := Vector2.ZERO
	if not _no_input:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (_pivot.global_basis * Vector3(input.x, 0, input.y))
	dir.y = 0
	dir = dir.normalized()
	var speed := RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	move_and_slide()
	_check_fall_damage()

	# Turn the model to face the way we're walking.
	if dir.length() > 0.1:
		var target := atan2(-dir.x, -dir.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target, 12.0 * delta)

	_update_highlight()


# ---------------------------------------------------------------- health

## Remembers the top of each fall; landing from higher than SAFE_FALL
## costs one health per extra block.
func _check_fall_damage() -> void:
	var on_floor := is_on_floor()
	if not on_floor:
		if _was_on_floor:
			_peak_y = global_position.y
		_peak_y = maxf(_peak_y, global_position.y)
	elif not _was_on_floor:
		var fall := _peak_y - global_position.y
		if fall > SAFE_FALL:
			take_damage(int(fall - SAFE_FALL))
	_was_on_floor = on_floor


func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	health = maxi(health - amount, 0)
	damaged.emit(amount)
	health_changed.emit(health, max_health)
	if health == 0:
		_die()


func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


## Eats one Meat for MEAT_HEAL health. Returns false if you can't.
func eat() -> bool:
	if health >= max_health or not inventory.take(Blocks.MEAT):
		return false
	heal(MEAT_HEAL)
	return true


func _die() -> void:
	died.emit()
	respawn()


func respawn() -> void:
	global_position = spawn_point
	velocity = Vector3.ZERO
	_peak_y = spawn_point.y
	_was_on_floor = false
	health = max_health
	health_changed.emit(health, max_health)


# ---------------------------------------------------------------- progression

## XP needed to finish the current level.
func xp_needed() -> int:
	return 10 * level


func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		max_health = BASE_HEALTH + HEALTH_PER_LEVEL * (level - 1)
		health = max_health   # levelling up is a full heal
		health_changed.emit(health, max_health)
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_needed(), level)


# ---------------------------------------------------------------- combat

## Left click: punch a creature if one is under the crosshair and close,
## otherwise break the block.
func _attack_or_break() -> void:
	var target := _aim_creature()
	if target != null:
		if _punch_cooldown > 0.0:
			return
		_punch_cooldown = PUNCH_COOLDOWN
		target.take_hit(PUNCH_DAMAGE, global_position, self)
		return
	_break_block()


## The creature under the crosshair within punching range, or null.
func _aim_creature() -> Creature:
	var from := _camera.global_position
	var to := from + (-_camera.global_basis.z) * (PUNCH_RANGE + _arm.spring_length)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = 3   # blocks AND creatures, so walls shield them
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var creature := hit.collider as Creature
	if creature == null:
		return null
	if creature.global_position.distance_to(global_position) > PUNCH_RANGE + 0.5:
		return null
	return creature


# ---------------------------------------------------------------- block editing

## Shoots a ray from the camera through the crosshair and returns what it
## hit (a dictionary with "position" and "normal"), or an empty one.
func _aim_ray() -> Dictionary:
	var from := _camera.global_position
	var to := from + (-_camera.global_basis.z) * (REACH + _arm.spring_length)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = 1   # blocks only; creatures live on layer 2
	return get_world_3d().direct_space_state.intersect_ray(query)


func _update_highlight() -> void:
	var hit := _aim_ray()
	if hit.is_empty():
		_highlight.visible = false
		return
	var block := Vector3i((hit.position - hit.normal * 0.5).floor())
	_highlight.visible = true
	_highlight.global_position = Vector3(block) + Vector3(0.5, 0.5, 0.5)


func _break_block() -> void:
	var hit := _aim_ray()
	if hit.is_empty():
		return
	# Step half a block INTO the face we hit to land inside that block.
	var block := Vector3i((hit.position - hit.normal * 0.5).floor())
	var id := world.get_block(block.x, block.y, block.z)
	if id == Blocks.AIR:
		return
	world.set_block(block.x, block.y, block.z, Blocks.AIR)
	inventory.add(id)   # the block goes in your pocket


func _place_block() -> void:
	var hit := _aim_ray()
	if hit.is_empty():
		return
	# Step half a block OUT of the face we hit to land in the empty neighbour.
	var block := Vector3i((hit.position + hit.normal * 0.5).floor())
	if _overlaps_player(block):
		return
	var id: int = Blocks.HOTBAR[selected]
	if not inventory.take(id):
		return   # you don't have one to place
	world.set_block(block.x, block.y, block.z, id)


## True if placing a block here would trap us inside it.
func _overlaps_player(block: Vector3i) -> bool:
	var p := global_position
	var half := 0.3
	return (block.x + 1 > p.x - half and block.x < p.x + half
		and block.y + 1 > p.y and block.y < p.y + 1.3
		and block.z + 1 > p.z - half and block.z < p.z + half)
