extends Node
## Autoload "ArcadeHistory": maps the platform Back button onto the arcade shell.
##
## Web (browser Back / Forward, SPA-style history):
##   GameRegistry.launch(entry)     -> history.pushState  pretty "/<slug>/" (+ ?e=enhanced)
##                                     with "#play/<id>/<edition>" so hash parsers still work
##   GameRegistry.return_to_arcade() -> history.replaceState back to the gallery root path
##                                     (never history.back(): no double pop, never leaves the site)
##   popstate to a non-play URL      -> return_to_arcade() (unpause + gallery scene + gallery scale)
##   popstate to play URL            -> launch that entry (Forward, or a hand-edited URL)
##   cold load with play URL         -> rewrite the entry to the gallery, then launch, so the
##                                     first Back lands on the gallery instead of leaving the site
##
## Pretty paths (no full navigation / no wasm reload): pushState changes pathname to
## /arcade/<slug>/ while the root-hosted engine keeps running. Gallery URL is always the
## captured base (e.g. /arcade/ or /index.html), never the stub path.
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
const GameSlugs := preload("res://arcade/game_slugs.gd")

var _web := false
var _syncing := false  ## true while we are applying a URL change (popstate / cold load)
var _current := {}     ## {"id", "edition"} of the running game, {} on the gallery
var _window: JavaScriptObject
var _history: JavaScriptObject
var _location: JavaScriptObject
var _popstate_cb: JavaScriptObject  ## kept on the node so the JS callback is never GC'd
var _gallery_path := "/"   ## pathname of the gallery root (no slug); set on web ready
var _gallery_search := ""  ## search string on the gallery (edition ?e= stripped)


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


## Public slug for a registry id (delegates to game_slugs.gd).
static func slug_for_id(id: String) -> String:
	return GameSlugs.id_to_slug(id)


## Registry id for a public slug (delegates to game_slugs.gd).
static func id_for_slug(slug: String) -> String:
	return GameSlugs.slug_to_id(slug)


## Relative play URL: "<dir>/<slug>/" + optional "?e=enhanced" + "#play/<id>/<edition>".
## gallery_path is the gallery pathname (e.g. "/arcade/", "/arcade/index.html", "/index.html").
static func play_url(id: String, edition: String, gallery_path: String = "/") -> String:
	var slug := GameSlugs.id_to_slug(id)
	var dir := _gallery_dir(gallery_path)
	var path := "%s%s/" % [dir, slug]
	var query := "?e=enhanced" if edition == "enhanced" else ""
	return path + query + play_hash(id, edition)


## Gallery root href (path + search, no hash) for replaceState on return.
static func gallery_url(gallery_path: String = "/", gallery_search: String = "") -> String:
	return gallery_path + gallery_search


## Parse a play target from hash and/or pathname + search.
## Prefers #play/<id>/<edition>; else /<slug>/ (+ ?e=enhanced -> enhanced, else direct).
static func parse_play_location(pathname: String, search: String, hash: String,
		gallery_path: String = "/") -> Dictionary:
	var from_hash := parse_play_hash(hash)
	if not from_hash.is_empty():
		return from_hash
	var slug := _slug_under_gallery(pathname, gallery_path)
	if slug.is_empty():
		return {}
	var id := GameSlugs.slug_to_id(slug)
	# Aliases may use dotted slugs (mineswpr.old); registry ids must be ASCII identifiers.
	if not id.is_valid_ascii_identifier():
		return {}
	var edition := "direct"
	if search.find("e=enhanced") != -1:
		edition = "enhanced"
	return {"id": id, "edition": edition}


## Directory prefix for play stubs under the gallery (always ends with "/").
static func _gallery_dir(gallery_path: String) -> String:
	var p := gallery_path
	if p.is_empty():
		return "/"
	# "/arcade/index.html" or "/index.html" -> parent dir; "/arcade/" stays "/arcade/".
	var file := p.get_file()
	if file.contains("."):
		p = p.get_base_dir()
	if not p.ends_with("/"):
		p += "/"
	return p if p != "" else "/"


## Last path segment if it sits under gallery_path as a single extra slug; else "".
static func _slug_under_gallery(pathname: String, gallery_path: String) -> String:
	var dir := _gallery_dir(gallery_path)
	var path := pathname
	if not path.ends_with("/"):
		# "/arcade/giraffe" or "/arcade/giraffe/index.html"
		var file := path.get_file()
		if file.contains("."):
			path = path.get_base_dir()
		path += "/"
	if not path.begins_with(dir):
		return ""
	var rest := path.substr(dir.length()).trim_suffix("/")
	if rest.is_empty() or "/" in rest:
		return ""
	return rest


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
	_capture_gallery_base()
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
	var want := play_url(entry.id, entry.edition, _gallery_path)
	var cur := _href_path_query_hash()
	if cur == want:
		return
	# Push when leaving the gallery; replace when hopping game -> game (Forward / typed URL).
	if _is_play_href(cur):
		_history.replaceState("arcade-play", "", want)
	else:
		_history.pushState("arcade-play", "", want)


func _on_returned() -> void:
	_current = {}
	if not _web or _syncing:
		return
	if _is_play_href(_href_path_query_hash()):
		_to_gallery_url()


# --- URL -> arcade ----------------------------------------------------------------

func _on_popstate(_args: Array) -> void:
	# JS event context: apply on the next idle frame, inside the normal main loop.
	_sync_from_url.call_deferred()


func _sync_from_url() -> void:
	if _syncing:
		return
	_syncing = true
	var target := _parse_location()
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
	var target := _parse_location()
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


func _parse_location() -> Dictionary:
	return parse_play_location(
		str(_location.pathname),
		str(_location.search),
		_hash(),
		_gallery_path,
	)


func _href_path_query_hash() -> String:
	return str(_location.pathname) + str(_location.search) + str(_location.hash)


func _is_play_href(href: String) -> bool:
	# Hash form or pretty path under the gallery.
	var hash_i := href.find("#")
	var hash_part := href.substr(hash_i) if hash_i != -1 else ""
	var before := href.substr(0, hash_i) if hash_i != -1 else href
	var q_i := before.find("?")
	var path := before.substr(0, q_i) if q_i != -1 else before
	var search := before.substr(q_i) if q_i != -1 else ""
	return not parse_play_location(path, search, hash_part, _gallery_path).is_empty()


func _to_gallery_url() -> void:
	_history.replaceState(null, "", gallery_url(_gallery_path, _gallery_search))


func _capture_gallery_base() -> void:
	var path := str(_location.pathname)
	var search := str(_location.search)
	var hash_target := parse_play_hash(str(_location.hash))
	var seg := _last_path_segment(path)
	var strip := false
	if not seg.is_empty() and seg != "index.html":
		if GameSlugs.ALIASES.has(seg):
			strip = true
		elif not hash_target.is_empty() and GameSlugs.id_to_slug(hash_target.id) == seg:
			strip = true
		else:
			var rid := GameSlugs.slug_to_id(seg)
			if rid.is_valid_ascii_identifier():
				var e0 = GameRegistry.get_entry(rid, "direct")
				var e1 = GameRegistry.get_entry(rid, "enhanced")
				if (e0 != null and e0.is_playable()) or (e1 != null and e1.is_playable()):
					strip = true
	if strip:
		path = _parent_path(path)
	# Normalize directory gallery paths to a trailing slash; keep *.html as-is.
	if not path.get_file().contains(".") and not path.ends_with("/"):
		path += "/"
	if path.is_empty():
		path = "/"
	_gallery_path = path
	_gallery_search = _strip_edition_query(search)


func _strip_edition_query(search: String) -> String:
	if search.is_empty() or search == "?":
		return ""
	var q := search.trim_prefix("?")
	var kept: PackedStringArray = []
	for part in q.split("&"):
		if part.is_empty() or part.begins_with("e="):
			continue
		kept.append(part)
	return ("?" + "&".join(kept)) if kept.size() > 0 else ""


static func _last_path_segment(pathname: String) -> String:
	var path := pathname.trim_suffix("/")
	if path.is_empty():
		return ""
	var file := path.get_file()
	if GameSlugs.ALIASES.has(file):
		return file  # dotted alias slugs like mineswpr.old
	if file.contains("."):
		return ""  # index.html / other files, not a game slug
	return file


static func _parent_path(pathname: String) -> String:
	var path := pathname.trim_suffix("/")
	var parent := path.get_base_dir()
	if parent.is_empty():
		return "/"
	return parent if parent.ends_with("/") else parent + "/"
