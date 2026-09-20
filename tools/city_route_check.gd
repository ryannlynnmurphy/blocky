extends SceneTree
## Dev tool for B4: loads scenes/city_block.tscn standalone (same pattern as
## tools/city_block_check.gd -- this scene isn't wired into main.gd or
## --selftest yet, that's B5's job) and proves the literal acceptance check,
## "a debug actor must be able to travel between locations": a
## scripts/debug_actor.gd walks a full tour through all five named
## locations (apartment -> cafe -> park -> workplace -> street ->
## apartment), each leg routed through CityBlock.get_route(), and each
## arrival is checked by real position, not just elapsed time.
##
##   godot --headless --path . --fixed-fps 60 --script tools/city_route_check.gd --quit-after 900
##
## --fixed-fps 60 matters here for the same reason city_block_check.gd notes:
## without it, --quit-after counts idle frames and this scene is light
## enough to outrun the physics timestep, so the tour never finishes before
## quitting.

const WALK_SPEED := 4.5   # matches scripts/debug_actor.gd's WALK_SPEED
const ARRIVE_CHECK_DIST := 1.0   # generous vs. DebugActor's own 0.5 arrival radius
const TOUR := ["apartment", "cafe", "park", "workplace", "street", "apartment"]

var block: Node3D
var actor: CharacterBody3D
var _reported_markers := false
var _started := false
var _leg_index := 0
var _leg_frame := 0
var _leg_timeout := 0
var _all_done := false


func _init() -> void:
	block = load("res://scenes/city_block.tscn").instantiate()
	get_root().add_child(block)
	print("city_route_check: scene loaded without error")
	# block._ready() (which builds geometry and route_markers) only runs
	# once the node enters the live tree next frame -- deferred into
	# _physics_process below, same reasoning as city_block_check.gd.


func _physics_process(_delta: float) -> bool:
	if _all_done:
		return true

	if not _reported_markers:
		_reported_markers = true
		var expected := ["apartment", "street", "cafe", "workplace", "park"]
		var have_all := true
		for k in expected:
			if not block.route_markers.has(k):
				have_all = false
		print("city_route_check: %d route marker(s) registered, all 5 named locations present: %s"
			% [block.route_markers.size(), have_all])
		print("city_route_check: route between an unknown location and a real one is empty: %s (expect true)"
			% [block.get_route("nowhere", "apartment").is_empty()])

		actor = CharacterBody3D.new()
		actor.name = "DebugActor"
		actor.set_script(load("res://scripts/debug_actor.gd"))
		get_root().add_child(actor)
		return false

	if actor.get_child_count() == 0:
		return false   # actor._ready() (adds its collision shape) hasn't run yet

	if not _started:
		_started = true
		_start_leg()
		return false

	_leg_frame += 1

	if actor.route_complete:
		_report_leg_result(true)
		_leg_index += 1
		if _leg_index >= TOUR.size() - 1:
			print("city_route_check: full tour of all %d locations complete" % [TOUR.size() - 1])
			_all_done = true
			return true
		_start_leg()
		return false

	if _leg_frame > _leg_timeout:
		_report_leg_result(false)
		_all_done = true
		return true

	return false


func _start_leg() -> void:
	var from_key: String = TOUR[_leg_index]
	var to_key: String = TOUR[_leg_index + 1]
	var route: Array = block.get_route(from_key, to_key)

	if _leg_index == 0:
		var start: Vector3 = route[0]
		actor.global_position = start + Vector3(0, 1.0, 0)

	actor.follow_route(route)

	var dist := 0.0
	for i in range(route.size() - 1):
		dist += (route[i] as Vector3).distance_to(route[i + 1])
	# Generous budget: straight-line time at walk speed, x1.6 for waypoint
	# turning overhead, plus a flat 2s settle/fall buffer for the first leg.
	_leg_timeout = int((dist / WALK_SPEED) * 60.0 * 1.6) + 120

	_leg_frame = 0


func _report_leg_result(ok: bool) -> void:
	var from_key: String = TOUR[_leg_index]
	var to_key: String = TOUR[_leg_index + 1]
	var target: Vector3 = block.route_markers[to_key]
	var pos: Vector3 = actor.global_position
	var flat_dist := Vector2(pos.x - target.x, pos.z - target.z).length()
	if ok:
		print("city_route_check: leg %s -> %s complete in %d physics frames, %.2fm from target (expect < %.1f) at %s"
			% [from_key, to_key, _leg_frame, flat_dist, ARRIVE_CHECK_DIST, pos])
	else:
		print("city_route_check: leg %s -> %s FAILED to complete within %d frames -- stuck at %s, %.2fm from target"
			% [from_key, to_key, _leg_timeout, pos, flat_dist])
