extends Node2D
## Fnarbmlyx Binary Tree (Enhanced). Presentation makeover of the Direct depth-5 tree sketch.
## The tree itself is Direct `binary_tree.tscn` (shared `binary_tree.gd`, verbatim `_draw()`),
## instanced in its native 1920×1080 SubViewport — nothing about the drawing is copied.
## Enhanced owns the 1280×720 letterbox chrome, a grow-in reveal, traversal-wave halos,
## hover inspection and the HUD / title card. Overlay positions are read from the Direct
## node's own `node_radius` / `gap` / `DEPTH` / `size` (see `node_points()`), so they
## follow Direct if it changes. Esc → PauseOverlay (global autoload). No Alchementrix IP.

const DEMO := preload("res://games/fnarb_binary_tree/direct/binary_tree.tscn")
const TreeScript := preload("res://games/fnarb_binary_tree/direct/binary_tree.gd")

const STAGE := Vector2(1280, 720)
## Direct demo is authored for a 1920×1080 window; Enhanced frames the tree in a clipped field.
const VP_SIZE := Vector2(1920, 1080)
const FIELD_POS := Vector2(40, 104)
const FIELD := Vector2(1200, 420)
## Direct's vertical step per level (`dy = 40` in build_node), used only for overlay rows.
const ROW_DY := 40.0

const BG_TOP := Color(0.03, 0.05, 0.10)
const BG_BOT := Color(0.07, 0.04, 0.12)
const PANEL := Color(0.08, 0.10, 0.18, 0.94)
const FRAME := Color(0.45, 0.75, 1.0)
const INK := Color(0.92, 0.95, 1.0)
const MUTED := Color(0.58, 0.64, 0.82)
const GOLD := Color(1.0, 0.85, 0.25)
const ACCENT := Color(0.45, 0.90, 0.75)

const GROW_TIME := 2.2
const STEP_TIME := 0.16
const MODES := ["Breadth-first", "Pre-order", "In-order", "Post-order"]

enum { TITLE, PLAY }

var state := TITLE
var demo: Control = null

## View-only presentation state.
var mode := 0
var order: Array[int] = []
var cursor := -1        ## index into `order`; -1 = wave not started
var visited := {}       ## heap index -> time visited
var hover := 0          ## heap index under the mouse (0 = none)
var grow := 0.0         ## 0..1 reveal progress
var _row_popped := -1
var _step_t := 0.0
var _rest_t := 0.0
var _time := 0.0
var _flash := 0.0
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _banner := ""
var _banner_t := 0.0
var _trail: Array[int] = []
var _k := 1.0           ## Direct viewport px -> stage px
var _vp_offset := Vector2.ZERO
var _pts := {}          ## heap index -> Direct viewport position
var _mouse_override = null  ## tests can set a stage point here

var _clip: Control
var _vp_box: SubViewportContainer
var _viewport: SubViewport
var _fx: Node2D
var _ui: CanvasLayer
var _hud: Control
var _cards := {}
var _mode_label: Label
var _visit_label: Label
var _trail_label: Label
var _inspect_label: Label
var _swatch: ColorRect
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
		_regrow()


func _load_demo() -> void:
	demo = DEMO.instantiate() as Control
	_viewport.add_child(demo)
	_frame_tree()


func _regrow() -> void:
	grow = 0.0
	_row_popped = -1
	_particles.clear()
	_floaters.clear()
	_restart_wave()
	_banner = "GROWING  DEPTH %d" % (demo.DEPTH if demo else 5)
	_banner_t = 1.6


func _restart_wave() -> void:
	order = traversal(mode)
	cursor = -1
	visited.clear()
	_trail.clear()
	_step_t = 0.0
	_rest_t = 0.0


# --- tree geometry (read from the Direct node) ------------------------------------

func node_count() -> int:
	return (1 << (demo.DEPTH + 1)) - 1 if demo else 0


func level_of(i: int) -> int:
	var d := 0
	while i > 1:
		i >>= 1
		d += 1
	return d


## Direct viewport positions keyed by heap index (1 = root, 2i = screen-left, 2i+1 = screen-right).
## Mirrors where Direct `build_node` puts each disk, using the Direct node's own fields.
func node_points() -> Dictionary:
	var out := {}
	if demo == null:
		return out
	_place(out, 1, demo.position + demo.size * 0.5, demo.DEPTH)
	return out


func _place(out: Dictionary, i: int, xy: Vector2, depth: int) -> void:
	out[i] = xy
	if depth:
		var width: int = (demo.node_radius + demo.gap) * (1 << depth)
		var dx: int = width / 2
		_place(out, 2 * i, xy + Vector2(-dx, ROW_DY), depth - 1)
		_place(out, 2 * i + 1, xy + Vector2(+dx, ROW_DY), depth - 1)


func traversal(m: int) -> Array[int]:
	var out: Array[int] = []
	var n := node_count()
	if n == 0:
		return out
	if m == 0:
		for i in range(1, n + 1):
			out.append(i)
	else:
		_walk(out, 1, n, m)
	return out


func _walk(out: Array[int], i: int, n: int, m: int) -> void:
	if i > n:
		return
	if m == 1:
		out.append(i)
	_walk(out, 2 * i, n, m)
	if m == 2:
		out.append(i)
	_walk(out, 2 * i + 1, n, m)
	if m == 3:
		out.append(i)


func path_of(i: int) -> String:
	var s := ""
	while i > 1:
		s = ("L" if i % 2 == 0 else "R") + s
		i >>= 1
	return s if s != "" else "root"


func node_color(i: int) -> Color:
	return demo.colors[level_of(i)] if demo else Color.WHITE


func to_stage(p: Vector2) -> Vector2:
	return FIELD_POS + _vp_offset + p * _k


func _frame_tree() -> void:
	_pts = node_points()
	if _pts.is_empty():
		return
	var lo: Vector2 = _pts[1]
	var hi: Vector2 = _pts[1]
	for p in _pts.values():
		lo = lo.min(p)
		hi = hi.max(p)
	var r := float(demo.node_radius)
	lo -= Vector2(r, r)
	hi += Vector2(r, r)
	var box := hi - lo
	_k = minf((FIELD.x - 48.0) / box.x, (FIELD.y - 120.0) / box.y)
	_vp_offset = FIELD * 0.5 + Vector2(0, 24) - (lo + box * 0.5) * _k
	_vp_box.scale = Vector2(_k, _k)
	_vp_box.position = _vp_offset


## Heap index of the disk under a stage-space point, or 0.
func pick(stage_pt: Vector2) -> int:
	if demo == null:
		return 0
	var best := 0
	var best_d: float = (demo.node_radius + 4.0) * _k
	for i in _pts:
		var d := stage_pt.distance_to(to_stage(_pts[i]))
		if d <= best_d:
			best_d = d
			best = i
	return best


# --- input / tick ----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var e := event as InputEventKey
	if state == TITLE:
		if e.keycode in [KEY_ENTER, KEY_SPACE]:
			_set_state(PLAY)
			get_viewport().set_input_as_handled()
		return
	match e.keycode:
		KEY_R:
			_regrow()
			get_viewport().set_input_as_handled()
		KEY_TAB, KEY_T:
			mode = (mode + 1) % MODES.size()
			_restart_wave()
			_banner = MODES[mode].to_upper()
			_banner_t = 1.2
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 2.5)
	_banner_t = maxf(0.0, _banner_t - delta)
	if state == PLAY and demo != null:
		if _pts.is_empty() or demo.size == Vector2.ZERO:
			_frame_tree()
		_tick_grow(delta)
		_tick_wave(delta)
		var mp: Vector2 = _mouse_override if _mouse_override != null else get_local_mouse_position()
		hover = pick(mp)
		_refresh_hud()
	_animate_fx(delta)
	queue_redraw()
	_fx.queue_redraw()


func _tick_grow(delta: float) -> void:
	if grow < 1.0:
		grow = minf(1.0, grow + delta / GROW_TIME)
	var levels: int = demo.DEPTH + 1
	var row := mini(int(floor(grow * levels)), levels - 1) if grow < 1.0 else levels - 1
	while _row_popped < row:
		_row_popped += 1
		for i in range(1 << _row_popped, 1 << (_row_popped + 1)):
			if _pts.has(i):
				_burst(to_stage(_pts[i]), node_color(i), 3, 90.0)
	# Reveal the tree from the root downward by growing the clip height.
	var root_y: float = to_stage(_pts.get(1, Vector2.ZERO)).y - FIELD_POS.y
	var reveal: float = root_y + (grow * levels) * ROW_DY * _k + demo.node_radius * _k
	_clip.size = Vector2(FIELD.x, clampf(reveal, 0.0, FIELD.y) if grow < 1.0 else FIELD.y)


func _tick_wave(delta: float) -> void:
	if grow < 1.0 or order.is_empty():
		return
	if cursor >= order.size() - 1:
		_rest_t += delta
		if _rest_t > 1.4:
			_restart_wave()
		return
	_step_t += delta
	while _step_t >= STEP_TIME and cursor < order.size() - 1:
		_step_t -= STEP_TIME
		cursor += 1
		var i: int = order[cursor]
		visited[i] = _time
		_trail.append(i)
		if _trail.size() > 12:
			_trail.pop_front()
		_burst(to_stage(_pts[i]), node_color(i).lightened(0.3), 6, 140.0)
		if cursor == order.size() - 1:
			_flash = 0.6
			_banner = "%s  |  %d NODES" % [MODES[mode].to_upper(), order.size()]
			_banner_t = 1.2
			_floater("done", to_stage(_pts[1]) + Vector2(-18, -34), GOLD)


func _refresh_hud() -> void:
	_mode_label.text = "%s  (Tab)" % MODES[mode]
	var cur: int = order[cursor] if cursor >= 0 and cursor < order.size() else 0
	_visit_label.text = "Visited  %d / %d%s" % [visited.size(), node_count(),
			("   now #%d" % cur) if cur else ""]
	var t := PackedStringArray()
	for i in _trail:
		t.append(str(i))
	_trail_label.text = " -> ".join(t) if t.size() else "..."
	if hover:
		var d := level_of(hover)
		var sub: int = (1 << (demo.DEPTH - d + 1)) - 1
		_inspect_label.text = "Node #%d   depth %d\nPath  %s\nSubtree  %d node%s%s" % [
				hover, d, path_of(hover), sub, "" if sub == 1 else "s",
				"   (leaf)" if d == demo.DEPTH else ""]
		_swatch.color = node_color(hover)
		_swatch.visible = true
	else:
		_inspect_label.text = "Hover a node to inspect it.\nRoot = #1, children 2i / 2i+1."
		_swatch.visible = false


# --- draw -------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, STAGE), BG_TOP)
	for i in 24:
		var t := float(i) / 24.0
		var c := BG_TOP.lerp(BG_BOT, t)
		draw_rect(Rect2(0, STAGE.y * t, STAGE.x, STAGE.y / 24.0 + 1.0), c)
	# slow drifting motes
	for i in 40:
		var x := fmod(i * 97.3 + _time * (6.0 + i % 5), STAGE.x)
		var y := fmod(i * 53.1 + sin(_time * 0.3 + i) * 12.0 + 360.0, STAGE.y)
		draw_circle(Vector2(x, y), 1.0 + (i % 3) * 0.6, Color(0.6, 0.8, 1.0, 0.10 + 0.05 * (i % 3)))
	if state == PLAY:
		var fr := Rect2(FIELD_POS - Vector2(10, 10), FIELD + Vector2(20, 20))
		draw_rect(fr, Color(0.05, 0.07, 0.13, 0.9))
		# faint level guides behind the tree
		if demo != null and _pts.has(1):
			for d in demo.DEPTH + 1:
				var y: float = to_stage(_pts[1]).y + d * ROW_DY * _k
				var c: Color = demo.colors[d]
				c.a = 0.10
				draw_line(Vector2(FIELD_POS.x + 8, y), Vector2(FIELD_POS.x + FIELD.x - 8, y), c, 1.0)
				_draw_label("d%d" % d, Vector2(FIELD_POS.x + 10, y - 3), 11, Color(c, 0.6))
		draw_rect(fr.grow(-4), Color(FRAME, 0.5), false, 2.0)


## Overlay above the Direct viewport (child node drawn after the field).
func _draw_fx() -> void:
	if state == PLAY and demo != null and not _pts.is_empty():
		var r: float = demo.node_radius * _k
		# halos for visited nodes (fade from bright to a steady glow)
		for i in visited:
			var age: float = _time - visited[i]
			var p := to_stage(_pts[i])
			var c := node_color(i).lightened(0.35)
			var pulse := clampf(1.0 - age * 1.5, 0.0, 1.0)
			c.a = 0.18 + 0.5 * pulse
			_fx.draw_arc(p, r + 3.0 + 8.0 * pulse, 0, TAU, 28, c, 2.0 + 2.0 * pulse)
		# current traversal cursor
		if cursor >= 0 and cursor < order.size():
			var p := to_stage(_pts[order[cursor]])
			var w := 0.5 + 0.5 * sin(_time * 10.0)
			_fx.draw_arc(p, r + 6.0 + 3.0 * w, 0, TAU, 32, GOLD, 3.0)
		# hover: gold path back to the root
		if hover:
			var i := hover
			while i > 1:
				_fx.draw_line(to_stage(_pts[i >> 1]), to_stage(_pts[i]), GOLD, 3.0)
				i >>= 1
			_fx.draw_arc(to_stage(_pts[hover]), r + 4.0, 0, TAU, 32, Color.WHITE, 2.5)
			_fx.draw_circle(to_stage(_pts[1]), 3.0, GOLD)
	for p in _particles:
		var col: Color = p.color
		col.a *= clampf(p.life / p.max, 0.0, 1.0)
		_fx.draw_circle(p.pos, p.size, col)
	for f in _floaters:
		var col: Color = f.color
		col.a *= clampf(f.life / f.max, 0.0, 1.0)
		_fx.draw_string(_font, f.pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
	if _flash > 0.0:
		_fx.draw_rect(Rect2(FIELD_POS, FIELD), Color(GOLD, _flash * 0.12))
	if _banner_t > 0.0 and _banner != "":
		var a := clampf(_banner_t, 0.0, 1.0)
		var r2 := Rect2(STAGE.x * 0.5 - 220, FIELD_POS.y + 14, 440, 34)
		_fx.draw_rect(r2, Color(0.04, 0.05, 0.10, 0.8 * a))
		_fx.draw_string(_font, r2.position + Vector2(0, 24), _banner, HORIZONTAL_ALIGNMENT_CENTER,
				r2.size.x, 18, Color(GOLD, a))


func _draw_label(text: String, pos: Vector2, size: int, color: Color) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# --- FX helpers -------------------------------------------------------------------

func _burst(at: Vector2, color: Color, n: int, speed: float) -> void:
	for i in n:
		var ang := randf() * TAU
		var sp := randf_range(0.3, 1.0) * speed
		_particles.append({
			"pos": at, "vel": Vector2(cos(ang), sin(ang)) * sp,
			"life": randf_range(0.3, 0.6), "max": 0.6,
			"color": color, "size": randf_range(1.5, 3.5),
		})


func _floater(text: String, at: Vector2, color: Color) -> void:
	_floaters.append({"pos": at, "life": 1.0, "max": 1.0, "text": text, "color": color})


func _animate_fx(delta: float) -> void:
	var i := 0
	while i < _particles.size():
		var p: Dictionary = _particles[i]
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.94
		if p.life <= 0.0:
			_particles.remove_at(i)
		else:
			i += 1
	i = 0
	while i < _floaters.size():
		var f: Dictionary = _floaters[i]
		f.life -= delta
		f.pos.y -= 24.0 * delta
		if f.life <= 0.0:
			_floaters.remove_at(i)
		else:
			i += 1


# --- build ------------------------------------------------------------------------

func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "DirectVP"
	_viewport.size = Vector2i(VP_SIZE)
	_viewport.transparent_bg = true  # Enhanced chrome shows through Direct's default clear colour
	_viewport.own_world_3d = true
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

	var top := _panel(Rect2(40, 18, 1200, 68))
	_hud.add_child(top)
	top.add_child(_label("FNARB BINARY TREE", 26, GOLD, Vector2(18, 16)))
	top.add_child(_label("Enhanced", 14, ACCENT, Vector2(300, 28)))
	top.add_child(_label("depth 5  |  63 nodes  |  32 leaves  |  62 edges", 14, MUTED, Vector2(400, 28)))
	var back := _btn("Back to Arcade", Vector2(1062, 16), Vector2(124, 36))
	back.pressed.connect(GameRegistry.return_to_arcade)
	top.add_child(back)

	var wave := _panel(Rect2(40, 546, 470, 156))
	_hud.add_child(wave)
	wave.add_child(_label("TRAVERSAL", 11, MUTED, Vector2(14, 10)))
	_mode_label = _label("Breadth-first  (Tab)", 16, GOLD, Vector2(14, 30))
	wave.add_child(_mode_label)
	_visit_label = _label("Visited  0 / 63", 13, INK, Vector2(14, 60))
	wave.add_child(_visit_label)
	_trail_label = _label("...", 12, ACCENT, Vector2(14, 88))
	_trail_label.size = Vector2(440, 56)
	_trail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wave.add_child(_trail_label)

	var insp := _panel(Rect2(522, 546, 360, 156))
	_hud.add_child(insp)
	insp.add_child(_label("INSPECT", 11, MUTED, Vector2(14, 10)))
	_swatch = ColorRect.new()
	_swatch.position = Vector2(318, 10)
	_swatch.size = Vector2(26, 26)
	_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	insp.add_child(_swatch)
	_inspect_label = _label("", 14, INK, Vector2(14, 36))
	insp.add_child(_inspect_label)

	var keys := _panel(Rect2(894, 546, 346, 156))
	_hud.add_child(keys)
	keys.add_child(_label("CONTROLS", 11, MUTED, Vector2(14, 10)))
	keys.add_child(_label("Mouse  inspect a node\nTab / T  traversal order\nR  regrow\nEsc  pause / arcade",
			13, INK, Vector2(14, 32)))
	keys.add_child(_label("Same Direct binary_tree.gd draws the tree.", 11, MUTED, Vector2(14, 128)))

	# Title card
	var card := _panel(Rect2(STAGE.x * 0.5 - 310, STAGE.y * 0.5 - 170, 620, 340))
	card.name = "TitleCard"
	_ui.add_child(card)
	_cards["title"] = card
	card.add_child(_label("FNARB BINARY TREE", 32, GOLD, Vector2(36, 34)))
	card.add_child(_label("Enhanced edition", 16, ACCENT, Vector2(36, 80)))
	card.add_child(_label(
		"The Direct depth-5 tree sketch, framed and animated:\nit grows in from the root, a traversal wave walks it,\nand you can hover any node to see its path and subtree.",
		14, INK, Vector2(36, 118)))
	var start := _btn("Start", Vector2(36, 220), Vector2(120, 40))
	start.pressed.connect(func(): _set_state(PLAY))
	card.add_child(start)
	card.add_child(_label("Enter / Space  to begin", 14, MUTED, Vector2(180, 230)))
	var title_back := _btn("Back to Arcade", Vector2(36, 280), Vector2(160, 34))
	title_back.pressed.connect(GameRegistry.return_to_arcade)
	card.add_child(title_back)
	# depth colour legend, read from Direct's palette at runtime
	var probe: Control = DEMO.instantiate()
	for d in probe.DEPTH + 1:
		var sw := ColorRect.new()
		sw.position = Vector2(400 + d * 30, 290)
		sw.size = Vector2(22, 22)
		sw.color = probe.colors[d]
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(sw)
	probe.free()


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
