extends SceneTree
## Keyboard-only play for both 80x25 mineswpr hosts (GDScript Direct = /mineswpr.old,
## b4 cart = /mineswpr). Launches through GameRegistry, then drives the game with
## InputEventKey only: the original mswp' listener lines `x y ?`, `x y +`,
## `x y -`, `r`, `q` (mineswpr.org: no other keys exist). Also checks the 1280x800
## stage fits the window so the `ok` prompt (row 24) is on screen.

const PROMPT_ROW := 24
var _fail := 0


func _check(ok: bool, what: String) -> void:
	print(("  ok: " if ok else "  FAIL: ") + what)
	if not ok:
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _key(ch: String) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	match ch:
		"\n": ev.keycode = KEY_ENTER
		"\b": ev.keycode = KEY_BACKSPACE
		_:
			ev.keycode = OS.find_keycode_from_string(ch.to_upper()) if ch != " " else KEY_SPACE
			ev.unicode = ch.unicode_at(0)
			ev.shift_pressed = ch == "?" or ch == "+"
	ev.physical_keycode = ev.keycode
	root.push_input(ev)
	var up := ev.duplicate()
	up.pressed = false
	root.push_input(up)


func _type(s: String) -> void:
	for ch in s:
		_key(ch)
	await process_frame


## [mine, cover, flag] for board cell (x, y), read from whichever host runs.
func _bits(g, x: int, y: int) -> Array:
	var v: int = g.cart.cell_value(y * 16 + x) if "cart" in g else g.game.grid[y * 16 + x]
	return [v & 1 != 0, v & 2 != 0, v & 4 != 0]


func _find(g, want_mine: bool) -> Vector2i:
	for i in 256:  # mines from the far corner, so the hex has letters
		var x := i % 16 if not want_mine else 15 - i % 16
		var y := i / 16 if not want_mine else 15 - i / 16
		var b := _bits(g, x, y)
		if b[0] == want_mine and b[1] and not b[2]:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


func _play(reg, id: String) -> void:
	print("%s (keyboard only):" % id)
	reg.launch(reg.get_entry(id, "direct"))
	for i in 4:
		await process_frame
	var g = current_scene
	var term: Control = g.get_node("%Term") if g.has_node("%Term") else g.get_node("%TermGrid")
	var vis := root.get_visible_rect()
	_check(vis.encloses(term.get_global_rect()),
		"stage %s fits visible %s (prompt row on screen)" % [term.get_global_rect(), vis])

	var p := _find(g, false)
	var cmd := "%X %X" % [p.x, p.y]
	await _type(cmd + " Z\b")
	_check(term.row_text(PROMPT_ROW).contains(cmd) and not term.row_text(PROMPT_ROW).contains("Z"),
		"typed '%s' + Z + Backspace echoes '%s' on the ok prompt" % [cmd, cmd])
	await _type(" ?\n")
	_check(not _bits(g, p.x, p.y)[1], "'%s ?' + Enter uncovers (%d,%d)" % [cmd, p.x, p.y])
	_check(not term.row_text(PROMPT_ROW).contains(cmd), "Enter clears the prompt")

	var f := _find(g, true)
	cmd = "%x %x" % [f.x, f.y]  # lowercase hex a-f are words too
	await _type(cmd + " +\n")
	_check(_bits(g, f.x, f.y)[2], "'%s +' flags (%d,%d)" % [cmd, f.x, f.y])
	await _type(cmd + " -\n")
	_check(not _bits(g, f.x, f.y)[2], "'%s -' unflags it" % cmd)

	await _type("r\n")
	var covered := 0
	for y in 16:
		for x in 16:
			covered += int(_bits(current_scene, x, y)[1])
	_check(covered == 256, "'r' starts a new game (all 256 covered, got %d)" % covered)

	await _type("q\n")
	for i in 3:
		await process_frame
	_check(reg.in_arcade(), "'q' returns to the arcade")
	_check(root.content_scale_size == Vector2i(1280, 720), "arcade restores 1280x720 base")


func _run() -> void:
	var reg = root.get_node("GameRegistry")
	for id in ["mineswpr", "mineswpr_b4"]:
		await _play(reg, id)
	reg.launch(reg.get_entry("mineswpr", "enhanced"))
	for i in 3:
		await process_frame
	_check(root.content_scale_size == Vector2i(1280, 720), "Enhanced keeps its 1280x720 stage")
	reg.return_to_arcade()
	for i in 3:
		await process_frame
	print("mineswpr_keys: %s" % ("PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	quit(0 if _fail == 0 else 1)
