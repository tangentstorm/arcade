extends RefCounted
## Invader Sketch — Direct edition simulation.
## Faithful GDScript port of GameSketchLib course w02 `InvaderSketch.pde`, plus the
## tiny subset of GameSketchLib (`BaseGame.pde`) it relies on: GsTimer, GsObject/GsSprite,
## GsGroup update/overlap/removeDead/firstDead/atRandom, GsKeys justPressed, switchState.
##
## One step() == one Processing draw() frame. The original ran at Processing's default
## 60 fps with per-frame movement (px/frame) and millisecond timers, so the caller steps
## this at a fixed 60 Hz; timers see whole-millisecond frames (16,17,17 ms...).

const W := 640
const H := 480
const FPS := 60.0
const FRAME_MS := 1000.0 / FPS  ## nominal; step() uses whole-millisecond frames, see frame_ms()
const SECONDS := 1000.0
const CELL := 50  ## SHEET = new GsSpriteSheet("invaders.png", 50, 50, ...)

enum { MENU, PLAY, GAMEOVER, WIN }

## Game.bounds
const BOUNDS := Rect2(0, 0, W, H)


## Static helpers (inner classes can't call the outer script's static funcs).
class GsMath:
	## Processing's GsObject.overlaps(): strict inequalities on both axes.
	static func overlaps(a: Rect2, b: Rect2) -> bool:
		return a.position.x < b.end.x and a.end.x > b.position.x \
			and a.position.y < b.end.y and a.end.y > b.position.y

	## Java `int += float` compound assignment truncates toward zero.
	static func jint(v: float) -> int:
		return int(v)


# --- GsTimer ---------------------------------------------------------------
class GsTimer:
	var millis_per_tick := 0.0
	var millis_so_far := 0.0
	var ready := false
	var tick_count := 0

	func _init(p_millis: float, immediate := false) -> void:
		millis_per_tick = p_millis
		if immediate:
			millis_so_far = p_millis

	func update(frame_ms: float) -> void:
		ready = false
		millis_so_far += frame_ms
		if millis_so_far > millis_per_tick:
			ready = true
			millis_so_far = 0.0
			tick_count += 1

	func check_ready(frame_ms: float) -> bool:
		update(frame_ms)
		return ready

	func randomize(rng: RandomNumberGenerator) -> void:
		millis_so_far = rng.randf() * millis_per_tick


# --- GsSprite and the game's sprite classes ---------------------------------
class GsSprite:
	var kind := "sprite"
	var x := 0.0
	var y := 0.0
	var w := 0.0
	var h := 0.0
	var dx := 0.0
	var dy := 0.0
	var health := 1.0
	var alive := true
	var visible := true
	var active := true
	var exists := true
	var frames: Array = []   ## sheet cell indices (sheetFrames)
	var frame := 0
	var animated := true
	var timer := GsTimer.new(SECONDS / 8)
	var degrees := 0         ## int, like the original
	var rng: RandomNumberGenerator

	func _init(p_x: float, p_y: float, p_rng: RandomNumberGenerator) -> void:
		x = p_x
		y = p_y
		rng = p_rng

	func sheet_frames(nums: Array) -> void:
		frames = nums
		w = CELL  # sizeToFrame(): every cell is 50x50
		h = CELL

	func rect() -> Rect2:
		return Rect2(x, y, w, h)

	func update(frame_ms: float) -> void:
		if animated:
			timer.update(frame_ms)
			if timer.ready:
				frame = (frame + 1) % frames.size()

	func randomize() -> void:
		frame = int(rng.randf() * frames.size())
		timer.randomize(rng)

	## Collision rect used when this object is the *moving* side of an overlap.
	func overlaps(other: GsSprite) -> bool:
		return GsMath.overlaps(rect(), other.rect())

	## GsObject.hurt(). Returns true when this call killed it (onDeath ran).
	func hurt() -> bool:
		health -= 1
		if health <= 0:
			health = 0
			alive = false
			on_death()
			return true
		return false

	func on_death() -> void:
		visible = false

	func on_overlap(_other: GsSprite) -> void:
		pass

	func sheet_cell() -> int:
		return frames[frame]


class ShipInvader extends GsSprite:
	func _init(p_x: float, p_y: float, p_rng: RandomNumberGenerator) -> void:
		super(p_x, p_y, p_rng)
		kind = "ship"
		sheet_frames([1])


class SpinInvader extends GsSprite:
	var angle_delta := 2.5

	func _init(p_x: float, p_y: float, p_rng: RandomNumberGenerator) -> void:
		super(p_x, p_y, p_rng)
		kind = "spin"
		sheet_frames([2, 3])
		randomize()
		degrees = int(rng.randf_range(-60.0, 60.0))

	func update(frame_ms: float) -> void:
		super(frame_ms)
		degrees = GsMath.jint(degrees + angle_delta)
		if degrees > 60 or degrees < -60:
			angle_delta *= -1


class JellInvader extends GsSprite:
	var y_drift := 0.0

	func _init(p_x: float, p_y: float, p_rng: RandomNumberGenerator) -> void:
		super(p_x, p_y, p_rng)
		kind = "jell"
		sheet_frames([8, 9, 10, 11])
		randomize()
		dy = 1
		y_drift = rng.randf_range(-10.0, 10.0)
		y += y_drift

	func update(frame_ms: float) -> void:
		super(frame_ms)
		y += dy
		y_drift += dy
		if y_drift > 10 or y_drift < -10:
			dy *= -1


class Shield extends GsSprite:
	func _init(p_x: float, p_y: float, p_rng: RandomNumberGenerator) -> void:
		super(p_x, p_y, p_rng)
		kind = "shield"
		sheet_frames([12, 13, 14])
		animated = false
		health = 3

	func hurt() -> bool:
		var died := super()
		if alive:
			frame += 1
		return died


class HeroSprite extends GsSprite:
	func _init(p_x: float, p_y: float, p_rng: RandomNumberGenerator) -> void:
		super(p_x, p_y, p_rng)
		kind = "hero"
		sheet_frames([0])
	# onDeath() -> Game.switchState(new GameOverState()) is done by the world
	# when hurt() reports the hero died (see PlayWorld._overlap).


class Bullet extends GsSprite:
	var true_bounds := Rect2()  ## new GsObject(): (0,0,0,0) until the first update()

	func _init(p_x: float, p_y: float, p_rng: RandomNumberGenerator) -> void:
		super(p_x, p_y, p_rng)
		kind = "bullet"
		sheet_frames([4])
		alive = false

	func update(_frame_ms: float) -> void:
		if alive:
			y += dy
			x += dx
		true_bounds = Rect2(x + 20, y + 20, 10, 15)
		if not GsMath.overlaps(true_bounds, BOUNDS):
			alive = false

	func fire(p_x: float, p_y: float) -> void:
		x = p_x
		y = p_y
		alive = true

	func overlaps(other: GsSprite) -> bool:
		return GsMath.overlaps(true_bounds, other.rect())

	func overlaps_rect(r: Rect2) -> bool:
		return GsMath.overlaps(true_bounds, r)

	func on_overlap(_other: GsSprite) -> void:
		alive = false
		# other.hurt() is called by the world so it can see the hero's death.


class EnemyBullet extends Bullet:
	func _init(p_x: float, p_y: float, p_rng: RandomNumberGenerator) -> void:
		super(p_x, p_y, p_rng)
		kind = "enemy_bullet"
		sheet_frames([5])
		alive = true


# --- World / states ---------------------------------------------------------
const HERO_SPEED := 3.5
const BULLET_COUNT := 3
const BULLET_SPEED := -1.75
const BULLET_W := 10
const BULLET_H := 50
const SHIELD_XS := [50, 100, 150, 250, 300, 350, 450, 500, 550]

var rng := RandomNumberGenerator.new()
var state := MENU
var _pending := -1

# MenuState: CrazyText colour (starts #FFFFFF, re-rolled every SECONDS/10)
var crazy_color := Color.WHITE
var _crazy_timer := GsTimer.new(SECONDS / 10)

# PlayState fields
var invaders: Array = []
var ship_invaders: Array = []
var hero_bullets: Array = []
var enemy_bullets: Array = []
var shields: Array = []
var hero_group: Array = []
var hero: HeroSprite
var bullets_left := BULLET_COUNT
var _shift_timer := GsTimer.new(0.1 * SECONDS)
var drift_x := 0
var fleet_speed_x := 2
var fleet_speed_y := 10
var _enemy_shot_timer := GsTimer.new(4 * SECONDS, true)
var frames_played := 0
var frame_count := 0  ## global frame clock (Processing millis() is whole ms)
var _frame_ms := 16.0


func _init(start_state := MENU, seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	switch_state(start_state)
	_apply_pending()


## Game.switchState(). The original swapped Game.state immediately but the
## caller's update() kept running, so the last switch in a frame wins.
func switch_state(s: int) -> void:
	_pending = s


func _apply_pending() -> void:
	if _pending < 0:
		return
	state = _pending
	_pending = -1
	match state:
		MENU:
			crazy_color = Color.WHITE
			_crazy_timer = GsTimer.new(SECONDS / 10)
		PLAY:
			_create_play()


## PlayState.create()
func _create_play() -> void:
	invaders = []
	ship_invaders = []
	hero_bullets = []
	enemy_bullets = []
	shields = []
	hero_group = []
	bullets_left = BULLET_COUNT
	_shift_timer = GsTimer.new(0.1 * SECONDS)
	drift_x = 0
	fleet_speed_x = 2
	fleet_speed_y = 10
	_enemy_shot_timer = GsTimer.new(4 * SECONDS, true)
	frames_played = 0

	hero = HeroSprite.new(W / 2 - 25, H - 50, rng)
	hero_group.append(hero)

	for i in BULLET_COUNT:
		var b := Bullet.new(0, 0, rng)
		b.dy = BULLET_SPEED
		hero_bullets.append(b)

	var row := 0
	var y := 25
	while y < H - 100:
		var x := 65
		while x < W - 50:
			match row:
				0:
					var s := ShipInvader.new(x, y, rng)
					ship_invaders.append(s)
					invaders.append(s)
				1, 3:
					invaders.append(SpinInvader.new(x, y, rng))
				2:
					invaders.append(JellInvader.new(x, y, rng))
				_:
					pass  # only do 4 rows
			x += 75
		y += 75
		row += 1

	for sx in SHIELD_XS:
		shields.append(Shield.new(sx, H - 125, rng))


## Draw order of the PlayState's groups (bullets first so they appear behind).
func render_groups() -> Array:
	return [hero_bullets, enemy_bullets, hero_group, shields, invaders]


## One frame. input: {"just": Array of "space"/"r", "left": bool, "right": bool}
func step(input: Dictionary) -> void:
	var just: Array = input.get("just", [])
	# Game.frameMillis = millis() - lastMillis; at 60 fps millis() advances 16,17,17,...
	_frame_ms = float(int((frame_count + 1) * 1000 / 60) - int(frame_count * 1000 / 60))
	frame_count += 1
	match state:
		MENU:
			if _crazy_timer.check_ready(_frame_ms):
				crazy_color = Color8(127 + int(rng.randf() * 127),
						127 + int(rng.randf() * 127), 127 + int(rng.randf() * 127))
			if just.has("space"):
				switch_state(PLAY)
		GAMEOVER, WIN:
			if just.has("space"):
				switch_state(MENU)
		PLAY:
			_update_play(input, just)
	_apply_pending()


func _update_play(input: Dictionary, just: Array) -> void:
	frames_played += 1
	# super.update(): GsGroup.update over the state's members, in add() order.
	for g in render_groups():
		for o in g:
			if o.exists and o.active:
				o.update(_frame_ms)

	if just.has("space"):
		shoot()
	if input.get("left", false):
		hero.x -= HERO_SPEED
	if input.get("right", false):
		hero.x += HERO_SPEED
	hero.x = clampf(hero.x, 0, W - hero.w)

	# debug key from the original: spin a random ship invader
	# (the original NPE'd here once every ship was dead; we just skip)
	if just.has("r") and not ship_invaders.is_empty():
		var g: GsSprite = _at_random(ship_invaders)
		g.degrees = int(rng.randf() * 360)

	_update_hero_bullets()
	_update_invaders()
	_enemy_fire()
	_update_shields()

	# checkForWin
	if _first_alive(invaders) == null:
		switch_state(WIN)


func shoot() -> void:
	if bullets_left > 0:
		bullets_left -= 1
		var b: Bullet = _first_dead(hero_bullets)
		b.fire(hero.x, hero.y)


func _update_hero_bullets() -> void:
	_overlap(hero_bullets, invaders)
	_overlap(hero_bullets, shields)
	var left := 0
	for i in BULLET_COUNT:
		var b: Bullet = hero_bullets[i]
		b.update(_frame_ms)  # second update this frame, as in the original
		if not b.overlaps_rect(BOUNDS):
			b.alive = false
		if not b.alive:
			b.x = BULLET_W * left
			left += 1
			b.y = H - BULLET_H
	bullets_left = left


func _update_invaders() -> void:
	_remove_dead(invaders)
	_remove_dead(ship_invaders)
	_shift_timer.update(_frame_ms)
	if _shift_timer.ready:
		for g in invaders:
			g.x += fleet_speed_x
		drift_x += fleet_speed_x
		if drift_x > 50 or drift_x < -50:
			fleet_speed_x *= -1
			for g in invaders:
				g.y += fleet_speed_y
				# game over if one gets within 100px of the bottom
				if g.y >= H - g.h * 2:
					switch_state(GAMEOVER)


func _enemy_fire() -> void:
	_remove_dead(enemy_bullets)
	_overlap(enemy_bullets, hero_group)
	_overlap(enemy_bullets, shields)
	# only the orange ships at the top shoot
	if ship_invaders.is_empty():
		return
	if _enemy_shot_timer.check_ready(_frame_ms):
		_enemy_shot_timer.randomize(rng)
		if _enemy_shot_timer.tick_count == 1:
			return  # wait a bit to start shooting
		var ship: GsSprite = _at_random(ship_invaders)
		var b := EnemyBullet.new(ship.x, ship.y, rng)
		b.dy = -BULLET_SPEED
		enemy_bullets.append(b)


func _update_shields() -> void:
	_remove_dead(shields)


# --- GsGroup helpers ---------------------------------------------------------
func _overlap(group: Array, other: Array) -> void:
	for a in group:
		if a.active and a.exists:
			for b in other:
				if b.active and b.exists and a != b and a.overlaps(b):
					a.on_overlap(b)
					if b.hurt() and b is HeroSprite:
						switch_state(GAMEOVER)  # HeroSprite.onDeath()


func _first_dead(group: Array):
	for o in group:
		if not o.alive:
			return o
	return null


func _first_alive(group: Array):
	for o in group:
		if o.alive:
			return o
	return null


func _remove_dead(group: Array) -> void:
	var i := 0
	while i < group.size():
		if not group[i].alive:
			group.remove_at(i)
		else:
			i += 1


func _at_random(group: Array):
	if group.is_empty():
		return null
	return group[int(rng.randf() * group.size())]
