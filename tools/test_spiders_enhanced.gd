extends SceneTree
## Headless checks for the spiders_v_aliens Enhanced edition (presentation layer over the
## shared Direct simulation). Drives the real scene through game.step_once(held, just).
## Run: godot --headless --path . --script res://tools/test_spiders_enhanced.gd

const SCENE := "res://games/spiders_v_aliens/enhanced/game.tscn"
const L := preload("res://games/spiders_v_aliens/direct/sva_logic.gd")
const Hints := preload("res://games/spiders_v_aliens/enhanced/hints.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: spiders_enhanced ", msg)
		_fail += 1


func _steps(g, n: int, held := {}) -> void:
	for i in n:
		g.step_once(held.duplicate(), {})


func _place(o, x: float, y: float) -> void:
	L.move_to(o, x, y)
	o.vx = 0.0
	o.vy = 0.0


func _find(w, kind: String, x: float, y: float):
	for o in w.master_layer:
		if not o.is_tilemap() and o.kind == kind and o.x == x and o.y == y:
			return o
	return null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# registry: Enhanced is playable and points at this scene, letterboxed
	var reg = root.get_node_or_null("GameRegistry")
	_check(reg != null, "GameRegistry autoload present")
	if reg != null:
		var e = reg.get_entry("spiders_v_aliens", "enhanced")
		_check(e != null and e.status == "playable" and e.is_playable(), "registry: enhanced is playable")
		_check(e != null and e.scene_path == SCENE and e.scale_mode == "letterbox", "registry: enhanced scene + letterbox")

	# scene loads and builds its stage
	var packed := load(SCENE) as PackedScene
	_check(packed != null, "enhanced scene loads")
	if packed == null:
		quit(1)
		return
	var g = packed.instantiate()
	root.add_child(g)
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 3:
		await process_frame
	_check(g.process_mode == Node.PROCESS_MODE_INHERIT, "game pauses with the tree (PauseOverlay)")
	_check(g.world is L, "world is the shared Direct simulation (sva_logic.gd)")
	_check(g.world.state == L.MENU, "starts on the title screen")
	_check(g.stage != null and g.stage.layers.size() == 4, "stage built 4 tile layers")
	var env: TileMapLayer = g.stage.layers["Environment"]
	_check(env.get_used_cells().size() > 3000, "Environment layer populated (%d cells)" % env.get_used_cells().size())
	_check(g.stage.fixtures.size() == 17, "17 fluorescent fixtures found for lighting (%d)" % g.stage.fixtures.size())
	_check(g.get_node("%BackButton").visible, "title shows Back to Arcade button")
	_check(g.get_node("%BackButton").focus_mode == Control.FOCUS_NONE, "Back button never steals Space")

	# Space walks the original menu -> prologue flow
	g.step_once({}, {"space": true})
	g.step_once({}, {})
	_check(g.world.state == L.OPENING1, "space -> prologue 1")
	# Enter (Enhanced QoL) skips straight into the ship
	g.step_once({}, {"enter": true})
	_check(g.world.state == L.PLAY, "enter skips the prologue -> play")
	_check(g.aliens_at_start == 25, "25 live Dentists at start (%d)" % g.aliens_at_start)
	await process_frame
	_check(not g.get_node("%BackButton").visible, "Back button hidden in play")
	_check(g.stage.light_count > 0, "lights fed to the shader (%d)" % g.stage.light_count)

	# hero move through the scene's input path; camera follows
	var w = g.world
	var x0: float = w.hero.x
	var cam0: Vector2 = g.cam_center
	_steps(g, 30, {"right": true})
	_check(w.hero.x > x0 + 15.0 and w.hero.vx <= 100.0, "right arrow moves the hero (%.1f -> %.1f)" % [x0, w.hero.x])
	_check(w.geist.vx > 0.0, "mimeogeist mirrors the move")
	for i in 20:
		await process_frame
	_check(g.cam_center.x > cam0.x, "camera follows the hero")
	var hero_screen: Vector2 = g.world_to_screen(Vector2(w.hero.x, w.hero.y))
	_check(g.view_rect().has_point(hero_screen), "hero is on screen")

	# interaction 1: grab prompt then drag a crate (same spot as the Direct test)
	var box = _find(w, "Box", 96.0, 1240.0)
	_place(w.hero, 64.0, 1240.0)
	g.step_once({}, {})
	_place(w.hero, 80.0, 1240.0)
	g.step_once({}, {})
	var ps: Array = Hints.prompts(w, w.hero)
	var east = null
	for p in ps:
		if p["dir"] == L.DIR_E:
			east = p
	_check(east != null and east["text"] == "Drag crate" and east["key"] == "D", "prompt: [D] Drag crate")
	g.step_once({"d": true}, {"d": true})
	_check(w.hero.grabbers[L.DIR_E].content == box, "D grabs the crate")
	_check(g.sfx.last_played == "grab", "grab plays a sound")
	var bx0: float = box.x
	_steps(g, 10, {"d": true, "left": true})
	_check(box.x < bx0, "dragged crate follows the hero")
	g.step_once({}, {})
	_check(w.hero.grabbers[L.DIR_E].content == null, "releasing D drops it")

	# interaction 2: portal at (400,1400) -> far side of its twin
	_place(w.hero, 384.0, 1400.0)
	g.step_once({}, {})
	ps = Hints.prompts(w, w.hero)
	_check(ps.size() > 0 and ps[0]["text"] == "Teleport", "prompt: Teleport at a live portal")
	g.step_once({"d": true}, {"d": true})
	_check(w.hero.x == 352.0 and w.hero.y == 1400.0, "portal teleports (same rules as Direct)")
	_check(g.sfx.last_played == "warp", "teleport plays the warp sound")

	# locked portal says so (and grabbing it does nothing)
	var locked = _find(w, "Portal", 336.0, 1200.0)
	var d: Dictionary = Hints.describe(w, w.hero, L.DIR_E, locked)
	_check(d["text"] == "Portal offline" and not d["active"], "prompt: unpowered portal reads 'Portal offline'")

	# hurt -> flash + sound; death -> R retries straight into a fresh ship
	w.hero_hurt(1)
	g.step_once({}, {})
	_check(w.hero.health == 4.0, "hurt costs a heart")
	w.hero.health = 1.0
	w.hero_hurt(1)
	g.step_once({}, {})
	_check(g.world.state == L.DEATH, "last heart -> GAME OVER")
	_check(g.sfx.last_played == "lose", "game over sting")
	await process_frame
	g.step_once({}, {"r": true})
	_check(g.world.state == L.PLAY and g.world.hero.health == 5.0 and g.world != w, "R retries with a fresh ship")
	w = g.world

	# win
	_place(w.hero, w.exit_obj.x + 4.0, w.exit_obj.y + 4.0)
	g.step_once({}, {})
	g.step_once({}, {})
	_check(w.state == L.WIN, "touching the exit -> YOU ESCAPED")
	await process_frame
	g.step_once({"space": true}, {})
	g.step_once({}, {})
	_check(g.world.state == L.MENU, "space on the win screen -> title")

	# pausing the tree (what PauseOverlay does) freezes the simulation
	g.step_once({}, {"enter": true})
	var f0: int = g.world.frame_count
	paused = true
	for i in 5:
		await process_frame
	_check(g.world.frame_count == f0, "paused tree: simulation frozen")
	paused = false
	for i in 5:
		await process_frame

	# toggles
	g.step_once({}, {"m": true})
	_check(not g.show_map, "M hides the minimap")
	g.step_once({}, {"h": true})
	_check(not g.show_hints, "H hides grab hints")

	g.queue_free()
	await create_timer(0.2).timeout  # let the audio server drop stopped playbacks
	quit(1 if _fail else 0)
