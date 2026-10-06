extends Node2D
## Overlap Demo (Enhanced). Presentation makeover of the Direct GameSketchLib
## course w02 OverlapDemo port. The demo is Direct `game.tscn` (shared
## `overlap_logic.gd`), instanced in a native 300×300 SubViewport and shown @2×
## (stretch=false + Control.scale) — no rules copied. Enhanced owns the
## 1280×720 letterbox chrome, HUD, title card and juice derived from watching
## Direct square colours / in_hand / positions: overlap-zone highlights,
## grab/drop rings, overlap/clear bursts, lost-square edge arrows. Esc →
## PauseOverlay. No Alchementrix IP. No new mechanics.

const DIRECT := preload("res://games/overlap_demo/direct/game.tscn")
const Logic := preload("res://games/overlap_demo/direct/overlap_logic.gd")

const STAGE := Vector2(1280, 720)
## Direct sketch is 300×300; the SubViewport stays native and the container scales it 2×.
const VP_SIZE := Vector2(Logic.W, Logic.H)
const PX := 2.0
const FIELD := VP_SIZE * PX  ## 600×600
const FIELD_POS := Vector2((STAGE.x - FIELD.x) * 0.5, (STAGE.y - FIELD.y) * 0.5)

const BG_TOP := Color(0.03, 0.05, 0.13)
const BG_BOT := Color(0.07, 0.05, 0.14)
const PANEL := Color(0.06, 0.09, 0.19, 0.94)
const FRAME := Color(0.45, 0.66, 1.0)  ## echoes Direct's #3366FF canvas
const INK := Color(0.93, 0.96, 1.0)
const MUTED := Color(0.58, 0.64, 0.82)
const GOLD := Color(1.0, 0.84, 0.32)
const HOT := Color(1.0, 0.45, 0.32)
const GREEN := Color(0.42, 0.95, 0.58)
const STEEL := Color(0.72, 0.76, 0.86)

enum { TITLE, PLAY }

var state := TITLE
var direct: Control = null  ## Direct game.tscn root (owns `world`)

## View-only presentation state (derived from Direct square state).
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _banner := ""
var _banner_t := 0.0
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _rings: Array[Dictionary] = []

var _prev_gray: Array[bool] = []
var _prev_on_canvas: Array[bool] = []
var _prev_held := -1

var _gray_count := 0
var _pair_count := 0
var _max_gray := 0
var _grabs := 0
var _overlap_events := 0
var _clear_events := 0
var _lost_count := 0
var _first_overlap := false

var _stage_host: Control
var _vp_box: SubViewportContainer
var _viewport: SubViewport
var _fx: Node2D  ## juice above the Direct SubViewport
var _ui: CanvasLayer
var _hud: Control
var _cards := {}
var _state_label: Label
var _gray_label: Label
var _pairs_label: Label
var _held_label: Label
var _mouse_label: Label
var _grabs_label: Label
var _events_label: Label
var _lost_label: Label
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
	_load_direct()
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
	# Direct is frozen (no step, no input) behind the title card.
	if direct != null:
		direct.process_mode = Node.PROCESS_MODE_INHERIT if s == PLAY else Node.PROCESS_MODE_DISABLED
	if s == PLAY:
		_banner = "DRAG THE SQUARES"
		_banner_t = 1.8
		_flash = 0.4
		_flash_color = FRAME
		_burst(FIELD_POS + FIELD * 0.5, GOLD, 18, 220.0)


func start() -> void:
	_set_state(PLAY)


func _load_direct() -> void:
	direct = DIRECT.instantiate() as Control
	direct.set_anchors_preset(Control.PRESET_FULL_RECT)
	direct.offset_left = 0
	direct.offset_top = 0
	direct.offset_right = 0
	direct.offset_bottom = 0
	_viewport.add_child(direct)
	# Direct's margin hint would sit on the sketch at native 300×300; Enhanced has its own HUD.
	var help := direct.get_node_or_null("Help") as CanvasItem
	if help:
		help.visible = false
	_snapshot()
	_refresh_hud()


func _restart() -> void:
	_particles.clear()
	_floaters.clear()
	_rings.clear()
	_gray_count = 0
	_pair_count = 0
	_max_gray = 0
	_grabs = 0
	_overlap_events = 0
	_clear_events = 0
	_lost_count = 0
	_first_overlap = false
	if direct != null:
		direct.queue_free()
		direct = null
	_load_direct()
	_set_state(PLAY)


# --- input ------------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if state == TITLE:
		if k.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			start()
			get_viewport().set_input_as_handled()
		return
	if k.keycode == KEY_R:
		_restart()
		get_viewport().set_input_as_handled()


# --- loop / observer (read-only over Direct state) ---------------------------------

func _process(delta: float) -> void:
	_time += delta
	_animate(delta)
	if state == PLAY and direct != null:
		_observe()
	_refresh_hud()
	queue_redraw()
	if _fx:
		_fx.queue_redraw()


func _world():
	return direct.world if direct != null else null


func _snapshot() -> void:
	_prev_gray.clear()
	_prev_on_canvas.clear()
	var w = _world()
	if w == null:
		return
	for sq in w.squares:
		_prev_gray.append(sq.fill_color == Logic.GRAY)
		_prev_on_canvas.append(_on_canvas(sq))
	_prev_held = w.squares.find(w.in_hand) if w.in_hand != null else -1


func _on_canvas(sq) -> bool:
	return Rect2(sq.x, sq.y, sq.w, sq.h).intersects(Rect2(Vector2.ZERO, VP_SIZE))


func _sq_rect(sq) -> Rect2:
	return Rect2(sq.x, sq.y, sq.w, sq.h)


## Sketch → stage coordinates (the field origin plus 2×).
func sketch_to_stage(p: Vector2) -> Vector2:
	return FIELD_POS + p * PX


func _observe() -> void:
	var w = _world()
	if w == null:
		return
	var n: int = w.squares.size()
	while _prev_gray.size() < n:
		_prev_gray.append(false)
		_prev_on_canvas.append(true)
	var grays := 0
	var lost := 0
	for i in n:
		var sq = w.squares[i]
		var gray: bool = sq.fill_color == Logic.GRAY
		var c := sketch_to_stage(_sq_rect(sq).get_center())
		if gray:
			grays += 1
		if gray and not _prev_gray[i]:
			_overlap_events += 1
			_burst(c, HOT, 10, 160.0)
			_rings.append({"pos": c, "life": 0.4, "max": 0.4, "col": HOT, "r": 40.0})
			_floater("OVERLAP", c + Vector2(-30, -40), HOT)
			_shake = maxf(_shake, 0.25)
		elif not gray and _prev_gray[i]:
			_clear_events += 1
			_burst(c, GREEN, 6, 110.0)
			_floater("clear", c + Vector2(-16, -40), GREEN)
		_prev_gray[i] = gray
		var on := _on_canvas(sq)
		if not on:
			lost += 1
			if _prev_on_canvas[i]:
				var edge := _edge_point(_sq_rect(sq).get_center())
				_burst(edge, STEEL, 10, 140.0)
				_floater("LOST", edge + Vector2(-18, -18), STEEL)
		_prev_on_canvas[i] = on
	_gray_count = grays
	_lost_count = lost
	_max_gray = maxi(_max_gray, grays)
	_pair_count = _overlap_pairs().size()
	if grays > 0 and not _first_overlap:
		_first_overlap = true
		_banner = "OVERLAP!"
		_banner_t = 1.4
		_flash = maxf(_flash, 0.35)
		_flash_color = HOT
		_shake = maxf(_shake, 0.4)
	var held: int = w.squares.find(w.in_hand) if w.in_hand != null else -1
	if held != _prev_held:
		if held >= 0:
			_grabs += 1
			var gc := sketch_to_stage(_sq_rect(w.squares[held]).get_center())
			_rings.append({"pos": gc, "life": 0.35, "max": 0.35, "col": GOLD, "r": 34.0})
			_burst(gc, GOLD, 8, 120.0)
		elif _prev_held >= 0 and _prev_held < n:
			var dc := sketch_to_stage(_sq_rect(w.squares[_prev_held]).get_center())
			_rings.append({"pos": dc, "life": 0.3, "max": 0.3, "col": FRAME, "r": 28.0})
			_burst(dc + Vector2(0, 25), Color(0.8, 0.88, 1.0, 0.8), 6, 80.0)
		_prev_held = held


## Pairs of squares whose rects intersect (strict, like Direct) — drawing only.
## Gray counts in the HUD come from Direct's own fill colours.
func _overlap_pairs() -> Array:
	var out: Array = []
	var w = _world()
	if w == null:
		return out
	for i in w.squares.size():
		for j in range(i + 1, w.squares.size()):
			var a := _sq_rect(w.squares[i])
			var b := _sq_rect(w.squares[j])
			if a.intersects(b):
				out.append([i, j, a.intersection(b)])
	return out


## Clamp a sketch point to the field border in stage coords (for lost-square arrows).
func _edge_point(p: Vector2) -> Vector2:
	var cp := Vector2(clampf(p.x, 6.0, VP_SIZE.x - 6.0), clampf(p.y, 6.0, VP_SIZE.y - 6.0))
	return sketch_to_stage(cp)


func mouse_sketch() -> Vector2:
	return ((get_local_mouse_position() - FIELD_POS) / PX).floor()


func _animate(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 2.6)
	_flash = maxf(0.0, _flash - delta * 2.0)
	_banner_t = maxf(0.0, _banner_t - delta)
	for p in _particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.94
	_particles = _particles.filter(func(p): return p.life > 0.0)
	for f in _floaters:
		f.life -= delta
		f.pos.y -= 26.0 * delta
	_floaters = _floaters.filter(func(f): return f.life > 0.0)
	for r in _rings:
		r.life -= delta
	_rings = _rings.filter(func(r): return r.life > 0.0)


func _burst(at: Vector2, col: Color, n: int, speed: float) -> void:
	for i in n:
		var a := randf() * TAU
		_particles.append({
			"pos": at,
			"vel": Vector2(cos(a), sin(a)) * randf_range(0.3, 1.0) * speed,
			"r": randf_range(1.5, 3.5),
			"life": randf_range(0.3, 0.6),
			"max": 0.6,
			"col": col,
		})


func _floater(text: String, at: Vector2, col: Color) -> void:
	_floaters.append({"text": text, "pos": at, "life": 0.9, "max": 0.9, "col": col, "size": 16})


# --- drawing --------------------------------------------------------------------

## Backdrop + frame (below the SubViewport).
func _draw() -> void:
	for i in 24:
		var t := float(i) / 24.0
		draw_rect(Rect2(0, STAGE.y * t, STAGE.x, STAGE.y / 24.0 + 1.0), BG_TOP.lerp(BG_BOT, t))
	draw_circle(Vector2(140, 110), 170, Color(0.2, 0.4, 1.0, 0.07))
	draw_circle(Vector2(STAGE.x - 120, STAGE.y - 90), 200, Color(1.0, 0.5, 0.3, 0.05))
	for i in 40:
		var seed := float(i * 73 + 11)
		var p := Vector2(fmod(seed * 37.0, STAGE.x), fmod(seed * 53.0, STAGE.y))
		var a := 0.1 + 0.2 * (0.5 + 0.5 * sin(_time * 1.6 + seed))
		draw_circle(p, 1.2, Color(0.75, 0.85, 1.0, a))
	# Shake only the frame chrome: the SubViewport (and Fx aligned to it) stays put so the
	# window → sketch mouse mapping is exactly Direct's, even mid-juice.
	var off := Vector2.ZERO
	if _shake > 0.0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 8.0 * _shake * _shake
	var fr := Rect2(FIELD_POS - Vector2(12, 12) + off, FIELD + Vector2(24, 24))
	draw_rect(Rect2(fr.position + Vector2(8, 10), fr.size), Color(0, 0, 0, 0.35))
	draw_rect(fr, Color(0.05, 0.07, 0.14))
	draw_rect(fr.grow(-4), Color(FRAME, 0.55), false, 2.0)
	var corner := Color(GOLD, 0.75)
	for c in [fr.position, Vector2(fr.end.x - 30, fr.position.y), Vector2(fr.position.x, fr.end.y - 3), fr.end - Vector2(30, 3)]:
		draw_rect(Rect2(c, Vector2(30, 3)), corner)
	for c in [fr.position, Vector2(fr.end.x - 3, fr.position.y), Vector2(fr.position.x, fr.end.y - 30), fr.end - Vector2(3, 30)]:
		draw_rect(Rect2(c, Vector2(3, 30)), corner)


## Overlay above the Direct SubViewport (Fx is added after StageHost).
func _draw_fx() -> void:
	var w = _world()
	if w != null and state == PLAY:
		_draw_squares_fx(w)
	for r in _rings:
		var t: float = 1.0 - r.life / r.max
		var col: Color = r.col
		col.a = 0.8 * (1.0 - t)
		_fx.draw_arc(r.pos, r.r * (0.5 + t), 0.0, TAU, 32, col, 3.0)
	for p in _particles:
		var col2: Color = p.col
		col2.a *= clampf(p.life / p.max, 0.0, 1.0)
		_fx.draw_circle(p.pos, p.r, col2)
	for f in _floaters:
		var col3: Color = f.col
		col3.a *= clampf(f.life / f.max, 0.0, 1.0)
		_fx.draw_string(_font, f.pos + Vector2(1, 1), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(f.size), Color(0, 0, 0, col3.a * 0.7))
		_fx.draw_string(_font, f.pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(f.size), col3)
	if _flash > 0.0:
		var fc := _flash_color
		fc.a = _flash * 0.22
		_fx.draw_rect(Rect2(FIELD_POS, FIELD), fc)
	if _banner_t > 0.0 and _banner != "":
		var a := clampf(_banner_t, 0.0, 1.0)
		var r := Rect2(FIELD_POS.x + FIELD.x * 0.5 - 170, FIELD_POS.y + 18, 340, 40)
		_fx.draw_rect(r, Color(0.03, 0.04, 0.10, 0.8 * a))
		_fx.draw_rect(r, Color(GOLD, 0.6 * a), false, 2.0)
		_fx.draw_string(_font, Vector2(r.position.x, r.position.y + 28), _banner,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, Color(GOLD, a))


func _draw_squares_fx(w) -> void:
	var field := Rect2(FIELD_POS, FIELD)
	# Overlap zones: the intersection of each overlapping pair, hatched.
	for pr in _overlap_pairs():
		var zr := Rect2(sketch_to_stage(pr[2].position), pr[2].size * PX)
		var pulse := 0.5 + 0.5 * sin(_time * 8.0)
		_fx.draw_rect(zr, Color(HOT, 0.35 + 0.2 * pulse))
		var step := 6.0
		var k := 0.0
		while k < zr.size.x + zr.size.y:
			var a := zr.position + Vector2(minf(k, zr.size.x), maxf(0.0, k - zr.size.x))
			var b := zr.position + Vector2(maxf(0.0, k - zr.size.y), minf(k, zr.size.y))
			_fx.draw_line(a, b, Color(1, 0.9, 0.8, 0.55), 1.0)
			k += step
	var held = w.in_hand
	for i in w.squares.size():
		var sq = w.squares[i]
		var sr := Rect2(sketch_to_stage(Vector2(sq.x, sq.y)), Vector2(sq.w, sq.h) * PX)
		if not field.intersects(sr):
			continue
		if sq.fill_color == Logic.GRAY:
			var pulse2 := 0.5 + 0.5 * sin(_time * 6.0 + i)
			_fx.draw_rect(sr.grow(3.0 + 2.0 * pulse2), Color(HOT, 0.55 + 0.3 * pulse2), false, 2.0)
		else:
			_fx.draw_rect(sr.grow(3.0), Color(1, 1, 1, 0.18), false, 2.0)
		if sq == held:
			var g := 0.5 + 0.5 * sin(_time * 10.0)
			_fx.draw_rect(sr.grow(7.0 + 2.0 * g), Color(GOLD, 0.85), false, 3.0)
			# Alignment guides from the held square to the field edges.
			var cy := sr.get_center().y
			var cx := sr.get_center().x
			var gc := Color(GOLD, 0.22)
			_fx.draw_line(Vector2(field.position.x, cy), Vector2(field.end.x, cy), gc, 1.0)
			_fx.draw_line(Vector2(cx, field.position.y), Vector2(cx, field.end.y), gc, 1.0)
			_fx.draw_string(_font, sr.position + Vector2(0, -12), "#%d" % i,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOLD)
	# Hover hint: the square a press would grab (Direct grabs the lowest index under the mouse).
	if held == null:
		var m := mouse_sketch() + Vector2(0.5, 0.5)
		for i in w.squares.size():
			var sq = w.squares[i]
			if _sq_rect(sq).grow(0.5).has_point(m):
				var hr := Rect2(sketch_to_stage(Vector2(sq.x, sq.y)), Vector2(sq.w, sq.h) * PX)
				_fx.draw_rect(hr.grow(6.0), Color(GREEN, 0.75), false, 2.0)
				break
	# Lost squares: arrows on the field edge pointing at off-canvas squares.
	for sq in w.squares:
		if _on_canvas(sq):
			continue
		var c: Vector2 = _sq_rect(sq).get_center()
		var e := _edge_point(c)
		var dir := (sketch_to_stage(c) - e).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		var bob := 0.5 + 0.5 * sin(_time * 5.0)
		var tip := e + dir * (4.0 + 3.0 * bob)
		var side := dir.orthogonal() * 10.0
		var tri := PackedVector2Array([tip, tip - dir * 20.0 + side, tip - dir * 20.0 - side])
		_fx.draw_colored_polygon(tri, Color(0.9, 0.94, 1.0, 0.7 + 0.3 * bob))
		tri.append(tip)
		_fx.draw_polyline(tri, Color(0.02, 0.04, 0.12, 0.8), 1.5)


# --- HUD ------------------------------------------------------------------------

func _refresh_hud() -> void:
	if _state_label == null:
		return
	var w = _world()
	_state_label.text = "DRAGGING" if (w != null and w.in_hand != null) else "LIVE"
	_gray_label.text = "GRAY  %d / %d" % [_gray_count, Logic.K_SQUARE_COUNT]
	_gray_label.add_theme_color_override("font_color", HOT if _gray_count > 0 else INK)
	_pairs_label.text = "overlap zones  %d" % _pair_count
	if w != null and w.in_hand != null:
		var i: int = w.squares.find(w.in_hand)
		_held_label.text = "held  #%d @ (%d, %d)" % [i, int(w.in_hand.x), int(w.in_hand.y)]
		_held_label.add_theme_color_override("font_color", GOLD)
	else:
		_held_label.text = "held  —"
		_held_label.add_theme_color_override("font_color", MUTED)
	var m := mouse_sketch()
	_mouse_label.text = "mouse  (%d, %d)" % [int(m.x), int(m.y)]
	_grabs_label.text = "grabs  %d" % _grabs
	_events_label.text = "overlaps  %d   peak gray  %d" % [_overlap_events, _max_gray]
	_lost_label.text = "off canvas  %d" % _lost_count
	_lost_label.add_theme_color_override("font_color", STEEL if _lost_count > 0 else MUTED)


# --- build ------------------------------------------------------------------------

func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "DirectVP"
	_viewport.size = Vector2i(VP_SIZE)
	_viewport.transparent_bg = false
	_viewport.handle_input_locally = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true

	# Native 300×300 Direct sketch shown at 2× via Control.scale (not stretch):
	# stretch=true would resize the SubViewport to the field and break VP_SIZE / juice math.
	_vp_box = SubViewportContainer.new()
	_vp_box.name = "DemoView"
	_vp_box.position = FIELD_POS
	_vp_box.size = VP_SIZE
	_vp_box.stretch = false
	_vp_box.scale = Vector2(PX, PX)
	_vp_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  ## crisp 2× Processing pixels
	_vp_box.add_child(_viewport)

	_stage_host = Control.new()
	_stage_host.name = "StageHost"
	_stage_host.size = STAGE
	_stage_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage_host)
	_stage_host.add_child(_vp_box)

	# Juice above Direct's opaque blue canvas.
	_fx = Node2D.new()
	_fx.name = "Fx"
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "UI"
	_ui.layer = 10
	add_child(_ui)

	_hud = Control.new()
	_hud.name = "Hud"
	_hud.size = STAGE
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_hud)

	var left := _panel(Rect2(24, 60, 280, 600))
	_hud.add_child(left)
	left.add_child(_label("OVERLAP DEMO", 26, GOLD, Vector2(16, 14), Vector2(248, 36)))
	left.add_child(_label("Enhanced · GameSketchLib w02", 13, MUTED, Vector2(16, 50), Vector2(248, 20)))
	var hint := _label(
		"Drag the nine squares.\nAny square touching another\n(more than edge-to-edge)\nturns gray.\n\nGrabbing a stack takes the\nlowest-numbered square,\neven if one is drawn on top.\nSquares can be dragged off\nthe canvas and lost.",
		15, INK, Vector2(16, 88), Vector2(248, 260))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(hint)
	left.add_child(_label("CONTROLS", 12, MUTED, Vector2(16, 380), Vector2(248, 18)))
	left.add_child(_label("Mouse  drag squares\nR  reset the demo\nEsc  pause", 15, INK, Vector2(16, 402), Vector2(248, 70)))
	var back := _button("Back to Arcade", Color(0.22, 0.30, 0.58), 17)
	back.position = Vector2(16, 532)
	back.size = Vector2(248, 44)
	back.pressed.connect(GameRegistry.return_to_arcade)
	left.add_child(back)

	var right := _panel(Rect2(STAGE.x - 304, 60, 280, 600))
	_hud.add_child(right)
	_state_label = _label("LIVE", 22, GOLD, Vector2(16, 14), Vector2(248, 30))
	right.add_child(_state_label)
	_gray_label = _label("GRAY  0 / 9", 20, INK, Vector2(16, 54), Vector2(248, 28))
	right.add_child(_gray_label)
	_pairs_label = _label("overlap zones  0", 16, INK, Vector2(16, 92), Vector2(248, 24))
	right.add_child(_pairs_label)
	_held_label = _label("held  —", 16, MUTED, Vector2(16, 124), Vector2(248, 24))
	right.add_child(_held_label)
	_mouse_label = _label("mouse  (0, 0)", 15, MUTED, Vector2(16, 156), Vector2(248, 24))
	right.add_child(_mouse_label)
	_grabs_label = _label("grabs  0", 15, INK, Vector2(16, 196), Vector2(248, 22))
	right.add_child(_grabs_label)
	_events_label = _label("overlaps  0   peak gray  0", 15, HOT, Vector2(16, 222), Vector2(248, 22))
	right.add_child(_events_label)
	_lost_label = _label("off canvas  0", 15, MUTED, Vector2(16, 248), Vector2(248, 22))
	right.add_child(_lost_label)
	right.add_child(_label("LEGEND", 12, MUTED, Vector2(16, 300), Vector2(248, 18)))
	right.add_child(_label("white   free\ngray    overlapping\nred     overlap zone\ngold    held square\ngreen   grab target\narrow   lost off canvas",
		14, INK, Vector2(16, 322), Vector2(248, 130)))
	var tip := _label("View-only HUD over the same\nDirect overlap_logic.gd:\nn² overlap scan, strict <,\n60 Hz step.", 13, MUTED, Vector2(16, 500), Vector2(248, 80))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(tip)

	_cards["title"] = _make_title_card()


func _make_title_card() -> Control:
	var wrap := Control.new()
	wrap.name = "TitleCard"
	wrap.position = Vector2.ZERO
	wrap.size = STAGE
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP  ## blocks the field until Start
	_ui.add_child(wrap)
	var dim := ColorRect.new()
	dim.size = STAGE
	dim.color = Color(0.02, 0.03, 0.08, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(dim)
	var box := _panel(Rect2((STAGE.x - 480) * 0.5, (STAGE.y - 380) * 0.5, 480, 380))
	wrap.add_child(box)
	var h := _label("OVERLAP DEMO", 30, GOLD, Vector2(20, 22), Vector2(440, 40))
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(h)
	var sub := _label("Enhanced edition · GameSketchLib w02 (2011)", 14, FRAME, Vector2(20, 64), Vector2(440, 22))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var body := _label(
		"The first step of the InvaderSketch tutorial: collision boxes.\nDrag the nine squares around; any square that overlaps\nanother turns gray. Same Direct sketch, now with\noverlap zones, grab rings and a live HUD.",
		14, INK, Vector2(20, 100), Vector2(440, 120))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	var start_btn := _button("Start", Color(0.18, 0.55, 0.42), 18)
	start_btn.position = Vector2(150, 236)
	start_btn.size = Vector2(180, 44)
	start_btn.pressed.connect(start)
	box.add_child(start_btn)
	var keys := _label("or Space / Enter", 12, MUTED, Vector2(20, 284), Vector2(440, 18))
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(keys)
	var back := _button("Back to Arcade", Color(0.22, 0.30, 0.58), 15)
	back.position = Vector2(150, 316)
	back.size = Vector2(180, 38)
	back.pressed.connect(GameRegistry.return_to_arcade)
	box.add_child(back)
	return wrap


func _panel(r: Rect2) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.add_theme_stylebox_override("panel", _panel_style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(text: String, size: int, col: Color, pos: Vector2, box: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = box
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
