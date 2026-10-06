extends SceneTree
## Headless checks for the Tentraminos Enhanced edition: presentation over the unchanged
## Direct rules. Drives the real scene (keys go through game._unhandled_key_input) and
## replays the same inputs on a bare Direct logic instance to prove rule parity.
## Run: godot --headless --path . --script res://tools/test_tentraminos_enhanced.gd

const SCENE := "res://games/tentraminos/enhanced/game.tscn"
const Logic := preload("res://games/tentraminos/direct/tentraminos_logic.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: tentraminos_enhanced ", msg)
		_fail += 1


func _key(g, keycode: Key, echo := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	ev.echo = echo
	g._unhandled_key_input(ev)


func _same(g, d) -> bool:
	return g.game.matrix == d.matrix and g.game.hold == d.hold and g.game.score == d.score \
			and g.game.clock == d.clock and g.game.next == d.next \
			and g.game.cursor_x == d.cursor_x and g.game.cursor_y == d.cursor_y


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# registry: Enhanced is playable, points at this scene, letterboxed like Direct
	var reg = root.get_node_or_null("GameRegistry")
	_check(reg != null, "GameRegistry autoload present")
	if reg != null:
		var e = reg.get_entry("tentraminos", "enhanced")
		_check(e != null and e.status == "playable" and e.is_playable(), "registry: enhanced is playable")
		_check(e != null and e.scene_path == SCENE and e.scale_mode == "letterbox", "registry: enhanced scene + letterbox")
		var d = reg.get_entry("tentraminos", "direct")
		_check(d != null and d.is_playable(), "registry: direct still playable")

	var packed := load(SCENE) as PackedScene
	_check(packed != null, "enhanced scene loads")
	if packed == null:
		quit(1)
		return
	var g = packed.instantiate()
	g.seed_value = 1234
	g.persist_best = false
	root.add_child(g)
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 5:
		await process_frame
	_check(g.process_mode == Node.PROCESS_MODE_INHERIT, "game pauses with the tree (PauseOverlay)")
	_check(g.game is Logic, "rules are the shared Direct logic (tentraminos_logic.gd)")
	_check(not g.started and g.get_node("%Overlay").visible, "opens on the start card")
	_check(g.game.next == Logic.NEWGAME, "clock does not run before start")
	for b in ["%BackButton", "%CardBack"]:
		var btn: Button = g.get_node(b)
		_check(btn.visible and btn.focus_mode == Control.FOCUS_NONE, "%s visible, never steals keys" % b)
	var board: Control = g.get_node("%Board")
	var layout_min: Vector2 = g.get_node("Center/HBox").get_combined_minimum_size()
	_check(board.size.x >= 568 and board.size.y >= 646 and layout_min.x <= 1280.0 and layout_min.y <= 720.0
			and g.get_global_rect().encloses(board.get_global_rect()),
			"board + HUD fit the 1280×720 letterbox stage (%s)" % layout_min)

	# drive ticks by hand from here on (deterministic), mirrored on a bare Direct instance
	g.set_process(false)
	var d = Logic.new(1234)
	_check(_same(g, d), "same seed -> same opening tray as Direct")

	_key(g, KEY_SPACE)
	_check(g.started and not g.get_node("%Overlay").visible, "Space starts, card hides")
	_check(g.sfx.last_played == "start", "start jingle")

	# first drop: the tray row slides down and falls; both reach PLAYING identically
	g.tick_once(); d.tick()
	_check(g.offsets[0].y < -60.0, "released row starts in the tray (slide-down offset %.0f)" % g.offsets[0].y)
	var n := 1
	var fell_anim := false
	while d.next != Logic.PLAYING and n < 60:
		g.tick_once(); d.tick(); n += 1
		for i in range(Logic.GW, Logic.NUMCELLS):
			if g.offsets[i].y < -1.0:
				fell_anim = true
	_check(_same(g, d) and g.game.next == Logic.PLAYING, "first cascade matches Direct (%d ticks)" % n)
	_check(fell_anim, "falling tiles are animated (per-cell offsets)")
	_check(g.rounds == 1 and g.hold_pop > 0.0, "round 1 + tray refill pop")
	g._update_juice(1.0)
	var settled := true
	for i in Logic.NUMCELLS:
		if g.offsets[i] != Vector2.ZERO:
			settled = false
	_check(settled, "offsets decay back to the grid")

	# input: same keymap as Direct, same effect on the rules
	_key(g, KEY_LEFT); d.code("<")
	_check(g.game.cursor_x == d.cursor_x and g.sfx.last_played == "move", "Left moves cursor (+ move sfx)")
	g.game.cursor_x = 0; g.game.cursor_y = 7; d.cursor_x = 0; d.cursor_y = 7
	_key(g, KEY_Z); d.code("(")
	_check(_same(g, d), "Z rotates exactly like Direct '('")
	_check(g.sfx.last_played == "rotate" and g.rot_flash.life > 0.0, "rotate sfx + arrow flash")
	var moved := false
	for i in [63, 64, 72, 73]:
		if g.game.matrix[i] != 0 and g.offsets[i] != Vector2.ZERO:
			moved = true
	_check(moved, "rotated tiles slide from their old cells")
	_key(g, KEY_X); d.code(")")
	_key(g, KEY_O); d.code("(")
	_key(g, KEY_U); d.code(")")
	_key(g, KEY_J); d.code(")")
	_key(g, KEY_K); d.code("(")
	_check(_same(g, d), "x/o/u/j/k rotations match Direct")
	g.game.cursor_x = 0; g.game.cursor_y = 0; d.cursor_x = 0; d.cursor_y = 0
	_key(g, KEY_UP)
	_check(g.game.cursor_y == 0 and g.cursor_nudge != Vector2.ZERO, "edge bump nudges the cursor")

	# pause with P (game rule) hides the board; P resumes
	_key(g, KEY_P); d.code("p")
	g.tick_once(); d.tick()
	_check(g.game.next == Logic.PAUSED and _same(g, d), "P pauses the round (state PAUSED like Direct)")
	_check(g.sfx.last_played == "pause", "pause sfx")
	var c0: int = g.game.clock
	for i in 5:
		g.tick_once(); d.tick()
	_check(g.game.clock == c0, "clock frozen while P-paused")
	_key(g, KEY_P, true)
	_check(g.game.paused, "held P (echo) doesn't toggle")
	_key(g, KEY_P); d.code("p")
	g.tick_once(); d.tick()
	_check(g.game.next == Logic.PLAYING and _same(g, d), "P resumes")

	# clears: a lit group of 5 scores 10*2^(5-4) = 20 with burst/popup/shake
	g.game.matrix.fill(0); d.matrix.fill(0)
	for x in 5:
		g.game.matrix[Logic.GW * 8 + x] = 3
		d.matrix[Logic.GW * 8 + x] = 3
	g.game.cursor_x = 6; g.game.cursor_y = 0; d.cursor_x = 6; d.cursor_y = 0
	g.game.next = Logic.TIMEUP; d.next = Logic.TIMEUP
	var s0: int = g.game.score
	g.tick_once(); d.tick()
	_check(_same(g, d) and g.game.score == s0 + 20, "TIMEUP clear scores +20 like Direct")
	_check(g.popups.size() >= 1 and g.popups[0].text == "+20", "score popup '+20'")
	_check(g.particles.size() >= 30 and g.flashes.size() == 5, "clear burst (%d particles)" % g.particles.size())
	_check(g.shake > 0.0 and g.sfx.last_played == "clear1", "screen shake + clear sfx")
	_check(g.tiles_cleared == 5 and g.biggest_group == 5, "HUD stats: 5 tiles, biggest 5")
	# two groups at once -> combo popup
	g.game.matrix.fill(0)
	for x in 4:
		g.game.matrix[Logic.GW * 8 + x] = 1
		g.game.matrix[Logic.GW * 6 + x] = 2
	g.game.next = Logic.TIMEUP
	var hold_before: PackedInt32Array = g.game.hold.duplicate()
	g.tick_once()
	var combo := false
	for p in g.popups:
		if String(p.text).begins_with("2 GROUPS"):
			combo = true
	_check(combo, "two groups -> combo popup")
	_check(g.game.matrix.slice(0, Logic.GW) == hold_before, "the tray row was released into the top row")
	g._update_juice(2.0)
	_check(g.particles.is_empty() and g.popups.is_empty() and g.shake == 0.0, "juice settles")

	# danger marker: a full column (rows 1..8) flags that tray slot
	g.game.matrix.fill(0)
	for y in range(1, Logic.GH):
		g.game.matrix[y * Logic.GW + 4] = (y % 8) + 1
	_check(g.danger_columns() == [4], "danger column detected")

	# Enhanced-only toggles don't touch the rules
	var mtx: PackedInt32Array = g.game.matrix.duplicate()
	_key(g, KEY_M)
	_key(g, KEY_G)
	_check(g.sfx.muted and not g.show_glyphs and g.game.matrix == mtx, "M mutes, G hides glyphs, rules untouched")
	_key(g, KEY_M)
	_key(g, KEY_G)

	# pausing the tree (what PauseOverlay does) freezes everything
	g.restart()
	g.set_process(true)
	for i in 3:
		await process_frame
	var st: int = g.game.next
	var clk: int = g.game.clock
	var tm: float = g.time
	paused = true
	for i in 8:
		await process_frame
	_check(g.game.next == st and g.game.clock == clk and g.time == tm, "paused tree: rules + juice frozen")
	paused = false
	g.set_process(false)

	# full idle game with scripted input: identical outcome to Direct, then game over card
	d = Logic.new(777)
	g.game = Logic.new(777)
	g.restart()
	d.new_game()  # restart() calls new_game() again; mirror it so the RNG streams line up
	var script := ["(", ">", ">", ")", "v", "(", "<", "^", ")", ")"]
	var t := 0
	while d.next != Logic.THEEND and t < 100000:
		if d.next == Logic.PLAYING and t % 7 == 0:
			var c: String = script[(t / 7) % script.size()]
			g.press(c); d.code(c)
		g.tick_once(); d.tick(); t += 1
	_check(_same(g, d) and g.game.next == Logic.THEEND, "scripted game ends identically to Direct (%d ticks, score %d)" % [t, d.score])
	_check(g.get_node("%Overlay").visible and g.get_node("%CardTitle").text == "GAME OVER", "game over card")
	_check(g.best == maxi(g.best, d.score) and g.rounds > 0, "best + rounds tracked (best %d, rounds %d)" % [g.best, g.rounds])
	_check(g.sfx.last_played in ["lose", "best"], "game over sting")
	_key(g, KEY_Z)
	_check(g.game.matrix == d.matrix, "no rotations after game over (like Direct)")

	# randomized parity: three more seeds with busy random input, every tick compared
	for sd in [3, 11, 2013]:
		var rng := RandomNumberGenerator.new()
		rng.seed = sd
		d = Logic.new(sd)
		g.game = Logic.new(sd)
		g.restart()
		d.new_game()
		var codes := ["^", "v", "<", ">", "(", ")", "(", ")"]
		var ok := true
		var ticks := 0
		while d.next != Logic.THEEND and ticks < 100000:
			if d.next == Logic.PLAYING and rng.randf() < 0.35:
				var c: String = codes[rng.randi_range(0, codes.size() - 1)]
				g.press(c); d.code(c)
			g.tick_once(); d.tick(); ticks += 1
			if not _same(g, d):
				ok = false
				break
		_check(ok and g.game.next == Logic.THEEND,
				"seed %d: random-input game identical to Direct every tick (%d ticks, score %d, cleared %d)" % [
				sd, ticks, d.score, g.tiles_cleared])
	_key(g, KEY_ENTER)
	_check(g.started and g.game.next == Logic.NEWGAME and g.game.score == 0 and not g.get_node("%Overlay").visible,
			"Enter restarts")

	g.queue_free()
	await create_timer(0.2).timeout
	quit(1 if _fail else 0)
