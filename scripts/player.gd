class_name Player
extends CharacterBody3D
## The character you control: movement, jumping, camera, and block editing.

signal hotbar_changed(index: int)
signal health_changed(health: int, max_health: int)
signal damaged(amount: int)
signal died
signal xp_changed(xp: int, xp_needed: int, level: int)
signal leveled_up(level: int)
signal hunger_changed(hunger: int, max_hunger: int)
signal break_progress_changed(progress: float)   # 0..1 while holding on a block

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

# ---- hunger ----
const MAX_HUNGER := 10
const MEAT_FOOD := 4              # hunger points one Meat restores
const HUNGER_DRAIN_SECONDS := 45.0   # seconds per hunger point lost
const RUN_HUNGER_MULT := 3.0      # sprinting burns food this much faster
const REGEN_HUNGER := 7           # at or above this, health regenerates
const REGEN_SECONDS := 4.0        # seconds per health point regained
const STARVE_SECONDS := 10.0      # seconds per health point lost at 0 hunger

var hunger := MAX_HUNGER
var _hunger_timer := 0.0
var _regen_timer := 0.0
var _starve_timer := 0.0

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
var ui_open := false     # a screen (inventory) is open: ignore game input

@onready var _pivot: Node3D = $CameraPivot
@onready var _arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var _camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var _model: Node3D = $Model
@onready var _highlight: MeshInstance3D = $Highlight
@onready var _arm_l: Node3D = $Model/ArmL
@onready var _arm_r: Node3D = $Model/ArmR
@onready var _leg_l: Node3D = $Model/LegL
@onready var _leg_r: Node3D = $Model/LegR

var _walk_cycle := 0.0    # advances while walking; drives the limb swing
var _punch_timer := 0.0   # while > 0 the right arm is thrown forward

const BASE_FOV := 70.0
const RUN_FOV := 80.0     # the camera widens a little while sprinting
const RUN_LEAN := 0.14    # radians of forward lean while sprinting

## Tests drive movement through these when input is locked out.
var test_move := Vector2.ZERO
var test_run := false
var test_hold_break := false

var _knock := Vector3.ZERO   # shove from being hit; fades out

# ---- breaking blocks takes time ----
const NO_TARGET := Vector3i(1 << 20, 0, 0)
var _break_target := NO_TARGET
var _break_progress := 0.0
var _mining := false   # arm keeps swinging while true


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
	if _no_input or ui_open:
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
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_slot(selected + 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_slot(selected - 1)

	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		var n := int(key.keycode) - int(KEY_1)
		if n >= 0 and n < Blocks.HOTBAR.size():
			select_slot(n)
		elif key.keycode == KEY_E:
			eat()


## Picks a hotbar slot; wraps around at both ends (for the scroll wheel).
func select_slot(index: int) -> void:
	selected = posmod(index, Blocks.HOTBAR.size())
	hotbar_changed.emit(selected)


func _physics_process(delta: float) -> void:
	_punch_cooldown = maxf(_punch_cooldown - delta, 0.0)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif not _no_input and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_SPEED

	# Movement is relative to where the camera is looking.
	var input := test_move
	var run_held := test_run
	if not _no_input and not ui_open:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		run_held = Input.is_action_pressed("run")
	var dir := (_pivot.global_basis * Vector3(input.x, 0, input.y))
	dir.y = 0
	dir = dir.normalized()
	var moving := dir.length() > 0.1
	var running := run_held and moving
	var speed := RUN_SPEED if running else WALK_SPEED
	velocity.x = dir.x * speed + _knock.x
	velocity.z = dir.z * speed + _knock.z
	_knock = _knock.move_toward(Vector3.ZERO, 25.0 * delta)

	move_and_slide()
	_check_fall_damage()

	# Turn the model to face the way we're walking; lean into a sprint.
	if moving:
		var target := atan2(-dir.x, -dir.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target, 12.0 * delta)
	_model.rotation.x = lerp_angle(_model.rotation.x, -RUN_LEAN if running else 0.0, 8.0 * delta)
	_camera.fov = lerpf(_camera.fov, RUN_FOV if running else BASE_FOV, 6.0 * delta)

	var holding := test_hold_break
	if not _no_input:
		holding = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not ui_open
	_update_breaking(delta, holding)
	_animate_limbs(delta, moving and is_on_floor(), speed, running)
	_tick_hunger(delta, running)
	_update_highlight()


## Swings arms and legs while walking; throws the right arm on a punch.
## Limb pivots sit at the shoulder/hip, and a positive X rotation moves
## the hand or foot forward (toward the model's -Z).
func _animate_limbs(delta: float, walking: bool, speed: float, running: bool) -> void:
	if walking:
		_walk_cycle += delta * speed * 2.2
	var amplitude := 1.1 if running else 0.7
	var swing := sin(_walk_cycle) * amplitude if walking else 0.0
	var k := 12.0 * delta
	_arm_l.rotation.x = lerp_angle(_arm_l.rotation.x, swing, k)
	_leg_l.rotation.x = lerp_angle(_leg_l.rotation.x, -swing, k)
	_leg_r.rotation.x = lerp_angle(_leg_r.rotation.x, swing, k)
	if _mining:
		# Repeated chopping swing while holding on a block.
		_arm_r.rotation.x = 1.0 + sin(Time.get_ticks_msec() / 1000.0 * 18.0) * 0.5
	elif _punch_timer > 0.0:
		_punch_timer -= delta
		_arm_r.rotation.x = lerp_angle(_arm_r.rotation.x, 1.5, 30.0 * delta)
	else:
		_arm_r.rotation.x = lerp_angle(_arm_r.rotation.x, -swing, k)


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


## A shove: sideways part fades over a few frames, upward part is a hop.
func apply_knockback(push: Vector3) -> void:
	_knock = Vector3(push.x, 0.0, push.z)
	if push.y > 0.0:
		velocity.y = push.y


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


## Eats one Meat for MEAT_FOOD hunger. Returns false if you can't
## (already full, or nothing to eat).
func eat() -> bool:
	if hunger >= MAX_HUNGER or not inventory.take(Blocks.MEAT):
		return false
	hunger = mini(hunger + MEAT_FOOD, MAX_HUNGER)
	hunger_changed.emit(hunger, MAX_HUNGER)
	return true


## Hunger slowly drains (faster when sprinting). Well fed = health
## regenerates; starving = health drains, but never below 1.
func _tick_hunger(delta: float, running: bool) -> void:
	_hunger_timer += delta * (RUN_HUNGER_MULT if running else 1.0)
	if _hunger_timer >= HUNGER_DRAIN_SECONDS:
		_hunger_timer -= HUNGER_DRAIN_SECONDS
		if hunger > 0:
			hunger -= 1
			hunger_changed.emit(hunger, MAX_HUNGER)

	if hunger >= REGEN_HUNGER and health < max_health:
		_regen_timer += delta
		if _regen_timer >= REGEN_SECONDS:
			_regen_timer -= REGEN_SECONDS
			heal(1)
	else:
		_regen_timer = 0.0

	if hunger == 0 and health > 1:
		_starve_timer += delta
		if _starve_timer >= STARVE_SECONDS:
			_starve_timer -= STARVE_SECONDS
			take_damage(1)
	else:
		_starve_timer = 0.0


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
	hunger = MAX_HUNGER
	hunger_changed.emit(hunger, MAX_HUNGER)


# ---------------------------------------------------------------- saving

func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": _yaw,
		"pitch": _pitch,
		"health": health,
		"max_health": max_health,
		"hunger": hunger,
		"level": level,
		"xp": xp,
		"selected": selected,
		"inventory": inventory.to_dict(),
	}


func load_save_data(d: Dictionary) -> void:
	var p: Array = d.get("position", [global_position.x, global_position.y, global_position.z])
	global_position = Vector3(p[0], p[1], p[2])
	velocity = Vector3.ZERO
	_peak_y = global_position.y
	_was_on_floor = false
	set_look(float(d.get("yaw", _yaw)), float(d.get("pitch", _pitch)))
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	max_health = int(d.get("max_health", BASE_HEALTH))
	health = int(d.get("health", max_health))
	hunger = int(d.get("hunger", MAX_HUNGER))
	selected = int(d.get("selected", 0))
	inventory.from_dict(d.get("inventory", {}))
	# Tell the HUD.
	health_changed.emit(health, max_health)
	hunger_changed.emit(hunger, MAX_HUNGER)
	xp_changed.emit(xp, xp_needed(), level)
	hotbar_changed.emit(selected)


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

## Left click: punch a creature if one is under the crosshair and close.
## Blocks aren't broken by a click — you hold the button (see
## _update_breaking), so a click on a block just starts the swing.
func _attack_or_break() -> void:
	_punch_timer = 0.25   # arm swing, whatever we hit
	var target := _aim_creature()
	if target != null:
		if _punch_cooldown > 0.0:
			return
		_punch_cooldown = PUNCH_COOLDOWN
		target.take_hit(PUNCH_DAMAGE, global_position, self)


## Called every physics frame with whether the break button is held.
## Progress builds while you keep aiming at the same block, at a rate set
## by that block's hardness; it resets if you let go or look elsewhere.
func _update_breaking(delta: float, holding: bool) -> void:
	if not holding or _aim_creature() != null:
		_reset_breaking()
		return
	var hit := _aim_ray()
	if hit.is_empty():
		_reset_breaking()
		return
	var block := Vector3i((hit.position - hit.normal * 0.5).floor())
	var id := world.get_block(block.x, block.y, block.z)
	if id == Blocks.AIR:
		_reset_breaking()
		return
	if block != _break_target:
		_break_target = block
		_break_progress = 0.0
	_mining = true
	_break_progress += delta * tool_multiplier(id) / Blocks.hardness(id)
	if _break_progress >= 1.0:
		world.set_block(block.x, block.y, block.z, Blocks.AIR)
		if drops_when_broken(id):
			world.spawn_drop(Vector3(block) + Vector3(0.5, 0.1, 0.5), id)   # pops out as an item
		_reset_breaking()
		return
	break_progress_changed.emit(_break_progress)


# ---------------------------------------------------------------- tools

## Speed factor from the best tool you own for this block (1.0 = hands).
## Tools aren't equipped; owning one is enough.
func tool_multiplier(id: int) -> float:
	var cls := Blocks.tool_class(id)
	if cls == "":
		return 1.0
	var best := 1.0
	for tool in Blocks.TOOLS[cls]:
		if inventory.count(tool[0]) > 0:
			best = maxf(best, tool[1])
	return best


## Some blocks (stone) only drop when you have the right kind of tool.
func drops_when_broken(id: int) -> bool:
	if not Blocks.NEEDS_TOOL.has(id):
		return true
	for tool in Blocks.TOOLS[Blocks.NEEDS_TOOL[id]]:
		if inventory.count(tool[0]) > 0:
			return true
	return false


## Is there a Workbench block within 3 blocks?
func near_workbench() -> bool:
	var c := Vector3i(global_position.floor())
	for dy in range(-2, 3):
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				if world.get_block(c.x + dx, c.y + dy, c.z + dz) == Blocks.WORKBENCH:
					return true
	return false


func _reset_breaking() -> void:
	if _break_progress > 0.0 or _mining:
		break_progress_changed.emit(0.0)
	_break_target = NO_TARGET
	_break_progress = 0.0
	_mining = false


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
	# The box darkens as the block gets closer to breaking.
	var mat: StandardMaterial3D = _highlight.get_surface_override_material(0)
	mat.albedo_color = Color(1, 1, 1, 0.25).lerp(Color(0.05, 0.05, 0.05, 0.7), _break_progress)


## Instant break, used by tests and dev tools. Play uses _update_breaking.
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
