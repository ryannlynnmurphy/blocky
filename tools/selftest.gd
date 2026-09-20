extends Node
## Dev tool: exercises the game's real code paths and prints what
## happened. Added by main.gd when the game is run with `-- --selftest`.
##
##   frames  40..100   hold to break a block, magnet-collect it, place it back
##   frames 120..200   spawn a critter, punch it dead, pick up its drop (combat)
##   frames 210..290   fall from 8 blocks, eat meat, die and respawn (health)
##   frames 300..320   kill two critters, reach level 2 (progression)
##   frames 330..360   save, wreck the state, load it back (saving); also
##                     round-trips the person profile (id/name/wardrobe)
##                     through the same save file, checks a save with no
##                     "person" key (pre-D0) still migrates safely, needs
##                     clamp on load, and (frame 351) the HUD shows the
##                     player's chosen name
##   frames 370..430   walk 0.5 s, then run 0.5 s; check distances (movement)
##   frames 440..480   craft log -> planks -> sticks -> workbench -> pickaxe (crafting)
##   frames 490..640   midnight: a Shade hunts and bites; noon: it burns (hostiles)
##   frame  800        generate a chunk and count caves + ores; tool tier rules (underground)
##   frames 810..842   pause/title/new-game screen transitions
##   frames 850..870   craft and place a Torch; it lights up and keeps hostiles away
##   frames 880..890   sleeping in a Bed: no-op by day, skips to dawn at night
##   frames 900..1020  shelter: a walled-in player is never bitten by a chasing Shade
##   frames 1030..1060 sword: hits harder than a fist, only visible while held, wears out
##   frames 1070..1080 furnace: iron ore only smelts into Iron there, not on breaking it
##   frames 1110..1200 a carved 2-tall corridor doesn't snag the player's head
##   frame  1210       breaking the ground under a prop removes it and drops an item

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
var _torch_pos := Vector3i.ZERO
var _shelter_shade: Hostile
var _shelter_center := Vector3.ZERO
var _shelter_health := 0
var _sleep_test_hostile: Hostile
var _corridor_start := Vector3.ZERO
var _person_test_id := ""


func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			main.save_path = TEST_SAVE   # never touch the real save file
			player.set_look(0.0, -1.0)   # look down at the ground just ahead
			print("selftest: music loop playing: %s (expect true)"
				% (Sfx.instance != null and Sfx.instance._music.playing))
		2:
			# Water-table data must be independent of loaded chunks and have a
			# dry surface boundary.  This does not create visual water or alter
			# player movement; WATER-05/06 own those later layers.
			var sample := _find_water_table_fixture()
			var sx: int = sample.x
			var sz: int = sample.y
			var ground_top := float(world.height_at(sx, sz) + 1)
			var surface := world.water_surface_y_at(sx, sz)
			var submerged := Vector3(sx + 0.5, ground_top + 0.1, sz + 0.5)
			var at_surface := Vector3(sx + 0.5, surface, sz + 0.5)
			var dry := Vector3(sx + 0.5, surface + 0.1, sz + 0.5)
			print("selftest: water table fixture (%d, %d), surface %.1f, depth %.1f; submerged %s, surface dry %s, above dry %s (expect true, true, true)"
				% [sx, sz, surface, world.water_depth_at(submerged), world.is_water_at(submerged),
					not world.is_water_at(at_surface), not world.is_water_at(dry)])
		3:
			# Exercise the real click path (slot_clicked), not just direct
			# grid mutation — the reported "doubles the item" bug can only
			# show up through the actual mouse-click code.
			player.inventory.set_slot(9, Blocks.DIRT, 5)
			player.inventory.set_slot(10, Blocks.STONE, 3)
			main.set_inventory_open(true)
		4:
			var ui: InventoryUI = main.hud.inventory_ui()
			var v9 := _find_slot_view(ui, player.inventory, 9)
			v9.ui.slot_clicked(v9, MOUSE_BUTTON_LEFT, false)   # pick up the 5 Dirt
			print("selftest: after pickup: cursor %s x%d, bag %s (expect Dirt x5 cursor, Dirt x0 Stone x3 bag)"
				% [Blocks.NAMES[ui.cursor_id], ui.cursor_count, player.inventory.summary()])
		5:
			var ui: InventoryUI = main.hud.inventory_ui()
			var v11 := _find_slot_view(ui, player.inventory, 11)   # empty slot
			v11.ui.slot_clicked(v11, MOUSE_BUTTON_LEFT, false)   # drop the 5 Dirt there
			print("selftest: after drop into empty slot: cursor %s x%d, bag %s (expect Air cursor, Dirt x5 Stone x3, total 8)"
				% [Blocks.NAMES[ui.cursor_id], ui.cursor_count, player.inventory.summary()])
		6:
			var ui: InventoryUI = main.hud.inventory_ui()
			var v11 := _find_slot_view(ui, player.inventory, 11)
			v11.ui.slot_clicked(v11, MOUSE_BUTTON_LEFT, false)   # pick the Dirt back up
			var v10 := _find_slot_view(ui, player.inventory, 10)
			v10.ui.slot_clicked(v10, MOUSE_BUTTON_LEFT, false)   # swap with the Stone
			print("selftest: after swap: cursor %s x%d, bag %s (expect Stone x3 cursor, Dirt x5 in slot 10, total still 8)"
				% [Blocks.NAMES[ui.cursor_id], ui.cursor_count, player.inventory.summary()])
		7:
			var ui: InventoryUI = main.hud.inventory_ui()
			var v10 := _find_slot_view(ui, player.inventory, 10)
			v10.ui.slot_clicked(v10, MOUSE_BUTTON_LEFT, false)   # drop the Stone back where it swapped from... into Dirt x5
			print("selftest: after re-place onto mismatched stack (swap again): bag %s (expect total still 8, no duplication)"
				% player.inventory.summary())
			main.set_inventory_open(false)
			player.inventory.clear()
		20:
			print("selftest: default view: first_person %s, arm offset %s, spring %.1f, model visible %s (expect false, x=0.55, 4.0, true)"
				% [player.first_person, player._arm.position, player._arm.spring_length, player._model.visible])
			player.toggle_view()
		21:
			print("selftest: after toggle: first_person %s, arm offset %s, spring %.1f, model visible %s (expect true, x=0.0, 0.0, false)"
				% [player.first_person, player._arm.position, player._arm.spring_length, player._model.visible])
			player.toggle_view()
		22:
			print("selftest: after toggle back: first_person %s, arm offset %s, spring %.1f, model visible %s (expect false, x=0.55, 4.0, true)"
				% [player.first_person, player._arm.position, player._arm.spring_length, player._model.visible])
		30:
			# WATER-05: completed streamed chunks own exactly one transparent
			# surface when they contain floodable columns. The World helper also
			# confirms it never retains a surface over dry/solid columns.
			print("selftest: water visuals %d, streamed surfaces valid %s (expect true)"
				% [world.water_visual_count(), world.water_visuals_match_streamed_chunks()])
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
			# Dig a hole and remember where, then save. Also customize the
			# person profile (D0-D4: it should round-trip through the same
			# save file, id included, exactly like level/xp/inventory do).
			player.set_look(0.0, -0.8)
			var hit := player._aim_ray()
			_hole = Vector3i((hit.position - hit.normal * 0.5).floor())
			player._break_block()
			main.person_profile.data["identity"]["name"] = "Selftest Person"
			main.person_profile.set_wardrobe("bracelet", "bracelet_silver")
			_person_test_id = main.person_profile.id()
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
			main.person_profile = PersonProfile.new()   # a different id, wiped identity
			print("selftest: wrecked: level %d, %s, block at hole after regen: %d (expect 1 = grass back)"
				% [player.level, player.inventory.summary(), world.get_block(_hole.x, _hole.y, _hole.z)])
		350:
			var ok: bool = main.load_game(TEST_SAVE)
			world.ensure_data(Vector2i(_hole.x >> 4, _hole.z >> 4))
			print("selftest: loaded: %s -> level %d, xp %d, %s, block at hole: %d (expect 0 = hole kept), moved back: %s"
				% [ok, player.level, player.xp, player.inventory.summary(),
					world.get_block(_hole.x, _hole.y, _hole.z),
					player.global_position.distance_to(Vector3(_hole) + Vector3(0.5, 0, 0.5)) < 6.0])
			print("selftest: person round-trip: id kept %s (expect true), name %s (expect Selftest Person), bracelet %s (expect bracelet_silver)"
				% [main.person_profile.id() == _person_test_id, main.person_profile.data["identity"]["name"],
					main.person_profile.wardrobe_id("bracelet")])
			var migrated := PersonProfile.new()
			migrated.load_dict({})   # simulates main.load_game() on a pre-D0 save with no "person" key
			print("selftest: old save missing 'person' key still loads safely: id %s (expect non-empty), name %s (expect Alex Rivera)"
				% [not migrated.id().is_empty(), migrated.data["identity"]["name"]])
		351:
			# A frame later: hud._process() runs on the idle loop, not this
			# physics loop, so it needs a tick to pick up frame 350's new
			# player reference -- same class of gotcha as M28/M36's
			# check-a-frame-later notes.
			print("selftest: HUD shows the player's name: %s (expect true)"
				% main.hud._clock_label.text.begins_with(player.person_name()))
			var clamped := PersonProfile.new()
			clamped.load_dict({"needs": {"hunger": 999, "energy": -50, "money": -20}})
			print("selftest: need clamping: hunger %d (expect 100), energy %d (expect 0), money %d (expect 0)"
				% [clamped.data["needs"]["hunger"], clamped.data["needs"]["energy"], clamped.data["needs"]["money"]])
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
			# (Steeper than the -0.6 used elsewhere: from the taller player's
			# higher camera, -0.6 now overshoots past the nearby dig-test hole.)
			player.set_look(0.0, -1.0)
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
			# New Game now stops at Create a Person (main.State.CREATOR, which
			# also pauses the tree) rather than starting play directly; confirm
			# it the same way clicking "Enter Hollowmark" would, or every test
			# below this point silently runs against a paused, non-PLAYING
			# game (state-gated signals like furnace_used no-op, even though
			# direct data calls like inventory/world edits keep "working"
			# regardless of pause -- this is exactly how WATER-05's sibling
			# regression was found).
			main._new_game("42")
			main._finish_new_game()
			print("selftest: new game: seed %d (expect 42), inventory %s, health %d, playing: %s (expect true)"
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
		850:
			# Torch: craft it, place it, confirm it lights up and pushes
			# hostile spawns away; a broken torch's light goes with it.
			player.inventory.add(Blocks.COAL, 1)
			player.inventory.add(Blocks.STICK, 1)
			var torch_recipe := {}
			for r in Recipes.LIST:
				if r.get("out", [0])[0] == Blocks.TORCH:
					torch_recipe = r
			print("selftest: can craft torch from 1 coal + 1 stick: %s (expect true)"
				% Recipes.can_craft(player.inventory, torch_recipe, false))
			Recipes.craft(player.inventory, torch_recipe)
			print("selftest: after crafting: %s (expect Torch x4)" % player.inventory.summary())
			var tp := player.global_position
			_torch_pos = Vector3i(int(floor(tp.x)) + 3, int(floor(tp.y)), int(floor(tp.z)))
			world.set_block(_torch_pos.x, _torch_pos.y, _torch_pos.z, Blocks.TORCH)
			print("selftest: torch placed: block is torch %s, light exists %s (both expect true)"
				% [world.get_block(_torch_pos.x, _torch_pos.y, _torch_pos.z) == Blocks.TORCH,
					world._torch_lights.has(_torch_pos)])
			var near_pt := Vector3(_torch_pos) + Vector3(2, 0, 0)
			var far_pt := Vector3(_torch_pos) + Vector3(50, 0, 0)
			print("selftest: keeps hostiles away nearby %s (expect true), far away %s (expect false)"
				% [world._near_a_torch(near_pt), world._near_a_torch(far_pt)])
		860:
			world.set_block(_torch_pos.x, _torch_pos.y, _torch_pos.z, Blocks.AIR)
			print("selftest: torch broken: light removed %s (expect true)"
				% (not world._torch_lights.has(_torch_pos)))
		870:
			# Bed: needs a workbench (3-wide shape), sleeping is a no-op by
			# day and skips straight to dawn at night.
			player.inventory.add(Blocks.PLANKS, 3)
			var bed_recipe := {}
			for r in Recipes.LIST:
				if r.get("out", [0])[0] == Blocks.BED:
					bed_recipe = r
			print("selftest: can craft bed at a workbench: %s (expect true), in a pocket: %s (expect false)"
				% [Recipes.can_craft(player.inventory, bed_recipe, true),
					Recipes.can_craft(player.inventory, bed_recipe, false)])
			Recipes.craft(player.inventory, bed_recipe)
			var bp := player.global_position
			var bed_pos := Vector3i(int(floor(bp.x)) - 3, int(floor(bp.y)), int(floor(bp.z)))
			world.set_block(bed_pos.x, bed_pos.y, bed_pos.z, Blocks.BED)
			print("selftest: bed placed: %s (expect true)"
				% (world.get_block(bed_pos.x, bed_pos.y, bed_pos.z) == Blocks.BED))
		880:
			main.day_night.time_of_day = 0.5   # noon
			main.day_night._apply()
			var before: float = main.day_night.time_of_day
			main._try_sleep()
			print("selftest: sleep attempt at noon: time unchanged %s (expect true)"
				% is_equal_approx(main.day_night.time_of_day, before))
		890:
			main.day_night.time_of_day = 0.9   # deep night
			main.day_night._apply()
			var day_before: int = main.day_night.day_count
			main._try_sleep()
			print("selftest: sleep attempt at night: time now %.2f (expect 0.25), day %d -> %d"
				% [main.day_night.time_of_day, day_before, main.day_night.day_count])
		895:
			# Sleep should also refuse with a hostile nearby (Minecraft-
			# style), even at night — Hostile.SIGHT (18 blocks) away is
			# close enough, well past that is not.
			main.day_night.time_of_day = 0.9   # deep night again
			main.day_night._apply()
			var day_before2: int = main.day_night.day_count
			_sleep_test_hostile = world.spawn_hostile_at(player.global_position + Vector3(5, 0, 0))
			main._try_sleep()
			print("selftest: sleep blocked with a hostile 5 blocks away: day unchanged %s (expect true)"
				% (main.day_night.day_count == day_before2))
			_sleep_test_hostile.free()   # immediate, not queue_free — must be gone before the next check this same frame
			_sleep_test_hostile = null
			var far_hostile := world.spawn_hostile_at(player.global_position + Vector3(30, 0, 0))
			main._try_sleep()
			print("selftest: sleep works again with a hostile 30 blocks away: day %d -> %d (expect +1)"
				% [day_before2, main.day_night.day_count])
			far_hostile.queue_free()
		900:
			# Shelter: wall a 3x3 pocket in solid on all six sides, put the
			# player at its centre, and send a night hunter after them —
			# it should never make it through the walls.
			world.day_night.time_of_day = 0.0   # midnight, hostiles are active
			world.day_night._apply()
			var c := Vector3i(player.global_position) + Vector3i(20, 0, 20)
			_shelter_center = Vector3(c) + Vector3(0.5, 0.5, 0.5)
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					for dy in range(0, 4):
						world.set_block(c.x + dx, c.y + dy, c.z + dz, Blocks.AIR)
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					world.set_block(c.x + dx, c.y - 1, c.z + dz, Blocks.STONE)   # floor
					world.set_block(c.x + dx, c.y + 3, c.z + dz, Blocks.STONE)  # ceiling
			for dy in range(0, 3):
				for i in range(-2, 3):
					world.set_block(c.x - 2, c.y + dy, c.z + i, Blocks.STONE)
					world.set_block(c.x + 2, c.y + dy, c.z + i, Blocks.STONE)
					world.set_block(c.x + i, c.y + dy, c.z - 2, Blocks.STONE)
					world.set_block(c.x + i, c.y + dy, c.z + 2, Blocks.STONE)
			player.global_position = _shelter_center
			player.velocity = Vector3.ZERO
			_shelter_health = player.health
			_shelter_shade = world.spawn_hostile_at(_shelter_center + Vector3(6, 0, 0))
			print("selftest: shelter built, hostile spawned %.1f blocks away"
				% _shelter_shade.global_position.distance_to(player.global_position))
		1020:
			var breached := is_instance_valid(_shelter_shade) \
				and _shelter_shade.global_position.distance_to(_shelter_center) <= 2.5
			print("selftest: after 2 s, shelter breached: %s (expect false), health unchanged: %s (expect true)"
				% [breached, player.health == _shelter_health])
		1030:
			# Sword: craft it, equip it, confirm it hits harder than a bare
			# fist and only shows up while actually held. _sword.visible is
			# updated once a physics frame in Player._physics_process, so
			# it's checked a frame after each select_slot(), not the same
			# frame — otherwise the check races Player's own update.
			player.inventory.add(Blocks.PLANKS, 2)
			player.inventory.add(Blocks.STICK, 1)
			var sword_recipe := {}
			for r in Recipes.LIST:
				if r.get("out", [0])[0] == Blocks.SWORD:
					sword_recipe = r
			print("selftest: can craft sword at a workbench: %s (expect true), in a pocket: %s (expect false, 3 rows tall)"
				% [Recipes.can_craft(player.inventory, sword_recipe, true),
					Recipes.can_craft(player.inventory, sword_recipe, false)])
			Recipes.craft(player.inventory, sword_recipe)
			player.select_slot(player.inventory.find_slot(Blocks.SWORD))
			var dummy := world.spawn_creature_at(player.global_position + Vector3(0, 0.5, -2))
			var hp_before := dummy.health
			dummy.take_hit(Player.SWORD_DAMAGE, player.global_position, player)
			print("selftest: sword damage: %d -> %d (expect drop of %d, more than a fist's %d)"
				% [hp_before, dummy.health, Player.SWORD_DAMAGE, Player.PUNCH_DAMAGE])
		1031:
			print("selftest: sword equipped: held %s, model visible %s (both expect true)"
				% [player.held_id() == Blocks.SWORD, player._sword.visible])
		1040:
			var full_durability := Blocks.max_durability(Blocks.SWORD)
			print("selftest: sword durability starts full: %d (expect %d)"
				% [player.tool_durability_left(Blocks.SWORD), full_durability])
			player._use_tool(Blocks.SWORD)
			print("selftest: after one hit: %d (expect %d)"
				% [player.tool_durability_left(Blocks.SWORD), full_durability - 1])
			player.select_slot(0)
		1041:
			print("selftest: sword hidden once something else is held: held %s, model visible %s (expect false, false)"
				% [player.held_id() == Blocks.SWORD, player._sword.visible])
		1050:
			player.select_slot(player.inventory.find_slot(Blocks.SWORD))
			player.tool_durability[Blocks.SWORD] = 1
			var sword_before := player.inventory.count(Blocks.SWORD)
			player._use_tool(Blocks.SWORD)
			print("selftest: sword breaks at 0 durability: had %d, now %d (expect 1 -> 0)"
				% [sword_before, player.inventory.count(Blocks.SWORD)])
		1060:
			# Same wear-and-break mechanism, on a mining tool this time.
			player.inventory.add(Blocks.WOOD_PICKAXE, 1)
			player.tool_durability[Blocks.WOOD_PICKAXE] = 1
			var pick_before := player.inventory.count(Blocks.WOOD_PICKAXE)
			player._use_tool(Blocks.WOOD_PICKAXE)
			print("selftest: pickaxe breaks at 0 durability too: had %d, now %d (expect 1 -> 0)"
				% [pick_before, player.inventory.count(Blocks.WOOD_PICKAXE)])
		1070:
			# Furnace: Iron Ore no longer converts to Iron just by breaking
			# it — only smelting does that now.
			print("selftest: iron ore drops %s (expect Iron Ore, not Iron)"
				% Blocks.NAMES[Blocks.drop_for(Blocks.IRON_ORE)])
			player.inventory.add(Blocks.STONE, 8)
			var furnace_recipe := {}
			for r in Recipes.LIST:
				if r.get("out", [0])[0] == Blocks.FURNACE:
					furnace_recipe = r
			print("selftest: can craft furnace at a workbench: %s (expect true)"
				% Recipes.can_craft(player.inventory, furnace_recipe, true))
			# Right-click DETECTION (aim ray -> player._place_block() ->
			# branch on the aimed block's id) is the exact same mechanism
			# the Workbench test above already exercises with a real
			# raycast — Furnace's check is structurally identical, just a
			# different Blocks id, so it's not worth re-proving with
			# another raycast (whose geometry, at this point deep into the
			# test, is a real headache: the shelter test's walls/trees are
			# nearby, and placing a block close to the player can make the
			# third-person camera's spring arm pull in to avoid clipping
			# through it, silently retargeting the very next raycast
			# somewhere else entirely — confirmed by diagnostics, not
			# guessed). Test the signal wiring directly instead, the same
			# way the Bed/sleep test above does.
			player.furnace_used.emit()
			print("selftest: furnace_used opens the furnace screen: %s (expect true)"
				% (main.state == main.State.FURNACE))
		1080:
			var ui: InventoryUI = main.hud.inventory_ui()
			player.inventory.add(Blocks.IRON_ORE, 1)
			player.inventory.add(Blocks.COAL, 1)
			ui.grid.set_slot(0, Blocks.IRON_ORE, 1)
			ui.grid.set_slot(1, Blocks.COAL, 1)
			player.inventory.take(Blocks.IRON_ORE, 1)
			player.inventory.take(Blocks.COAL, 1)
			print("selftest: furnace result with ore + fuel loaded: %s (expect Iron)"
				% Blocks.NAMES[ui._result_view.result_id])
			ui.take_result(true)   # shift-click: straight into the bag
			print("selftest: smelted: %s (expect Iron x1), ore/fuel slots emptied: %s (expect true)"
				% [player.inventory.summary(), ui.grid.is_empty()])
			main.set_inventory_open(false)
		1110:
			# Carve a straight 2-tall, 1-wide corridor and walk it end to end.
			# A capsule that exactly fills a 2-tall gap catches on the ceiling
			# from physics jitter alone; this is the regression check for that.
			var base := Vector3i(int(floorf(player.global_position.x)), 25, int(floorf(player.global_position.z)))
			for i in 10:
				world.set_block(base.x + i, base.y - 1, base.z, Blocks.STONE)   # floor
				world.set_block(base.x + i, base.y, base.z, Blocks.AIR)        # feet level
				world.set_block(base.x + i, base.y + 1, base.z, Blocks.AIR)    # head level
				world.set_block(base.x + i, base.y + 2, base.z, Blocks.STONE)  # ceiling
			player.velocity = Vector3.ZERO
			player.global_position = Vector3(base.x + 0.5, base.y, base.z + 0.5)
			player.set_look(0.0, 0.0)   # face +X, the corridor's direction
			player.test_move = Vector2(1, 0)
			_corridor_start = player.global_position
		1200:
			player.test_move = Vector2.ZERO
			var traveled := player.global_position.distance_to(_corridor_start)
			print("selftest: walked %.1f blocks through a 2-tall corridor in 1.5 s (expect > 5.0 — near 0 means the head snagged the ceiling)"
				% traveled)
		1210:
			# Plant a synthetic mushroom prop on solid ground, then knock
			# the ground out from under it.
			var cpos := world.chunk_coord_of(player.global_position)
			var lx := 5
			var lz := 5
			var by := 30
			var bx := cpos.x * VoxelWorld.SIZE + lx
			var bz := cpos.y * VoxelWorld.SIZE + lz
			world.set_block(bx, by - 1, bz, Blocks.STONE)   # ground
			world.set_block(bx, by, bz, Blocks.AIR)         # clear space for it
			var entry := {"type": "mushroom_cluster", "lx": lx, "lz": lz, "y": by, "rot": 0.0}
			if not world.chunk_props.has(cpos):
				world.chunk_props[cpos] = []
			world.chunk_props[cpos].append(entry)
			world._instantiate_props(world.chunks[cpos], [entry])
			var wpos := Vector3i(bx, by, bz)
			print("selftest: mushroom prop placed: tracked %s (expect true)" % world._prop_nodes.has(wpos))
			var before_drops := world.drop_count()
			world.set_block(bx, by - 1, bz, Blocks.AIR)   # break the ground it stands on
			print("selftest: after breaking ground under it: prop gone %s (expect true), item dropped %s (expect true)"
				% [not world._prop_nodes.has(wpos), world.drop_count() > before_drops])


## Finds the SlotView the InventoryUI built for a given (inv, index) pair,
## so a test can drive the real click handler instead of poking data.
func _find_slot_view(ui: InventoryUI, inv: Inventory, index: int) -> InventoryUI.SlotView:
	for v in ui._slot_views:
		if v.inv == inv and v.index == index:
			return v
	return null


## Finds a generated water column using only deterministic terrain data, so the
## fixture does not depend on chunk streaming order or player position.
func _find_water_table_fixture() -> Vector2i:
	for z in range(-128, 129):
		for x in range(-128, 129):
			if float(world.height_at(x, z) + 1) < world.water_surface_y_at(x, z):
				return Vector2i(x, z)
	push_error("selftest: no generated water-table fixture found")
	return Vector2i.ZERO
