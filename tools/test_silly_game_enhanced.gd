extends SceneTree
## Headless checks for Silly Game Enhanced (presentation over the Direct scene).
## Run: godot --headless --path . --script res://tools/test_silly_game_enhanced.gd

const SCENE := "res://games/silly_game/enhanced/game.tscn"
const DIRECT := "res://games/silly_game/direct/game.tscn"
const HeroScript := preload("res://games/silly_game/direct/hero.gd")
const AimScript := preload("res://games/silly_game/direct/aim.gd")
const BadguyScript := preload("res://games/silly_game/direct/badguy.gd")
const BulletsScript := preload("res://games/silly_game/direct/bullets.gd")
const WorldScript := preload("res://games/silly_game/direct/world.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: silly_game_enhanced ", msg)
	else:
		print("SMOKE FAIL: silly_game_enhanced ", msg)
		_fail += 1


func _key(code: Key, down := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	return ev


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
	print("silly_game_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	_check(load(DIRECT) is PackedScene, "Direct scene still loads")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("silly_game", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "expand",
		"registry: enhanced playable, expand (title scale_mode)")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")
	_check(reg.get_entry("silly_game", "direct").is_playable(), "registry: direct still playable")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(inst.state == inst.TITLE and inst._cards["title"].visible, "boots on the title card")
	_check(inst.direct == null, "Direct scene not loaded until play")

	var back: Button = null
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			back = b
	_check(back != null and back.focus_mode == Control.FOCUS_NONE, "Back to Arcade present, FOCUS_NONE")

	# Space -> play: Direct scene instanced with Direct scripts.
	root.push_input(_key(KEY_SPACE))
	await _frames(4)
	_check(inst.state == inst.PLAY and inst.direct != null, "Space begins and loads the Direct scene")
	_check(not inst._cards["title"].visible and inst._hud.visible, "title hidden, HUD shown")
	var d: Node2D = inst.direct
	_check(d.scene_file_path == DIRECT, "embedded scene is Direct game.tscn")
	_check(d.get_script() == WorldScript and d.placed == 671, "Direct world.gd rebuilt 671 tiles (got %d)" % d.placed)
	_check(inst.hero.get_script() == HeroScript, "hero uses Direct hero.gd (shared)")
	_check(inst.aim.get_script() == AimScript, "aim uses Direct aim.gd (shared)")
	_check(inst.badguy.get_script() == BadguyScript, "badguy uses Direct badguy.gd (shared)")
	_check(inst.bullets.get_script() == BulletsScript and inst.bullets.get_child_count() == 51,
		"bullet pool is Direct bullets.gd with 51 bullets")
	_check(not d.get_node("Hud").visible, "Direct hint HUD hidden; Enhanced owns HUD")
	_check(inst._under.get_parent() == d and inst._under.get_index() == d.get_node("TileMap").get_index() + 1,
		"shadow layer sits between tilemap and sprites")

	# Walk: same 8 px / physics frame as Direct.
	await _physics(2)
	var h0: Vector2 = inst.hero.position
	_hold(KEY_D, true)
	await _physics(5)
	_hold(KEY_D, false)
	_check(is_equal_approx(inst.hero.position.x - h0.x, 40.0),
		"D walks 8 px/frame like Direct (dx=%.1f)" % (inst.hero.position.x - h0.x))
	_check(inst.hero.frame == 0, "D faces right (frame 0)")
	await _frames(2)
	_check(inst.distance > 30.0, "HUD walked distance tracks hero (%.1f)" % inst.distance)

	# Shot detection: emulate Direct firing a pooled bullet at the badguy.
	var b1: Sprite2D = inst.bullets.get_child(1)
	var target: Vector2 = inst.badguy.position
	b1.position = target - Vector2(16 * 6, 0)
	b1.velocity = Vector2(16, 0)
	await _frames(1)
	_check(inst.shots == 1, "new bullet velocity counts as a shot (shots=%d)" % inst.shots)
	_check(inst._muzzle > 0.0, "juice: muzzle flash")
	await _physics(12)
	await _frames(2)
	_check(b1.position.x > target.x, "bullet advances at Direct speed past the badguy")
	_check(inst.hits == 1, "view-only hit counter (hits=%d)" % inst.hits)
	_check(inst._trails[b1].size() > 1, "juice: bullet trail recorded")
	_check(inst.badguy.frame == 12, "Direct badguy.gd flipped to hit frame 12")
	_check(inst.badguy_down and inst._flash > 0.0, "juice: BONK flash on badguy hit")
	_check(inst._particles.size() > 0, "juice: hit particles")
	_check(inst._stat_labels["foe"].text == "BONKED", "HUD shows badguy BONKED")
	_check(inst._stat_labels["acc"].text == "100%", "HUD accuracy 100%% (got %s)" % inst._stat_labels["acc"].text)
	_check(inst._ground_kind(Vector2(-100000, -100000)) == "void", "ground probe: off-map is void")

	# R: Direct hero.gd reloads the scene; Enhanced lands straight back in play.
	_hold(KEY_R, true)
	await _physics(2)
	_hold(KEY_R, false)
	await _frames(6)
	var inst2 = current_scene
	_check(inst2 != null and inst2 != inst and inst2.scene_file_path == SCENE, "R reloads the Enhanced scene")
	_check(inst2.state == inst2.PLAY and inst2.direct != null and inst2.shots == 0,
		"after R: back in play with fresh stats, no title card")

	# Esc -> PauseOverlay, Esc again -> arcade (cursor restored by Direct aim.gd).
	root.push_input(_key(KEY_ESCAPE))
	await _frames(6)
	_check(paused, "Esc opens PauseOverlay and pauses the tree")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(4)
	_check(reg.in_arcade() and not paused, "Esc again -> Back to Arcade")
