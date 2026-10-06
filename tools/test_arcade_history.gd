extends SceneTree
## Headless check for the Back-button shell (ArcadeHistory + GameRegistry + PauseOverlay).
## Off the web, history must be a no-op while launch / return / Android Back still work.
## Run: godot --headless --path . --script res://tools/test_arcade_history.gd

## Loaded at runtime (not preload): the script names the GameRegistry autoload, which only
## exists once the tree is up.
var History: GDScript

var _fail := 0
var _step := 0
var _f := 0
var _reg: Node
var _hist: Node
var _pause: CanvasLayer
var _seen := []


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("ok: ", what)
	else:
		print("SMOKE FAIL: arcade_history: ", what)
		_fail += 1


func _check_hashes() -> void:
	History = load("res://arcade/arcade_history.gd")
	_ok(History.play_hash("tetraminex", "direct") == "#play/tetraminex/direct", "play_hash format")
	_ok(History.parse_play_hash("#play/tetraminex/direct") == {"id": "tetraminex", "edition": "direct"}, "parse round-trip")
	_ok(History.parse_play_hash("#play/_template/enhanced") == {"id": "_template", "edition": "enhanced"}, "parse _template/enhanced")
	for bad in ["", "#", "#play", "#play/", "#play/tetraminex", "#play/tetraminex/deluxe",
			"#play/a/b/c", "#play/../direct", "#other/tetraminex/direct", "play/tetraminex/direct"]:
		_ok(History.parse_play_hash(bad).is_empty(), "reject %s" % [bad if bad != "" else "<empty>"])
	# slug ↔ id (keep in sync with arcade/game_slugs.gd / gen_game_pages ALIASES)
	_ok(History.slug_for_id("mineswpr_b4") == "mineswpr", "slug mineswpr_b4 -> mineswpr")
	_ok(History.slug_for_id("mineswpr") == "mineswpr.old", "slug mineswpr -> mineswpr.old")
	_ok(History.slug_for_id("giraffe") == "giraffe", "slug giraffe == id")
	_ok(History.id_for_slug("mineswpr") == "mineswpr_b4", "id mineswpr -> mineswpr_b4")
	_ok(History.id_for_slug("mineswpr.old") == "mineswpr", "id mineswpr.old -> mineswpr")
	_ok(History.id_for_slug("giraffe") == "giraffe", "id giraffe == slug")
	# pretty play_url under /arcade/ and under /index.html (web_smoke)
	_ok(History.play_url("giraffe", "direct", "/arcade/")
			== "/arcade/giraffe/#play/giraffe/direct", "play_url giraffe direct")
	_ok(History.play_url("giraffe", "enhanced", "/arcade/")
			== "/arcade/giraffe/?e=enhanced#play/giraffe/enhanced", "play_url giraffe enhanced")
	_ok(History.play_url("mineswpr_b4", "direct", "/arcade/")
			== "/arcade/mineswpr/#play/mineswpr_b4/direct", "play_url mineswpr_b4 alias")
	_ok(History.play_url("mineswpr", "direct", "/arcade/")
			== "/arcade/mineswpr.old/#play/mineswpr/direct", "play_url mineswpr.old alias")
	_ok(History.play_url("tetraminex", "direct", "/index.html")
			== "/tetraminex/#play/tetraminex/direct", "play_url under index.html")
	_ok(History.gallery_url("/arcade/", "") == "/arcade/", "gallery_url root")
	_ok(History.gallery_url("/index.html", "?back=1") == "/index.html?back=1", "gallery_url smoke")
	# parse: hash wins; else pathname slug + ?e=
	_ok(History.parse_play_location("/arcade/giraffe/", "", "#play/giraffe/enhanced", "/arcade/")
			== {"id": "giraffe", "edition": "enhanced"}, "parse prefers hash over path")
	_ok(History.parse_play_location("/arcade/giraffe/", "", "", "/arcade/")
			== {"id": "giraffe", "edition": "direct"}, "parse path-only direct")
	_ok(History.parse_play_location("/arcade/giraffe/", "?e=enhanced", "", "/arcade/")
			== {"id": "giraffe", "edition": "enhanced"}, "parse path + e=enhanced")
	_ok(History.parse_play_location("/arcade/mineswpr/", "", "", "/arcade/")
			== {"id": "mineswpr_b4", "edition": "direct"}, "parse alias mineswpr path")
	_ok(History.parse_play_location("/arcade/mineswpr.old/", "?e=enhanced", "", "/arcade/")
			== {"id": "mineswpr", "edition": "enhanced"}, "parse mineswpr.old path")
	_ok(History.parse_play_location("/arcade/", "", "", "/arcade/").is_empty(), "gallery path not play")
	_ok(History.parse_play_location("/tetraminex/", "", "", "/index.html")
			== {"id": "tetraminex", "edition": "direct"}, "parse under index.html gallery")


func _process(_d: float) -> bool:
	_f += 1
	if _f > 600:
		_ok(false, "timed out at step %d" % _step)
		return _finish()
	if _f % 5 != 0:
		return false
	match _step:
		0:
			_reg = root.get_node_or_null("GameRegistry")
			_hist = root.get_node_or_null("ArcadeHistory")
			_pause = root.get_node_or_null("PauseOverlay")
			_ok(_reg != null and _hist != null and _pause != null, "autoloads present")
			if _reg == null or _hist == null or _pause == null or not _hist.has_method("is_active"):
				_ok(false, "ArcadeHistory script did not load")
				return _finish()
			_check_hashes()
			_ok(not _hist.is_active(), "history inactive off the web")
			_reg.launched.connect(func(e): _seen.append("launch:%s/%s" % [e.id, e.edition]))
			_reg.returned_to_arcade.connect(func(): _seen.append("return"))
			_reg.return_to_arcade()
		1:
			_ok(_reg.in_arcade(), "starts in arcade")
			_reg.launch(_reg.get_entry("_template", "direct"))
		2:
			_ok(not _reg.in_arcade(), "launch leaves arcade")
			_ok(_hist.current_game() == {"id": "_template", "edition": "direct"}, "history tracks running game")
			# Esc twice: pause panel, then back to arcade (desktop behaviour unchanged).
			_esc()
		3:
			_ok(paused and _pause.get_node("Panel").visible, "Esc pauses + shows panel")
			_esc()
		4:
			_ok(_reg.in_arcade() and not paused, "second Esc returns to arcade unpaused")
			_ok(not _pause.get_node("Panel").visible, "panel hidden after Esc return")
			_ok(_hist.current_game().is_empty(), "history cleared on return")
			_reg.launch(_reg.get_entry("_template", "direct"))
		5:
			# Pause, then a platform Back (Android go-back) returns in one step.
			_esc()
		6:
			_ok(paused, "paused before platform Back")
			_hist.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		7:
			_ok(_reg.in_arcade(), "platform Back returns to arcade")
			_ok(not paused, "platform Back unpauses")
			_ok(not _pause.get_node("Panel").visible, "platform Back hides pause panel")
			_ok(_seen == ["return", "launch:_template/direct", "return", "launch:_template/direct", "return"],
				"signal order %s" % [_seen])
			return _finish()
	_step += 1
	return false


func _esc() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)


func _finish() -> bool:
	quit(1 if _fail else 0)
	return true
