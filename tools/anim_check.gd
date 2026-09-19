extends Node
## Dev-only visual/print check for the walk/sprint/jump limb animations.
## `-- --animtest --skiptitle --no-input --fresh` drives the player through
## a sprint, then a jump, printing limb rotations so a recorded movie/
## screenshot can confirm the pose actually changes instead of freezing.
## Not part of the regular --selftest suite (which already asserts run
## speed/fov/lean) — this is just for eyeballing the new animation work.

var player: Player
var _frame := 0


func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			player.set_look(0.0, -0.15)
		10:
			print("animtest: walking")
			player.test_move = Vector2(0, -1)
		60:
			print("animtest: sprinting")
			player.test_run = true
		90:
			print("animtest: arm_l=%.2f leg_l=%.2f leg_r=%.2f (expect a wide, fast swing)"
				% [player._arm_l.rotation.x, player._leg_l.rotation.x, player._leg_r.rotation.x])
		100:
			print("animtest: jumping")
			player.test_jump = true
		106:
			print("animtest: airborne, vel_y=%.2f leg_l=%.2f leg_r=%.2f arm_l=%.2f (expect legs opposite each other, arms raised)"
				% [player.velocity.y, player._leg_l.rotation.x, player._leg_r.rotation.x, player._arm_l.rotation.x])
		118:
			print("animtest: airborne, vel_y=%.2f leg_l=%.2f leg_r=%.2f (expect legs to have swapped sides — alternating)"
				% [player.velocity.y, player._leg_l.rotation.x, player._leg_r.rotation.x])
		160:
			print("animtest: on_floor=%s (expect true — landed)" % player.is_on_floor())
		170:
			player.test_move = Vector2.ZERO
			player.test_run = false
			print("animtest: done")
