extends SceneTree
## Headless checks for OFCP Enhanced (presentation over Direct thin client).
## Prefer offline mock — does not require the live OFCP server.
## Run: godot --headless --path . --script res://tools/test_ofcp_enhanced.gd

const SCENE := "res://games/ofcp/enhanced/game.tscn"
const DIRECT := "res://games/ofcp/direct/game.tscn"
const OfcpTable := preload("res://games/ofcp/direct/ofcp_table.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ofcp_enhanced ", msg)
	else:
		print("SMOKE FAIL: ofcp_enhanced ", msg)
		_fail += 1


func _key(code: Key, pressed := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func c(s: String) -> Dictionary:
	return {"rank": s[0], "suit": s[1]}


func cards(list: Array) -> Array:
	return list.map(func(s): return c(s))


func state(phase: String, hand: Array, brd := {}, cur := 0, fl := false, scores := [0, 0]) -> Dictionary:
	var b := {"top": [], "middle": [], "bottom": []}
	for k in brd:
		b[k] = cards(brd[k])
	return {
		"type": "game_state",
		"phase": phase,
		"currentPlayerIndex": cur,
		"round": 0,
		"mode": "normal",
		"profile": "normal",
		"you": {"index": 0, "board": b, "hand": cards(hand), "fantasyland": fl},
		"opponents": [{"index": 1, "board": {"top": [], "middle": [], "bottom": []}, "handSize": 5}],
		"scores": scores,
	}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_scene()
	print("ofcp_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _no_rules_copy() -> void:
	var src := FileAccess.get_file_as_string("res://games/ofcp/enhanced/game.gd")
	_check(src.contains("preload(\"res://games/ofcp/direct/game.tscn\")") \
			or src.contains("preload('res://games/ofcp/direct/game.tscn')"),
		"preloads Direct game.tscn")
	_check(not src.contains("func evaluate5") and not src.contains("func evaluate3"),
		"no hand_eval rules copy")
	_check(not src.contains("func createDeck") and not src.contains("func shuffle"),
		"no deck rules copy")
	_check(not src.contains("func score_hu") and not src.contains("func scoreHand"),
		"no scoring engine copy")
	_check(not src.contains("games/ofcp/shared/"), "does not preload shared/ rules")
	_check(not src.contains("PokerStars") and not src.contains("Full Tilt")
			and not src.contains("ClubWPT"),
		"no poker-site brand names (cash/normal, windfall, progressive only)")
	_check(src.contains("cash") or src.contains("Cash / normal"), "uses cash/normal label")
	_check(src.contains("windfall") or src.contains("Windfall"), "uses windfall label")
	_check(src.contains("progressive") or src.contains("Progressive"), "uses progressive label")
	_check(DirAccess.open("res://games/ofcp/enhanced/") != null, "enhanced/ exists")
	var files: PackedStringArray = DirAccess.get_files_at("res://games/ofcp/enhanced/")
	for f in files:
		if f.ends_with(".gd") and f != "game.gd":
			_check(false, "unexpected extra script in enhanced/: " + f)


func _test_scene() -> void:
	_no_rules_copy()
	_check(load(SCENE) is PackedScene, "scene loads")
	_check(load(DIRECT) is PackedScene, "Direct scene still loads")

	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("ofcp", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "expand",
		"registry: enhanced playable, expand")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")
	_check(reg.get_entry("ofcp", "direct").is_playable(),
		"registry: direct still playable")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(inst.state == inst.TITLE and inst._cards["title"].visible, "boots on the title card")
	_check(inst.demo == null, "Direct demo not loaded until play")
	_check(inst.STAGE == Vector2(1280, 720), "1280×720 stage")
	_check(inst.FIELD == Vector2(1024, 576), "1024×576 field (0.8 of 1280×720)")

	# Back to Arcade FOCUS_NONE (title card + HUD).
	var backs: Array = []
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			backs.append(b)
			_check(b.focus_mode == Control.FOCUS_NONE, "Back to Arcade FOCUS_NONE (%s)" % b.get_path())
	_check(backs.size() >= 1, "Back to Arcade present")
	for b2 in inst._ui.find_children("*", "Button", true, false):
		if b2.text == "Start":
			_check(b2.focus_mode == Control.FOCUS_NONE, "Start FOCUS_NONE")

	# Space → play: Direct instanced with Direct script.
	root.push_input(_key(KEY_SPACE))
	await _frames(10)
	_check(inst.state == inst.PLAY and inst.demo != null, "Space begins and loads Direct")
	_check(not inst._cards["title"].visible and inst._hud.visible, "title hidden, HUD shown")
	_check(inst._vp_box.visible, "table viewport visible")
	var d: Control = inst.demo
	_check(d.scene_file_path == DIRECT, "embedded scene is Direct game.tscn")
	_check(d.get_script() != null and str(d.get_script().resource_path).ends_with("direct/game.gd"),
		"demo uses Direct game.gd (shared)")

	# SubViewport stretch=false + scale (Overlap #78 lesson).
	_check(inst._viewport.size == Vector2i(1280, 720),
		"SubViewport stays 1280×720 (not stretched down to field)")
	_check(inst._vp_box.stretch == false, "TableView.stretch is false")
	_check(inst._vp_box.size == inst.VP_SIZE, "TableView size is VP_SIZE")
	var sc: Vector2 = inst._vp_box.scale
	_check(is_equal_approx(sc.x, 0.8) and is_equal_approx(sc.y, 0.8),
		"TableView scaled to FIELD/VP_SIZE (0.8)")
	_check(inst.FIELD_POS.x + inst.FIELD.x <= inst.STAGE.x \
			and inst.FIELD_POS.y + inst.FIELD.y <= inst.STAGE.y,
		"field fits inside stage")
	_check(inst._fx != null and is_instance_valid(inst._fx), "Fx juice layer exists")
	var fx_i: int = inst._fx.get_index()
	var host_i: int = inst.get_node("StageHost").get_index()
	_check(fx_i > host_i, "Fx draws above StageHost/Direct SubViewport")

	# Offline mock: feed game_state (no live server).
	var mock := state("INITIAL_PLACE", ["As", "Kd", "Tc", "2h", "9s"], {}, 0, false, [3, -3])
	inst.apply_mock(mock)
	await _frames(4)
	_check(inst.mock_feeds >= 1, "apply_mock fed a message")
	_check(d.table.is_my_turn() and d.table.need_place() == 5, "mock: my turn, need 5")
	_check(d.table.hand().size() == 5, "mock: 5 cards in hand")
	_check(d.table.my_score() == 3, "mock: score from state")
	_check(OfcpTable.suit_color(c("Ad")) == Color(0.12, 0.35, 0.85), "4-color diamonds blue")
	_check(OfcpTable.suit_color(c("Ac")) == Color(0.08, 0.55, 0.28), "4-color clubs green")

	# Place via Direct table → juice.
	var before_places: int = inst.places
	_check(d.table.place(c("As"), "top"), "Direct place As → top")
	_check(d.table.place(c("Kd"), "top"), "Direct place Kd → top")
	d._refresh()
	await _frames(4)
	_check(inst.places > before_places, "juice counted card places (%d)" % inst.places)
	_check(inst._particles.size() > 0 or inst._floaters.size() > 0 or inst._banner_t > 0.0,
		"juice particles/floaters after place")

	# Parity vs bare Direct twin with the same mock state.
	var twin: Control = (load(DIRECT) as PackedScene).instantiate()
	root.add_child(twin)
	await _frames(4)
	twin._on_message(mock)
	twin._hide_overlay()
	twin.game_started = true
	twin.table.place(c("As"), "top")
	twin.table.place(c("Kd"), "top")
	_check(twin.get_script() != null and str(twin.get_script().resource_path).ends_with("direct/game.gd"),
		"twin uses Direct game.gd")
	_check(d.table.pending.size() == twin.table.pending.size(),
		"parity: pending size matches twin (%d)" % d.table.pending.size())
	_check(d.table.my_score() == twin.table.my_score(), "parity: scores match twin")
	_check(d.table.phase() == twin.table.phase(), "parity: phase matches twin")
	_check(d.table.need_place() == twin.table.need_place(), "parity: need_place matches twin")
	# Finish placing and compare submit message shape.
	_check(d.table.place(c("Tc"), "top") and d.table.place(c("2h"), "bottom") \
			and d.table.place(c("9s"), "middle"), "Direct places remaining 3")
	twin.table.place(c("Tc"), "top")
	twin.table.place(c("2h"), "bottom")
	twin.table.place(c("9s"), "middle")
	var msg_e: Dictionary = d.table.build_submit()
	var msg_t: Dictionary = twin.table.build_submit()
	_check(msg_e.type == msg_t.type and msg_e.type == "place_initial",
		"parity: place_initial submit type")
	_check(msg_e.placements.size() == msg_t.placements.size() and msg_e.placements.size() == 5,
		"parity: 5 placements")

	# Fantasyland juice via mock.
	var fl_hand := ["As", "Ah", "Ad", "Kc", "Kd", "Ks", "Qc", "Qd", "Qs", "Jc", "Jd", "Js", "Tc", "2d"]
	inst.apply_mock(state("INITIAL_PLACE", fl_hand, {}, 0, true, [0, 0]))
	await _frames(4)
	_check(d.table.is_fantasyland() and d.table.need_place() == 13, "mock Fantasyland need 13")
	_check(inst.fl_celebrations >= 1 or inst._banner.contains("FANTASY") or inst._banner_t > 0.0,
		"Fantasyland juice / banner")

	# Game-over score flash.
	var go := state("GAME_OVER", [], {"top": ["As", "Ks", "Qs"]}, 0, false, [6, -6])
	go["breakdowns"] = [{"netScore": 6, "rowWins": {"A": 3, "B": 0}, "scoop": "A",
		"playerA": {"fouled": false, "rows": [], "totalRoyalties": 0},
		"playerB": {"fouled": false, "rows": [], "totalRoyalties": 0}}]
	var before_flash: int = inst.score_flashes
	inst.apply_mock(go)
	await _frames(4)
	_check(d.table.is_game_over() and d.table.my_score() == 6, "mock game over score 6")
	_check(inst.score_flashes > before_flash or inst._flash > 0.0 or inst._banner_t > 0.0,
		"score / hand-over juice")

	twin.queue_free()
	await _frames(2)

	# Esc → PauseOverlay → arcade
	root.push_input(_key(KEY_ESCAPE))
	await _frames(3)
	_check(paused, "Esc opens PauseOverlay and pauses the tree")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(6)
	_check(reg.in_arcade() and not paused, "Esc again → Back to Arcade")
