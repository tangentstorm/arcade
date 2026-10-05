extends SceneTree
## Logic tests for games/brickslayer/direct/brickslayer_logic.gd.
## Run: godot --headless --path . --script res://tools/test_brickslayer.gd

const Logic := preload("res://games/brickslayer/direct/brickslayer_logic.gd")
const TrailData := preload("res://games/brickslayer/trail/trail_data.gd")
const TrailCursor := preload("res://games/brickslayer/trail/trail_cursor.gd")
const STORE := "user://test_brickslayer_scores.cfg"

var _fails := 0
var _games: Array = []


func mk(step: int):
	var g = Logic.new(step, STORE)
	_games.append(g)
	return g


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	test_layout()
	test_step_gating()
	test_serve_and_walls()
	test_collide()
	test_brick_shades_and_score()
	test_lose_life_and_game_over()
	test_level_clear()
	test_high_scores()
	test_trail()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	for g in _games:
		g.dispose()
	_games.clear()
	print("brickslayer tests: %s" % ("OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(1 if _fails else 0)


func check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("SMOKE FAIL: brickslayer: ", what)


func ticks(g, n: int) -> void:
	for i in n:
		g.tick()


func test_layout() -> void:
	var g = mk(10)
	check(g.bricks.size() == 50, "50 bricks")
	check(g.bricks[0].x == 8 and g.bricks[0].y == 4 * 22 + 30 and g.bricks[0].shade == 1,
			"first brick is bottom of column 0")
	check(g.bricks[4].y == 30 and g.bricks[4].shade == 5, "top row is shade 5")
	check(g.screen == "title", "starts on title")
	check(g.paddle.x == 168 and g.paddle.y == 250, "paddle at 168,250")


func test_step_gating() -> void:
	var g1 = mk(1)
	check(g1.bricks.is_empty() and g1.screen == "game", "lesson 1: no bricks, straight to game")
	var g2 = mk(2)
	g2.key_down(KEY_LEFT); g2.key_down(KEY_LEFT)
	check(g2.paddle.x == 148, "lesson 2: keydown moves 10px")
	var g3 = mk(3)
	g3.key_down(KEY_RIGHT); ticks(g3, 10)
	check(g3.paddle.x == 218, "lesson 3: velocity 5/tick")
	ticks(g3, 100)
	check(g3.paddle.x == 400 - 64, "lesson 3: clamped at right wall")
	g3.key_up(KEY_RIGHT)
	check(g3.paddle.velocity == 0, "lesson 3: keyup stops")
	var g5 = mk(5)
	g5.key_down(KEY_P)
	check(g5.screen == "game", "lesson 5: no pause screen yet")


func test_serve_and_walls() -> void:
	var g = mk(10)
	g.key_up(KEY_ENTER)
	check(g.screen == "game", "enter starts game")
	g.tick()
	check(g.ball.on_paddle and g.ball.x == 168 + 32 - 8 and g.ball.y == 250 - 16, "ball sits on paddle")
	g.key_down(KEY_UP)
	check(not g.ball.on_paddle and g.ball.dy == -4 and is_equal_approx(g.ball.dx, 0.25), "serve")
	var x0: int = g.ball.x
	ticks(g, 5)
	check(g.ball.x == x0, "0.25 dx rounds away like offsetLeft")
	# wall bounce
	g.ball.set_x(2); g.ball.set_y(200); g.ball.dx = -3; g.ball.dy = -1
	g.tick()
	check(g.ball.dx == 3, "left wall flips dx")


func test_collide() -> void:
	var g = mk(10)
	var r = Logic.Sprite.new(100, 100, 34, 18)
	g.ball.set_x(110); g.ball.set_y(130); g.ball.dx = 0; g.ball.dy = -4
	check(g.collide(r) == null, "not yet")
	g.ball.set_y(121)
	g.ball.set_y(119)
	var v = g.collide(r)
	check(v != null and v[0] == 1 and v[1] == -1, "straight-up hit on bottom bounces dy")
	g.ball.set_x(137); g.ball.set_y(105); g.ball.dx = -3; g.ball.dy = 0.5
	v = g.collide(r)
	check(v != null and v[0] == -1, "side hit bounces dx")


func test_brick_shades_and_score() -> void:
	var g = mk(10)
	g.swap("game")
	var b = g.bricks[4]    # shade 5, top row
	g._brick_hit(b)
	check(b.shade == 4 and b.solid, "hit lowers shade")
	var low = g.bricks[0]
	g._brick_hit(low)
	check(not low.solid and g.brick_count == 49, "shade 1 breaks")
	g.score_inc()
	check(g.score == 1, "score_inc")


func test_lose_life_and_game_over() -> void:
	var g = mk(10)
	g.swap("game")
	g.score_set(0)
	for i in 3:
		g.lose_life()
	check(g.balls_left == 0 and g.screen == "game", "three spares used")
	g.lose_life()
	check(g.screen == "gameover", "fourth loss is game over")
	ticks(g, 350)
	check(g.screen == "scores", "score 0 -> high score list (not name entry)")
	check(g.balls_left == 3 and g.score == 0, "game_reset after SWAP_SPEED")
	ticks(g, 350)
	check(g.screen == "title", "scores -> title")
	var g6 = mk(6)
	for i in 5:
		g6.lose_life()
	check(g6.screen == "game", "lesson 6: no game over screen")


func test_level_clear() -> void:
	var g = mk(10)
	g.swap("game")
	for b in g.bricks:
		while b.solid:
			g._brick_hit(b)
	check(g.screen == "clear", "level clear screen")
	ticks(g, 200)
	check(g.screen == "game" and g.current_level == 2 and g.brick_count == 50, "next level after 2 s")
	var g5 = mk(5)
	for b in g5.bricks:
		while b.solid:
			g5._brick_hit(b)
	check(g5.screen == "game" and g5.bricks[0].solid, "lesson 5: bricks just reset")


func test_high_scores() -> void:
	var g = mk(10)
	check(g.top_scores().size() == 10 and g.low_high_score == 1, "seeded list")
	g.swap("game")
	g.score_set(42)
	g.balls_left = 0
	g.lose_life()
	ticks(g, 350)
	check(g.screen == "congrats", "42 beats the list")
	g.post_score("  zed   the  great ")
	check(g.screen == "scores", "post -> scores")
	var top = g.top_scores()
	check(top[0][2] == "zed the great" and top[0][0] == 42 and top[0][3] == "new", "new score first")
	g.post_score("again")
	check(g.high_scores.size() == 11, "no double post")
	var g2 = mk(10)
	check(g2.top_scores()[0][2] == "zed the great", "scores persist")
	check(g2.low_high_score == 2, "10th place is now 2")


func test_trail() -> void:
	check(TrailData.LESSONS.size() == 11, "11 lessons")
	var c = TrailCursor.new(TrailData.LESSONS)
	var n := 1
	while not c.at_end():
		var before: float = c.value()
		c.next()
		check(c.value() > before, "cursor advances")
		n += 1
	var total := 0
	for l in TrailData.LESSONS:
		total += maxi(1, l["blocks"].size())
	check(n == total, "visits every block once (%d)" % total)
	c.seek(1, 0)
	c.prev()
	check(c.lesson == 0 and c.block == 2, "prev crosses into last block of previous lesson")
	check(c.code().begins_with("/*"), "00-setup block 3 is the header comment")
