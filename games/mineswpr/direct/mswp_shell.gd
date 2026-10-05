extends RefCounted
## The `chain: mswp'` command parser from mineswpr.org, plus just enough of the
## Retro listener to run it: a persistent data stack, numbers read in hex
## (mineswpr-play does `reset hex`), and words looked up in mswp'.
##
##   x y +   flag      x y -   unflag      x y ?   prod for mine
##   a..f    push $A..$F      r  game-new      q  quit
##
## As in the original, numbers stay on the stack between lines, and a command
## with fewer than two numbers on the stack does nothing.

signal quit_requested  ## `q` -> mineswpr-exit-hook

var game  ## mineswpr_logic.gd instance
var stack: Array[int] = []
var last_error := ""  ## "word ?" for the most recent unknown token, if any


func _init(p_game) -> void:
	game = p_game


## Run one line of input. Returns true if any token was processed.
func eval_line(line: String) -> bool:
	last_error = ""
	var any := false
	for tok in line.strip_edges().split(" ", false):
		tok = tok.strip_edges()
		if tok == "":
			continue
		any = true
		eval_token(tok)
	return any


func eval_token(tok: String) -> void:
	match tok:
		"+": _if_cell_ok(game.flag_add)
		"-": _if_cell_ok(game.flag_remove)
		"?": _if_cell_ok(game.prod)
		"a": stack.push_back(0xA)
		"b": stack.push_back(0xB)
		"c": stack.push_back(0xC)
		"d": stack.push_back(0xD)
		"e": stack.push_back(0xE)
		"f": stack.push_back(0xF)
		"r": game.game_new()
		"q": quit_requested.emit()
		# the two Retro words the original screen tells you about
		"play":  # mineswpr-play: reset hex game-new
			stack.clear()
			game.game_new()
		"reset":
			stack.clear()
		_:
			var n = parse_hex(tok)
			if n == null:
				last_error = tok + " ?"
			else:
				stack.push_back(n)


## Retro number syntax in hex: optional leading '-', digits 0-9 A-F (either case).
static func parse_hex(tok: String):
	var s := tok
	var neg := false
	if s.begins_with("-") and s.length() > 1:
		neg = true
		s = s.substr(1)
	if s.length() > 8 or not s.is_valid_hex_number(false):
		return null
	var n := s.hex_to_int()
	return -n if neg else n


## if-cell-ok ( xyq- ): needs depth >= 2 and an in-bounds point.
func _if_cell_ok(action: Callable) -> void:
	if stack.size() < 2:
		return
	var y: int = stack.pop_back()
	var x: int = stack.pop_back()
	if game.inbounds(x, y):
		var c: int = game.cell(x, y)  # with-cell
		game.active_cell = c
		action.call(c)


## `.s`-style dump of the stack, numbers in hex.
func stack_text() -> String:
	var parts: PackedStringArray = ["<%d>" % stack.size()]
	for n in stack:
		parts.append(("-%X" % -n) if n < 0 else ("%X" % n))
	return " ".join(parts)
