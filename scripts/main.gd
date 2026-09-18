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

	# Find dry land near the origin to spawn on.
	var sx := 8
	while world.height_at(sx, 8) <= WorldGen.SEA_LEVEL + 2 and sx < 400:
		sx += 4
	var spawn := Vector3(sx + 0.5, world.height_at(sx, 8) + 2.0, 8.5)
	player.global_position = spawn

	# Build the ground under the player immediately so they don't fall
	# through the world while the rest streams in.
	var pc := world.chunk_coord_of(spawn)
	world.update_chunks(pc)
	world.build_chunk_now(pc)


func _process(_delta: float) -> void:
	# The water is one big flat plane that follows the player.
	water.global_position.x = player.global_position.x
	water.global_position.z = player.global_position.z
