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
		90:
			var on_floor: bool = main._city_walker.is_on_floor() if main._city_walker else false
			print("citytest: walker settled on_floor=%s (expect true -- real ground collision inside the embedded instance)" % [on_floor])
			var drift_while_visiting := player.global_position.distance_to(_player_pos_before_city)
			print("citytest: player position while paused in the city: %.3f m drift from pre-visit baseline (expect ~0.0 -- get_tree().paused genuinely freezes the player)"
				% [drift_while_visiting])
			# Simulate Esc the same way a real keypress does: city_walker.gd's
			# _unhandled_input emits this exact signal.
			main._city_walker.exit_requested.emit()
		93:
			print("citytest: after exit signal: state=%d (expect 2 = PLAYING), tree paused=%s (expect false)"
				% [main.state, get_tree().paused])
		110:
			var city_freed := main._city == null or not is_instance_valid(main._city)
			print("citytest: city instance actually freed=%s (expect true -- queue_free() had a full frame budget to run)" % [city_freed])
			var drift := player.global_position.distance_to(_player_pos_before_city)
			print("citytest: player position undisturbed by the whole visit: %.3f m drift (expect ~0.0)" % [drift])
			# Prove normal play genuinely still works after returning, not
			# just that the state label says PLAYING -- same test_move
			# technique tools/anim_check.gd and tools/selftest.gd both use.
			player.test_move = Vector2(0, -1)
		160:
			var moved := player.global_position.distance_to(_player_pos_before_city)
			print("citytest: walked %.2f m after returning from the city (expect > 1.0 -- normal play resumed for real)" % [moved])
			player.test_move = Vector2.ZERO
			print("citytest: done")
