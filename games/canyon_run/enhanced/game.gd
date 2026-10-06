extends Node2D
## Canyon Run (Enhanced). Presentation shell over Direct canyon_logic.gd.
## Field visuals use the same Claude Design paper-cut topo renderer as Direct
## (canyon_topo.gd). This file owns the 1280×720 letterbox chrome: HUD panels,
## title / crash cards, kill / crash juice, Back to Arcade. Esc → PauseOverlay.
## No Alchementrix IP. No new core mechanics (no fuel, bridges, lives, sound).

const Logic := preload("res://games/canyon_run/direct/canyon_logic.gd")
const Topo := preload("res://games/canyon_run/direct/canyon_topo.gd")

const STAGE := Vector2(1280, 720)
const PX := 2.0  ## 240×320 → 480×640 field (same Direct resolution, richer chrome)
const FIELD := Vector2(Logic.STAGE_W, Logic.STAGE_H) * PX
const FIELD_POS := Vector2((STAGE.x - FIELD.x) * 0.5, 40.0)

const BG_TOP := Color(0.03, 0.04, 0.09)
const BG_BOTTOM := Color(0.06, 0.05, 0.12)
const PANEL := Color(0.07, 0.09, 0.18, 0.94)
const FRAME := Color(0.42, 0.78, 0.95)
const INK := Color(0.93, 0.96, 1.0)
const MUTED := Color(0.58, 0.64, 0.82)
const GOLD := Color(1.0, 0.84, 0.32)
const CYAN := Color(0.35, 0.92, 1.0)
const HOT := Color(1.0, 0.48, 0.28)
const RED := Color(1.0, 0.34, 0.38)
const GREEN := Color(0.42, 0.95, 0.58)
const WATER_DEEP := Color(0.05, 0.18, 0.38)
const WATER_MID := Color(0.10, 0.34, 0.58)
const WATER_LIT := Color(0.22, 0.52, 0.72)
const ROCK := Color(0.38, 0.24, 0.14)
const ROCK_MID := Color(0.50, 0.33, 0.18)
const ROCK_LIT := Color(0.68, 0.48, 0.28)
const ROCK_RIM := Color(0.85, 0.68, 0.42)
const CRAFT := Color(0.98, 0.94, 0.55)
const CRAFT_GLOW := Color(1.0, 0.92, 0.40, 0.35)
const ENEMY := Color(0.95, 0.28, 0.32)
const BULLET := Color(1.0, 0.98, 0.75)

var logic = Logic.new(1)  ## Direct canyon_logic.gd instance
var topo = Topo.new()
var _bank := 0.0
var playing := false  ## false while the Enhanced title card is up
var steer_override := 0.0  ## tests can drive without input events
var throttle_override := NAN
var fire_override := false

var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _trail: Array[Vector2] = []
var _prev_kills := 0
var _prev_bullets := 0
var _prev_state := Logic.State.READY
var _speed_peak := Logic.SPEED_CRUISE

var _field: Control
var _ui: CanvasLayer
var _cards := {}
var _score_label: Label
var _best_label: Label
var _speed_label: Label
var _dist_label: Label
var _kills_label: Label
var _width_label: Label
var _hint_label: Label
var _font: Font
var _mono: Font
var _panel_style := StyleBoxFlat.new()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	_mono = sf
	_panel_style.bg_color = PANEL
	_panel_style.border_color = Color(FRAME, 0.45)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(14)
	# Fresh seed per launch (tests replace logic afterward).
	logic = Logic.new(Time.get_ticks_usec())
	topo.reset(logic._seed)
	_prev_kills = 0
	_prev_bullets = 0
	_prev_state = logic.state
	_speed_peak = logic.speed
	_build_field()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_card("title")
	_refresh_hud()


func _layout() -> void:
	var size := get_viewport_rect().size
	var s := minf(size.x / STAGE.x, size.y / STAGE.y)
	if s <= 0.0:
		return
	scale = Vector2(s, s)
	position = ((size - STAGE * s) * 0.5).floor()


func start() -> void:
	playing = true
	_show_card("")
	if logic.state == Logic.State.READY:
		logic.start()


## One presentation step over Direct logic.update (tests call this for parity).
func tick(delta: float, steer: float = 0.0, throttle: float = 0.0, fire: bool = false) -> void:
	if fire:
		if not logic.restart_if_ready():
			logic.fire()
	logic.update(delta, steer, throttle)
	_observe()


func _observe() -> void:
	# Kill juice: Direct increments kills when a bullet hits a drifter.
	if logic.kills > _prev_kills:
		for i in (logic.kills - _prev_kills):
			_burst(Vector2(logic.player_x, Logic.PLAYER_Y - 40.0), HOT, 10, 2.4)
			_float_text("+50", Vector2(logic.player_x, Logic.PLAYER_Y - 50.0), GOLD)
		_prev_kills = logic.kills
	# Muzzle flash when a new bullet appears.
	if logic.bullets.size() > _prev_bullets and logic.state == Logic.State.PLAY:
		_burst(Vector2(logic.player_x, Logic.PLAYER_Y - Logic.PLAYER_HALF.y), BULLET, 4, 1.2)
		_shake = maxf(_shake, 0.18)
	_prev_bullets = logic.bullets.size()
	# Crash juice.
	if logic.state == Logic.State.CRASHED and _prev_state != Logic.State.CRASHED:
		_shake = 1.0
		_flash = 0.85
		_flash_color = Color(1.0, 0.35, 0.25)
		_burst(Vector2(logic.player_x, Logic.PLAYER_Y), HOT, 18, 3.2)
		_burst(Vector2(logic.player_x, Logic.PLAYER_Y), GOLD, 10, 2.4)
		_show_card("crash")
	elif logic.state == Logic.State.PLAY and _prev_state != Logic.State.PLAY:
		_show_card("")
	elif logic.state == Logic.State.READY and playing:
		# After a restart_if_ready reset, return to play chrome.
		_show_card("")
	_prev_state = logic.state
	_speed_peak = maxf(_speed_peak, logic.speed)


func _process(delta: float) -> void:
	_time += delta
	if playing:
		var steer := _read_steer()
		var throttle := _read_throttle()
		var fire := _read_fire()
		tick(delta, steer, throttle, fire)
		_bank = move_toward(_bank, steer, delta * 4.0)
	else:
		_bank = move_toward(_bank, 0.0, delta * 2.0)
	topo.tick(delta)
	topo.sync_seed(logic._seed)
	_animate(delta)
	_refresh_hud()
	_field.queue_redraw()
	queue_redraw()


func _read_steer() -> float:
	if steer_override != 0.0:
		return clamp(steer_override, -1.0, 1.0)
	var steer := Input.get_axis("ui_left", "ui_right")
	if Input.is_physical_key_pressed(KEY_A):
		steer -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		steer += 1.0
	return clamp(steer, -1.0, 1.0)


func _read_throttle() -> float:
	if not is_nan(throttle_override):
		return clamp(throttle_override, -1.0, 1.0)
	var throttle := Input.get_axis("ui_down", "ui_up")
	if Input.is_physical_key_pressed(KEY_W):
		throttle += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		throttle -= 1.0
	return clamp(throttle, -1.0, 1.0)


func _read_fire() -> bool:
	if fire_override:
		fire_override = false
		return true
	return Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_Z)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.keycode
	if not playing and k in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z]:
		start()
		get_viewport().set_input_as_handled()
	elif playing and logic.state == Logic.State.CRASHED \
			and k in [KEY_SPACE, KEY_Z, KEY_ENTER] and logic.crash_timer >= Logic.CRASH_HOLD:
		logic.restart_if_ready()
		_prev_kills = 0
		_prev_bullets = 0
		_prev_state = logic.state
		_speed_peak = logic.speed
		_trail.clear()
		_show_card("")
		get_viewport().set_input_as_handled()


func _animate(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 2.4)
	_flash = maxf(0.0, _flash - delta * 1.8)
	# Exhaust particles while flying.
	if playing and logic.state == Logic.State.PLAY:
		var thrust := lerpf(0.4, 1.2, (logic.speed - Logic.SPEED_MIN) / (Logic.SPEED_MAX - Logic.SPEED_MIN))
		if randf() < 0.55 * thrust:
			_particles.append({
				"pos": Vector2(logic.player_x + randf_range(-2.0, 2.0), Logic.PLAYER_Y + Logic.PLAYER_HALF.y),
				"vel": Vector2(randf_range(-12.0, 12.0), randf_range(40.0, 90.0) * thrust),
				"r": randf_range(1.2, 2.6) * thrust,
				"life": randf_range(0.18, 0.38),
				"max": 0.38,
				"col": Color(CYAN.r, CYAN.g, CYAN.b, 0.9) if randf() < 0.45 else Color(GOLD.r, GOLD.g, GOLD.b, 0.85),
			})
		_trail.append(Vector2(logic.player_x, Logic.PLAYER_Y))
		while _trail.size() > 18:
			_trail.pop_front()
	for p in _particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.96
	_particles = _particles.filter(func(p): return p.life > 0.0)
	for f in _floaters:
		f.life -= delta
		f.pos += f.vel * delta
		f.vel.y -= 18.0 * delta
	_floaters = _floaters.filter(func(f): return f.life > 0.0)
	# Field shake offset.
	if _field != null:
		var shake_off := Vector2.ZERO
		if _shake > 0.0:
			shake_off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 6.0
		_field.position = FIELD_POS + shake_off


func _burst(at: Vector2, col: Color, n: int, speed: float) -> void:
	for i in n:
		var a := randf() * TAU
		_particles.append({
			"pos": at,
			"vel": Vector2(cos(a), sin(a)) * randf_range(20.0, 70.0) * speed,
			"r": randf_range(1.5, 3.5),
			"life": randf_range(0.25, 0.55),
			"max": 0.55,
			"col": col,
		})


func _float_text(text: String, at: Vector2, col: Color) -> void:
	_floaters.append({
		"text": text,
		"pos": at,
		"vel": Vector2(randf_range(-8.0, 8.0), -40.0),
		"life": 0.9,
		"max": 0.9,
		"col": col,
	})


func _draw() -> void:
	# Stage backdrop gradient.
	for i in 18:
		var t := float(i) / 17.0
		var c := BG_TOP.lerp(BG_BOTTOM, t)
		draw_rect(Rect2(0, STAGE.y * t, STAGE.x, STAGE.y / 18.0 + 1.0), c)
	# Soft vignette bars beside the field.
	draw_rect(Rect2(0, 0, FIELD_POS.x - 8, STAGE.y), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(FIELD_POS.x + FIELD.x + 8, 0, STAGE.x - (FIELD_POS.x + FIELD.x + 8), STAGE.y), Color(0, 0, 0, 0.25))
	if _flash > 0.0:
		var fc := _flash_color
		fc.a = _flash * 0.45
		draw_rect(Rect2(Vector2.ZERO, STAGE), fc)


func _build_field() -> void:
	_field = Control.new()
	_field.name = "Field"
	_field.position = FIELD_POS
	_field.size = FIELD
	_field.clip_contents = true
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.draw.connect(_draw_field)
	add_child(_field)


func _s(p: Vector2) -> Vector2:
	return p * PX


func _draw_field() -> void:
	# Paper-cut topo (same renderer as Direct) + Enhanced juice overlays.
	topo.paint(_field, logic, Vector2.ZERO, PX, _bank)
	# Wake / trail behind the craft.
	if _trail.size() >= 2 and logic.state == Logic.State.PLAY:
		for i in range(1, _trail.size()):
			var a := float(i) / float(_trail.size())
			var p0: Vector2 = _s(_trail[i - 1])
			var p1: Vector2 = _s(_trail[i])
			_field.draw_line(p0, p1, Color(CYAN.r, CYAN.g, CYAN.b, 0.12 * a), 2.0)
	# Particles + floaters in field space.
	for part in _particles:
		var a: float = clampf(part.life / maxf(part.max, 0.01), 0.0, 1.0)
		var pc: Color = part.col
		pc.a *= a
		_field.draw_circle(_s(part.pos), part.r * PX * 0.5, pc)
	for f in _floaters:
		var a: float = clampf(f.life / maxf(f.max, 0.01), 0.0, 1.0)
		var fc: Color = f.col
		fc.a = a
		_field.draw_string(_font, _s(f.pos), f.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, fc)
	if _font:
		topo.paint_badge(_field, Vector2.ZERO, PX, _font)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	# Left panel — controls + status.
	var left := _panel(Rect2(24, 40, 280, 520))
	_ui.add_child(left)
	var title := _label("CANYON RUN", 28, GOLD)
	title.position = Vector2(16, 14)
	title.size = Vector2(248, 36)
	left.add_child(title)
	var sub := _label("Enhanced | topo mock parity", 14, MUTED)
	sub.position = Vector2(16, 48)
	sub.size = Vector2(248, 22)
	left.add_child(sub)
	_hint_label = _label("<-/-> or A/D  steer\n^/v or W/S  throttle\nSpace / Z   fire\nEsc         pause\n\nFly the canyon.\nDon't kiss the walls\nor the gunboats.", 15, INK)
	_hint_label.position = Vector2(16, 88)
	_hint_label.size = Vector2(248, 280)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_hint_label)
	var back := _button("Back to Arcade", Color(0.22, 0.30, 0.58), 17)
	back.position = Vector2(16, 450)
	back.size = Vector2(248, 44)
	back.pressed.connect(GameRegistry.return_to_arcade)
	left.add_child(back)
	# Right panel — live HUD.
	var right := _panel(Rect2(STAGE.x - 304, 40, 280, 520))
	_ui.add_child(right)
	_score_label = _label("SCORE  0", 26, GOLD)
	_score_label.position = Vector2(16, 16)
	_score_label.size = Vector2(248, 34)
	right.add_child(_score_label)
	_best_label = _label("BEST   0", 18, MUTED)
	_best_label.position = Vector2(16, 54)
	_best_label.size = Vector2(248, 26)
	right.add_child(_best_label)
	_dist_label = _label("DIST   0", 18, INK)
	_dist_label.position = Vector2(16, 100)
	_dist_label.size = Vector2(248, 26)
	right.add_child(_dist_label)
	_speed_label = _label("SPEED  70", 18, CYAN)
	_speed_label.position = Vector2(16, 132)
	_speed_label.size = Vector2(248, 26)
	right.add_child(_speed_label)
	_kills_label = _label("KILLS  0", 18, HOT)
	_kills_label.position = Vector2(16, 164)
	_kills_label.size = Vector2(248, 26)
	right.add_child(_kills_label)
	_width_label = _label("CHANNEL  -", 18, MUTED)
	_width_label.position = Vector2(16, 196)
	_width_label.size = Vector2(248, 26)
	right.add_child(_width_label)
	var spd_cap := _label("THROTTLE", 13, MUTED)
	spd_cap.position = Vector2(16, 250)
	spd_cap.size = Vector2(248, 18)
	right.add_child(spd_cap)
	# Speed bar is drawn via a ColorRect stack updated in _refresh_hud.
	var bar_bg := ColorRect.new()
	bar_bg.name = "SpeedBarBg"
	bar_bg.position = Vector2(16, 274)
	bar_bg.size = Vector2(248, 18)
	bar_bg.color = Color(0.12, 0.14, 0.22)
	right.add_child(bar_bg)
	var bar_fill := ColorRect.new()
	bar_fill.name = "SpeedBar"
	bar_fill.position = Vector2(16, 274)
	bar_fill.size = Vector2(124, 18)
	bar_fill.color = CYAN
	right.add_child(bar_fill)
	var tip := _label("Best of Direct rules +\nRiver Raid chrome.\nNo fuel / bridges yet.", 13, MUTED)
	tip.position = Vector2(16, 320)
	tip.size = Vector2(248, 80)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(tip)
	# Title card.
	_cards["title"] = _make_card("CANYON RUN", "Paper-cut canyon flyer\n\nSteer clear of the walls.\nBlast the gunboats.\n\nSpace / Enter to fly", true)
	# Crash card.
	_cards["crash"] = _make_card("CRASHED", "score 0\n\nSpace to fly again", false)


func _panel(rect: Rect2) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", _panel_style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if _font:
		l.add_theme_font_override("font", _font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, col: Color, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	b.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate()
	sb_h.bg_color = col.lightened(0.12)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", sb_h)
	return b


func _make_card(heading: String, body: String, with_start: bool) -> Control:
	var wrap := Control.new()
	wrap.visible = false
	wrap.position = FIELD_POS
	wrap.size = FIELD
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(wrap)
	var dim := ColorRect.new()
	dim.size = FIELD
	dim.color = Color(0.02, 0.03, 0.08, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(dim)
	var box := _panel(Rect2((FIELD.x - 360) * 0.5, (FIELD.y - 280) * 0.5, 360, 280))
	wrap.add_child(box)
	var h := _label(heading, 32, GOLD)
	h.position = Vector2(20, 24)
	h.size = Vector2(320, 40)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(h)
	var b := _label(body, 16, INK)
	b.name = "Body"
	b.position = Vector2(24, 80)
	b.size = Vector2(312, 140)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(b)
	if with_start:
		var start_btn := _button("Start", Color(0.18, 0.55, 0.42), 18)
		start_btn.position = Vector2(90, 210)
		start_btn.size = Vector2(180, 44)
		start_btn.pressed.connect(start)
		box.add_child(start_btn)
	return wrap


func _show_card(key: String) -> void:
	for k in _cards.keys():
		_cards[k].visible = (k == key)


func _refresh_hud() -> void:
	_score_label.text = "SCORE  %d" % logic.score
	_best_label.text = "BEST   %d" % maxi(logic.best, logic.score)
	_dist_label.text = "DIST   %d" % int(logic.dist)
	_speed_label.text = "SPEED  %d" % int(logic.speed)
	_kills_label.text = "KILLS  %d" % logic.kills
	var w: Vector2 = logic.walls_at(logic.player_world_y())
	_width_label.text = "CHANNEL  %d px" % int(w.y - w.x)
	var right: Panel = null
	for c in _ui.get_children():
		if c is Panel and c.position.x > STAGE.x * 0.5:
			right = c
			break
	if right:
		var bar: ColorRect = right.get_node_or_null("SpeedBar")
		if bar:
			var t := clampf((logic.speed - Logic.SPEED_MIN) / (Logic.SPEED_MAX - Logic.SPEED_MIN), 0.0, 1.0)
			bar.size.x = 248.0 * t
			bar.color = CYAN.lerp(HOT, t)
	if logic.state == Logic.State.CRASHED and _cards.has("crash"):
		var body: Label = _cards["crash"].find_child("Body", true, false)
		if body:
			if logic.crash_timer >= Logic.CRASH_HOLD:
				body.text = "score %d\n\nSpace to fly again" % logic.score
			else:
				body.text = "score %d" % logic.score
