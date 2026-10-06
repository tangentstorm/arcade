extends Control
## Terratri (Enhanced). Visual/UI makeover of the Direct hotseat port.
## Rules, notation and state are Direct's terratri_game.gd / terratri_rules.gd /
## terratri_input.gd (preloaded, not copied); the keymap is Direct game.gd's KEYS (loaded at runtime).
## Every legal step goes through the same Game.apply_step(); this file only
## diffs the previous and next snapshots to drive presentation: a lit tabletop
## board, sliding/hopping pawns, claim and capture ripples, rising forts, turn
## banners, player cards with fort trays + action pips, a territory balance bar,
## title / win cards and synthesized SFX. Esc is handled by the PauseOverlay.
##
## The title's scale mode is `expand` (shared with Direct); this shell designs
## on a 1280x720 stage and fits it to the window itself, while the backdrop
## fills the whole window.

const Game := preload("res://games/terratri/direct/terratri_game.gd")
const Rules := preload("res://games/terratri/direct/terratri_rules.gd")
const In := preload("res://games/terratri/direct/terratri_input.gd")
## Direct game.gd owns the keymap (KEYS); loaded at runtime because that
## script names the GameRegistry autoload.
const DIRECT_SHELL := "res://games/terratri/direct/game.gd"
const Board := preload("res://games/terratri/enhanced/board.gd")
const Sfx := preload("res://games/terratri/enhanced/sfx.gd")

enum { TITLE, PLAY, OVER }

const STAGE := Vector2(1280, 720)
const BOARD_POS := Vector2(360, 92)
const LEFT := Rect2(24, 92, 312, 560)
const RIGHT := Rect2(944, 92, 312, 560)
const CLAIM_SEC := 0.45
const FORT_SEC := 0.55
const HOP_SEC := 0.26
const BANNER_SEC := 1.3

const BG_TOP := Color("0b0d1a")
const BG_BOT := Color("1c1430")
const PANEL := Color(0.075, 0.085, 0.15, 0.94)
const INK := Color("f2eee6")
const MUTED := Color("9aa0bf")
const GOLD := Color("ffd25a")
const RED := Color("f0874a")       # original client .red #e08040, brightened
const RED_LAND := Color("6a3420")
const BLUE := Color("5a8cf0")      # original client .blue #4070c0, brightened
const BLUE_LAND := Color("1f3466")

var game: RefCounted = Game.new()
var _keys: Dictionary = {}
var state := TITLE
var sfx: Node
var time := 0.0
var glow_color := RED

## Presentation-only animation state (cell index = y * 5 + x).
var claim_t := PackedFloat32Array()
var claim_from: Array[String] = []
var fort_t := PackedFloat32Array()
var _pawn_from := {"r": Vector2.ZERO, "b": Vector2.ZERO}
var _pawn_to := {"r": Vector2.ZERO, "b": Vector2.ZERO}
var _pawn_k := {"r": 1.0, "b": 1.0}
var particles: Array[Dictionary] = []   ## stage coords
var floaters: Array[Dictionary] = []    ## stage coords
var shake := 0.0
var banner_t := 1.0
var banner_text := ""
var banner_side := "r"
var _motes: Array[Vector3] = []

## View-only counters derived from snapshot diffs (reset on restart).
var captures := {"r": 0, "b": 0}
var forts_built := {"r": 0, "b": 0}

var board: Control
var _stage: Control
var _fx: Control
var _cards := {}
var _status: Label
var _hint: Label
var _buttons := {}
var _side_ui := {}   ## side -> {panel, name, chip, stats, ready, deco}
var _history: RichTextLabel
var _win_title: Label
var _win_body: Label
var _stuck_body: Label
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	_keys = load(DIRECT_SHELL).KEYS
	claim_t.resize(25)
	fort_t.resize(25)
	claim_from.resize(25)
	sfx = Sfx.new()
	sfx.name = "Sfx"
	add_child(sfx)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2011
	for i in 46:
		_motes.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.3, 1.0)))
	_build_ui()
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_sync_visuals()
	_refresh()
	_show_card("title")


func _exit_tree() -> void:
	if sfx:
		sfx.stop_all()


func _layout() -> void:
	var sz := get_viewport_rect().size
	if size != sz:
		size = sz
	var s := minf(sz.x / STAGE.x, sz.y / STAGE.y)
	_stage.scale = Vector2(s, s)
	_stage.position = ((sz - STAGE * s) * 0.5).floor()


func side_color(side: String) -> Color:
	return RED if side == "r" else BLUE


func land_color(side: String) -> Color:
	return RED_LAND if side == "r" else BLUE_LAND


static func side_name(side: String) -> String:
	return "Red" if side == "r" else "Blue"


func interactive() -> bool:
	return state == PLAY


# -- UI construction -------------------------------------------------------------

func _style(bg: Color, radius: int, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.set_corner_radius_all(radius)
	st.border_color = border
	st.set_border_width_all(bw)
	st.anti_aliasing = true
	return st


func _label(parent: Node, text: String, fs: int, col: Color, pos: Vector2, w := 0.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	if w > 0.0:
		l.size = Vector2(w, 0)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, cb: Callable, fs := 15) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_disabled_color", Color(MUTED, 0.45))
	b.add_theme_stylebox_override("normal", _style(Color("232a46"), 10, Color("3a4470"), 1))
	b.add_theme_stylebox_override("hover", _style(Color("2f3860"), 10, Color("6a78b8"), 1))
	b.add_theme_stylebox_override("pressed", _style(Color("3a4578"), 10, GOLD, 1))
	b.add_theme_stylebox_override("disabled", _style(Color("181c30"), 10, Color("262c48"), 1))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_ui() -> void:
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.size = STAGE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_stage.draw.connect(_draw_stage)

	# header: logo, status, back
	_label(_stage, "TERRATRI", 30, INK, Vector2(30, 14))
	_label(_stage, "ENHANCED  |  HOTSEAT", 12, MUTED, Vector2(33, 52))
	_status = _label(_stage, "", 22, INK, Vector2(BOARD_POS.x, 14), Board.BOARD.x, HORIZONTAL_ALIGNMENT_CENTER)
	var back := _button(_stage, "Back to Arcade", _to_arcade)
	back.position = Vector2(1096, 18)
	back.size = Vector2(160, 36)

	board = Board.new()
	board.name = "Board"
	board.g = self
	board.position = BOARD_POS
	_stage.add_child(board)
	board.cell_clicked.connect(_on_cell)

	for side in ["r", "b"]:
		_build_side(side, LEFT if side == "r" else RIGHT)

	# action bar
	var bar := HBoxContainer.new()
	bar.position = Vector2(BOARD_POS.x, 662)
	bar.size = Vector2(Board.BOARD.x, 34)
	bar.add_theme_constant_override("separation", 8)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_stage.add_child(bar)
	_buttons["x"] = _button(bar, "End turn  Space", _action.bind("x"), 14)
	_buttons["k"] = _button(bar, "Bank  K", _action.bind("k"), 14)
	_buttons["f"] = _button(bar, "Fortify  F", _action.bind("f"), 14)
	_buttons["undo"] = _button(bar, "Undo  Bksp", undo, 14)
	_buttons["restart"] = _button(bar, "Restart  R", restart, 14)
	for b in _buttons.values():
		b.custom_minimum_size = Vector2(102, 34)
	_hint = _label(_stage, "Click a glowing square or use arrows / WASD  |  M sound  |  Esc pause", 13, MUTED,
		Vector2(BOARD_POS.x, 700), Board.BOARD.x, HORIZONTAL_ALIGNMENT_CENTER)

	_fx = Control.new()
	_fx.name = "Fx"
	_fx.size = STAGE
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_fx)
	_fx.draw.connect(_draw_fx)

	_build_cards()


func _build_side(side: String, rect: Rect2) -> void:
	var col := side_color(side)
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style(PANEL, 18, Color(col, 0.35), 2))
	_stage.add_child(panel)
	var deco := Control.new()
	deco.size = rect.size
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(deco)
	deco.draw.connect(_draw_side.bind(side, deco))
	var ui := {"panel": panel, "deco": deco}
	ui.name = _label(panel, side_name(side).to_upper(), 30, col, Vector2(70, 16))
	ui.chip = _label(panel, "TO MOVE", 13, GOLD, Vector2(168, 28), 124, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(panel, "ACTIONS", 12, MUTED, Vector2(20, 68))
	_label(panel, "FORTS", 12, MUTED, Vector2(20, 124))
	ui.stats = _label(panel, "", 16, INK, Vector2(20, 210), 272)
	ui.stats.add_theme_constant_override("line_spacing", 1)
	ui.ready = _label(panel, "", 14, MUTED, Vector2(20, 318), 272)
	if side == "r":
		_label(panel, "MOVE LOG", 12, MUTED, Vector2(20, 352))
		_history = RichTextLabel.new()
		_history.bbcode_enabled = true
		_history.scroll_active = false
		_history.position = Vector2(20, 374)
		_history.size = Vector2(272, 176)
		_history.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_history.add_theme_font_size_override("normal_font_size", 15)
		_history.add_theme_color_override("default_color", INK)
		panel.add_child(_history)
	else:
		_label(panel, "HOW TO PLAY", 12, MUTED, Vector2(20, 352))
		var how := Label.new()
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		how.custom_minimum_size = Vector2(272, 0)
		how.position = Vector2(20, 374)
		how.size = Vector2(272, 176)
		how.mouse_filter = Control.MOUSE_FILTER_IGNORE
		how.add_theme_font_size_override("font_size", 13)
		how.add_theme_color_override("font_color", Color(MUTED, 0.95))
		panel.add_child(how)
		how.text = ("2 actions a turn: step one square (not onto the enemy pawn or forts) or fortify.\n\n" \
			+ "Squares you leave stay claimed; stepping onto enemy land captures it.\n\n" \
			+ "Fortify needs 5 empty claimed squares. Bank your 2nd action for a bonus later. 5 forts wins.")
	_side_ui[side] = ui


func _card(id: String, accent: Color) -> VBoxContainer:
	var root := Control.new()
	root.size = STAGE
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.62)
	dim.size = STAGE
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var center := CenterContainer.new()
	center.size = STAGE
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var panel := PanelContainer.new()
	var st := _style(Color(0.07, 0.08, 0.14, 0.97), 22, Color(accent, 0.8), 3)
	st.shadow_color = Color(accent, 0.25)
	st.shadow_size = 26
	st.content_margin_left = 44
	st.content_margin_right = 44
	st.content_margin_top = 30
	st.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", st)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	_stage.add_child(root)
	root.visible = false
	_cards[id] = root
	return vb


func _card_label(vb: Node, text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	vb.add_child(l)
	return l


func _build_cards() -> void:
	var vb := _card("title", GOLD)
	var t := _card_label(vb, "TERRATRI", 64, INK)
	t.add_theme_color_override("font_outline_color", Color(GOLD, 0.35))
	t.add_theme_constant_override("outline_size", 10)
	_card_label(vb, "a territory game by Adam \"Atomic\" Saltsman", 16, MUTED)
	var body := _card_label(vb, "Two pawns | a 5x5 field | two actions a turn.\n" \
		+ "Claim squares as you move, fortify on your own land,\nbank an action for a bonus later.\n" \
		+ "First to raise 5 forts wins.", 19, INK)
	body.custom_minimum_size = Vector2(560, 0)
	_card_label(vb, "Hotseat for 2 players  |  Red moves first", 15, Color(RED, 0.95))
	_card_label(vb, "Space / Enter to start", 24, GOLD)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	_button(row, "Start", start, 18).custom_minimum_size = Vector2(150, 40)
	_button(row, "Back to Arcade", _to_arcade, 16).custom_minimum_size = Vector2(170, 40)

	vb = _card("win", GOLD)
	_win_title = _card_label(vb, "RED WINS", 60, RED)
	_win_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	_win_title.add_theme_constant_override("outline_size", 8)
	_win_body = _card_label(vb, "", 19, INK)
	_win_body.custom_minimum_size = Vector2(520, 0)
	row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	_button(row, "Play again  R", restart, 18).custom_minimum_size = Vector2(170, 40)
	_button(row, "Undo  Bksp", undo, 16).custom_minimum_size = Vector2(140, 40)
	_button(row, "Back to Arcade", _to_arcade, 16).custom_minimum_size = Vector2(170, 40)

	vb = _card("stuck", Color("ff6a5a"))
	_card_label(vb, "BOXED IN", 44, Color("ff8a7a"))
	_stuck_body = _card_label(vb, "", 18, INK)
	_stuck_body.custom_minimum_size = Vector2(500, 0)
	row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	_button(row, "Undo  Bksp", undo, 18).custom_minimum_size = Vector2(150, 40)
	_button(row, "Restart  R", restart, 18).custom_minimum_size = Vector2(150, 40)


func _show_card(id: String) -> void:
	for k in _cards:
		_cards[k].visible = k == id


func _to_arcade() -> void:
	var reg := get_node_or_null("/root/GameRegistry")
	if reg != null:
		reg.return_to_arcade()


# -- input -----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match state:
		TITLE:
			if k.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
				start()
			else:
				return
		OVER:
			if k.keycode in [KEY_R, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
				restart()
			elif k.keycode in [KEY_BACKSPACE, KEY_U, KEY_Z]:
				undo()
			else:
				return
		PLAY:
			if _keys.has(k.keycode):
				_action(_keys[k.keycode])
			elif k.keycode in [KEY_BACKSPACE, KEY_U, KEY_Z]:
				undo()
			elif k.keycode == KEY_R:
				restart()
			elif k.keycode == KEY_M:
				sfx.muted = not sfx.muted
				_float_at(Vector2(640, 80), "SOUND OFF" if sfx.muted else "SOUND ON", MUTED, 18)
			else:
				return
	get_viewport().set_input_as_handled()


func start() -> void:
	if state != TITLE:
		return
	state = PLAY
	_show_card("")
	sfx.play("start")
	_sync_visuals()
	_refresh()
	_turn_banner(game.whose_turn)


func _action(action: String) -> void:
	if state != PLAY:
		return
	var step := In.step_for_action(game.valid_steps, action)
	if step == "":
		_reject()
		return
	play_step(step)


func _on_cell(cell: Vector2i) -> void:
	if state != PLAY:
		return
	var step := In.step_for_cell(game.valid_steps, cell)
	if step == "":
		_reject(cell)
		return
	play_step(step)


func _reject(cell := Vector2i(-1, -1)) -> void:
	sfx.play("nope")
	shake = maxf(shake, 3.0)
	if cell.x >= 0:
		_burst(BOARD_POS + Board.cell_center(cell), Color(MUTED, 0.6), 5, 60.0)


## Apply a step if legal (same contract as Direct game.gd). Returns whether it was played.
func play_step(step: String) -> bool:
	if not game.valid_steps.has(step):
		return false
	var prev: RefCounted = game
	game = game.apply_step(step)
	_juice(prev, game, step)
	_refresh()
	return true


func undo() -> void:
	if game.step_count() == 0:
		return
	game = Game.at_step(game.steps, game.step_count() - 1)
	if state == OVER and game.winner == "":
		state = PLAY
	sfx.play("undo")
	_sync_visuals()
	_refresh()


func restart() -> void:
	game = Game.new()
	captures = {"r": 0, "b": 0}
	forts_built = {"r": 0, "b": 0}
	particles.clear()
	floaters.clear()
	state = PLAY
	sfx.play("start")
	_sync_visuals()
	_refresh()
	_turn_banner("r")


# -- presentation derived from snapshot diffs -------------------------------------

## Snap every animation to the current snapshot (start, undo, restart).
func _sync_visuals() -> void:
	claim_t.fill(1.0)
	fort_t.fill(1.0)
	for i in 25:
		claim_from[i] = ""
	for side in ["r", "b"]:
		var p := _pawn_cell(game, side)
		_pawn_from[side] = p
		_pawn_to[side] = p
		_pawn_k[side] = 1.0
	glow_color = side_color(game.whose_turn if game.whose_turn != "" else game.winner if game.winner != "" else "r")


static func _pawn_cell(snap, side: String) -> Vector2:
	var f := Rules.find_pawn(side, snap.grid)
	return Vector2(f.x, f.y) if not f.is_empty() else Vector2(-9, -9)


func pawn_draw_pos(side: String) -> Vector2:
	var k: float = _pawn_k[side]
	return (_pawn_from[side] as Vector2).lerp(_pawn_to[side], 1.0 - pow(1.0 - k, 3))


func pawn_hop(side: String) -> float:
	var k: float = _pawn_k[side]
	return sin(PI * k) * 26.0 if k < 1.0 else 0.0


func land_count(side: String) -> int:
	var n := 0
	for row in game.grid:
		for ch in row:
			if Board.owner_of(ch) == side:
				n += 1
	return n


func turn_number() -> int:
	return game.steps.count("|") / 2 + 1


func _juice(prev, next, step: String) -> void:
	var side: String = prev.whose_turn
	var col := side_color(side)
	var claimed := 0
	for y in 5:
		for x in 5:
			var i := y * 5 + x
			var a: String = prev.grid[y][x]
			var b: String = next.grid[y][x]
			var oa := Board.owner_of(a)
			var ob := Board.owner_of(b)
			var center := BOARD_POS + Board.cell_center(Vector2i(x, y))
			if ob != "" and ob != oa:
				claim_t[i] = 0.0
				claim_from[i] = oa
				claimed += 1
				if oa != "":
					captures[ob] += 1
					_burst(center, side_color(ob).lightened(0.3), 16, 170.0)
					_float_at(center + Vector2(0, -40), "CAPTURE", side_color(ob).lightened(0.35), 18)
					shake = maxf(shake, 4.0)
					sfx.play("capture")
				else:
					_burst(center, side_color(ob), 8, 110.0)
					sfx.play("claim", randf_range(0.95, 1.1))
			if Board.is_fort(b) and not Board.is_fort(a):
				fort_t[i] = 0.0
				forts_built[ob] += 1
				_burst(center + Vector2(0, 26), Color("d8c8a8"), 22, 150.0, 0.0)
				_burst(center, GOLD, 12, 200.0)
				_float_at(center + Vector2(0, -52), "FORT %d / 5" % next.forts_on_board(ob), GOLD, 22)
				shake = maxf(shake, 9.0)
				sfx.play("fort")
	for s in ["r", "b"]:
		var p0 := _pawn_cell(prev, s)
		var p1 := _pawn_cell(next, s)
		if p0 != p1:
			_pawn_from[s] = pawn_draw_pos(s)
			_pawn_to[s] = p1
			_pawn_k[s] = 0.0
			sfx.play("move")
	if next.banked(side) > prev.banked(side):
		var card := (LEFT if side == "r" else RIGHT)
		_float_at(card.position + Vector2(card.size.x * 0.5, 100), "+1 BANKED", GOLD, 20)
		_coin_trail(BOARD_POS + Board.cell_center(Vector2i(_pawn_cell(next, side))), card.position + Vector2(160, 160), col)
		sfx.play("bank")
	elif next.banked(side) < prev.banked(side):
		_float_at(BOARD_POS + Board.cell_center(Vector2i(_pawn_cell(next, side))) + Vector2(0, -60), "BONUS ACTION",
			col.lightened(0.4), 18)
	if next.winner != "" and prev.winner == "":
		_win(next.winner)
	elif next.whose_turn != side and next.whose_turn != "":
		_turn_banner(next.whose_turn)
		sfx.play("turn")


func _turn_banner(side: String) -> void:
	if side == "":
		return
	banner_side = side
	banner_text = "%s'S TURN  |  TURN %d" % [side_name(side).to_upper(), turn_number()]
	banner_t = 0.0


func _win(side: String) -> void:
	state = OVER
	banner_t = 1.0
	sfx.play("win")
	shake = 12.0
	var col := side_color(side)
	for i in 90:
		var a := randf() * TAU
		var v := randf_range(120.0, 520.0)
		particles.append({"pos": BOARD_POS + Board.BOARD * 0.5, "vel": Vector2(cos(a), sin(a)) * v + Vector2(0, -160),
			"col": [col, col.lightened(0.4), GOLD, INK][i % 4], "life": randf_range(1.2, 2.2), "max": 2.2,
			"size": randf_range(3.0, 7.0), "g": 420.0, "confetti": true, "spin": randf() * TAU})
	_win_title.text = "%s WINS" % side_name(side).to_upper()
	_win_title.add_theme_color_override("font_color", col)
	_win_body.text = "%s raised 5 forts in %d turns.\nLand  Red %d | Blue %d      Captures  Red %d | Blue %d" % [
		side_name(side), turn_number(), land_count("r"), land_count("b"), captures.r, captures.b]
	_show_card("win")


func _burst(pos: Vector2, col: Color, n: int, speed: float, up := 60.0) -> void:
	for i in n:
		var a := randf() * TAU
		var v := randf_range(speed * 0.35, speed)
		particles.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * v + Vector2(0, -up), "col": col,
			"life": randf_range(0.35, 0.7), "max": 0.7, "size": randf_range(2.0, 4.5), "g": 260.0})


func _coin_trail(from: Vector2, to: Vector2, col: Color) -> void:
	for i in 8:
		particles.append({"pos": from, "vel": (to - from) / 0.6 + Vector2(randf_range(-60, 60), randf_range(-60, 60)),
			"col": GOLD if i % 2 == 0 else col.lightened(0.4), "life": 0.6, "max": 0.6, "size": 5.0, "g": 0.0})


func _float_at(pos: Vector2, text: String, col: Color, fs := 18) -> void:
	# stack floaters spawned together at the same spot
	for f in floaters:
		if f.max - f.life < 0.2 and absf(f.pos.x - pos.x) < 120.0 and absf(f.pos.y - pos.y) < 24.0:
			pos.y = f.pos.y - 26.0
	floaters.append({"pos": pos, "text": text, "col": col, "life": 1.1, "max": 1.1, "fs": fs})


# -- loop ------------------------------------------------------------------------

func _process(delta: float) -> void:
	time += delta
	for i in 25:
		if claim_t[i] < 1.0:
			claim_t[i] = minf(1.0, claim_t[i] + delta / CLAIM_SEC)
		if fort_t[i] < 1.0:
			fort_t[i] = minf(1.0, fort_t[i] + delta / FORT_SEC)
	for s in ["r", "b"]:
		_pawn_k[s] = minf(1.0, _pawn_k[s] + delta / HOP_SEC)
	var target := side_color(game.whose_turn) if game.whose_turn != "" else side_color(game.winner) if game.winner != "" else RED
	glow_color = glow_color.lerp(target, minf(1.0, delta * 4.0))
	if banner_t < 1.0:
		banner_t = minf(1.0, banner_t + delta / BANNER_SEC)
	for p in particles:
		p.life -= delta
		p.vel.y += p.g * delta
		p.pos += p.vel * delta
		if p.has("spin"):
			p.spin += delta * 8.0
	particles = particles.filter(func(p): return p.life > 0.0)
	for f in floaters:
		f.life -= delta
		f.pos.y -= 38.0 * delta
	floaters = floaters.filter(func(f): return f.life > 0.0)
	shake = maxf(0.0, shake - delta * 30.0)
	board.position = BOARD_POS + (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake if shake > 0.0 else Vector2.ZERO)
	queue_redraw()
	_stage.queue_redraw()
	board.queue_redraw()
	_fx.queue_redraw()
	for side in _side_ui:
		_side_ui[side].deco.queue_redraw()


func _refresh() -> void:
	var turn: String = game.whose_turn
	var v: Dictionary = game.valid_steps
	var stuck := turn != "" and v.is_empty()
	if game.winner != "":
		_status.text = "%s wins with 5 forts!" % side_name(game.winner)
		_status.add_theme_color_override("font_color", side_color(game.winner))
	elif stuck:
		_status.text = "%s is boxed in: Undo or Restart" % side_name(turn)
		_status.add_theme_color_override("font_color", Color("ff8a7a"))
	else:
		var idx: int = game.step_index()
		var what := "action %d of 2" % (idx + 1) if idx < 2 else "bonus action (spends 1 bank)"
		if idx == 1 and In.step_for_action(v, "k") != "":
			what += " | or bank it"
		_status.text = "%s  |  %s" % [side_name(turn), what]
		_status.add_theme_color_override("font_color", side_color(turn).lightened(0.15))
	var live := state == PLAY
	_buttons["x"].disabled = not live or In.step_for_action(v, "x") == ""
	_buttons["k"].disabled = not live or In.step_for_action(v, "k") == ""
	_buttons["f"].disabled = not live or In.step_for_action(v, "f") == ""
	_buttons["undo"].disabled = game.step_count() == 0 or state == TITLE
	_buttons["restart"].disabled = state == TITLE
	for side in ["r", "b"]:
		var ui: Dictionary = _side_ui[side]
		var mine: bool = side == turn
		ui.chip.text = "> TO MOVE" if mine else ("WINNER" if game.winner == side else "")
		ui.chip.add_theme_color_override("font_color", GOLD)
		ui.panel.add_theme_stylebox_override("panel", _style(PANEL, 18,
			Color(side_color(side), 0.9 if mine or game.winner == side else 0.25), 3 if mine else 2))
		ui.stats.text = "Forts     %d / 5\nLand      %d square%s\nBank      %d\nSupply    %d" % [
			game.forts_on_board(side), land_count(side), "" if land_count(side) == 1 else "s",
			game.banked(side), game.supply(side)]
		var empty := Rules.square_count(side, game.grid)
		if mine and In.step_for_action(v, "f") != "":
			ui.ready.text = "* FORTIFY READY  [F]"
			ui.ready.add_theme_color_override("font_color", GOLD)
		elif game.supply(side) <= 0:
			ui.ready.text = "Supply empty (forts placed or banked)"
			ui.ready.add_theme_color_override("font_color", MUTED)
		else:
			ui.ready.text = "Empty land %d / 5 to fortify" % mini(empty, 5) if empty < 5 \
				else "Fortify from open land (not on a fort)"
			ui.ready.add_theme_color_override("font_color", MUTED)
	var rows: Array = []
	var hist: Array = game.history
	for i in hist.size():
		var parts: PackedStringArray = String(hist[i]).split(" ")
		var red := parts[0] if parts.size() > 0 else ""
		var blue := parts[1] if parts.size() > 1 else ""
		rows.append("[color=#9aa0bf]%2d.[/color]  [color=#%s]%s[/color]   [color=#%s]%s[/color]" % [
			i + 1, RED.to_html(false), red, BLUE.to_html(false), blue])
	_history.text = "\n".join(rows.slice(maxi(0, rows.size() - 8)))
	if state == PLAY and stuck:
		_stuck_body.text = "%s has no legal step (hemmed in by edges and enemy pieces).\nThe original rules stall here too." % side_name(turn)
		_show_card("stuck")
	elif state == PLAY:
		_show_card("")


# -- drawing ---------------------------------------------------------------------

func _draw() -> void:
	var sz := size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), sz, Vector2(0, sz.y)]),
		PackedColorArray([BG_TOP, BG_TOP, BG_BOT, BG_BOT]))
	# faint diagonal weave
	var step := 56.0
	var x := -sz.y
	while x < sz.x:
		draw_line(Vector2(x, 0), Vector2(x + sz.y, sz.y), Color(1, 1, 1, 0.025), 1.0)
		x += step
	# glow behind the board in the colour of the side to move
	var s := _stage.scale.x
	var c := _stage.position + (BOARD_POS + Board.BOARD * 0.5) * s
	for i in 10:
		var r := (440.0 - i * 36.0) * s
		draw_circle(c, r, Color(glow_color, 0.022))
	for m in _motes:
		var p := Vector2(fmod(m.x * sz.x + time * 8.0 * m.z, sz.x), fmod(m.y * sz.y - time * 12.0 * m.z + sz.y * 4.0, sz.y))
		draw_circle(p, 1.2 + m.z, Color(glow_color.lightened(0.5), 0.10 + 0.12 * m.z))


func _draw_stage() -> void:
	# territory balance bar (red from the left, blue from the right)
	var bar := Rect2(BOARD_POS.x + 40, 58, Board.BOARD.x - 80, 12)
	var rl := land_count("r")
	var bl := land_count("b")
	var bs := StyleBoxFlat.new()
	bs.set_corner_radius_all(6)
	bs.bg_color = Color("1a1f36")
	_stage.draw_style_box(bs, bar)
	var rw := bar.size.x * rl / 25.0
	var bw := bar.size.x * bl / 25.0
	if rw > 0.0:
		bs.bg_color = RED
		_stage.draw_style_box(bs, Rect2(bar.position, Vector2(rw, bar.size.y)))
	if bw > 0.0:
		bs.bg_color = BLUE
		_stage.draw_style_box(bs, Rect2(bar.position + Vector2(bar.size.x - bw, 0), Vector2(bw, bar.size.y)))
	_stage.draw_line(Vector2(bar.get_center().x, bar.position.y - 3), Vector2(bar.get_center().x, bar.end.y + 3),
		Color(INK, 0.35), 1.0)
	_stage.draw_string(_font, Vector2(BOARD_POS.x, 70), str(rl), HORIZONTAL_ALIGNMENT_CENTER, 36, 15, RED)
	_stage.draw_string(_font, Vector2(BOARD_POS.x + Board.BOARD.x - 36, 70), str(bl), HORIZONTAL_ALIGNMENT_CENTER,
		36, 15, BLUE)


func _draw_side(side: String, deco: Control) -> void:
	var col := side_color(side)
	var mine: bool = game.whose_turn == side and state != TITLE
	# pawn badge
	var c := Vector2(40, 36)
	deco.draw_circle(c + Vector2(0, 4), 18, col.darkened(0.45))
	deco.draw_circle(c, 18, col)
	deco.draw_arc(c, 12, 0, TAU, 28, col.lightened(0.35), 2.5)
	deco.draw_circle(c, 5, INK)
	if mine:
		deco.draw_arc(c, 24 + sin(time * 5.0) * 1.5, 0, TAU, 36, Color(GOLD, 0.6), 2.0)
	# action pips: 2 regular + banked bonus coins
	var idx: int = game.step_index() if mine else 0
	for i in 2:
		var p := Vector2(32 + i * 34, 98)
		var used := mine and idx > i
		var next := mine and idx == i
		var r := 11.0 + (1.5 * sin(time * 6.0) if next else 0.0)
		deco.draw_circle(p, r, Color(col, 0.18) if used or not mine else col)
		deco.draw_arc(p, r, 0, TAU, 24, Color(col.lightened(0.3), 0.8 if mine else 0.3), 2.0)
	var bank: int = game.banked(side)
	for i in bank:
		var p := Vector2(118 + i * 28, 98)
		deco.draw_circle(p, 9, Color(GOLD, 0.95 if mine else 0.45))
		deco.draw_arc(p, 6, 0, TAU, 20, Color(0.5, 0.36, 0.05, 0.8), 1.5)
	if bank > 0:
		deco.draw_string(_font, Vector2(118 + bank * 28, 104), "bank", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
	# fort tray: built castles, banked coins, supply outlines
	var forts: int = game.forts_on_board(side)
	for i in 5:
		var base := Vector2(20 + i * 56, 146)
		var cell := Rect2(base, Vector2(48, 52))
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(8)
		sb.bg_color = Color("161a2e")
		sb.border_color = Color(col, 0.25)
		sb.set_border_width_all(1)
		deco.draw_style_box(sb, cell)
		var cc := cell.get_center() + Vector2(0, 4)
		if i < forts:
			_mini_castle(deco, cc, col, 1.0, false)
		elif i < forts + bank:
			deco.draw_circle(cc, 13, GOLD)
			deco.draw_arc(cc, 9, 0, TAU, 20, Color(0.5, 0.36, 0.05), 2.0)
		else:
			_mini_castle(deco, cc, col, 0.4, true)


func _mini_castle(ci: CanvasItem, c: Vector2, col: Color, alpha: float, ghost: bool) -> void:
	var rects := [Rect2(c + Vector2(-16, -14), Vector2(9, 28)), Rect2(c + Vector2(7, -14), Vector2(9, 28)),
		Rect2(c + Vector2(-7, -8), Vector2(14, 22))]
	for r in rects:
		if ghost:
			ci.draw_rect(r, Color(col.lightened(0.2), alpha), false, 1.5)
		else:
			ci.draw_rect(r, Color(col.lightened(0.1), alpha))
			ci.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.65, 0), Vector2(r.size.x * 0.35, r.size.y)),
				Color(col.darkened(0.35), alpha))
	if not ghost:
		ci.draw_rect(Rect2(c + Vector2(-3, 6), Vector2(6, 8)), Color(0.05, 0.05, 0.1))


func _draw_fx() -> void:
	for p in particles:
		var a: float = clampf(p.life / p.max, 0.0, 1.0)
		var col: Color = p.col
		if p.has("confetti"):
			_fx.draw_set_transform(p.pos, p.spin, Vector2.ONE)
			_fx.draw_rect(Rect2(-p.size, -p.size * 0.5, p.size * 2.0, p.size), Color(col, a))
			_fx.draw_set_transform(Vector2.ZERO)
		else:
			_fx.draw_circle(p.pos, p.size * (0.5 + 0.5 * a), Color(col, a))
	for f in floaters:
		var a: float = clampf(f.life / f.max * 1.6, 0.0, 1.0)
		var w := 300.0
		_fx.draw_string_outline(_font, f.pos - Vector2(w * 0.5, 0), f.text, HORIZONTAL_ALIGNMENT_CENTER, w, f.fs, 6,
			Color(0, 0, 0, 0.6 * a))
		_fx.draw_string(_font, f.pos - Vector2(w * 0.5, 0), f.text, HORIZONTAL_ALIGNMENT_CENTER, w, f.fs,
			Color(f.col, a))
	if banner_t < 1.0 and banner_text != "":
		# swoosh in, hold, swoosh out across the board
		var t := banner_t
		var slide := 0.0
		if t < 0.2:
			slide = (1.0 - t / 0.2)
		elif t > 0.8:
			slide = -((t - 0.8) / 0.2)
		var alpha := 1.0 - absf(slide)
		var y := BOARD_POS.y + Board.BOARD.y * 0.5
		var col := side_color(banner_side)
		var off := slide * 500.0
		_fx.draw_rect(Rect2(BOARD_POS.x - 40 + off, y - 34, Board.BOARD.x + 80, 68), Color(0.03, 0.03, 0.08, 0.82 * alpha))
		_fx.draw_rect(Rect2(BOARD_POS.x - 40 + off, y - 34, Board.BOARD.x + 80, 3), Color(col, alpha))
		_fx.draw_rect(Rect2(BOARD_POS.x - 40 + off, y + 31, Board.BOARD.x + 80, 3), Color(col, alpha))
		_fx.draw_string(_font, Vector2(BOARD_POS.x + off, y + 12), banner_text, HORIZONTAL_ALIGNMENT_CENTER,
			Board.BOARD.x, 34, Color(col.lightened(0.3), alpha))
