extends Node
## Autoload "GameRegistry": the list of games the arcade knows about.
##
## Each title may have up to two editions:
##   "direct"   - a faithful port of the original game
##   "enhanced" - a modernized / reimagined version
## A GameEntry describes one (title, edition) pair.

const ARCADE_SCENE := "res://arcade/main.tscn"

const EDITIONS := ["direct", "enhanced"]


class GameEntry:
	var id: String          ## folder name under res://games/
	var title: String       ## display name
	var edition: String     ## "direct" or "enhanced"
	var scene_path: String  ## res:// path to the edition's main scene
	var status: String      ## "playable", "wip", or "planned"
	var notes: String       ## short provenance / porting note

	func _init(p_id: String, p_title: String, p_edition: String,
			p_scene_path: String, p_status: String, p_notes: String = "") -> void:
		id = p_id
		title = p_title
		edition = p_edition
		scene_path = p_scene_path
		status = p_status
		notes = p_notes

	func is_playable() -> bool:
		return status != "planned" and ResourceLoader.exists(scene_path)


## [id, title, status, notes] for every title. Both editions are registered.
const TITLES := [
	["_template", "Template Demo", "playable", "Reference stub for new ports."],
	["tetraminex", "Tetraminex", "planned", ""],
	["spiders_v_aliens", "Spiders vs Aliens", "planned", ""],
	["tentraminos", "Tentraminos", "planned", ""],
	["ld48", "LD48", "planned", "Ludum Dare 48 entry."],
	["ok_defender", "OK Defender", "planned", ""],
	["shep", "Shep", "planned", ""],
	["gamemaker_stuff", "GameMaker Stuff", "planned", ""],
	["flappy_clone", "Flappy Clone", "planned", "Port from tangentstorm/unitylabs."],
	["fnarbmlyx", "Fnarbmlyx", "planned", ""],
	["gamesketchlib", "GameSketchLib", "planned", ""],
	["godotlab", "GodotLab", "planned", ""],
	["cupid", "Cupid", "planned", ""],
	["mineswpr", "Mineswpr", "planned", "Retro Forth via b4-gd tooling."],
	["ofcp", "OFCP", "planned", "Private build — not in public export."],
]

var entries: Array[GameEntry] = []


func _ready() -> void:
	_register_all()


func _register_all() -> void:
	entries.clear()
	for t in TITLES:
		for edition in EDITIONS:
			var path := "res://games/%s/%s/game.tscn" % [t[0], edition]
			register(GameEntry.new(t[0], t[1], edition, path, t[2], t[3]))


func register(entry: GameEntry) -> void:
	entries.append(entry)


## Unique title ids in registration order.
func title_ids() -> Array[String]:
	var ids: Array[String] = []
	for e in entries:
		if not ids.has(e.id):
			ids.append(e.id)
	return ids


func get_entry(id: String, edition: String) -> GameEntry:
	for e in entries:
		if e.id == id and e.edition == edition:
			return e
	return null


func launch(entry: GameEntry) -> void:
	if entry == null or not entry.is_playable():
		push_warning("GameRegistry: cannot launch %s" % [entry.id if entry else "<null>"])
		return
	get_tree().change_scene_to_file(entry.scene_path)


func return_to_arcade() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(ARCADE_SCENE)


func in_arcade() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == ARCADE_SCENE
