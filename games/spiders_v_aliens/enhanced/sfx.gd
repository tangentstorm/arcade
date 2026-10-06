extends Node
## Spiders v. Aliens Enhanced: tiny synthesized sound effects.
## The 2011 game shipped music only (SFX were still TODO in escapegame.org). These are generated
## at startup as 16-bit PCM AudioStreamWAVs, so no new audio assets are vendored.

const RATE := 22050
const VOICES := 6
const VOLUME_DB := -9.0

var streams := {}
var last_played := ""
var played_count := 0
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2011
	streams["grab"] = _wav(_tone(520.0, 760.0, 0.05, "square", 0.35))
	streams["drop"] = _wav(_tone(420.0, 260.0, 0.06, "square", 0.25))
	streams["warp"] = _wav(_mix([_tone(180.0, 1400.0, 0.28, "sine", 0.5), _tone(90.0, 700.0, 0.28, "tri", 0.3)]))
	streams["click"] = _wav(_tone(1200.0, 900.0, 0.03, "square", 0.3, 0.3))
	streams["unlock"] = _wav(_seq([[660.0, 0.07], [880.0, 0.07], [1320.0, 0.14]], "tri", 0.45))
	streams["zap"] = _wav(_tone(1700.0, 220.0, 0.22, "saw", 0.4, 0.15))
	streams["hurt"] = _wav(_tone(160.0, 60.0, 0.25, "square", 0.5, 0.45))
	streams["heal"] = _wav(_seq([[784.0, 0.06], [1046.0, 0.06], [1568.0, 0.12]], "sine", 0.45))
	streams["splat"] = _wav(_tone(300.0, 80.0, 0.18, "tri", 0.45, 0.6))
	streams["win"] = _wav(_seq([[523.0, 0.12], [659.0, 0.12], [784.0, 0.12], [1046.0, 0.4]], "tri", 0.5))
	streams["lose"] = _wav(_seq([[392.0, 0.18], [330.0, 0.18], [262.0, 0.18], [196.0, 0.5]], "square", 0.35))
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = VOLUME_DB
		add_child(p)
		_players.append(p)


func play(name: String) -> void:
	if not streams.has(name):
		return
	last_played = name
	played_count += 1
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = streams[name]
	p.play()


func stop_all() -> void:
	for p in _players:
		p.stop()
		p.stream = null


func _tone(f0: float, f1: float, dur: float, wave := "square", vol := 0.5, noise := 0.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / dur
		phase += lerpf(f0, f1, u) / RATE
		var ph := fmod(phase, 1.0)
		var s := 0.0
		match wave:
			"square":
				s = 1.0 if ph < 0.5 else -1.0
			"saw":
				s = ph * 2.0 - 1.0
			"tri":
				s = 1.0 - 4.0 * absf(ph - 0.5)
			_:
				s = sin(ph * TAU)
		if noise > 0.0:
			s = lerpf(s, _rng.randf_range(-1.0, 1.0), noise)
		var env := minf(1.0, t / 0.004) * pow(1.0 - u, 2.0)
		out[i] = s * env * vol
	return out


func _seq(notes: Array, wave: String, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for nd in notes:
		out.append_array(_tone(nd[0], nd[0], nd[1], wave, vol))
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


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
