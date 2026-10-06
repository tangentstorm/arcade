extends RefCounted
## Cupid: Direct edition simulation (no rendering).
## A port of tangentstorm/cupid's GameState.as and friends (AS3 + Flixel v1, 2010).
## One step() is one Flixel frame. FlxGame pins stage.frameRate at 90, so this runs
## at a fixed 90 Hz with FlxG.elapsed = 1/90. Units are the 656x350 Flash stage.
##
## Coordinates follow Flixel: `scroll_x` is FlxG.scroll.x (zero or negative), and
## a sprite's screen x is floor(x) + floor(scroll_x * scrollFactor).

enum { TITLE, PLAY, WON }

const FPS := 90
const DT := 1.0 / FPS

# --- Const.as ---
const STAGE_W := 656
const STAGE_H := 350
const GAME_W := 1800
const PERSON_HEIGHT := 90
const BUBBLE_HEIGHT := 55
const NUM_COUPLES := 5
const SYMBOL_OFFSET_X := 15
const SYMBOL_OFFSET_Y := 5
const HEAVY_RAIN := 500
const RAIN_SCROLL_FACTOR := 0.33
const AVG_WALK_SPEED := 1.25
const ARROW_SPEED := 500.0
const BUBBLE_DURATION := 1.5  # 1500 ms
const MATCH_ICON_SIZE := 40
const CUPID_START_X := 300
const CUPID_START_Y := 55
const ARROW_START_XOFF := 42
const ARROW_START_YOFF := 72
const BG_SCROLL := [0.0, 0.2, 0.4, 0.6, 0.8]
const BG_LEVELS := 5  # Const.BG_TINTS.length (every tint is 0xFFFFFF)

# --- sprite sizes (Flixel loadGraphic: animated frames are height x height) ---
const CUPID_W := 72
const CUPID_H := 72
const PERSON_W := 100
const PERSON_H := 100
const ARROW_W := 6
const ARROW_H := 28
const RAIN_SIZE := 128
const RAIN_FRAMES := 4  # heavy-rain.png is 512x128

# --- Cupid.as ---
const CUPID_SPEED := 2.5
# --- Music.as ---
const FLX_VOLUME := 0.7
const RAIN_VOLUME := 0.5
const RAIN_STEP := 0.1

# --- FlxEmitter defaults as Storm.as configures them ---
const RAIN_EMIT_X := 0.0
const RAIN_EMIT_Y := -100.0
const RAIN_VX := 20.0      # setXVelocity(20, 20)
const RAIN_VY_MIN := -100.0  # default minVelocity.y
const RAIN_VY_MAX := 100.0   # default maxVelocity.y
const RAIN_GRAVITY := 400.0  # default gravity


## FlxSprite's animation player, including the addAnimationCallback hook that
## fires from calcFrame() every time the frame is recalculated.
class Anim:
	var anims := {}
	var name := ""
	var cur := 0
	var caf := 0
	var timer := 0.0
	var finished := false
	var callback: Callable

	func add(n: String, frames: Array, fps: float, looped: bool) -> void:
		anims[n] = {"frames": frames, "delay": 1.0 / fps if fps > 0 else 0.0, "looped": looped}

	func play(n: String, force := false) -> void:
		if not force and name == n:
			return
		cur = 0
		timer = 0.0
		name = n
		var a: Dictionary = anims[n]
		finished = a.delay <= 0
		caf = a.frames[0]
		_calc()

	func _calc() -> void:
		if callback.is_valid():
			callback.call(name, cur, caf)

	func update(dt: float) -> void:
		if name == "":
			return
		var a: Dictionary = anims[name]
		if a.delay > 0 and (a.looped or not finished):
			timer += dt
			if timer > a.delay:
				timer -= a.delay
				if cur == a.frames.size() - 1:
					if a.looped:
						cur = 0
					finished = true
				else:
					cur += 1
				caf = a.frames[cur]
				_calc()


class Person:
	var x := 0.0
	var y := float(STAGE_H - PERSON_HEIGHT)
	var image := 0         # frame in pixel-people-standins-gray.png
	var symbol := 0        # frame in symbols.png
	var right := true      # facing
	var speed := 0.0
	var stopped := false
	var exists := true
	var marked := false    # bubble + symbol + glow mask visible
	var mark_x := 0.0      # where the bubble/mask were placed (onArrow)
	var mark_right := true


class MatchIcon:
	var good := true
	var visible := false
	var last_frame := 6
	var anim := Anim.new()
	var owner_ref: WeakRef

	func _init(p_good: bool, owner) -> void:
		good = p_good
		owner_ref = weakref(owner)
		if good:
			last_frame = 6
			anim.add("good", [0, 1, 2, 3, 4, 5, 6], 12, false)
		else:
			last_frame = 8
			anim.add("bad", [0, 1, 2, 3, 4, 5, 6, 7, 8], 12, false)
		anim.callback = _on_frame

	func which() -> String:
		return "good" if good else "bad"

	func show() -> void:
		visible = true
		owner_ref.get_ref().icon_showing = true
		anim.play(which(), true)

	func _on_frame(_n: String, _num: int, index: int) -> void:
		if visible and index == last_frame:
			owner_ref.get_ref().icon_showing = false
			anim.finished = true
			# this.visible = false;  (commented out in the original, so the icon stays up)


var rng := RandomNumberGenerator.new()
var state := TITLE
var f := 0  # frames since the game started

var scroll_x := 0.0
var scroll_y := 0.0

# cupid
var cx := float(CUPID_START_X)
var cy := float(CUPID_START_Y)
var cvx := 0.0
var c_right := true
var cupid_anim := Anim.new()

# arrow
var arrow_exists := false
var ax := 0.0
var ay := 0.0

var people: Array[Person] = []
var last_hit: Person = null
var couples_left := NUM_COUPLES
var level := -1
var music_level := 0
var rain_volume := RAIN_VOLUME
var clouds_left := NUM_COUPLES
var won := false

var good_icon: MatchIcon
var bad_icon: MatchIcon
var icon_showing := false  # MatchIcon.showing (static)
var timers: Array = []     # pending flash.utils.Timer callbacks: {t, good, p1, p2}

# rain: NUM_COUPLES emitters x HEAVY_RAIN recycled particles
var rain_x := PackedFloat32Array()
var rain_y := PackedFloat32Array()
var rain_vy := PackedFloat32Array()
var rain_frame := PackedByteArray()
var rain_alive := PackedByteArray()
var rain_next := PackedInt32Array()

var mouse_x := 0.0  # FlxG.mouse.x: world coordinates
var mouse_y := 0.0


func _init(start_state := TITLE, seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	if start_state == PLAY:
		new_game()
	else:
		state = TITLE


func random() -> float:
	return rng.randf()


## GameState() constructor.
func new_game() -> void:
	state = PLAY
	f = 0
	won = false
	level = -1
	music_level = 0
	rain_volume = RAIN_VOLUME
	timers.clear()
	last_hit = null
	icon_showing = false
	arrow_exists = false

	cx = CUPID_START_X
	cy = CUPID_START_Y
	cvx = 0.0
	c_right = true
	cupid_anim = Anim.new()
	cupid_anim.add("flight", [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], 12, true)
	cupid_anim.add("shoot", [10, 11, 12, 10], 12, true)
	cupid_anim.callback = _on_cupid_frame
	cupid_anim.play("flight")

	# MatchMaker: symbols are 0..NUM_COUPLES-1, shuffled; matches are a shuffled copy.
	var symbols: Array = []
	while symbols.size() < NUM_COUPLES:
		symbols.append(symbols.size())
	shuffle(symbols)
	var matches: Array = symbols.duplicate()
	shuffle(matches)

	couples_left = NUM_COUPLES
	people.clear()
	for i in NUM_COUPLES:
		people.append(_make_person(symbols[i], i))
		people.append(_make_person(matches[i], i + NUM_COUPLES))
	var dist := int(GAME_W / float(NUM_COUPLES * 2 + 1))
	shuffle(people)
	for i in people.size():
		people[i].x = (i + 1) * dist

	# FlxG.follow(cupid, 1); followAdjust(0.5, 0); followBounds(0, 0, GAME_W, STAGE_H)
	scroll_x = (STAGE_W >> 1) - cx - (CUPID_W >> 1)
	scroll_y = (STAGE_H >> 1) - cy - (CUPID_H >> 1)
	_follow(0.0)

	good_icon = MatchIcon.new(true, self)
	bad_icon = MatchIcon.new(false, self)

	clouds_left = NUM_COUPLES
	var n := NUM_COUPLES * HEAVY_RAIN
	rain_x.resize(n)
	rain_y.resize(n)
	rain_vy.resize(n)
	rain_frame.resize(n)
	rain_alive.resize(n)
	rain_alive.fill(0)
	rain_next.resize(NUM_COUPLES)
	rain_next.fill(0)
	for i in n:
		rain_frame[i] = int(random() * RAIN_FRAMES)  # createSprites: s.randomFrame()


func _make_person(symbol: int, image: int) -> Person:
	var p := Person.new()
	p.image = image
	p.symbol = symbol
	p.right = random() <= 0.5  # (Math.random() > 0.5) ? LEFT : RIGHT
	var speed_change := floori(5.0 * (random() - 0.5))
	p.speed = AVG_WALK_SPEED + speed_change * 0.10
	return p


## MatchMaker.shuffle: length*10 random swaps.
func shuffle(arr: Array) -> void:
	for i in arr.size() * 10:
		var a := floori(random() * arr.size())
		var b := floori(random() * arr.size())
		var tmp = arr[b]
		arr[b] = arr[a]
		arr[a] = tmp


func _on_cupid_frame(n: String, _num: int, _index: int) -> void:
	if cupid_anim.finished and n == "shoot":
		cupid_anim.play("flight")


## FlxG.doFollow with followLerp 1, followLead (0.5, 0), followBounds(0, 0, GAME_W, STAGE_H).
func _follow(dt: float) -> void:
	if dt > 0:
		var tx := (STAGE_W >> 1) - cx - (CUPID_W >> 1) - cvx * 0.5
		var ty := (STAGE_H >> 1) - cy - (CUPID_H >> 1)
		scroll_x += (tx - scroll_x) * 1.0 * dt
		scroll_y += (ty - scroll_y) * 1.0 * dt
	scroll_x = minf(scroll_x, 0.0)
	scroll_y = minf(scroll_y, 0.0)
	scroll_x = maxf(scroll_x, float(STAGE_W - GAME_W))
	scroll_y = maxf(scroll_y, float(STAGE_H - STAGE_H))


## input: stage_x/stage_y (mouse on the 656x350 stage), click (mouse just
## pressed), start (Space just pressed), next_level (N just pressed).
func step(input: Dictionary = {}) -> void:
	var sx: float = input.get("stage_x", mouse_x + scroll_x)
	var sy: float = input.get("stage_y", mouse_y + scroll_y)
	if state == TITLE:
		# MenuState: FlxG.keys.justPressed("SPACE") -> GameState
		if input.get("start", false) or input.get("click", false):
			new_game()
			mouse_x = sx - scroll_x
			mouse_y = sy - scroll_y
		return
	if state == WON and input.get("start", false):
		new_game()
		return

	f += 1
	# FlxG.updateInput(): mouse is in world space
	mouse_x = sx - scroll_x
	mouse_y = sy - scroll_y
	_follow(DT)
	_tick_timers()

	# super.update(): bg layers, lyrSprites (cupid, people, arrow), lyrRain, lyrHUD
	_update_cupid()
	for p in people:
		if p.exists:
			_update_person(p)
	_update_arrow()
	_update_rain()
	good_icon.anim.update(DT)
	bad_icon.anim.update(DT)

	_emit_rain()  # storm.emit()

	if input.get("next_level", false):
		next_level()

	if arrow_exists:
		_overlap_people()
	elif input.get("click", false):
		_on_click()


func _update_cupid() -> void:
	var dx := int(mouse_x - cx)
	cvx = dx * CUPID_SPEED
	if dx > 0:
		c_right = true
	elif dx < 0:
		c_right = false
	cupid_anim.update(DT)
	cx += cvx * DT


func _update_person(p: Person) -> void:
	if p.stopped:
		return
	# randomly turn around .2% of the time
	if random() > 0.998:
		p.right = not p.right
	if p.right:
		p.x += p.speed
		if p.x + PERSON_W >= GAME_W:
			p.x = GAME_W - PERSON_W
			p.right = false
	else:
		p.x -= p.speed
		if p.x <= 0:
			p.x = 0
			p.right = true


func _update_arrow() -> void:
	if not arrow_exists:
		return
	if ay >= STAGE_H:
		arrow_exists = false
	else:
		ay += ARROW_SPEED * DT


func _emit_rain() -> void:
	for c in clouds_left:
		var i := c * HEAVY_RAIN + rain_next[c]
		rain_x[i] = RAIN_EMIT_X - (RAIN_SIZE >> 1) + random() * GAME_W
		rain_y[i] = RAIN_EMIT_Y - (RAIN_SIZE >> 1) + random() * 0.0
		rain_vy[i] = RAIN_VY_MIN + random() * (RAIN_VY_MAX - RAIN_VY_MIN)
		rain_alive[i] = 1
		rain_next[c] = (rain_next[c] + 1) % HEAVY_RAIN


func _update_rain() -> void:
	# Particles keep falling forever in the original; once a drop's top edge is
	# below the stage it can never be seen again (gravity only pulls down), so
	# it's retired instead of simulated.
	for i in rain_alive.size():
		if rain_alive[i] == 0:
			continue
		rain_vy[i] += RAIN_GRAVITY * DT
		rain_x[i] += RAIN_VX * DT
		rain_y[i] += rain_vy[i] * DT
		if rain_y[i] >= STAGE_H:
			rain_alive[i] = 0


func rain_count() -> int:
	var n := 0
	for a in rain_alive:
		n += a
	return n


## Where the last shot's arrow x came from (test helper): cupid.x at the click.
var _shot_cx := 0.0
func cx_prev_shot() -> float:
	return _shot_cx + ARROW_START_XOFF


func _on_click() -> void:
	if icon_showing:
		return
	cupid_anim.play("shoot", true)
	_shot_cx = cx
	var arrow_x: int
	if c_right:
		arrow_x = int(cx + ARROW_START_XOFF)
	else:
		arrow_x = int(cx + CUPID_W - ARROW_START_XOFF)
	arrow_exists = true
	ax = arrow_x
	ay = int(cy + ARROW_START_YOFF)


## FlxG.overlapArray(people, arrow, onCollision) with FlxCore.overlaps.
func _overlap_people() -> void:
	for p in people:
		if not arrow_exists:
			return
		if not p.exists:
			continue
		if (ax <= p.x - ARROW_W) or (ax >= p.x + PERSON_W) or (ay <= p.y - ARROW_H) or (ay >= p.y + PERSON_H):
			continue
		_on_collision(p)


func _on_collision(person: Person) -> void:
	if not arrow_exists:
		return
	arrow_exists = false
	if person.stopped:
		return
	_on_arrow(person)
	if last_hit == null:
		last_hit = person
		return
	var good := person.symbol == last_hit.symbol
	if good:
		next_level()
		good_icon.show()
	else:
		bad_icon.show()
	timers.append({"t": BUBBLE_DURATION, "good": good, "p1": person, "p2": last_hit})
	last_hit = null


func _tick_timers() -> void:
	var due: Array = []
	for t in timers:
		t.t -= DT
		if t.t <= 0:
			due.append(t)
	for t in due:
		timers.erase(t)
		if t.good:
			_good_match(t.p1, t.p2)
		else:
			_resume(t.p1)
			_resume(t.p2)


func _on_arrow(p: Person) -> void:
	p.stopped = true
	p.marked = true
	p.mark_x = p.x
	p.mark_right = p.right


func _resume(p: Person) -> void:
	p.stopped = false
	p.marked = false


func _good_match(p1: Person, p2: Person) -> void:
	p1.marked = false
	p1.exists = false
	p2.marked = false
	p2.exists = false
	couples_left -= 1
	if couples_left == 0:
		won = true
		state = WON


func next_level() -> void:
	level += 1
	if level >= BG_LEVELS:
		level = 0
	# tintBackgrounds(): every BG_TINTS entry is 0xFFFFFF, so it's a no-op.
	# music.nextLevel()
	music_level += 1
	if music_level == 6:
		music_level = 0
		rain_volume = RAIN_VOLUME
	else:
		rain_volume -= RAIN_STEP
	# storm.nextLevel()
	clouds_left -= 1


## Effective rain loop volume (FlxG.volume * rainLoop.volume), clamped at 0.
func rain_gain() -> float:
	return maxf(0.0, FLX_VOLUME * rain_volume) if state != TITLE else 0.0


func remaining() -> int:
	var n := 0
	for p in people:
		if p.exists:
			n += 1
	return n
