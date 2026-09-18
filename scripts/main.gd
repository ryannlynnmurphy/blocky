extends Node3D
## Entry point. Wires the world, the player and the HUD together, and
## owns saving/loading.

const SAVE_PATH := "user://save.json"
const AUTOSAVE_SECONDS := 30.0

@onready var world: VoxelWorld = $World
@onready var player: Player = $Player
@onready var water: MeshInstance3D = $Water
@onready var day_night: DayNight = $DayNight
@onready var hud := $HUD

var _autosave_timer := 0.0
var _was_night := false


func _ready() -> void:
	print("Voxel RPG booted. Godot %s" % Engine.get_version_info()["string"])
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

	# Find dry land near the origin to spawn on.
	var sx := 8
	var sz := 8
	# Testing aid: `godot --path . -- --spawn=-300,-20` spawns at that column.
	for arg in args:
		if arg.begins_with("--spawn="):
			var xy := arg.get_slice("=", 1).split(",")
			sx = int(xy[0])
			sz = int(xy[1])
	while world.height_at(sx, sz) <= WorldGen.SEA_LEVEL + 2 and sx < 400:
		sx += 4
	var spawn := Vector3(sx + 0.5, world.height_at(sx, sz) + 2.0, sz + 0.5)
	player.global_position = spawn
	player.spawn_point = spawn

	# Continue the saved game unless told to start over.
	if "--fresh" not in args and SaveGame.exists(SAVE_PATH):
		load_game()
		print("Loaded save from %s" % ProjectSettings.globalize_path(SAVE_PATH))

	hud.bind_player(player)
	hud.bind_day_night(day_night)
	hud.bind_world(world, player)
	_build_ground_under_player()

	# We save on close, so ask Godot not to quit on its own.
	get_tree().set_auto_accept_quit(false)
	_was_night = day_night.is_night()   # no banner at startup

	# Testing aid: `-- --look=3.14,-0.3` points the camera (yaw, pitch in radians).
	for arg in args:
		if arg.begins_with("--look="):
			var yp := arg.get_slice("=", 1).split(",")
			player.set_look(float(yp[0]), float(yp[1]))
	# Testing aid: `-- --critter` puts one animal right in front of you.
	if "--critter" in args:
		world.spawn_creature(sx, sz - 3)
	# Testing aid: `-- --selftest` exercises the game's systems automatically.
	if "--selftest" in args:
		var test: Node = load("res://tools/selftest.gd").new()
		test.player = player
		test.world = world
		test.main = self
		add_child(test)


func _process(delta: float) -> void:
	# The water is one big flat plane that follows the player.
	water.global_position.x = player.global_position.x
	water.global_position.z = player.global_position.z

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
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_F5:
			save_game()
			hud.show_message("Saved")
		elif key == KEY_TAB:
			set_inventory_open(not hud.is_inventory_open())
		elif key == KEY_ESCAPE and hud.is_inventory_open():
			set_inventory_open(false)


## Opens/closes the inventory screen; the player stops taking input and
## the mouse is freed while it's open.
func set_inventory_open(open: bool) -> void:
	hud.set_inventory_open(open)
	player.ui_open = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()


## Builds the chunk under the player immediately so they don't fall
## through the world while the rest streams in.
func _build_ground_under_player() -> void:
	var pc := world.chunk_coord_of(player.global_position)
	world.update_chunks(pc)
	world.build_chunk_now(pc)


# ---------------------------------------------------------------- saving

func save_game(path: String = SAVE_PATH) -> bool:
	var data := {
		"version": 1,
		"world": world.get_save_data(),
		"player": player.get_save_data(),
		"time": day_night.get_save_data(),
	}
	return SaveGame.write(path, data)


func load_game(path: String = SAVE_PATH) -> bool:
	var data := SaveGame.read(path)
	if data.is_empty():
		return false
	world.load_save_data(data.get("world", {}))
	player.load_save_data(data.get("player", {}))
	day_night.load_save_data(data.get("time", {}))
	_build_ground_under_player()
	return true
