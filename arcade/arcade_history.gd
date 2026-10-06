extends Node
## Autoload "ArcadeHistory": maps the platform Back button onto the arcade shell.
##
## Web (browser Back / Forward, SPA-style history):
##   GameRegistry.launch(entry)     -> history.pushState  "#play/<id>/<edition>"
##   GameRegistry.return_to_arcade() -> history.replaceState back to the bare gallery URL
##                                     (never history.back(): no double pop, never leaves the site)
##   popstate to a non-play URL      -> return_to_arcade() (unpause + gallery scene + gallery scale)
##   popstate to "#play/<id>/<ed>"   -> launch that entry (Forward, or a hand-edited hash)
##   cold load with "#play/<id>/<ed>" -> rewrite the entry to the gallery, then launch, so the
##                                     first Back lands on the gallery instead of leaving the site
##
## Android: the system Back button arrives as NOTIFICATION_WM_GO_BACK_REQUEST (not ui_cancel).
## project.godot sets application/config/quit_on_go_back=false so Back in a game returns to the
## gallery; Back on the gallery quits the app.
##
## Desktop / editor: no history; Esc and the PauseOverlay behave exactly as before.
##
## Every game gets this for free because it hooks GameRegistry's launched / returned_to_arcade
## signals; individual games keep calling GameRegistry.return_to_arcade() as they always have.

const PLAY_PREFIX := "#play/"
const EDITIONS := ["direct", "enhanced"]  ## mirrors GameRegistry.EDITIONS (usable from static funcs)

var _web := false
var _syncing := false  ## true while we are applying a URL change (popstate / cold load)
var _current := {}     ## {"id", "edition"} of the running game, {} on the gallery
var _window: JavaScriptObject
var _history: JavaScriptObject
var _location: JavaScriptObject
var _popstate_cb: JavaScriptObject  ## kept on the node so the JS callback is never GC'd


## "#play/<id>/<edition>" for a game entry.
static func play_hash(id: String, edition: String) -> String:
	return "%s%s/%s" % [PLAY_PREFIX, id, edition]


## {"id", "edition"} for a "#play/<id>/<edition>" hash, or {} for anything else.
static func parse_play_hash(h: String) -> Dictionary:
	if not h.begins_with(PLAY_PREFIX):
		return {}
	var parts := h.substr(PLAY_PREFIX.length()).split("/")
	if parts.size() != 2:
		return {}
	var id := parts[0].uri_decode()
	var edition := parts[1].uri_decode()
	if not edition in EDITIONS or not id.is_valid_ascii_identifier():
		return {}
	return {"id": id, "edition": edition}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Back must work while the tree is paused
	GameRegistry.launched.connect(_on_launched)
	GameRegistry.returned_to_arcade.connect(_on_returned)
	_web = OS.has_feature("web") and ClassDB.class_exists("JavaScriptBridge")
	if not _web:
		return
	_window = JavaScriptBridge.get_interface("window")
	_history = JavaScriptBridge.get_interface("history")
	_location = JavaScriptBridge.get_interface("location")
	if _window == null or _history == null or _location == null:
		_web = false
		return
	_popstate_cb = JavaScriptBridge.create_callback(_on_popstate)
	_window.addEventListener("popstate", _popstate_cb)
	_cold_load.call_deferred()


func is_active() -> bool:
	return _web


func current_game() -> Dictionary:
	return _current.duplicate()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if GameRegistry.in_arcade():
		get_tree().quit()
	else:
		GameRegistry.return_to_arcade()


# --- GameRegistry hooks -------------------------------------------------------

func _on_launched(entry) -> void:
	_current = {"id": entry.id, "edition": entry.edition}
	if not _web or _syncing:
		return
	var want := play_hash(entry.id, entry.edition)
	var cur := _hash()
	if cur == want:
		return
	if parse_play_hash(cur).is_empty():
		_history.pushState("arcade-play", "", want)
	else:
		_history.replaceState("arcade-play", "", want)


func _on_returned() -> void:
	_current = {}
	if not _web or _syncing:
		return
	if not parse_play_hash(_hash()).is_empty():
		_to_gallery_url()


# --- URL -> arcade ----------------------------------------------------------------

func _on_popstate(_args: Array) -> void:
	# JS event context: apply on the next idle frame, inside the normal main loop.
	_sync_from_url.call_deferred()


func _sync_from_url() -> void:
	if _syncing:
		return
	_syncing = true
	var target := parse_play_hash(_hash())
	if target.is_empty():
		if not GameRegistry.in_arcade() or not _current.is_empty():
			GameRegistry.return_to_arcade()
	elif target != _current or GameRegistry.in_arcade():
		var entry = GameRegistry.get_entry(target.id, target.edition)
		if entry != null and entry.is_playable():
			GameRegistry.launch(entry)
		else:
			_to_gallery_url()
			if not GameRegistry.in_arcade():
				GameRegistry.return_to_arcade()
	_syncing = false


func _cold_load() -> void:
	# Let the gallery scene finish its own _ready (it awaits a frame) before swapping it out.
	await get_tree().process_frame
	await get_tree().process_frame
	var target := parse_play_hash(_hash())
	if target.is_empty():
		return
	var entry = GameRegistry.get_entry(target.id, target.edition)
	# Rewrite the landing entry to the gallery so Back from the deep-linked game returns to the
	# gallery; launch() then pushes the play entry on top of it.
	_to_gallery_url()
	if entry != null and entry.is_playable() and _current.is_empty():
		GameRegistry.launch(entry)


func _hash() -> String:
	return str(_location.hash) if _location != null else ""


func _to_gallery_url() -> void:
	_history.replaceState(null, "", str(_location.pathname) + str(_location.search))
