class_name DayNight
extends Node3D
## The day/night cycle.
##
## Time of day is one number, 0.0 -> 1.0 over a full day:
##   0.0 midnight, 0.25 sunrise, 0.5 noon, 0.75 sunset, 1.0 midnight again.
## The Sun light is rotated around the world once per day; the Moon light
## is always on the exact opposite side. Every frame we look at how high
## the sun is and blend sky / fog / light colors between three palettes.

## Real seconds for one full in-game day.
@export var day_length_seconds := 600.0
## Where the day starts (0.3 = mid-morning).
@export var start_time := 0.3
## How much faster time runs while holding T.
@export var fast_forward := 40.0

var time_of_day := 0.0   # 0..1 within the current day
var day_count := 1

@onready var sun: DirectionalLight3D = $Sun
@onready var moon: DirectionalLight3D = $Moon
@onready var _env: Environment = get_node("../WorldEnvironment").environment
@onready var _sky: ProceduralSkyMaterial = _env.sky.sky_material

# ---- palettes: [sky top, sky horizon, ground] -------------------------------
const DAY := [Color(0.29, 0.55, 0.95), Color(0.72, 0.85, 0.98), Color(0.35, 0.45, 0.30)]
const SUNSET := [Color(0.25, 0.30, 0.55), Color(0.98, 0.58, 0.35), Color(0.22, 0.18, 0.18)]
const NIGHT := [Color(0.02, 0.03, 0.08), Color(0.07, 0.09, 0.18), Color(0.03, 0.04, 0.05)]

const SUN_COLOR_NOON := Color(1.0, 0.98, 0.92)
const SUN_COLOR_LOW := Color(1.0, 0.62, 0.38)
const MOON_COLOR := Color(0.55, 0.65, 1.0)


func _ready() -> void:
	time_of_day = start_time
	# The moon lights the ground but doesn't get its own disc in the sky.
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	# Testing aid: `godot --path . -- --day-length=5` makes a day last 5 s.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--day-length="):
			day_length_seconds = float(arg.get_slice("=", 1))
	_apply()


func _process(delta: float) -> void:
	var speed := 1.0 / day_length_seconds
	if Input.is_key_pressed(KEY_T):
		speed *= fast_forward
	time_of_day += delta * speed
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day_count += 1
	_apply()


## Height of the sun above the horizon: 1 straight overhead, -1 straight below.
func sun_elevation() -> float:
	return sin((time_of_day - 0.25) * TAU)


func is_night() -> bool:
	return sun_elevation() < -0.1


## "Day 3  14:07" for the HUD.
func clock_text() -> String:
	var minutes := int(time_of_day * 24.0 * 60.0)
	return "Day %d  %02d:%02d" % [day_count, minutes / 60, minutes % 60]


func _apply() -> void:
	# Rotate the sun. A DirectionalLight3D shines along its own -Z axis, and
	# tilting it by -90 degrees on X points it straight down (= noon).
	var angle := (time_of_day - 0.25) * TAU
	sun.rotation = Vector3(-angle, deg_to_rad(30.0), 0.0)
	moon.rotation = Vector3(-angle + PI, deg_to_rad(30.0), 0.0)

	var e := sun_elevation()

	# Pick the palette for this moment.
	var pal: Array
	if e >= 0.3:
		pal = DAY
	elif e >= 0.0:
		pal = _lerp_palette(SUNSET, DAY, e / 0.3)
	elif e >= -0.15:
		pal = _lerp_palette(NIGHT, SUNSET, (e + 0.15) / 0.15)
	else:
		pal = NIGHT

	_sky.sky_top_color = pal[0]
	_sky.sky_horizon_color = pal[1]
	_sky.ground_horizon_color = pal[1]
	_sky.ground_bottom_color = pal[2]
	_env.fog_light_color = pal[1]

	# Sunlight: orange and gentle when low, white and strong at noon. The
	# sky paints the sun disc as color x energy, so energy never drops
	# near zero while the sun is up (that would draw a black disc); the
	# light is simply switched off once the sun is below the horizon.
	var daylight := smoothstep(0.0, 0.3, e)
	sun.light_energy = lerpf(0.6, 1.25, daylight)
	sun.light_color = SUN_COLOR_LOW.lerp(SUN_COLOR_NOON, clampf(e / 0.35, 0.0, 1.0))
	sun.visible = e > -0.02

	# Moonlight: the opposite, dim and blue.
	var moonlight := 1.0 - smoothstep(-0.15, 0.05, e)
	moon.light_energy = moonlight * 0.12
	moon.light_color = MOON_COLOR
	moon.visible = moonlight > 0.001

	# Ambient (light from the sky itself) gets dim at night but never black.
	_env.ambient_light_energy = lerpf(0.25, 1.0, smoothstep(-0.15, 0.25, e))


## Sleeping in a bed: jump straight to the next sunrise.
func skip_to_morning() -> void:
	if time_of_day > 0.25:
		day_count += 1
	time_of_day = 0.25
	_apply()


func get_save_data() -> Dictionary:
	return {"time_of_day": time_of_day, "day_count": day_count}


func load_save_data(d: Dictionary) -> void:
	time_of_day = float(d.get("time_of_day", time_of_day))
	day_count = int(d.get("day_count", day_count))
	_apply()


func _lerp_palette(a: Array, b: Array, t: float) -> Array:
	return [a[0].lerp(b[0], t), a[1].lerp(b[1], t), a[2].lerp(b[2], t)]
