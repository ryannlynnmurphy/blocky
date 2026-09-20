class_name Hostile
extends Creature
## The Shade: comes out at night, hunts the player, burns away at dawn.
## It reuses the critter's body plumbing (gravity, hopping, cliff
## checks, hit flash, knockback) and replaces the brain.

const SIGHT := 18.0        # blocks; closer than this and it comes for you
const CHASE_SPEED := 4.0   # slower than sprinting, about walking pace
const BITE_RANGE := 1.7
const BITE_DAMAGE := 2
const BITE_COOLDOWN := 1.2
const SHADE_HEALTH := 5
const SHADE_XP := 10
const BURN_INTERVAL := 0.5   # seconds per health lost in daylight

var _bite_cooldown := 0.6    # a moment's grace when it first reaches you
var _burn_timer := 0.0
var _groan_timer := 2.0


func _init() -> void:
	body_color = Color(0.16, 0.12, 0.22)
	health = SHADE_HEALTH


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	_bite_cooldown = maxf(_bite_cooldown - delta, 0.0)
	_groan_timer -= delta
	if _groan_timer <= 0.0:
		_groan_timer = _rng.randf_range(3.0, 7.0)
		Sfx.play("groan", global_position, 0.2, -4.0)
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_mat.albedo_color = body_color

	# Daylight is fatal.
	if world != null and world.day_night != null and world.day_night.sun_elevation() > 0.05:
		_burn_timer += delta
		if _burn_timer >= BURN_INTERVAL:
			_burn_timer = 0.0
			health -= 1
			_mat.albedo_color = body_color.lerp(Color(1.0, 0.5, 0.1), 0.8)
			_flash_timer = 0.25
			if health <= 0:
				_die()
				return

	# Hunt the player if they're close enough; otherwise wander.
	var chasing := false
	var target: Node3D = world.player if world != null else null
	if target != null:
		var to := target.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist < SIGHT:
			chasing = true
			_wandering = true
			_dir = to.normalized()
			if dist < BITE_RANGE and _bite_cooldown <= 0.0:
				_bite(target)
	if not chasing:
		_timer -= delta
		if _timer <= 0.0:
			if _wandering:
				_go_idle()
			else:
				_go_wander()

	if _wandering:
		if not chasing and _path_blocked():
			_go_wander()
		var speed := CHASE_SPEED if chasing else WALK_SPEED
		velocity.x = _dir.x * speed
		velocity.z = _dir.z * speed
		if is_on_floor() and is_on_wall():
			velocity.y = JUMP_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

	velocity.x += _knock.x
	velocity.z += _knock.z
	_knock = _knock.move_toward(Vector3.ZERO, 25.0 * delta)
	move_and_slide()

	if _wandering:
		var facing := atan2(-_dir.x, -_dir.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, facing, 8.0 * delta)


func _bite(target: Node3D) -> void:
	_bite_cooldown = BITE_COOLDOWN
	if target is Player:
		var away := target.global_position - global_position
		away.y = 0.0
		away = away.normalized()
		target.take_damage(BITE_DAMAGE)
		target.apply_knockback(away * 6.0 + Vector3.UP * 3.0)
		Sfx.play("bite", global_position, 0.1)


## Being hit doesn't scare it off.
func take_hit(damage: int, from: Vector3, attacker: Node = null) -> void:
	super(damage, from, attacker)
	_flee_timer = 0.0


## No meat from a Shade, just the XP.
func _die() -> void:
	if _last_attacker is Player:
		_last_attacker.gain_xp(SHADE_XP)
	queue_free()
