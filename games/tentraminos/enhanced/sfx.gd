extends Node
## Tentraminos Enhanced: small synthesized sound effects.
## The 2013 LD27 entry had no audio. These are generated at startup as 16-bit PCM
## AudioStreamWAVs, so no audio assets are vendored (same approach as SvA Enhanced).

const RATE := 22050
const VOICES := 8
const VOLUME_DB := -10.0

var streams := {}
var last_played := ""
var played_count := 0
var muted := false
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2013
	streams["move"] = _wav(_tone(1400.0, 1250.0, 0.025, "tri", 0.25))
	streams["rotate"] = _wav(_tone(520.0, 880.0, 0.06, "square", 0.22))
	streams["land"] = _wav(_tone(180.0, 90.0, 0.07, "tri", 0.4, 0.25))
	streams["drop"] = _wav(_tone(900.0, 220.0, 0.16, "sine", 0.35, 0.2))
	streams["tick"] = _wav(_tone(1760.0, 1760.0, 0.05, "sine", 0.35))
	streams["tock"] = _wav(_tone(880.0, 880.0, 0.09, "square", 0.25))
	streams["clear1"] = _wav(_seq([[659.0, 0.06], [988.0, 0.12]], "tri", 0.45))
	streams["clear2"] = _wav(_seq([[659.0, 0.05], [831.0, 0.05], [988.0, 0.05], [1319.0, 0.16]], "tri", 0.45))
	streams["clear3"] = _wav(_seq([[523.0, 0.05], [659.0, 0.05], [784.0, 0.05], [1046.0, 0.05],
			[1319.0, 0.05], [1568.0, 0.22]], "tri", 0.5))
	streams["pause"] = _wav(_tone(660.0, 440.0, 0.08, "sine", 0.35))
	streams["start"] = _wav(_seq([[392.0, 0.07], [523.0, 0.07], [784.0, 0.14]], "square", 0.3))
	streams["best"] = _wav(_seq([[523.0, 0.1], [659.0, 0.1], [784.0, 0.1], [1046.0, 0.35]], "tri", 0.5))
	streams["lose"] = _wav(_seq([[392.0, 0.16], [330.0, 0.16], [262.0, 0.16], [196.0, 0.45]], "square", 0.32))
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = VOLUME_DB
		add_child(p)
		_players.append(p)


func play(name: String, pitch := 1.0) -> void:
	if not streams.has(name):
		return
	last_played = name
	played_count += 1
	if muted or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = streams[name]
	p.pitch_scale = pitch
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
