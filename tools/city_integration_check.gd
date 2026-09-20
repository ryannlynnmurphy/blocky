extends Node
## Dev-only check for B5 (main.gd's real State.CITY integration, as opposed
## to the standalone scenes/city_block.tscn preview tools/city_block_check.gd
## and tools/city_route_check.gd already cover). Runs as a real child of the
## actual booted main.tscn -- same pattern as tools/anim_check.gd -- so this
## exercises the literal production code path (main._enter_city()/
## _exit_city()), not a re-implementation of it.
##
## `-- --citytest --skiptitle --no-input --fresh --mute`
##
## Deliberately separate from the large, already-verified tools/selftest.gd
## suite: a bug in a brand-new check shouldn't risk that suite's own frame
## numbering or existing assertions.

var main: Node
var player: Player
var _frame := 0
var _player_pos_before_city := Vector3.ZERO
var _work_minutes_before := 0.0
var _talked_to_actor: DebugActor = null


func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		# 60 frames (1s) gives the player's own initial ~2-block spawn fall
		# (_place_player_at_spawn() drops them 2 blocks above ground) time to
		# fully settle before this test's own baseline/timing depends on the
		# player being genuinely at rest -- same reasoning as
		# tools/city_block_check.gd's own SETTLE_FRAME.
		60:
			print("citytest: initial state=%d (expect 2 = PLAYING), on_floor=%s (expect true -- settled from spawn), mouse captured (headless baseline, informational)=%s"
				% [main.state, player.is_on_floor(), Input.mouse_mode == Input.MOUSE_MODE_CAPTURED])
			_player_pos_before_city = player.global_position
			main._enter_city()
		63:
			print("citytest: after _enter_city(): state=%d (expect 8 = CITY), city instance present=%s, walker present=%s"
				% [main.state, main._city != null, main._city_walker != null])
			print("citytest: tree paused=%s (expect true), hud visible=%s (expect false), mouse captured=%s (informational, matches the PLAYING baseline above either way)"
				% [get_tree().paused, main.hud.visible, Input.mouse_mode == Input.MOUSE_MODE_CAPTURED])
			if main._city_walker:
				var pos: Vector3 = main._city_walker.global_position
				print("citytest: walker world position %s (expect y far below 0 -- embedded offset, never overlapping real terrain)" % [pos])
		70:
			# S4/L1: the resident roster (L0) now actually appears in the
			# city (see main._enter_city()) -- find the first one by node
			# name (Godot auto-suffixes siblings sharing a base name:
			# Resident, Resident2, Resident3, ...) and confirm it has a
			# real rendered body, not just a bare capsule. A separate,
			# direct scene-tree count (not just trusting main._city_residents,
			# main.gd's own bookkeeping) confirms all 20 actually exist as
			# real nodes, not just tracked references.
			var resident: Node = main._city.get_node_or_null("Resident")
			var mesh_count := 0
			if resident:
				mesh_count = resident.find_children("*", "MeshInstance3D", true, false).size()
			var resident_pos: Vector3 = resident.global_position if resident else Vector3.ZERO
			var apartment_global: Vector3 = main._city.to_global(main._city.location_positions["apartment"])
			print("citytest: S4 resident present=%s, mesh parts=%d (expect > 0 -- a real rig, not a bare capsule), %.1fm from apartment (expect small -- spawned home)"
				% [resident != null, mesh_count, resident_pos.distance_to(apartment_global) if resident else -1.0])
			# Counted by actual node type (DebugActor), not by name -- Godot's
			# sibling name auto-dedup for 20 children all created with the
			# same name.begins_with("Resident") doesn't reliably keep that
			# prefix (checked directly: it did not), so type is the honest
			# way to count them, not a naming-convention guess.
			var debug_actor_count := 0
			for c in main._city.get_children():
				if c is DebugActor:
					debug_actor_count += 1
			print("citytest: L1 resident nodes actually in the scene tree=%d (expect 20)" % [debug_actor_count])
		74:
			# S5/L1: drive Priya (roster index 0, see L0's handoff) through a
			# full home/work/food day via the REAL hour_changed signal
			# (main._on_city_resident_hour_changed()), not a direct call to
			# _drive_all_city_residents() -- proves the whole wired path,
			# same reasoning as the E-keypress test above. Boot's start_time
			# (day_night.gd) is 0.3 = hour 7 (wake), which _enter_city()
			# already dispatched once on entry (breakfast, hour 7 is neither
			# Priya's sleep nor work window) -- confirm that happened before
			# jumping further.
			print("citytest: S5 initial dispatch at hour=%d: resident location=%s (expect cafe -- awake, not yet work hours)"
				% [main.day_night.hour(), main._city_residents[0]["location"]])
		78:
			main.day_night.load_save_data({"time_of_day": 9.0 / 24.0 + 0.001, "day_count": 1})
			print("citytest: S5 hour jumped to work_start (9): resident location=%s (expect workplace), route in progress=%s"
				% [main._city_residents[0]["location"], not main._city_residents[0]["actor"].route_complete])
		82:
			main.day_night.load_save_data({"time_of_day": 18.0 / 24.0 + 0.001, "day_count": 1})
			print("citytest: S5 hour jumped past work_end to dinner (18): resident location=%s (expect cafe), route in progress=%s"
				% [main._city_residents[0]["location"], not main._city_residents[0]["actor"].route_complete])
		86:
			main.day_night.load_save_data({"time_of_day": 22.0 / 24.0 + 0.001, "day_count": 1})
			print("citytest: S5 hour jumped to sleep_hour (22): resident location=%s (expect apartment), route in progress=%s"
				% [main._city_residents[0]["location"], not main._city_residents[0]["actor"].route_complete])
			print("citytest: S5 full home->work->food->home loop dispatched entirely through real hour_changed signals, not direct calls")
			# L1: all 20 residents (not just Priya) exist and are being
			# driven -- confirm the population, not just one representative.
			print("citytest: L1 resident population=%d (expect 20)" % [main._city_residents.size()])
		100:
			var on_floor: bool = main._city_walker.is_on_floor() if main._city_walker else false
			print("citytest: walker settled on_floor=%s (expect true -- real ground collision inside the embedded instance)" % [on_floor])
			var drift_while_visiting := player.global_position.distance_to(_player_pos_before_city)
			print("citytest: player position while paused in the city: %.3f m drift from pre-visit baseline (expect ~0.0 -- get_tree().paused genuinely freezes the player)"
				% [drift_while_visiting])
		104:
			# L2: teleport the walker next to Priya's (roster index 0)
			# current position (wherever her S5 routine actually put her --
			# read her real position, don't assume). At this point in the
			# test several residents share similar staggered sleep hours
			# (L0) and have all converged on the same home, so the actor
			# CityWalker's live proximity query finds isn't guaranteed to
			# be Priya specifically -- deliberately NOT assumed below;
			# whichever resident is genuinely closest is who a real player
			# would end up talking to, and that's what's checked.
			var priya: DebugActor = main._city_residents[0]["actor"]
			main._city_walker.global_position = priya.global_position + Vector3(1.0, 0, 0)
			main._city_walker.velocity = Vector3.ZERO
		108:
			_talked_to_actor = main._city_walker.near_resident
			print("citytest: near_resident after standing near the crowd: found=%s" % [_talked_to_actor != null])
			for entry in main._city_residents:
				entry["profile"].data["relationships"].clear()
			main.person_profile.data["relationships"].clear()
			# A real F keypress, not a direct signal.emit() -- exercises
			# CityWalker._unhandled_input()'s own near_resident gate, not a
			# re-implementation of it.
			var f_press := InputEventKey.new()
			f_press.keycode = KEY_F
			f_press.pressed = true
			Input.parse_input_event(f_press)
		112:
			var talked_to: PersonProfile = main._profile_for_resident_actor(_talked_to_actor)
			print("citytest: real F keypress near %s triggered PersonActions.talk(): player->them=%d, them->player=%d (expect both %d)"
				% [talked_to.display_name() if talked_to else "??", main.person_profile.relationship_affinity(talked_to.id()) if talked_to else -1,
					talked_to.relationship_affinity(main.person_profile.id()) if talked_to else -1, PersonActions.TALK_AFFINITY_GAIN])
			# L3: the same real conversation also left both parties a memory
			# of it, not just a relationship number.
			print("citytest: L3 memories after that conversation: player=%d, them=%d (expect both >= 1)"
				% [main.person_profile.memories().size(), talked_to.memories().size() if talked_to else -1])
			# A real I keypress (the "resident debug inspector" trigger),
			# not a direct call to debug_summary() -- proves the wiring
			# (CityWalker.inspect_requested -> main._on_city_inspect_requested())
			# doesn't crash and reaches the real profile, same reasoning as
			# the E/F keypress tests above. Printed output isn't captured
			# here (main.gd just print()s it, same as work/talk), but a
			# crash would show up as a SCRIPT ERROR in this run's own output.
			var i_press := InputEventKey.new()
			i_press.keycode = KEY_I
			i_press.pressed = true
			Input.parse_input_event(i_press)
		114:
			main._city_walker.global_position = Vector3(0, -499.9, 0)   # away from the crowd, clear of talk/inspect range
		118:
			print("citytest: near_resident after walking away: %s (expect null/none)" % [main._city_walker.near_resident])
		120:
			# S2: teleport to the floor in front of the workplace workbench
			# (exposed as CityBlock.workbench_position, in CityBlock's own
			# LOCAL space -- main._city itself is offset by
			# CITY_EMBED_Y_OFFSET, so this must go through to_global(), not
			# be used as a global position directly) rather than re-walking
			# the door transition B3's own tools/city_block_check.gd already
			# verifies -- this check is only about the work trigger from
			# here on. Y must be the interior FLOOR (workbench_position.y
			# minus the 0.45 the workbench box itself sits above the floor),
			# not the workbench's own table-height Y -- the walker's collision
			# capsule is itself offset +0.55 above its origin (see
			# CityBlock.spawn_walker()), so standing at table height would
			# put the capsule's center too high, right at the trigger's edge.
			var floor_y_local: float = main._city.workbench_position.y - 0.45
			var stand_local := Vector3(main._city.workbench_position.x, floor_y_local, main._city.workbench_position.z)
			var target: Vector3 = main._city.to_global(stand_local) + Vector3(0, 0.0, 1.0)
			main._city_walker.global_position = target
			main._city_walker.velocity = Vector3.ZERO
		126:
			# 6 physics frames of settle/overlap-detection budget, matching
			# tools/city_block_check.gd's own entrance-trigger checks
			# (_entrance_frame == 3, at 60fps -- this project runs
			# --citytest at 60fps too) rather than assuming 1-2 is enough.
			print("citytest: near_workbench after standing at the trigger: %s (expect true -- CityBlock.near_workbench_at() found the walker in range), walker now at %s"
				% [main._city_walker.near_workbench, main._city_walker.global_position])
			main.person_profile.data["needs"]["money"] = 0
			_work_minutes_before = main.day_night.total_minutes()
			# A real E keypress, not a direct signal.emit() -- exercises
			# CityWalker._unhandled_input()'s own near_workbench gate, not a
			# re-implementation of it.
			var e_press := InputEventKey.new()
			e_press.keycode = KEY_E
			e_press.pressed = true
			Input.parse_input_event(e_press)
		130:
			print("citytest: real E keypress near the workbench triggered PersonActions.work(): money %d (expect %d), clock advanced %.1f min (expect %.1f = %dh)"
				% [main.person_profile.need("money"), PersonActions.WORK_PAY,
					main.day_night.total_minutes() - _work_minutes_before,
					PersonActions.WORK_SHIFT_HOURS * 60.0, PersonActions.WORK_SHIFT_HOURS])
			main._city_walker.global_position = Vector3(0, -499.9, 0)   # back onto the open street floor, clear of the trigger
		136:
			print("citytest: near_workbench after leaving the trigger: %s (expect false)" % [main._city_walker.near_workbench])
		140:
			# L4: teleport to the cafe's own outdoor point (location_positions,
			# already public/reused throughout B4-B5) and confirm the shop
			# trigger finds it -- no new geometry needed, unlike the workbench.
			var cafe_local: Vector3 = main._city.location_positions["cafe"]
			main._city_walker.global_position = main._city.to_global(cafe_local) + Vector3(0, 0.1, 0.5)
			main._city_walker.velocity = Vector3.ZERO
		146:
			print("citytest: near_shop after standing at the cafe: %s (expect true -- CityBlock.near_shop_at() found it)"
				% [main._city_walker.near_shop])
			main.person_profile.data["needs"]["money"] = 100
			main.person_profile.data["needs"]["hunger"] = 30
			# A real B keypress, not a direct call -- exercises
			# CityWalker._unhandled_input()'s own near_shop gate.
			var b_press := InputEventKey.new()
			b_press.keycode = KEY_B
			b_press.pressed = true
			Input.parse_input_event(b_press)
		150:
			print("citytest: real B keypress at the cafe triggered PersonActions.buy_food(): money %d (expect %d), hunger %d (expect %d)"
				% [main.person_profile.need("money"), 100 - PersonActions.SHOP_FOOD_COST,
					main.person_profile.need("hunger"), 30 + PersonActions.SHOP_FOOD_HUNGER])
			main._city_walker.global_position = Vector3(0, -499.9, 0)   # away from the cafe, clear of the shop trigger
		154:
			print("citytest: near_shop after leaving the cafe: %s (expect false)" % [main._city_walker.near_shop])
			# L4: a real day_changed (through load_save_data(), same real
			# public path S0 already proved fires this signal) should pay
			# every resident and charge rent on everyone, player included --
			# through main._on_city_day_changed(), not a direct call.
			for entry in main._city_residents:
				entry["profile"].data["needs"]["money"] = 50
			main.person_profile.data["needs"]["money"] = 50
			main.day_night.load_save_data({"time_of_day": main.day_night.time_of_day, "day_count": main.day_night.day_count + 1})
		157:
			var resident_money: int = main._city_residents[0]["profile"].need("money")
			var expected_resident: int = 50 + PersonActions.DAILY_WAGE - PersonActions.DAILY_RENT
			print("citytest: L4 real day_changed paid a resident and charged rent: money %d (expect %d)"
				% [resident_money, expected_resident])
			var expected_player: int = 50 - PersonActions.DAILY_RENT
			print("citytest: L4 real day_changed charged the player rent (no payday -- no job yet): money %d (expect %d)"
				% [main.person_profile.need("money"), expected_player])
		160:
			# Door transitions were the actual bug this card's work-trigger
			# testing surfaced (see the CORRECTION comment on
			# CityBlock._add_transition()): confirm walking through a real
			# door -- not just the work trigger -- also works while
			# genuinely embedded and paused, the exact condition that used
			# to silently do nothing.
			var door_local: Vector3 = main._city._entrances["apartment"]
			var door_target: Vector3 = main._city.to_global(door_local) + Vector3(0, 1.0, 0.1)
			main._city_walker.global_position = door_target
			main._city_walker.velocity = Vector3.ZERO
		164:
			var walker_y: float = main._city_walker.global_position.y
			print("citytest: apartment door transition while embedded+paused: walker y=%.1f (expect near %.1f -- INTERIOR_Y teleport fired, not the ~%.1f street/door level it started at)"
				% [walker_y, main._city.position.y + main._city.INTERIOR_Y, main._city.position.y])
			# Simulate Esc the same way a real keypress does: city_walker.gd's
			# _unhandled_input emits this exact signal.
			main._city_walker.exit_requested.emit()
		167:
			print("citytest: after exit signal: state=%d (expect 2 = PLAYING), tree paused=%s (expect false)"
				% [main.state, get_tree().paused])
		174:
			var city_freed := main._city == null or not is_instance_valid(main._city)
			print("citytest: city instance actually freed=%s (expect true -- queue_free() had a full frame budget to run)" % [city_freed])
			var drift := player.global_position.distance_to(_player_pos_before_city)
			print("citytest: player position undisturbed by the whole visit: %.3f m drift (expect ~0.0)" % [drift])
			# Prove normal play genuinely still works after returning, not
			# just that the state label says PLAYING -- same test_move
			# technique tools/anim_check.gd and tools/selftest.gd both use.
			player.test_move = Vector2(0, -1)
		230:
			var moved := player.global_position.distance_to(_player_pos_before_city)
			print("citytest: walked %.2f m after returning from the city (expect > 1.0 -- normal play resumed for real)" % [moved])
			player.test_move = Vector2.ZERO
			print("citytest: done")
