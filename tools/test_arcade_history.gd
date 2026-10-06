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
