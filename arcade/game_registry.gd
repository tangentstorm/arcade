extends Node
## Autoload "GameRegistry": the list of games the arcade knows about.
##
## Each title may have up to two editions:
##   "direct"   - a faithful port of the original game
##   "enhanced" - a modernized / reimagined version
## A GameEntry describes one (title, edition) pair.
##
## scale_mode (per title, both editions):
##   "letterbox" — keep aspect, prefer integer scale, large centered stage
##   "expand"    — fill the window (Control/UI roots that already reflow)

## Emitted after a game scene change is requested (ArcadeHistory pushes browser history).
signal launched(entry)
## Emitted when control returns to the gallery (PauseOverlay hides, ArcadeHistory rewinds URL).
signal returned_to_arcade

const ARCADE_SCENE := "res://arcade/main.tscn"

const EDITIONS := ["direct", "enhanced"]

## Per-title presentation when launched from the gallery.
## letterbox: fixed-res / pixel / designed aspect → KEEP + integer stretch.
## expand: window-filling Control/UI → EXPAND + fractional stretch.
const SCALE_MODE := {
	"_template": "expand",
	"tetraminex": "letterbox",       # 640×480-ish grid playfield
	"spiders_v_aliens": "letterbox",
	"tentraminos": "letterbox",      # 9×9 SVG board
	"ld48": "expand",                # Godot scenes / rooms fill window
	"ok_defender": "letterbox",      # 320×200 iKe stage
	"shep": "letterbox",             # fixed 800×575 stage
	"gm_defense": "letterbox",
	"killem_all": "letterbox",
	"toroidal_zombie_herder": "letterbox",  # room-sized GM view
	"flappy_clone": "letterbox",     # orthographic pixel stage
	"sketchbots": "letterbox",       # 300×300 Processing sketch
	"invader_sketch": "letterbox",   # fixed sketch stage
	"overlap_demo": "letterbox",     # 300×300 Processing sketches (GameSketchLib w02 demos)
	"overlap_demo_live": "letterbox",
	"bullet_demo": "letterbox",
	"bullet_demo_live": "letterbox",
	"gamesketchlib_demo": "letterbox",
	"keyboard_test_workaround": "letterbox",
	"keyboard_test_buggy": "letterbox",
	"keyboard_test_hashmap": "letterbox",
	"fnarb_overlap": "letterbox",    # fnarbmlyx demos: 1920×1080 SubViewport stage
	"fnarb_ast": "letterbox",
	"fnarb_binary_tree": "letterbox",
	"fnarb_binary_adder": "letterbox",
	"fnarb_binary_space": "letterbox",
	"godotlab_collatz": "expand",    # Control UI / bits layout
	"godotlab_game00": "letterbox",  # small sprite stage
	"godotlab_game01": "letterbox",
	"godotlab_tilemap": "letterbox",
	"cupid": "letterbox",            # 656×350 Flash stage
	"mineswpr": "letterbox",         # 80×25 terminal grid
	"brickslayer": "letterbox",      # 400×300 console @2x
	"ofcp": "expand",                # live client UI reflows
}


class GameEntry:
	var id: String          ## folder name under res://games/
	var title: String       ## display name
	var edition: String     ## "direct" or "enhanced"
	var scene_path: String  ## res:// path to the edition's main scene
	var status: String      ## "playable", "wip", or "planned"
	var notes: String       ## short provenance / porting note
	var scale_mode: String  ## "letterbox" or "expand"

	func _init(p_id: String, p_title: String, p_edition: String,
			p_scene_path: String, p_status: String, p_notes: String = "",
			p_scale_mode: String = "letterbox") -> void:
		id = p_id
		title = p_title
		edition = p_edition
		scene_path = p_scene_path
		status = p_status
		notes = p_notes
		scale_mode = p_scale_mode

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
	["sketchbots", "SketchBots", {"direct": "playable", "enhanced": "planned"},
		"From GameSketchLib course w01 (Processing, ~2011)."],
	["invader_sketch", "Invader Sketch", {"direct": "playable", "enhanced": "planned"},
		"From GameSketchLib course w02 (Processing, 2011)."],
	["overlap_demo", "Overlap Demo", {"direct": "playable", "enhanced": "planned"},
		"GameSketchLib course w02 tech demo (Processing, ~2011): drag squares, overlaps turn gray. Not a full game."],
	["overlap_demo_live", "Overlap Demo (Live)", {"direct": "playable", "enhanced": "planned"},
		"GameSketchLib course w02 live-coded OverlapDemo (Processing, ~2011). Tech demo, not a full game."],
	["bullet_demo", "Bullet Demo", {"direct": "playable", "enhanced": "planned"},
		"GameSketchLib course w02 tech demo (Processing, ~2011): click to shoot 3 bullets at 9 squares. Not a full game."],
	["bullet_demo_live", "Bullet Demo (Live)", {"direct": "playable", "enhanced": "planned"},
		"GameSketchLib course w02 live-coded BulletDemo on the mini game lib (Processing, ~2011). Tech demo."],
	["gamesketchlib_demo", "GameSketchLib Demo", {"direct": "playable", "enhanced": "planned"},
		"GameSketchLib course w02 tech demo (Processing, ~2011): BulletDemo on a flixel-style mini lib. Not a full game."],
	["keyboard_test_workaround", "Keyboard Test (Workaround)", {"direct": "playable", "enhanced": "planned"},
		"GameSketchLib course w02 keyboard test (Processing, ~2011): WASD + arrow pads, XOR toggles."],
	["keyboard_test_buggy", "Keyboard Test (Buggy)", {"direct": "playable", "enhanced": "planned"},
		"GameSketchLib course w02 keyboard test (Processing, ~2011): processing-js CODED bug, arrows dead."],
	["keyboard_test_hashmap", "Keyboard Test (HashMap)", {"direct": "playable", "enhanced": "planned"},
		"GameSketchLib course w02 keyboard test (Processing, ~2011): HashMap key state, Space recolours."],
	["godotlab_collatz", "Collatz (GodotLab)", {"direct": "playable", "enhanced": "planned"},
		"godotlab/collatz (Godot 3, 2020) bit register → Godot 4 Collatz stepper."],
	["godotlab_game00", "GodotLab Game 00", {"direct": "playable", "enhanced": "planned"},
		"godotlab/game00 (Godot 3) arrow-key drift sprite → Godot 4."],
	["godotlab_game01", "GodotLab Game 01", {"direct": "playable", "enhanced": "planned"},
		"godotlab/game01 (Godot 3) top-down hero + crosshair → Godot 4."],
	["godotlab_tilemap", "GodotLab Tilemap", {"direct": "playable", "enhanced": "planned"},
		"godotlab/tilemap (Godot 3) Kenney tilemap test → Godot 4 TileMapLayer."],
	["fnarb_overlap", "Fnarbmlyx Overlap Demo", {"direct": "playable", "enhanced": "planned"},
		"fnarbmlyx demos/overlap_demo (Godot 4.1, 2023): OverlapDemo redone in Godot. Sketch, not a game."],
	["fnarb_ast", "Fnarbmlyx Boolean Syntax Tree", {"direct": "playable", "enhanced": "planned"},
		"fnarbmlyx demos/boolean_syntax_tree (Godot 4.1, 2023): seeded random boolean AST. Visual sketch."],
	["fnarb_binary_tree", "Fnarbmlyx Binary Tree", {"direct": "playable", "enhanced": "planned"},
		"fnarbmlyx demos/binary_tree (Godot 4.1, 2023): depth-5 binary tree drawing. Visual sketch."],
	["fnarb_binary_adder", "Fnarbmlyx Binary Adder", {"direct": "playable", "enhanced": "planned"},
		"fnarbmlyx demos/binary_adder (Godot 4.1, 2023): animated 4-bit addition. Visual sketch."],
	["fnarb_binary_space", "Fnarbmlyx Binary Space", {"direct": "playable", "enhanced": "planned"},
		"fnarbmlyx demos/binary_space (Godot 4.1, 2023): 5-input truth-table space. Visual sketch."],
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
	_apply_arcade_scale()


func _register_all() -> void:
	entries.clear()
	for t in TITLES:
		var scale_mode: String = SCALE_MODE.get(t[0], "letterbox")
		for edition in EDITIONS:
			var path := "res://games/%s/%s/game.tscn" % [t[0], edition]
			var status: String = t[2] if t[2] is String else t[2].get(edition, "planned")
			register(GameEntry.new(t[0], t[1], edition, path, status, t[3], scale_mode))


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
	get_tree().paused = false
	_apply_game_scale(entry)
	get_tree().change_scene_to_file(entry.scene_path)
	launched.emit(entry)


func return_to_arcade() -> void:
	get_tree().paused = false
	_apply_arcade_scale()
	get_tree().change_scene_to_file(ARCADE_SCENE)
	returned_to_arcade.emit()


func in_arcade() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == ARCADE_SCENE


## Gallery hub: fill the window; cards reflow themselves.
func _apply_arcade_scale() -> void:
	var win := get_window()
	if win == null:
		return
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL


## In-game: letterbox → large centered stage, integer scale when crisp;
## expand → UI roots that already fill / reflow with the window.
func _apply_game_scale(entry: GameEntry) -> void:
	var win := get_window()
	if win == null:
		return
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if entry.scale_mode == "expand":
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	else:
		# KEEP letterboxes; INTEGER prefers crisp pixels and still maximizes
		# the largest integer fit (bars around a large centered stage).
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
