class_name Drop
extends Area3D
## A dropped item: a small spinning cube you pick up by walking into it.
## An Area3D doesn't block anything; it just reports what overlaps it.

var item_id := Blocks.MEAT

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


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		body.inventory.add(item_id)
		queue_free()
