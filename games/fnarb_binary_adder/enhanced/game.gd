extends Node2D
## Fnarbmlyx Binary Adder (Enhanced). Presentation makeover of the Direct
## ripple-carry sketch. The demo is Direct `binary_addition.tscn` (shared
## `adder.gd` / `rect.gd` / `truth_table.gd` / `shaded_grid.gd` + AnimationTree),
## instanced in a 1920×1080 SubViewport — no rules copied. Enhanced owns the
## 1280×720 letterbox chrome, HUD, title / done cards and juice derived from
## watching result/carry bit colours and the gold carriage. Esc → PauseOverlay.
## No Alchementrix IP.

const DEMO := preload("res://games/fnarb_binary_adder/direct/binary_addition.tscn")
const AdderScript := preload("res://games/fnarb_binary_adder/direct/adder.gd")
const RectScript := preload("res://games/fnarb_binary_adder/direct/rect.gd")
const TruthScript := preload("res://games/fnarb_binary_adder/direct/truth_table.gd")
const GridScript := preload("res://games/fnarb_binary_adder/direct/shaded_grid.gd")

const STAGE := Vector2(1280, 720)
## Direct demo is authored for a 1920×1080 window; show it at ½ in a clipped field.
const VP_SIZE := Vector2(1920, 1080)
const FIELD := Vector2(960, 540)
const FIELD_POS := Vector2(160, 90)

const BG_TOP := Color(0.04, 0.06, 0.12)
const BG_BOT := Color(0.08, 0.05, 0.14)
const PANEL := Color(0.09, 0.11, 0.20, 0.94)
const FRAME := Color(0.45, 0.75, 1.0)
const INK := Color(0.92, 0.95, 1.0)
const MUTED := Color(0.58, 0.64, 0.82)
const GOLD := Color(1.0, 0.85, 0.0)
const ACCENT := Color(0.45, 0.90, 0.75)
const CARRY_C := Color(1.0, 0.55, 0.35)
const RESULT_C := Color(0.55, 0.85, 1.0)

enum { TITLE, PLAY, DONE }

var state := TITLE
var demo: Control = null
var adder: Control = null
var carriage: Node2D = null
var cursor: ReferenceRect = null

## View-only presentation state (derived from Direct bit colours).
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _banner_t := 0.0
var _banner := ""
var _prev_r := {}  ## bit index -> Color
var _prev_c := {}  ## bit index -> Color
var _bits_set := 0
var _carries_set := 0
var _column := 0
var _done_fired := false

var _vp_box: SubViewportContainer
var _viewport: SubViewport
var _ui: CanvasLayer
var _hud: Control
var _cards := {}
var _eq_label: Label
var _col_label: Label
var _bits_label: Label
var _carry_label: Label
var _status_label: Label
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
	_cards["done"].visible = s == DONE
	_hud.visible = s == PLAY or s == DONE
	_vp_box.visible = s == PLAY or s == DONE
	if s == PLAY and demo == null:
		_load_demo()
	if s == PLAY:
		_banner = "ADDING  3 + 7"
		_banner_t = 1.6


func _load_demo() -> void:
	demo = DEMO.instantiate() as Control
	demo.set_anchors_preset(Control.PRESET_FULL_RECT)
	demo.offset_left = 0
	demo.offset_top = 0
	demo.offset_right = 0
	demo.offset_bottom = 0
	_viewport.add_child(demo)
	adder = demo.get_node("Adder") as Control
	carriage = adder.get_node("carriage") as Node2D
	cursor = adder.get_node("carriage/cursor") as ReferenceRect
	_snapshot_bits()
	_refresh_hud()


## Snapshot current Direct result / carry bit colours (for juice deltas).
func _snapshot_bits() -> void:
	_prev_r.clear()
	_prev_c.clear()
	if adder == null:
		return
	for i in 4:
		var n: ColorRect = adder.get_node("r/bit%d" % i)
		_prev_r[i] = n.color
	for i in range(1, 5):
		var n: ColorRect = adder.get_node("c/bit%d" % i)
		_prev_c[i] = n.color


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var e := event as InputEventKey
	if state == TITLE:
		if e.keycode in [KEY_ENTER, KEY_SPACE]:
			_set_state(PLAY)
			get_viewport().set_input_as_handled()
		return
	if state == DONE:
		if e.keycode in [KEY_ENTER, KEY_SPACE, KEY_R]:
			_restart()
			get_viewport().set_input_as_handled()
		return
	# PLAY
	if e.keycode == KEY_R:
		_restart()
		get_viewport().set_input_as_handled()


func _restart() -> void:
	_done_fired = false
	_bits_set = 0
	_carries_set = 0
	_column = 0
	_particles.clear()
	_floaters.clear()
	if demo != null:
		demo.queue_free()
		demo = null
		adder = null
		carriage = null
		cursor = null
	_set_state(PLAY)


func _process(delta: float) -> void:
	_time += delta
	_shake = maxf(0.0, _shake - delta * 2.8)
	_flash = maxf(0.0, _flash - delta * 2.5)
	_banner_t = maxf(0.0, _banner_t - delta)
	_animate_fx(delta)
	if state == PLAY and adder != null:
		_track_bits()
		_track_column()
		_check_done()
		_refresh_hud()
	queue_redraw()


func _track_bits() -> void:
	for i in 4:
		var n: ColorRect = adder.get_node("r/bit%d" % i)
		var prev: Color = _prev_r.get(i, n.color)
		if prev != AdderScript.I and n.color == AdderScript.I:
			_bits_set += 1
			var gp := _bit_stage_pos("r", i)
			_burst(gp, RESULT_C, 14, 220.0)
			_floater("r%d=1" % i, gp + Vector2(0, -20), RESULT_C)
		_prev_r[i] = n.color
	for i in range(1, 5):
		var n: ColorRect = adder.get_node("c/bit%d" % i)
		var prev: Color = _prev_c.get(i, n.color)
		if prev != AdderScript.I and n.color == AdderScript.I:
			_carries_set += 1
			var gp := _bit_stage_pos("c", i)
			_burst(gp, CARRY_C, 10, 180.0)
			_floater("c%d" % i, gp + Vector2(0, -18), CARRY_C)
		_prev_c[i] = n.color


func _track_column() -> void:
	if carriage == null:
		return
	# Carriage starts at x=768 and steps −32 per column.
	var col := int(round((AdderScript.CARRIAGE_ORIGIN.x - carriage.position.x) / 32.0))
	col = clampi(col, 0, 3)
	if col != _column:
		_column = col
		_banner = "COLUMN  %d" % col
		_banner_t = 0.9


func _check_done() -> void:
	if _done_fired:
		return
	# Result is 1010 once all four result bits have been written (I or O final).
	# Wait until the script has painted bit3 (MSB) — same as Direct smoke.
	var bits := _result_bits()
	if bits == "1010":
		_done_fired = true
		_flash = 0.9
		_flash_color = GOLD
		_shake = 0.45
		_burst(FIELD_POS + FIELD * 0.5, GOLD, 36, 320.0)
		_floater("1010", FIELD_POS + Vector2(FIELD.x * 0.5 - 30, 40), GOLD)
		_banner = "3 + 7 = 10"
		_banner_t = 2.4
		_set_state(DONE)


func _result_bits() -> String:
	if adder == null:
		return ""
	var bits := ""
	for i in [3, 2, 1, 0]:
		bits += "1" if adder.get_node("r/bit%d" % i).color == AdderScript.I else "0"
	return bits


func _carry_bits() -> String:
	if adder == null:
		return ""
	var bits := ""
	for i in [4, 3, 2, 1]:
		bits += "1" if adder.get_node("c/bit%d" % i).color == AdderScript.I else "0"
	return bits


func _bit_stage_pos(reg: String, i: int) -> Vector2:
	# Map Direct viewport local → stage field (approximate bit centres).
	var node: Node = adder.get_node("%s/bit%d" % [reg, i])
	var local := Vector2.ZERO
	if node is Control:
		local = (node as Control).position + (node as Control).size * 0.5
		if reg == "r" or reg == "c":
			# bits live under a Node2D parent
			var parent: Node2D = node.get_parent() as Node2D
			if parent:
				local += parent.position
		local += adder.position
	else:
		local = Vector2(800, 400)
	var u := local / VP_SIZE
	return FIELD_POS + Vector2(u.x * FIELD.x, u.y * FIELD.y)


func _refresh_hud() -> void:
	if _eq_label == null:
		return
	var a := 3
	var b := 7
	if adder != null:
		a = adder.a
		b = adder.b
	var res := _result_bits()
	var eq := "%d + %d = ?" % [a, b]
	if res == "1010":
		eq = "%d + %d = 10  (0b%s)" % [a, b, res]
	elif res != "0000" and res != "":
		eq = "%d + %d -> 0b%s..." % [a, b, res]
	_eq_label.text = eq
	_col_label.text = "Column  %d / 3" % _column
	_bits_label.text = "Result bits set  %d\nCarry bits set   %d" % [_bits_set, _carries_set]
	_carry_label.text = "Carry row  %s\nResult row %s" % [
		_carry_bits() if _carry_bits() != "" else "----",
		res if res != "" else "----",
	]
	if state == DONE:
		_status_label.text = "Done - plays once, as in Direct"
		_status_label.add_theme_color_override("font_color", GOLD)
	elif state == PLAY:
		_status_label.text = "Ripple-carry walk (gold box)"
		_status_label.add_theme_color_override("font_color", MUTED)


# --- draw ---------------------------------------------------------------------

func _draw() -> void:
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 8.0 * _shake * _shake
	draw_rect(Rect2(Vector2.ZERO, STAGE), BG_TOP)
	for i in 20:
		var t := float(i) / 20.0
		var c := BG_TOP.lerp(BG_BOT, t)
		c.a = 0.55
		draw_rect(Rect2(0, STAGE.y * t, STAGE.x, STAGE.y / 20.0 + 1.0), c)
	# Soft circuit glow orbs
	draw_circle(Vector2(100, 80), 180, Color(0.15, 0.35, 0.55, 0.12))
	draw_circle(Vector2(STAGE.x - 80, STAGE.y - 60), 220, Color(0.35, 0.15, 0.45, 0.14))
	if state == PLAY or state == DONE:
		var fr := Rect2(FIELD_POS + shake - Vector2(14, 14), FIELD + Vector2(28, 28))
		draw_rect(fr, Color(0.06, 0.08, 0.14))
		draw_rect(fr.grow(-5), Color(FRAME.r, FRAME.g, FRAME.b, 0.55), false, 2.0)
		# Gold accent corners echoing the Direct highlight
		var corner := Color(GOLD.r, GOLD.g, GOLD.b, 0.7)
		draw_rect(Rect2(fr.position, Vector2(28, 3)), corner)
		draw_rect(Rect2(fr.position, Vector2(3, 28)), corner)
		draw_rect(Rect2(fr.end - Vector2(28, 3), Vector2(28, 3)), corner)
		draw_rect(Rect2(fr.end - Vector2(3, 28), Vector2(3, 28)), corner)
	if _flash > 0.0:
		var fc := _flash_color
		fc.a = _flash * 0.35
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
		var r := Rect2(STAGE.x * 0.5 - 200, 28, 400, 34)
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
			"grav": 30.0,
		})


func _floater(text: String, at: Vector2, color: Color) -> void:
	_floaters.append({
		"pos": at,
		"life": 1.1,
		"max": 1.1,
		"text": text,
		"color": color,
		"size": 18.0,
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
		f.pos.y -= 26.0 * delta
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

	# Title bar (left)
	var title := _panel(Rect2(24, 18, 120, 56))
	_hud.add_child(title)
	# Actually left column is thin — put title above field area via a wider bar on left edge
	title.queue_free()
	var left_top := _panel(Rect2(16, 18, 130, 64))
	_hud.add_child(left_top)
	left_top.add_child(_label("BINARY", 18, GOLD, Vector2(12, 8)))
	left_top.add_child(_label("ADDER", 18, GOLD, Vector2(12, 30)))

	var left := _panel(Rect2(16, 96, 130, 280))
	_hud.add_child(left)
	left.add_child(_label("EQUATION", 11, MUTED, Vector2(10, 10)))
	_eq_label = _label("3 + 7 = ?", 13, INK, Vector2(10, 32))
	_eq_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_eq_label.size = Vector2(110, 50)
	left.add_child(_eq_label)
	_col_label = _label("Column  0 / 3", 13, GOLD, Vector2(10, 90))
	left.add_child(_col_label)
	_bits_label = _label("Result bits set  0\nCarry bits set   0", 12, INK, Vector2(10, 120))
	left.add_child(_bits_label)
	_status_label = _label("Waiting...", 11, MUTED, Vector2(10, 180))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size = Vector2(110, 60)
	left.add_child(_status_label)

	var controls := _panel(Rect2(16, 390, 130, 150))
	_hud.add_child(controls)
	controls.add_child(_label("CONTROLS", 11, MUTED, Vector2(10, 10)))
	controls.add_child(_label("Space  Start\nR  Replay\nEsc  Pause", 12, INK, Vector2(10, 34)))

	# Right HUD
	var right := _panel(Rect2(1134, 96, 130, 320))
	_hud.add_child(right)
	right.add_child(_label("LIVE ROWS", 11, MUTED, Vector2(10, 10)))
	_carry_label = _label("Carry row  ----\nResult row ----", 12, INK, Vector2(10, 36))
	right.add_child(_carry_label)
	right.add_child(_label("Direct gold box\ntracks the column\nbeing added.", 11, MUTED, Vector2(10, 100)))
	right.add_child(_label("a=3  b=7\n-> 1010 / c 0111", 12, ACCENT, Vector2(10, 170)))
	right.add_child(_label("Same Adder.gd\nscript as Direct.", 11, MUTED, Vector2(10, 230)))

	var back := _btn("Back to Arcade", Vector2(16, 660), Vector2(160, 36))
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(GameRegistry.return_to_arcade)
	_hud.add_child(back)

	# Title card
	var card := _panel(Rect2(STAGE.x * 0.5 - 300, STAGE.y * 0.5 - 160, 600, 320))
	card.name = "TitleCard"
	_ui.add_child(card)
	_cards["title"] = card
	card.add_child(_label("FNARB BINARY ADDER", 30, GOLD, Vector2(36, 36)))
	card.add_child(_label("Enhanced edition", 16, ACCENT, Vector2(36, 80)))
	card.add_child(_label(
		"A chrome shell over the Direct ripple-carry sketch.\nSame Adder script, same gold column highlight,\nsame 3 + 7 -> 1010 walk - just clearer HUD + juice.",
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

	# Done card
	var done := _panel(Rect2(STAGE.x * 0.5 - 260, STAGE.y * 0.5 - 120, 520, 240))
	done.name = "DoneCard"
	done.visible = false
	_ui.add_child(done)
	_cards["done"] = done
	done.add_child(_label("3 + 7 = 10", 34, GOLD, Vector2(36, 28)))
	done.add_child(_label("Result 1010   |   Carries 0111", 16, ACCENT, Vector2(36, 80)))
	done.add_child(_label("Plays once, as in the Direct edition.\nR / Space  to watch again.", 14, INK, Vector2(36, 120)))
	var again := _btn("Watch again", Vector2(36, 180), Vector2(140, 36))
	again.focus_mode = Control.FOCUS_NONE
	again.pressed.connect(func(): _restart())
	done.add_child(again)
	var done_back := _btn("Back to Arcade", Vector2(200, 180), Vector2(160, 36))
	done_back.focus_mode = Control.FOCUS_NONE
	done_back.pressed.connect(GameRegistry.return_to_arcade)
	done.add_child(done_back)


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
