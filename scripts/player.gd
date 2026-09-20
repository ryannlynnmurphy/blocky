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
signal breath_changed(breath: int, max_breath: int)
signal break_progress_changed(progress: float)   # 0..1 while holding on a block
signal workbench_used   # right-clicked a Workbench block
signal furnace_used   # right-clicked a Furnace block
signal sleep_requested   # right-clicked a Bed block
signal tool_broke(item_name: String)   # a tool/weapon ran out of durability
signal durability_changed   # any tool/weapon's remaining durability ticked down

const WALK_SPEED := 4.5
const RUN_SPEED := 7.5
const JUMP_SPEED := 7.5
const GRAVITY := 22.0
const MOUSE_SENS := 0.0025
# ---- swimming ----
# The visual water surface (water_tile.glb props, see world_gen.gd's
# WATER_TILE_Y) sits at y=19.9, just under the top of the sea-level block —
# matches WorldGen.SEA_LEVEL (19) + 0.9. Gameplay uses this constant
# directly rather than reading it off any placed tile.
const WATER_SURFACE_Y := WorldGen.SEA_LEVEL + 0.9
const SWIM_SPEED := 3.0
## Holding Shift plus a direction while fully underwater is an active swim:
## faster than wading, and follows the camera's up/down angle so looking down
## lets the player dive and looking up lets them climb without surface-walking.
const SWIM_SPRINT_SPEED := 5.0
const SWIM_RISE_SPEED := 3.0
const WATER_GRAVITY := 4.0   # much gentler than GRAVITY — you sink slowly, not drop
# Swim-up caps just under WATER_SURFACE_Y (not AT it — resting exactly on
# the strict "<" threshold would itself read as "not in water" next frame).
const WATER_SURFACE_CEILING := WATER_SURFACE_Y - 0.05
var _in_water := false
# ---- breath / drowning ----
# Separate from _in_water (feet-in-water, drives swim physics): this is
# "is your HEAD under the surface", checked at the camera pivot's height
# (CameraPivot sits at local y=1.54, our best stand-in for eye level)
# rather than the feet, so wading in shin-deep water never costs breath.
const MAX_BREATH := 10
const BREATH_DRAIN_SECONDS := 1.4   # seconds per breath point lost, submerged
const BREATH_REGEN_SECONDS := 0.4   # seconds per breath point regained, surfaced
const DROWN_SECONDS := 2.0          # seconds per health point lost at 0 breath
var breath := MAX_BREATH
var head_submerged := false   # public: main.gd reads this to drive Sfx.set_underwater
# Separate drain/regen timers (not one shared one) — same reason
# _tick_hunger keeps _hunger_timer/_regen_timer/_starve_timer apart: a
# shared timer would carry leftover time from one phase into the other
# the instant you surface or dive, causing a burst of bogus extra ticks.
var _breath_drain_timer := 0.0
var _breath_regen_timer := 0.0
var _drown_timer := 0.0
const REACH := 6.0   # how far you can break/place, in blocks
const PUNCH_RANGE := 3.0
const PUNCH_DAMAGE := 1
const PUNCH_COOLDOWN := 0.35
const SWORD_DAMAGE := 4
const SWORD_COOLDOWN := 0.5   # slower but harder-hitting than a bare punch

var _punch_cooldown := 0.0

## Remaining uses for a tool/weapon that's taken damage; a tool not in
## here is still at full health (Blocks.max_durability(id)). Cleared on
## a fresh game, but NOT on respawn — dying doesn't repair your tools.
var tool_durability := {}

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
var selected := 0    # selected hotbar slot (inventory slots 0-8)
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

## Built by _build_model() at the start of _ready() (not @onready: these
## nodes don't exist yet at @onready time, since the whole point is that
## Model starts empty and the rig is assembled from player.glb in code).
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _sword: Node3D   # visible only while Blocks.SWORD is the held item
## Visual identity comes from Create a Person. Gameplay code never depends on
## it, which keeps the same player controller usable for every appearance.
var _person_profile: Dictionary = PersonProfile.default_data()

var _walk_cycle := 0.0    # advances while walking; drives the limb swing
var _punch_timer := 0.0   # while > 0 the right arm is thrown forward
var _step_sign := 1.0     # which leg is forward; a footstep sounds when it flips
var _tick_timer := 0.0    # spacing between digging tick sounds

const BASE_FOV := 70.0
const RUN_FOV := 78.0     # the camera widens a little while sprinting
const RUN_LEAN := 0.11    # radians of forward lean while sprinting

# ---- jump pose (airborne, not mid-stride) ----
const AIR_LEG_SWING := 0.65   # legs scissor-kick opposite each other while airborne
const AIR_CYCLE_SPEED := 7.0  # radians/sec, independent of horizontal speed so
                               # the legs keep alternating even jumping straight up
const JUMP_POSE_SPEED := 15.0   # snappier snap into the pose

# ---- run bob (extra vertical bounce while moving; bigger while sprinting) ----
const WALK_BOB := 0.03
const RUN_BOB := 0.08

# ---- camera view mode ----
var first_person := false
const TP_ARM_OFFSET := Vector3(0.55, 0.15, 0)   # over-the-shoulder, from player.tscn
const FP_ARM_OFFSET := Vector3(0.0, 0.15, 0)    # centered, at the same eye height
const TP_SPRING_LENGTH := 4.0
const FP_SPRING_LENGTH := 0.0

## Tests drive movement through these when input is locked out.
var test_move := Vector2.ZERO
var test_run := false
var test_hold_break := false
var test_swim_up := false
var test_jump := false   # one-shot: set true for a frame to trigger a jump

var _knock := Vector3.ZERO   # shove from being hit; fades out

# ---- breaking blocks takes time ----
const NO_TARGET := Vector3i(1 << 20, 0, 0)
var _break_target := NO_TARGET
var _break_progress := 0.0
var _mining := false   # arm keeps swinging while true


func _ready() -> void:
	_build_model()
	_setup_input_actions()
	_arm.add_excluded_object(get_rid())   # camera arm ignores our own body
	_pivot.rotation.y = _yaw
	_arm.rotation.x = _pitch
	# Testing aid: `-- --no-input` locks the camera and ignores clicks/keys.
	_no_input = "--no-input" in OS.get_cmdline_user_args()
	if not _no_input:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------- model

const PLAYER_GLB := preload("res://blocky/models/player.glb")
const SWORD_GLB := preload("res://blocky/models/short_sword.glb")
const MODEL_HEIGHT := 2.0   # visual height: a two-block-tall player; the
                            # source asset is authored at real human scale
                            # (~1.85 m)
const BODY_HEIGHT := 1.8   # actual collision capsule height (see player.tscn)
                            # — deliberately a bit under two blocks, or the
                            # capsule exactly fills a 2-tall passage with zero
                            # clearance and catches on the ceiling
const SWORD_SCALE := 0.42   # extra shrink so a "short" sword looks short on us

## Parts that don't animate on their own: everything except the four limbs.
const STATIC_PARTS := ["torso", "belt", "buckle", "head",
	"hair_cap", "hair_shard_main", "hair_shard_side", "hair_shard_bang",
	"hair_brow", "hair_lock_front", "hair_back", "hair_side_L", "hair_side_R",
	"eye_L", "eye_R"]

## Assembles the player's visible model from player.glb: rigs the four
## limbs onto rotation pivots (so the walk animation can swing them),
## moves everything else onto Model directly, scales the whole thing
## down to our chunky character height, and hangs a sword off the hand.
func _build_model() -> void:
	var rig: Node3D = PLAYER_GLB.instantiate()
	_model.add_child(rig)   # so global positions below are meaningful

	var head := rig.find_child("head", true, false) as MeshInstance3D
	var head_aabb := head.get_aabb()
	var head_top: float = head.global_position.y + head_aabb.position.y + head_aabb.size.y
	var scale_factor: float = MODEL_HEIGHT / head_top

	_arm_l = _rig_limb(rig, "arm_L", ["hand_L"])
	_arm_r = _rig_limb(rig, "arm_R", ["hand_R"])
	_leg_l = _rig_limb(rig, "leg_L", ["boot_L"])
	_leg_r = _rig_limb(rig, "leg_R", ["boot_R"])

	for part_name in STATIC_PARTS:
		_move_to(rig.find_child(part_name, true, false), _model)

	rig.queue_free()   # empty shell (plus any import wrapper node) left behind
	_model.scale = Vector3(scale_factor, scale_factor, scale_factor)

	# A sword, held loosely at the character's side. Its own local origin
	# sits at the pommel with the blade pointing up, so flipping it 180
	# hangs the blade down beside the hand. Only shown while Blocks.SWORD
	# is actually the held item (see _physics_process). It's authored at
	# ~1.7 units (most of our real human-scale source asset's height)
	# because the asset assumes a real human-scale wearer, so it needs its
	# own extra scale-down on top of the body's, or the blade drives into
	# the ground when it hangs.
	_sword = SWORD_GLB.instantiate()
	var hand_r: Node = _arm_r.find_child("hand_R", true, false)
	hand_r.add_child(_sword)
	_sword.rotation.x = PI
	_sword.scale = Vector3.ONE * SWORD_SCALE
	_sword.visible = false
	PersonAppearance.apply_to(_model, _person_profile)


func set_person_profile(profile: Dictionary) -> void:
	_person_profile = profile.duplicate(true)
	if is_instance_valid(_model):
		PersonAppearance.apply_to(_model, _person_profile)


## Makes a pivot at the top-centre of `upper_name` (where that limb
## joins the body) and moves it, plus everything named in `hanging`,
## underneath it — keeping their appearance exactly as authored.
## Rotating the returned pivot swings the whole limb from that joint.
func _rig_limb(rig: Node3D, upper_name: String, hanging: Array) -> Node3D:
	var upper := rig.find_child(upper_name, true, false) as MeshInstance3D
	var aabb := upper.get_aabb()
	var top_y: float = upper.global_position.y + aabb.position.y + aabb.size.y
	var pivot := Node3D.new()
	_model.add_child(pivot)
	pivot.global_position = Vector3(upper.global_position.x, top_y, upper.global_position.z)
	for part_name in ([upper_name] + hanging):
		_move_to(rig.find_child(part_name, true, false), pivot)
	return pivot


## Reparents `part` under `new_parent`, keeping its world transform
## (position *and* rotation — a few of the hair pieces are rotated).
func _move_to(part: Node3D, new_parent: Node3D) -> void:
	var t := part.global_transform
	part.get_parent().remove_child(part)
	new_parent.add_child(part)
	part.global_transform = t


## Points the camera. Used by tests; the mouse handler does the same thing.
func set_look(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = clampf(pitch, -1.3, 0.8)
	_pivot.rotation.y = _yaw
	_arm.rotation.x = _pitch


func toggle_view() -> void:
	set_first_person(not first_person)


## Swings the camera onto the player's shoulder, or right up to their eyes.
## First-person hides the body model — otherwise you'd be staring at the
## inside of your own head.
func set_first_person(fp: bool) -> void:
	first_person = fp
	_arm.position = FP_ARM_OFFSET if fp else TP_ARM_OFFSET
	_arm.spring_length = FP_SPRING_LENGTH if fp else TP_SPRING_LENGTH
	_model.visible = not fp


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
		return   # Esc / Tab are handled by main.gd's screen state machine

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
		if n >= 0 and n < Inventory.HOTBAR:
			select_slot(n)
		elif key.keycode == KEY_E:
			eat()
		elif key.keycode == KEY_V:
			toggle_view()


## Picks a hotbar slot; wraps around at both ends (for the scroll wheel).
func select_slot(index: int) -> void:
	selected = posmod(index, Inventory.HOTBAR)
	hotbar_changed.emit(selected)


## What's in the selected hotbar slot (AIR if nothing).
func held_id() -> int:
	return inventory.id_at(selected)


func _physics_process(delta: float) -> void:
	_punch_cooldown = maxf(_punch_cooldown - delta, 0.0)
	_in_water = global_position.y < WATER_SURFACE_Y
	if _in_water:
		# Sink gently instead of dropping, and cap the sink speed so
		# swimming back up always wins — holding jump rises.
		velocity.y = maxf(velocity.y - WATER_GRAVITY * delta, -SWIM_SPEED)
		if test_swim_up or (not _no_input and Input.is_action_pressed("jump")):
			velocity.y = SWIM_RISE_SPEED
			# Swim-up alone must never carry you ABOVE the surface. Left
			# uncapped, holding jump set velocity.y to the same constant
			# rise speed every single frame (not a one-time impulse), so
			# each frame's climb popped just past WATER_SURFACE_Y, flipped
			# _in_water off for an instant, and handed back real gravity
			# and full walk/run speed for that instant — repeated every
			# frame while holding jump + a move key, that reads as smooth
			# walking across the surface instead of swimming. Now it caps
			# right at the surface instead of crossing it.
			if global_position.y + velocity.y * delta > WATER_SURFACE_CEILING:
				velocity.y = (WATER_SURFACE_CEILING - global_position.y) / delta
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif test_jump or (not _no_input and Input.is_action_just_pressed("jump")):
		velocity.y = JUMP_SPEED
		test_jump = false

	# Movement is relative to where the camera is looking.
	var input := test_move
	var run_held := test_run
	if not _no_input and not ui_open:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		run_held = Input.is_action_pressed("run")
	var horizontal_dir := (_pivot.global_basis * Vector3(input.x, 0, input.y))
	horizontal_dir.y = 0
	horizontal_dir = horizontal_dir.normalized()
	var moving := input.length() > 0.1
	var running := run_held and moving
	# The camera's basis includes pitch; use it only for deliberate underwater
	# sprint-swimming. Normal water movement stays horizontal so shallow water
	# remains easy to navigate and Space remains the reliable surface control.
	var fully_submerged := _pivot.global_position.y < WATER_SURFACE_Y
	var actively_swimming := _in_water and fully_submerged and running
	var swim_dir := (_camera.global_basis.x * input.x + _camera.global_basis.z * input.y).normalized()
	var speed := SWIM_SPRINT_SPEED if actively_swimming else (SWIM_SPEED if _in_water else (RUN_SPEED if running else WALK_SPEED))
	if actively_swimming:
		velocity.x = swim_dir.x * speed + _knock.x
		velocity.y = swim_dir.y * speed
		velocity.z = swim_dir.z * speed + _knock.z
	else:
		velocity.x = horizontal_dir.x * speed + _knock.x
		velocity.z = horizontal_dir.z * speed + _knock.z
	_knock = _knock.move_toward(Vector3.ZERO, 25.0 * delta)

	move_and_slide()
	_check_fall_damage()

	# Turn the model to face the way we're walking; lean into a sprint.
	if horizontal_dir.length() > 0.1:
		var target := atan2(-horizontal_dir.x, -horizontal_dir.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target, 12.0 * delta)
	_model.rotation.x = lerp_angle(_model.rotation.x, -RUN_LEAN if running else 0.0, 8.0 * delta)
	_camera.fov = lerpf(_camera.fov, RUN_FOV if running else BASE_FOV, 6.0 * delta)

	var holding := test_hold_break
	if not _no_input:
		holding = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not ui_open
	_update_breaking(delta, holding)
	_animate_limbs(delta, moving and is_on_floor(), speed, running, is_on_floor())
	_tick_hunger(delta, running)
	_tick_breath(delta)
	_update_highlight()
	_sword.visible = held_id() == Blocks.SWORD


## The block under your feet decides what a step sounds like.
func _footstep(running: bool) -> void:
	var p := global_position
	var id := world.get_block(int(floor(p.x)), int(floor(p.y - 0.1)), int(floor(p.z)))
	var name := "step_grass"
	match id:
		Blocks.SAND: name = "step_sand"
		Blocks.STONE: name = "step_stone"
		Blocks.SNOW: name = "step_snow"
		Blocks.LOG, Blocks.PLANKS, Blocks.WORKBENCH: name = "step_wood"
	Sfx.play(name, null, 0.15, -3.0 if running else -8.0)


## Swings arms and legs while walking or sprinting (wider, faster swing plus
## a vertical bob while running); scissor-kicks the legs opposite each other
## while airborne, with each arm swinging opposite its own leg (same
## contralateral pattern as a normal stride) instead of freezing mid-stride;
## throws the right arm on a punch. Limb pivots sit at the shoulder/hip, and
## a positive X rotation moves the hand or foot forward (toward the model's -Z).
func _animate_limbs(delta: float, walking: bool, speed: float, running: bool, on_floor: bool) -> void:
	var airborne := not on_floor and not _in_water
	if walking:
		_walk_cycle += delta * speed * 2.2
		# Each time the legs cross, a foot lands.
		var s := signf(sin(_walk_cycle))
		if s != 0.0 and s != _step_sign:
			_step_sign = s
			_footstep(running)
	elif airborne:
		# Keeps alternating even on a straight-up jump with no horizontal speed.
		_walk_cycle += delta * AIR_CYCLE_SPEED

	var amplitude := 0.75 if running else 0.43
	var swing := 0.0
	if walking:
		swing = sin(_walk_cycle) * amplitude
	elif airborne:
		swing = sin(_walk_cycle) * AIR_LEG_SWING
	var k := (18.0 if running else 12.0) * delta

	if airborne:
		var jk := JUMP_POSE_SPEED * delta
		_leg_l.rotation.x = lerp_angle(_leg_l.rotation.x, swing, jk)
		_leg_r.rotation.x = lerp_angle(_leg_r.rotation.x, -swing, jk)
		# Arms alternate opposite the leg on the same side, same as a normal
		# stride, just carried on into the air.
		_arm_l.rotation.x = lerp_angle(_arm_l.rotation.x, -swing, jk)
	else:
		_arm_l.rotation.x = lerp_angle(_arm_l.rotation.x, swing, k)
		_leg_l.rotation.x = lerp_angle(_leg_l.rotation.x, -swing, k)
		_leg_r.rotation.x = lerp_angle(_leg_r.rotation.x, swing, k)

	if _mining:
		# Repeated chopping swing while holding on a block.
		_arm_r.rotation.x = 1.0 + sin(Time.get_ticks_msec() / 1000.0 * 18.0) * 0.5
	elif _punch_timer > 0.0:
		_punch_timer -= delta
		_arm_r.rotation.x = lerp_angle(_arm_r.rotation.x, 1.5, 30.0 * delta)
	elif airborne:
		_arm_r.rotation.x = lerp_angle(_arm_r.rotation.x, swing, JUMP_POSE_SPEED * delta)
	else:
		_arm_r.rotation.x = lerp_angle(_arm_r.rotation.x, -swing, k)

	# A little extra bounce on top of the lean while sprinting sells the
	# "sprint feel" beyond just the faster limb swing.
	var bob_target := absf(sin(_walk_cycle)) * (RUN_BOB if running else WALK_BOB) if walking else 0.0
	_model.position.y = lerp(_model.position.y, bob_target, k)


# ---------------------------------------------------------------- health

## Remembers the top of each fall; landing from higher than SAFE_FALL
## costs one health per extra block. Water cushions a fall completely —
## it counts as a safe "landing" the moment you enter it, same as touching
## solid ground, so diving in from a cliff never hurts, and swimming down
## to touch the seabed afterward doesn't retroactively charge the drop.
func _check_fall_damage() -> void:
	if _in_water:
		_peak_y = global_position.y
		_was_on_floor = true
		return
	var on_floor := is_on_floor()
	if not on_floor:
		if _was_on_floor:
			_peak_y = global_position.y
		_peak_y = maxf(_peak_y, global_position.y)
	elif not _was_on_floor:
		var fall := _peak_y - global_position.y
		if fall > 1.2:
			Sfx.play("land", null, 0.1, clampf(-16.0 + fall * 2.0, -16.0, -2.0))
		# Rounded, not truncated: a 3.5-block drop already costs 1.
		var damage := roundi(fall - SAFE_FALL)
		if damage > 0:
			take_damage(damage)
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
	Sfx.play("hurt", null, 0.15)
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
	Sfx.play("eat")
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


## Breath drains while the head is underwater and refills once it isn't;
## out of breath and still under costs health every DROWN_SECONDS, same
## shape as _tick_hunger's starve timer.
func _tick_breath(delta: float) -> void:
	head_submerged = _pivot.global_position.y < WATER_SURFACE_Y
	if head_submerged:
		_breath_regen_timer = 0.0
		_breath_drain_timer += delta
		if _breath_drain_timer >= BREATH_DRAIN_SECONDS:
			_breath_drain_timer -= BREATH_DRAIN_SECONDS
			if breath > 0:
				breath -= 1
				breath_changed.emit(breath, MAX_BREATH)
		if breath == 0:
			_drown_timer += delta
			if _drown_timer >= DROWN_SECONDS:
				_drown_timer -= DROWN_SECONDS
				take_damage(1)
		else:
			_drown_timer = 0.0
	else:
		_drown_timer = 0.0
		_breath_drain_timer = 0.0
		if breath < MAX_BREATH:
			_breath_regen_timer += delta
			if _breath_regen_timer >= BREATH_REGEN_SECONDS:
				_breath_regen_timer -= BREATH_REGEN_SECONDS
				breath += 1
				breath_changed.emit(breath, MAX_BREATH)
		else:
			_breath_regen_timer = 0.0


## Announces the death; main.gd shows the death screen and calls
## respawn() when the player chooses to.
func _die() -> void:
	Sfx.play("died")
	died.emit()


## Back to square one for a New Game.
func reset_for_new_game() -> void:
	inventory.clear()
	level = 1
	xp = 0
	max_health = BASE_HEALTH
	selected = 0
	tool_durability.clear()
	set_look(0.0, -0.3)
	respawn()
	xp_changed.emit(xp, xp_needed(), level)
	hotbar_changed.emit(selected)


func respawn() -> void:
	global_position = spawn_point
	velocity = Vector3.ZERO
	_peak_y = spawn_point.y
	_was_on_floor = false
	health = max_health
	health_changed.emit(health, max_health)
	hunger = MAX_HUNGER
	hunger_changed.emit(hunger, MAX_HUNGER)
	breath = MAX_BREATH
	breath_changed.emit(breath, MAX_BREATH)


# ---------------------------------------------------------------- saving

func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": _yaw,
		"pitch": _pitch,
		"health": health,
		"max_health": max_health,
		"hunger": hunger,
		"breath": breath,
		"level": level,
		"xp": xp,
		"selected": selected,
		"inventory": inventory.to_dict(),
		"tool_durability": tool_durability,
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
	breath = int(d.get("breath", MAX_BREATH))
	selected = int(d.get("selected", 0))
	inventory.from_dict(d.get("inventory", {}))
	# JSON round-trips dict keys as strings; back to int so lookups by id work.
	tool_durability.clear()
	for key in (d.get("tool_durability", {}) as Dictionary).keys():
		tool_durability[int(key)] = int(d["tool_durability"][key])
	# Tell the HUD.
	health_changed.emit(health, max_health)
	hunger_changed.emit(hunger, MAX_HUNGER)
	breath_changed.emit(breath, MAX_BREATH)
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
## A held Sword hits harder (but slower) than a bare fist, and wears
## down with use like any other tool. Blocks aren't broken by a click —
## you hold the button (see _update_breaking), so a click on a block
## just starts the swing.
func _attack_or_break() -> void:
	_punch_timer = 0.25   # arm swing, whatever we hit
	var target := _aim_creature()
	if target != null:
		if _punch_cooldown > 0.0:
			return
		var wielding_sword := held_id() == Blocks.SWORD
		_punch_cooldown = SWORD_COOLDOWN if wielding_sword else PUNCH_COOLDOWN
		target.take_hit(SWORD_DAMAGE if wielding_sword else PUNCH_DAMAGE, global_position, self)
		if wielding_sword:
			_use_tool(Blocks.SWORD)


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
	var centre := Vector3(block) + Vector3(0.5, 0.5, 0.5)
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = 0.22
		Sfx.play("tick", centre, 0.2, -4.0)
	if _break_progress >= 1.0:
		world.set_block(block.x, block.y, block.z, Blocks.AIR)
		Sfx.play("crack", centre, 0.15)
		if drops_when_broken(id):
			# Pops out as an item (ores turn into coal / iron).
			world.spawn_drop(Vector3(block) + Vector3(0.5, 0.1, 0.5), Blocks.drop_for(id))
		_use_tool(held_id())   # no-op unless what's held actually wears out
		_reset_breaking()
		return
	break_progress_changed.emit(_break_progress)


# ---------------------------------------------------------------- tools

## The tool in your hand, if it's the right class: [speed multiplier, tier].
## Hands (or the wrong tool) = [1, 0]. You have to be HOLDING it.
func best_tool(cls: String) -> Array:
	if cls == "":
		return [1.0, 0]
	var held := held_id()
	for tool in Blocks.TOOLS[cls]:
		if tool[0] == held:
			return [tool[1], tool[2]]
	return [1.0, 0]


## Speed factor from the best tool you own for this block (1.0 = hands).
func tool_multiplier(id: int) -> float:
	return best_tool(Blocks.tool_class(id))[0]


## Some blocks only drop when you have a good enough tool: stone and
## coal need any pickaxe, iron ore needs a stone pickaxe or better.
func drops_when_broken(id: int) -> bool:
	if not Blocks.NEEDS_TOOL.has(id):
		return true
	var need: Array = Blocks.NEEDS_TOOL[id]
	return best_tool(need[0])[1] >= need[1]


func tool_durability_left(id: int) -> int:
	return tool_durability.get(id, Blocks.max_durability(id))


## One use of a tool/weapon: a completed block break for pickaxes/axes,
## a landed hit for the sword. Items with no DURABILITY entry (0) never
## wear out and this is a no-op. Breaks and disappears from the
## inventory at 0, with a message.
func _use_tool(id: int) -> void:
	var max_d := Blocks.max_durability(id)
	if max_d <= 0:
		return
	var left: int = tool_durability_left(id) - 1
	if left <= 0:
		tool_durability.erase(id)
		inventory.take(id, 1)   # also emits inventory.changed, which refreshes the HUD
		tool_broke.emit(Blocks.NAMES[id])
	else:
		tool_durability[id] = left
		durability_changed.emit()




func _reset_breaking() -> void:
	if _break_progress > 0.0 or _mining:
		break_progress_changed.emit(0.0)
	_break_target = NO_TARGET
	_break_progress = 0.0
	_mining = false
	_tick_timer = 0.0


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
	# Right-clicking a Workbench or Furnace opens it, and a Bed sleeps,
	# instead of building on top of them.
	var target := Vector3i((hit.position - hit.normal * 0.5).floor())
	var target_id := world.get_block(target.x, target.y, target.z)
	if target_id == Blocks.WORKBENCH:
		workbench_used.emit()
		return
	if target_id == Blocks.FURNACE:
		furnace_used.emit()
		return
	if target_id == Blocks.BED:
		sleep_requested.emit()
		return
	# Step half a block OUT of the face we hit to land in the empty neighbour.
	var block := Vector3i((hit.position + hit.normal * 0.5).floor())
	if _overlaps_player(block):
		return
	var id := held_id()
	if not Blocks.is_block(id):
		return   # holding nothing, or a tool / item
	inventory.take_from_slot(selected, 1)
	world.set_block(block.x, block.y, block.z, id)
	Sfx.play("place", Vector3(block) + Vector3(0.5, 0.5, 0.5), 0.15)


## True if placing a block here would trap us inside it.
func _overlaps_player(block: Vector3i) -> bool:
	var p := global_position
	var half := 0.3
	return (block.x + 1 > p.x - half and block.x < p.x + half
		and block.y + 1 > p.y and block.y < p.y + BODY_HEIGHT
		and block.z + 1 > p.z - half and block.z < p.z + half)
