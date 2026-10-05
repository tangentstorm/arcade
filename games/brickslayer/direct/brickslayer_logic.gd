extends RefCounted
## Brickslayer game logic, ported from the javascriptgamer.com lesson code (2007).
##
## Nothing here touches nodes; game.gd draws the state and feeds in keys.
## `step` is the lesson number (0..10). Each feature turns on at the lesson
## that added it, so the code trail can "Play this step".
##
## The original was DOM-based: sprite positions came from offsetLeft and
## offsetTop, which are integers. Positions here are ints too, rounded on
## every set, so a fractional dx like the 0.25 serve spin behaves as it did
## in the browser.

signal sound(name: String)         ## soundManager.play(name)
signal screen_changed(name: String)

const W := 400                     ## #console width
const H := 300                     ## #console height
const TICK_MS := 10                ## setInterval(…, 1) was clamped to ~10 ms in 2007 browsers
const SERVE_SPEED := -4            ## var serveSpeed = -4
const SPARES_START := 3
const CLEARED_SPEED := 2000        ## ms to show level clear
const SWAP_SPEED := 3500           ## ms to show game over / high scores
const BOUNCE := -1
const NO_BOUNCE := 1

## Lesson numbers where features appear.
const STEP_PADDLE := 1
const STEP_KEYBOARD := 2
const STEP_ANIMATION := 3
const STEP_WORLD := 4
const STEP_COLLISION := 5
const STEP_SCORING := 6
const STEP_SOUND := 7
const STEP_SCREENS := 8
const STEP_HIGHSCORES := 9
const LAST_STEP := 10

## Seed list from lesson 09 (highscores.txt): [score, level, name].
const SEED_SCORES := [
	[10, 1, "alice"], [9, 1, "bob"], [8, 1, "charlie"], [7, 1, "darla"],
	[6, 1, "eddie"], [5, 1, "flora"], [4, 1, "gabe"], [3, 1, "hannah"],
	[2, 1, "ian"], [1, 1, "jamie"],
]
const SCORE_FILE_SIZE := 100       ## $FILE_SIZE
const SCORE_LIST_SIZE := 10        ## $LIST_SIZE


class Sprite:
	var x := 0
	var y := 0
	var w := 0
	var h := 0

	func _init(px: int, py: int, pw: int, ph: int) -> void:
		x = px; y = py; w = pw; h = ph

	## style.left = v + 'px'; offsetLeft reads it back rounded.
	func set_x(v: float) -> void:
		x = int(floor(v + 0.5))

	func set_y(v: float) -> void:
		y = int(floor(v + 0.5))

	func move_by(dx: float, dy: float) -> void:
		set_x(x + dx)
		set_y(y + dy)


class Paddle extends Sprite:
	var speed := 5
	var friction := 0.5
	var velocity := 0.0

	func _init() -> void:
		super(168, 250, 64, 16)    ## #paddle { left:168px; top:250px; 64x16 }


class Ball extends Sprite:
	var dx := 0.0
	var dy := 0.0
	var on_paddle := true

	func _init() -> void:
		super(268, 274, 16, 16)    ## #ball { top:274px; left:268px; 16x16 }


class Brick extends Sprite:
	var start_shade := 1
	var shade := 1
	var solid := true

	func _init(px: int, py: int, p_shade: int) -> void:
		# 32x16 box + 1px border on each side = 34x18 offset size
		super(px, py, 34, 18)
		start_shade = p_shade
		reset()

	func reset() -> void:
		solid = true
		shade = start_shade


var step := LAST_STEP
var paddle := Paddle.new()
var ball := Ball.new()
var bricks: Array[Brick] = []
var brick_count := 0               ## Brick.count
var score := 0
var current_level := 1
var balls_left := SPARES_START
var screen := "game"
var clock_ms := 0
var _timers: Array = []            ## [[due_ms, Callable], …] (window.setTimeout)

# high scores (lesson 09). highscores.php becomes a local list.
var high_scores: Array = []        ## [[score, level, name, age], …] sorted
var low_high_score := 100
var posted_scores := false
var player_score := 0              ## hidden #player_score field, filled at game over
var player_level := 1              ## hidden #player_level field
var score_store_path := "user://brickslayer_scores.cfg"


func _init(p_step: int = LAST_STEP, store_path: String = "") -> void:
	step = clampi(p_step, 0, LAST_STEP)
	if store_path != "":
		score_store_path = store_path
	init_game()


## Drop pending timeouts. Their lambdas hold a reference back to this object.
func dispose() -> void:
	_timers.clear()


func has(feature_step: int) -> bool:
	return step >= feature_step


## function initGame()
func init_game() -> void:
	if has(STEP_WORLD):
		_create_bricks()
	if has(STEP_HIGHSCORES):
		get_scores()
	if has(STEP_SCORING):
		game_reset()
	screen = "title" if has(STEP_SCREENS) else "game"


func _create_bricks() -> void:
	bricks.clear()
	# Collision tests run in array order, so the bottom row of each column comes first.
	for bx in 10:
		for by in range(4, -1, -1):
			bricks.append(Brick.new(bx * 39 + 8, by * 22 + 30, 5 - by))
	brick_count = bricks.size()


# ---- Console ------------------------------------------------------------

## One setInterval tick: fire due timeouts, then tick the current screen.
func tick() -> void:
	clock_ms += TICK_MS
	_run_timers()
	if screen == "game":
		_game_tick()


func swap(to_screen: String) -> void:
	screen = to_screen
	screen_changed.emit(screen)
	match screen:
		"clear":
			set_timeout(CLEARED_SPEED, func(): level_init(current_level + 1))
			schedule_swap("game", CLEARED_SPEED)
		"gameover":
			posted_scores = false
			player_score = score       # game_reset clears score before the name is entered
			player_level = current_level
			if has(STEP_HIGHSCORES):
				schedule_swap("congrats" if score > low_high_score else "scores")
			else:
				schedule_swap("title")
			set_timeout(SWAP_SPEED, game_reset)
		"scores":
			schedule_swap("title")


func schedule_swap(next: String, speed: int = SWAP_SPEED) -> void:
	var old := screen
	set_timeout(speed, func():
		if screen == old:
			swap(next))


func set_timeout(ms: int, fn: Callable) -> void:
	_timers.append([clock_ms + ms, fn])


func _run_timers() -> void:
	var due: Array = []
	for t in _timers:
		if t[0] <= clock_ms:
			due.append(t)
	for t in due:
		_timers.erase(t)
		t[1].call()


# ---- Keyboard -----------------------------------------------------------

func key_down(key: Key) -> void:
	match screen:
		"game":
			_game_key_down(key)
		"pause":
			if key == KEY_P:
				swap("game")


func key_up(key: Key) -> void:
	match screen:
		"game":
			if not has(STEP_ANIMATION):
				return
			if key == KEY_LEFT and paddle.velocity < 0:
				paddle.velocity = 0
			elif key == KEY_RIGHT and paddle.velocity > 0:
				paddle.velocity = 0
		"title", "scores":
			if key == KEY_ENTER or key == KEY_KP_ENTER:
				swap("game")


func _game_key_down(key: Key) -> void:
	match key:
		KEY_LEFT:
			if has(STEP_ANIMATION):
				paddle.velocity = -paddle.speed
			elif has(STEP_KEYBOARD):
				paddle.move_by(-10, 0)
		KEY_RIGHT:
			if has(STEP_ANIMATION):
				paddle.velocity = +paddle.speed
			elif has(STEP_KEYBOARD):
				paddle.move_by(+10, 0)
		KEY_UP:
			if has(STEP_COLLISION) and ball.on_paddle:
				serve(paddle.velocity + 0.25, SERVE_SPEED)
		KEY_P:
			if has(STEP_SCREENS):
				swap("pause")


# ---- Game screen --------------------------------------------------------

func _game_tick() -> void:
	if has(STEP_ANIMATION):
		_paddle_tick()
	if has(STEP_COLLISION):
		_ball_tick()


func _paddle_tick() -> void:
	if paddle.x + paddle.velocity <= 0:
		paddle.set_x(0)
	elif paddle.x + paddle.velocity + paddle.w >= W:
		paddle.set_x(W - paddle.w)
	else:
		paddle.move_by(paddle.velocity, 0)


func paddle_center() -> void:
	paddle.set_x(W / 2.0 - paddle.w / 2.0)
	paddle.velocity = 0


func stick_to_paddle() -> void:
	ball.set_x(paddle.x + paddle.w / 2.0 - ball.w / 2.0)
	ball.set_y(paddle.y - ball.h)
	ball.on_paddle = true


func serve(dx: float, dy: float) -> void:
	ball.on_paddle = false
	ball.dy = dy
	ball.move_by(0, -2)
	ball.dx = dx
	_play("serve")


func _ball_tick() -> void:
	if ball.on_paddle:
		stick_to_paddle()
		return
	# React separately from detection: two bricks hit at once must not
	# cancel each other's bounce.
	var vector = _smash_bricks()
	if vector != null:
		_bounce(vector)
	_check_paddle()
	_check_walls()
	if _hitting_floor():
		if has(STEP_SCORING):
			lose_life()
	else:
		ball.move_by(ball.dx, ball.dy)


func _smash_bricks():
	for b in bricks:
		if b.solid:
			var vector = collide(b)
			if vector != null:
				_brick_hit(b)
				if has(STEP_SCORING):
					score_inc()
				return vector      # can only hit one thing at a time
	return null


func _brick_hit(b: Brick) -> void:
	if b.shade - 1 <= 0:
		b.solid = false
		brick_count -= 1
		_play("break")
		if brick_count <= 0:
			if has(STEP_SCREENS):
				swap("clear")
			else:
				level_init(current_level + 1)
	else:
		b.shade -= 1
		_play("hit")


func _check_walls() -> void:
	if ball.x + ball.dx <= 0 or ball.x + ball.dx + ball.w >= W:
		ball.dx *= -1
		_play("bounce")
	if ball.y + ball.dy <= 0:
		ball.dy *= -1
		_play("bounce")


func _hitting_floor() -> bool:
	return ball.y + ball.dy + ball.h >= H


func _check_paddle() -> void:
	var vector = collide(paddle)
	if vector != null:
		_play("bounce")
		_bounce(vector)
		ball.dx += int(paddle.velocity * paddle.friction)   # parseInt truncates


func _bounce(vector: Array) -> void:
	ball.dx *= vector[0]
	ball.dy *= vector[1]


# ---- Ball physics (lesson 05) -------------------------------------------

## Ticks until the ball's path crosses the horizontal segment [x1,x2] at y=hline.
func ticks_to_hline(x1: float, x2: float, hline: float):
	var x: float
	if ball.dx == 0:
		x = ball.x
	else:
		x = (hline - ball.y) * (ball.dx / ball.dy) + ball.x
	if x < x1 or x > x2:
		return null
	var ticks := (hline - ball.y) / ball.dy
	return ticks if ticks >= 0 else null


## Ticks until the ball's path crosses the vertical segment x=vline, [y1,y2].
func ticks_to_vline(vline: float, y1: float, y2: float):
	if ball.dx == 0:
		return null
	var y := (ball.dy / ball.dx) * (vline - ball.x) + ball.y
	if y < y1 or y > y2:
		return null
	var ticks := (y - ball.y) / ball.dy
	return ticks if ticks >= 0 else null


## Returns [x_mult, y_mult] (BOUNCE/NO_BOUNCE) if the ball hits rect this tick.
func collide(rect: Sprite):
	var rect_left := float(rect.x)
	var rect_top := float(rect.y)
	var rect_right := rect_left + rect.w
	var rect_bottom := rect_top + rect.h
	var diameter := float(ball.w)
	var radius := diameter / 2.0
	var going_up := ball.dy < 0
	var going_left := ball.dx < 0

	var y_ticks = ticks_to_hline(rect_left - diameter, rect_right + radius,
			rect_bottom if going_up else rect_top - diameter)
	var x_ticks
	if going_left:
		x_ticks = ticks_to_vline(rect_right, rect_top - radius, rect_bottom + radius)
	else:
		x_ticks = ticks_to_vline(rect_left - diameter, rect_top - radius, rect_bottom + radius)

	var hit_x: bool = x_ticks != null and x_ticks <= 1
	var hit_y: bool = y_ticks != null and y_ticks <= 1
	if not (hit_x or hit_y):
		return null
	if x_ticks != null and y_ticks != null and x_ticks == y_ticks:
		hit_x = false              # treat corners as hitting the top or bottom
	return [BOUNCE if hit_x else NO_BOUNCE, BOUNCE if hit_y else NO_BOUNCE]


# ---- Scoring (lesson 06) ------------------------------------------------

func game_reset() -> void:
	score_set(0)
	level_init(1)
	balls_left = SPARES_START


func score_set(value: int) -> void:
	score = value


func score_inc() -> void:
	score_set(score + 1)


func level_init(level: int) -> void:
	for b in bricks:
		b.reset()
	brick_count = bricks.size()
	current_level = level
	paddle_center()
	stick_to_paddle()


func lose_life() -> void:
	_play("fall")
	if balls_left == 0:
		if has(STEP_SCREENS):
			swap("gameover")
		# before lesson 08 there is no game over: the ball just sits in the lake
	else:
		balls_left -= 1
		stick_to_paddle()


func _play(name: String) -> void:
	if has(STEP_SOUND):
		sound.emit(name)


# ---- High scores (lesson 09) --------------------------------------------
# highscores.php kept a text file on the server. Here the same list is
# kept in user://, seeded with the lesson's example file.

func get_scores() -> void:
	var stored := _load_store()
	high_scores.clear()
	for row in stored:
		high_scores.append([int(row[0]), int(row[1]), str(row[2]), "old"])
	_show_scores()


## post_score(): append, sort high-first, keep FILE_SIZE, then show the list.
func post_score(player_name: String) -> void:
	if posted_scores:
		return                     # prevent double post
	posted_scores = true
	var clean := " ".join(player_name.strip_edges().split(" ", false))
	var rows: Array = []
	for r in high_scores:
		rows.append([r[0], r[1], r[2], "old"])
	rows.append([player_score, player_level, clean, "new"])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	rows = rows.slice(0, SCORE_FILE_SIZE)
	high_scores = rows
	_save_store()
	_show_scores()
	swap("scores")


## Top LIST_SIZE rows; the lowest of them is the bar for the name screen.
func top_scores() -> Array:
	return high_scores.slice(0, SCORE_LIST_SIZE)


func _show_scores() -> void:
	var top := top_scores()
	if not top.is_empty():
		low_high_score = int(top[top.size() - 1][0])


func _load_store() -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(score_store_path) == OK:
		var rows = cfg.get_value("scores", "rows", [])
		if rows is Array and not rows.is_empty():
			return rows
	return SEED_SCORES.duplicate(true)


func _save_store() -> void:
	var cfg := ConfigFile.new()
	var rows: Array = []
	for r in high_scores:
		rows.append([r[0], r[1], r[2]])
	cfg.set_value("scores", "rows", rows)
	cfg.save(score_store_path)
