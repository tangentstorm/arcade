extends SceneTree
## Headless checks for cardinalrule Direct (spritetest.pas motion + title -> play).
## Run: godot --headless --path . --script res://tools/test_cardinalrule.gd

const L := preload("res://games/cardinalrule/direct/bird_logic.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: cardinalrule ", msg)
		_fail += 1


func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev


func _initialize() -> void:
	var b = L.new()
	_check(b.pos == Vector2(256, 224) and b.MAX_X == 448 and b.MAX_Y == 384,
		"starts at (256,224), bounds 0..448 x 0..384 (64px hero)")
	b.step()
	_check(b.pos == Vector2(256, 224) and is_equal_approx(b.dy, 0.2), "gravity +0.2 after move")
	for i in 200:
		b.step()
	_check(b.pos.y == 384 and b.dy <= 0.2, "falls and lands on the bottom edge")
	var dy0: float = b.dy
	b.key(KEY_UP)
	_check(is_equal_approx(b.dy, dy0 - 4.0), "Up = dy - 4 (flap)")
	b.step()
	_check(b.pos.y < 384, "flap lifts off")
	b.key(KEY_LEFT)
	b.key(KEY_LEFT)
	for i in 400:
		b.step()
	_check(b.pos.x == 0 and is_equal_approx(b.dx, -4.0), "Left x2 = dx -4, kept; clamps at x=0")
	for i in 5:
		b.key(KEY_RIGHT)
	for i in 400:
		b.step()
	_check(b.pos.x == 448, "Right impulses carry it to x=448")
	for i in 30:
		b.key(KEY_UP)
	for i in 5:
		b.step()
	_check(b.pos.y == 0, "clamps at the top edge")
	b.key(KEY_HOME)
	_check(is_equal_approx(b.dx, 6.0), "PgUp/PgDn/Home/End are no-ops (pass)")

	var scene: PackedScene = load("res://games/cardinalrule/direct/game.tscn")
	_check(scene != null and scene.can_instantiate(), "direct scene loads")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	_check(not game.playing, "opens on the MenuState title")
	game._gui_input(_key(KEY_UP))
	_check(not game.playing, "arrows do nothing on the title")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	game._gui_input(click)
	_check(game.playing, "click to play")
	game._gui_input(_key(KEY_UP))
	_check(is_equal_approx(game.bird.dy, -4.0), "Up reaches the bird in play")
	game.queue_free()
	await process_frame
	print("VERIFY DONE: ", _fail)
	quit(_fail)
