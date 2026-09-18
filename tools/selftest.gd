extends Node
## Dev tool: exercises the game's real code paths and prints what
## happened. Added by main.gd when the game is run with `-- --selftest`.
##
##   frames  40 / 80   break a block, place it back  (inventory)
##   frames 120..200   spawn a critter, punch it dead, pick up its drop (combat)
##   frames 210..290   fall from 8 blocks, eat meat, die and respawn (health)
##   frames 300..320   kill two critters, reach level 2 (progression)
##   frames 330..360   save, wreck the state, load it back (saving)
##   frames 370..430   walk 0.5 s, then run 0.5 s; check distances (movement)

const TEST_SAVE := "user://selftest_save.json"

var player: Player
var world: VoxelWorld
var main: Node
var _frame := 0
var _critter: Creature
var _deaths := 0
var _hole := Vector3i.ZERO
var _move_start := Vector3.ZERO


func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			player.set_look(0.0, -0.8)   # look down at the ground ahead
		40:
			print("selftest: inventory before break: %s" % player.inventory.summary())
			player._break_block()
			print("selftest: inventory after break:  %s" % player.inventory.summary())
		80:
			# Select whatever we picked up, then put it back down.
			for i in Blocks.HOTBAR.size():
				if player.inventory.count(Blocks.HOTBAR[i]) > 0:
					player.selected = i
					player.hotbar_changed.emit(i)
					break
			player._place_block()
			print("selftest: inventory after place:  %s" % player.inventory.summary())
		120:
			# Spawn the critter exactly where the crosshair points at the
			# ground, so a click would land on it like a real player's.
			player.set_look(0.0, -0.6)
			var hit := player._aim_ray()
			if hit.is_empty():
				print("selftest: aim ray hit nothing; cannot place critter")
			else:
				var p: Vector3 = hit.position
				_critter = world.spawn_creature_at(p + Vector3(0, 0.05, 0))   # exactly under the crosshair
				print("selftest: spawned critter: %s" % (_critter != null))
		140:
			print("selftest: crosshair sees critter: %s" % (player._aim_creature() != null))
			# Debug detail if that failed.
			var hit := player._aim_ray()
			if not hit.is_empty():
				print("  aim ray hits %s, %.2f from player" % [hit.position, hit.position.distance_to(player.global_position)])
			if is_instance_valid(_critter):
				print("  critter at %s, %.2f from player, layer %d" % [_critter.global_position, _critter.global_position.distance_to(player.global_position), _critter.collision_layer])
			var cam: Camera3D = player._camera
			var from := cam.global_position
			var q := PhysicsRayQueryParameters3D.create(from, from + (-cam.global_basis.z) * 10.0)
			q.collision_mask = 2
			var h2 := player.get_world_3d().direct_space_state.intersect_ray(q)
			print("  creature-only ray: %s" % ("nothing" if h2.is_empty() else str(h2.collider)))
		150:
			# First blow through the real left-click path.
			player._attack_or_break()
			if is_instance_valid(_critter):
				print("selftest: clicked; critter health now %d" % _critter.health)
		160, 170:
			# It flees after the first hit, so finish it directly.
			if is_instance_valid(_critter):
				_critter.take_hit(1, player.global_position)
				print("selftest: hit critter, health now %d" % _critter.health)
		180:
			print("selftest: critter alive: %s, drops on ground: %d"
				% [is_instance_valid(_critter), world.drop_count()])
		190:
			# Walk onto the drop by teleporting next to it.
			if world.drop_count() > 0:
				var d: Drop = world._drops.get_child(0)
				player.global_position = d.global_position + Vector3(0, 0.2, 0)
		200:
			print("selftest: inventory after pickup: %s" % player.inventory.summary())
		210:
			print("selftest: health before fall: %d" % player.health)
			player.died.connect(func(): _deaths += 1)
			player.global_position.y += 8.0   # drop from 8 blocks up (lands after ~0.85 s)
		280:
			print("selftest: health after fall:  %d" % player.health)
			var ate := player.eat()
			print("selftest: ate meat: %s, health now %d, %s" % [ate, player.health, player.inventory.summary()])
		290:
			player.take_damage(100)
			print("selftest: after lethal damage: deaths %d, health %d, at spawn: %s"
				% [_deaths, player.health, player.global_position.distance_to(player.spawn_point) < 0.01])
		300:
			print("selftest: level %d, xp %d/%d, max health %d"
				% [player.level, player.xp, player.xp_needed(), player.max_health])
			player.take_damage(3)   # so the level-up heal is visible
			for i in 2:
				var c := world.spawn_creature_at(player.global_position + Vector3(2 + i, 0.5, 0))
				for hit in 3:
					c.take_hit(1, player.global_position, player)
			print("selftest: after 2 kills: level %d, xp %d/%d, max health %d, health %d"
				% [player.level, player.xp, player.xp_needed(), player.max_health, player.health])
		330:
			# Dig a hole and remember where, then save.
			player.set_look(0.0, -0.8)
			var hit := player._aim_ray()
			_hole = Vector3i((hit.position - hit.normal * 0.5).floor())
			player._break_block()
			var ok: bool = main.save_game(TEST_SAVE)
			print("selftest: saved to %s: %s (hole at %s, block there now %d)"
				% [TEST_SAVE, ok, _hole, world.get_block(_hole.x, _hole.y, _hole.z)])
		340:
			# Wreck everything the save should restore.
			player.level = 1
			player.xp = 0
			player.inventory.from_dict({})
			player.global_position += Vector3(5, 0, 5)
			world.edits.clear()
			world.reset_chunks()
			world.ensure_data(Vector2i(_hole.x >> 4, _hole.z >> 4))   # regenerate now, not next frame
			print("selftest: wrecked: level %d, %s, block at hole after regen: %d (expect 1 = grass back)"
				% [player.level, player.inventory.summary(), world.get_block(_hole.x, _hole.y, _hole.z)])
		350:
			var ok: bool = main.load_game(TEST_SAVE)
			world.ensure_data(Vector2i(_hole.x >> 4, _hole.z >> 4))
			print("selftest: loaded: %s -> level %d, xp %d, %s, block at hole: %d (expect 0 = hole kept), moved back: %s"
				% [ok, player.level, player.xp, player.inventory.summary(),
					world.get_block(_hole.x, _hole.y, _hole.z),
					player.global_position.distance_to(Vector3(_hole) + Vector3(0.5, 0, 0.5)) < 6.0])
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
		370:
			player.set_look(0.0, -0.2)
			_move_start = player.global_position
			player.test_move = Vector2(0, -1)   # forward
			player.test_run = false
		400:
			var d := player.global_position.distance_to(_move_start)
			print("selftest: walked %.2f blocks in 0.5 s (expect ~%.2f)" % [d, Player.WALK_SPEED * 0.5])
			_move_start = player.global_position
			player.test_run = true
		430:
			var d := player.global_position.distance_to(_move_start)
			print("selftest: ran %.2f blocks in 0.5 s (expect ~%.2f), fov %.0f, lean %.2f"
				% [d, Player.RUN_SPEED * 0.5, player._camera.fov, player._model.rotation.x])
			player.test_move = Vector2.ZERO
			player.test_run = false
