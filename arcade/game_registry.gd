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
	"silly_game": "expand",           # camera-followed open map
	"cupid": "letterbox",            # 656×350 Flash stage
	"mineswpr": "letterbox",         # 80×25 terminal grid; Enhanced 1280×720 stage
	"brickslayer": "letterbox",      # 400×300 console @2x
	"giraffe": "letterbox",          # 128×128 Pico-8 stage
	"ofcp": "expand",                # live client UI reflows
	"chesscoach": "letterbox",       # Direct 400×400; Enhanced 1280×720 around walnut board
	"canyon_run": "letterbox",       # 240×320 portrait stage @2× (480×640)
	"terratri": "expand",            # Control UI; board picks an integer cell size
	"doth": "letterbox",             # Direct 1120×368; Enhanced 1280×720 around 1120×320 field
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
	["tetraminex", "Tetraminex", {"direct": "playable", "enhanced": "playable"},
		"Episode 0 Training Day (2011), AS3/Flixel → GDScript grid rewrite."],
	["spiders_v_aliens", "Spiders vs Aliens", {"direct": "playable", "enhanced": "playable"},
		"Ludum Dare 21 \"Escape\" (2011), tangentstorm/spiders-v-aliens AS3/Flixel 2.55 → GDScript; Enhanced = lit widescreen makeover over the same rules."],
	["tentraminos", "Tentraminos", {"direct": "playable", "enhanced": "playable"},
		"Ludum Dare 27 (2013), TypeScript/d3 → GDScript; Enhanced = modern board/HUD + juice over the same rules."],
	["ld48", "LD48: Deeper and Deeper", {"direct": "playable", "enhanced": "playable"},
		"Ludum Dare 48 (2021), Godot 3 → Godot 4 scene migration; Enhanced = restyled chat/help + juice over the same Direct rooms."],
	["ok_defender", "oK Defender", {"direct": "playable", "enhanced": "playable"},
		"Ludum Dare 49 (2021) Defender clone, oK/iKe (K) → GDScript."],
	["shep", "Shep", {"direct": "playable", "enhanced": "playable"},
		"robocognito zero-g fuse puzzler (2010), Haxe/Flash 9 + physaxe → GDScript; Enhanced = clearer fuse/ship UI + juice over the same physics."],
	["gm_defense", "GM Defense", {"direct": "playable", "enhanced": "playable"},
		"gamemaker-stuff/gm2-defense (GameMaker Studio 2, 2017) Defender-clone toy: fly left/right past a squid. Not a full game; Enhanced = deep-space room, ship/squid glow + off-room locator over the same rules."],
	["killem_all", "Kill 'Em All", {"direct": "playable", "enhanced": "playable"},
		"gamemaker-stuff/killem-all.gmx (GameMaker: Studio 1.x) twin-stick prototype: thrust, aim, spray bullets. No enemies yet; Enhanced = neon arena, tracers, thrust flame, radar + flight HUD over the same Direct rules."],
	["toroidal_zombie_herder", "Toroidal Zombie Herder", {"direct": "playable", "enhanced": "playable"},
		"From gamemaker-stuff (GameMaker: Studio 1.x): herd zombies onto traps in a wrap-around maze. Enhanced = crypt-stone maze, lantern hero, edge portals + wrap ghosts, trap/caught juice, torus minimap HUD over the same Direct rules."],
	["flappy_clone", "Flappy Clone", {"direct": "playable", "enhanced": "playable"},
		"Unity 5 (2015) unitylabs/flappyclone → GDScript."],
	["sketchbots", "SketchBots", {"direct": "playable", "enhanced": "playable"},
		"GameSketchLib course w01 (Processing, ~2011) two-player hello-world movers; Enhanced = framed 300×300 @2× field, bot glow/squash/dust, meet + off-canvas juice, side HUD over the same Direct quirks."],
	["invader_sketch", "Invader Sketch", {"direct": "playable", "enhanced": "playable"},
		"From GameSketchLib course w02 (Processing, 2011). Enhanced = starfield stage, sprite glow, shoot/kill/shield juice + HUD over the same Direct rules."],
	["overlap_demo", "Overlap Demo", {"direct": "playable", "enhanced": "planned"},
		"GameSketchLib course w02 tech demo (Processing, ~2011): drag squares, overlaps turn gray. Not a full game."],
	["overlap_demo_live", "Overlap Demo (Live)", {"direct": "playable", "enhanced": "planned"},
		"GameSketchLib course w02 live-coded OverlapDemo (Processing, ~2011). Tech demo, not a full game."],
	["bullet_demo", "Bullet Demo", {"direct": "playable", "enhanced": "planned"},
		"GameSketchLib course w02 tech demo (Processing, ~2011): click to shoot 3 bullets at 9 squares. Not a full game."],
	["bullet_demo_live", "Bullet Demo (Live)", {"direct": "playable", "enhanced": "planned"},
		"GameSketchLib course w02 live-coded BulletDemo on the mini game lib (Processing, ~2011). Tech demo."],
	["gamesketchlib_demo", "GameSketchLib Demo", {"direct": "playable", "enhanced": "playable"},
		"GameSketchLib course w02 tech demo (Processing, ~2011): BulletDemo on a flixel-style mini lib. Not a full game. Enhanced = framed 300×300 @2× field, bullet glow/trails, hit/soak/miss juice, aim guide + side HUD over the same Direct rules."],
	["keyboard_test_workaround", "Keyboard Test (Workaround)", {"direct": "playable", "enhanced": "planned"},
		"GameSketchLib course w02 keyboard test (Processing, ~2011): WASD + arrow pads, XOR toggles."],
	["keyboard_test_buggy", "Keyboard Test (Buggy)", {"direct": "playable", "enhanced": "planned"},
		"GameSketchLib course w02 keyboard test (Processing, ~2011): processing-js CODED bug, arrows dead."],
	["keyboard_test_hashmap", "Keyboard Test (HashMap)", {"direct": "playable", "enhanced": "planned"},
		"GameSketchLib course w02 keyboard test (Processing, ~2011): HashMap key state, Space recolours."],
	["godotlab_collatz", "Collatz (GodotLab)", {"direct": "playable", "enhanced": "playable"},
		"godotlab/collatz (Godot 3, 2020) bit register → Godot 4 Collatz stepper; Enhanced = letterbox chrome, bit flip/shift/carry-ripple juice, step breakdown + trajectory chart over the same Direct scene."],
	["godotlab_game00", "GodotLab Game 00", {"direct": "playable", "enhanced": "playable"},
		"godotlab/game00 (Godot 3) arrow-key drift sprite → Godot 4; Enhanced = letterbox chrome + trail/glow/wrap juice over the same Direct icon.gd scene."],
	["godotlab_game01", "GodotLab Game 01", {"direct": "playable", "enhanced": "playable"},
		"godotlab/game01 (Godot 3) top-down hero + crosshair → Godot 4; Enhanced = letterbox chrome, aim laser, dust trail, fireball glow + off-field locator over the same Direct scene."],
	["godotlab_tilemap", "GodotLab Tilemap", {"direct": "playable", "enhanced": "playable"},
		"godotlab/tilemap (Godot 3) Kenney tilemap test → Godot 4 TileMapLayer; Enhanced = letterbox chrome, sky backdrop, landing dust / jump trails, minimap + stats HUD and a tile-grid view over the same Direct level."],
	["silly_game", "Silly Game", {"direct": "playable", "enhanced": "playable"},
		"tangentstorm/silly-game (Godot 3, archived): WASD aardvark walker + mouse shoot; Enhanced = ocean, trails, hit juice + minimap HUD over the same Direct scene."],
	["fnarb_overlap", "Fnarbmlyx Overlap Demo", {"direct": "playable", "enhanced": "playable"},
		"fnarbmlyx demos/overlap_demo (Godot 4.1, 2023): OverlapDemo redone in Godot; Enhanced = letterbox chrome + HUD/overlap juice over the same Direct demo."],
	["fnarb_ast", "Fnarbmlyx Boolean Syntax Tree", {"direct": "playable", "enhanced": "playable"},
		"fnarbmlyx demos/boolean_syntax_tree (Godot 4.1, 2023): seeded random boolean AST; Enhanced = letterbox chrome + grow-in / traversal-wave juice + hover inspector over the same Direct demo."],
	["fnarb_binary_tree", "Fnarbmlyx Binary Tree", {"direct": "playable", "enhanced": "playable"},
		"fnarbmlyx demos/binary_tree (Godot 4.1, 2023): depth-5 binary tree drawing; Enhanced = letterbox chrome, grow-in + traversal-wave juice and hover inspector over the same Direct tree scene."],
	["fnarb_binary_adder", "Fnarbmlyx Binary Adder", {"direct": "playable", "enhanced": "playable"},
		"fnarbmlyx demos/binary_adder (Godot 4.1, 2023): animated 4-bit addition; Enhanced = letterbox chrome + HUD/juice over the same Direct Adder scene."],
	["fnarb_binary_space", "Fnarbmlyx Binary Space", {"direct": "playable", "enhanced": "playable"},
		"fnarbmlyx demos/binary_space (Godot 4.1, 2023): 5-input truth-table space; Enhanced = letterbox chrome + HUD/scan juice over the same Direct demo."],
	["cupid", "Cupid", {"direct": "playable", "enhanced": "playable"},
		"Matchmaking Cupid (2010), AS3/Flixel v1 → GDScript; Enhanced = storm-to-sunset city, clearer bubbles/HUD + match juice over the same rules."],
	["mineswpr", "Mineswpr", {"direct": "playable", "enhanced": "playable"},
		"Retro Forth 11 terminal Minesweeper (2013) → GDScript; Enhanced = modern tiles, flags + win/lose juice over the same rules."],
	["brickslayer", "Brickslayer", {"direct": "playable", "enhanced": "playable"},
		"javascriptgamer.com Breakout + lesson trail (2007), JS → GDScript."],
	["giraffe", "Giraffe", {"direct": "playable", "enhanced": "playable"},
		"pico-games/giraffe.p8 (Pico-8) tiny platformer → GDScript; Enhanced = savanna-dusk restyle + landing juice over the same Direct logic."],
	["ofcp", "OFCP", {"direct": "playable", "enhanced": "playable"},
		"Pineapple OFC vs AI; thin client over wss://ofcp.tangentcode.com/ws; Enhanced = felt chrome + place/score/FL juice over the same Direct client."],
	["chesscoach", "Chess Coach", {"direct": "playable", "enhanced": "playable"},
		"tangentstorm/gd-chesscoach (Godot 4.3): tiny FEN board + trays; Enhanced = walnut chrome + move-list HUD over the same Direct scene. No Stockfish."],
	["canyon_run", "Canyon Run", {"direct": "playable", "enhanced": "playable"},
		"Original River Raid-style canyon flyer (2026): procedural Godot 4 MVP; Enhanced = layered canyon chrome + clearer HUD + juice over the same Direct logic (Design parity deferred)."],
	["terratri", "Terratri", {"direct": "playable", "enhanced": "playable"},
		"Adam Atomic's 5×5 territory game (Terratri Online, 2011/2026 TS) → GDScript rules, hotseat 2P; Enhanced = lit tabletop, hopping pawns, rising forts + player cards over the same Direct rules."],
	["doth", "Doth", {"direct": "playable", "enhanced": "playable"},
		"silverware Doth-A (Turbo Pascal, 1993–1996) Kroz-like adventure → SvA-like pixel Direct; Enhanced = torchlit chrome + pickup juice over the same rules."],
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
