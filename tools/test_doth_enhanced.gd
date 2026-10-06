extends SceneTree
## Headless checks for Doth Enhanced (presentation over Direct doth_world.gd).
## Run: godot --headless --path . --script res://tools/test_doth_enhanced.gd

const World := preload("res://games/doth/direct/doth_world.gd")
const Tiles := preload("res://games/doth/direct/doth_tiles.gd")
const SCENE := "res://games/doth/enhanced/game.tscn"

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: doth_enhanced ", msg)
	else:
		print("SMOKE FAIL: doth_enhanced ", msg)
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _key(code: Key, pressed := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	_test_parity_vs_direct()
	_test_juice_and_stats()
	await _test_scene()
	print("doth_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _same(a, b) -> bool:
	if a.state != b.state or a.level_id != b.level_id or a.hero != b.hero:
		return false
	if a.cash != b.cash or a.magic != b.magic or a.health != b.health or a.ammo != b.ammo:
		return false
	if a.moves != b.moves or a.picks_left != b.picks_left or a.message != b.message:
		return false
	if a.cells != b.cells:
		return false
	return true


## Scripted moves through Enhanced try_move must match a bare Direct twin.
func _test_parity_vs_direct() -> void:
	var inst = (load(SCENE) as PackedScene).instantiate()
	root.add_child(inst)
	_check(inst.world.get_script() == World, "uses the Direct doth_world.gd (no rules copy)")
	_check(inst._atlas != null and inst._atlas.get_width() == Tiles.COLS * Tiles.TILE,
		"shares Direct SvA-like tile atlas width")

	inst.start("starter")
	var d = World.new()
	d.start_play("starter")
	_check(_same(inst.world, d), "starter load matches Direct twin")

	# Walk onto the known coin at (15,8) from forced hero at (14,8).
	for w in [inst.world, d]:
		w.set_cell(w.hero, World.Kind.FLOOR)
		w.hero = Vector2i(14, 8)
		w.set_cell(w.hero, World.Kind.HERO)
	_check(d.get_cell(Vector2i(15, 8)) == World.Kind.COIN, "fixture coin at (15,8)")
	d.try_move(1, 0)
	inst.try_move(1, 0)
	_check(_same(inst.world, d), "coin pickup state matches Direct")
	_check(inst.coins_taken == 1 and inst._particles.size() > 0, "coin juice + counter")

	# Wall bump
	for w in [inst.world, d]:
		w.set_cell(w.hero, World.Kind.FLOOR)
		w.hero = Vector2i(1, 1)
		w.set_cell(w.hero, World.Kind.HERO)
	var bumps0: int = inst.bumps
	_check(not d.try_move(-1, 0) and not inst.try_move(-1, 0), "wall blocks west")
	_check(_same(inst.world, d), "wall bump leaves identical state")
	_check(inst.bumps == bumps0 + 1 and inst._shake > 0.0, "bump juice + counter")

	# Lone boulder push
	for w in [inst.world, d]:
		w.set_cell(w.hero, World.Kind.FLOOR)
		w.hero = Vector2i(39, 10)
		w.set_cell(w.hero, World.Kind.HERO)
		w.set_cell(Vector2i(40, 10), World.Kind.FLOOR)
		w.set_cell(Vector2i(41, 10), World.Kind.FLOOR)
		w.set_cell(Vector2i(42, 10), World.Kind.FLOOR)
		w.set_cell(Vector2i(40, 10), World.Kind.BOULDER)
	d.try_move(1, 0)
	inst.try_move(1, 0)
	_check(_same(inst.world, d), "boulder push matches Direct")
	_check(inst.pushes == 1, "push counter")

	# Overworld load parity
	inst.start("overworld")
	d.start_play("overworld")
	_check(_same(inst.world, d), "overworld load matches Direct twin")

	# Scripted wander on overworld
	var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, 0), Vector2i(1, 0)]
	var same := true
	for i in 40:
		var dir: Vector2i = dirs[i % dirs.size()]
		d.try_move(dir.x, dir.y)
		inst.try_move(dir.x, dir.y)
		same = same and _same(inst.world, d)
	_check(same, "40 scripted overworld moves match Direct twin")
	inst.free()


func _test_juice_and_stats() -> void:
	var inst = (load(SCENE) as PackedScene).instantiate()
	root.add_child(inst)
	_check(inst.state == inst.TITLE and inst._cards["title"].visible, "boots on title card")
	inst.start("starter")
	_check(inst.state == inst.PLAY and not inst._cards["title"].visible, "start() leaves title")

	# Collect gem for magic juice
	inst.world.set_cell(inst.world.hero, World.Kind.FLOOR)
	inst.world.hero = Vector2i(10, 10)
	inst.world.set_cell(inst.world.hero, World.Kind.HERO)
	inst.world.set_cell(Vector2i(11, 10), World.Kind.GEM)
	inst.world.picks_left = maxi(inst.world.picks_left, 1)
	inst._snap_prev()
	inst.try_move(1, 0)
	_check(inst.gems_taken == 1 and inst.world.magic >= 5, "gem pickup tracked")
	_check(inst._floaters.size() > 0, "gem floater")

	# Force win card
	inst.world.picks_left = 0
	inst.world.state = World.State.PLAY
	inst.world.set_cell(inst.world.hero, World.Kind.FLOOR)
	inst.world.hero = Vector2i(12, 10)
	inst.world.set_cell(inst.world.hero, World.Kind.HERO)
	inst.world.set_cell(Vector2i(13, 10), World.Kind.COIN)
	inst.world.picks_left = 1
	inst._snap_prev()
	inst.try_move(1, 0)
	_check(inst.state == inst.WIN and inst._cards["win"].visible, "clearing last pickup shows win card")
	_check(inst._toast_t > 0.0, "room-cleared toast")
	inst._refresh_hud()
	_check(inst._picks_label.text == "0", "HUD picks left 0")
	inst.free()


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("doth", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(reg.get_entry("doth", "direct").is_playable(), "registry: direct still playable")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "letterbox keeps aspect")
	_check(inst.state == inst.TITLE and inst._cards["title"].visible, "boots on the title card")
	var moves0: int = inst.world.moves
	await _frames(10)
	_check(inst.world.moves == moves0, "sim idle on title")

	var back: Button = null
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			back = b
	_check(back != null and back.focus_mode == Control.FOCUS_NONE, "Back to Arcade present, FOCUS_NONE")

	root.push_input(_key(KEY_1))
	root.push_input(_key(KEY_1, false))
	await _frames(8)
	_check(inst.state == inst.PLAY and inst.world.level_id == "starter", "1 leaves title for starter")
	_check(not inst._cards["title"].visible, "title card hidden in play")

	# Esc -> PauseOverlay, Esc again -> arcade
	root.push_input(_key(KEY_ESCAPE))
	await _frames(4)
	_check(paused, "Esc opens PauseOverlay")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(4)
	_check(reg.in_arcade() and not paused, "Esc again -> Back to Arcade")
