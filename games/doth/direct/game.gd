extends Control
## Doth Direct — 80×25 CP437 TermGrid presentation of silverware Doth-A.
## Visual SoT: games/doth/source/doth-reference-dosbox.png (DOSBox DOTH-A).
## Chrome from other/dplay1.pic; room glyphs/attrs from work/doth_a.pas.
## Esc → PauseOverlay. Letterbox via GameRegistry.

const World := preload("res://games/doth/direct/doth_world.gd")

const MAP_W := World.MAP_W
const MAP_H := World.MAP_H
const MAP_OX := 1  ## room[1,1] → screen (1,1) 0-based (dplay1 interior)
const MAP_OY := 1

## ANSI/xterm indices (TermGrid palette). PAS wallatr=$06 DOS-brown → ANSI 3.
const FG_WALL := 3
const FG_HERO := 11   ## DOS $0E yellow
const FG_COIN := 10   ## green $ as in DOS shot (PAS used yellow •)
const FG_GEM := 11    ## yellow *
const FG_HEART := 9   ## DOS $0C light red
const FG_AMMO := 7    ## DOS $07 gray ¶
const FG_BOULDER := 7
const FG_FLOOR := 0
const FG_WHITE := 15
const FG_GRAY := 7
const FG_DIM := 8
const FG_YELLOW := 14
const FG_GREEN := 10
const FG_LABEL_HI := 15
const FG_LABEL_LO := 10
const FG_COLON := 14

const CH_WALL := "█"
const CH_HERO := "☺"
const CH_COIN := "$"
const CH_GEM := "*"
const CH_HEART := "♥"
const CH_AMMO := "¶"
const CH_BOULDER := "O"
const CH_FLOOR := " "

var world = World.new()
var _elapsed := 0.0

@onready var term: Control = %Term


func _ready() -> void:
	_redraw()


func _process(delta: float) -> void:
	if world.state == World.State.PLAY:
		_elapsed += delta
		# Refresh timer ~1 Hz without redrawing every frame.
		if int(_elapsed) != int(_elapsed - delta):
			_draw_timer()
			term.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var e := event as InputEventKey
	if world.state == World.State.TITLE or world.state == World.State.WIN:
		world.handle_title_key(e.keycode)
		if world.state == World.State.PLAY:
			_elapsed = 0.0
		_redraw()
		return
	var d := _dir_from_key(e)
	if d != Vector2i.ZERO:
		world.try_move(d.x, d.y)
		_redraw()
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_1:
		world.start_play("starter")
		_elapsed = 0.0
		_redraw()
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_2:
		world.start_play("overworld")
		_elapsed = 0.0
		_redraw()
		get_viewport().set_input_as_handled()


func _dir_from_key(e: InputEventKey) -> Vector2i:
	match e.keycode:
		KEY_UP, KEY_W, KEY_KP_8:
			return Vector2i(0, -1)
		KEY_DOWN, KEY_S, KEY_KP_2:
			return Vector2i(0, 1)
		KEY_LEFT, KEY_A, KEY_KP_4:
			return Vector2i(-1, 0)
		KEY_RIGHT, KEY_D, KEY_KP_6:
			return Vector2i(1, 0)
		KEY_KP_7, KEY_HOME:
			return Vector2i(-1, -1)
		KEY_KP_9, KEY_PAGEUP:
			return Vector2i(1, -1)
		KEY_KP_1, KEY_END:
			return Vector2i(-1, 1)
		KEY_KP_3, KEY_PAGEDOWN:
			return Vector2i(1, 1)
		_:
			pass
	match e.physical_keycode:
		KEY_W:
			return Vector2i(0, -1)
		KEY_S:
			return Vector2i(0, 1)
		KEY_A:
			return Vector2i(-1, 0)
		KEY_D:
			return Vector2i(1, 0)
		_:
			return Vector2i.ZERO


func _redraw() -> void:
	term.cscr(FG_GRAY, 0)
	_draw_chrome()
	match world.state:
		World.State.TITLE:
			_draw_title()
		_:
			_draw_map()
			_draw_status_values()
			_draw_timer()
			_draw_message()


func _draw_chrome() -> void:
	## Frame + controls column from dplay1.pic (single-line box, atr $08/$09/$0F).
	var box := FG_DIM
	# Top / bottom borders
	term.put(0, 0, "┌", box, 0)
	term.put(71, 0, "┐", box, 0)
	for x in range(1, 71):
		term.put(x, 0, "─", box, 0)
	for x in range(72, 80):
		term.put(x, 0, "─", 9, 0)  ## light blue rules over controls title
	term.put(0, 21, "├", box, 0)
	term.put(71, 21, "┤", box, 0)  ## overwritten by timer tee below
	term.put(0, 24, "└", box, 0)
	term.put(79, 24, "┘", box, 0)
	for x in range(1, 79):
		term.put(x, 24, "─", box, 0)
	# Verticals map / sidebar
	for y in range(1, 21):
		term.put(0, y, "│", box, 0)
		term.put(71, y, "│", box, 0)
	for y in range(22, 24):
		term.put(0, y, "│", box, 0)
		term.put(79, y, "│", box, 0)
	# Status split at col 27
	term.put(27, 21, "┬", box, 0)
	term.put(27, 22, "│", box, 0)
	term.put(27, 23, "│", box, 0)
	term.put(27, 24, "┴", box, 0)
	for x in range(1, 27):
		term.put(x, 21, "─", box, 0)
	for x in range(28, 71):
		term.put(x, 21, "─", box, 0)
	# Controls header + rules
	term.puts(72, 1, "controls", FG_WHITE, 0)
	for x in range(72, 80):
		term.put(x, 2, "─", 9, 0)
		term.put(x, 7, "─", 9, 0)
		term.put(x, 13, "─", 9, 0)
		term.put(x, 16, "─", 9, 0)
	_ctrl_line(3, 24, " NoRTH")   ## ↑ CP437 0x18
	_ctrl_line(4, 25, " SouTH")
	_ctrl_line(5, 16, " eaST ")   ## ► 0x10
	_ctrl_line(6, 17, " WeST ")
	_ctrl_line(8, 45, " SHooT")   ## '-'
	_ctrl_line(9, 47, " TaLK ")
	_ctrl_line(10, 42, " MaGiC")
	_ctrl_line(11, 43, " iTeMS")
	_ctrl_line(12, 48, " MaP  ")
	# f1 / esc (multi-char keys)
	term.put_cp(72, 14, 102, FG_GRAY, 0)  ## f
	term.put_cp(73, 14, 49, FG_GRAY, 0)   ## 1
	term.put(74, 14, ":", FG_COLON, 0)
	_mixed(75, 14, " HeLP")
	term.puts(72, 15, "esc", FG_GRAY, 0)
	term.put(75, 15, ":", FG_COLON, 0)
	_mixed(76, 15, "MeNu")
	# Timer box (rows 17-20, cols 71-79)
	term.put(71, 17, "├", box, 0)
	term.put(79, 17, "┐", box, 0)
	term.put(71, 19, "├", box, 0)
	term.put(79, 19, "┤", box, 0)
	term.put(71, 21, "┴", box, 0)
	for x in range(72, 79):
		term.put(x, 17, "─", box, 0)
		term.put(x, 19, "─", box, 0)
		term.put(x, 21, "─", box, 0)
	term.put(71, 18, "│", box, 0)
	term.put(79, 18, "│", box, 0)
	term.put(71, 20, "│", box, 0)
	term.put(79, 20, "│", box, 0)
	# Static status labels (dplay1 mixed case)
	_mixed(1, 22, "NaMe")
	term.put(5, 22, ":", FG_COLON, 0)
	_mixed(1, 23, "RaNK")
	term.put(5, 23, ":", FG_COLON, 0)
	_mixed(30, 23, "CaSH")
	term.put(34, 23, ":", FG_COLON, 0)
	_mixed(43, 23, "MaGiC")
	term.put(48, 23, ":", FG_COLON, 0)
	_mixed(55, 23, "aMMo")
	term.put(59, 23, ":", FG_COLON, 0)
	_mixed(66, 23, "HeaLTH")
	term.put(72, 23, ":", FG_COLON, 0)


func _ctrl_line(row: int, cp_icon: int, label: String) -> void:
	term.put_cp(72, row, cp_icon, FG_GRAY, 0)
	term.put(73, row, ":", FG_COLON, 0)
	_mixed(74, row, label)


func _mixed(x: int, y: int, s: String) -> void:
	## Uppercase → white, lowercase → green (dplay1 label style).
	for i in s.length():
		var ch := s[i]
		var fg := FG_LABEL_LO if ch.to_lower() == ch and ch.to_upper() != ch else FG_LABEL_HI
		if ch == " ":
			fg = FG_LABEL_HI
		term.put(x + i, y, ch, fg, 0)


func _draw_timer() -> void:
	var sec := int(_elapsed) if world.state == World.State.PLAY else 0
	var mm := mini(99, sec / 60)
	var ss := sec % 60
	var t := "%02d:%02d" % [mm, ss]
	term.puts(73, 18, t, FG_DIM, 0)


func _draw_status_values() -> void:
	var name_s: String = world.name_str.left(18)
	term.puts(7, 22, name_s, FG_WHITE, 0)
	term.puts(7, 23, world.rank_str.left(18), 12, 0)  ## blue-ish rank like PAS |B
	term.puts(36, 23, "%06d" % world.cash, FG_GRAY, 0)
	term.puts(50, 23, "%04d" % world.magic, FG_GRAY, 0)
	term.puts(61, 23, "%04d" % world.ammo, FG_GRAY, 0)
	term.puts(74, 23, "%04d" % world.health, FG_GRAY, 0)


func _draw_message() -> void:
	var msg: String = world.message.left(40)
	term.puts(29, 22, msg, FG_DIM, 0)


func _draw_map() -> void:
	for y in MAP_H:
		for x in MAP_W:
			var k: int = world.cells[world.idx(x, y)]
			var ch := CH_FLOOR
			var fg := FG_FLOOR
			match k:
				World.Kind.WALL:
					ch = CH_WALL
					fg = FG_WALL
				World.Kind.HERO:
					ch = CH_HERO
					fg = FG_HERO
				World.Kind.COIN:
					ch = CH_COIN
					fg = FG_COIN
				World.Kind.GEM:
					ch = CH_GEM
					fg = FG_GEM
				World.Kind.HEART:
					ch = CH_HEART
					fg = FG_HEART
				World.Kind.AMMO:
					ch = CH_AMMO
					fg = FG_AMMO
				World.Kind.BOULDER:
					ch = CH_BOULDER
					fg = FG_BOULDER
				_:
					ch = CH_FLOOR
					fg = FG_FLOOR
			if ch != CH_FLOOR:
				term.put(MAP_OX + x, MAP_OY + y, ch, fg, 0)
	if world.state == World.State.WIN:
		term.puts(22, 10, " Room cleared! Enter=title ", FG_YELLOW, 4)


func _draw_title() -> void:
	## Text title card inside the map frame (no SvA brick field).
	for y in range(1, 21):
		for x in range(1, 71):
			term.put(x, y, " ", FG_GRAY, 0)
	term.puts(32, 4, "DOTH", FG_YELLOW, 0)
	term.puts(24, 6, "Quest for the Empire", FG_WHITE, 0)
	term.puts(14, 8, "(c) 1993-1996 Sterling Silverware / Michal Wallace", FG_DIM, 0)
	term.puts(18, 11, "Enter / Space / 2  —  overworld (dmap1)", FG_GREEN, 0)
	term.puts(26, 13, "1  —  starter chamber", FG_GREEN, 0)
	term.puts(24, 16, "Esc — pause / Back to Arcade", FG_DIM, 0)
	_draw_status_values()
	term.puts(29, 22, "CP437 TermGrid Direct", FG_DIM, 0)
