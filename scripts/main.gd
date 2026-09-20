extends Node3D
## Entry point. Wires the world, the player and the HUD together, owns
## saving/loading, and runs the screen state machine (title, playing,
## paused, dead, inventory).

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const AUTOSAVE_SECONDS := 30.0
## How far below the voxel world's own terrain (which never generates below
## y=0 -- one vertical chunk per column, see README) an embedded city-block
## instance is offset, so the two can share one scene tree/physics world
## with zero chance of spatial or collision overlap however far the player
## has explored. Same "pocket dimension via a Y offset" technique
## scripts/city_block.gd already uses for its own interiors (INTERIOR_Y).
const CITY_EMBED_Y_OFFSET := -500.0

enum State { TITLE, CREATOR, PLAYING, PAUSED, DEAD, INVENTORY, WORKBENCH, FURNACE, CITY }

@onready var world: VoxelWorld = $World
@onready var player: Player = $Player
@onready var day_night: DayNight = $DayNight
@onready var hud := $HUD

var state := State.TITLE
var screens: Screens
var sfx: Sfx
## Where this session saves. Tests point it at a throwaway file so they
## can never touch the real save.
var save_path: String = SAVE_PATH
var _autosave_timer := 0.0
var _was_night := false
var _spawn_col := Vector2i(8, 8)
var person_profile := PersonProfile.new()
var _pending_seed := 0
## B5: the embedded city-block instance and its walker while State.CITY is
## active, else null. See _enter_city()/_exit_city().
var _city: Node3D = null
var _city_walker: CityWalker = null


func _ready() -> void:
	print("Voxel RPG booted. Godot %s" % Engine.get_version_info()["string"])
	process_mode = Node.PROCESS_MODE_ALWAYS   # menus and Esc must work while paused
	world.process_mode = Node.PROCESS_MODE_ALWAYS   # chunks keep streaming behind the title
	var args := OS.get_cmdline_user_args()
	world.player = player
	world.day_night = day_night
	player.world = world
	# Testing aids: `-- --perf` prints chunk timings; `-- --radius=8` sets view distance.
	world.perf_enabled = "--perf" in args
	for arg in args:
		if arg.begins_with("--radius="):
			world.view_radius = int(arg.get_slice("=", 1))
	# Fog fades the world out just before the edge of the loaded chunks,
	# so you never see terrain stop dead.
	var view_dist := float(world.view_radius * VoxelWorld.SIZE)
	var env: Environment = $WorldEnvironment.environment
	env.fog_depth_begin = view_dist * 0.6
	env.fog_depth_end = view_dist * 0.97

	# All sound is synthesized here at startup.
	sfx = Sfx.new()
	sfx.name = "Sfx"
	sfx.day_night = day_night
	add_child(sfx)
	player.inventory.added.connect(func(_id: int, _n: int): Sfx.play("pickup", null, 0.05, -6.0))

	# Testing aid: `godot --path . -- --spawn=-300,-20` spawns at that column.
	for arg in args:
		if arg.begins_with("--spawn="):
			var xy := arg.get_slice("=", 1).split(",")
			_spawn_col = Vector2i(int(xy[0]), int(xy[1]))
	_place_player_at_spawn()

	# Testing aid: `-- --save=user://x.json` uses another save file.
	for arg in args:
		if arg.begins_with("--save="):
			save_path = arg.get_slice("=", 1)
	# Continue the saved game unless told to start over.
	if "--fresh" not in args and SaveGame.exists(save_path):
		load_game()
		print("Loaded save from %s" % ProjectSettings.globalize_path(save_path))

	hud.bind_player(player)
	hud.bind_day_night(day_night)
	hud.bind_world(world, player)
	_build_ground_under_player()

	# Menus.
	screens = Screens.new()
	screens.name = "Screens"
	add_child(screens)
	screens.continue_pressed.connect(func(): _enter(State.PLAYING))
	screens.new_game_pressed.connect(_new_game)
	screens.person_confirmed.connect(_finish_new_game)
	screens.creator_cancelled.connect(func(): _enter(State.TITLE))
	screens.quit_pressed.connect(func(): get_tree().quit())
	screens.resume_pressed.connect(func(): _enter(State.PLAYING))
	screens.save_pressed.connect(func():
		save_game()
		hud.show_message("Saved"))
	screens.to_title_pressed.connect(func():
		if state != State.DEAD:
			save_game()
		_enter(State.TITLE))
	screens.respawn_pressed.connect(respawn_from_death)
	screens.sfx_volume_changed.connect(_set_sfx_volume)
	screens.visit_city_pressed.connect(_enter_city)
	player.died.connect(func():
		if state == State.PLAYING:
			_enter(State.DEAD))
	player.workbench_used.connect(func():
		if state == State.PLAYING:
			_enter(State.WORKBENCH))
	player.furnace_used.connect(func():
		if state == State.PLAYING:
			_enter(State.FURNACE))
	player.sleep_requested.connect(_try_sleep)
	player.tool_broke.connect(func(item_name: String): hud.show_message("%s broke!" % item_name))
	player.ate_meat.connect(func(): PersonActions.eat(day_night, person_profile))
	_load_settings()

	# We save on close, so ask Godot not to quit on its own.
	get_tree().set_auto_accept_quit(false)
	_was_night = day_night.is_night()   # no banner at startup

	# Testing aid: `-- --critter` puts one animal right in front of you.
	if "--critter" in args:
		world.spawn_creature(_spawn_col.x, _spawn_col.y - 3)
	# Testing aid: `-- --look=3.14,-0.3` points the camera (yaw, pitch in radians).
	for arg in args:
		if arg.begins_with("--look="):
			var yp := arg.get_slice("=", 1).split(",")
			player.set_look(float(yp[0]), float(yp[1]))
	# Testing aid: `-- --selftest` exercises the game's systems automatically.
	var selftest := "--selftest" in args
	if selftest:
		var test: Node = load("res://tools/selftest.gd").new()
		test.player = player
		test.world = world
		test.main = self
		test.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(test)

	# Testing aid: `-- --animtest` drives a sprint then a jump so the new
	# limb-animation work can be watched/recorded (see tools/anim_check.gd).
	if "--animtest" in args:
		var anim_test: Node = load("res://tools/anim_check.gd").new()
		anim_test.player = player
		anim_test.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(anim_test)

	# Testing aid: `-- --citytest` drives a full State.CITY round trip (see
	# tools/city_integration_check.gd) to prove B5's real main.gd
	# integration, not just the standalone city_block.tscn preview.
	if "--citytest" in args:
		var city_test: Node = load("res://tools/city_integration_check.gd").new()
		city_test.main = self
		city_test.player = player
		city_test.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(city_test)

	# Start on the title screen, unless a test or recording wants to skip it.
	if selftest or "--skiptitle" in args:
		_enter(State.PLAYING)
	else:
		_enter(State.TITLE)

	# Testing aid: `-- --show-inventory` stocks the bag and opens the pockets
	# screen, for UI screenshots.
	if "--show-inventory" in args:
		for id in [Blocks.LOG, Blocks.STONE, Blocks.PLANKS, Blocks.STICK,
				Blocks.COAL, Blocks.IRON_ORE, Blocks.DIRT, Blocks.SAND]:
			player.inventory.add(id, 8)
		set_inventory_open(true)

	# Testing aid: `-- --show-creator` opens Create a Person directly, for
	# wardrobe/preview screenshots without clicking through the title screen.
	if "--show-creator" in args:
		_enter(State.CREATOR)


func _process(delta: float) -> void:
	if state not in [State.PLAYING, State.INVENTORY, State.WORKBENCH, State.FURNACE]:
		return
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_SECONDS:
		_autosave_timer = 0.0
		save_game()

	# Announce dusk and dawn.
	var night := day_night.is_night()
	if night != _was_night:
		_was_night = night
		hud.show_message("Night falls. Something stirs." if night else "Dawn.")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode
	match state:
		State.PLAYING:
			if key == KEY_ESCAPE:
				_enter(State.PAUSED)
			elif key == KEY_TAB:
				_enter(State.INVENTORY)
			elif key == KEY_F5:
				save_game()
				hud.show_message("Saved")
		State.PAUSED:
			if key == KEY_ESCAPE:
				_enter(State.PLAYING)
		State.INVENTORY, State.WORKBENCH, State.FURNACE:
			if key == KEY_ESCAPE or key == KEY_TAB:
				_enter(State.PLAYING)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if state != State.TITLE:
			save_game()
		get_tree().quit()


# ---------------------------------------------------------------- screens

## The one place that decides what's on screen, whether the game runs,
## and whether the mouse is captured.
func _enter(s: State) -> void:
	state = s
	screens.hide_all()
	hud.set_inventory_open(false)
	match s:
		State.TITLE:
			screens.show_title(SaveGame.exists(save_path))
		State.CREATOR:
			screens.show_creator(person_profile)
		State.PAUSED:
			screens.show_pause()
		State.DEAD:
			screens.show_death()
		State.INVENTORY:
			hud.set_inventory_open(true)
		State.WORKBENCH:
			hud.set_inventory_open(true, "bench")
		State.FURNACE:
			hud.set_inventory_open(true, "furnace")
	var playing := s == State.PLAYING
	hud.visible = s != State.TITLE and s != State.CITY
	player.ui_open = not playing
	get_tree().paused = s in [State.TITLE, State.CREATOR, State.PAUSED, State.DEAD, State.CITY]
	var mouse_needed := s in [State.PLAYING, State.CITY]
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_needed else Input.MOUSE_MODE_VISIBLE


## B5: "Visit Hollowmark" on the title screen AND the pause menu call this
## instead of _enter(State.CITY) directly -- entering the city needs to
## build and embed the scene first, which a plain state switch can't do.
## Ignores a repeat press while already visiting.
func _enter_city() -> void:
	if _city:
		return
	var city: Node3D = load("res://scenes/city_block.tscn").instantiate()
	city.standalone = false
	city.process_mode = Node.PROCESS_MODE_ALWAYS   # keep working while get_tree().paused is true, same technique `world` already uses
	city.position = Vector3(0, CITY_EMBED_Y_OFFSET, 0)
	add_child(city)
	_city = city
	_city_walker = city.spawn_walker()
	_city_walker.standalone = false
	_city_walker.exit_requested.connect(_exit_city)
	_city_walker.work_requested.connect(_on_city_work_requested)
	_enter(State.CITY)


## S2: E pressed near the workplace workbench (scripts/city_walker.gd's
## work_requested, gated by CityBlock's work trigger). No visible in-city
## feedback yet (the HUD is hidden throughout State.CITY, and a proper "you
## earned $X" moment is presentation work, not this card's job) -- printed
## so it's still verifiable, same as every other dev/test print in this
## project.
func _on_city_work_requested() -> void:
	PersonActions.work(day_night, person_profile)
	print("Worked a shift: +$%d, needs now %s" % [PersonActions.WORK_PAY, person_profile.data["needs"]])


## scripts/city_walker.gd's exit_requested signal (Esc), only reachable
## while embedded (standalone = false, i.e. actually State.CITY).
func _exit_city() -> void:
	if _city:
		_city.queue_free()   # deferred: safe to call from a signal this same node's own subtree just emitted
		_city = null
		_city_walker = null
	player.activate_camera()
	_enter(State.PLAYING)


## Kept for tests: opens/closes the inventory screen.
func set_inventory_open(open: bool) -> void:
	_enter(State.INVENTORY if open else State.PLAYING)


func respawn_from_death() -> void:
	player.respawn()
	_enter(State.PLAYING)


## Right-clicked a Bed. Skips time at night, unless a hostile is close
## enough to be a real threat — Hostile.SIGHT, the same range it uses to
## notice and chase the player in the first place.
func _try_sleep() -> void:
	if state != State.PLAYING:
		return
	if not day_night.is_night():
		hud.show_message("Can't sleep now")
		return
	if world.hostile_near(player.global_position, Hostile.SIGHT):
		hud.show_message("Too dangerous to sleep")
		return
	# S2: measure the real jump via day_night's own clock (total_minutes(),
	# added by S0) instead of re-deriving sunrise math here -- correct
	# whether skip_to_morning() rolls into the next day or not.
	var before_minutes := day_night.total_minutes()
	day_night.skip_to_morning()
	var hours_asleep := (day_night.total_minutes() - before_minutes) / 60.0
	PersonActions.sleep(person_profile, hours_asleep)
	hud.show_message("Slept until morning")


func _new_game(seed_text: String) -> void:
	var seed_value: int
	if seed_text.strip_edges() == "":
		seed_value = randi()
	elif seed_text.is_valid_int():
		seed_value = int(seed_text)
	else:
		seed_value = hash(seed_text)
	_pending_seed = seed_value
	person_profile = PersonProfile.new()
	_enter(State.CREATOR)


func _finish_new_game() -> void:
	if SaveGame.exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	world.load_save_data({"seed": _pending_seed, "edits": {}})
	world.clear_entities()
	day_night.load_save_data({"time_of_day": day_night.start_time, "day_count": 1})
	player.reset_for_new_game()
	player.set_person_profile(person_profile.to_dict())
	_place_player_at_spawn()
	_build_ground_under_player()
	_was_night = day_night.is_night()
	_enter(State.PLAYING)
	hud.show_message("%s begins a new life" % person_profile.display_name())


# ---------------------------------------------------------------- spawning

## Puts the player on terrain near the spawn column.
func _place_player_at_spawn() -> void:
	var sx := _spawn_col.x
	var sz := _spawn_col.y
	var spawn := Vector3(sx + 0.5, world.height_at(sx, sz) + 2.0, sz + 0.5)
	player.global_position = spawn
	player.spawn_point = spawn


## Builds the chunk under the player immediately so they don't fall
## through the world while the rest streams in.
func _build_ground_under_player() -> void:
	var pc := world.chunk_coord_of(player.global_position)
	world.update_chunks(pc)
	world.build_chunk_now(pc)


# ---------------------------------------------------------------- saving

func save_game(path: String = "") -> bool:
	if path == "":
		path = save_path
	var data := {
		"version": 1,
		"world": world.get_save_data(),
		"player": player.get_save_data(),
		"time": day_night.get_save_data(),
		"person": person_profile.to_dict(),
	}
	return SaveGame.write(path, data)


func load_game(path: String = "") -> bool:
	if path == "":
		path = save_path
	var data := SaveGame.read(path)
	if data.is_empty():
		return false
	world.load_save_data(data.get("world", {}))
	player.load_save_data(data.get("player", {}))
	day_night.load_save_data(data.get("time", {}))
	person_profile.load_dict(data.get("person", {}))
	player.set_person_profile(person_profile.to_dict())
	_build_ground_under_player()
	return true


func _set_sfx_volume(v: float) -> void:
	sfx.set_volume(v)
	SaveGame.write(SETTINGS_PATH, {"sfx_volume": v})


func _load_settings() -> void:
	var s := SaveGame.read(SETTINGS_PATH)
	var v := float(s.get("sfx_volume", 1.0))
	sfx.set_volume(v)
	screens.set_volume_slider(v)
