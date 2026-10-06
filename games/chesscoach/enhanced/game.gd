extends Node2D
## Chess Coach (Enhanced). Presentation makeover of the Direct FEN board.
## Board setup, trays, piece sprites and the recorded "fool's mate" AnimationPlayer
## are the Direct scene and scripts (instanced, not copied): `direct/game.tscn` with
## chess_board.gd / tray.gd / square.gd / game_editor.gd. This file owns the
## 1280×720 letterbox shell: walnut board chrome, file/rank labels, FEN + move
## list HUD, replay progress juice, title card and Back to Arcade.
## Esc is handled by the PauseOverlay autoload. No Stockfish. No Alchementrix IP.

const DIRECT := preload("res://games/chesscoach/direct/game.tscn")
const BoardScript := preload("res://games/chesscoach/direct/chess_board.gd")
const TrayScript := preload("res://games/chesscoach/direct/tray.gd")
const SquareScript := preload("res://games/chesscoach/direct/square.gd")
const GameEditorScript := preload("res://games/chesscoach/direct/game_editor.gd")

const STAGE := Vector2(1280, 720)
## Direct board Panel is 398×398; room for toolbar strip we hide + padding.
const VP_SIZE := Vector2(420, 440)
const FIELD := Vector2(520, 520)  ## scaled board frame on stage
const FIELD_POS := Vector2(380, 88)

const BG_TOP := Color(0.07, 0.05, 0.10)
const BG_BOT := Color(0.14, 0.09, 0.06)
const PANEL := Color(0.12, 0.09, 0.14, 0.94)
const FRAME := Color(0.92, 0.78, 0.42)
const INK := Color(0.96, 0.93, 0.86)
const MUTED := Color(0.70, 0.64, 0.55)
const GOLD := Color(1.0, 0.84, 0.32)
const WOOD_LIGHT := Color(0.90, 0.78, 0.58)
const WOOD_DARK := Color(0.52, 0.34, 0.18)
const WOOD_FRAME := Color(0.28, 0.16, 0.08)
const ACCENT := Color(0.55, 0.78, 1.0)
const CAPTURE := Color(1.0, 0.42, 0.38)
const MOVE_HL := Color(0.95, 0.85, 0.35, 0.55)

enum { TITLE, PLAY }

var state := TITLE
var direct: Control = null
var board: Panel = null
var player: AnimationPlayer = null
var editor: Node = null

## View-only presentation state.
var moves: Array = []
var move_index := -1
var replaying := false
var pieces_on := 32
var captures_seen := 0
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _banner_t := 0.0
var _banner := ""
var _prev_modulate := {}  ## piece name -> Color (detect capture fades)
var _prev_playing := false

var _vp_box: SubViewportContainer
var _viewport: SubViewport
var _ui: CanvasLayer
var _hud: Control
var _cards := {}
var _fen_label: Label
var _moves_label: RichTextLabel
var _status_label: Label
var _progress: ProgressBar
var _pieces_label: Label
var _hint_label: Label
var _font: Font
var _panel_style := StyleBoxFlat.new()
var _board_frame: ColorRect


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
	_vp_box.visible = s == PLAY
	_board_frame.visible = s == PLAY
	if s == PLAY and direct == null:
		_load_direct()


func _load_direct() -> void:
	direct = DIRECT.instantiate() as Control
	# Fill the SubViewport instead of centering on the arcade window.
	direct.set_anchors_preset(Control.PRESET_FULL_RECT)
	direct.offset_left = 0
	direct.offset_top = 0
	direct.offset_right = 0
	direct.offset_bottom = 0
	direct.grow_horizontal = Control.GROW_DIRECTION_BOTH
	direct.grow_vertical = Control.GROW_DIRECTION_BOTH
	_viewport.add_child(direct)
	board = direct.get_node("board") as Panel
	player = direct.get_node("AnimationPlayer") as AnimationPlayer
	editor = direct.get_node("Editor")
	# Enhanced owns chrome; hide Direct toolbar / hint.
	var toolbar: Control = direct.get_node_or_null("Toolbar")
	if toolbar:
		toolbar.visible = false
	# Restyle after Direct's deferred FEN boot.
	_restyle_board.call_deferred()
	_banner = "STARTING POSITION"
	_banner_t = 1.6
	_refresh_moves_from_editor()


func _restyle_board() -> void:
	if board == null:
		return
	# Wait for Direct chess_board._boot (two process frames) + a couple extra.
	for i in 6:
		await get_tree().process_frame
	_apply_wood_palette()
	_snapshot_modulates()
	_refresh_hud()
	_check_shared_scripts()


func _check_shared_scripts() -> void:
	if board == null or direct == null or editor == null:
		return
	# Soft assert for humans reading the scene; hard checks live in the test.
	assert(board.get_script() == BoardScript)
	assert(direct.get_node("white-tray").get_script() == TrayScript)
	assert(direct.get_node("black-tray").get_script() == TrayScript)
	assert(editor.get_script() == GameEditorScript)


func _apply_wood_palette() -> void:
	# Board panel frame
	var sb := StyleBoxFlat.new()
	sb.bg_color = WOOD_FRAME
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 4
	sb.content_margin_top = 4
	sb.content_margin_right = 4
	sb.content_margin_bottom = 4
	board.add_theme_stylebox_override("panel", sb)
	# Squares: keep Direct's dark flag, paint walnut / cream.
	for node in board.find_children("*", "ColorRect", true, false):
		var sq := node as ColorRect
		if sq.get_script() != SquareScript:
			continue
		sq.color = WOOD_DARK if sq.dark else WOOD_LIGHT


func _refresh_moves_from_editor() -> void:
	moves = []
	if editor and editor.has_method("parse_moves"):
		var parsed = editor.parse_moves()
		if parsed is Array:
			moves = parsed


func _snapshot_modulates() -> void:
	_prev_modulate.clear()
	if board == null:
		return
	var pieces: Node = board.get_node_or_null("pieces")
	if pieces == null:
		return
	for p in pieces.get_children():
		if p is CanvasItem:
			_prev_modulate[str(p.name)] = (p as CanvasItem).modulate


# --- input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var e := event as InputEventKey
	if state == TITLE:
		if e.keycode in [KEY_ENTER, KEY_SPACE]:
			_set_state(PLAY)
			get_viewport().set_input_as_handled()
		return
	# PLAY
	if e.keycode == KEY_R:
		_do_reset()
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_P:
		_do_replay()
		get_viewport().set_input_as_handled()


# --- Direct actions -----------------------------------------------------------

func _do_reset() -> void:
	if direct == null:
		return
	if player and player.is_playing():
		player.stop()
	replaying = false
	move_index = -1
	captures_seen = 0
	if board and board.has_method("setup_board"):
		board.setup_board(board.INIT_FEN)
	_apply_wood_palette()
	_snapshot_modulates()
	_banner = "RESET"
	_banner_t = 1.2
	_burst(FIELD_POS + FIELD * 0.5, GOLD, 18, 180.0)
	_refresh_hud()


func _do_replay() -> void:
	if direct == null or player == null:
		return
	_do_reset()
	# Match Direct game.gd._replay: settle layout, then play.
	await get_tree().process_frame
	await get_tree().process_frame
	if player.has_animation("fool's mate"):
		player.play("fool's mate")
		replaying = true
		_banner = "REPLAY"
		_banner_t = 1.4
		_burst(FIELD_POS + FIELD * 0.5, ACCENT, 22, 220.0)


# --- process / juice ----------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_shake = maxf(0.0, _shake - delta * 2.8)
	_flash = maxf(0.0, _flash - delta * 2.5)
	_banner_t = maxf(0.0, _banner_t - delta)
	_animate_fx(delta)
	if state == PLAY and direct != null and board != null:
		_track_replay()
		_track_captures()
		pieces_on = board.pieces_on_board() if board.has_method("pieces_on_board") else pieces_on
		_refresh_hud()
	queue_redraw()


func _track_replay() -> void:
	var playing := player != null and player.is_playing()
	if playing:
		replaying = true
		var anim := player.get_current_animation()
		var len := player.get_current_animation_length()
		var pos := player.current_animation_position
		if len > 0.0 and moves.size() > 0:
			# Map animation time onto move index (roughly uniform over ply count).
			move_index = clampi(int((pos / len) * float(moves.size())), 0, moves.size() - 1)
		if _progress:
			_progress.value = (pos / maxf(len, 0.001)) * 100.0
	elif _prev_playing and replaying:
		# Just finished.
		replaying = false
		move_index = moves.size() - 1 if moves.size() > 0 else -1
		_banner = "CHECKMATE" if moves.size() > 0 else "DONE"
		_banner_t = 2.0
		_flash = 0.85
		_flash_color = GOLD
		_shake = 0.55
		_burst(FIELD_POS + FIELD * 0.5, GOLD, 40, 360.0)
		_floater("Qe8#", FIELD_POS + Vector2(FIELD.x * 0.5, 40), GOLD)
		if _progress:
			_progress.value = 100.0
	_prev_playing = playing


func _track_captures() -> void:
	if board == null:
		return
	var pieces: Node = board.get_node_or_null("pieces")
	if pieces == null:
		return
	for p in pieces.get_children():
		if not (p is CanvasItem):
			continue
		var ci := p as CanvasItem
		var name := str(p.name)
		var prev: Color = _prev_modulate.get(name, Color.WHITE)
		# Direct capture keyframes fade modulate alpha toward 0.
		if prev.a > 0.6 and ci.modulate.a < 0.35:
			captures_seen += 1
			var gp := _piece_stage_pos(ci)
			_burst(gp, CAPTURE, 14, 240.0)
			_floater("x", gp + Vector2(0, -18), CAPTURE)
			_shake = maxf(_shake, 0.25)
		_prev_modulate[name] = ci.modulate


func _piece_stage_pos(ci: CanvasItem) -> Vector2:
	# Map Direct viewport local → stage field.
	var local: Vector2 = ci.global_position + Vector2(24, 24)  # piece centre ~48px
	var u: Vector2 = local / VP_SIZE
	return FIELD_POS + Vector2(u.x * FIELD.x, u.y * FIELD.y)


# --- HUD refresh --------------------------------------------------------------

func _refresh_hud() -> void:
	if _fen_label == null:
		return
	var fen := BoardScript.INIT_FEN if board == null else str(BoardScript.INIT_FEN)
	# Direct does not expose a live FEN serializer; show INIT after reset, and
	# annotate during replay.
	if replaying and move_index >= 0 and move_index < moves.size():
		var m = moves[move_index]
		var san := str(m[3]) if m is Array and m.size() > 3 else "?"
		_fen_label.text = "Replay  |  ply %d / %d  |  %s" % [move_index + 1, moves.size(), san]
	elif board and board.has_method("pieces_on_board") and board.pieces_on_board() == 32 \
			and not (player and player.is_playing()):
		_fen_label.text = fen
	else:
		_fen_label.text = "Position live on Direct board  |  %d pieces" % pieces_on
	_pieces_label.text = "Pieces  %d\nCaptures  %d" % [pieces_on, captures_seen]
	if replaying:
		_status_label.text = "Replaying recorded game"
		_status_label.add_theme_color_override("font_color", GOLD)
	else:
		_status_label.text = "Starting position" if pieces_on == 32 else "Board cleared / mid-game"
		_status_label.add_theme_color_override("font_color", MUTED)
	_rebuild_moves_text()


func _rebuild_moves_text() -> void:
	if _moves_label == null:
		return
	var bb := ""
	var i := 0
	while i < moves.size():
		var w = moves[i]
		var num := int(w[0]) if w is Array else (i / 2 + 1)
		var wsan := str(w[3]) if w is Array and w.size() > 3 else "?"
		var line := "[color=#c9b896]%d.[/color] " % num
		var hi_w := (replaying or move_index >= 0) and i == move_index
		if hi_w:
			line += "[color=#ffd25a][b]%s[/b][/color]" % wsan
		else:
			line += "[color=#f2eee6]%s[/color]" % wsan
		if i + 1 < moves.size():
			var b = moves[i + 1]
			var bsan := str(b[3]) if b is Array and b.size() > 3 else "?"
			var hi_b := (replaying or move_index >= 0) and (i + 1) == move_index
			if hi_b:
				line += "  [color=#ffd25a][b]%s[/b][/color]" % bsan
			else:
				line += "  [color=#f2eee6]%s[/color]" % bsan
		bb += line + "\n"
		i += 2
	_moves_label.text = bb if bb != "" else "[color=#9a907e]No recorded moves.[/color]"


# --- draw ---------------------------------------------------------------------

func _draw() -> void:
	# Stage backdrop
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0 * _shake * _shake
	draw_rect(Rect2(Vector2.ZERO, STAGE), BG_TOP)
	# Warm vertical gradient (felt / study lamps)
	for i in 18:
		var t := float(i) / 18.0
		var c := BG_TOP.lerp(BG_BOT, t)
		c.a = 0.55
		draw_rect(Rect2(0, STAGE.y * t, STAGE.x, STAGE.y / 18.0 + 1.0), c)
	# Soft vignette corners
	draw_circle(Vector2(80, 60), 220, Color(0.35, 0.18, 0.05, 0.18))
	draw_circle(Vector2(STAGE.x - 60, STAGE.y - 40), 260, Color(0.15, 0.08, 0.18, 0.22))
	# Board wood frame (behind SubViewport)
	if state == PLAY:
		var fr := Rect2(FIELD_POS + shake - Vector2(18, 18), FIELD + Vector2(36, 36))
		draw_rect(fr, WOOD_FRAME)
		draw_rect(fr.grow(-6), Color(0.18, 0.10, 0.05))
		# File / rank labels around the field
		var files := "abcdefgh"
		for f in 8:
			var x := FIELD_POS.x + shake.x + (f + 0.5) * (FIELD.x / 8.0)
			_draw_label(files[f], Vector2(x, FIELD_POS.y + FIELD.y + shake.y + 8), 14, MUTED)
			_draw_label(str(8 - f), Vector2(FIELD_POS.x + shake.x - 18,
					FIELD_POS.y + shake.y + (f + 0.5) * (FIELD.y / 8.0) - 8), 14, MUTED)
	# Flash / particles / floaters / banner
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
		var r := Rect2(STAGE.x * 0.5 - 180, 36, 360, 36)
		draw_rect(r, Color(0.08, 0.06, 0.10, 0.75 * a))
		_draw_label(_banner, r.position + Vector2(r.size.x * 0.5 - _banner.length() * 5.5, 8),
				18, Color(GOLD.r, GOLD.g, GOLD.b, a))


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
			"grav": 40.0,
		})


func _floater(text: String, at: Vector2, color: Color) -> void:
	_floaters.append({
		"pos": at,
		"life": 1.1,
		"max": 1.1,
		"text": text,
		"color": color,
		"size": 22.0,
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
		f.pos.y -= 28.0 * delta
		if f.life <= 0.0:
			_floaters.remove_at(i)
		else:
			_floaters[i] = f
			i += 1


# --- UI build -----------------------------------------------------------------

func _build_stage() -> void:
	_board_frame = ColorRect.new()
	_board_frame.color = Color(0, 0, 0, 0)  # drawn in _draw; placeholder for layout
	_board_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_frame.visible = false
	add_child(_board_frame)

	_viewport = SubViewport.new()
	_viewport.name = "DirectVP"
	_viewport.size = Vector2i(VP_SIZE)
	_viewport.transparent_bg = true
	_viewport.handle_input_locally = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.gui_disable_input = false

	_vp_box = SubViewportContainer.new()
	_vp_box.name = "BoardView"
	_vp_box.position = FIELD_POS
	_vp_box.size = FIELD
	_vp_box.stretch = true
	_vp_box.visible = false
	_vp_box.add_child(_viewport)
	# SubViewportContainer must live under a CanvasItem in tree; add as child.
	var host := CanvasLayer.new()
	host.layer = 0
	host.name = "BoardLayer"
	add_child(host)
	# Position via a Control full-stage so letterbox transform applies via parent Node2D...
	# Actually CanvasLayer ignores Node2D transform — put the container under a
	# Control child of this Node2D instead.
	host.queue_free()
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

	# Title bar
	var title := _panel(Rect2(24, 18, 330, 56))
	_hud.add_child(title)
	title.add_child(_label("CHESS COACH", 22, GOLD, Vector2(16, 10)))
	title.add_child(_label("Enhanced  |  FEN board + replay", 12, MUTED, Vector2(16, 34)))

	# Left: FEN / status
	var left := _panel(Rect2(24, 88, 330, 200))
	_hud.add_child(left)
	left.add_child(_label("POSITION", 12, MUTED, Vector2(16, 12)))
	_fen_label = _label(BoardScript.INIT_FEN, 11, INK, Vector2(16, 36))
	_fen_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fen_label.size = Vector2(298, 70)
	left.add_child(_fen_label)
	_status_label = _label("Starting position", 13, MUTED, Vector2(16, 110))
	left.add_child(_status_label)
	_pieces_label = _label("Pieces  32\nCaptures  0", 14, INK, Vector2(16, 140))
	left.add_child(_pieces_label)

	# Left bottom: controls
	var controls := _panel(Rect2(24, 304, 330, 160))
	_hud.add_child(controls)
	controls.add_child(_label("CONTROLS", 12, MUTED, Vector2(16, 12)))
	controls.add_child(_label("R  Reset to starting FEN\nP  Replay recorded game\nEsc  Pause / Back to Arcade", 13, INK, Vector2(16, 36)))
	_hint_label = _label("Same Direct board, trays & AnimationPlayer.", 11, MUTED, Vector2(16, 120))
	controls.add_child(_hint_label)

	# Right: move list
	var right := _panel(Rect2(930, 88, 326, 520))
	_hud.add_child(right)
	right.add_child(_label("RECORDED GAME", 12, MUTED, Vector2(16, 12)))
	right.add_child(_label("fool's mate library", 11, GOLD, Vector2(16, 32)))
	_moves_label = RichTextLabel.new()
	_moves_label.position = Vector2(16, 56)
	_moves_label.size = Vector2(294, 400)
	_moves_label.bbcode_enabled = true
	_moves_label.fit_content = false
	_moves_label.scroll_active = true
	_moves_label.add_theme_font_size_override("normal_font_size", 13)
	_moves_label.add_theme_color_override("default_color", INK)
	right.add_child(_moves_label)
	_progress = ProgressBar.new()
	_progress.position = Vector2(16, 470)
	_progress.size = Vector2(294, 18)
	_progress.max_value = 100
	_progress.value = 0
	_progress.show_percentage = false
	right.add_child(_progress)

	# Buttons
	var back := _btn("Back to Arcade", Vector2(24, 660), Vector2(160, 36))
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(GameRegistry.return_to_arcade)
	_hud.add_child(back)
	var reset := _btn("Reset", Vector2(200, 660), Vector2(100, 36))
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(func(): _do_reset())
	_hud.add_child(reset)
	var replay := _btn("Replay", Vector2(316, 660), Vector2(110, 36))
	replay.focus_mode = Control.FOCUS_NONE
	replay.pressed.connect(func(): _do_replay())
	_hud.add_child(replay)

	# Title card
	var card := _panel(Rect2(STAGE.x * 0.5 - 280, STAGE.y * 0.5 - 150, 560, 300))
	card.name = "TitleCard"
	_ui.add_child(card)
	_cards["title"] = card
	card.add_child(_label("CHESS COACH", 36, GOLD, Vector2(40, 40)))
	card.add_child(_label("Enhanced edition", 16, ACCENT, Vector2(40, 90)))
	card.add_child(_label(
		"Walnut board chrome over the Direct FEN trays.\nSame pieces, same recorded replay.\nNo Stockfish - just the board.",
		14, INK, Vector2(40, 130)))
	card.add_child(_label("Enter / Space  to begin", 15, MUTED, Vector2(40, 230)))


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
	return l


func _btn(text: String, pos: Vector2, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	return b
