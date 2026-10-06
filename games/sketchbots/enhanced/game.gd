extends Node2D
## SketchBots (Enhanced). Visual/UI makeover of the Direct GameSketchLib
## w01 SketchBots port. Simulation is Direct sketchbots_logic.gd (preloaded,
## not copied): heading bitflags, 10 px/frame (incl. diagonals), bottom-only
## clamp, XOR key-release, two-player orange (WASD/,aoe) + blue (arrows).
## This file owns the 1280×720 letterbox shell: framed sketch field, bot glow
## + walk squash + dust, meet-up sparkles, off-canvas locators, side HUD,
## title card, Back to Arcade. Esc is handled by the PauseOverlay autoload.
## No Alchementrix IP. No new core mechanics (still no goal or scoring).

const Logic := preload("res://games/sketchbots/direct/sketchbots_logic.gd")
const TEX_BG := preload("res://games/sketchbots/direct/assets/background.png")
const TEX_ORANGE := {
	Logic.Face.L: preload("res://games/sketchbots/direct/assets/orangeguy-L.png"),
	Logic.Face.R: preload("res://games/sketchbots/direct/assets/orangeguy-R.png"),
	Logic.Face.U: preload("res://games/sketchbots/direct/assets/orangeguy-U.png"),
	Logic.Face.D: preload("res://games/sketchbots/direct/assets/orangeguy-D.png"),
}
const TEX_BLUE := {
	Logic.Face.L: preload("res://games/sketchbots/direct/assets/blueguy-L.png"),
	Logic.Face.R: preload("res://games/sketchbots/direct/assets/blueguy-R.png"),
	Logic.Face.U: preload("res://games/sketchbots/direct/assets/blueguy-U.png"),
	Logic.Face.D: preload("res://games/sketchbots/direct/assets/blueguy-D.png"),
}

const STAGE := Vector2(1280, 720)
const PX := 2.0  ## 300×300 → 600×600 field
const FIELD := Vector2(Logic.W, Logic.H) * PX
const FIELD_POS := Vector2((STAGE.x - FIELD.x) * 0.5, (STAGE.y - FIELD.y) * 0.5)
const STEP_SEC := 1.0 / Logic.FPS

const BG_TOP := Color(0.04, 0.05, 0.10)
const BG_BOTTOM := Color(0.08, 0.06, 0.14)
const PANEL := Color(0.07, 0.09, 0.18, 0.94)
const FRAME := Color(0.55, 0.78, 1.0)
const INK := Color(0.93, 0.96, 1.0)
const MUTED := Color(0.58, 0.64, 0.82)
const GOLD := Color(1.0, 0.84, 0.32)
const ORANGE := Color(1.0, 0.55, 0.22)
const BLUE := Color(0.35, 0.72, 1.0)
const HOT := Color(1.0, 0.48, 0.28)
const GREEN := Color(0.42, 0.95, 0.58)

var world = Logic.new()
var playing := false  ## false while the Enhanced title card is up
var _acc := 0.0
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _meets := 0
var _steps := 0
var _off_canvas_events := 0

var _prev_ox := 0
var _prev_oy := 0
var _prev_bx := 0
var _prev_by := 0
var _prev_overlap := false
var _prev_orange_off := false
var _prev_blue_off := false

var _draw_o := Vector2.ZERO
var _draw_b := Vector2.ZERO
var _target_o := Vector2.ZERO
var _target_b := Vector2.ZERO
var _squash_o := Vector2.ONE
var _squash_b := Vector2.ONE

var _field: Control
var _ui: CanvasLayer
var _cards := {}
var _pos_o_label: Label
var _pos_b_label: Label
var _face_o_label: Label
var _face_b_label: Label
var _meet_label: Label
var _step_label: Label
var _status_label: Label
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
	_draw_o = Vector2(world.orange_x, world.orange_y)
	_draw_b = Vector2(world.blue_x, world.blue_y)
	_target_o = _draw_o
	_target_b = _draw_b
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


func _snap_prev() -> void:
	_prev_ox = world.orange_x
	_prev_oy = world.orange_y
	_prev_bx = world.blue_x
	_prev_by = world.blue_y
	_prev_overlap = _bots_overlap()
	_prev_orange_off = _is_off(world.orange_x, world.orange_y, world.orange_w, world.orange_h)
	_prev_blue_off = _is_off(world.blue_x, world.blue_y, world.blue_w, world.blue_h)


## One presentation step over Direct handle_key + step (tests call this for parity).
## `actions` is an Array of [token:String, pressed:bool].
func tick(actions: Array = []) -> void:
	for a in actions:
		world.handle_key(String(a[0]), bool(a[1]))
	world.step()
	_steps += 1
	_observe()


func _bots_overlap() -> bool:
	var oa := Rect2(world.orange_x, world.orange_y, world.orange_w, world.orange_h)
	var ba := Rect2(world.blue_x, world.blue_y, world.blue_w, world.blue_h)
	return oa.intersects(ba)


func _is_off(x: int, y: int, w: int, h: int) -> bool:
	return x < 0 or y < 0 or x + w > Logic.W or y + h > Logic.H


func _observe() -> void:
	_target_o = Vector2(world.orange_x, world.orange_y)
	_target_b = Vector2(world.blue_x, world.blue_y)
	var o_moved: bool = world.orange_x != _prev_ox or world.orange_y != _prev_oy
	var b_moved: bool = world.blue_x != _prev_bx or world.blue_y != _prev_by
	if o_moved:
		_squash_o = Vector2(0.82, 1.18)
		_dust(Vector2(world.orange_x + world.orange_w * 0.5, world.orange_y + world.orange_h), ORANGE, 3, 1.1)
	if b_moved:
		_squash_b = Vector2(0.82, 1.18)
		_dust(Vector2(world.blue_x + world.blue_w * 0.5, world.blue_y + world.blue_h), BLUE, 3, 1.1)
	# Meet-up juice when AABBs first overlap (visual only — no rules).
	var now_overlap := _bots_overlap()
	if now_overlap and not _prev_overlap:
		_meets += 1
		var mid := Vector2(
			(world.orange_x + world.blue_x + world.orange_w) * 0.5,
			(world.orange_y + world.blue_y + world.orange_h) * 0.5)
		_burst(mid, GOLD, 14, 2.4)
		_burst(mid, HOT, 8, 1.8)
		_float_text("HI!", mid + Vector2(0, -18), GOLD)
		_shake = maxf(_shake, 0.28)
		_flash = 0.35
		_flash_color = Color(1.0, 0.9, 0.5)
	_prev_overlap = now_overlap
	# Off-canvas event when a bot first leaves the 300×300 (top/left/right open).
	var o_off := _is_off(world.orange_x, world.orange_y, world.orange_w, world.orange_h)
	var b_off := _is_off(world.blue_x, world.blue_y, world.blue_w, world.blue_h)
	if o_off and not _prev_orange_off:
		_off_canvas_events += 1
		_float_text("OFF", Vector2(clampf(world.orange_x, 8, Logic.W - 40), clampf(world.orange_y, 8, Logic.H - 24)), ORANGE)
	if b_off and not _prev_blue_off:
		_off_canvas_events += 1
		_float_text("OFF", Vector2(clampf(world.blue_x, 8, Logic.W - 40), clampf(world.blue_y, 8, Logic.H - 24)), BLUE)
	_prev_orange_off = o_off
	_prev_blue_off = b_off
	_prev_ox = world.orange_x
	_prev_oy = world.orange_y
	_prev_bx = world.blue_x
	_prev_by = world.blue_y


func _process(delta: float) -> void:
	_time += delta
	if playing:
		_acc = minf(_acc + delta, 0.25)
		var stepped := false
		while _acc >= STEP_SEC:
			_acc -= STEP_SEC
			world.step()
			_steps += 1
			_observe()
			stepped = true
		if not stepped:
			# Keep interp target fresh even when we didn't step this frame.
			pass
	_animate(delta)
	_refresh_hud()
	_field.queue_redraw()
	queue_redraw()


func _key_token(k: InputEventKey) -> String:
	if k.unicode != 0:
		var ch := String.chr(k.unicode).to_lower()
		if ch in [",", "<", "w", "e", "d", "o", "s", "a"]:
			return ch
	match k.keycode:
		KEY_COMMA:
			return ","
		KEY_W:
			return "w"
		KEY_E:
			return "e"
		KEY_D:
			return "d"
		KEY_O:
			return "o"
		KEY_S:
			return "s"
		KEY_A:
			return "a"
		KEY_UP:
			return "up"
		KEY_DOWN:
			return "down"
		KEY_LEFT:
			return "left"
		KEY_RIGHT:
			return "right"
		_:
			return ""


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or k.echo:
		return
	if not playing and k.pressed and k.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		start()
		get_viewport().set_input_as_handled()
		return
	if not playing:
		return
	var token := _key_token(k)
	if token.is_empty():
		return
	world.handle_key(token, k.pressed)
	get_viewport().set_input_as_handled()


func _animate(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 2.4)
	_flash = maxf(0.0, _flash - delta * 1.8)
	_squash_o = _squash_o.lerp(Vector2.ONE, minf(1.0, delta * 10.0))
	_squash_b = _squash_b.lerp(Vector2.ONE, minf(1.0, delta * 10.0))
	# Smooth draw positions toward Direct targets between 30 Hz steps.
	var blend := minf(1.0, delta * 18.0)
	_draw_o = _draw_o.lerp(_target_o, blend)
	_draw_b = _draw_b.lerp(_target_b, blend)
	for p in _particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.94
	_particles = _particles.filter(func(p): return p.life > 0.0)
	for f in _floaters:
		f.life -= delta
		f.pos += f.vel * delta
		f.vel.y -= 22.0 * delta
	_floaters = _floaters.filter(func(f): return f.life > 0.0)
	if _field != null:
		var shake_off := Vector2.ZERO
		if _shake > 0.0:
			shake_off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 5.0
		_field.position = FIELD_POS + shake_off


func _dust(at: Vector2, col: Color, n: int, speed: float) -> void:
	for i in n:
		_particles.append({
			"pos": at + Vector2(randf_range(-6, 6), randf_range(-2, 2)),
			"vel": Vector2(randf_range(-30, 30), randf_range(-55, -15)) * speed,
			"r": randf_range(1.4, 2.8),
			"life": randf_range(0.18, 0.38),
			"max": 0.38,
			"col": col,
		})


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
	for i in 18:
		var t := float(i) / 17.0
		draw_rect(Rect2(0, STAGE.y * t, STAGE.x, STAGE.y / 18.0 + 1.0), BG_TOP.lerp(BG_BOTTOM, t))
	# Soft vignette beside the field.
	draw_rect(Rect2(0, 0, FIELD_POS.x - 10, STAGE.y), Color(0, 0, 0, 0.28))
	draw_rect(Rect2(FIELD_POS.x + FIELD.x + 10, 0, STAGE.x - (FIELD_POS.x + FIELD.x + 10), STAGE.y), Color(0, 0, 0, 0.28))
	# Neon frame around the playfield.
	var fr := Rect2(FIELD_POS - Vector2(6, 6), FIELD + Vector2(12, 12))
	draw_rect(fr, Color(FRAME, 0.35), false, 3.0)
	draw_rect(fr.grow(4.0), Color(FRAME, 0.12), false, 2.0)
	if _flash > 0.0:
		var fc := _flash_color
		fc.a = _flash * 0.40
		draw_rect(Rect2(Vector2.ZERO, STAGE), fc)


func _build_field() -> void:
	_field = Control.new()
	_field.name = "Field"
	_field.position = FIELD_POS
	_field.size = FIELD
	_field.clip_contents = true
	_field.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.draw.connect(_draw_field)
	add_child(_field)


func _s(p: Vector2) -> Vector2:
	return p * PX


func _face_name(f: int) -> String:
	match f:
		Logic.Face.L:
			return "L"
		Logic.Face.R:
			return "R"
		Logic.Face.U:
			return "U"
		Logic.Face.D:
			return "D"
		_:
			return "?"


func _heading_bits(h: int) -> String:
	var parts: PackedStringArray = []
	if h & Logic.NORTH:
		parts.append("N")
	if h & Logic.EAST:
		parts.append("E")
	if h & Logic.SOUTH:
		parts.append("S")
	if h & Logic.WEST:
		parts.append("W")
	return "-".join(parts) if parts.size() > 0 else "-"


func _draw_bot(tex: Texture2D, pos: Vector2, squash: Vector2, glow: Color) -> void:
	var cx := pos.x + 25.0
	var cy := pos.y + 25.0
	var centre := _s(Vector2(cx, cy))
	# Soft glow disc behind the sprite.
	var pulse := 0.55 + 0.45 * sin(_time * 5.0 + cx * 0.07)
	_field.draw_circle(centre, 34.0 * pulse, Color(glow.r, glow.g, glow.b, 0.28 * pulse))
	_field.draw_circle(centre, 22.0, Color(glow.r, glow.g, glow.b, 0.18))
	# Drop shadow.
	_field.draw_circle(centre + Vector2(0, 18), 16.0, Color(0, 0, 0, 0.28))
	# Squash/stretch around feet.
	var feet := _s(Vector2(cx, pos.y + 50.0))
	_field.draw_set_transform(feet, 0.0, Vector2(PX * squash.x, PX * squash.y))
	_field.draw_texture(tex, Vector2(-25.0, -50.0))
	_field.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_locator(pos: Vector2, w: int, h: int, col: Color) -> void:
	# Edge chevron when the bot has left the canvas (clipped by field).
	var cx := pos.x + w * 0.5
	var cy := pos.y + h * 0.5
	var tip := Vector2(clampf(cx, 8.0, Logic.W - 8.0), clampf(cy, 8.0, Logic.H - 8.0))
	var dir := Vector2(cx, cy) - tip
	if dir.length_squared() < 1.0:
		return
	dir = dir.normalized()
	var tip_s := _s(tip)
	var a := tip_s + dir.rotated(2.4) * 14.0
	var b := tip_s + dir.rotated(-2.4) * 14.0
	_field.draw_colored_polygon(PackedVector2Array([tip_s, a, b]), col)
	_field.draw_circle(tip_s, 4.0, Color(col.r, col.g, col.b, 0.8))


func _draw_field() -> void:
	# Soft room wash over the Direct background (left 300×300 of the 900×300 asset).
	_field.draw_texture_rect(TEX_BG, Rect2(Vector2.ZERO, FIELD), false)
	# Subtle scan / grid overlay so the sketch feels staged.
	for i in 6:
		var y := FIELD.y * float(i) / 5.0
		_field.draw_line(Vector2(0, y), Vector2(FIELD.x, y), Color(1, 1, 1, 0.03), 1.0)
	for i in 6:
		var x := FIELD.x * float(i) / 5.0
		_field.draw_line(Vector2(x, 0), Vector2(x, FIELD.y), Color(1, 1, 1, 0.03), 1.0)
	# Bottom clamp cue (only edge that actually clamps).
	_field.draw_rect(Rect2(0, FIELD.y - 4.0, FIELD.x, 4.0), Color(GREEN.r, GREEN.g, GREEN.b, 0.35 + 0.15 * sin(_time * 3.0)))
	# Bots (interpolated).
	_draw_bot(TEX_ORANGE[world.orange_face], _draw_o, _squash_o, ORANGE)
	_draw_bot(TEX_BLUE[world.blue_face], _draw_b, _squash_b, BLUE)
	# Off-canvas locators.
	if _is_off(int(_draw_o.x), int(_draw_o.y), world.orange_w, world.orange_h):
		_draw_locator(_draw_o, world.orange_w, world.orange_h, ORANGE)
	if _is_off(int(_draw_b.x), int(_draw_b.y), world.blue_w, world.blue_h):
		_draw_locator(_draw_b, world.blue_w, world.blue_h, BLUE)
	# Particles + floaters in Direct sketch space.
	for part in _particles:
		var a: float = clampf(part.life / maxf(part.max, 0.01), 0.0, 1.0)
		var pc: Color = part.col
		pc.a *= a
		_field.draw_circle(_s(part.pos), part.r * PX * 0.45, pc)
	for f in _floaters:
		var a: float = clampf(f.life / maxf(f.max, 0.01), 0.0, 1.0)
		var fc: Color = f.col
		fc.a = a
		_field.draw_string(_font, _s(f.pos), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, fc)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	# Left panel — title + controls.
	var left := _panel(Rect2(24, 60, 280, 560))
	_ui.add_child(left)
	var title := _label("SKETCHBOTS", 28, GOLD)
	title.position = Vector2(16, 14)
	title.size = Vector2(248, 36)
	left.add_child(title)
	var sub := _label("Enhanced | GameSketchLib w01", 13, MUTED)
	sub.position = Vector2(16, 48)
	sub.size = Vector2(248, 22)
	left.add_child(sub)
	var hint := _label(
		"Orange: WASD or ,AOE\nBlue:   arrow keys\nEsc:    pause\n\nHello-world mover.\nBottom edge clamps;\ntop/left/right are open.\nDiagonals are full speed.\nNo goal - just roam.",
		15, INK)
	hint.position = Vector2(16, 88)
	hint.size = Vector2(248, 300)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(hint)
	var back := _button("Back to Arcade", Color(0.22, 0.30, 0.58), 17)
	back.position = Vector2(16, 490)
	back.size = Vector2(248, 44)
	back.pressed.connect(GameRegistry.return_to_arcade)
	left.add_child(back)
	# Right panel — live HUD.
	var right := _panel(Rect2(STAGE.x - 304, 60, 280, 560))
	_ui.add_child(right)
	_step_label = _label("STEPS  0", 22, GOLD)
	_step_label.position = Vector2(16, 16)
	_step_label.size = Vector2(248, 30)
	right.add_child(_step_label)
	_meet_label = _label("MEETS  0", 18, HOT)
	_meet_label.position = Vector2(16, 52)
	_meet_label.size = Vector2(248, 26)
	right.add_child(_meet_label)
	var o_cap := _label("ORANGE", 14, ORANGE)
	o_cap.position = Vector2(16, 100)
	o_cap.size = Vector2(248, 20)
	right.add_child(o_cap)
	_pos_o_label = _label("pos  125, 125", 16, INK)
	_pos_o_label.position = Vector2(16, 122)
	_pos_o_label.size = Vector2(248, 24)
	right.add_child(_pos_o_label)
	_face_o_label = _label("face L | -", 15, MUTED)
	_face_o_label.position = Vector2(16, 148)
	_face_o_label.size = Vector2(248, 22)
	right.add_child(_face_o_label)
	var b_cap := _label("BLUE", 14, BLUE)
	b_cap.position = Vector2(16, 190)
	b_cap.size = Vector2(248, 20)
	right.add_child(b_cap)
	_pos_b_label = _label("pos  125, 250", 16, INK)
	_pos_b_label.position = Vector2(16, 212)
	_pos_b_label.size = Vector2(248, 24)
	right.add_child(_pos_b_label)
	_face_b_label = _label("face D | -", 15, MUTED)
	_face_b_label.position = Vector2(16, 238)
	_face_b_label.size = Vector2(248, 22)
	right.add_child(_face_b_label)
	_status_label = _label("on canvas", 15, GREEN)
	_status_label.position = Vector2(16, 290)
	_status_label.size = Vector2(248, 80)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_status_label)
	var tip := _label("View-only HUD.\nMeet sparkles when\nthe bots overlap.\nSame Direct quirks.", 13, MUTED)
	tip.position = Vector2(16, 400)
	tip.size = Vector2(248, 100)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(tip)
	_cards["title"] = _make_card(
		"SKETCHBOTS",
		"Two-player hello-world movers\nfrom GameSketchLib week 1.\n\nOrange: WASD / ,AOE\nBlue: arrow keys\n\nSpace / Enter to roam",
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
	var box := _panel(Rect2((FIELD.x - 380) * 0.5, (FIELD.y - 300) * 0.5, 380, 300))
	wrap.add_child(box)
	var h := _label(heading, 30, GOLD)
	h.position = Vector2(20, 20)
	h.size = Vector2(340, 40)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(h)
	var b := _label(body, 15, INK)
	b.name = "Body"
	b.position = Vector2(24, 72)
	b.size = Vector2(332, 150)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(b)
	if with_start:
		var start_btn := _button("Start", Color(0.18, 0.55, 0.42), 18)
		start_btn.position = Vector2(100, 230)
		start_btn.size = Vector2(180, 44)
		start_btn.pressed.connect(start)
		box.add_child(start_btn)
	return wrap


func _show_card(key: String) -> void:
	for k in _cards.keys():
		_cards[k].visible = (k == key)


func _refresh_hud() -> void:
	_step_label.text = "STEPS  %d" % _steps
	_meet_label.text = "MEETS  %d" % _meets
	_pos_o_label.text = "pos  %d, %d" % [world.orange_x, world.orange_y]
	_pos_b_label.text = "pos  %d, %d" % [world.blue_x, world.blue_y]
	_face_o_label.text = "face %s | %s" % [_face_name(world.orange_face), _heading_bits(world.heading)]
	_face_b_label.text = "face %s | %s" % [_face_name(world.blue_face), _heading_bits(world.blue_heading)]
	var bits: PackedStringArray = []
	if _prev_orange_off:
		bits.append("orange off-canvas")
	if _prev_blue_off:
		bits.append("blue off-canvas")
	if _prev_overlap:
		bits.append("overlapping")
	if bits.is_empty():
		bits.append("on canvas")
	if _off_canvas_events > 0:
		bits.append("exits %d" % _off_canvas_events)
	_status_label.text = " | ".join(bits)
