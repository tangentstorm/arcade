extends Node2D
## Flappy Clone (Enhanced). Draws flappy_enhanced_logic.gd procedurally on a
## 1280x720 stage (letterbox), with parallax sky, tilt and squash on the bird,
## a score pop, and a soft landing before the Game Over panel.
## Esc is handled globally by the PauseOverlay autoload.

const Logic := preload("res://games/flappy_clone/enhanced/flappy_enhanced_logic.gd")
const STAGE := Vector2(1280, 720)
const PX := 720.0 / 6.72
const SAVE_PATH := "user://flappy_clone_enhanced.cfg"

const SKY_TOP := Color(0.22, 0.47, 0.86)
const SKY_HORIZON := Color(0.99, 0.80, 0.62)
const CLOUD := Color(1, 1, 1, 0.85)
const CITY := Color(0.55, 0.62, 0.86)
const CITY_WINDOW := Color(0.98, 0.92, 0.70, 0.55)
const HILL := Color(0.42, 0.72, 0.45)
const HILL_DARK := Color(0.33, 0.62, 0.40)
const GRASS := Color(0.47, 0.80, 0.30)
const GRASS_STRIPE := Color(0.40, 0.72, 0.25)
const DIRT := Color(0.87, 0.72, 0.47)
const DIRT_DARK := Color(0.78, 0.62, 0.40)
const PIPE := Color(0.38, 0.76, 0.30)
const PIPE_LIGHT := Color(0.62, 0.90, 0.45)
const PIPE_SHADE := Color(0.26, 0.58, 0.22)
const PIPE_EDGE := Color(0.14, 0.33, 0.14)
const BIRD := Color(1.0, 0.80, 0.18)
const BIRD_BELLY := Color(1.0, 0.93, 0.62)
const BIRD_WING := Color(0.98, 0.62, 0.15)
const BIRD_EDGE := Color(0.35, 0.20, 0.08)
const BEAK := Color(0.98, 0.42, 0.16)
const GOLD := Color(1.0, 0.85, 0.30)

var logic := Logic.new()
var _tilt := 0.0
var _squash := 0.0
var _wing := 0.0
var _shake := 0.0
var _puffs: Array[Dictionary] = []   ## {pos, vel, r, life, max}
var _pipe_style := StyleBoxFlat.new()
var _cap_style := StyleBoxFlat.new()

var _ui: CanvasLayer
var _score_label: Label
var _hint: Label
var _title_panel: Control
var _over_panel: Control
var _over_score: Label
var _over_best: Label
var _new_best: Label
var _retry_hint: Label
var _flash: ColorRect
var _score_tween: Tween
var _last_state := -1


func _ready() -> void:
	logic.rng.randomize()
	logic.best = _load_best()
	for s in [_pipe_style, _cap_style]:
		s.bg_color = PIPE
		s.border_color = PIPE_EDGE
		s.set_border_width_all(4)
		s.set_corner_radius_all(6)
	_cap_style.set_corner_radius_all(10)
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var size := get_viewport_rect().size
	var s := minf(size.x / STAGE.x, size.y / STAGE.y)
	scale = Vector2(s, s)
	position = (size - STAGE * s) * 0.5


func _process(delta: float) -> void:
	logic.update(delta)
	for ev in logic.take_events():
		_on_event(ev)
	if logic.state != _last_state:
		_last_state = logic.state
		_on_state_changed()
	_animate(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo \
			and event.keycode in [KEY_SPACE, KEY_UP, KEY_W, KEY_ENTER]
	elif event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if pressed:
		logic.press()
		get_viewport().set_input_as_handled()


func _on_event(ev: StringName) -> void:
	match ev:
		&"flap":
			_squash = 1.0
			_wing = 0.0
			for i in 3:
				_puff(logic.bird_pos + Vector2(-0.25, -0.05),
					Vector2(randf_range(-1.6, -0.8), randf_range(-0.8, 0.2)), 0.07, 0.35)
		&"score":
			_pop_score()
		&"hit":
			_shake = 1.0
			_flash.color.a = 0.7
		&"land":
			for i in 6:
				_puff(Vector2(logic.bird_pos.x, Logic.FLOOR_TOP),
					Vector2(randf_range(-1.5, 1.5), randf_range(0.2, 1.0)), 0.09, 0.5)
		&"over":
			if logic.new_best:
				_save_best(logic.best)
		&"ready":
			_tilt = 0.0


func _animate(delta: float) -> void:
	var target := 0.0
	match logic.state:
		Logic.State.PLAY:
			target = clampf(-logic.bird_vy * 0.13, -0.45, 1.35)
		Logic.State.DYING, Logic.State.OVER:
			target = 1.45
	_tilt = lerpf(_tilt, target, 1.0 - exp(-delta * 10.0))
	_squash = move_toward(_squash, 0.0, delta * 5.0)
	_shake = move_toward(_shake, 0.0, delta * 3.0)
	_flash.color.a = move_toward(_flash.color.a, 0.0, delta * 2.5)
	var flapping := logic.state in [Logic.State.TITLE, Logic.State.READY, Logic.State.PLAY]
	_wing += delta * (18.0 if flapping else 0.0)
	for p in _puffs:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.92
	_puffs = _puffs.filter(func(p): return p.life > 0.0)
	_retry_hint.visible = logic.can_restart()
	_hint.modulate.a = 0.6 + 0.4 * sin(logic.time * 4.0)


func _puff(pos: Vector2, vel: Vector2, r: float, life: float) -> void:
	_puffs.append({"pos": pos, "vel": vel, "r": r, "life": life, "max": life})


func _pop_score() -> void:
	_score_label.text = str(logic.score)
	_score_label.pivot_offset = _score_label.size * 0.5
	if _score_tween:
		_score_tween.kill()
	_score_label.scale = Vector2(1.45, 1.45)
	_score_label.modulate = GOLD
	_score_tween = create_tween().set_parallel()
	_score_tween.tween_property(_score_label, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_score_tween.tween_property(_score_label, "modulate", Color.WHITE, 0.4)


func _on_state_changed() -> void:
	var st := logic.state
	_title_panel.visible = st == Logic.State.TITLE
	_hint.visible = st == Logic.State.READY
	_score_label.visible = st in [Logic.State.PLAY, Logic.State.DYING]
	_score_label.text = str(logic.score)
	if st == Logic.State.OVER:
		_over_score.text = str(logic.score)
		_over_best.text = str(logic.best)
		_new_best.visible = logic.new_best
		_over_panel.visible = true
		_over_panel.modulate.a = 0.0
		_over_panel.position.y = 60.0
		var tw := create_tween().set_parallel()
		tw.tween_property(_over_panel, "position:y", 0.0, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_over_panel, "modulate:a", 1.0, 0.25)
	else:
		_over_panel.visible = false


# --- drawing (world units, +y up, origin at stage center) -------------------

static func _px(u: Vector2) -> Vector2:
	return Vector2(STAGE.x * 0.5 + u.x * PX, STAGE.y * 0.5 - u.y * PX)


## Deterministic 0..1 noise per (tile, salt) so parallax tiles never shimmer.
static func _hash01(i: int, salt: int) -> float:
	var h := hash(Vector2i(i, salt))
	return float(h & 0xffff) / 65535.0


func _draw() -> void:
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0 * _shake * _shake
	draw_set_transform(shake)
	_draw_sky()
	_draw_clouds(logic.scroll * 0.08)
	_draw_city(logic.scroll * 0.25)
	_draw_hills(logic.scroll * 0.5)
	for g in logic.gates:
		_draw_gate(g)
	_draw_ground(logic.scroll)
	for p in _puffs:
		var a: float = p.life / p.max
		draw_circle(_px(p.pos), p.r * PX * (1.6 - a * 0.6), Color(1, 1, 1, 0.8 * a))
	_draw_bird(shake)


func _draw_sky() -> void:
	var m := 400.0
	var pts := PackedVector2Array([Vector2(-m, -m), Vector2(STAGE.x + m, -m),
		Vector2(STAGE.x + m, STAGE.y + m), Vector2(-m, STAGE.y + m)])
	draw_polygon(pts, PackedColorArray([SKY_TOP, SKY_TOP, SKY_HORIZON, SKY_HORIZON]))
	var sun := Vector2(STAGE.x * 0.78, STAGE.y * 0.30)
	for i in 4:
		draw_circle(sun, 70.0 + i * 26.0, Color(1, 0.95, 0.75, 0.10))
	draw_circle(sun, 56.0, Color(1, 0.96, 0.80))


func _tiles(off: float, spacing: float) -> Array[int]:
	var hw := STAGE.x * 0.5 / PX + 4.0
	var out: Array[int] = []
	for k in range(int(floor((off - hw) / spacing)), int(ceil((off + hw) / spacing)) + 1):
		out.append(k)
	return out


func _draw_clouds(off: float) -> void:
	for k in _tiles(off, 3.5):
		var c := Vector2(k * 3.5 - off + _hash01(k, 1) * 1.5, 1.4 + _hash01(k, 2) * 1.5)
		var s := 0.35 + _hash01(k, 3) * 0.3
		for b in [Vector3(0, 0, 1), Vector3(-0.9, -0.15, 0.75), Vector3(0.9, -0.2, 0.7),
				Vector3(0.4, 0.35, 0.7)]:
			draw_circle(_px(c + Vector2(b.x, b.y) * s), b.z * s * PX, CLOUD)


func _draw_city(off: float) -> void:
	var base := Logic.FLOOR_TOP + 0.4
	for k in _tiles(off, 1.1):
		var w := 0.7 + _hash01(k, 4) * 0.3
		var h := 1.0 + _hash01(k, 5) * 2.2
		var x := k * 1.1 - off
		var tl := _px(Vector2(x, base + h))
		var rect := Rect2(tl, Vector2(w * PX, h * PX))
		draw_rect(rect, CITY)
		for wy in range(int(h / 0.32)):
			for wx in 2:
				if _hash01(k * 31 + wy, wx + 7) > 0.55:
					draw_rect(Rect2(tl + Vector2((0.14 + wx * 0.3) * PX, (0.18 + wy * 0.32) * PX),
						Vector2(0.12 * PX, 0.14 * PX)), CITY_WINDOW)


func _draw_hills(off: float) -> void:
	for k in _tiles(off, 2.4):
		var x := k * 2.4 - off + _hash01(k, 8) * 0.8
		var r := 1.0 + _hash01(k, 9) * 0.7
		var col := HILL if k % 2 == 0 else HILL_DARK
		draw_circle(_px(Vector2(x, Logic.FLOOR_TOP - r * 0.45)), r * PX, col)


func _draw_gate(g) -> void:
	var w := Logic.PIPE_HALF_W * 2.0 * PX
	var cap_w := w + 0.22 * PX
	var cap_h := 0.36 * PX
	var top_y := _px(Vector2(0, g.gap_y + Logic.GAP_HALF)).y
	var bot_y := _px(Vector2(0, g.gap_y - Logic.GAP_HALF)).y
	var cx := _px(Vector2(g.x, 0)).x
	var floor_y := _px(Vector2(0, Logic.FLOOR_TOP)).y
	for r in [Rect2(cx - w * 0.5, -40.0, w, top_y + 40.0),
			Rect2(cx - w * 0.5, bot_y, w, floor_y - bot_y + 10.0)]:
		draw_style_box(_pipe_style, r)
		draw_rect(Rect2(r.position.x + w * 0.16, r.position.y, w * 0.14, r.size.y), PIPE_LIGHT)
		draw_rect(Rect2(r.position.x + w * 0.72, r.position.y, w * 0.18, r.size.y), PIPE_SHADE)
	for y in [top_y - cap_h, bot_y]:
		var r := Rect2(cx - cap_w * 0.5, y, cap_w, cap_h)
		draw_style_box(_cap_style, r)
		draw_rect(Rect2(r.position.x + cap_w * 0.16, y + 6.0, cap_w * 0.12, cap_h - 12.0), PIPE_LIGHT)


func _draw_ground(off: float) -> void:
	var top := _px(Vector2(0, Logic.FLOOR_TOP)).y
	draw_rect(Rect2(-400, top, STAGE.x + 800, STAGE.y - top + 400), DIRT)
	draw_rect(Rect2(-400, top, STAGE.x + 800, 22), GRASS)
	var stripe := 0.5 * PX
	var shift := fposmod(off * PX, stripe * 2.0)
	var x := -400.0 - shift
	while x < STAGE.x + 400:
		draw_colored_polygon(PackedVector2Array([Vector2(x, top + 22), Vector2(x + stripe, top + 22),
			Vector2(x + stripe + 12, top), Vector2(x + 12, top)]), GRASS_STRIPE)
		x += stripe * 2.0
	draw_rect(Rect2(-400, top + 22, STAGE.x + 800, 6), DIRT_DARK)
	draw_line(Vector2(-400, top), Vector2(STAGE.x + 400, top), PIPE_EDGE.darkened(0.2), 3.0)


func _draw_bird(shake: Vector2) -> void:
	if logic.state == Logic.State.TITLE:
		return
	var r := Logic.BIRD_RADIUS * PX
	var sq := Vector2(1.0 - 0.18 * _squash, 1.0 + 0.18 * _squash)
	draw_set_transform(shake + _px(logic.bird_pos), _tilt, sq)
	draw_circle(Vector2(2, 4), r * 1.08, Color(0, 0, 0, 0.15))
	draw_circle(Vector2.ZERO, r * 1.08, BIRD_EDGE)
	draw_circle(Vector2.ZERO, r, BIRD)
	draw_circle(Vector2(r * 0.15, r * 0.35), r * 0.62, BIRD_BELLY)
	var flap := sin(_wing) * 0.5 if logic.state != Logic.State.OVER else 0.4
	var wing := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		wing.append(Vector2(cos(a) * r * 0.55, sin(a) * r * 0.32).rotated(flap) + Vector2(-r * 0.35, r * 0.05))
	draw_colored_polygon(wing, BIRD_WING)
	draw_polyline(wing + PackedVector2Array([wing[0]]), BIRD_EDGE, 2.5)
	draw_circle(Vector2(r * 0.45, -r * 0.35), r * 0.34, Color.WHITE)
	draw_arc(Vector2(r * 0.45, -r * 0.35), r * 0.34, 0, TAU, 16, BIRD_EDGE, 2.0)
	if logic.state in [Logic.State.DYING, Logic.State.OVER]:
		var e := Vector2(r * 0.52, -r * 0.35)
		var d := r * 0.14
		draw_line(e - Vector2(d, d), e + Vector2(d, d), BIRD_EDGE, 3.0)
		draw_line(e - Vector2(d, -d), e + Vector2(d, -d), BIRD_EDGE, 3.0)
	else:
		draw_circle(Vector2(r * 0.55, -r * 0.33), r * 0.14, Color(0.1, 0.06, 0.04))
	draw_colored_polygon(PackedVector2Array([Vector2(r * 0.75, -r * 0.05),
		Vector2(r * 1.35, r * 0.12), Vector2(r * 0.75, r * 0.35)]), BEAK)
	draw_set_transform(Vector2.ZERO)


# --- UI ----------------------------------------------------------------------

func _label(text: String, size: int, outline := 8) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.18, 0.12, 0.10))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 28)
	for state in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = color.lightened(0.12) if state == "hover" else color.darkened(0.1) if state == "pressed" else color
		s.border_color = Color(0.18, 0.12, 0.10)
		s.set_border_width_all(4)
		s.border_width_bottom = 8 if state != "pressed" else 4
		s.set_corner_radius_all(14)
		s.content_margin_left = 36
		s.content_margin_right = 36
		s.content_margin_top = 10
		s.content_margin_bottom = 12
		b.add_theme_stylebox_override(state, s)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0.18, 0.12, 0.10))
	b.add_theme_constant_override("outline_size", 6)
	return b


func _panel_box() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.99, 0.94, 0.80)
	s.border_color = Color(0.18, 0.12, 0.10)
	s.set_border_width_all(5)
	s.set_corner_radius_all(22)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 12
	s.shadow_offset = Vector2(0, 6)
	s.set_content_margin_all(28)
	p.add_theme_stylebox_override("panel", s)
	return p


func _centered(parent: Control) -> VBoxContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	c.add_child(v)
	return v


func _full_rect() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.get_child(0).add_child(c)
	return c


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)

	_score_label = _label("0", 84, 14)
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_score_label.offset_left = -150
	_score_label.offset_right = 150
	_score_label.offset_top = 36
	_score_label.offset_bottom = 136
	root.add_child(_score_label)

	_hint = _label("space / click / tap to flap", 30)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -300
	_hint.offset_right = 300
	_hint.offset_top = -210
	_hint.offset_bottom = -160
	root.add_child(_hint)

	_title_panel = _full_rect()
	var tv := _centered(_title_panel)
	tv.add_child(_label("Flappy Clone", 96, 18))
	var sub := _label("ENHANCED", 30, 8)
	sub.add_theme_color_override("font_color", GOLD)
	tv.add_child(sub)
	var play := _button("Play", Color(0.95, 0.55, 0.20))
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(logic.press)
	tv.add_child(play)
	var best := _label("best %d" % logic.best, 24, 6)
	best.visible = logic.best > 0
	tv.add_child(best)

	_over_panel = _full_rect()
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.10, 0.06, 0.12, 0.30)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over_panel.add_child(shade)
	var ov := _centered(_over_panel)
	ov.add_child(_label("Game Over", 80, 16))
	var box := _panel_box()
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ov.add_child(box)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 60)
	box.add_child(grid)
	for caption in ["SCORE", "BEST"]:
		var cap := _label(caption, 22, 0)
		cap.add_theme_color_override("font_color", Color(0.85, 0.45, 0.20))
		grid.add_child(cap)
	_over_score = _label("0", 56, 10)
	_over_best = _label("0", 56, 10)
	grid.add_child(_over_score)
	grid.add_child(_over_best)
	_new_best = _label("New best!", 30, 8)
	_new_best.add_theme_color_override("font_color", GOLD)
	ov.add_child(_new_best)
	var again := _button("Play again", Color(0.95, 0.55, 0.20))
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(logic.press)
	ov.add_child(again)
	_retry_hint = _label("or press space / tap", 22, 6)
	ov.add_child(_retry_hint)

	var back := _button("Back to Arcade", Color(0.30, 0.42, 0.75))
	back.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed"]:
		var s: StyleBoxFlat = back.get_theme_stylebox(state)
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 6
		s.content_margin_bottom = 8
	back.position = Vector2(14, 12)
	back.pressed.connect(GameRegistry.return_to_arcade)
	root.add_child(back)


func _load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0
	return int(cfg.get_value("flappy", "best", 0))


func _save_best(value: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("flappy", "best", value)
	cfg.save(SAVE_PATH)
