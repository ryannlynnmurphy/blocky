extends SceneTree
## L1 (Work Orders Layer 6): "Scale scheduling from 1 to 3, 5, then 20
## residents. Done when: each population step is profiled and stable."
## Loads scenes/city_block.tscn standalone (same pattern as
## tools/city_block_check.gd) and, for each population size, spawns that
## many residents from L0's ResidentRoster, times both spawning them and
## driving a full goal-dispatch pass (ResidentRoutine.current_goal() +
## CityBlock.get_route() + DebugActor.follow_route() for every one of
## them, exactly what main.gd's _drive_all_city_residents() does on every
## real hour_changed), then frees them before the next size -- so each
## step's numbers are for that size alone, not cumulative.
##
##   godot --headless --path . --fixed-fps 60 --script tools/city_population_check.gd --quit-after 480

const POPULATIONS := [1, 3, 5, 20]
const SETTLE_FRAMES := 90   # let each batch's actors land on the ground before moving on

var block: Node3D
var _roster: Array[PersonProfile] = []
var _pop_index := 0
var _actors: Array[DebugActor] = []
var _locations: Array[String] = []
var _frame := 0
var _batch_start_frame := 0
var _errors: Array[String] = []


func _init() -> void:
	block = load("res://scenes/city_block.tscn").instantiate()
	get_root().add_child(block)
	_roster = ResidentRoster.build()
	print("city_population_check: scene loaded, roster built (%d available)" % [_roster.size()])


func _physics_process(_delta: float) -> bool:
	if _pop_index >= POPULATIONS.size():
		if _errors.is_empty():
			print("CITY_POPULATION_CHECK OK: all %d population steps spawned, dispatched, and freed cleanly" % [POPULATIONS.size()])
		else:
			for e in _errors:
				printerr("CITY_POPULATION_CHECK FAIL: " + e)
		return true

	_frame += 1
	var elapsed := _frame - _batch_start_frame

	if elapsed == 1:
		_run_population(POPULATIONS[_pop_index])
	elif elapsed == SETTLE_FRAMES:
		_check_population(POPULATIONS[_pop_index])
		for a in _actors:
			if is_instance_valid(a):
				a.queue_free()
		_actors.clear()
		_locations.clear()
		_pop_index += 1
		_batch_start_frame = _frame
	return false


func _run_population(n: int) -> void:
	var t0 := Time.get_ticks_usec()
	for i in n:
		var profile: PersonProfile = _roster[i]
		var home: String = profile.routine("home")
		var actor: DebugActor = block.spawn_resident(profile.to_dict(), home)
		actor.position += CityBlock.spread_offset(i, n)
		_actors.append(actor)
		_locations.append(home)
	var spawn_us := Time.get_ticks_usec() - t0

	var t1 := Time.get_ticks_usec()
	for i in n:
		var goal := ResidentRoutine.current_goal(_roster[i].data["routine"], 12)   # noon: everyone should head to work
		if goal == _locations[i]:
			continue
		var route: Array = block.get_route(_locations[i], goal)
		if route.is_empty():
			_errors.append("population %d: resident %d got an empty route %s -> %s" % [n, i, _locations[i], goal])
			continue
		_actors[i].follow_route(route)
		_locations[i] = goal
	var dispatch_us := Time.get_ticks_usec() - t1

	print("city_population_check: population %d: spawn %.2f ms (%.3f ms/resident), dispatch %.2f ms (%.3f ms/resident)"
		% [n, spawn_us / 1000.0, (spawn_us / 1000.0) / n, dispatch_us / 1000.0, (dispatch_us / 1000.0) / n])


func _check_population(n: int) -> void:
	var alive := 0
	var on_floor := 0
	# is_on_floor() itself turns out not to be a reliable stability signal
	# here: measured directly across several spacing values, roughly 1 in
	# 20 resting, correctly-grounded actors reads is_on_floor()=false even
	# though their own Y position sits within a millimeter of every other,
	# successfully-"on_floor" actor's -- a CharacterBody3D floor-detection
	# nuance for a near-motionless body, not evidence of falling through or
	# never landing. grounded (position-based: is Y actually near the
	# ground, not falling into the void or flying off) is the real
	# stability check; on_floor is reported for visibility, not a hard
	# failure condition.
	var grounded := 0
	for a in _actors:
		if is_instance_valid(a):
			alive += 1
			if a.is_on_floor():
				on_floor += 1
			if absf(a.global_position.y - block.global_position.y) < 0.5:
				grounded += 1
	print("city_population_check: population %d after %d settle frames: %d/%d alive, %d/%d grounded (Y near the ground, expect == %d), %d/%d on_floor flag (informational -- see notes on why this isn't the hard check)"
		% [n, SETTLE_FRAMES, alive, n, grounded, n, n, on_floor, n])
	if alive != n or grounded != n:
		_errors.append("population %d: only %d/%d alive and %d/%d actually grounded after settling" % [n, alive, n, grounded, n])
		for i in _actors.size():
			var a := _actors[i]
			if is_instance_valid(a) and absf(a.global_position.y - block.global_position.y) >= 0.5:
				print("city_population_check: DEBUG not grounded, actor %d at %s (local offset %s)" % [i, a.global_position, CityBlock.spread_offset(i, n)])
