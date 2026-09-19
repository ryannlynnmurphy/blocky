extends Node3D
## Entry point. Wires the world, the player and the HUD together, owns
## saving/loading, and runs the screen state machine (title, playing,
## paused, dead, inventory).

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const AUTOSAVE_SECONDS := 30.0

enum State { TITLE, PLAYING, PAUSED, DEAD, INVENTORY, WORKBENCH, FURNACE }

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
	hud.visible = s != State.TITLE
	player.ui_open = not playing
	get_tree().paused = s in [State.TITLE, State.PAUSED, State.DEAD]
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if playing else Input.MOUSE_MODE_VISIBLE


## Kept for tests: opens/closes the inventory screen.
func set_inventory_open(open: bool) -> void:
	_enter(State.INVENTORY if open else State.PLAYING)


func respawn_from_death() -> void:
	player.respawn()
	_enter(State.PLAYING)


## Right-clicked a Bed. Only skips time at night (no "monsters nearby"
## block yet — that's Minecraft's rule, not implemented here).
func _try_sleep() -> void:
	if state != State.PLAYING:
		return
	if day_night.is_night():
		day_night.skip_to_morning()
		hud.show_message("Slept until morning")
	else:
		hud.show_message("Can't sleep now")


func _new_game(seed_text: String) -> void:
	var seed_value: int
	if seed_text.strip_edges() == "":
		seed_value = randi()
	elif seed_text.is_valid_int():
		seed_value = int(seed_text)
	else:
		seed_value = hash(seed_text)
	if SaveGame.exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	world.load_save_data({"seed": seed_value, "edits": {}})
	world.clear_entities()
	day_night.load_save_data({"time_of_day": day_night.start_time, "day_count": 1})
	player.reset_for_new_game()
	_place_player_at_spawn()
	_build_ground_under_player()
	_was_night = day_night.is_night()
	_enter(State.PLAYING)
	hud.show_message("Seed %d" % seed_value)


# ---------------------------------------------------------------- spawning

## Finds dry land near the spawn column and puts the player there.
func _place_player_at_spawn() -> void:
	var sx := _spawn_col.x
	var sz := _spawn_col.y
	while world.height_at(sx, sz) <= WorldGen.SEA_LEVEL + 2 and sx < 400:
		sx += 4
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
