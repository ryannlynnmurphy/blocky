extends Node3D
## Entry point. Wires the world, the player and the HUD together.

@onready var world: VoxelWorld = $World
@onready var player: Player = $Player
@onready var water: MeshInstance3D = $Water
@onready var hud := $HUD


func _ready() -> void:
	print("Voxel RPG booted. Godot %s" % Engine.get_version_info()["string"])
	world.player = player
	player.world = world
	hud.bind_player(player)
	hud.bind_day_night($DayNight)
	hud.bind_world(world, player)

	# Find dry land near the origin to spawn on.
	var sx := 8
	var sz := 8
	# Testing aid: `godot --path . -- --spawn=-300,-20` spawns at that column.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--spawn="):
			var xy := arg.get_slice("=", 1).split(",")
			sx = int(xy[0])
			sz = int(xy[1])
	while world.height_at(sx, sz) <= WorldGen.SEA_LEVEL + 2 and sx < 400:
		sx += 4
	var spawn := Vector3(sx + 0.5, world.height_at(sx, sz) + 2.0, sz + 0.5)
	player.global_position = spawn

	# Build the ground under the player immediately so they don't fall
	# through the world while the rest streams in.
	var pc := world.chunk_coord_of(spawn)
	world.update_chunks(pc)
	world.build_chunk_now(pc)

	# Testing aid: `-- --critter` puts one animal right in front of you.
	if "--critter" in OS.get_cmdline_user_args():
		world.spawn_creature(sx, sz - 3)


func _process(_delta: float) -> void:
	# The water is one big flat plane that follows the player.
	water.global_position.x = player.global_position.x
	water.global_position.z = player.global_position.z
