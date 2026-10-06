extends "res://games/brickslayer/direct/brickslayer_logic.gd"
## Brickslayer (Enhanced) rules. This extends the Direct logic, so the wall,
## the lesson-05 collision math, the 10 ms tick, serve speed, +1 per hit,
## 3 spares and level clear all stay exactly as in Direct.
##
## What it changes:
## - Game over waits for the player (no timed hop to the name entry or score
##   list). A run's best score is kept in `best`; game.gd saves it.
## - Events (`take_events()`) for the view: brick hit/break, paddle and wall
##   bounces, a ball lost in the lake, serve, screen changes.
## - Held-key steering (`set_held`) so left+right never cancel wrongly, and an
##   optional pointer target (`pointer_x`) for mouse/touch. The pointer moves
##   the paddle through `paddle.velocity`, capped at paddle.speed, so the
##   Direct paddle "english" (parseInt(velocity * friction)) still applies.

const RESTART_LOCK_MS := 600

var best := 0
var new_best := false
var pointer_x := NAN                ## logical x the paddle center chases; NAN = keys only
var _held_left := false
var _held_right := false
var _events: Array[Dictionary] = []
var _over_at_ms := 0


func _init(store_path: String = "") -> void:
	super(LAST_STEP, store_path)


## The Direct high-score list is not used here (game.gd keeps a best score).
func get_scores() -> void:
	pass


func take_events() -> Array[Dictionary]:
	var out := _events
	_events = []
	return out


func _emit(type: StringName, data: Dictionary = {}) -> void:
	data["type"] = type
	_events.append(data)


# ---- screens --------------------------------------------------------------

func swap(to_screen: String) -> void:
	if to_screen == "gameover":
		screen = to_screen
		player_score = score
		player_level = current_level
		new_best = score > best
		best = maxi(best, score)
		_over_at_ms = clock_ms
		_emit(&"screen", {"screen": screen})
		screen_changed.emit(screen)
		return
	super(to_screen)
	_emit(&"screen", {"screen": screen})


## Start from the title, or restart after game over (after a short lockout).
func start() -> bool:
	match screen:
		"title":
			swap("game")
			return true
		"gameover":
			if not can_restart():
				return false
			new_best = false
			game_reset()
			swap("game")
			return true
	return false


func can_restart() -> bool:
	return screen == "gameover" and clock_ms - _over_at_ms >= RESTART_LOCK_MS


func toggle_pause() -> void:
	if screen == "game":
		swap("pause")
	elif screen == "pause":
		swap("game")


# ---- input ------------------------------------------------------------------

func set_held(left: bool, right: bool) -> void:
	_held_left = left
	_held_right = right
	if left or right:
		pointer_x = NAN
	if screen == "game":
		paddle.velocity = (int(right) - int(left)) * paddle.speed


func try_serve() -> void:
	if screen == "game" and ball.on_paddle:
		serve(paddle.velocity + 0.25, SERVE_SPEED)


func _paddle_tick() -> void:
	if _held_left or _held_right:
		paddle.velocity = (int(_held_right) - int(_held_left)) * paddle.speed
	elif not is_nan(pointer_x):
		var delta := pointer_x - (paddle.x + paddle.w / 2.0)
		paddle.velocity = clampf(roundf(delta), -paddle.speed, paddle.speed)
	super()


# ---- events on top of the Direct rules ---------------------------------------

func serve(dx: float, dy: float) -> void:
	super(dx, dy)
	_emit(&"serve", {"pos": _ball_center()})


func _brick_hit(b: Brick) -> void:
	var shade_before := b.shade
	var idx := bricks.find(b)
	var center := Vector2(b.x + b.w / 2.0, b.y + b.h / 2.0)
	super(b)
	if b.solid:
		_emit(&"brick_hit", {"index": idx, "pos": center, "shade": shade_before})
	else:
		_emit(&"brick_break", {"index": idx, "pos": center, "shade": shade_before})


func _check_paddle() -> void:
	var vector = collide(paddle)
	if vector != null:
		_play("bounce")
		_bounce(vector)
		ball.dx += int(paddle.velocity * paddle.friction)   # parseInt truncates
		_emit(&"paddle", {"pos": _ball_center()})


func _check_walls() -> void:
	if ball.x + ball.dx <= 0 or ball.x + ball.dx + ball.w >= W:
		ball.dx *= -1
		_play("bounce")
		_emit(&"wall", {"pos": _ball_center()})
	if ball.y + ball.dy <= 0:
		ball.dy *= -1
		_play("bounce")
		_emit(&"wall", {"pos": _ball_center()})


func lose_life() -> void:
	_emit(&"lost", {"pos": _ball_center(), "last": balls_left == 0})
	super()


func _ball_center() -> Vector2:
	return Vector2(ball.x + ball.w / 2.0, ball.y + ball.h / 2.0)
