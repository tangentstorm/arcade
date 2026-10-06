extends RefCounted
## GameSketchLibDemo: a line-for-line port of
## course/w02_InvaderSketch/demos/GameSketchLibDemo/GameSketchLibDemo.pde.
## This is BulletDemo rebuilt on a mini flixel-style library (GameBasic, GameObject, GameGroup,
## GameState, Game.switchState) with a click-to-start menu. Clearing all nine squares returns
## to the menu.
## step() is one Processing draw() frame. render() returns the frame as a draw list.

const W := 300
const H := 300
const FPS := 60

const MENU_BG := Color("#000000")
const PLAY_BG := Color("#3366FF")
const LIVE := Color("#FFFFFF")
const DEAD := Color("#CCCCCC")
const BULLET := Color("#FFCC33")
const TEXT := Color("#FFFFFF")

const K_BULLET_W := 10
const K_BULLET_H := 20
const K_BULLET_COUNT := 3
const K_BULLET_SPEED := -3.75

enum State { MENU, PLAY }


## GameBasic + GameObject + Rectangle (Square / Bullet differ only in colours and update()).
class Obj:
	var visible := true
	var active := true
	var exists := true
	var alive := true
	var x := 0.0
	var y := 0.0
	var w := 0.0
	var h := 0.0
	var dx := 0.0
	var dy := 0.0
	var live_color := Color("#FFFFFF")
	var dead_color := Color("#CCCCCC")
	var is_bullet := false

	func _init(px: float, py: float, pw: float, ph: float) -> void:
		x = px
		y = py
		w = pw
		h = ph

	func x2() -> float:
		return x + w

	func y2() -> float:
		return y + h

	func overlaps(that: Obj) -> bool:
		return x < that.x2() and x2() > that.x and y < that.y2() and y2() > that.y

	## Bullet.update(). Squares inherit GameBasic's empty update().
	func update() -> void:
		if is_bullet and alive:
			y += dy
			x += dx

	func fire(px: float, py: float) -> void:
		x = px
		y = py
		alive = true

	## Bullet.onOverlap(). Only bullets ever call it.
	func on_overlap(other: Obj) -> void:
		alive = false
		other.alive = false


var state := State.MENU
var bg := MENU_BG
var squares: Array[Obj] = []
var bullets: Array[Obj] = []
var bounds := Obj.new(0, 0, W, H)


func _init() -> void:
	switch_state(State.MENU)


## Game.switchState(new XState()): a fresh state, then create().
func switch_state(s: State) -> void:
	state = s
	squares = []
	bullets = []
	bg = MENU_BG
	if s == State.PLAY:
		for i in 3:
			for j in 3:
				squares.append(Obj.new(75 * i + 50, 75 * j + 50, 25, 25))
		for i in K_BULLET_COUNT:
			var b := Obj.new(0, 0, K_BULLET_W, K_BULLET_H)
			b.is_bullet = true
			b.alive = false
			b.live_color = BULLET
			b.dead_color = BULLET
			b.dy = K_BULLET_SPEED
			bullets.append(b)
		bg = PLAY_BG


## GameGroup.overlap(): checks active/exists, never alive. Dead squares stay active,
## so they still soak up bullets.
func _overlap(group_a: Array[Obj], group_b: Array[Obj]) -> void:
	for a in group_a:
		if a.active and a.exists:
			for b in group_b:
				if b.active and b.exists and a != b and a.overlaps(b):
					a.on_overlap(b)


func _first_alive(group: Array[Obj]) -> Obj:
	for o in group:
		if o.alive:
			return o
	return null


func _first_dead(group: Array[Obj]) -> Obj:
	for o in group:
		if not o.alive:
			return o
	return null


## PlayState.update() (MenuState inherits GameGroup.update() over its one GameText: a no-op).
func step() -> void:
	if state != State.PLAY:
		return
	_overlap(bullets, squares)
	var left := 0
	for b in bullets:
		b.update()
		if not b.overlaps(bounds):
			b.alive = false
		if not b.alive:
			b.x = K_BULLET_W * left
			left += 1
			b.y = H - K_BULLET_H
	if _first_alive(squares) == null:
		switch_state(State.MENU)


func render() -> Array:
	var out: Array = [["bg", bg]]
	if state == State.MENU:
		# new GameText("BulletDemo! Click to start.", 10, 50, #FFFFFF, 16), textAlign(LEFT)
		out.append(["text", "BulletDemo! Click to start.", Vector2(10, 50), 16, TEXT])
		return out
	for group in [squares, bullets]:
		for o: Obj in group:
			if o.exists and o.visible:
				out.append(["rect", Rect2(o.x, o.y, o.w, o.h), o.live_color if o.alive else o.dead_color])
	return out


func mouse_pressed(mx: int, _my: int) -> void:
	if state == State.MENU:
		switch_state(State.PLAY)
		return
	var b := _first_dead(bullets)
	if b != null:
		b.fire(mx, H - K_BULLET_H * 2)


func mouse_released(_mx: int, _my: int) -> void:
	pass


func mouse_dragged(_mx: int, _my: int) -> void:
	pass
