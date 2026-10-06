extends Node2D
## Fnarbmlyx Boolean Syntax Tree (Enhanced). Presentation makeover of the Direct
## seeded boolean AST sketch. The demo is Direct `ast_node_demo.tscn` (shared
## `ast_node_demo.gd` / `ast_node.gd` / `shaded_grid.gd`), instanced in its native
## 1920×1080 SubViewport — no rules copied. Enhanced owns the 1280×720 letterbox
## chrome, a grow-in reveal, traversal-wave halos, hover inspection and the HUD /
## title card. Overlay positions are read from each Direct ASTNode's own
## `global_position` + `link_point()`. Esc → PauseOverlay. No Alchementrix IP.

const DEMO := preload("res://games/fnarb_ast/direct/ast_node_demo.tscn")
const DemoScript := preload("res://games/fnarb_ast/direct/ast_node_demo.gd")
const AstScript := preload("res://games/fnarb_ast/direct/ast_node.gd")
const GridScript := preload("res://games/fnarb_ast/direct/shaded_grid.gd")

const STAGE := Vector2(1280, 720)
## Direct demo is authored for a 1920×1080 window; show it at ½ in a clipped field.
const VP_SIZE := Vector2(1920, 1080)
const FIELD := Vector2(960, 540)
const FIELD_POS := Vector2(160, 90)

const BG_TOP := Color(0.04, 0.05, 0.12)
const BG_BOT := Color(0.10, 0.08, 0.18)
const PANEL := Color(0.09, 0.10, 0.20, 0.94)
const FRAME := Color(0.55, 0.70, 1.0)
const INK := Color(0.92, 0.95, 1.0)
const MUTED := Color(0.58, 0.64, 0.82)
const GOLD := Color(1.0, 0.85, 0.28)
const ACCENT := Color(0.50, 0.90, 0.78)

const GROW_TIME := 2.0
const STEP_TIME := 0.12
const MODES := ["Breadth-first", "Pre-order", "In-order", "Post-order"]

enum { TITLE, PLAY }

var state := TITLE
var demo: ColorRect = null
var ast: Control = null

## View-only presentation state.
var mode := 0
var order: Array[int] = []   ## indices into `_nodes`
var cursor := -1
var visited := {}            ## node index -> time visited
var hover := -1              ## node index under the mouse (-1 = none)
var grow := 0.0
var _depth_popped := -1
var _step_t := 0.0
var _rest_t := 0.0
var _time := 0.0
var _flash := 0.0
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _banner := ""
var _banner_t := 0.0
var _trail: Array[int] = []
var _mouse_override = null   ## tests can set a stage point here

## Flat view of the Direct AST (read-only).
var _nodes: Array[Control] = []
var _paths: Array[String] = []
var _depths: Array[int] = []
var _parents: Array[int] = []
var _max_depth := 0

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
var _stats_label: Label
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
	_clip.visible = s == PLAY
	if s == PLAY and demo == null:
		_load_demo()
	if s == PLAY:
		_regrow()


func _load_demo() -> void:
	demo = DEMO.instantiate() as ColorRect
	_viewport.add_child(demo)
	ast = demo.get_node_or_null("ASTNodeDemo") as Control
	# ASTNodeDemo.rebuild() runs in _ready; nodes may land next frame.
	_collect_nodes()
	_refresh_hud()


func _regrow() -> void:
	grow = 0.0
	_depth_popped = -1
	_particles.clear()
	_floaters.clear()
	_restart_wave()
	var n := _nodes.size()
	_banner = "GROWING  %d NODES" % n if n else "GROWING"
	_banner_t = 1.6


func _restart_wave() -> void:
	order = traversal(mode)
	cursor = -1
	visited.clear()
	_trail.clear()
	_step_t = 0.0
	_rest_t = 0.0


# --- AST geometry (read from Direct nodes) ------------------------------------

func _collect_nodes() -> void:
	_nodes.clear()
	_paths.clear()
	_depths.clear()
	_parents.clear()
	_max_depth = 0
	if ast == null or ast.get_child_count() == 0:
		return
	var root_n: Control = ast.get_child(0) as Control
	if root_n == null or root_n.get_script() != AstScript:
		return
	_walk_collect(root_n, "root", 0, -1)


func _walk_collect(n: Control, path: String, depth: int, parent: int) -> void:
	var i := _nodes.size()
	_nodes.append(n)
	_paths.append(path)
	_depths.append(depth)
	_parents.append(parent)
	_max_depth = maxi(_max_depth, depth)
	for c_i in n.get_child_count():
		var c: Control = n.get_child(c_i) as Control
		if c == null or c.get_script() != AstScript:
			continue
		var child_path := path
		if path == "root":
			child_path = "L" if c_i == 0 else "R"
		else:
			child_path = path + ("L" if c_i == 0 else "R")
		_walk_collect(c, child_path, depth + 1, i)


func node_count() -> int:
	return _nodes.size()


func node_center_vp(i: int) -> Vector2:
	if i < 0 or i >= _nodes.size():
		return Vector2.ZERO
	var n: Control = _nodes[i]
	return n.global_position + n.link_point()


func to_stage(vp_pt: Vector2) -> Vector2:
	return FIELD_POS + vp_pt * (FIELD / VP_SIZE)


func node_color(i: int) -> Color:
	if i < 0 or i >= _nodes.size():
		return Color.WHITE
	return _nodes[i].fill_color


func node_text(i: int) -> String:
	if i < 0 or i >= _nodes.size():
		return ""
	return str(_nodes[i].text)


func traversal(m: int) -> Array[int]:
	var out: Array[int] = []
	if _nodes.is_empty():
		return out
	if m == 0:
		## BFS by depth, left-to-right within a depth (collection order is already DFS,
		## so regroup by depth).
		var by_d: Dictionary = {}
		for i in _nodes.size():
			var d: int = _depths[i]
			if not by_d.has(d):
				by_d[d] = []
			by_d[d].append(i)
		for d in range(_max_depth + 1):
			if by_d.has(d):
				for i in by_d[d]:
					out.append(i)
	else:
		_walk_order(out, 0, m)
	return out


func _walk_order(out: Array[int], i: int, m: int) -> void:
	if i < 0 or i >= _nodes.size():
		return
	if m == 1:
		out.append(i)
	var kids: Array[int] = []
	for j in _nodes.size():
		if _parents[j] == i:
			kids.append(j)
	if kids.size() >= 1:
		_walk_order(out, kids[0], m)
	if m == 2:
		out.append(i)
	if kids.size() >= 2:
		_walk_order(out, kids[1], m)
	if m == 3:
		out.append(i)


## Node index under a stage-space point, or -1.
func pick(stage_pt: Vector2) -> int:
	if _nodes.is_empty():
		return -1
	var best := -1
	var best_d := 22.0  ## ~ node radius at ½ scale (16 px Direct → 8 stage, pick a bit wider)
	for i in _nodes.size():
		var d := stage_pt.distance_to(to_stage(node_center_vp(i)))
		if d <= best_d:
			best_d = d
			best = i
	return best


# --- input / tick -------------------------------------------------------------

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
		if _nodes.is_empty() and ast != null and ast.get_child_count() > 0:
			_collect_nodes()
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
	var levels := _max_depth + 1
	if levels <= 0:
		_clip.size = FIELD
		return
	var row := mini(int(floor(grow * levels)), levels - 1) if grow < 1.0 else levels - 1
	while _depth_popped < row:
		_depth_popped += 1
		for i in _nodes.size():
			if _depths[i] == _depth_popped:
				_burst(to_stage(node_center_vp(i)), node_color(i), 3, 90.0)
	## Reveal from the root downward by growing the clip height.
	var root_y := 0.0
	if not _nodes.is_empty():
		root_y = to_stage(node_center_vp(0)).y - FIELD_POS.y
	var reveal := root_y + grow * FIELD.y
	_clip.size = Vector2(FIELD.x, clampf(reveal, 24.0, FIELD.y) if grow < 1.0 else FIELD.y)


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
		_burst(to_stage(node_center_vp(i)), node_color(i).lightened(0.3), 5, 130.0)
		if cursor == order.size() - 1:
			_flash = 0.55
			_banner = "%s  |  %d NODES" % [MODES[mode].to_upper(), order.size()]
			_banner_t = 1.2
			_floater("done", to_stage(node_center_vp(0)) + Vector2(-18, -28), GOLD)


func _refresh_hud() -> void:
	if _mode_label == null:
		return
	_mode_label.text = "%s  (Tab)" % MODES[mode]
	var cur: int = order[cursor] if cursor >= 0 and cursor < order.size() else -1
	_visit_label.text = "Visited  %d / %d%s" % [visited.size(), node_count(),
			("   now %s" % node_text(cur)) if cur >= 0 else ""]
	var t := PackedStringArray()
	for i in _trail:
		t.append(node_text(i))
	_trail_label.text = " -> ".join(t) if t.size() else "..."
	if ast != null:
		_stats_label.text = "Seed  %d\nNodes  %d\nHeight  %d\nDepths  0...%d" % [
				ast.rng_seed, node_count(),
				ast.tree.height if ast.tree else 0, _max_depth]
	if hover >= 0:
		var n: Control = _nodes[hover]
		var kids := n.get_child_count()
		_inspect_label.text = "Op  %s\nPath  %s\nDepth  %d\nChildren  %d%s" % [
				node_text(hover), _paths[hover], _depths[hover], kids,
				"   (leaf)" if kids == 0 else ""]
		_swatch.color = node_color(hover)
		_swatch.visible = true
	else:
		_inspect_label.text = "Hover a node to inspect it.\n& | != over x0-x4, F, T."
		_swatch.visible = false


# --- draw ---------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, STAGE), BG_TOP)
	for i in 24:
		var t := float(i) / 24.0
		var c := BG_TOP.lerp(BG_BOT, t)
		draw_rect(Rect2(0, STAGE.y * t, STAGE.x, STAGE.y / 24.0 + 1.0), c)
	for i in 36:
		var x := fmod(i * 97.3 + _time * (5.0 + i % 4), STAGE.x)
		var y := fmod(i * 53.1 + sin(_time * 0.3 + i) * 10.0 + 360.0, STAGE.y)
		draw_circle(Vector2(x, y), 1.0 + (i % 3) * 0.5, Color(0.65, 0.75, 1.0, 0.08 + 0.04 * (i % 3)))
	if state == PLAY:
		var fr := Rect2(FIELD_POS - Vector2(10, 10), FIELD + Vector2(20, 20))
		draw_rect(fr, Color(0.05, 0.06, 0.12, 0.9))
		draw_rect(fr.grow(-4), Color(FRAME, 0.5), false, 2.0)


func _draw_fx() -> void:
	if state == PLAY and not _nodes.is_empty():
		var r := 10.0
		for i in visited:
			var age: float = _time - visited[i]
			var p := to_stage(node_center_vp(i))
			var c := node_color(i).lightened(0.35)
			var pulse := clampf(1.0 - age * 1.5, 0.0, 1.0)
			c.a = 0.18 + 0.5 * pulse
			_fx.draw_arc(p, r + 2.0 + 6.0 * pulse, 0, TAU, 28, c, 2.0 + 2.0 * pulse)
		if cursor >= 0 and cursor < order.size():
			var p2 := to_stage(node_center_vp(order[cursor]))
			var w := 0.5 + 0.5 * sin(_time * 10.0)
			_fx.draw_arc(p2, r + 5.0 + 2.5 * w, 0, TAU, 32, GOLD, 2.5)
		if hover >= 0:
			var i2 := hover
			while i2 > 0:
				var p_i := _parents[i2]
				if p_i < 0:
					break
				_fx.draw_line(to_stage(node_center_vp(p_i)), to_stage(node_center_vp(i2)), GOLD, 2.5)
				i2 = p_i
			_fx.draw_arc(to_stage(node_center_vp(hover)), r + 3.0, 0, TAU, 32, Color.WHITE, 2.0)
			_fx.draw_circle(to_stage(node_center_vp(0)), 3.0, GOLD)
	for p in _particles:
		var col: Color = p.color
		col.a *= clampf(p.life / p.max, 0.0, 1.0)
		_fx.draw_circle(p.pos, p.size, col)
	for f in _floaters:
		var col2: Color = f.color
		col2.a *= clampf(f.life / f.max, 0.0, 1.0)
		_fx.draw_string(_font, f.pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col2)
	if _flash > 0.0:
		_fx.draw_rect(Rect2(FIELD_POS, FIELD), Color(GOLD, _flash * 0.12))
	if _banner_t > 0.0 and _banner != "":
		var a := clampf(_banner_t, 0.0, 1.0)
		var r2 := Rect2(STAGE.x * 0.5 - 220, FIELD_POS.y + 14, 440, 34)
		_fx.draw_rect(r2, Color(0.04, 0.05, 0.10, 0.8 * a))
		_fx.draw_string(_font, r2.position + Vector2(0, 24), _banner, HORIZONTAL_ALIGNMENT_CENTER,
				r2.size.x, 18, Color(GOLD, a))


# --- FX helpers ---------------------------------------------------------------

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


# --- build --------------------------------------------------------------------

func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "DirectVP"
	_viewport.size = Vector2i(VP_SIZE)
	_viewport.transparent_bg = false
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE

	_vp_box = SubViewportContainer.new()
	_vp_box.name = "DemoView"
	## Keep Direct at native 1920×1080 (AST rebuild uses get_viewport().size); scale into field.
	_vp_box.size = VP_SIZE
	_vp_box.scale = FIELD / VP_SIZE
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

	var top := _panel(Rect2(160, 18, 960, 58))
	_hud.add_child(top)
	top.add_child(_label("FNARB BOOLEAN AST", 22, GOLD, Vector2(16, 14)))
	top.add_child(_label("Enhanced", 13, ACCENT, Vector2(280, 20)))
	top.add_child(_label("seeded & | != tree  |  Direct ast_node_demo", 13, MUTED, Vector2(380, 20)))
	var back := _btn("Back to Arcade", Vector2(820, 12), Vector2(124, 34))
	back.pressed.connect(GameRegistry.return_to_arcade)
	top.add_child(back)

	var left := _panel(Rect2(16, 90, 130, 300))
	_hud.add_child(left)
	left.add_child(_label("TREE", 11, MUTED, Vector2(10, 10)))
	_stats_label = _label("Seed  -\nNodes  -\nHeight  -", 12, INK, Vector2(10, 34))
	left.add_child(_stats_label)
	left.add_child(_label("Same Direct\nast_node.gd +\nshaded_grid.gd.", 11, MUTED, Vector2(10, 150)))
	left.add_child(_label("OPS", 11, MUTED, Vector2(10, 220)))
	left.add_child(_label("& &  | |  != !=\nx0...x4  F T", 12, ACCENT, Vector2(10, 242)))

	var wave := _panel(Rect2(16, 404, 130, 196))
	_hud.add_child(wave)
	wave.add_child(_label("WALK", 11, MUTED, Vector2(10, 10)))
	_mode_label = _label("Breadth-first", 12, GOLD, Vector2(10, 32))
	_mode_label.size = Vector2(110, 40)
	_mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wave.add_child(_mode_label)
	_visit_label = _label("Visited  0", 11, INK, Vector2(10, 80))
	_visit_label.size = Vector2(110, 40)
	_visit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wave.add_child(_visit_label)
	_trail_label = _label("...", 11, ACCENT, Vector2(10, 130))
	_trail_label.size = Vector2(110, 56)
	_trail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wave.add_child(_trail_label)

	var right := _panel(Rect2(1134, 90, 130, 300))
	_hud.add_child(right)
	right.add_child(_label("INSPECT", 11, MUTED, Vector2(10, 10)))
	_swatch = ColorRect.new()
	_swatch.position = Vector2(94, 10)
	_swatch.size = Vector2(24, 24)
	_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_swatch)
	_inspect_label = _label("Hover a node...", 12, INK, Vector2(10, 44))
	_inspect_label.size = Vector2(110, 160)
	_inspect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_inspect_label)

	var keys := _panel(Rect2(1134, 404, 130, 196))
	_hud.add_child(keys)
	keys.add_child(_label("CONTROLS", 11, MUTED, Vector2(10, 10)))
	keys.add_child(_label("Mouse  inspect\nTab/T  order\nR  regrow\nEsc  pause", 12, INK, Vector2(10, 36)))

	# Title card
	var card := _panel(Rect2(STAGE.x * 0.5 - 310, STAGE.y * 0.5 - 170, 620, 340))
	card.name = "TitleCard"
	_ui.add_child(card)
	_cards["title"] = card
	card.add_child(_label("FNARB BOOLEAN AST", 30, GOLD, Vector2(36, 34)))
	card.add_child(_label("Enhanced edition", 16, ACCENT, Vector2(36, 80)))
	card.add_child(_label(
		"The Direct seeded boolean syntax tree, framed and animated:\nit grows in from the root, a traversal wave walks it,\nand you can hover any node to see its op and path.",
		14, INK, Vector2(36, 118)))
	var start := _btn("Start", Vector2(36, 220), Vector2(120, 40))
	start.pressed.connect(func(): _set_state(PLAY))
	card.add_child(start)
	card.add_child(_label("Enter / Space  to begin", 14, MUTED, Vector2(180, 230)))
	var title_back := _btn("Back to Arcade", Vector2(36, 280), Vector2(160, 34))
	title_back.pressed.connect(GameRegistry.return_to_arcade)
	card.add_child(title_back)
	# Op colour swatches from a probe of Direct ASTNode colours.
	var probe: Control = (load("res://games/fnarb_ast/direct/ast_node.tscn") as PackedScene).instantiate()
	var ops := [7, 8, 9, 0, 5, 6]  ## ∧ ∨ ≠ x₀ ⊥ ⊤
	for i in ops.size():
		probe.op = ops[i]
		var sw := ColorRect.new()
		sw.position = Vector2(400 + i * 30, 290)
		sw.size = Vector2(22, 22)
		sw.color = probe.fill_color
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
