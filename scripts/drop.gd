class_name Drop
extends Area3D
## A dropped item: a small spinning cube of the item's colour.
## Once the player is within MAGNET_RANGE it glides toward them and is
## collected up close, so picking things up never needs a precise touch.

const MAGNET_RANGE := 2.5
const MAGNET_SPEED := 7.0
const COLLECT_RANGE := 0.7

var item_id := Blocks.MEAT
var player: Node3D   # set by the world; may be null in tests

var _mesh := MeshInstance3D.new()
var _time := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1   # the player is on layer 1
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.3, 0.3)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Blocks.face_color(item_id, 1)
	mat.roughness = 1.0
	_mesh.mesh = box
	_mesh.material_override = mat
	_mesh.position.y = 0.3
	add_child(_mesh)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	shape.shape = sphere
	shape.position.y = 0.3
	add_child(shape)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	_mesh.rotation.y += 2.0 * delta
	_mesh.position.y = 0.3 + sin(_time * 3.0) * 0.06   # gentle bob

	if player == null:
		return
	# Aim for the player's middle, not their feet.
	var target: Vector3 = player.global_position + Vector3(0, 0.6, 0)
	var dist := global_position.distance_to(target)
	if dist < COLLECT_RANGE:
		_collect(player)
	elif dist < MAGNET_RANGE:
		global_position = global_position.move_toward(target, MAGNET_SPEED * delta)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_collect(body)


func _collect(who: Node3D) -> void:
	if not is_queued_for_deletion():
		who.inventory.add(item_id)
		queue_free()
