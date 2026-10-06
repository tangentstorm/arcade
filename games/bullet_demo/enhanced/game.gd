extends Node2D
## Bullet Demo (Enhanced). Presentation makeover of the Direct GameSketchLib
## course w02 BulletDemo port. The playfield is Direct `game.tscn` (shared
## `bullet_logic.gd`), instanced in a native 300×300 SubViewport — fire / kill /
## ammo-rack stay Direct. Enhanced owns the 1280×720 letterbox chrome, frames
## the viewport with stretch=false + scale @2× (not stretch=true), and derives
## juice from observing Direct's world: muzzle flash, bullet glow + trails,
## hit bursts, top-edge fizzles, aim guide, side HUD, title card.
## Esc → PauseOverlay. No Alchementrix IP.

const DIRECT := preload("res://games/bullet_demo/direct/game.tscn")
const Logic := preload("res://games/bullet_demo/direct/bullet_logic.gd")

const STAGE := Vector2(1280, 720)
## Direct sketch is authored at 300×300; show it @2× in a clipped field.
const VP_SIZE := Vector2(300, 300)
const FIELD := Vector2(600, 600)
const FIELD_POS := Vector2(340, 60)
const VIEW_K := FIELD.x / VP_SIZE.x  ## 2.0
const TRAIL_LEN := 12

const BG_TOP := Color(0.03, 0.05, 0.14)
const BG_BOT := Color(0.06, 0.04, 0.14)
const PANEL := Color(0.06, 0.09, 0.20, 0.94)
const FRAME := Color(0.45, 0.70, 1.0)
const INK := Color(0.93, 0.96, 1.0)
const MUTED := Color(0.58, 0.64, 0.82)
const GOLD := Color(1.0, 0.84, 0.32)
const HOT := Color(1.0, 0.48, 0.28)
const GREEN := Color(0.42, 0.95, 0.58)
const LIVE_GLOW := Color(0.95, 0.98, 1.0)
const DEAD_GLOW := Color(0.55, 0.58, 0.68)

enum { TITLE, PLAY }

var state := TITLE
var demo: Control = null
var world = null  ## Direct bullet_logic.gd once loaded

## View-only presentation state (derived from Direct).
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _trails: Array = []  ## per bullet: Array[Vector2] sketch positions
var _banner := ""
var _banner_t := 0.0
var _aim_x := 150.0  ## sketch-space mouse x for the view-only aim guide

var _steps := 0
var _shots := 0
var _hits := 0
var _fizzles := 0
var _dry_clicks := 0
var _starts := 0

## Previous-frame snapshot of Direct state (for deltas).
var _prev_sq_alive: Array[bool] = []
var _prev_bullets: Array[Dictionary] = []
var _prev_left := 0

var _vp_box: SubViewportContainer
var _viewport: SubViewport
var _fx: Node2D
var _ui: CanvasLayer
var _hud: Control
var _cards := {}
var _shots_label: Label
var _hits_label: Label
var _fizz_label: Label
var _squares_label: Label
var _rack_label: Label
var _hint_label: Label
var _font: Font
var _panel_style := StyleBoxFlat.new()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_panel_style.bg_color = PANEL
	_panel_style.border_color = Color(FRAME, 0.45)
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
	position = ((size - STAGE * s) * 0.5).floor()
	if _ui:
		_ui.transform = Transform2D(0.0, scale, 0.0, position)


func _set_state(s: int) -> void:
	state = s
	_cards["title"].visible = s == TITLE
	_hud.visible = s == PLAY
	_vp_box.visible = s == PLAY
	if s == PLAY and demo == null:
		_load_demo()
	if s == PLAY:
		_starts += 1
		_banner = "CLICK TO FIRE  |  3 BULLETS"
		_banner_t = 2.0
		_flash = 0.35
		_flash_color = FRAME


func _load_demo() -> void:
	demo = DIRECT.instantiate() as Control
	demo.set_anchors_preset(Control.PRESET_FULL_RECT)
	demo.offset_left = 0
	demo.offset_top = 0
	demo.offset_right = 0
	demo.offset_bottom = 0
	_viewport.add_child(demo)
	world = demo.world
	# Enhanced draws its own chrome; hide Direct's plain hint + letterbox fill.
	var help := demo.get_node_or_null("Help")
	if help:
		help.visible = false
	var bg := demo.get_node_or_null("Background")
	if bg:
		bg.visible = false
	_snap_prev()
	_frame_view()
	_refresh_hud()


func _frame_view() -> void:
	## stretch=false + explicit scale (do not use stretch=true to fake half-size).
	_vp_box.scale = Vector2(VIEW_K, VIEW_K)
	_vp_box.position = FIELD_POS
	_vp_box.size = VP_SIZE


## Sketch → stage mapping (for overlays / tests).
func sketch_to_stage(p: Vector2) -> Vector2:
	return FIELD_POS + p * VIEW_K


# --- Direct I/O (tests call these for parity) ---------------------------------

## Forward a Processing mousePressed at sketch coords, then read the deltas.
func press(sx: int, sy: int) -> void:
	if world == null:
		return
	var before_left: int = world.bullets_left
	world.mouse_pressed(sx, sy)
	if world.bullets_left == before_left and before_left == 0:
		_dry_clicks += 1
		_floater("empty", sketch_to_stage(Vector2(sx, Logic.H - 40)), MUTED)
	_observe(true)


func release(sx: int, sy: int) -> void:
	if world == null:
		return
	world.mouse_released(sx, sy)


func drag(sx: int, sy: int) -> void:
	if world == null:
		return
	world.mouse_dragged(sx, sy)
	_aim_x = float(sx)


## One presentation step: apply events, then one Direct step().
## `events` is an Array of ["press"|"release"|"drag", x, y].
func tick(events: Array = []) -> void:
	if world == null:
		return
	for e in events:
		match String(e[0]):
			"press":
				press(int(e[1]), int(e[2]))
			"release":
				release(int(e[1]), int(e[2]))
			"drag":
				drag(int(e[1]), int(e[2]))
	world.step()
	_steps += 1
	_observe(false)
	if demo != null and demo.has_node("%Room"):
		demo.get_node("%Room").queue_redraw()


# --- Delta observer (read-only over Direct state) -----------------------------

func _snap_prev() -> void:
	if world == null:
		return
	_prev_sq_alive.clear()
	for sq in world.squares:
		_prev_sq_alive.append(sq.alive)
	_prev_bullets.clear()
	for b in world.bullets:
		_prev_bullets.append({"alive": b.alive, "rect": Rect2(b.x, b.y, b.w, b.h)})
	_prev_left = world.bullets_left
	while _trails.size() < world.bullets.size():
		_trails.append([])
	if _trails.size() > world.bullets.size():
		_trails.resize(world.bullets.size())


func _observe(from_input: bool = false) -> void:
	if world == null:
		return
	# Shots: a dead → alive bullet (or bullets_left drop on press).
	for i in world.bullets.size():
		var b = world.bullets[i]
		var was: Dictionary = _prev_bullets[i] if i < _prev_bullets.size() else {"alive": false}
		if b.alive and not was.alive:
			_shots += 1
			var at := sketch_to_stage(Vector2(b.x + b.w * 0.5, b.y + b.h))
			_burst(at, GOLD, 10, 160.0)
			_flash = maxf(_flash, 0.35)
			_flash_color = GOLD
			_shake = maxf(_shake, 0.2)
			_aim_x = b.x
		if b.alive:
			var trail: Array = _trails[i]
			trail.append(Vector2(b.x + b.w * 0.5, b.y + b.h * 0.5))
			while trail.size() > TRAIL_LEN:
				trail.pop_front()
			_trails[i] = trail
		elif _trails[i].size() > 0:
			_trails[i] = []
		# Fizzle: was alive, now dead, and no square died this frame for this bullet.
		if was.alive and not b.alive and not from_input:
			var killed := false
			for j in world.squares.size():
				if _prev_sq_alive[j] and not world.squares[j].alive:
					killed = true
					break
			if not killed and was.rect.position.y < 40.0:
				_fizzles += 1
				_burst(sketch_to_stage(was.rect.position + was.rect.size * 0.5), FRAME, 8, 120.0)
				_floater("miss", sketch_to_stage(Vector2(was.rect.position.x, 8)), MUTED)
				_rings.append({
					"pos": sketch_to_stage(Vector2(was.rect.position.x + was.rect.size.x * 0.5, 4)),
					"life": 0.45, "max": 0.45, "color": FRAME, "r": 6.0,
				})
	# Hits: live → dead squares.
	for j in world.squares.size():
		if j < _prev_sq_alive.size() and _prev_sq_alive[j] and not world.squares[j].alive:
			_hits += 1
			var sq = world.squares[j]
			var at2 := sketch_to_stage(Vector2(sq.x + sq.w * 0.5, sq.y + sq.h * 0.5))
			_burst(at2, HOT, 16, 220.0)
			_floater("HIT", at2 + Vector2(-14, -18), HOT)
			_flash = 0.5
			_flash_color = HOT
			_shake = maxf(_shake, 0.35)
			_rings.append({"pos": at2, "life": 0.55, "max": 0.55, "color": GOLD, "r": 10.0})
	_snap_prev()
	_refresh_hud()


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


func _input(event: InputEvent) -> void:
	if state != PLAY:
		return
	# Track mouse x over the field for the view-only aim guide.
	var mm := event as InputEventMouseMotion
	if mm != null:
		var local := to_local(mm.position)
		if Rect2(FIELD_POS, FIELD).has_point(local):
			_aim_x = (local.x - FIELD_POS.x) / VIEW_K


# --- tick ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 2.4)
	_shake = maxf(0.0, _shake - delta * 3.0)
	_banner_t = maxf(0.0, _banner_t - delta)
	if state == PLAY and world != null:
		# Direct steps itself; we only observe after its tick(s).
		_observe(false)
	_animate_fx(delta)
	var off := Vector2.ZERO
	if _shake > 0.0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 5.0
	_vp_box.position = FIELD_POS + off
	queue_redraw()
	if _fx:
		_fx.queue_redraw()


func _refresh_hud() -> void:
	if world == null or _shots_label == null:
		return
	var live := 0
	for sq in world.squares:
		if sq.alive:
			live += 1
	_shots_label.text = "shots  %d" % _shots
	_hits_label.text = "hits  %d" % _hits
	_fizz_label.text = "misses  %d" % _fizzles
	_squares_label.text = "squares  %d / %d" % [live, world.squares.size()]
	_rack_label.text = "ammo  %d / %d" % [world.bullets_left, Logic.K_BULLET_COUNT]
	_hint_label.text = "click anywhere on the field to fire from mouse x"


# --- draw ---------------------------------------------------------------------

func _draw() -> void:
	for i in 24:
		var t := float(i) / 24.0
		draw_rect(Rect2(0, STAGE.y * t, STAGE.x, STAGE.y / 24.0 + 1.0), BG_TOP.lerp(BG_BOT, t))
	for i in 40:
		var x := fmod(i * 97.3 + _time * (4.0 + i % 5), STAGE.x)
		var y := fmod(i * 53.1 + sin(_time * 0.4 + i) * 10.0 + 180.0, STAGE.y)
		draw_circle(Vector2(x, y), 1.0 + (i % 3) * 0.5, Color(0.55, 0.75, 1.0, 0.07 + 0.04 * (i % 3)))
	if state != PLAY:
		return
	var fr := Rect2(FIELD_POS - Vector2(12, 12), FIELD + Vector2(24, 24))
	draw_rect(fr, Color(0.04, 0.06, 0.14, 0.92))
	draw_rect(fr.grow(-4), Color(FRAME, 0.5), false, 2.0)
	var corner := Color(GOLD.r, GOLD.g, GOLD.b, 0.75)
	draw_rect(Rect2(fr.position, Vector2(28, 3)), corner)
	draw_rect(Rect2(fr.position, Vector2(3, 28)), corner)
	draw_rect(Rect2(fr.end - Vector2(28, 3), Vector2(28, 3)), corner)
	draw_rect(Rect2(fr.end - Vector2(3, 28), Vector2(3, 28)), corner)


func _draw_fx() -> void:
	if state == PLAY and world != null:
		# Soft glow over live / dead squares (Direct still draws the rects).
		for sq in world.squares:
			var c := LIVE_GLOW if sq.alive else DEAD_GLOW
			var r := Rect2(sketch_to_stage(Vector2(sq.x, sq.y)), Vector2(sq.w, sq.h) * VIEW_K)
			_fx.draw_rect(r.grow(3.0), Color(c, 0.10 if sq.alive else 0.06))
			if sq.alive:
				var pulse := 0.5 + 0.5 * sin(_time * 3.0 + sq.x * 0.1)
				_fx.draw_rect(r.grow(1.0), Color(FRAME, 0.15 + 0.12 * pulse), false, 1.5)
		# Bullet trails + glow.
		for i in world.bullets.size():
			var b = world.bullets[i]
			var trail: Array = _trails[i] if i < _trails.size() else []
			if trail.size() >= 2:
				for t_i in trail.size() - 1:
					var a: Vector2 = sketch_to_stage(trail[t_i])
					var bb: Vector2 = sketch_to_stage(trail[t_i + 1])
					var tt := float(t_i + 1) / float(trail.size())
					_fx.draw_line(a, bb, Color(GOLD, 0.15 + 0.55 * tt), 2.0 + 3.0 * tt)
			if b.alive:
				var br := Rect2(sketch_to_stage(Vector2(b.x, b.y)), Vector2(b.w, b.h) * VIEW_K)
				_fx.draw_rect(br.grow(4.0), Color(GOLD, 0.18))
				_fx.draw_rect(br.grow(1.0), Color(GOLD, 0.55), false, 2.0)
		# View-only aim guide (does not affect Direct).
		var gx := FIELD_POS.x + _aim_x * VIEW_K
		_fx.draw_line(Vector2(gx, FIELD_POS.y), Vector2(gx, FIELD_POS.y + FIELD.y),
				Color(FRAME, 0.18 + 0.08 * sin(_time * 4.0)), 1.5)
		_fx.draw_circle(Vector2(gx, FIELD_POS.y + FIELD.y - 8), 4.0, Color(GOLD, 0.55))
	for part in _particles:
		var col: Color = part.color
		col.a *= clampf(part.life / part.max, 0.0, 1.0)
		_fx.draw_circle(part.pos, part.size, col)
	for f in _floaters:
		var col2: Color = f.color
		col2.a *= clampf(f.life / f.max, 0.0, 1.0)
		_fx.draw_string(_font, f.pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col2)
	for ring in _rings:
		var a3 := clampf(ring.life / ring.max, 0.0, 1.0)
		var rr: float = ring.r + (1.0 - a3) * 28.0
		_fx.draw_arc(ring.pos, rr, 0, TAU, 28, Color(ring.color, a3 * 0.7), 2.0)
	if _flash > 0.0:
		_fx.draw_rect(Rect2(FIELD_POS, FIELD), Color(_flash_color, _flash * 0.16))
	if _banner_t > 0.0 and _banner != "":
		var a4 := clampf(_banner_t, 0.0, 1.0)
		var r2 := Rect2(STAGE.x * 0.5 - 240, FIELD_POS.y + 12, 480, 32)
		_fx.draw_rect(r2, Color(0.04, 0.05, 0.10, 0.8 * a4))
		_fx.draw_string(_font, r2.position + Vector2(0, 23), _banner, HORIZONTAL_ALIGNMENT_CENTER,
				r2.size.x, 16, Color(GOLD, a4))


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
	i = 0
	while i < _rings.size():
		var r: Dictionary = _rings[i]
		r.life -= delta
		if r.life <= 0.0:
			_rings.remove_at(i)
		else:
			i += 1


# --- build --------------------------------------------------------------------

func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "DirectVP"
	_viewport.size = Vector2i(VP_SIZE)
	_viewport.transparent_bg = true
	_viewport.handle_input_locally = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.own_world_3d = true
	_viewport.gui_disable_input = false

	# Native 300×300 Direct Control, shown @2× via Control.scale (not stretch).
	# stretch=true would resize the SubViewport to the field and break VP_SIZE.
	_vp_box = SubViewportContainer.new()
	_vp_box.name = "DemoView"
	_vp_box.position = FIELD_POS
	_vp_box.size = VP_SIZE
	_vp_box.stretch = false
	_vp_box.scale = FIELD / VP_SIZE
	_vp_box.visible = false
	_vp_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vp_box.add_child(_viewport)

	var stage_host := Control.new()
	stage_host.name = "StageHost"
	stage_host.size = STAGE
	stage_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_host.add_child(_vp_box)
	add_child(stage_host)

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

	var left_top := _panel(Rect2(16, 18, 150, 64))
	_hud.add_child(left_top)
	left_top.add_child(_label("BULLET", 18, GOLD, Vector2(12, 8)))
	left_top.add_child(_label("DEMO", 16, FRAME, Vector2(12, 34)))

	var left := _panel(Rect2(16, 96, 150, 280))
	_hud.add_child(left)
	left.add_child(_label("LIVE", 11, MUTED, Vector2(12, 10)))
	_shots_label = _label("shots  0", 14, GOLD, Vector2(12, 36))
	left.add_child(_shots_label)
	_hits_label = _label("hits  0", 14, HOT, Vector2(12, 64))
	left.add_child(_hits_label)
	_fizz_label = _label("misses  0", 14, MUTED, Vector2(12, 92))
	left.add_child(_fizz_label)
	_squares_label = _label("squares  9 / 9", 14, INK, Vector2(12, 128))
	left.add_child(_squares_label)
	_rack_label = _label("ammo  3 / 3", 14, GREEN, Vector2(12, 156))
	left.add_child(_rack_label)
	left.add_child(_label(
		"Same Direct\nbullet_logic.\nSpent bullets\nreturn to the\nrack.",
		11, MUTED, Vector2(12, 200)))

	var right := _panel(Rect2(1114, 96, 150, 200))
	_hud.add_child(right)
	right.add_child(_label("CONTROLS", 11, MUTED, Vector2(12, 10)))
	right.add_child(_label(
		"Click  fire\nfrom mouse x\n\n3 bullets\nEsc  pause",
		12, INK, Vector2(12, 36)))

	var bottom := _panel(Rect2(340, 672, 600, 36))
	_hud.add_child(bottom)
	_hint_label = _label("click anywhere on the field to fire from mouse x", 13, MUTED, Vector2(16, 8))
	bottom.add_child(_hint_label)

	var back := _btn("Back to Arcade", Vector2(1114, 18), Vector2(150, 36))
	back.pressed.connect(GameRegistry.return_to_arcade)
	_hud.add_child(back)

	# Title card
	var card := _panel(Rect2(STAGE.x * 0.5 - 310, STAGE.y * 0.5 - 170, 620, 340))
	card.name = "TitleCard"
	_ui.add_child(card)
	_cards["title"] = card
	card.add_child(_label("BULLET DEMO", 32, GOLD, Vector2(36, 28)))
	card.add_child(_label("Enhanced edition", 16, FRAME, Vector2(36, 76)))
	card.add_child(_label(
		"The Direct GameSketchLib BulletDemo, framed with chrome:\nclick still fires from mouse x through Direct bullet_logic,\nthree bullets, dead squares turn gray - Enhanced only\nadds trails, hit bursts, an aim guide and the HUD.",
		14, INK, Vector2(36, 110)))
	var start := _btn("Start", Vector2(36, 224), Vector2(120, 40))
	start.pressed.connect(func(): _set_state(PLAY))
	card.add_child(start)
	card.add_child(_label("Enter / Space  to begin", 14, MUTED, Vector2(180, 234)))
	var title_back := _btn("Back to Arcade", Vector2(36, 282), Vector2(160, 34))
	title_back.pressed.connect(GameRegistry.return_to_arcade)
	card.add_child(title_back)
	card.add_child(_label("# # #", 20, Color(GOLD, 0.7), Vector2(480, 288)))


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
		var base := Color(0.12, 0.22, 0.42)
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
