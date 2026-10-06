extends Node2D
## GameSketchLib Demo (Enhanced). Visual/UI makeover of the Direct GameSketchLib
## course w02 GameSketchLibDemo port (BulletDemo on the flixel-style mini lib).
## Simulation is Direct gsl_demo_logic.gd (preloaded, not copied): click-to-start
## menu, 3 bullets fired with firstDead(), overlap-before-move, dead squares that
## still soak up bullets, clear-the-board → back to the menu. Enhanced paints
## Direct's render list in a 1280×720 letterbox shell and derives juice from
## state deltas: muzzle flash, bullet glow + trails, hit bursts, soak pings,
## top-edge fizzles, aim guide, side HUD, title card, Back to Arcade.
## Esc is handled by the PauseOverlay autoload. No Alchementrix IP.

const Logic := preload("res://games/gamesketchlib_demo/direct/gsl_demo_logic.gd")

const STAGE := Vector2(1280, 720)
const PX := 2.0  ## 300×300 → 600×600 field
const FIELD := Vector2(Logic.W, Logic.H) * PX
const FIELD_POS := Vector2((STAGE.x - FIELD.x) * 0.5, (STAGE.y - FIELD.y) * 0.5)
const STEP_SEC := 1.0 / Logic.FPS
const TRAIL_LEN := 10

const BG_TOP := Color(0.03, 0.05, 0.12)
const BG_BOTTOM := Color(0.06, 0.04, 0.12)
const PANEL := Color(0.06, 0.09, 0.19, 0.94)
const FRAME := Color(0.45, 0.70, 1.0)
const INK := Color(0.93, 0.96, 1.0)
const MUTED := Color(0.58, 0.64, 0.82)
const GOLD := Color(1.0, 0.84, 0.32)
const HOT := Color(1.0, 0.48, 0.28)
const GREEN := Color(0.42, 0.95, 0.58)
const STEEL := Color(0.72, 0.76, 0.86)

var world = Logic.new()
var playing := false  ## false while the Enhanced title card is up
var _acc := 0.0
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _trails: Array = []  ## per bullet index: Array[Vector2] of recent sketch positions

var _steps := 0
var _shots := 0
var _hits := 0
var _soaks := 0
var _fizzles := 0
var _dry_clicks := 0
var _clears := 0
var _starts := 0

## Previous-frame snapshot of Direct state (for deltas).
var _prev_state := 0
var _prev_sq_alive: Array[bool] = []
var _prev_bullets: Array[Dictionary] = []

var _field: Control
var _ui: CanvasLayer
var _cards := {}
var _state_label: Label
var _shots_label: Label
var _hits_label: Label
var _soak_label: Label
var _fizz_label: Label
var _squares_label: Label
var _rack_label: Label
var _clears_label: Label
var _font: Font
var _panel_style := StyleBoxFlat.new()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_panel_style.bg_color = PANEL
	_panel_style.border_color = Color(FRAME, 0.45)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(14)
	world = Logic.new()
	_snap_prev()
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


# --- Direct I/O (tests call these for parity) -----------------------------------

## Forward a Processing mousePressed at sketch coords, then read the deltas.
func press(sx: int, sy: int) -> void:
	world.mouse_pressed(sx, sy)
	_observe(true)


func release(sx: int, sy: int) -> void:
	world.mouse_released(sx, sy)


func drag(sx: int, sy: int) -> void:
	world.mouse_dragged(sx, sy)


## One presentation step: apply events, then one Direct step().
## `events` is an Array of ["press"|"release"|"drag", x, y].
func tick(events: Array = []) -> void:
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


# --- Delta observer (read-only over Direct state) -------------------------------

func _snap_prev() -> void:
	_prev_state = world.state
	_prev_sq_alive.clear()
	for sq in world.squares:
		_prev_sq_alive.append(sq.alive)
	_prev_bullets.clear()
	for b in world.bullets:
		_prev_bullets.append({"alive": b.alive, "rect": Rect2(b.x, b.y, b.w, b.h)})
	while _trails.size() < world.bullets.size():
		_trails.append([])
	if _trails.size() > world.bullets.size():
		_trails.resize(world.bullets.size())


func _live_squares() -> int:
	var n := 0
	for sq in world.squares:
		if sq.alive:
			n += 1
	return n


func _ready_bullets() -> int:
	var n := 0
	for b in world.bullets:
		if not b.alive:
			n += 1
	return n


func _observe(from_click: bool) -> void:
	if world.state != _prev_state:
		if world.state == Logic.State.PLAY:
			_starts += 1
			_float_text("GO!", Vector2(130, 30), GOLD, 22)
			_flash = 0.35
			_flash_color = Color(0.5, 0.7, 1.0)
		else:
			# PlayState.update() switched back to the menu: the board was cleared.
			_clears += 1
			for sq_center in [Vector2(150, 150), Vector2(75, 75), Vector2(225, 225)]:
				_burst(sq_center, GOLD, 18, 2.6)
			_float_text("BOARD CLEAR!", Vector2(90, 140), GOLD, 22)
			_shake = maxf(_shake, 0.45)
			_flash = 0.6
			_flash_color = Color(1.0, 0.9, 0.5)
		for t in _trails:
			t.clear()
		_snap_prev()
		return
	if world.state != Logic.State.PLAY:
		_snap_prev()
		return
	var fired := false
	for i in world.bullets.size():
		var b = world.bullets[i]
		var was: Dictionary = _prev_bullets[i] if i < _prev_bullets.size() else {"alive": false, "rect": Rect2()}
		var trail: Array = _trails[i]
		if b.alive and not was.alive:
			fired = true
			_shots += 1
			trail.clear()
			var muzzle := Vector2(b.x + b.w * 0.5, b.y + b.h)
			_burst(muzzle, GOLD, 8, 1.4)
			_rings.append({"pos": muzzle, "life": 0.3, "max": 0.3, "col": GOLD, "r": 18.0})
		elif was.alive and not b.alive:
			trail.clear()
			_bullet_died(was.rect)
		if b.alive:
			trail.append(Vector2(b.x + b.w * 0.5, b.y + b.h * 0.5))
			while trail.size() > TRAIL_LEN:
				trail.pop_front()
	if from_click and not fired:
		_dry_clicks += 1
		_float_text("EMPTY", Vector2(clampf(_mouse_sketch().x, 8, Logic.W - 60), Logic.H - 56), MUTED, 14)
	for j in world.squares.size():
		var sq = world.squares[j]
		if j < _prev_sq_alive.size() and _prev_sq_alive[j] and not sq.alive:
			_hits += 1
			var c := Vector2(sq.x + sq.w * 0.5, sq.y + sq.h * 0.5)
			_burst(c, Color.WHITE, 16, 2.4)
			_burst(c, GOLD, 10, 1.8)
			_rings.append({"pos": c, "life": 0.45, "max": 0.45, "col": Color.WHITE, "r": 30.0})
			_float_text("HIT", c + Vector2(-12, -22), GOLD, 16)
			_shake = maxf(_shake, 0.3)
			_flash = maxf(_flash, 0.2)
			_flash_color = Color(1, 1, 1)
	_snap_prev()


## A bullet went from alive to dead this step. The overlap check runs on the
## pre-move position, so a square overlapping that rect means a collision; if
## that square was already dead, it soaked the shot (Direct quirk).
func _bullet_died(prev: Rect2) -> void:
	for j in world.squares.size():
		var sq = world.squares[j]
		var r := Rect2(sq.x, sq.y, sq.w, sq.h)
		if prev.intersects(r):
			var was_alive: bool = j < _prev_sq_alive.size() and _prev_sq_alive[j]
			if not was_alive:
				_soaks += 1
				var c := Vector2(sq.x + sq.w * 0.5, sq.y + sq.h)
				_burst(c, STEEL, 8, 1.2)
				_rings.append({"pos": c, "life": 0.35, "max": 0.35, "col": STEEL, "r": 20.0})
				_float_text("SOAK", c + Vector2(-16, 6), STEEL, 14)
			return
	_fizzles += 1
	var top := Vector2(prev.position.x + prev.size.x * 0.5, 2)
	_burst(top, HOT, 6, 1.0)


func _mouse_sketch() -> Vector2:
	if _field == null or not _field.is_inside_tree():
		return Vector2(-1, -1)
	return (_field.get_local_mouse_position() / PX).floor()


# --- Loop / input ---------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if playing:
		_acc = minf(_acc + delta, 0.25)
		while _acc >= STEP_SEC:
			_acc -= STEP_SEC
			world.step()
			_steps += 1
			_observe(false)
	_animate(delta)
	_refresh_hud()
	_field.queue_redraw()
	queue_redraw()


func _on_field_input(event: InputEvent) -> void:
	if not playing:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index <= MOUSE_BUTTON_MIDDLE:
		var p := (mb.position / PX).floor()
		if mb.pressed:
			press(int(p.x), int(p.y))
		else:
			release(int(p.x), int(p.y))
		_field.accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and mm.button_mask != 0:
		var p := (mm.position / PX).floor()
		drag(int(p.x), int(p.y))


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or k.echo:
		return
	if not playing and k.pressed and k.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		start()
		get_viewport().set_input_as_handled()


func _animate(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 2.4)
	_flash = maxf(0.0, _flash - delta * 1.8)
	for p in _particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.93
	_particles = _particles.filter(func(p): return p.life > 0.0)
	for f in _floaters:
		f.life -= delta
		f.pos += f.vel * delta
	_floaters = _floaters.filter(func(f): return f.life > 0.0)
	for r in _rings:
		r.life -= delta
	_rings = _rings.filter(func(r): return r.life > 0.0)
	if _field != null:
		var off := Vector2.ZERO
		if _shake > 0.0:
			off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 6.0
		_field.position = FIELD_POS + off


func _burst(at: Vector2, col: Color, n: int, speed: float) -> void:
	for i in n:
		var a := randf() * TAU
		_particles.append({
			"pos": at,
			"vel": Vector2(cos(a), sin(a)) * randf_range(20.0, 70.0) * speed,
			"r": randf_range(1.2, 3.0),
			"life": randf_range(0.25, 0.55),
			"max": 0.55,
			"col": col,
		})


func _float_text(text: String, at: Vector2, col: Color, size: int) -> void:
	_floaters.append({
		"text": text, "pos": at, "vel": Vector2(0, -28.0),
		"life": 0.9, "max": 0.9, "col": col, "size": size,
	})


# --- Drawing --------------------------------------------------------------------

func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(STAGE.x, 0), STAGE, Vector2(0, STAGE.y)]),
		PackedColorArray([BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM]))
	draw_rect(Rect2(0, 0, FIELD_POS.x - 10, STAGE.y), Color(0, 0, 0, 0.28))
	draw_rect(Rect2(FIELD_POS.x + FIELD.x + 10, 0, STAGE.x - (FIELD_POS.x + FIELD.x + 10), STAGE.y), Color(0, 0, 0, 0.28))
	var fr := Rect2(FIELD_POS - Vector2(6, 6), FIELD + Vector2(12, 12))
	draw_rect(fr, Color(FRAME, 0.35), false, 3.0)
	draw_rect(fr.grow(4.0), Color(FRAME, 0.12), false, 2.0)
	if _flash > 0.0:
		var fc := _flash_color
		fc.a = _flash * 0.35
		draw_rect(Rect2(Vector2.ZERO, STAGE), fc)


func _build_field() -> void:
	_field = Control.new()
	_field.name = "Field"
	_field.position = FIELD_POS
	_field.size = FIELD
	_field.clip_contents = true
	_field.mouse_filter = Control.MOUSE_FILTER_STOP
	_field.mouse_default_cursor_shape = Control.CURSOR_CROSS
	_field.draw.connect(_draw_field)
	_field.gui_input.connect(_on_field_input)
	add_child(_field)


func _s(p: Vector2) -> Vector2:
	return p * PX


func _sr(r: Rect2) -> Rect2:
	return Rect2(r.position * PX, r.size * PX)


## Paint Direct's render list (bg / rect / text) at 2×, with glow on top.
func _draw_field() -> void:
	var menu: bool = world.state == Logic.State.MENU
	for cmd in world.render():
		match cmd[0]:
			"bg":
				_field.draw_rect(Rect2(Vector2.ZERO, FIELD), cmd[1])
				if menu:
					_draw_menu_backdrop()
				else:
					_draw_play_backdrop()
			"rect":
				_draw_sketch_rect(cmd[1], cmd[2])
			"text":
				var pos := _s(cmd[2])
				var size := int(cmd[3] * PX)
				var a := 0.75 + 0.25 * sin(_time * 3.0)
				_field.draw_string(_font, pos + Vector2(2, 2), cmd[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.2, 0.4, 1.0, 0.5))
				var tc: Color = cmd[4]
				tc.a = a
				_field.draw_string(_font, pos, cmd[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, tc)
	if not menu:
		_draw_trails()
		_draw_aim()
	for r in _rings:
		var t: float = 1.0 - r.life / r.max
		var rc: Color = r.col
		rc.a = (1.0 - t) * 0.8
		_field.draw_arc(_s(r.pos), (6.0 + r.r * t) * PX * 0.5, 0, TAU, 28, rc, 2.5)
	for part in _particles:
		var a: float = clampf(part.life / maxf(part.max, 0.01), 0.0, 1.0)
		var pc: Color = part.col
		pc.a *= a
		_field.draw_circle(_s(part.pos), part.r * PX * 0.5, pc)
	for f in _floaters:
		var a: float = clampf(f.life / maxf(f.max, 0.01), 0.0, 1.0)
		var fc: Color = f.col
		fc.a = a
		_field.draw_string(_font, _s(f.pos) + Vector2(2, 2), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, f.size * 2, Color(0, 0, 0, 0.45 * a))
		_field.draw_string(_font, _s(f.pos), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, f.size * 2, fc)


func _draw_menu_backdrop() -> void:
	# Slow drifting specks on the black menu.
	for i in 40:
		var x := fmod(i * 73.0 + _time * (6.0 + i % 5), FIELD.x)
		var y := fmod(i * 131.0 + i * i * 7.0, FIELD.y)
		var tw := 0.25 + 0.25 * sin(_time * 2.0 + i)
		_field.draw_circle(Vector2(x, y), 1.4, Color(0.6, 0.75, 1.0, tw))


func _draw_play_backdrop() -> void:
	# Light-from-above wash + faint grid over Direct's #3366FF.
	var lit := Color(1, 1, 1, 0.12)
	var clear := Color(1, 1, 1, 0.0)
	_field.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(FIELD.x, 0), FIELD, Vector2(0, FIELD.y)]),
		PackedColorArray([lit, lit, clear, clear]))
	for i in 13:
		var g := FIELD.x * float(i) / 12.0
		_field.draw_line(Vector2(g, 0), Vector2(g, FIELD.y), Color(1, 1, 1, 0.05), 1.0)
		_field.draw_line(Vector2(0, g), Vector2(FIELD.x, g), Color(1, 1, 1, 0.05), 1.0)
	# Rack shelf along the bottom where Direct parks spent bullets.
	_field.draw_rect(Rect2(0, FIELD.y - Logic.K_BULLET_H * PX - 4, FIELD.x, 4), Color(0, 0, 0.2, 0.25))


func _draw_sketch_rect(r: Rect2, col: Color) -> void:
	var sr := _sr(r)
	if col == Logic.BULLET:
		var racked: bool = is_equal_approx(r.position.y, Logic.H - Logic.K_BULLET_H)
		var glow := 0.18 if racked else 0.4
		_field.draw_rect(sr.grow(6.0), Color(1.0, 0.8, 0.2, glow * 0.5))
		_field.draw_rect(sr.grow(3.0), Color(1.0, 0.8, 0.2, glow))
		_field.draw_rect(sr, col)
		_field.draw_rect(Rect2(sr.position + Vector2(3, 3), Vector2(sr.size.x * 0.35, sr.size.y - 6)), Color(1, 1, 0.9, 0.55))
	elif col == Logic.LIVE:
		var pulse := 0.5 + 0.5 * sin(_time * 4.0 + r.position.x * 0.05 + r.position.y * 0.03)
		_field.draw_rect(sr.grow(8.0 + 3.0 * pulse), Color(1, 1, 1, 0.08 + 0.06 * pulse))
		_field.draw_rect(sr.grow(3.0), Color(1, 1, 1, 0.22))
		_field.draw_rect(sr, col)
		_field.draw_rect(Rect2(sr.position, Vector2(sr.size.x, 8)), Color(0.85, 0.92, 1.0, 0.8))
	elif col == Logic.DEAD:
		_field.draw_rect(sr.grow(2.0), Color(0, 0, 0.1, 0.25))
		_field.draw_rect(sr, col)
		# Cracks: dead but still solid (it keeps soaking bullets).
		var c := Color(0.45, 0.48, 0.55, 0.9)
		_field.draw_line(sr.position + Vector2(6, 4), sr.get_center(), c, 2.0)
		_field.draw_line(sr.get_center(), sr.end - Vector2(8, 6), c, 2.0)
		_field.draw_line(sr.get_center(), Vector2(sr.end.x - 6, sr.position.y + 10), c, 1.5)
	else:
		_field.draw_rect(sr, col)
	# Processing's default 1 px black stroke, at 2×.
	_field.draw_rect(sr, Color.BLACK, false, 2.0)


func _draw_trails() -> void:
	for i in mini(_trails.size(), world.bullets.size()):
		var trail: Array = _trails[i]
		if not world.bullets[i].alive or trail.size() < 2:
			continue
		var w: float = world.bullets[i].w * PX
		for k in trail.size() - 1:
			var t := float(k + 1) / float(trail.size())
			var a: Vector2 = _s(trail[k])
			var b: Vector2 = _s(trail[k + 1])
			_field.draw_line(a, b, Color(1.0, 0.75, 0.2, 0.35 * t), w * (0.3 + 0.5 * t))


## Aim guide: where the next firstDead() bullet would launch (Direct fires at
## x = mouse x, y = H - 40), and which square it meets first. View-only.
func _draw_aim() -> void:
	var m := _mouse_sketch()
	if m.x < 0 or m.y < 0 or m.x >= Logic.W or m.y >= Logic.H or not playing:
		return
	var has_ammo := _ready_bullets() > 0
	var launch := Rect2(m.x, Logic.H - Logic.K_BULLET_H * 2, Logic.K_BULLET_W, Logic.K_BULLET_H)
	var col := Color(1.0, 0.85, 0.3, 0.5) if has_ammo else Color(0.7, 0.7, 0.8, 0.3)
	var cx := (m.x + Logic.K_BULLET_W * 0.5) * PX
	var target = null
	for sq in world.squares:
		if launch.position.x < sq.x + sq.w and launch.end.x > sq.x and sq.y < launch.position.y:
			if target == null or sq.y > target.y:
				target = sq
	var top_y: float = 0.0 if target == null else (target.y + target.h) * PX
	var y := launch.position.y * PX
	while y > top_y:
		_field.draw_line(Vector2(cx, y), Vector2(cx, maxf(top_y, y - 8.0)), col, 2.0)
		y -= 16.0
	_field.draw_rect(_sr(launch), col, false, 2.0)
	if target != null:
		var tr := _sr(Rect2(target.x, target.y, target.w, target.h)).grow(5.0)
		var tc := GREEN if target.alive else STEEL
		tc.a = 0.8
		_field.draw_rect(tr, tc, false, 2.5)
		if not target.alive:
			_field.draw_line(tr.position, tr.end, tc, 2.0)
			_field.draw_line(Vector2(tr.end.x, tr.position.y), Vector2(tr.position.x, tr.end.y), tc, 2.0)


# --- UI -------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	var left := _panel(Rect2(24, 60, 280, 560))
	_ui.add_child(left)
	var title := _label("GSL DEMO", 28, GOLD)
	title.position = Vector2(16, 14)
	title.size = Vector2(248, 36)
	left.add_child(title)
	var sub := _label("Enhanced | GameSketchLib w02", 13, MUTED)
	sub.position = Vector2(16, 48)
	sub.size = Vector2(248, 22)
	left.add_child(sub)
	var hint := _label(
		"Click the field: start /\nfire from mouse x\nEsc: pause\n\nBulletDemo rebuilt on the\nfirst GameSketchLib engine.\n3 bullets, 9 squares.\nGray squares are dead but\nstill solid: they soak up\nshots, so aim at live\ncolumns. Clear the board\nto return to the menu.",
		15, INK)
	hint.position = Vector2(16, 88)
	hint.size = Vector2(248, 380)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(hint)
	var back := _button("Back to Arcade", Color(0.22, 0.30, 0.58), 17)
	back.position = Vector2(16, 490)
	back.size = Vector2(248, 44)
	back.pressed.connect(GameRegistry.return_to_arcade)
	left.add_child(back)

	var right := _panel(Rect2(STAGE.x - 304, 60, 280, 560))
	_ui.add_child(right)
	_state_label = _label("MENU", 22, GOLD)
	_state_label.position = Vector2(16, 16)
	_state_label.size = Vector2(248, 30)
	right.add_child(_state_label)
	_rack_label = _label("RACK  # # #", 18, GOLD)
	_rack_label.position = Vector2(16, 56)
	_rack_label.size = Vector2(248, 26)
	right.add_child(_rack_label)
	_squares_label = _label("SQUARES  9 / 9 live", 16, INK)
	_squares_label.position = Vector2(16, 100)
	_squares_label.size = Vector2(248, 24)
	right.add_child(_squares_label)
	_shots_label = _label("shots  0", 16, INK)
	_shots_label.position = Vector2(16, 140)
	_shots_label.size = Vector2(248, 24)
	right.add_child(_shots_label)
	_hits_label = _label("hits  0", 16, GREEN)
	_hits_label.position = Vector2(16, 166)
	_hits_label.size = Vector2(248, 24)
	right.add_child(_hits_label)
	_soak_label = _label("soaked  0", 16, STEEL)
	_soak_label.position = Vector2(16, 192)
	_soak_label.size = Vector2(248, 24)
	right.add_child(_soak_label)
	_fizz_label = _label("missed  0", 16, HOT)
	_fizz_label.position = Vector2(16, 218)
	_fizz_label.size = Vector2(248, 24)
	right.add_child(_fizz_label)
	_clears_label = _label("boards cleared  0", 16, GOLD)
	_clears_label.position = Vector2(16, 258)
	_clears_label.size = Vector2(248, 24)
	right.add_child(_clears_label)
	var tip := _label("View-only HUD.\nAim guide shows where the\nnext bullet launches and\nthe square it meets first\n(green = live, gray X =\ndead, will soak). Same\nDirect quirks.", 13, MUTED)
	tip.position = Vector2(16, 380)
	tip.size = Vector2(248, 160)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(tip)
	_cards["title"] = _make_card(
		"GAMESKETCHLIB DEMO",
		"BulletDemo on the first cut of the\nGameSketchLib engine (week 2).\n\nClick the field to start, then click\nto fire from the mouse x.\nDead squares still soak up bullets.",
		true)


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
	var box := _panel(Rect2((FIELD.x - 420) * 0.5, (FIELD.y - 330) * 0.5, 420, 330))
	wrap.add_child(box)
	var h := _label(heading, 26, GOLD)
	h.position = Vector2(20, 20)
	h.size = Vector2(380, 40)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(h)
	var b := _label(body, 15, INK)
	b.name = "Body"
	b.position = Vector2(20, 68)
	b.size = Vector2(380, 170)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(b)
	if with_start:
		var start_btn := _button("Start", Color(0.18, 0.55, 0.42), 18)
		start_btn.position = Vector2(120, 252)
		start_btn.size = Vector2(180, 44)
		start_btn.pressed.connect(start)
		box.add_child(start_btn)
		var keys := _label("or Space / Enter", 12, MUTED)
		keys.position = Vector2(20, 298)
		keys.size = Vector2(380, 18)
		keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(keys)
	return wrap


func _show_card(key: String) -> void:
	for k in _cards.keys():
		_cards[k].visible = (k == key)


func _refresh_hud() -> void:
	var in_play: bool = world.state == Logic.State.PLAY
	_state_label.text = "PLAY" if in_play else "MENU | click to start"
	var rack := ""
	if in_play:
		var n := _ready_bullets()
		for i in world.bullets.size():
			rack += ("# " if i < n else ". ")
	else:
		rack = "-"
	_rack_label.text = "RACK  %s" % rack.strip_edges()
	_squares_label.text = ("SQUARES  %d / 9 live" % _live_squares()) if in_play else "SQUARES  -"
	_shots_label.text = "shots  %d" % _shots
	_hits_label.text = "hits  %d" % _hits
	_soak_label.text = "soaked  %d" % _soaks
	_fizz_label.text = "missed  %d" % _fizzles
	_clears_label.text = "boards cleared  %d" % _clears
