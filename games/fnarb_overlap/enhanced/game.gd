extends Node2D
## Fnarbmlyx Overlap Demo (Enhanced). Presentation makeover of the Direct
## 9-box drag sketch. The demo is Direct `overlap_demo.tscn` (shared
## `overlap_demo.gd`), instanced in a 1920×1080 SubViewport — no rules copied.
## Enhanced owns the 1280×720 letterbox chrome, HUD, title card and juice
## derived from watching Direct box colours / subject / mouseXY. Esc →
## PauseOverlay. No Alchementrix IP. No new core mechanics.

const DEMO := preload("res://games/fnarb_overlap/direct/overlap_demo.tscn")
const DemoScript := preload("res://games/fnarb_overlap/direct/overlap_demo.gd")

const STAGE := Vector2(1280, 720)
## Direct demo is authored for a 1920×1080 window; show it at ½ in a clipped field.
const VP_SIZE := Vector2(1920, 1080)
const FIELD := Vector2(960, 540)
const FIELD_POS := Vector2(160, 90)

const BG_TOP := Color(0.04, 0.06, 0.10)
const BG_BOT := Color(0.10, 0.12, 0.16)
const PANEL := Color(0.10, 0.12, 0.18, 0.94)
const FRAME := Color(0.55, 0.78, 1.0)
const INK := Color(0.92, 0.95, 1.0)
const MUTED := Color(0.58, 0.64, 0.78)
const GOLD := Color(0.85, 0.65, 0.20)  ## goldenrod-ish (Direct press colour)
const ACCENT := Color(0.40, 0.70, 0.95)  ## cornflower-ish (Direct hover)
const OVERLAP_C := Color(0.55, 0.55, 0.58)
const HELD_C := Color(0.15, 0.15, 0.15)

enum { TITLE, PLAY }

var state := TITLE
var demo: ColorRect = null

## View-only presentation state (derived from Direct box colours).
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _banner_t := 0.0
var _banner := ""
var _prev_colors: Array[Color] = []
var _overlap_count := 0
var _first_overlap := false
var _drag_bursts := 0

var _vp_box: SubViewportContainer
var _viewport: SubViewport
var _fx: Node2D  ## juice above Direct SubViewport
var _ui: CanvasLayer
var _hud: Control
var _cards := {}
var _mouse_label: Label
var _subject_label: Label
var _overlap_label: Label
var _status_label: Label
var _legend_label: Label
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
	_vp_box.visible = s == PLAY
	if s == PLAY and demo == null:
		_load_demo()
	if s == PLAY:
		_banner = "DRAG TO OVERLAP"
		_banner_t = 1.8
		_flash = 0.45
		_flash_color = FRAME
		_burst(FIELD_POS + FIELD * 0.5, GOLD, 18, 220.0)
		_first_overlap = false
		_drag_bursts = 0


func _load_demo() -> void:
	demo = DEMO.instantiate() as ColorRect
	demo.set_anchors_preset(Control.PRESET_FULL_RECT)
	demo.offset_left = 0
	demo.offset_top = 0
	demo.offset_right = 0
	demo.offset_bottom = 0
	_viewport.add_child(demo)
	_snapshot_colors()
	_refresh_hud()


func _snapshot_colors() -> void:
	_prev_colors.clear()
	if demo == null:
		return
	for b in demo.boxes:
		_prev_colors.append((b as ColorRect).color)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var e := event as InputEventKey
	if state == TITLE:
		if e.keycode in [KEY_ENTER, KEY_SPACE]:
			_set_state(PLAY)
			get_viewport().set_input_as_handled()
		return
	if e.keycode == KEY_R:
		_restart()
		get_viewport().set_input_as_handled()


func _restart() -> void:
	_particles.clear()
	_floaters.clear()
	_prev_colors.clear()
	_overlap_count = 0
	_first_overlap = false
	_drag_bursts = 0
	if demo != null:
		demo.queue_free()
		demo = null
	_set_state(PLAY)


func _process(delta: float) -> void:
	_time += delta
	_shake = maxf(0.0, _shake - delta * 2.8)
	_flash = maxf(0.0, _flash - delta * 2.2)
	_banner_t = maxf(0.0, _banner_t - delta)
	_animate_fx(delta)
	if state == PLAY and demo != null:
		_watch_boxes()
		_refresh_hud()
	queue_redraw()
	if _fx:
		_fx.queue_redraw()


## Presentation only: read Direct box colours / subject and fire juice.
func _watch_boxes() -> void:
	if demo == null or demo.boxes.is_empty():
		return
	var n: int = demo.boxes.size()
	while _prev_colors.size() < n:
		_prev_colors.append(Color.WHITE)
	var overlaps := 0
	for i in n:
		var box: ColorRect = demo.boxes[i] as ColorRect
		var c: Color = box.color
		var prev: Color = _prev_colors[i]
		if not _approx_color(c, prev):
			var gp := _box_stage_pos(box)
			var juice_c := _juice_for(c)
			_burst(gp + Vector2(8, 8), juice_c, 8, 140.0)
			if c == Color.DIM_GRAY or c == Color.BLACK:
				_floater("overlap", gp + Vector2(-10, -14), OVERLAP_C)
			elif c == Color.GOLDENROD:
				_floater("grab", gp + Vector2(-6, -14), GOLD)
			elif c == Color.CORNFLOWER_BLUE:
				_floater("hover", gp + Vector2(-8, -14), ACCENT)
			_prev_colors[i] = c
			_drag_bursts += 1
		if c == Color.DIM_GRAY or c == Color.BLACK:
			overlaps += 1
	_overlap_count = overlaps
	if overlaps > 0 and not _first_overlap:
		_first_overlap = true
		_banner = "OVERLAP DETECTED"
		_banner_t = 1.5
		_flash = 0.4
		_flash_color = OVERLAP_C
		_burst(FIELD_POS + FIELD * 0.5, OVERLAP_C, 16, 180.0)
		_shake = 0.35


func _approx_color(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 \
			and absf(a.b - b.b) < 0.01 and absf(a.a - b.a) < 0.01


func _juice_for(c: Color) -> Color:
	if c == Color.CORNFLOWER_BLUE:
		return ACCENT
	if c == Color.GOLDENROD:
		return GOLD
	if c == Color.BLACK:
		return HELD_C
	if c == Color.DIM_GRAY:
		return OVERLAP_C
	return FRAME


## HUD text colour: same mapping as juice, but black/near-black stay readable on the panel.
func _hud_subject_color(c: Color) -> Color:
	if c == Color.BLACK:
		return Color(0.78, 0.80, 0.88)  ## held+overlap — not near-black on dark HUD
	if c == Color.DIM_GRAY:
		return OVERLAP_C.lightened(0.25)
	return _juice_for(c)


func _box_stage_pos(box: ColorRect) -> Vector2:
	## Map Direct 1920×1080 box coords into the ½-scale field.
	return FIELD_POS + box.position * (FIELD / VP_SIZE)


func _color_name(c: Color) -> String:
	if c == Color.WHITE:
		return "white (idle)"
	if c == Color.CORNFLOWER_BLUE:
		return "cornflower (hover)"
	if c == Color.GOLDENROD:
		return "goldenrod (held)"
	if c == Color.BLACK:
		return "black (held+overlap)"
	if c == Color.DIM_GRAY:
		return "dim gray (overlap)"
	return "custom"


func _refresh_hud() -> void:
	if _mouse_label == null:
		return
	var mouse_txt := "—"
	if demo != null and demo.has_node("mouseXY"):
		mouse_txt = str(demo.get_node("mouseXY").text)
	_mouse_label.text = "mouse\n%s" % mouse_txt
	if demo != null and demo.subject != null:
		var sub: ColorRect = demo.subject as ColorRect
		_subject_label.text = "subject\n%s\n@ %s" % [
			_color_name(sub.color),
			str(sub.position.round()),
		]
		# Keep Direct juice hues, but lift near-black held colour for HUD contrast.
		_subject_label.add_theme_color_override("font_color", _hud_subject_color(sub.color))
	else:
		_subject_label.text = "subject\n(none)"
		_subject_label.add_theme_color_override("font_color", MUTED)
	_overlap_label.text = "Overlaps\n%d / 9" % _overlap_count
	if _overlap_count > 0:
		_overlap_label.add_theme_color_override("font_color", OVERLAP_C)
		_status_label.text = "Brute-force O(n²)\noverlap pass live"
		_status_label.add_theme_color_override("font_color", GOLD)
	else:
		_overlap_label.add_theme_color_override("font_color", INK)
		_status_label.text = "Hover a box,\nthen drag it."
		_status_label.add_theme_color_override("font_color", MUTED)


# --- draw ---------------------------------------------------------------------

func _draw() -> void:
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 6.0 * _shake * _shake
	draw_rect(Rect2(Vector2.ZERO, STAGE), BG_TOP)
	for i in 24:
		var t := float(i) / 24.0
		var c := BG_TOP.lerp(BG_BOT, t)
		c.a = 0.55
		draw_rect(Rect2(0, STAGE.y * t, STAGE.x, STAGE.y / 24.0 + 1.0), c)
	draw_circle(Vector2(100, 80), 150, Color(0.20, 0.35, 0.55, 0.12))
	draw_circle(Vector2(STAGE.x - 80, STAGE.y - 60), 180, Color(0.45, 0.35, 0.15, 0.10))
	for i in 36:
		var seed := float(i * 91 + 17)
		var px := fmod(seed * 41.0, STAGE.x)
		var py := fmod(seed * 59.0, STAGE.y)
		var a := 0.12 + 0.22 * (0.5 + 0.5 * sin(_time * 1.8 + seed))
		draw_circle(Vector2(px, py), 1.2, Color(0.75, 0.85, 1.0, a))
	if state == PLAY:
		var fr := Rect2(FIELD_POS + shake - Vector2(14, 14), FIELD + Vector2(28, 28))
		draw_rect(fr, Color(0.06, 0.07, 0.10))
		draw_rect(fr.grow(-5), Color(FRAME.r, FRAME.g, FRAME.b, 0.55), false, 2.0)
		var corner := Color(GOLD.r, GOLD.g, GOLD.b, 0.7)
		draw_rect(Rect2(fr.position, Vector2(28, 3)), corner)
		draw_rect(Rect2(fr.position, Vector2(3, 28)), corner)
		draw_rect(Rect2(fr.end - Vector2(28, 3), Vector2(28, 3)), corner)
		draw_rect(Rect2(fr.end - Vector2(3, 28), Vector2(3, 28)), corner)


## Overlay above the Direct SubViewport (child drawn after DemoView).
func _draw_fx() -> void:
	if state == PLAY and demo != null:
		for box in demo.boxes:
			var b: ColorRect = box as ColorRect
			var gp := _box_stage_pos(b) + Vector2(8, 8)
			var jc := _juice_for(b.color)
			jc.a = 0.22 if b.color != Color.WHITE else 0.08
			_fx.draw_circle(gp, 14.0, jc)
	if _flash > 0.0:
		var fc := _flash_color
		fc.a = _flash * 0.28
		_fx.draw_rect(Rect2(Vector2.ZERO, STAGE), fc)
	for p in _particles:
		var col: Color = p.color
		col.a *= clampf(p.life / p.max, 0.0, 1.0)
		_fx.draw_circle(p.pos, p.size, col)
	for f in _floaters:
		var col2: Color = f.color
		col2.a *= clampf(f.life / f.max, 0.0, 1.0)
		_fx.draw_string(_font, f.pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(f.size), col2)
	if _banner_t > 0.0 and _banner != "":
		var a := clampf(_banner_t, 0.0, 1.0)
		var r := Rect2(STAGE.x * 0.5 - 200, 28, 400, 34)
		_fx.draw_rect(r, Color(0.05, 0.06, 0.10, 0.78 * a))
		_fx.draw_string(_font, r.position + Vector2(r.size.x * 0.5 - _banner.length() * 5.0, 8),
				_banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(GOLD.r, GOLD.g, GOLD.b, a))


func _draw_label(text: String, pos: Vector2, size: int, color: Color) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# --- FX helpers ---------------------------------------------------------------

func _burst(at: Vector2, color: Color, n: int, speed: float) -> void:
	for i in n:
		var ang := randf() * TAU
		var sp := randf_range(0.3, 1.0) * speed
		_particles.append({
			"pos": at,
			"vel": Vector2(cos(ang), sin(ang)) * sp,
			"life": randf_range(0.35, 0.7),
			"max": 0.7,
			"color": color,
			"size": randf_range(2.0, 5.0),
			"grav": 20.0,
		})


func _floater(text: String, at: Vector2, color: Color) -> void:
	_floaters.append({
		"pos": at,
		"life": 1.0,
		"max": 1.0,
		"text": text,
		"color": color,
		"size": 14.0,
	})


func _animate_fx(delta: float) -> void:
	var i := 0
	while i < _particles.size():
		var p: Dictionary = _particles[i]
		p.life -= delta
		p.pos += p.vel * delta
		p.vel.y += p.grav * delta
		p.vel *= 0.96
		if p.life <= 0.0:
			_particles.remove_at(i)
		else:
			_particles[i] = p
			i += 1
	i = 0
	while i < _floaters.size():
		var f: Dictionary = _floaters[i]
		f.life -= delta
		f.pos.y -= 24.0 * delta
		if f.life <= 0.0:
			_floaters.remove_at(i)
		else:
			_floaters[i] = f
			i += 1


# --- UI build -----------------------------------------------------------------

func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "DirectVP"
	_viewport.size = Vector2i(VP_SIZE)
	_viewport.transparent_bg = false
	_viewport.handle_input_locally = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.own_world_3d = true
	_viewport.gui_disable_input = false

	# Native 1920×1080 Direct demo, shown at ½ via Control.scale (not stretch).
	# stretch=true would resize the SubViewport to the field and break VP_SIZE / juice math.
	_vp_box = SubViewportContainer.new()
	_vp_box.name = "DemoView"
	_vp_box.position = FIELD_POS
	_vp_box.size = VP_SIZE
	_vp_box.stretch = false
	_vp_box.scale = FIELD / VP_SIZE
	_vp_box.visible = false
	_vp_box.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_vp_box.add_child(_viewport)

	var stage_host := Control.new()
	stage_host.name = "StageHost"
	stage_host.size = STAGE
	stage_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage_host)
	stage_host.add_child(_vp_box)

	# Juice (particles / halos / floaters / banner) above Direct's solid background.
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

	var left_top := _panel(Rect2(16, 18, 130, 64))
	_hud.add_child(left_top)
	left_top.add_child(_label("FNARB", 18, GOLD, Vector2(12, 8)))
	left_top.add_child(_label("OVERLAP", 16, GOLD, Vector2(12, 32)))

	var left := _panel(Rect2(16, 96, 130, 300))
	_hud.add_child(left)
	left.add_child(_label("LIVE", 11, MUTED, Vector2(10, 10)))
	_mouse_label = _label("mouse\n—", 12, INK, Vector2(10, 32))
	left.add_child(_mouse_label)
	_subject_label = _label("subject\n(none)", 11, MUTED, Vector2(10, 90))
	_subject_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subject_label.size = Vector2(110, 70)
	left.add_child(_subject_label)
	_overlap_label = _label("Overlaps\n0 / 9", 13, INK, Vector2(10, 175))
	left.add_child(_overlap_label)
	_status_label = _label("Hover a box,\nthen drag it.", 11, MUTED, Vector2(10, 230))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size = Vector2(110, 50)
	left.add_child(_status_label)

	var controls := _panel(Rect2(16, 410, 130, 140))
	_hud.add_child(controls)
	controls.add_child(_label("CONTROLS", 11, MUTED, Vector2(10, 10)))
	controls.add_child(_label("Hover / drag\nR  Replay\nEsc  Pause", 12, INK, Vector2(10, 34)))

	var right := _panel(Rect2(1134, 96, 130, 340))
	_hud.add_child(right)
	right.add_child(_label("COLOURS", 11, MUTED, Vector2(10, 10)))
	_legend_label = _label(
		"white  idle\nblue   hover\ngold   held\nblack  held+\n       overlap\ngray   overlap",
		11, INK, Vector2(10, 34))
	right.add_child(_legend_label)
	right.add_child(_label(
		"Same Direct\noverlap_demo.gd\n3×3 of 32×32\nboxes. O(n²)\ncolorize.",
		11, MUTED, Vector2(10, 200)))

	var back := _btn("Back to Arcade", Vector2(16, 660), Vector2(160, 36))
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(GameRegistry.return_to_arcade)
	_hud.add_child(back)

	# Title card
	var card := _panel(Rect2(STAGE.x * 0.5 - 300, STAGE.y * 0.5 - 160, 600, 320))
	card.name = "TitleCard"
	_ui.add_child(card)
	_cards["title"] = card
	card.add_child(_label("FNARB OVERLAP", 28, GOLD, Vector2(36, 36)))
	card.add_child(_label("Enhanced edition", 16, ACCENT, Vector2(36, 80)))
	card.add_child(_label(
		"A chrome shell over the Direct 9-box overlap sketch.\nSame hover / drag / O(n²) colorize — just clearer\nHUD + juice when boxes collide.",
		14, INK, Vector2(36, 120)))
	var start := _btn("Start", Vector2(36, 230), Vector2(120, 40))
	start.focus_mode = Control.FOCUS_NONE
	start.pressed.connect(func(): _set_state(PLAY))
	card.add_child(start)
	card.add_child(_label("Enter / Space  to begin", 14, MUTED, Vector2(180, 240)))

	var title_back := _btn("Back to Arcade", Vector2(36, 280), Vector2(160, 32))
	title_back.focus_mode = Control.FOCUS_NONE
	title_back.pressed.connect(GameRegistry.return_to_arcade)
	card.add_child(title_back)


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
		var base := Color(0.14, 0.20, 0.32)
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
