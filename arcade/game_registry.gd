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
## status is a String applied to both editions, or a Dictionary keyed by
## edition (missing editions default to "planned").
const TITLES := [
	["_template", "Template Demo", "playable", "Reference stub for new ports."],
	["tetraminex", "Tetraminex", {"direct": "playable", "enhanced": "planned"},
		"Episode 0 Training Day (2011), AS3/Flixel → GDScript grid rewrite."],
	["spiders_v_aliens", "Spiders vs Aliens", "planned", ""],
	["tentraminos", "Tentraminos", {"direct": "playable", "enhanced": "planned"},
		"Ludum Dare 27 (2013), TypeScript/d3 → GDScript."],
	["ld48", "LD48: Deeper and Deeper", {"direct": "playable", "enhanced": "planned"},
		"Ludum Dare 48 (2021), Godot 3 → Godot 4 scene migration."],
	["ok_defender", "oK Defender", {"direct": "playable", "enhanced": "planned"},
		"Ludum Dare 49 (2021) Defender clone, oK/iKe (K) → GDScript."],
	["shep", "Shep", {"direct": "playable", "enhanced": "planned"},
		"robocognito zero-g fuse puzzler (2010), Haxe/Flash 9 + physaxe → GDScript."],
	["gm_defense", "GM Defense", "planned", "From gamemaker-stuff/gm2-defense."],
	["killem_all", "Kill 'Em All", "planned", "From gamemaker-stuff/killem-all."],
	["toroidal_zombie_herder", "Toroidal Zombie Herder", {"direct": "playable", "enhanced": "planned"},
		"From gamemaker-stuff (GameMaker: Studio 1.x)."],
	["flappy_clone", "Flappy Clone", {"direct": "playable", "enhanced": "planned"}, "Unity 5 (2015) unitylabs/flappyclone → GDScript."],
	["fnarbmlyx", "Fnarbmlyx", "planned", ""],
	["sketchbots", "SketchBots", {"direct": "playable", "enhanced": "planned"},
		"From GameSketchLib course w01 (Processing, ~2011)."],
	["invader_sketch", "Invader Sketch", {"direct": "playable", "enhanced": "planned"},
		"From GameSketchLib course w02 (Processing, 2011)."],
	["godotlab_collatz", "Collatz (GodotLab)", "planned", "From godotlab/collatz."],
	["godotlab_game00", "GodotLab Game 00", "planned", "From godotlab/game00."],
	["godotlab_game01", "GodotLab Game 01", "planned", "From godotlab/game01."],
	["godotlab_tilemap", "GodotLab Tilemap", "planned", "From godotlab/tilemap."],
	["cupid", "Cupid", {"direct": "playable", "enhanced": "planned"},
		"Matchmaking Cupid (2010), AS3/Flixel v1 → GDScript."],
	["mineswpr", "Mineswpr", {"direct": "playable", "enhanced": "planned"},
		"Retro Forth 11 terminal Minesweeper (2013) → GDScript."],
	["brickslayer", "Brickslayer", {"direct": "playable", "enhanced": "planned"},
		"javascriptgamer.com Breakout + lesson trail (2007), JS → GDScript."],
	["ofcp", "OFCP", {"direct": "playable", "enhanced": "planned"},
		"Pineapple OFC vs AI; thin client over wss://ofcp.tangentcode.com/ws."],
]

var entries: Array[GameEntry] = []


func _ready() -> void:
	_register_all()


func _register_all() -> void:
	entries.clear()
	for t in TITLES:
		for edition in EDITIONS:
			var path := "res://games/%s/%s/game.tscn" % [t[0], edition]
			var status: String = t[2] if t[2] is String else t[2].get(edition, "planned")
			register(GameEntry.new(t[0], t[1], edition, path, status, t[3]))


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
