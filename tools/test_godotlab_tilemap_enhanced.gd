extends SceneTree
## Headless checks for GodotLab Tilemap Enhanced (presentation over the Direct level).
## Run: godot --headless --path . --script res://tools/test_godotlab_tilemap_enhanced.gd

const SCENE := "res://games/godotlab_tilemap/enhanced/game.tscn"
const DIRECT := "res://games/godotlab_tilemap/direct/game.tscn"
const TilemapScript := preload("res://games/godotlab_tilemap/direct/tilemap.gd")
const PlayerScript := preload("res://games/godotlab_tilemap/direct/player.gd")

var _fail := 0
var _completed := false  ## a runtime error aborts _test_scene early; don't report "all ok" then


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: godotlab_tilemap_enhanced ", msg)
	else:
		print("SMOKE FAIL: godotlab_tilemap_enhanced ", msg)
		_fail += 1


func _key(code: Key, pressed := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev


func _tap(code: Key) -> void:
	root.push_input(_key(code, true))
	root.push_input(_key(code, false))


## Held keys go through Input so Direct's Input.is_key_pressed polling sees them (both players).
func _hold(code: Key, down: bool) -> void:
	Input.parse_input_event(_key(code, down))
	Input.flush_buffered_events()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_scene()
	_check(_completed, "test sequence ran to completion")
	print("godotlab_tilemap_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _no_rules_copy() -> void:
	## Enhanced must instance Direct, not redefine its tile replay or player physics.
	var src := FileAccess.get_file_as_string("res://games/godotlab_tilemap/enhanced/game.gd")
	_check(src.contains("preload(\"res://games/godotlab_tilemap/direct/game.tscn\")"),
		"preloads Direct game.tscn")
	_check(not src.contains("move_and_slide"), "no move_and_slide (player physics stays Direct)")
	_check(not src.contains("JUMP_VELOCITY") and not src.contains("GRAVITY"),
		"no jump / gravity constants copied")
	_check(not src.contains("set_cell("), "no set_cell (tile replay stays Direct)")
	_check(not src.contains("func respawn"), "no respawn rules copy")
	_check(not src.contains("TILE_DATA := ["), "no tile_data array copy")
	var files: PackedStringArray = DirAccess.get_files_at("res://games/godotlab_tilemap/enhanced/")
	for f in files:
		if f.ends_with(".gd") and f != "game.gd":
			_check(false, "unexpected extra script in enhanced/: " + f)


func _test_scene() -> void:
	_no_rules_copy()
	_check(load(SCENE) is PackedScene, "scene loads")
	_check(load(DIRECT) is PackedScene, "Direct scene still loads")

	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("godotlab_tilemap", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")
	_check(reg.get_entry("godotlab_tilemap", "direct").is_playable(), "registry: direct still playable")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(inst.state == inst.TITLE and inst._cards["title"].visible, "boots on the title card")
	_check(inst.demo == null, "Direct level not loaded until play")
	_check(inst.STAGE == Vector2(1280, 720), "1280×720 stage")
	_check(inst.FIELD == Vector2(960, 540), "960×540 field (¾ of 1280×720)")
	_check(inst.FIELD_POS.x >= 0 and inst.FIELD_POS.x + inst.FIELD.x <= inst.STAGE.x \
			and inst.FIELD_POS.y >= 0 and inst.FIELD_POS.y + inst.FIELD.y <= inst.STAGE.y,
		"field fits inside stage")

	var backs := 0
	var starts := 0
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			backs += 1
			_check(b.focus_mode == Control.FOCUS_NONE, "Back to Arcade FOCUS_NONE (%s)" % b.get_path())
		elif b.text == "Start":
			starts += 1
			_check(b.focus_mode == Control.FOCUS_NONE, "Start FOCUS_NONE")
	_check(backs >= 2, "Back to Arcade on title card and HUD (%d)" % backs)
	_check(starts == 1, "Start button on title card")

	# Enter → play: Direct level instanced with the Direct scripts.
	_tap(KEY_ENTER)
	await _frames(6)
	_check(inst.state == inst.PLAY and inst.demo != null, "Enter begins and loads Direct level")
	_check(not inst._cards["title"].visible and inst._hud.visible, "title hidden, HUD shown")
	_check(inst._vp_box.visible, "level viewport visible")
	var d: Node2D = inst.demo
	_check(d.scene_file_path == DIRECT, "embedded scene is Direct game.tscn")
	_check(d.get_script() == TilemapScript, "level uses Direct tilemap.gd (shared)")
	_check(inst.player.get_script() == PlayerScript, "player uses Direct player.gd (shared)")
	_check(d.placed == 48 and d.skipped_blank == 170,
		"Direct replay: placed %d, blank %d" % [d.placed, d.skipped_blank])
	_check(not d.get_node("Hud").visible, "Direct plain HUD hidden (Enhanced owns HUD)")
	_check(inst._blank_cells.size() == 170, "Enhanced reads 170 blank cells from Direct tile_data")

	# SubViewport keeps native 1280×720, scaled ¾ (stretch=false, not faked half-size).
	_check(inst._viewport.size == Vector2i(1280, 720), "SubViewport stays 1280×720")
	_check(inst._vp_box.stretch == false, "LevelView.stretch is false")
	_check(inst._vp_box.size == inst.VP_SIZE, "LevelView size is VP_SIZE (1280×720)")
	var sc: Vector2 = inst._vp_box.scale
	_check(is_equal_approx(sc.x, 0.75) and is_equal_approx(sc.y, 0.75), "LevelView scaled to FIELD/VP_SIZE (¾)")
	_check(inst._viewport.transparent_bg, "viewport transparent so the sky backdrop shows")
	_check(inst.player.get_viewport() == inst._viewport, "Direct player lives in the SubViewport")
	var fx_i: int = inst._fx.get_index()
	var host_i: int = inst.get_node("StageHost").get_index()
	_check(inst._fx.get_parent() == inst and fx_i > host_i,
		"Fx draws above StageHost/Direct SubViewport (index %d > %d)" % [fx_i, host_i])
	var clip: Control = inst.get_node("FieldClip")
	_check(clip.clip_contents and clip.get_index() > host_i and clip.size == inst.FIELD,
		"FieldClip clips in-field juice to the field, above Direct")
	_check(inst._field_fx.get_parent() == clip, "FieldFx (dust / trails / grid) lives in FieldClip")

	# Camera mapping: world_to_stage goes through Direct's Camera2D (684, 500) at ¾.
	await _physics(4)
	var cam_world := Vector2(684, 500)
	var mid: Vector2 = inst.world_to_stage(cam_world)
	var want: Vector2 = inst.FIELD_POS + inst.FIELD * 0.5
	_check(mid.distance_to(want) < 1.0, "camera centre maps to field centre (%s vs %s)" % [mid, want])
	var c0: Vector2 = inst.world_to_stage(Vector2(360, 288))
	var exp0: Vector2 = inst.FIELD_POS + (Vector2(360, 288) - cam_world + inst.VP_SIZE * 0.5) * 0.75
	_check(c0.distance_to(exp0) < 1.0, "grass corner maps through camera at ¾")

	# Bare Direct twin alongside: Input is global, so both players get the same keys.
	var twin: Node2D = (load(DIRECT) as PackedScene).instantiate()
	root.add_child(twin)
	var tp: CharacterBody2D = twin.get_node("Player")
	var ep: CharacterBody2D = inst.player
	await _physics(90)
	_check(twin.placed == d.placed and twin.skipped_blank == d.skipped_blank,
		"parity: placed / blank match Direct twin")
	var e_cells: Array = inst.layer.get_used_cells()
	var t_cells: Array = twin.get_node("TileMap").get_used_cells()
	e_cells.sort()
	t_cells.sort()
	_check(e_cells == t_cells, "parity: painted cells match Direct twin (%d)" % e_cells.size())
	var atlas_mismatch := 0
	for c in e_cells:
		if inst.layer.get_cell_atlas_coords(c) != twin.get_node("TileMap").get_cell_atlas_coords(c):
			atlas_mismatch += 1
	_check(atlas_mismatch == 0, "parity: atlas coords match Direct twin")
	_check(ep.is_on_floor() and tp.is_on_floor(), "both players land on the grass")
	_check(absf(ep.position.y - tp.position.y) < 0.5 and absf(ep.position.x - tp.position.x) < 0.5,
		"parity: rest position matches (%s vs %s)" % [ep.position, tp.position])
	_check(inst.landings >= 1, "juice: landing observed (%d)" % inst.landings)

	# Walk right together.
	var x0 := ep.position.x
	_hold(KEY_RIGHT, true)
	await _physics(20)
	_hold(KEY_RIGHT, false)
	await _physics(2)
	_check(ep.position.x > x0 + 60.0, "→ walks right in Enhanced (dx=%.0f)" % (ep.position.x - x0))
	_check(absf(ep.position.x - tp.position.x) < 1.0,
		"parity: walk distance matches twin (%.1f vs %.1f)" % [ep.position.x, tp.position.x])
	_check(inst.distance > 60.0, "HUD walked distance tracks Direct (%.0f px)" % inst.distance)
	_check(inst.walk_puffs >= 1, "juice: walk dust puffs (%d)" % inst.walk_puffs)
	_check(ep.get_node("Sprite").flip_h == tp.get_node("Sprite").flip_h, "parity: facing matches twin")

	# Jump together.
	var jumps0: int = inst.jumps
	_hold(KEY_SPACE, true)
	await _physics(6)
	_hold(KEY_SPACE, false)
	_check(ep.velocity.y < 0.0 and ep.position.y < 270.0, "Space jumps in Enhanced")
	_check(absf(ep.position.y - tp.position.y) < 1.0,
		"parity: jump arc matches twin (%.1f vs %.1f)" % [ep.position.y, tp.position.y])
	_check(inst.jumps == jumps0 + 1, "juice: jump counted (%d)" % inst.jumps)
	await _physics(10)
	_check(inst._ghosts.size() > 0, "juice: airborne afterimage trail")
	await _physics(60)
	_check(ep.is_on_floor() and tp.is_on_floor(), "both land again")
	_check(absf(ep.position.y - tp.position.y) < 0.5, "parity: landing y matches twin")
	_check(inst.peak_height > 100.0, "HUD peak height recorded (%.0f px)" % inst.peak_height)
	_check(inst.best_air > 0.3, "HUD airtime recorded (%.2f s)" % inst.best_air)
	_check(inst.landings >= 2, "juice: second landing observed")
	await _frames(2)
	_check(inst._stats_label.text.contains("jumps     1"), "stats HUD shows the jump")
	_check(inst._level_label.text.contains("placed 48"), "level HUD shows placed 48")

	# Fall off: Direct respawns; Enhanced observes it.
	ep.position = Vector2(100, 200)
	tp.position = Vector2(100, 200)
	await _physics(90)
	_check(ep.respawns >= 1 and tp.respawns == ep.respawns,
		"parity: Direct respawn fires in both (%d / %d)" % [ep.respawns, tp.respawns])
	_check(inst.respawns_seen == ep.respawns, "juice: respawn observed (%d)" % inst.respawns_seen)
	_check(ep.position.distance_to(tp.position) < 1.0, "parity: respawned at the same spot")
	twin.queue_free()
	await _frames(2)

	# Shadow / ground lookup reads Direct cells.
	var gy: float = inst.ground_below(Vector2(500, 200))
	_check(is_equal_approx(gy, 288.0), "ground_below finds the grass top (%.0f)" % gy)
	_check(is_nan(inst.ground_below(Vector2(100, 200))), "ground_below sees the void left of the level")

	# G toggles the grid view (presentation only).
	_tap(KEY_G)
	await _frames(2)
	_check(inst.show_grid, "G shows the tile grid")
	_tap(KEY_G)
	await _frames(2)
	_check(not inst.show_grid, "G hides the tile grid")

	# R reloads a fresh Direct level.
	var old = inst.demo
	_tap(KEY_R)
	await _frames(6)
	_check(inst.state == inst.PLAY and inst.demo != null and inst.demo != old, "R reloads a fresh Direct level")
	_check(inst.demo.get_script() == TilemapScript and inst.demo.placed == 48, "reloaded level is Direct, 48 tiles")
	_check(inst.jumps == 0 and inst.respawns_seen == 0, "R resets run stats")

	# Esc → PauseOverlay → arcade
	root.push_input(_key(KEY_ESCAPE))
	await _frames(3)
	_check(paused, "Esc opens PauseOverlay and pauses the tree")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(6)
	_check(reg.in_arcade() and not paused, "Esc again → Back to Arcade")
	_completed = true
