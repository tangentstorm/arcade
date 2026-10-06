extends Node2D
## GodotLab Game 00 (Enhanced). Presentation makeover of the Direct drift-sprite sketch.
## The playfield is Direct `game.tscn` (shared `icon.gd`), instanced in a 1280×720
## SubViewport — SPEED / friction / wrap stay Direct. Enhanced owns the 1280×720
## letterbox chrome, frames the viewport with stretch=false + scale (not stretch=true),
## and derives juice from observing the Direct icon's position / velocity: motion
## trail, speed glow, thrust sparks, wrap pops, HUD. Esc → PauseOverlay.
## No Alchementrix IP.

const DIRECT := preload("res://games/godotlab_game00/direct/game.tscn")
const IconScript := preload("res://games/godotlab_game00/direct/icon.gd")

const STAGE := Vector2(1280, 720)
## Direct wrap space matches the arcade window (project 1280×720).
const VP_SIZE := Vector2(1280, 720)
## Framed at ¾ with stretch=false + scale (Overlap #78 taught us not to fake this with stretch=true).
const FIELD := Vector2(960, 540)
const FIELD_POS := Vector2(160, 72)
const VIEW_K := FIELD.x / VP_SIZE.x  ## 0.75

const BG_TOP := Color(0.04, 0.06, 0.12)
const BG_BOT := Color(0.08, 0.04, 0.14)
const PANEL := Color(0.08, 0.10, 0.20, 0.94)
const FRAME := Color(0.45, 0.75, 1.0)
const INK := Color(0.93, 0.95, 1.0)
const MUTED := Color(0.58, 0.64, 0.82)
const GOLD := Color(1.0, 0.85, 0.30)
const ACCENT := Color(0.45, 0.90, 0.75)
const HOT := Color(1.0, 0.55, 0.35)

const TRAIL_LEN := 28
const ICON_R := 64.0  ## Direct icon.png is 128×128

enum { TITLE, PLAY }

var state := TITLE
var demo: Node2D = null
var icon: Sprite2D = null

## View-only presentation state (derived from Direct).
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _flash_c := GOLD
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _trail: Array[Vector2] = []
var _banner := ""
var _banner_t := 0.0
var _prev_pos := Vector2.ZERO
var _prev_vel := Vector2.ZERO
var _have_prev := false
var distance := 0.0
var wraps := 0
var boosts := 0
var peak_speed := 0.0
var thrusts := 0  ## frames where speed rose while an arrow was held (juice counter)

var _clip: Control
var _vp_box: SubViewportContainer
var _viewport: SubViewport
var _fx: Node2D
var _ui: CanvasLayer
var _hud: Control
var _cards := {}
var _speed_label: Label
var _pos_label: Label
var _dist_label: Label
var _wrap_label: Label
var _peak_label: Label
var _boost_label: Label
var _font: Font
var _panel_style := StyleBoxFlat.new()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_panel_style.bg_color = PANEL
	_panel_style.border_color = Color(FRAME, 0.55)
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
	if s <= 0.0:
		return
	scale = Vector2(s, s)
	position = (size - STAGE * s) * 0.5
	if _ui:
		_ui.transform = Transform2D(0.0, scale, 0.0, position)


func _set_state(s: int) -> void:
	state = s
	_cards["title"].visible = s == TITLE
	_hud.visible = s == PLAY
	_clip.visible = s == PLAY
	if s == PLAY and demo == null:
		_load_demo()
	if s == PLAY:
		_banner = "ARROW KEYS  |  PUSH THE ICON"
		_banner_t = 2.0


func _load_demo() -> void:
	demo = DIRECT.instantiate() as Node2D
	_viewport.add_child(demo)
	icon = demo.get_node("icon") as Sprite2D
	# Enhanced draws its own chrome; hide Direct's plain hint label.
	demo.get_node("Hud").visible = false
	_have_prev = false
	_trail.clear()
	distance = 0.0
	wraps = 0
	boosts = 0
	peak_speed = 0.0
	thrusts = 0
	_frame_view()
	_refresh_hud()


func _frame_view() -> void:
	## stretch=false + explicit scale (do not use stretch=true to fake half-size).
	_vp_box.scale = Vector2(VIEW_K, VIEW_K)
	_vp_box.position = Vector2.ZERO
	_vp_box.size = VP_SIZE


## Stage-space centre of the Direct icon (for overlays / tests).
func icon_stage_pos() -> Vector2:
	if icon == null:
		return Vector2.ZERO
	return FIELD_POS + icon.position * VIEW_K


## Stage-space radius of the Direct icon sprite.
func icon_stage_r() -> float:
	return ICON_R * VIEW_K


# --- input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var e := event as InputEventKey
	if state == TITLE:
		if e.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
			_set_state(PLAY)
			get_viewport().set_input_as_handled()
		return
	# Direct icon.gd reads Input actions itself; Enhanced only adds a soft reset.
	if e.keycode == KEY_R:
		_reset_icon()
		get_viewport().set_input_as_handled()


func _reset_icon() -> void:
	if icon == null:
		return
	icon.position = Vector2(438, 246)  # Direct spawn (presentation reset of Direct state)
	icon.velocity = Vector2.ZERO
	_trail.clear()
	_have_prev = false
	distance = 0.0
	wraps = 0
	boosts = 0
	peak_speed = 0.0
	thrusts = 0
	_banner = "RESET"
	_banner_t = 1.0
	_burst(icon_stage_pos(), GOLD, 10, 140.0)


# --- tick: observe Direct -----------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 2.4)
	_shake = maxf(0.0, _shake - delta * 3.0)
	_banner_t = maxf(0.0, _banner_t - delta)
	if state == PLAY and icon != null:
		_observe(delta)
		_refresh_hud()
	_animate_fx(delta)
	var off := Vector2.ZERO
	if _shake > 0.0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 5.0
	_clip.position = FIELD_POS + off
	queue_redraw()
	_fx.queue_redraw()


func _observe(delta: float) -> void:
	var pos: Vector2 = icon.position
	var vel: Vector2 = icon.velocity
	var spd := vel.length()
	peak_speed = maxf(peak_speed, spd)
	if _have_prev:
		var step := pos.distance_to(_prev_pos)
		# A wrap jumps nearly a full viewport edge — don't add that to distance.
		if step < VP_SIZE.x * 0.5:
			distance += step
		else:
			wraps += 1
			_wrap_juice(pos, _prev_pos)
		var rising := spd > _prev_vel.length() + 5.0
		var thrusting := (
			Input.is_action_pressed("ui_right")
			or Input.is_action_pressed("ui_left")
			or Input.is_action_pressed("ui_up")
			or Input.is_action_pressed("ui_down")
		)
		if thrusting and rising:
			thrusts += 1
			if thrusts % 4 == 1:
				boosts += 1
				_burst(icon_stage_pos() - vel.normalized() * 18.0, HOT, 4, 90.0)
		# Trail samples in Direct viewport space.
		if step > 1.5 or thrusting:
			_trail.append(pos)
			while _trail.size() > TRAIL_LEN:
				_trail.pop_front()
	else:
		_have_prev = true
	_prev_pos = pos
	_prev_vel = vel
	# Soft coast sparkles when moving fast without thrust.
	if spd > 200.0 and randf() < delta * 8.0:
		_burst(icon_stage_pos(), Color(FRAME, 0.7), 1, 40.0)


func _wrap_juice(now: Vector2, was: Vector2) -> void:
	_flash = 0.45
	_flash_c = ACCENT
	_shake = maxf(_shake, 0.25)
	_burst(FIELD_POS + was * VIEW_K, ACCENT, 12, 160.0)
	_burst(FIELD_POS + now * VIEW_K, GOLD, 10, 140.0)
	_floater("WRAP", FIELD_POS + now * VIEW_K + Vector2(-24, -40), ACCENT)
	_banner = "WRAP"
	_banner_t = 0.8


func _refresh_hud() -> void:
	var spd: float = icon.velocity.length() if icon else 0.0
	var pos: Vector2 = icon.position if icon else Vector2.ZERO
	_speed_label.text = "speed  %.0f px/s" % spd
	_pos_label.text = "pos  (%.0f, %.0f)" % [pos.x, pos.y]
	_dist_label.text = "distance  %.0f px" % distance
	_wrap_label.text = "wraps  %d" % wraps
	_peak_label.text = "peak  %.0f px/s" % peak_speed
	_boost_label.text = "boosts  %d" % boosts


# --- draw ---------------------------------------------------------------------

func _draw() -> void:
	for i in 24:
		var t := float(i) / 24.0
		draw_rect(Rect2(0, STAGE.y * t, STAGE.x, STAGE.y / 24.0 + 1.0), BG_TOP.lerp(BG_BOT, t))
	for i in 36:
		var x := fmod(i * 97.3 + _time * (5.0 + i % 5), STAGE.x)
		var y := fmod(i * 53.1 + sin(_time * 0.4 + i) * 10.0 + 200.0, STAGE.y)
		draw_circle(Vector2(x, y), 1.0 + (i % 3) * 0.5, Color(0.55, 0.75, 1.0, 0.08 + 0.04 * (i % 3)))
	if state != PLAY:
		return
	var fr := Rect2(FIELD_POS - Vector2(10, 10), FIELD + Vector2(20, 20))
	draw_rect(fr, Color(0.05, 0.07, 0.14, 0.92))
	# faint grid over the field
	for i in 9:
		var gx := FIELD_POS.x + FIELD.x * float(i) / 8.0
		var gy := FIELD_POS.y + FIELD.y * float(i) / 8.0
		draw_line(Vector2(gx, FIELD_POS.y), Vector2(gx, FIELD_POS.y + FIELD.y), Color(1, 1, 1, 0.04), 1.0)
		draw_line(Vector2(FIELD_POS.x, gy), Vector2(FIELD_POS.x + FIELD.x, gy), Color(1, 1, 1, 0.04), 1.0)
	draw_rect(fr.grow(-4), Color(FRAME, 0.5), false, 2.0)
	draw_rect(fr.grow(2), Color(FRAME, 0.18), false, 1.5)


func _draw_fx() -> void:
	if state == PLAY and icon != null:
		var p := icon_stage_pos()
		var r := icon_stage_r()
		var spd: float = icon.velocity.length()
		var vel: Vector2 = icon.velocity
		# Motion trail (Direct positions → stage).
		if _trail.size() >= 2:
			for i in _trail.size() - 1:
				var a := FIELD_POS + _trail[i] * VIEW_K
				var b := FIELD_POS + _trail[i + 1] * VIEW_K
				var t := float(i + 1) / float(_trail.size())
				_fx.draw_line(a, b, Color(GOLD, 0.15 + 0.45 * t), 2.0 + 4.0 * t)
		# Speed glow around the Direct sprite.
		var glow := clampf(spd / 800.0, 0.0, 1.0)
		if glow > 0.02:
			var pulse := 0.5 + 0.5 * sin(_time * (4.0 + glow * 6.0))
			_fx.draw_circle(p, r * (0.9 + 0.25 * glow), Color(GOLD, 0.08 + 0.12 * glow * pulse))
			_fx.draw_arc(p, r * (1.05 + 0.15 * glow * pulse), 0, TAU, 40,
					Color(FRAME, 0.25 + 0.45 * glow), 2.0 + 2.0 * glow)
		# Velocity vector (view-only).
		if spd > 20.0:
			var tip := p + vel.normalized() * (r + 12.0 + clampf(spd * 0.04, 0.0, 60.0))
			_fx.draw_line(p, tip, Color(ACCENT, 0.75), 2.5)
			_fx.draw_circle(tip, 3.5, ACCENT)
		# Soft ring at rest so the icon reads on the chrome.
		if spd < 30.0:
			_fx.draw_arc(p, r + 4.0 + 2.0 * sin(_time * 2.0), 0, TAU, 36, Color(FRAME, 0.35), 1.5)
	for part in _particles:
		var col: Color = part.color
		col.a *= clampf(part.life / part.max, 0.0, 1.0)
		_fx.draw_circle(part.pos, part.size, col)
	for f in _floaters:
		var col: Color = f.color
		col.a *= clampf(f.life / f.max, 0.0, 1.0)
		_fx.draw_string(_font, f.pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
	if _flash > 0.0:
		_fx.draw_rect(Rect2(FIELD_POS, FIELD), Color(_flash_c, _flash * 0.16))
	if _banner_t > 0.0 and _banner != "":
		var a := clampf(_banner_t, 0.0, 1.0)
		var r2 := Rect2(STAGE.x * 0.5 - 220, FIELD_POS.y + 12, 440, 32)
		_fx.draw_rect(r2, Color(0.04, 0.05, 0.10, 0.8 * a))
		_fx.draw_string(_font, r2.position + Vector2(0, 23), _banner, HORIZONTAL_ALIGNMENT_CENTER,
				r2.size.x, 16, Color(GOLD, a))


# --- FX helpers ---------------------------------------------------------------

func _burst(at: Vector2, color: Color, n: int, speed: float) -> void:
	for i in n:
		var ang := randf() * TAU
		var sp := randf_range(0.3, 1.0) * speed
		_particles.append({
			"pos": at, "vel": Vector2(cos(ang), sin(ang)) * sp,
			"life": randf_range(0.25, 0.55), "max": 0.55,
			"color": color, "size": randf_range(1.5, 3.5),
		})


func _floater(text: String, at: Vector2, color: Color) -> void:
	_floaters.append({"pos": at, "life": 0.9, "max": 0.9, "text": text, "color": color})


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
		f.pos.y -= 28.0 * delta
		if f.life <= 0.0:
			_floaters.remove_at(i)
		else:
			i += 1


# --- build --------------------------------------------------------------------

func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "DirectVP"
	_viewport.size = Vector2i(VP_SIZE)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.handle_input_locally = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE

	_vp_box = SubViewportContainer.new()
	_vp_box.name = "DemoView"
	_vp_box.size = VP_SIZE
	_vp_box.stretch = false
	_vp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp_box.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_vp_box.add_child(_viewport)

	_clip = Control.new()
	_clip.name = "Field"
	_clip.position = FIELD_POS
	_clip.size = FIELD
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.visible = false
	add_child(_clip)
	_clip.add_child(_vp_box)

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

	var top := _panel(Rect2(40, 14, 1200, 48))
	_hud.add_child(top)
	top.add_child(_label("GODOTLAB GAME 00", 22, GOLD, Vector2(16, 10)))
	top.add_child(_label("Enhanced", 13, ACCENT, Vector2(280, 16)))
	top.add_child(_label("arrow keys push | friction coasts | wraps at the edge", 13, MUTED, Vector2(380, 16)))
	var back := _btn("Back to Arcade", Vector2(1056, 8), Vector2(128, 32))
	back.pressed.connect(GameRegistry.return_to_arcade)
	top.add_child(back)

	var stats := _panel(Rect2(40, 624, 760, 80))
	_hud.add_child(stats)
	stats.add_child(_label("TELEMETRY", 11, MUTED, Vector2(14, 8)))
	_speed_label = _label("speed  0", 15, GOLD, Vector2(14, 28))
	stats.add_child(_speed_label)
	_pos_label = _label("pos  -", 14, INK, Vector2(14, 52))
	stats.add_child(_pos_label)
	_dist_label = _label("distance  0", 14, INK, Vector2(260, 28))
	stats.add_child(_dist_label)
	_peak_label = _label("peak  0", 14, ACCENT, Vector2(260, 52))
	stats.add_child(_peak_label)
	_wrap_label = _label("wraps  0", 14, HOT, Vector2(500, 28))
	stats.add_child(_wrap_label)
	_boost_label = _label("boosts  0", 14, GOLD, Vector2(500, 52))
	stats.add_child(_boost_label)

	var keys := _panel(Rect2(820, 624, 420, 80))
	_hud.add_child(keys)
	keys.add_child(_label("CONTROLS", 11, MUTED, Vector2(14, 8)))
	keys.add_child(_label("Arrows  push    R  reset spawn    Esc  pause / arcade", 13, INK, Vector2(14, 30)))
	keys.add_child(_label("Same Direct icon.gd drives the sprite.", 11, MUTED, Vector2(14, 54)))

	var card := _panel(Rect2(STAGE.x * 0.5 - 310, STAGE.y * 0.5 - 170, 620, 340))
	card.name = "TitleCard"
	_ui.add_child(card)
	_cards["title"] = card
	card.add_child(_label("GODOTLAB GAME 00", 32, GOLD, Vector2(36, 30)))
	card.add_child(_label("Enhanced edition", 16, ACCENT, Vector2(36, 78)))
	card.add_child(_label(
		"The Direct drift-sprite sketch, framed with chrome:\narrow keys still push via Direct icon.gd, friction still\ncoasts it to a stop, and the edges still wrap - Enhanced\nonly adds the trail, glow, wrap pops and telemetry.",
		14, INK, Vector2(36, 114)))
	var start := _btn("Start", Vector2(36, 224), Vector2(120, 40))
	start.pressed.connect(func(): _set_state(PLAY))
	card.add_child(start)
	card.add_child(_label("Enter / Space  to begin", 14, MUTED, Vector2(180, 234)))
	var title_back := _btn("Back to Arcade", Vector2(36, 282), Vector2(160, 34))
	title_back.pressed.connect(GameRegistry.return_to_arcade)
	card.add_child(title_back)
	card.add_child(_label("->  |  friction 0.975", 16, Color(GOLD, 0.7), Vector2(380, 290)))


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
		var base := Color(0.14, 0.22, 0.40)
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
