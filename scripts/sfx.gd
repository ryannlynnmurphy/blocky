class_name Sfx
extends Node
## All game audio, synthesized at startup. No sound files.
##
## A sound here is just a list of numbers between -1 and 1 (the speaker
## position over time). We make them from two ingredients:
##   - noise: random numbers, run through a low-pass filter to soften
##   - tones: sine or sawtooth waves whose pitch can slide
## then shape the volume with an envelope that fades out. That's enough
## for thuds, clicks, crunches, chirps and wind.
##
## Usage anywhere:  Sfx.play("crack", position)   (position optional)

const RATE := 22050          # samples per second; low-fi suits the look
const POOL_3D := 10
const POOL_2D := 4
const SFX_DB := -9.0         # overall loudness of effects (ambience is separate)

static var instance: Sfx

var day_night: DayNight       # for the day/night ambience crossfade
var plays := {}               # name -> how many times played (tests)

var _sounds := {}             # name -> AudioStreamWAV
var _sfx_bus := -1
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d: Array[AudioStreamPlayer] = []
var _amb_day: AudioStreamPlayer
var _amb_night: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	instance = self
	_rng.seed = 1234   # same seed = identical sounds every run
	var t0 := Time.get_ticks_msec()
	_build_sounds()
	print("sfx: synthesized %d sounds in %d ms" % [_sounds.size(), Time.get_ticks_msec() - t0])

	# All effects go through their own bus so one number sets their loudness.
	_sfx_bus = AudioServer.bus_count
	AudioServer.add_bus(_sfx_bus)
	AudioServer.set_bus_name(_sfx_bus, "SFX")
	AudioServer.set_bus_volume_db(_sfx_bus, SFX_DB)

	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.max_distance = 40.0
		p.bus = "SFX"
		add_child(p)
		_pool_3d.append(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool_2d.append(p)

	_amb_day = _make_ambient("amb_day")
	_amb_night = _make_ambient("amb_night")

	# A limiter on the master bus: however many sounds pile up at once
	# (a landing, a hurt and a bite in the same frame), the output can't
	# clip into distortion.
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, limiter)

	if "--mute" in OS.get_cmdline_user_args():
		AudioServer.set_bus_mute(0, true)


## Player-facing volume, 0..1, on top of the built-in SFX_DB level.
func set_volume(v: float) -> void:
	AudioServer.set_bus_volume_db(_sfx_bus, SFX_DB + linear_to_db(maxf(v, 0.001)))


## Stop the loops before the tree tears down, or the audio thread still
## holds them and Godot reports leaked objects at exit.
func _exit_tree() -> void:
	_amb_day.stop()
	_amb_night.stop()
	for p in _pool_3d:
		p.stop()
	for p in _pool_2d:
		p.stop()
	if instance == self:
		instance = null


func _make_ambient(name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _sounds[name]
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


func _process(_delta: float) -> void:
	if day_night == null:
		return
	var e := day_night.sun_elevation()
	var day := smoothstep(-0.1, 0.2, e)
	var night := 1.0 - smoothstep(-0.2, 0.05, e)
	# Ambience sits far in the background — barely there.
	_amb_day.volume_db = linear_to_db(maxf(day, 0.001)) - 30.0
	_amb_night.volume_db = linear_to_db(maxf(night, 0.001)) - 28.0


## Plays a named sound. With a position it comes from that spot in the
## world; without one it plays flat (UI, the player's own body).
static func play(name: String, pos = null, pitch_var := 0.1, volume_db := 0.0) -> void:
	if instance != null:
		instance._play(name, pos, pitch_var, volume_db)


func _play(name: String, pos, pitch_var: float, volume_db: float) -> void:
	var stream: AudioStreamWAV = _sounds.get(name)
	if stream == null:
		push_warning("Sfx: no sound named '%s'" % name)
		return
	plays[name] = plays.get(name, 0) + 1
	var pitch := 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	if pos == null:
		for p in _pool_2d:
			if not p.playing:
				p.stream = stream
				p.pitch_scale = pitch
				p.volume_db = volume_db
				p.play()
				return
	else:
		for p in _pool_3d:
			if not p.playing:
				p.stream = stream
				p.pitch_scale = pitch
				p.volume_db = volume_db
				p.global_position = pos
				p.play()
				return
	# All players busy: drop the sound. Nobody notices one missing footstep.


# ---------------------------------------------------------------- the sounds

func _build_sounds() -> void:
	# Footsteps: soft noise puffs with different "materials".
	_sounds["step_grass"] = _wav(_noise(0.09, 40.0, 0.12, 0.35))
	_sounds["step_sand"] = _wav(_noise(0.11, 35.0, 0.28, 0.3))
	_sounds["step_stone"] = _wav(_mix([_noise(0.06, 90.0, 0.6, 0.35), _tone(0.06, 180.0, 120.0, 60.0, 0.25, false)]))
	_sounds["step_snow"] = _wav(_crunch(0.12, 0.3))
	_sounds["step_wood"] = _wav(_mix([_tone(0.08, 220.0, 160.0, 45.0, 0.3, false), _noise(0.05, 80.0, 0.3, 0.15)]))
	# Digging.
	_sounds["tick"] = _wav(_mix([_noise(0.04, 120.0, 0.5, 0.4), _tone(0.04, 600.0, 300.0, 100.0, 0.2, false)]))
	_sounds["crack"] = _wav(_mix([_noise(0.18, 25.0, 0.35, 0.5), _tone(0.15, 300.0, 80.0, 25.0, 0.3, true)]))
	_sounds["place"] = _wav(_mix([_tone(0.09, 200.0, 110.0, 40.0, 0.35, false), _noise(0.04, 100.0, 0.4, 0.15)]))
	# Hits.
	_sounds["thud"] = _wav(_mix([_tone(0.12, 120.0, 50.0, 30.0, 0.45, false), _noise(0.06, 60.0, 0.2, 0.2)]))
	_sounds["hurt"] = _wav(_mix([_tone(0.15, 400.0, 150.0, 20.0, 0.3, true), _noise(0.1, 40.0, 0.3, 0.2)]))
	_sounds["bite"] = _wav(_mix([_tone(0.12, 250.0, 90.0, 25.0, 0.35, true), _noise(0.1, 40.0, 0.5, 0.3)]))
	_sounds["land"] = _wav(_mix([_tone(0.15, 90.0, 40.0, 25.0, 0.35, false), _noise(0.1, 40.0, 0.15, 0.2)]))
	# Small events.
	_sounds["pickup"] = _wav(_concat([_tone(0.05, 880.0, 880.0, 30.0, 0.2, false), _tone(0.08, 1320.0, 1320.0, 30.0, 0.2, false)]))
	_sounds["eat"] = _wav(_concat([_crunch(0.1, 0.3), _silence(0.08), _crunch(0.1, 0.3)]))
	_sounds["died"] = _wav(_concat([_tone(0.25, 440.0, 440.0, 8.0, 0.25, true), _tone(0.25, 330.0, 330.0, 8.0, 0.25, true), _tone(0.6, 220.0, 110.0, 5.0, 0.25, true)]))
	_sounds["groan"] = _wav(_tone(0.9, 70.0, 55.0, 3.0, 0.35, true, 5.0, 0.04))
	# Ambience loops.
	_sounds["amb_day"] = _wav(_birds(6.0), true)
	_sounds["amb_night"] = _wav(_wind(5.0), true)


## Turns float samples into a Godot audio stream (16-bit mono).
func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


func _silence(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	return out


## Filtered noise that fades out. `alpha` is the low-pass amount
## (small = muffled, 1 = raw hiss); `decay` how fast it fades.
func _noise(dur: float, decay: float, alpha: float, gain: float) -> PackedFloat32Array:
	var out := _silence(dur)
	var y := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var x := _rng.randf_range(-1.0, 1.0)
		y += alpha * (x - y)
		out[i] = y * exp(-decay * t) * gain
	return out


## A tone sliding from f0 to f1 Hz, fading out. Sine or sawtooth.
## Optional vibrato (rate Hz, depth as a fraction of pitch).
func _tone(dur: float, f0: float, f1: float, decay: float, gain: float, saw: bool,
		vib_rate := 0.0, vib_depth := 0.0) -> PackedFloat32Array:
	var out := _silence(dur)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / dur)
		if vib_rate > 0.0:
			f *= 1.0 + sin(TAU * vib_rate * t) * vib_depth
		phase += f / RATE
		var v := (2.0 * fmod(phase, 1.0) - 1.0) if saw else sin(TAU * phase)
		out[i] = v * exp(-decay * t) * gain
	return out


## Noise chopped into random on/off grains: snow, eating.
func _crunch(dur: float, gain: float) -> PackedFloat32Array:
	var out := _silence(dur)
	var gate := 1.0
	for i in out.size():
		var t := float(i) / RATE
		if i % 60 == 0:
			gate = 1.0 if _rng.randf() > 0.55 else 0.15
		out[i] = _rng.randf_range(-1.0, 1.0) * gate * exp(-25.0 * t) * gain
	return out


func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p in parts:
		for i in p.size():
			out[i] += p[i]
	return out


func _concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


## Daytime: a handful of two-note chirps scattered through the loop.
func _birds(dur: float) -> PackedFloat32Array:
	var out := _silence(dur)
	for c in 7:
		var start := int(_rng.randf_range(0.2, dur - 0.5) * RATE)
		var f := _rng.randf_range(2000.0, 3200.0)
		var chirp := _concat([
			_tone(0.07, f, f * 1.25, 18.0, 0.12, false),
			_silence(0.05),
			_tone(0.09, f * 1.15, f * 0.9, 18.0, 0.12, false)])
		for i in chirp.size():
			if start + i < out.size():
				out[start + i] += chirp[i]
	return out


## Night: deep, slowly breathing wind. The modulation completes whole
## cycles over the loop so the seam doesn't click.
func _wind(dur: float) -> PackedFloat32Array:
	var out := _silence(dur)
	var y := 0.0
	var y2 := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var x := _rng.randf_range(-1.0, 1.0)
		y += 0.03 * (x - y)     # very muffled
		y2 += 0.3 * (y - y2)    # and again, for depth
		var breath := 0.55 + 0.45 * sin(TAU * t / dur * 2.0)
		out[i] = y2 * breath * 2.5
	# Short fades at both ends hide the loop seam.
	var fade := int(0.05 * RATE)
	for i in fade:
		var k := float(i) / fade
		out[i] *= k
		out[out.size() - 1 - i] *= k
	return out
