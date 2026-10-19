extends SceneTree
## Pause-menu "Switch to Original/Enhanced": restarts the running game in its other edition,
## only shown when both editions are playable; Esc Esc still returns to the gallery.
## Run: godot --headless --path . --script res://tools/test_edition_toggle.gd

var _fail := 0
var _step := 0
var _f := 0
var _reg: Node
var _hist: Node
var _pause: CanvasLayer
var _btn: Button


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("ok: ", what)
	else:
		print("SMOKE FAIL: edition_toggle: ", what)
		_fail += 1


func _scene() -> String:
	return current_scene.scene_file_path if current_scene else ""


func _process(_d: float) -> bool:
	_f += 1
	if _f > 600:
		_ok(false, "timed out at step %d" % _step)
		return _finish()
	if _f % 5 != 0:
		return false
	match _step:
		0:
			_reg = root.get_node("GameRegistry")
			_hist = root.get_node("ArcadeHistory")
			_pause = root.get_node("PauseOverlay")
			_btn = _pause.get_node("%EditionButton")
			_reg.launch(_reg.get_entry("_template", "direct"))
		1:
			_esc()
		2:
			_ok(paused and _btn.is_visible_in_tree(), "button shown for a two-edition game")
			_ok(_btn.text == "Switch to Enhanced", "direct offers Enhanced (%s)" % _btn.text)
			_btn.pressed.emit()
		3:
			_ok(_scene() == "res://games/_template/enhanced/game.tscn", "switched to enhanced (%s)" % _scene())
			_ok(not paused and not _pause.get_node("Panel").visible, "switch unpauses + hides panel")
			_ok(_hist.current_game() == {"id": "_template", "edition": "enhanced"}, "history tracks enhanced")
			_esc()
		4:
			_ok(_btn.text == "Switch to Original", "enhanced offers Original (%s)" % _btn.text)
			_btn.pressed.emit()
		5:
			_ok(_scene() == "res://games/_template/direct/game.tscn", "switched back to direct")
			_esc()
		6:
			_esc()
		7:
			_ok(_reg.in_arcade() and not paused, "Esc Esc still returns to the gallery")
			_reg.launch(_reg.get_entry("gravitube", "direct"))  # enhanced is planned
		8:
			_esc()
		9:
			_ok(paused and not _btn.visible, "button hidden when the other edition is not playable")
			_esc()
		10:
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
