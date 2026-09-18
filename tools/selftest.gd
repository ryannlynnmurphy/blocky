extends Node
## Dev tool: exercises the game's real code paths and prints what
## happened. Added by main.gd when the game is run with `-- --selftest`.
##
##   frames  40..100   hold to break a block, magnet-collect it, place it back
##   frames 120..200   spawn a critter, punch it dead, pick up its drop (combat)
##   frames 210..290   fall from 8 blocks, eat meat, die and respawn (health)
##   frames 300..320   kill two critters, reach level 2 (progression)
##   frames 330..360   save, wreck the state, load it back (saving)
##   frames 370..430   walk 0.5 s, then run 0.5 s; check distances (movement)
##   frames 440..480   craft log -> planks -> sticks -> workbench -> pickaxe (crafting)
##   frames 490..640   midnight: a Shade hunts and bites; noon: it burns (hostiles)
##   frame  800        generate a chunk and count caves + ores; tool tier rules (underground)

const TEST_SAVE := "user://selftest_save.json"

var player: Player
var world: VoxelWorld
var main: Node
var _frame := 0
var _critter: Creature
var _deaths := 0
var _hole := Vector3i.ZERO
var _move_start := Vector3.ZERO
var _shade: Hostile
var _health_before_shade := 0


func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			main.save_path = TEST_SAVE   # never touch the real save file
			player.set_look(0.0, -1.0)   # look down at the ground just ahead
		40:
			print("selftest: inventory before break: %s" % player.inventory.summary())
			player.test_hold_break = true   # hold the button...
		60:
			print("selftest: mid-break progress %.2f (grass takes %.2f s)" % [player._break_progress, Blocks.hardness(Blocks.GRASS)])
		100:
			# ...grass takes 0.6 s (36 physics frames); the drop then magnets in.
			player.test_hold_break = false
			print("selftest: inventory after hold-break + pickup: %s, drops left %d"
				% [player.inventory.summary(), world.drop_count()])
		110:
			# Select the slot holding what we picked up, then put it back down.
			player.select_slot(player.inventory.find_slot(Blocks.GRASS))
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
			print("selftest: health after ~8-block fall: %d (expect 4-5: 8 blocks plus whatever we stood above ground)" % player.health)
			player.hunger = 3   # pretend we've been out a while
			var ate := player.eat()
			print("selftest: ate meat: %s, hunger now %d (expect 7), %s" % [ate, player.hunger, player.inventory.summary()])
			# Simulate 4 s of being well fed: should regenerate 1 health.
			var before := player.health
			player._tick_hunger(Player.REGEN_SECONDS, false)
			print("selftest: regen after %.0f s: health %d -> %d" % [Player.REGEN_SECONDS, before, player.health])
		290:
			player.take_damage(100)
			print("selftest: after lethal damage: deaths %d, death screen up: %s, game paused: %s"
				% [_deaths, main.state == main.State.DEAD, get_tree().paused])
		296:
			main.respawn_from_death()   # press "Respawn" (a few frames later, so it's on camera)
			print("selftest: after respawn: health %d, at spawn: %s, playing: %s"
				% [player.health, player.global_position.distance_to(player.spawn_point) < 0.01,
					main.state == main.State.PLAYING])
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
		302:
			player.global_position.y += 3.6   # a small drop: should cost exactly 1 (lands ~0.6 s later)
		345:
			print("selftest: health after a 3.6-block drop: %d (expect 11)" % player.health)
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
		440:
			# Crafting through the real grid UI, Minecraft-style.
			var inv := player.inventory
			inv.clear()
			main.set_inventory_open(true)   # pockets: 2x2 grid
			var ui: InventoryUI = main.hud.inventory_ui()
			ui.grid.set_slot(0, Blocks.LOG, 1)
			print("selftest: log in 2x2 grid -> result: %s" % ui._recipe_label.text)
			ui.take_result(true)   # shift-click: straight into the bag
			print("selftest: after taking result: %s (expect Planks x4)" % inv.summary())
			# Sticks: planks stacked vertically (2x2 slots 0 and 2).
			inv.take(Blocks.PLANKS, 2)
			ui.grid.set_slot(0, Blocks.PLANKS, 1)
			ui.grid.set_slot(2, Blocks.PLANKS, 1)
			print("selftest: planks over planks -> %s" % ui._recipe_label.text)
			ui.take_result(true)
			# Planks side by side should NOT be sticks.
			ui.grid.set_slot(0, Blocks.PLANKS, 1)
			ui.grid.set_slot(1, Blocks.PLANKS, 1)
			print("selftest: planks side by side -> '%s' (expect nothing)" % ui._recipe_label.text)
			ui.grid.clear()
			print("selftest: bag now: %s (expect Planks x2, Stick x4)" % inv.summary())
			# A pickaxe needs 3 wide: impossible in 2x2.
			main.set_inventory_open(false)
			print("selftest: stone by hand: x%.1f, drops: %s (expect 1.0, false)"
				% [player.tool_multiplier(Blocks.STONE), player.drops_when_broken(Blocks.STONE)])
			# Put a Workbench block where the crosshair points, then right-click it.
			player.set_look(0.0, -0.6)
			var hit := player._aim_ray()
			var spot := Vector3i((hit.position + hit.normal * 0.5).floor())
			world.set_block(spot.x, spot.y, spot.z, Blocks.WORKBENCH)
			player._place_block()   # right-click on the bench: should open it, not build
			print("selftest: right-clicked workbench: screen is workbench: %s, block still there: %s"
				% [main.state == main.State.WORKBENCH, world.get_block(spot.x, spot.y, spot.z) == Blocks.WORKBENCH])
			# Lay out a pickaxe in the 3x3: planks across the top, sticks down the middle.
			inv.add(Blocks.PLANKS, 1)   # need 3
			ui = main.hud.inventory_ui()
			for i in [0, 1, 2]:
				ui.grid.set_slot(i, Blocks.PLANKS, 1)
			ui.grid.set_slot(4, Blocks.STICK, 1)
			ui.grid.set_slot(7, Blocks.STICK, 1)
			inv.take(Blocks.PLANKS, 3)
			inv.take(Blocks.STICK, 2)
			print("selftest: pickaxe pattern -> %s" % ui._recipe_label.text)
			ui.take_result(true)
			player.select_slot(inv.find_slot(Blocks.WOOD_PICKAXE))   # hold it
			print("selftest: holding pickaxe: %s | stone x%.1f, drops: %s (expect 2.5, true)"
				% [inv.summary(), player.tool_multiplier(Blocks.STONE), player.drops_when_broken(Blocks.STONE)])
			player.select_slot(inv.find_slot(Blocks.STICK))   # put it away
			print("selftest: holding sticks instead: stone x%.1f (expect 1.0 — tools must be held)"
				% player.tool_multiplier(Blocks.STONE))
			player.select_slot(inv.find_slot(Blocks.WOOD_PICKAXE))
		480:
			main.set_inventory_open(false)
		490:
			var dn: DayNight = main.day_night
			dn.time_of_day = 0.0   # midnight
			dn._apply()
			player.set_look(0.0, -0.2)
			_health_before_shade = player.health
			var p := player.global_position
			_shade = world.spawn_hostile_at(p + Vector3(0, 0.5, -6))
			print("selftest: midnight, shade spawned %.1f blocks away, is_night %s" % [
				_shade.global_position.distance_to(p), dn.is_night()])
		550:
			print("selftest: 1 s later shade is %.1f blocks away (chasing at %.0f b/s)" % [
				_shade.global_position.distance_to(player.global_position), Hostile.CHASE_SPEED])
		610:
			print("selftest: after 2 s near it: health %d -> %d (bitten: %s), shade alive %s" % [
				_health_before_shade, player.health, player.health < _health_before_shade,
				is_instance_valid(_shade)])
			main.day_night.time_of_day = 0.5   # noon
			main.day_night._apply()
		700:
			# 1.5 s of daylight at 1 health per 0.5 s: 5 -> 2.
			print("selftest: 1.5 s of daylight: shade health %d (expect 2)" % (_shade.health if is_instance_valid(_shade) else -1))
		790:
			print("selftest: 3 s of daylight: shade alive %s (expect false), hostiles %d" % [
				is_instance_valid(_shade), world.hostile_count()])
			# Every sound hook should have fired at least once by now.
			var counts: Dictionary = Sfx.instance.plays if Sfx.instance != null else {}
			var keys := counts.keys()
			keys.sort()
			var parts: PackedStringArray = []
			for k in keys:
				parts.append("%s x%d" % [k, counts[k]])
			print("selftest: sounds played: %s" % ", ".join(parts))
		810:
			# Screens: pause, then title, then a new game with a fixed seed.
			main._enter(main.State.PAUSED)
			print("selftest: paused: %s, tree paused: %s" % [main.state == main.State.PAUSED, get_tree().paused])
		826:
			main._enter(main.State.TITLE)
			print("selftest: title: %s, HUD hidden: %s" % [main.state == main.State.TITLE, not main.hud.visible])
		842:
			main._new_game("42")
			print("selftest: new game: seed %d (expect 42), inventory %s, health %d, playing: %s"
				% [world.world_seed, player.inventory.summary(), player.health, main.state == main.State.PLAYING])
			print("selftest: real save untouched: save path is %s" % main.save_path)
		800:
			# Survey a few chunks for caves and ores.
			var air_below := 0
			var coal_n := 0
			var iron_n := 0
			for cx in range(-2, 3):
				var result: Array = world.gen.fill_chunk(Vector2i(cx, 5))
				var data: PackedByteArray = result[0]
				for lz in 16:
					for lx in 16:
						var h := world.gen.height_at(cx * 16 + lx, 5 * 16 + lz)
						for y in range(1, h - 3):
							var id := data[lx + 16 * (lz + 16 * y)]
							if id == Blocks.AIR:
								air_below += 1
							elif id == Blocks.COAL_ORE:
								coal_n += 1
							elif id == Blocks.IRON_ORE:
								iron_n += 1
			print("selftest: underground in 5 chunks: cave air %d, coal ore %d, iron ore %d (expect all > 0)" % [air_below, coal_n, iron_n])
			print("selftest: coal ore drops %s, iron ore drops %s" % [Blocks.NAMES[Blocks.drop_for(Blocks.COAL_ORE)], Blocks.NAMES[Blocks.drop_for(Blocks.IRON_ORE)]])
			print("selftest: holding wooden pickaxe: iron ore drops %s (expect false); coal ore drops %s (expect true)"
				% [player.drops_when_broken(Blocks.IRON_ORE), player.drops_when_broken(Blocks.COAL_ORE)])
			player.inventory.add(Blocks.STONE_PICKAXE, 1)
			player.select_slot(player.inventory.find_slot(Blocks.STONE_PICKAXE))
			print("selftest: holding stone pickaxe: iron ore drops %s (expect true), stone speed x%.1f (expect 4.0)"
				% [player.drops_when_broken(Blocks.IRON_ORE), player.tool_multiplier(Blocks.STONE)])
