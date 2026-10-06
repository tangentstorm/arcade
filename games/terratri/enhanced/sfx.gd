extends Node
## Terratri Enhanced: small synthesized sound effects. The original web client
## had no audio; these are 16-bit PCM AudioStreamWAVs built at startup, so no
## audio assets are vendored (same approach as Tentraminos / SvA Enhanced).

const RATE := 22050
const VOICES := 6
const VOLUME_DB := -11.0

var streams := {}
var last_played := ""
var played_count := 0
var muted := false
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2011
	streams["move"] = _wav(_tone(520.0, 780.0, 0.07, "tri", 0.35))
	streams["claim"] = _wav(_tone(880.0, 1320.0, 0.06, "sine", 0.30))
	streams["capture"] = _wav(_seq([[660.0, 0.05], [990.0, 0.09]], "square", 0.22))
	streams["fort"] = _wav(_tone(160.0, 70.0, 0.16, "tri", 0.5, 0.3)
		+ _seq([[784.0, 0.06], [1175.0, 0.14]], "tri", 0.35))
	streams["bank"] = _wav(_seq([[1319.0, 0.05], [1760.0, 0.12]], "sine", 0.35))
	streams["turn"] = _wav(_tone(330.0, 495.0, 0.12, "sine", 0.28))
	streams["undo"] = _wav(_tone(780.0, 420.0, 0.08, "tri", 0.3))
	streams["nope"] = _wav(_tone(150.0, 120.0, 0.09, "square", 0.18))
	streams["start"] = _wav(_seq([[392.0, 0.07], [523.0, 0.07], [784.0, 0.14]], "tri", 0.35))
	streams["win"] = _wav(_seq([[523.0, 0.1], [659.0, 0.1], [784.0, 0.1], [1046.0, 0.12],
		[784.0, 0.08], [1046.0, 0.4]], "tri", 0.45))
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
