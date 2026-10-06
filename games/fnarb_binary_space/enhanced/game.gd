extends Node2D
## Fnarbmlyx Binary Space (Enhanced). Presentation makeover of the Direct
## 5-input truth-table space sketch. The demo is Direct `binary_space.tscn`
## (shared `truth_table.gd` / `shaded_grid.gd`), instanced in a 1920×1080
## SubViewport — no rules copied. Enhanced owns the 1280×720 letterbox chrome,
## HUD, title card and juice derived from watching Direct row bits / modulate.
## Esc → PauseOverlay. No Alchementrix IP. No new core mechanics.

const DEMO := preload("res://games/fnarb_binary_space/direct/binary_space.tscn")
const TruthScript := preload("res://games/fnarb_binary_space/direct/truth_table.gd")
const GridScript := preload("res://games/fnarb_binary_space/direct/shaded_grid.gd")

const STAGE := Vector2(1280, 720)
## Direct demo is authored for a 1920×1080 window; show it at ½ in a clipped field.
const VP_SIZE := Vector2(1920, 1080)
const FIELD := Vector2(960, 540)
const FIELD_POS := Vector2(160, 90)

const BG_TOP := Color(0.03, 0.06, 0.12)
const BG_BOT := Color(0.06, 0.10, 0.18)
const PANEL := Color(0.08, 0.12, 0.22, 0.94)
const FRAME := Color(0.40, 0.78, 1.0)
const INK := Color(0.92, 0.95, 1.0)
const MUTED := Color(0.55, 0.64, 0.82)
const GOLD := Color(1.0, 0.84, 0.32)
const ACCENT := Color(0.45, 0.90, 0.78)
const ROW_C := Color(0.55, 0.82, 1.0)
const FADE_C := Color(0.70, 0.55, 0.95)

enum { TITLE, PLAY }

var state := TITLE
var demo: Node2D = null
var rows: VBoxContainer = null
var hidden_box: VBoxContainer = null
var bg: ColorRect = null
var camera: Camera2D = null

## View-only presentation state.
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _banner_t := 0.0
var _banner := ""
var _scan_row := -1
var _scan_acc := 0.0
var _reveal_t := 0.0
var _lit_count := 0
var _faded_count := 0
var _revealed := false

var _vp_box: SubViewportContainer
var _viewport: SubViewport
var _ui: CanvasLayer
var _hud: Control
var _cards := {}
var _row_label: Label
var _bits_label: Label
var _lit_label: Label
var _status_label: Label
var _pattern_label: Label
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
		_banner = "5-INPUT TRUTH SPACE"
		_banner_t = 1.8
		_reveal_t = 0.0
		_scan_row = -1
		_scan_acc = 0.0
		_revealed = false
		_flash = 0.55
		_flash_color = FRAME
		_burst(FIELD_POS + FIELD * 0.5, GOLD, 24, 260.0)


func _load_demo() -> void:
	demo = DEMO.instantiate() as Node2D
	_viewport.add_child(demo)
	bg = demo.get_node("bg") as ColorRect
	camera = demo.get_node("Camera2D") as Camera2D
	hidden_box = demo.get_node("VBoxContainer") as VBoxContainer
	rows = demo.get_node("VBoxContainer2") as VBoxContainer
	_count_rows()
	_refresh_hud()


func _count_rows() -> void:
	_lit_count = 0
	_faded_count = 0
	if rows == null:
		return
	for child in rows.get_children():
		if not (child is Control):
			continue
		if child.modulate.a < 0.5:
			_faded_count += 1
		else:
			_lit_count += 1


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
	if demo != null:
		demo.queue_free()
		demo = null
		rows = null
		hidden_box = null
		bg = null
		camera = null
	_set_state(PLAY)


func _process(delta: float) -> void:
	_time += delta
	_shake = maxf(0.0, _shake - delta * 2.8)
	_flash = maxf(0.0, _flash - delta * 2.2)
	_banner_t = maxf(0.0, _banner_t - delta)
	_animate_fx(delta)
	if state == PLAY and demo != null:
		_reveal_t += delta
		_scan_rows(delta)
		_refresh_hud()
	queue_redraw()


## Presentation scan: walk lit/faded rows and fire juice (does not touch Direct).
func _scan_rows(delta: float) -> void:
	if rows == null:
		return
	var n := rows.get_child_count()
	if n <= 0:
		return
	_scan_acc += delta
	# ~18 rows/sec so a full pass takes under 2 s.
	var step := 1.0 / 18.0
	while _scan_acc >= step:
		_scan_acc -= step
		var next := (_scan_row + 1) % n
		if next == 0 and _scan_row >= 0 and not _revealed:
			_revealed = true
			_banner = "SIERPINSKI PATTERN"
			_banner_t = 1.6
			_burst(FIELD_POS + FIELD * 0.5, ACCENT, 18, 200.0)
			_floater("32 rows", FIELD_POS + Vector2(FIELD.x * 0.5 - 40, 48), GOLD)
		_scan_row = next
		var row: Control = rows.get_child(_scan_row) as Control
		if row == null:
			continue
		var gp := _row_stage_pos(_scan_row)
		var bright := row.modulate.a >= 0.5
		if bright:
			_burst(gp, ROW_C, 6, 120.0)
			if _is_pow2(_scan_row) or _scan_row == 0:
				_floater("row %d" % _scan_row, gp + Vector2(-20, -10), GOLD)
		else:
			_burst(gp, FADE_C, 3, 70.0)


func _is_pow2(v: int) -> bool:
	return v > 0 and (v & (v - 1)) == 0


func _row_stage_pos(i: int) -> Vector2:
	# VBoxContainer2 sits at (416, 32)–(1440, 1056) in the Direct 1920×1080 stage.
	var local := Vector2(416.0 + 512.0, 32.0 + float(i) * 32.0 + 16.0)
	var u := local / VP_SIZE
	return FIELD_POS + Vector2(u.x * FIELD.x, u.y * FIELD.y)


func _row_bits(i: int) -> int:
	if rows == null or i < 0 or i >= rows.get_child_count():
		return 0
	var row: Control = rows.get_child(i) as Control
	if row == null:
		return 0
	return int(row.get("bits"))


func _bits_string(bits: int, nvars: int = 5) -> String:
	var w := 1 << nvars
	var s := ""
	for i in range(w - 1, -1, -1):
		s += "1" if (bits & (1 << i)) != 0 else "0"
	return s


func _refresh_hud() -> void:
	if _row_label == null:
		return
	var n := rows.get_child_count() if rows else 0
	var idx := clampi(_scan_row, 0, maxi(n - 1, 0))
	var bits := _row_bits(idx) if n > 0 else 0
	var faded := false
	if rows and n > 0:
		var row: Control = rows.get_child(idx) as Control
		if row:
			faded = row.modulate.a < 0.5
	_row_label.text = "Scan row  %d / %d" % [idx, maxi(n - 1, 0)]
	_bits_label.text = "bits  %d\n%s" % [bits, _bits_string(bits)]
	_lit_label.text = "Bright  %d\nFaded   %d" % [_lit_count, _faded_count]
	_pattern_label.text = "nvars = 5\n32 × 32 cells\nConjunctions of\nx₀…x₄"
	if faded:
		_status_label.text = "Non-power-of-two\nrow (25% fade)"
		_status_label.add_theme_color_override("font_color", FADE_C)
	else:
		_status_label.text = "Power-of-two /\nfull row (lit)"
		_status_label.add_theme_color_override("font_color", ACCENT)


# --- draw ---------------------------------------------------------------------

func _draw() -> void:
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 6.0 * _shake * _shake
	draw_rect(Rect2(Vector2.ZERO, STAGE), BG_TOP)
	for i in 24:
		var t := float(i) / 24.0
		var c := BG_TOP.lerp(BG_BOT, t)
		c.a = 0.55
		draw_rect(Rect2(0, STAGE.y * t, STAGE.x, STAGE.y / 24.0 + 1.0), c)
	# Soft orbs echoing the shaded-grid blue
	draw_circle(Vector2(90, 70), 160, Color(0.12, 0.28, 0.48, 0.14))
	draw_circle(Vector2(STAGE.x - 70, STAGE.y - 50), 200, Color(0.20, 0.18, 0.45, 0.12))
	# Twinkle dots
	for i in 40:
		var seed := float(i * 97 + 13)
		var px := fmod(seed * 37.0, STAGE.x)
		var py := fmod(seed * 53.0, STAGE.y)
		var a := 0.15 + 0.25 * (0.5 + 0.5 * sin(_time * 2.0 + seed))
		draw_circle(Vector2(px, py), 1.2, Color(0.7, 0.85, 1.0, a))
	if state == PLAY:
		var fr := Rect2(FIELD_POS + shake - Vector2(14, 14), FIELD + Vector2(28, 28))
		draw_rect(fr, Color(0.05, 0.08, 0.14))
		draw_rect(fr.grow(-5), Color(FRAME.r, FRAME.g, FRAME.b, 0.55), false, 2.0)
		var corner := Color(GOLD.r, GOLD.g, GOLD.b, 0.7)
		draw_rect(Rect2(fr.position, Vector2(28, 3)), corner)
		draw_rect(Rect2(fr.position, Vector2(3, 28)), corner)
		draw_rect(Rect2(fr.end - Vector2(28, 3), Vector2(28, 3)), corner)
		draw_rect(Rect2(fr.end - Vector2(3, 28), Vector2(3, 28)), corner)
		# Scan highlight bar over the active row (presentation only).
		if _scan_row >= 0 and rows != null:
			var gp := _row_stage_pos(_scan_row)
			var bar := Rect2(FIELD_POS.x + 8, gp.y - 8, FIELD.x - 16, 16)
			draw_rect(bar, Color(FRAME.r, FRAME.g, FRAME.b, 0.18))
			draw_rect(bar, Color(GOLD.r, GOLD.g, GOLD.b, 0.55), false, 1.5)
	if _flash > 0.0:
		var fc := _flash_color
		fc.a = _flash * 0.30
		draw_rect(Rect2(Vector2.ZERO, STAGE), fc)
	for p in _particles:
		var col: Color = p.color
		col.a *= clampf(p.life / p.max, 0.0, 1.0)
		draw_circle(p.pos, p.size, col)
	for f in _floaters:
		var col: Color = f.color
		col.a *= clampf(f.life / f.max, 0.0, 1.0)
		_draw_label(f.text, f.pos, int(f.size), col)
	if _banner_t > 0.0 and _banner != "":
		var a := clampf(_banner_t, 0.0, 1.0)
		var r := Rect2(STAGE.x * 0.5 - 220, 28, 440, 34)
		draw_rect(r, Color(0.05, 0.06, 0.12, 0.78 * a))
		_draw_label(_banner, r.position + Vector2(r.size.x * 0.5 - _banner.length() * 5.0, 8),
				17, Color(GOLD.r, GOLD.g, GOLD.b, a))


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
		"size": 16.0,
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

	_vp_box = SubViewportContainer.new()
	_vp_box.name = "DemoView"
	_vp_box.position = FIELD_POS
	_vp_box.size = FIELD
	_vp_box.stretch = true
	_vp_box.visible = false
	_vp_box.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_vp_box.add_child(_viewport)

	var stage_host := Control.new()
	stage_host.name = "StageHost"
	stage_host.size = STAGE
	stage_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage_host)
	stage_host.add_child(_vp_box)


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
	left_top.add_child(_label("BINARY", 18, GOLD, Vector2(12, 8)))
	left_top.add_child(_label("SPACE", 18, GOLD, Vector2(12, 30)))

	var left := _panel(Rect2(16, 96, 130, 280))
	_hud.add_child(left)
	left.add_child(_label("SCAN", 11, MUTED, Vector2(10, 10)))
	_row_label = _label("Scan row  —", 13, INK, Vector2(10, 32))
	left.add_child(_row_label)
	_bits_label = _label("bits  —", 11, ROW_C, Vector2(10, 60))
	_bits_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	left.add_child(_bits_label)
	_lit_label = _label("Bright  —\nFaded   —", 12, INK, Vector2(10, 130))
	left.add_child(_lit_label)
	_status_label = _label("Waiting…", 11, MUTED, Vector2(10, 190))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size = Vector2(110, 60)
	left.add_child(_status_label)

	var controls := _panel(Rect2(16, 390, 130, 150))
	_hud.add_child(controls)
	controls.add_child(_label("CONTROLS", 11, MUTED, Vector2(10, 10)))
	controls.add_child(_label("Space  Start\nR  Replay\nEsc  Pause", 12, INK, Vector2(10, 34)))

	var right := _panel(Rect2(1134, 96, 130, 320))
	_hud.add_child(right)
	right.add_child(_label("PATTERN", 11, MUTED, Vector2(10, 10)))
	_pattern_label = _label("nvars = 5", 12, INK, Vector2(10, 36))
	right.add_child(_pattern_label)
	right.add_child(_label(
		"Each row is one\n5-input conjunct.\nNon-power-of-two\nrows fade to 25%.",
		11, MUTED, Vector2(10, 130)))
	right.add_child(_label("Same Direct\ntruth_table.gd\n+ shaded_grid.gd.", 11, MUTED, Vector2(10, 230)))

	var back := _btn("Back to Arcade", Vector2(16, 660), Vector2(160, 36))
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(GameRegistry.return_to_arcade)
	_hud.add_child(back)

	# Title card
	var card := _panel(Rect2(STAGE.x * 0.5 - 300, STAGE.y * 0.5 - 160, 600, 320))
	card.name = "TitleCard"
	_ui.add_child(card)
	_cards["title"] = card
	card.add_child(_label("FNARB BINARY SPACE", 28, GOLD, Vector2(36, 36)))
	card.add_child(_label("Enhanced edition", 16, ACCENT, Vector2(36, 80)))
	card.add_child(_label(
		"A chrome shell over the Direct 5-input truth-table space.\nSame 32×32 conjunction grid, same 25% fade on non-\npower-of-two rows — just clearer HUD + scan juice.",
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
