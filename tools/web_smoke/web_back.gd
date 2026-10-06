extends Node
## Browser Back check helper for the Web export. web_smoke.sh injects this as an autoload in
## `back` mode only; it is never part of the shipped game. With ?back=1 it prints a
## "WEBBACK {json}" line whenever the scene / pause / overlay / URL hash changes, and exposes
## window.webBackLaunch(id, edition) which calls GameRegistry.launch (what a card click does).

var _on := false
var _last := ""
var _launch_cb: JavaScriptObject


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		return
	_on = str(JavaScriptBridge.eval("location.search")).find("back=1") != -1
	if not _on:
		return
	_launch_cb = JavaScriptBridge.create_callback(_launch)
	JavaScriptBridge.get_interface("window").webBackLaunch = _launch_cb


func _launch(args: Array) -> void:
	var reg = get_node("/root/GameRegistry")
	reg.launch.call_deferred(reg.get_entry(str(args[0]), str(args[1])))


func _process(_d: float) -> void:
	if not _on:
		return
	var scene := get_tree().current_scene
	var state := {
		"scene": scene.scene_file_path if scene else "",
		"paused": get_tree().paused,
		"panel": get_node("/root/PauseOverlay/Panel").visible,
		"hash": str(JavaScriptBridge.eval("location.hash")),
		"path": str(JavaScriptBridge.eval("location.pathname")),
		"search": str(JavaScriptBridge.eval("location.search")),
	}
	var line := JSON.stringify(state)
	if line != _last:
		_last = line
		print("WEBBACK ", line)
