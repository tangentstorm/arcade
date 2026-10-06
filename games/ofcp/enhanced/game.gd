extends Node2D
## OFCP (Enhanced). Presentation makeover of the Direct thin WSS client.
## The table is Direct `game.tscn` (shared ofcp_ws / ofcp_table / suit_icon),
## instanced in a 1280×720 SubViewport — no rules or AI copied. Enhanced owns
## the self-fitted 1280×720 chrome (title stays `expand`), side HUD, title card
## and juice derived from watching Direct's table (pending, phase, scores,
## Fantasyland). Mode labels: cash/normal, windfall, progressive (no poker-site
## names). Esc → PauseOverlay. No Alchementrix IP.
##
## Offline / headless: Direct skips the live socket; tests (and `apply_mock`)
## feed game_state dicts straight into Direct's message handler.

const DIRECT := preload("res://games/ofcp/direct/game.tscn")

const STAGE := Vector2(1280, 720)
## Direct Control fills a native 1280×720 SubViewport; shown via scale (not stretch).
const VP_SIZE := Vector2(1280, 720)
const FIELD := Vector2(1024, 576)  ## 0.8× — room for side chrome
const FIELD_POS := Vector2(128, 72)

const BG_TOP := Color(0.02, 0.08, 0.05)
const BG_BOT := Color(0.04, 0.14, 0.09)
const PANEL := Color(0.06, 0.12, 0.10, 0.94)
const FRAME := Color(0.92, 0.78, 0.32)
const INK := Color(0.94, 0.96, 0.92)
const MUTED := Color(0.58, 0.70, 0.62)
const GOLD := Color(1.0, 0.84, 0.30)
const FELT := Color(0.05, 0.32, 0.18)
const HEART := Color(0.78, 0.08, 0.1)
const DIAMOND := Color(0.12, 0.35, 0.85)
const CLUB := Color(0.08, 0.55, 0.28)
const SPADE := Color(0.75, 0.78, 0.82)

const MODE_LABELS := {
	"normal": "Cash / normal",
	"cash": "Cash / normal",
	"windfall": "Windfall",
	"progressive": "Progressive",
}

enum { TITLE, PLAY }

var state := TITLE
var demo: Control = null

## View-only counters (derived from Direct table deltas).
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _banner_t := 0.0
var _banner := ""
var _prev_pending := 0
var _prev_phase := ""
var _prev_score := 0
var _prev_fl := false
var _prev_over := false
var places := 0
var confirms := 0
var score_flashes := 0
var fl_celebrations := 0
var mock_feeds := 0

var _vp_box: SubViewportContainer
var _viewport: SubViewport
var _fx: Node2D
var _ui: CanvasLayer
var _hud: Control
var _cards := {}
var _mode_label: Label
var _phase_label: Label
var _score_label: Label
var _pending_label: Label
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
		_banner = "4-COLOR DECK  ·  PLACE YOUR BOARD"
		_banner_t = 2.0
		_flash = 0.4
		_flash_color = FRAME
		_burst(FIELD_POS + FIELD * 0.5, GOLD, 16, 200.0)


func _load_demo() -> void:
	demo = DIRECT.instantiate() as Control
	demo.set_anchors_preset(Control.PRESET_FULL_RECT)
	demo.offset_left = 0
	demo.offset_top = 0
	demo.offset_right = 0
	demo.offset_bottom = 0
	_viewport.add_child(demo)
	_resync()
	_refresh_hud()


## Snapshot Direct table without firing juice (load / mock reset).
func _resync() -> void:
	if demo == null:
		return
	_prev_pending = demo.table.pending.size()
	_prev_phase = demo.table.phase()
	_prev_score = demo.table.my_score()
	_prev_fl = demo.table.is_fantasyland()
	_prev_over = demo.table.is_game_over()


## Offline / test helper: feed a server-shaped message into Direct (no network).
func apply_mock(msg: Dictionary) -> void:
	if demo == null:
		return
	demo._on_message(msg)
	mock_feeds += 1
	# Hide Direct's "not connecting" / lobby overlay so the table is visible.
	if demo.has_method("_hide_overlay"):
		demo._hide_overlay()
	demo.game_started = true


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var e := event as InputEventKey
	if state == TITLE:
		if e.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
			_set_state(PLAY)
			get_viewport().set_input_as_handled()
		return


func _process(delta: float) -> void:
	_time += delta
	_shake = maxf(0.0, _shake - delta * 2.8)
	_flash = maxf(0.0, _flash - delta * 2.2)
	_banner_t = maxf(0.0, _banner_t - delta)
	_animate_fx(delta)
	if state == PLAY and demo != null:
		_watch_table()
		_refresh_hud()
	queue_redraw()
	if _fx:
		_fx.queue_redraw()


## Presentation only: read Direct table deltas and fire juice.
func _watch_table() -> void:
	if demo == null:
		return
	var t = demo.table
	var pend: int = t.pending.size()
	if pend > _prev_pending:
		places += pend - _prev_pending
		var at := FIELD_POS + Vector2(FIELD.x * 0.35, FIELD.y * 0.55)
		_burst(at, GOLD, 8, 140.0)
		_floater("+card", at + Vector2(-10, -20), GOLD)
	elif pend < _prev_pending and pend == 0 and _prev_pending > 0 \
			and not t.is_game_over() and t.phase() == _prev_phase:
		# Pending cleared while same phase → Confirm / Clear went out.
		confirms += 1
		_burst(FIELD_POS + FIELD * 0.5, FRAME, 12, 160.0)
		_floater("sent", FIELD_POS + Vector2(FIELD.x * 0.5 - 20, 40), FRAME)
	_prev_pending = pend

	var ph: String = t.phase()
	if ph != _prev_phase and ph != "":
		_banner = _phase_banner(ph)
		_banner_t = 1.6
		_flash = 0.35
		_flash_color = FRAME
	_prev_phase = ph

	var sc: int = t.my_score()
	if sc != _prev_score and t.is_game_over():
		score_flashes += 1
		var col := Color(0.45, 0.95, 0.55) if sc > _prev_score else Color(1.0, 0.4, 0.35)
		_flash = 0.7
		_flash_color = col
		_burst(FIELD_POS + FIELD * 0.5, col, 20, 220.0)
		_floater("%+d" % (sc - _prev_score), FIELD_POS + Vector2(FIELD.x * 0.5 - 16, 80), col)
		_shake = 0.4
	_prev_score = sc

	var fl: bool = t.is_fantasyland()
	if fl and not _prev_fl:
		fl_celebrations += 1
		_banner = "FANTASYLAND"
		_banner_t = 2.4
		_flash = 0.8
		_flash_color = GOLD
		_burst(FIELD_POS + FIELD * 0.5, GOLD, 28, 280.0)
		_shake = 0.55
	_prev_fl = fl

	if t.is_game_over() and not _prev_over:
		_banner = "HAND OVER"
		_banner_t = 1.8
	_prev_over = t.is_game_over()


func _phase_banner(ph: String) -> String:
	match ph:
		"INITIAL_PLACE":
			return "DEAL 5  ·  SET YOUR BOARD"
		"PINEAPPLE_PLACE":
			return "PINEAPPLE  ·  PLACE 2, DISCARD 1"
		"GAME_OVER":
			return "HAND OVER"
		_:
			return ph


func _refresh_hud() -> void:
	if _mode_label == null or demo == null:
		return
	var profile: String = demo.profile if demo.profile != "" else String(demo.table.state.get("profile", demo.table.state.get("mode", "")))
	_mode_label.text = "Mode\n%s" % MODE_LABELS.get(profile, profile if profile != "" else "—")
	var ph: String = demo.table.phase()
	_phase_label.text = "Phase\n%s" % (ph if ph != "" else "(lobby)")
	_score_label.text = "Score\nYou %+d" % demo.table.my_score()
	var need: int = demo.table.need_place() if demo.table.is_my_turn() else 0
	_pending_label.text = "Pending\n%d / %d" % [demo.table.pending.size(), need if need > 0 else demo.table.pending.size()]
	if demo.table.is_fantasyland():
		_status_label.text = "Fantasyland\n14 → place 13"
		_status_label.add_theme_color_override("font_color", GOLD)
	elif demo.table.is_game_over():
		_status_label.text = "Hand over\nN = new hand"
		_status_label.add_theme_color_override("font_color", FRAME)
	elif demo.table.is_my_turn():
		_status_label.text = "Your turn\n1/2/3 rows"
		_status_label.add_theme_color_override("font_color", INK)
	else:
		_status_label.text = "Waiting\non server / AI"
		_status_label.add_theme_color_override("font_color", MUTED)


# --- draw --------------------------------------------------------------------

func _draw() -> void:
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 6.0 * _shake * _shake
	draw_rect(Rect2(Vector2.ZERO, STAGE), BG_TOP)
	for i in 24:
		var t := float(i) / 24.0
		var c := BG_TOP.lerp(BG_BOT, t)
		c.a = 0.7
		draw_rect(Rect2(0, STAGE.y * t, STAGE.x, STAGE.y / 24.0 + 1.0), c)
	# Felt glow under the table
	draw_circle(Vector2(STAGE.x * 0.5, STAGE.y * 0.48), 320, Color(FELT.r, FELT.g, FELT.b, 0.18))
	# Suit dust
	var suits := [HEART, DIAMOND, CLUB, SPADE]
	for i in 40:
		var seed := float(i * 97 + 13)
		var px := fmod(seed * 37.0 + _time * (4.0 + i % 3), STAGE.x)
		var py := fmod(seed * 53.0 + _time * (2.0 + i % 2), STAGE.y)
		var a := 0.08 + 0.12 * (0.5 + 0.5 * sin(_time * 1.6 + seed))
		var sc: Color = suits[i % 4]
		draw_circle(Vector2(px, py), 1.4, Color(sc.r, sc.g, sc.b, a))
	if state == PLAY:
		var fr := Rect2(FIELD_POS + shake - Vector2(14, 14), FIELD + Vector2(28, 28))
		draw_rect(fr, Color(0.03, 0.10, 0.06))
		draw_rect(fr.grow(-5), Color(FRAME.r, FRAME.g, FRAME.b, 0.55), false, 2.0)
		var corner := Color(GOLD.r, GOLD.g, GOLD.b, 0.75)
		draw_rect(Rect2(fr.position, Vector2(28, 3)), corner)
		draw_rect(Rect2(fr.position, Vector2(3, 28)), corner)
		draw_rect(Rect2(fr.end - Vector2(28, 3), Vector2(28, 3)), corner)
		draw_rect(Rect2(fr.end - Vector2(3, 28), Vector2(3, 28)), corner)


func _draw_fx() -> void:
	if _flash > 0.0:
		var fc := _flash_color
		fc.a = _flash * 0.22
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
		var r := Rect2(STAGE.x * 0.5 - 240, 28, 480, 34)
		_fx.draw_rect(r, Color(0.04, 0.08, 0.06, 0.82 * a))
		_fx.draw_string(_font, r.position + Vector2(12, 8), _banner,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(GOLD.r, GOLD.g, GOLD.b, a))


# --- FX helpers --------------------------------------------------------------

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
			"grav": 18.0,
		})


func _floater(text: String, at: Vector2, color: Color) -> void:
	_floaters.append({
		"pos": at,
		"life": 1.0,
		"max": 1.0,
		"text": text,
		"color": color,
		"size": 15.0,
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


# --- UI build ----------------------------------------------------------------

func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "DirectVP"
	_viewport.size = Vector2i(VP_SIZE)
	_viewport.transparent_bg = false
	_viewport.handle_input_locally = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.gui_disable_input = false

	# Native 1280×720 Direct Control, shown via Control.scale (not stretch).
	# stretch=true would resize the SubViewport to the field and break VP_SIZE.
	_vp_box = SubViewportContainer.new()
	_vp_box.name = "TableView"
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

	var left_top := _panel(Rect2(8, 14, 112, 52))
	_hud.add_child(left_top)
	left_top.add_child(_label("OFCP", 18, GOLD, Vector2(10, 6)))
	left_top.add_child(_label("Enhanced", 12, FRAME, Vector2(10, 28)))

	var left := _panel(Rect2(8, 78, 112, 280))
	_hud.add_child(left)
	left.add_child(_label("LIVE", 11, MUTED, Vector2(10, 8)))
	_mode_label = _label("Mode\n—", 12, INK, Vector2(10, 28))
	left.add_child(_mode_label)
	_phase_label = _label("Phase\n—", 12, INK, Vector2(10, 78))
	left.add_child(_phase_label)
	_score_label = _label("Score\nYou +0", 13, GOLD, Vector2(10, 128))
	left.add_child(_score_label)
	_pending_label = _label("Pending\n0 / 0", 12, INK, Vector2(10, 178))
	left.add_child(_pending_label)
	_status_label = _label("Lobby", 11, MUTED, Vector2(10, 228))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size = Vector2(92, 40)
	left.add_child(_status_label)

	var controls := _panel(Rect2(8, 372, 112, 150))
	_hud.add_child(controls)
	controls.add_child(_label("CONTROLS", 11, MUTED, Vector2(10, 8)))
	controls.add_child(_label(
		"Click / 1-2-3\nEnter confirm\nH hint\nBksp clear\nN new hand\nEsc pause",
		11, INK, Vector2(10, 28)))

	var right := _panel(Rect2(1160, 78, 112, 300))
	_hud.add_child(right)
	right.add_child(_label("DECK", 11, MUTED, Vector2(10, 8)))
	_legend_label = _label(
		"♥ red\n♦ blue\n♣ green\n♠ black\n\nModes:\ncash/normal\nwindfall\nprogressive",
		11, INK, Vector2(10, 28))
	right.add_child(_legend_label)
	right.add_child(_label(
		"Same Direct\nthin client.\nServer owns\nrules + AI.",
		10, MUTED, Vector2(10, 210)))

	var back := _btn("Back to Arcade", Vector2(8, 660), Vector2(160, 36))
	back.pressed.connect(GameRegistry.return_to_arcade)
	_hud.add_child(back)

	# Title card
	var card := _panel(Rect2(STAGE.x * 0.5 - 320, STAGE.y * 0.5 - 175, 640, 350))
	card.name = "TitleCard"
	_ui.add_child(card)
	_cards["title"] = card
	card.add_child(_label("OFCP", 34, GOLD, Vector2(36, 28)))
	card.add_child(_label("Open Face Chinese Poker · Enhanced", 15, FRAME, Vector2(36, 76)))
	card.add_child(_label(
		"A chrome shell over the Direct thin client.\nSame live server (cash/normal, windfall, progressive),\n4-color deck, and placement keys — plus felt juice.",
		14, INK, Vector2(36, 118)))
	var start := _btn("Start", Vector2(36, 220), Vector2(120, 40))
	start.pressed.connect(func(): _set_state(PLAY))
	card.add_child(start)
	card.add_child(_label("Enter / Space  to begin", 14, MUTED, Vector2(180, 230)))
	var title_back := _btn("Back to Arcade", Vector2(36, 280), Vector2(160, 34))
	title_back.pressed.connect(GameRegistry.return_to_arcade)
	card.add_child(title_back)
	card.add_child(_label("♥ ♦ ♣ ♠", 20, Color(GOLD, 0.7), Vector2(480, 286)))


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
		var base := Color(0.12, 0.28, 0.18)
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
