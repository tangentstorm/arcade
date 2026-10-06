extends SceneTree
## Headless checks for LD48 Enhanced (presentation over Direct rooms/scripts).
## Run: godot --headless --path . --script res://tools/test_ld48_enhanced.gd

const SCENE := "res://games/ld48/enhanced/game.tscn"
const ROOM0 := "res://games/ld48/direct/game.tscn"
const OFFICE := "res://games/ld48/direct/ivan_office.tscn"
const ErnieScript := preload("res://games/ld48/direct/ernie.gd")
const Room0Script := preload("res://games/ld48/direct/room0.gd")
const TeleScript := preload("res://games/ld48/direct/teleporter.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ld48_enhanced ", msg)
	else:
		print("SMOKE FAIL: ld48_enhanced ", msg)
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _key(code: Key, pressed := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	await _test_scene()
	print("ld48_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	_check(load(ROOM0) is PackedScene and load(OFFICE) is PackedScene, "Direct rooms still load")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("ld48", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "expand",
		"registry: enhanced playable, expand (title scale_mode)")
	_check(reg.get_entry("ld48", "direct").is_playable(), "registry: direct still playable")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(inst.state == inst.TITLE and inst._cards["title"].visible, "boots on the title card")
	_check(inst._room == null, "Direct room not loaded until play")

	# Back to Arcade present, never steals focus
	var back: Button = null
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			back = b
			break
	_check(back != null and back.focus_mode == Control.FOCUS_NONE, "Back to Arcade present, FOCUS_NONE")

	# Space / begin -> load Direct room0 into the shell
	inst._set_state(inst.PLAY)
	await _frames(8)
	_check(inst.state == inst.PLAY and inst._room != null, "begin loads a room into the shell")
	_check(inst.room_kind == "room0", "starts in room0")
	_check(inst._room.scene_file_path == ROOM0, "embedded scene is Direct game.tscn")
	var room_node: Node = inst._room.get_node("room")
	_check(room_node.get_script() == Room0Script, "room0 uses Direct room0.gd (shared)")
	_check(inst._ernie != null and inst._ernie.get_script() == ErnieScript,
		"Ernie uses Direct ernie.gd (shared)")
	var tele = room_node.get_node("sprites/teleporter")
	_check(tele.get_script() == TeleScript, "teleporter uses Direct teleporter.gd (shared)")
	_check(not tele.teleport.is_connected(room_node._on_teleporter_teleport),
		"Direct change_scene warp is disconnected")
	_check(tele.teleport.is_connected(inst._on_warp_to_office), "Enhanced owns the warp")

	# Direct chrome hidden; Enhanced owns chat/help
	_check(not inst._room.get_node("camshaker/camera/sidebar").visible, "Direct sidebar hidden")
	_check(not inst._room.get_node("camshaker/camera/helptext").visible, "Direct helptext hidden")

	# Ernie still moves under Enhanced ownership
	await _physics(90)
	_check(inst._ernie.is_on_floor(), "Ernie lands on the tile floor under Enhanced")
	var x0: float = inst._ernie.position.x
	Input.parse_input_event(_key(KEY_D, true))
	Input.flush_buffered_events()
	await _physics(30)
	Input.parse_input_event(_key(KEY_D, false))
	Input.flush_buffered_events()
	_check(inst._ernie.position.x > x0 + 20, "D walks right under Enhanced (dx=%.1f)" % (inst._ernie.position.x - x0))

	# Dialog path: Enhanced chat receives speak; Direct chatroom is not fed
	inst._on_showchat(true)
	_check(inst._chat_panel.visible, "showchat opens Enhanced chat panel")
	var before: int = inst._chat_vbox.get_child_count()
	inst._on_speak("teddy", "Enhanced chat smoke test")
	await _frames(3)
	_check(inst._chat_vbox.get_child_count() == before + 1, "speak adds an Enhanced chat card")
	inst._on_helptext("Press E to Interact")
	_check(inst._help_label.text == "Press E to Interact", "helptext reaches Enhanced toast")

	# Juice path: landing-style burst
	var p0: int = inst._particles.size()
	inst._spawn_burst(inst.FIELD_POS + inst.FIELD * 0.5, Color.WHITE, 8)
	_check(inst._particles.size() > p0, "juice: particle burst")

	# Warp interception loads Direct office without leaving Enhanced
	inst._on_warp_to_office()
	await _frames(6)
	_check(inst.scene_file_path == SCENE, "shell stays after warp")
	_check(inst.room_kind == "office" and inst._room != null, "office room loaded")
	_check(inst._room.scene_file_path == OFFICE, "embedded scene is Direct ivan_office.tscn")
	_check(inst._ernie != null and inst._ernie.get_script() == ErnieScript, "office Ernie is Direct script")
	_check(inst._ernie.has_teleporter, "teleporter beam enabled in office")
	_check(inst._flash > 0.0, "warp flash juice")

	# Esc -> PauseOverlay (tree pause), Esc again -> arcade
	root.push_input(_key(KEY_ESCAPE))
	await _frames(8)
	_check(paused, "Esc opens PauseOverlay and pauses the tree")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(4)
	_check(reg.in_arcade() and not paused, "Esc again -> Back to Arcade")
