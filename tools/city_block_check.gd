extends SceneTree
## Dev tool: loads scenes/city_block.tscn standalone (it is NOT wired into
## main.gd/the --selftest suite yet — that's B5's job, a later card), and
## checks the things B1's acceptance check actually requires: it opens
## without errors, collision shapes exist on the ground/buildings/props
## (not just visuals), and a CharacterBody3D test capsule dropped onto the
## street can really move across the block under move_and_slide(), not just
## look like it can.
##
##   godot --headless --path . --fixed-fps 60 --script tools/city_block_check.gd --quit-after 420
##
## --fixed-fps 60 matters here: without it, --quit-after counts idle frames,
## and this scene is light enough that idle frames can outrun the fixed
## physics timestep by a wide margin, so the walk test never accumulates
## enough physics ticks to finish before quitting.
##
## Capsule shape/radius match scenes/player.tscn (radius 0.25, height 1.1).
## NOTE: the collision-shape offset below (half of CAPSULE_HEIGHT) was
## chosen from measuring this engine directly, not assumed — dropping a
## bare capsule onto a flat box and watching it settle showed
## CapsuleShape3D's total tip-to-tip height equals `height` itself here
## (i.e. the two hemispherical caps are NOT extra on top of `height`),
## which is the opposite of what the 2026-09-20 "REGRESSION FIX" board
## entry states ("total = height + 2*radius"). Using that entry's formula
## for this offset made a bare capsule settle 0.25 m (exactly one radius)
## into the ground instead of on top of it. This tool uses the
## empirically-measured value; scenes/player.tscn itself is untouched (out
## of scope for B1/B2, and the real game's collision is against solid
## voxel chunks, not a thin flat slab, so a small offset there may not be
## visible the same way) — flagged in the board handoff for whoever owns
## player.gd/player.tscn next to double-check.

const WALK_SPEED := 4.5   # matches scripts/player.gd's WALK_SPEED
const GRAVITY := 22.0     # matches scripts/player.gd's GRAVITY
const CAPSULE_RADIUS := 0.25
const CAPSULE_HEIGHT := 1.1
const SETTLE_FRAME := 40    # ~0.67s at 60fps — comfortably more than the ~27 frames a 2.2m fall under GRAVITY=22 needs
const WALK_FRAMES := 360    # 6s at WALK_SPEED 4.5 = ~27m, most of the ~43m clear street run from spawn to the far end

var block: Node3D
var capsule: CharacterBody3D
var _capsule_frame := 0   # counts physics frames since the capsule was spawned, not since boot
var _start_pos := Vector3.ZERO
var _reported_audit := false
var _reported_settle := false
var _reported_move := false


func _init() -> void:
	block = load("res://scenes/city_block.tscn").instantiate()
	get_root().add_child(block)
	print("city_block_check: scene loaded without error")
	# block._ready() (which builds all the geometry) only runs once the
	# node actually enters the live tree — that happens on the next frame,
	# not synchronously here — so the collision audit and capsule spawn are
	# deferred into _physics_process below, not done inline in _init().


static func _count_collision(node: Node) -> Vector2i:
	var count := Vector2i.ZERO
	if node is StaticBody3D:
		count.x += 1
		for c in node.get_children():
			if c is CollisionShape3D and (c as CollisionShape3D).shape:
				count.y += 1
	for c in node.get_children():
		count += _count_collision(c)
	return count


func _physics_process(delta: float) -> bool:
	if not _reported_audit:
		_reported_audit = true
		var counts := _count_collision(block)
		print("city_block_check: %d StaticBody3D node(s), %d with a real CollisionShape3D (expect both > 15 — ground, 3 building shells, and every placed prop)"
			% [counts.x, counts.y])
		print("city_block_check: %d location(s) registered: %s (expect apartment, street, park, cafe, workplace)"
			% [block.location_positions.size(), ", ".join(block.location_positions.keys())])

		capsule = CharacterBody3D.new()
		capsule.name = "TestCapsule"
		var shape := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = CAPSULE_RADIUS
		cap.height = CAPSULE_HEIGHT
		shape.shape = cap
		shape.position = Vector3(0.0, CAPSULE_HEIGHT * 0.5, 0.0)
		capsule.add_child(shape)
		# Drop it just above the street near the apartment end, so a
		# straight walk down the spine crosses the whole block toward the
		# workplace end.
		capsule.position = Vector3(-20.0, 3.0, 0.0)
		get_root().add_child(capsule)
		_start_pos = capsule.position
		return false

	_capsule_frame += 1
	var vel := capsule.velocity
	if not capsule.is_on_floor():
		vel.y -= GRAVITY * delta
	else:
		vel.y = 0.0
	vel.x = WALK_SPEED if _capsule_frame > SETTLE_FRAME else 0.0
	capsule.velocity = vel
	capsule.move_and_slide()

	if _capsule_frame == SETTLE_FRAME and not _reported_settle:
		_reported_settle = true
		print("city_block_check: capsule settled at y=%.2f, on_floor=%s (expect on_floor true — real ground collision, not falling through)"
			% [capsule.position.y, capsule.is_on_floor()])

	if _capsule_frame == SETTLE_FRAME + WALK_FRAMES and not _reported_move:
		_reported_move = true
		var moved := capsule.position.distance_to(_start_pos)
		print("city_block_check: after %d physics frames of walking, moved %.1f m along the street (expect > 25 — collision-driven traversal across most of the block, not a teleport or a wall stopping it dead)"
			% [WALK_FRAMES, moved])
		print("city_block_check: final position %s, still on_floor=%s" % [capsule.position, capsule.is_on_floor()])
	return false
