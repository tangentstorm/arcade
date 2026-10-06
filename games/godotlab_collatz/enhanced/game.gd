extends Node2D
## GodotLab Collatz (Enhanced). Presentation makeover of the Direct Collatz bit-register stepper.
## The game is Direct `game.tscn` (shared `collatz.gd` / `bit.gd` / `register.gd`), instanced
## as-is: its bits, click toggling, keys (Space/Enter/→ step, R run, C clear) and the stepper
## all stay Direct. Enhanced hides Direct's plain HUD labels and owns the 1280×720 letterbox
## chrome, bit glow / flip / shift / carry-ripple juice, the step breakdown panel, the trajectory
## chart, the HUD and the title card. Every visual is derived by *observing* the Direct node
## (`value()`, `history`, `steps`, `peak`, `running`, bit frames, Info text) — no rules here.
## Esc → PauseOverlay (global autoload). No Alchementrix IP.

const DIRECT := preload("res://games/godotlab_collatz/direct/game.tscn")
const CollatzScript := preload("res://games/godotlab_collatz/direct/collatz.gd")

const STAGE := Vector2(1280, 720)
## Where the Direct register's top edge lands on the stage (Direct puts it at y 280).
const REGISTER_TOP := 132.0
const FIELD_POS := Vector2(40, 90)
const FIELD := Vector2(1200, 140)
const STEP_POS := Vector2(40, 244)
const STEP_SIZE := Vector2(560, 262)
const CHART_POS := Vector2(612, 244)
const CHART_SIZE := Vector2(628, 262)

const BG_TOP := Color(0.04, 0.04, 0.09)
const BG_BOT := Color(0.09, 0.04, 0.10)
const PANEL := Color(0.09, 0.08, 0.16, 0.94)
const FRAME := Color(1.0, 0.45, 0.45)
const INK := Color(0.95, 0.94, 1.0)
const MUTED := Color(0.62, 0.60, 0.78)
const GOLD := Color(1.0, 0.84, 0.30)
const EVEN_C := Color(0.40, 0.80, 1.0)   ## shift-right steps
const ODD_C := Color(1.0, 0.52, 0.38)    ## 3n+1 steps
const GOOD := Color(0.45, 0.95, 0.60)

## Start values for the P key / Preset button. 703 overflows 16 bits on purpose.
const PRESETS := [27, 7, 97, 255, 703]
const ANIM_TIME := 0.22

enum { TITLE, PLAY }

var state := TITLE
var demo: Node2D = null

## View-only presentation state, all derived from the Direct node.
var last_value := -1
var last_steps := 0
var last_kind := ""      ## "", "shift" or "3n+1" (classified from Direct's history deltas)
var last_prev := 0
var last_next := 0
var flips := 0           ## bit flips seen (juice counter, also used by the test)
var shifts := 0          ## shift-right steps observed in this run
var triples := 0         ## 3n+1 steps observed in this run
var celebrations := 0
var overflows := 0
var hover_bit := -1
var preset_i := -1
var _frames_cache: Array[int] = []
var _bit_flash: Array[float] = []
var _anim := 1.0         ## 0..1 progress of the latest step animation
var _shake := 0.0
var _flash := 0.0
var _flash_c := GOLD
var _time := 0.0
var _last_info := ""
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _banner := ""
var _banner_t := 0.0
var _mouse_override = null  ## tests can set a stage point here

var _host: Node2D
var _fx: Node2D
var _ui: CanvasLayer
var _hud: Control
var _cards := {}
var _n_label: Label
var _bin_label: Label
var _stats_label: Label
var _trail_label: Label
var _run_btn: Button
var _font: Font
var _panel_style := StyleBoxFlat.new()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_panel_style.bg_color = PANEL
	_panel_style.border_color = Color(FRAME, 0.5)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(14)
	_build_stage()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_set_state(TITLE)


func _layout() -> void:
	var size := get_viewport_rect().size
	var s := minf(size.x / STAGE.x, size.y / STAGE.y)
	scale = Vector2(s, s)
	position = (size - STAGE * s) * 0.5
	if _ui:
		_ui.transform = Transform2D(0.0, scale, 0.0, position)


func _set_state(s: int) -> void:
	state = s
	_cards["title"].visible = s == TITLE
	_hud.visible = s == PLAY
	_host.visible = s == PLAY
	if s == PLAY and demo == null:
		_load_demo()


func _load_demo() -> void:
	demo = DIRECT.instantiate() as Node2D
	_host.add_child(demo)
	# Hide Direct's plain-label HUD; Enhanced draws its own over the same state.
	demo.get_node("Hud").visible = false
	# Slide the Direct scene so its register sits in the Enhanced field (presentation only).
	var reg: Node2D = demo.register
	demo.position = Vector2.ZERO
	demo.position.y = REGISTER_TOP - (demo.get_node("World") as Node2D).scale.y * reg.position.y
	reg.self_modulate = Color(0.78, 0.55, 0.62)  # mute Direct's Color.RED bar a little
	_resync()
	_banner = "CLICK BITS  ·  P = PRESET"
	_banner_t = 2.4


## Snapshot the Direct state without firing juice (load, clear, preset).
func _resync() -> void:
	last_value = demo.value()
	last_steps = demo.steps
	_frames_cache.clear()
	_bit_flash.clear()
	for b in demo.bits:
		_frames_cache.append(b.frame)
		_bit_flash.append(0.0)
	_last_info = demo.info.text


# --- reading the Direct node ------------------------------------------------------

func bit_count() -> int:
	return demo.bits.size() if demo else 0


## Stage-space centre of Direct bit `i` (bit 0 = rightmost / least significant).
func bit_pos(i: int) -> Vector2:
	return to_local(demo.bits[i].global_position) if demo else Vector2.ZERO


## Stage-space size of one register cell, read from the Direct sprites.
func cell() -> float:
	if demo == null or demo.bits.size() < 2:
		return 64.0
	return absf(bit_pos(0).x - bit_pos(1).x)


func binary(n: int, w := -1) -> String:
	if w < 0:
		w = bit_count()
	var s := ""
	for i in range(w - 1, -1, -1):
		s += "1" if (n >> i) & 1 else "0"
	return s


## Bit index under a stage-space point, or -1.
func pick(stage_pt: Vector2) -> int:
	if demo == null:
		return -1
	var r := cell() * 0.5
	for i in bit_count():
		if stage_pt.distance_to(bit_pos(i)) <= r:
			return i
	return -1


# --- input / actions (all forwarded to Direct) ------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Direct's own _unhandled_input (a child) sees Space/Enter/→/R/C first in PLAY.
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var e := event as InputEventKey
	if state == TITLE:
		if e.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
			_set_state(PLAY)
			get_viewport().set_input_as_handled()
		return
	if e.keycode == KEY_P:
		next_preset()
		get_viewport().set_input_as_handled()


func next_preset() -> void:
	if demo == null:
		return
	preset_i = (preset_i + 1) % PRESETS.size()
	var n: int = PRESETS[preset_i]
	demo.running = false
	demo.set_value(n)
	demo._restart_from_bits()
	shifts = 0
	triples = 0
	_juice_flips()
	_resync()
	_banner = "PRESET  n = %d" % n
	_banner_t = 1.4


func ui_step() -> void:
	if demo == null:
		return
	var before: String = demo.info.text
	# A first overflow changes Direct's Info text (picked up by _observe); repeats don't.
	if not demo.step() and demo.value() > 1 and demo.info.text == before:
		_overflow_juice()


func ui_run() -> void:
	if demo:
		demo.toggle_run()


func ui_clear() -> void:
	if demo:
		demo.clear()


# --- tick: observe Direct, fire juice ---------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 2.5)
	_shake = maxf(0.0, _shake - delta * 3.0)
	_banner_t = maxf(0.0, _banner_t - delta)
	_anim = minf(1.0, _anim + delta / ANIM_TIME)
	for i in _bit_flash.size():
		_bit_flash[i] = maxf(0.0, _bit_flash[i] - delta * 2.2)
	if state == PLAY and demo != null:
		_observe()
		var mp: Vector2 = _mouse_override if _mouse_override != null else get_local_mouse_position()
		hover_bit = pick(mp)
		_refresh_hud()
	_host.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 6.0 * _shake
	_animate_fx(delta)
	queue_redraw()
	_fx.queue_redraw()


func _observe() -> void:
	var n: int = demo.value()
	var st: int = demo.steps
	if st > last_steps and demo.history.size() >= 2:
		var prev: int = demo.history[demo.history.size() - 2]
		var nxt: int = demo.history[demo.history.size() - 1]
		# Classify from the observed delta (Direct decided; we only label it).
		last_kind = "shift" if nxt * 2 == prev else "3n+1"
		last_prev = prev
		last_next = nxt
		if last_kind == "shift":
			shifts += 1
		else:
			triples += 1
		_anim = 0.0
		_juice_flips()
		var c := EVEN_C if last_kind == "shift" else ODD_C
		_floater(("÷2" if last_kind == "shift" else "×3+1"),
				Vector2(FIELD_POS.x + FIELD.x - 70, FIELD_POS.y + 30 + 30 * (st % 2)), c)
		if nxt == 1:
			_celebrate()
	elif st < last_steps or (st == 0 and n != last_value):
		# Clicks / clear restart Direct's run.
		if st == 0:
			shifts = 0
			triples = 0
			last_kind = ""
		_juice_flips()
	var info: String = demo.info.text
	if info != _last_info and info.contains("overflow"):
		_overflow_juice()
	_last_info = info
	last_value = n
	last_steps = st


func _juice_flips() -> void:
	for i in mini(bit_count(), _frames_cache.size()):
		var f: int = demo.bits[i].frame
		if f != _frames_cache[i]:
			_frames_cache[i] = f
			_bit_flash[i] = 1.0
			flips += 1
			var c := GOLD if f == 1 else Color(0.5, 0.5, 0.7)
			_burst(bit_pos(i), c, 5 if f == 1 else 3, 120.0)


func _celebrate() -> void:
	celebrations += 1
	_flash = 0.8
	_flash_c = GOOD
	for i in bit_count():
		_burst(bit_pos(i), Color.from_hsv(float(i) / bit_count(), 0.6, 1.0), 6, 220.0)
	_banner = "REACHED 1 · %d STEPS · PEAK %d" % [demo.steps, demo.peak]
	_banner_t = 2.6


func _overflow_juice() -> void:
	overflows += 1
	_shake = 1.0
	_flash = 0.7
	_flash_c = Color(1.0, 0.25, 0.25)
	_banner = "OVERFLOW  ·  NEEDS > %d BITS" % bit_count()
	_banner_t = 2.2
	_burst(bit_pos(bit_count() - 1) + Vector2(-cell() * 0.6, 0), Color(1, 0.3, 0.3), 14, 200.0)


func _refresh_hud() -> void:
	var n: int = demo.value()
	_n_label.text = "n = %d" % n if n > 0 else "n = —"
	_bin_label.text = "0x%04X   %s" % [n, "even" if n % 2 == 0 else "odd"] if n > 0 else "click the bits"
	_stats_label.text = "steps  %d\npeak  %d\n÷2  %d    ×3+1  %d" % [demo.steps, demo.peak, shifts, triples]
	var h: Array = demo.history
	var shown := h.slice(maxi(0, h.size() - 14))
	_trail_label.text = ("… " if h.size() > 14 else "") + " → ".join(shown.map(func(v): return str(v)))
	if h.is_empty():
		_trail_label.text = "Trail appears here once you enter n."
	_run_btn.text = "Stop" if demo.running else "Run"


# --- draw -------------------------------------------------------------------------

func _draw() -> void:
	for i in 24:
		var t := float(i) / 24.0
		draw_rect(Rect2(0, STAGE.y * t, STAGE.x, STAGE.y / 24.0 + 1.0), BG_TOP.lerp(BG_BOT, t))
	# drifting binary dust
	for i in 36:
		var x := fmod(i * 131.7 + _time * (5.0 + i % 4), STAGE.x)
		var y := fmod(i * 61.3 + _time * (3.0 + i % 3) * 2.0, STAGE.y)
		_text("1" if i % 3 else "0", Vector2(x, y), 12, Color(1, 0.6, 0.7, 0.05 + 0.03 * (i % 3)))
	if state != PLAY or demo == null:
		return
	_frame(Rect2(FIELD_POS, FIELD))
	# bit index (top) + place value (bottom) per cell, read from the Direct sprites
	var c := cell()
	for i in bit_count():
		var p := bit_pos(i)
		var on: bool = demo.bits[i].frame == 1
		var col := GOLD if on else MUTED
		_text_c(str(i), Vector2(p.x, p.y - c * 0.5 - 6), 11, Color(col, 0.8))
		_text_c(str(1 << i), Vector2(p.x, p.y + c * 0.5 + 16), 10 if i < 10 else 9, Color(col, 0.55 if not on else 0.9))
	_draw_step_panel()
	_draw_chart()


func _frame(r: Rect2) -> void:
	draw_rect(r, Color(0.06, 0.05, 0.11, 0.92))
	draw_rect(r.grow(-3), Color(FRAME, 0.45), false, 2.0)


func _draw_step_panel() -> void:
	var r := Rect2(STEP_POS, STEP_SIZE)
	_frame(r)
	_text("LAST STEP", r.position + Vector2(16, 24), 12, MUTED)
	var w := bit_count()
	var cw := 22.0
	var x0 := r.position.x + r.size.x - 24 - w * cw
	var y := r.position.y + 64
	if last_kind == "":
		_text("Step (Space) to see the operation on the bits.", r.position + Vector2(16, 70), 15, INK)
		_text("even n  →  n >> 1        (shift right)", r.position + Vector2(16, 120), 15, EVEN_C)
		_text("odd n   →  3n + 1 = (n << 1) + n + 1", r.position + Vector2(16, 150), 15, ODD_C)
		return
	var a := _anim
	if last_kind == "shift":
		_text("even  →  n >> 1", r.position + Vector2(110, 24), 14, EVEN_C)
		_bits_row("n", last_prev, x0, y, cw, INK, 1.0)
		# the old row slides one cell right while the new one fades in
		_bits_row("", last_prev, x0 + cw * a, y + 44, cw, Color(EVEN_C, 0.5 * (1.0 - a)), 1.0, 99, true)
		_bits_row(">>1", last_next, x0, y + 44, cw, EVEN_C, a)
		draw_line(Vector2(x0, y + 70), Vector2(x0 + w * cw, y + 70), Color(EVEN_C, 0.4), 1.0)
		_text("%d / 2 = %d" % [last_prev, last_next], Vector2(r.position.x + 16, y + 112), 18, INK)
	else:
		_text("odd  →  (n << 1) + n + 1", r.position + Vector2(110, 24), 14, ODD_C)
		var dbl := last_prev << 1
		_bits_row("n<<1", dbl, x0, y, cw, Color(INK, 0.9), 1.0)
		_bits_row("+ n", last_prev, x0, y + 30, cw, Color(INK, 0.9), 1.0)
		_bits_row("+ 1", 1, x0, y + 60, cw, Color(INK, 0.9), 1.0)
		draw_line(Vector2(x0, y + 72), Vector2(x0 + w * cw, y + 72), Color(ODD_C, 0.6), 1.5)
		# carries of the visual sum, revealed LSB → MSB as a ripple
		var carry := 1  # the +1 enters as a carry into bit 0
		var ripple := int(a * (w + 1))
		for i in w:
			var s := ((dbl >> i) & 1) + ((last_prev >> i) & 1) + carry
			carry = s >> 1
			if carry and i < ripple and i + 1 < w:
				draw_circle(Vector2(x0 + (w - 2 - i) * cw + cw * 0.5, y - 20), 3.0, ODD_C)
		_bits_row("=", last_next, x0, y + 100, cw, ODD_C, a, ripple)
		_text("3·%d + 1 = %d" % [last_prev, last_next], Vector2(r.position.x + 16, y + 150), 18, INK)
		_text("dots = carries", Vector2(r.position.x + 16, y - 16), 11, Color(ODD_C, 0.8))


## One binary row, MSB on the left; `reveal` limits how many low bits are drawn (ripple).
func _bits_row(tag: String, n: int, x0: float, y: float, cw: float, col: Color, alpha: float,
		reveal := 99, ones_only := false) -> void:
	var w := bit_count()
	if tag != "":
		_text(tag, Vector2(x0 - 56, y), 14, Color(MUTED, alpha))
	for j in w:
		var i := w - 1 - j
		if i >= reveal:
			continue
		var on := (n >> i) & 1
		if ones_only and not on:
			continue
		var c := Color(col, col.a * alpha * (1.0 if on else 0.35))
		_text_c("1" if on else "0", Vector2(x0 + j * cw + cw * 0.5, y), 16, c)


func _draw_chart() -> void:
	var r := Rect2(CHART_POS, CHART_SIZE)
	_frame(r)
	_text("TRAJECTORY  (log₂ n)", r.position + Vector2(16, 24), 12, MUTED)
	var h: Array = demo.history
	var plot := Rect2(r.position + Vector2(44, 40), r.size - Vector2(64, 64))
	var bits := float(bit_count())
	for b in range(0, bit_count() + 1, 4):
		var gy := plot.end.y - plot.size.y * b / bits
		draw_line(Vector2(plot.position.x, gy), Vector2(plot.end.x, gy), Color(1, 1, 1, 0.06), 1.0)
		_text("2^%d" % b, Vector2(r.position.x + 10, gy + 4), 10, Color(MUTED, 0.7))
	if h.size() < 1:
		_text("Enter n to plot its path down to 1.", plot.position + Vector2(120, plot.size.y * 0.5), 14, MUTED)
		return
	var nmax := maxi(h.size() - 1, 1)
	var pts := PackedVector2Array()
	var peak_i := 0
	for i in h.size():
		var v: int = h[i]
		if v > h[peak_i]:
			peak_i = i
		var px := plot.position.x + plot.size.x * float(i) / nmax
		var py := plot.end.y - plot.size.y * (log(maxf(1.0, v)) / log(2.0)) / bits
		pts.append(Vector2(px, py))
	if pts.size() >= 2:
		for i in pts.size() - 1:
			var up: bool = h[i + 1] > h[i]
			draw_line(pts[i], pts[i + 1], Color(ODD_C if up else EVEN_C, 0.85), 2.0, true)
	if pts.size() <= 60:
		for i in pts.size():
			draw_circle(pts[i], 2.0, Color(INK, 0.5))
	draw_circle(pts[peak_i], 5.0, GOLD)
	_text("peak %d" % h[peak_i], pts[peak_i] + Vector2(-20, -10), 11, GOLD)
	var cur := pts[pts.size() - 1]
	var pulse := 0.5 + 0.5 * sin(_time * 8.0)
	draw_arc(cur, 6.0 + 3.0 * pulse, 0, TAU, 20, GOOD if h[-1] == 1 else INK, 2.0)
	_text("%d step%s" % [h.size() - 1, "" if h.size() == 2 else "s"], Vector2(plot.end.x - 70, r.end.y - 10), 11, MUTED)


## Overlay above the Direct scene (child node drawn after the host).
func _draw_fx() -> void:
	if state == PLAY and demo != null:
		var c := cell()
		for i in bit_count():
			var p := bit_pos(i)
			var on: bool = demo.bits[i].frame == 1
			if on:
				var g := 0.5 + 0.5 * sin(_time * 3.0 + i * 0.5)
				_fx.draw_circle(p, c * 0.36, Color(GOLD, 0.10 + 0.06 * g))
			if _bit_flash[i] > 0.0:
				var f: float = _bit_flash[i]
				_fx.draw_arc(p, c * 0.32 + (1.0 - f) * 14.0, 0, TAU, 28, Color(GOLD if on else INK, f), 3.0)
		# step animation on the register itself
		if _anim < 1.0 and last_kind != "":
			if last_kind == "shift":
				for i in bit_count():
					if (last_prev >> i) & 1 and i > 0:
						var from := bit_pos(i)
						var to := bit_pos(i - 1)
						_fx.draw_circle(from.lerp(to, _anim), c * 0.18, Color(EVEN_C, 0.7 * (1.0 - _anim)))
				if last_prev & 1 == 0:
					var p0 := bit_pos(0) + Vector2(c * _anim, 0)
					_fx.draw_circle(p0, c * 0.12, Color(EVEN_C, 0.4 * (1.0 - _anim)))
			else:
				var k := int(_anim * bit_count())
				for i in mini(k + 1, bit_count()):
					var p := bit_pos(i)
					var fall := clampf(1.0 - (k - i) * 0.25, 0.0, 1.0)
					_fx.draw_rect(Rect2(p - Vector2(c, c) * 0.5, Vector2(c, c)), Color(ODD_C, 0.25 * fall))
		if hover_bit >= 0:
			var p := bit_pos(hover_bit)
			_fx.draw_arc(p, c * 0.44, 0, TAU, 32, Color.WHITE, 2.0)
			var tip := "bit %d  ·  2^%d = %d" % [hover_bit, hover_bit, 1 << hover_bit]
			var tp := Vector2(clampf(p.x - 80, FIELD_POS.x + 8, FIELD_POS.x + FIELD.x - 170), FIELD_POS.y + 18)
			_fx.draw_rect(Rect2(tp - Vector2(6, 15), Vector2(172, 22)), Color(0.05, 0.04, 0.10, 0.85))
			_fx.draw_string(_font, tp, tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
		if demo.running:
			var a := 0.5 + 0.5 * sin(_time * 10.0)
			_fx.draw_circle(FIELD_POS + Vector2(22, 22), 6.0, Color(GOOD, 0.4 + 0.6 * a))
			_fx.draw_string(_font, FIELD_POS + Vector2(34, 27), "RUNNING", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOOD)
	for p in _particles:
		var col: Color = p.color
		col.a *= clampf(p.life / p.max, 0.0, 1.0)
		_fx.draw_circle(p.pos, p.size, col)
	for f in _floaters:
		var col: Color = f.color
		col.a *= clampf(f.life / f.max, 0.0, 1.0)
		_fx.draw_string(_font, f.pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
	if _flash > 0.0:
		_fx.draw_rect(Rect2(FIELD_POS, FIELD), Color(_flash_c, _flash * 0.18))
	if _banner_t > 0.0 and _banner != "":
		var a := clampf(_banner_t, 0.0, 1.0)
		var r2 := Rect2(CHART_POS.x + 196, CHART_POS.y + 8, 420, 28)  # chart header, clear of the register labels
		_fx.draw_rect(r2, Color(0.04, 0.03, 0.08, 0.85 * a))
		_fx.draw_string(_font, r2.position + Vector2(0, 21), _banner, HORIZONTAL_ALIGNMENT_CENTER,
				r2.size.x, 15, Color(GOLD, a))


func _text(t: String, pos: Vector2, size: int, color: Color) -> void:
	draw_string(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_c(t: String, pos: Vector2, size: int, color: Color) -> void:
	draw_string(_font, pos - Vector2(40, 0), t, HORIZONTAL_ALIGNMENT_CENTER, 80, size, color)


# --- FX helpers -------------------------------------------------------------------

func _burst(at: Vector2, color: Color, n: int, speed: float) -> void:
	for i in n:
		var ang := randf() * TAU
		var sp := randf_range(0.3, 1.0) * speed
		_particles.append({
			"pos": at, "vel": Vector2(cos(ang), sin(ang)) * sp,
			"life": randf_range(0.3, 0.7), "max": 0.7,
			"color": color, "size": randf_range(1.5, 3.5),
		})


func _floater(text: String, at: Vector2, color: Color) -> void:
	_floaters.append({"pos": at, "life": 0.8, "max": 0.8, "text": text, "color": color})


func _animate_fx(delta: float) -> void:
	var i := 0
	while i < _particles.size():
		var p: Dictionary = _particles[i]
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.93
		if p.life <= 0.0:
			_particles.remove_at(i)
		else:
			i += 1
	i = 0
	while i < _floaters.size():
		var f: Dictionary = _floaters[i]
		f.life -= delta
		f.pos.y -= 30.0 * delta
		if f.life <= 0.0:
			_floaters.remove_at(i)
		else:
			i += 1


# --- build ------------------------------------------------------------------------

func _build_stage() -> void:
	_host = Node2D.new()
	_host.name = "DirectHost"
	_host.visible = false
	add_child(_host)
	_fx = Node2D.new()
	_fx.name = "Fx"
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "UI"
	add_child(_ui)

	_hud = Control.new()
	_hud.name = "Hud"
	_hud.size = STAGE
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_hud)

	var top := _panel(Rect2(40, 14, 1200, 64))
	_hud.add_child(top)
	top.add_child(_label("COLLATZ", 26, GOLD, Vector2(18, 14)))
	top.add_child(_label("GodotLab · Enhanced", 14, FRAME, Vector2(150, 26)))
	top.add_child(_label("even n → n >> 1     odd n → 3n + 1", 16, INK, Vector2(380, 22)))
	var back := _btn("Back to Arcade", Vector2(1056, 14), Vector2(128, 36))
	back.pressed.connect(GameRegistry.return_to_arcade)
	top.add_child(back)

	var num := _panel(Rect2(40, 518, 330, 186))
	_hud.add_child(num)
	num.add_child(_label("REGISTER", 11, MUTED, Vector2(14, 10)))
	_n_label = _label("n = —", 30, GOLD, Vector2(14, 28))
	num.add_child(_n_label)
	_bin_label = _label("", 14, INK, Vector2(14, 74))
	num.add_child(_bin_label)
	_stats_label = _label("", 14, INK, Vector2(14, 100))
	num.add_child(_stats_label)

	var tr := _panel(Rect2(382, 518, 520, 186))
	_hud.add_child(tr)
	tr.add_child(_label("TRAIL", 11, MUTED, Vector2(14, 10)))
	_trail_label = _label("", 14, Color(0.85, 0.85, 0.95), Vector2(14, 30))
	_trail_label.size = Vector2(492, 96)
	_trail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tr.add_child(_trail_label)
	var row := [["Step", ui_step], ["Run", ui_run], ["Clear", ui_clear], ["Preset", next_preset]]
	for j in row.size():
		var b := _btn(row[j][0], Vector2(14 + j * 124, 136), Vector2(112, 36))
		b.pressed.connect(row[j][1])
		tr.add_child(b)
		if row[j][0] == "Run":
			_run_btn = b

	var keys := _panel(Rect2(914, 518, 326, 186))
	_hud.add_child(keys)
	keys.add_child(_label("CONTROLS", 11, MUTED, Vector2(14, 10)))
	keys.add_child(_label("Click bits  set n\nSpace / Enter / →  step\nR  run to 1     C  clear\nP  preset (27, 7, 97, 255, 703)\nEsc  pause / arcade",
			13, INK, Vector2(14, 30)))
	keys.add_child(_label("Same Direct collatz.gd steps the register.", 11, MUTED, Vector2(14, 160)))

	# Title card
	var card := _panel(Rect2(STAGE.x * 0.5 - 320, STAGE.y * 0.5 - 175, 640, 350))
	card.name = "TitleCard"
	_ui.add_child(card)
	_cards["title"] = card
	card.add_child(_label("COLLATZ", 36, GOLD, Vector2(36, 30)))
	card.add_child(_label("GodotLab · Enhanced edition", 16, FRAME, Vector2(36, 80)))
	card.add_child(_label(
		"Click bits on the 16-bit register to enter n, then step it:\neven n shifts right, odd n becomes 3n + 1.\nWatch the bits slide, the carries ripple and the path fall to 1.",
		14, INK, Vector2(36, 118)))
	var start := _btn("Start", Vector2(36, 224), Vector2(120, 40))
	start.pressed.connect(func(): _set_state(PLAY))
	card.add_child(start)
	card.add_child(_label("Enter / Space  to begin", 14, MUTED, Vector2(180, 234)))
	var title_back := _btn("Back to Arcade", Vector2(36, 286), Vector2(160, 34))
	title_back.pressed.connect(GameRegistry.return_to_arcade)
	card.add_child(title_back)
	card.add_child(_label("0 1 1 0 1 1   →   27", 18, Color(GOLD, 0.7), Vector2(380, 292)))


func _panel(r: Rect2) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.add_theme_stylebox_override("panel", _panel_style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(text: String, size: int, color: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _btn(text: String, pos: Vector2, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	for stn in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		var base := Color(0.32, 0.12, 0.20)
		s.bg_color = base.lightened(0.15) if stn == "hover" else base.darkened(0.15) if stn == "pressed" else base
		s.border_color = FRAME
		s.set_border_width_all(2)
		s.set_corner_radius_all(10)
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 4
		s.content_margin_bottom = 6
		b.add_theme_stylebox_override(stn, s)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	return b
