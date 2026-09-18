extends Node
## Dev tool: exercises the game's real code paths and prints what
## happened. Added by main.gd when the game is run with `-- --selftest`.
##
##   frames  40 / 80   break a block, place it back  (inventory)
##   frames 120..200   spawn a critter, punch it dead, pick up its drop (combat)

var player: Player
var world: VoxelWorld
var _frame := 0
var _critter: Creature


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
				_critter = world.spawn_creature(int(floor(p.x)), int(floor(p.z)))
				if _critter != null:
					_critter.global_position = p + Vector3(0, 0.05, 0)   # exactly under the crosshair
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
