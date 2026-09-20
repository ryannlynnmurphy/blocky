class_name DebugActor
extends CharacterBody3D
## B4: a minimal, autonomous (no input handling) walker that follows an
## ordered list of world-space waypoints -- e.g. CityBlock.get_route() --
## at a fixed walk speed. Exists to prove B4's literal acceptance check ("a
## debug actor must be able to travel between locations") and, looking
## ahead, is the movement primitive Layer 5's residents (S4/S5) will need
## for their home/work/food routines: same shape, different route source.
##
## Deliberately does NOT implement teleport_to() -- scripts/city_block.gd's
## door/interior Area3D triggers only act on bodies with that method (see
## CityWalker.teleport_to() and the guard in CityBlock._add_transition()),
## so this actor safely ignores them and stays on the street/park surface
## instead of falling into a building's teleport-only interior pocket.
## That guard already existing is what makes this safe without any extra
## work here.
##
## Self-contained: adds its own collision capsule in _ready() using the
## same measured values as CityWalker/tools/city_block_check.gd (radius
## 0.25, height 1.1, offset 0.55 -- see the board's 2026-09-20 CORRECTION
## entry for why those specific numbers, not the "height + 2*radius"
## formula an earlier entry wrongly stated).

const WALK_SPEED := 4.5    # matches CityWalker.WALK_SPEED
const GRAVITY := 22.0      # matches CityWalker.GRAVITY
const ARRIVE_DIST := 0.5   # horizontal distance that counts as "reached" a waypoint

## The waypoints currently being followed, and whether the last one has
## been reached (both public so a driving tool/behavior can inspect
## progress without reaching into private state).
var route: Array = []
var route_complete := true

var _route_index := 0

## Fires once, on the physics frame the final waypoint is reached.
signal route_finished


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 1.1
	shape.shape = cap
	shape.position = Vector3(0, 0.55, 0)
	add_child(shape)


## S4: attaches the same blocky-human rig/tinting the player and the
## creator's live preview use (PersonAppearance.make_preview()), so a
## resident visibly matches its own PersonProfile instead of being a bare
## capsule. No extra vertical offset needed -- confirmed with a recorded
## screenshot (checked, not assumed), the rig's own root already sits with
## feet at its local origin at PersonAppearance's 1.08 scale, matching
## this actor's own feet-at-origin convention (same as CityWalker/the
## player) with no correction required.
var _model: Node3D = null

## A0: the resident's own name, so a UI (the context interaction menu)
## can say who's in range, not just that someone is. Set from the exact
## same profile dict build_appearance() already receives -- no separate
## profile lookup needed for something this actor is already handed.
var display_name := ""


func build_appearance(profile: Dictionary) -> void:
	if _model:
		_model.queue_free()
	_model = PersonAppearance.make_preview(profile)
	add_child(_model)
	display_name = str(profile.get("identity", {}).get("name", "")).strip_edges()


## Starts (or replaces) the ordered waypoints this actor walks toward. An
## empty or single-point route counts as already complete -- there is
## nowhere left to walk to.
func follow_route(new_route: Array) -> void:
	route = new_route
	_route_index = 0
	route_complete = route.size() <= 1


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if route_complete or route.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var target: Vector3 = route[_route_index]
	var to_target := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	# Skip past any waypoint already reached (e.g. two markers that happen to
	# coincide) so a single close call doesn't stall progress toward the
	# next real target.
	while to_target.length() < ARRIVE_DIST and _route_index < route.size() - 1:
		_route_index += 1
		target = route[_route_index]
		to_target = Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)

	if to_target.length() < ARRIVE_DIST and _route_index == route.size() - 1:
		route_complete = true
		velocity.x = 0.0
		velocity.z = 0.0
		route_finished.emit()
	else:
		var dir := to_target.normalized()
		velocity.x = dir.x * WALK_SPEED
		velocity.z = dir.z * WALK_SPEED

	move_and_slide()
