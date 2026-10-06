extends RefCounted
## BulletDemoLive: a line-for-line port of course/w02_InvaderSketch/live/BulletDemoLive/BulletDemoLive.pde.
## This is the version live-coded in the video lessons. It's the same idea as GameSketchLibDemo
## (menu → click to fire 3 bullets → clear 9 squares → menu), but it tracks bullets with
## `active` instead of `alive`, moves everything in GameObject.update(), and deactivates squares
## when they're hit, so bullets fly through dead (darker gray #999999) squares.
## step() is one Processing draw() frame. render() returns the frame as a draw list.

const W := 300
const H := 300
const FPS := 60

const MENU_BG := Color("#000000")
const PLAY_BG := Color("#3366FF")
const LIVE := Color("#FFFFFF")
const DEAD := Color("#999999")
const BULLET := Color("#FFCC33")
const TEXT := Color("#FFFFFF")

const K_BULLET_W := 10
const K_BULLET_H := 20
const K_BULLET_SPEED := 3.75
const K_BULLET_COUNT := 3

enum State { MENU, PLAY }


## GameBasic + GameObject + GameRect (GameSquare / Bullet differ only in colours and onOverlap()).
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
	var dead_color := Color("#999999")
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

	## GameObject.update(): everything moves by (dx, dy). Squares have zero velocity.
	func update() -> void:
		x += dx
		y += dy

	func fire(px: float, py: float) -> void:
		x = px
		y = py
		active = true

	## Bullet.onOverlap(). GameObject's default is empty.
	func on_overlap(other: Obj) -> void:
		if not is_bullet:
			return
		active = false
		other.alive = false
		other.active = false


var state := State.MENU
var bg := MENU_BG
## PlayState members in add() order: mBullets first, then mSquares (so bullets draw underneath).
var bullets: Array[Obj] = []
var squares: Array[Obj] = []
var bounds := Obj.new(0, 0, W, H)


func _init() -> void:
	switch_state(State.MENU)


func switch_state(s: State) -> void:
	state = s
	squares = []
	bullets = []
	bg = MENU_BG
	if s == State.PLAY:
		bg = PLAY_BG
		for i in 3:
			for j in 3:
				squares.append(Obj.new(75 * i + 50, 75 * j + 50, 25, 25))
		for i in K_BULLET_COUNT:
			var b := Obj.new(K_BULLET_W * i, H - K_BULLET_H, K_BULLET_W, K_BULLET_H)
			b.is_bullet = true
			b.live_color = BULLET
			b.dy = -K_BULLET_SPEED
			b.active = false
			bullets.append(b)


func _group_update(group: Array[Obj]) -> void:
	for o in group:
		if o.exists and o.active:
			o.update()


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


func _first_inactive(group: Array[Obj]) -> Obj:
	for o in group:
		if not o.active:
			return o
	return null


func step() -> void:
	if state != State.PLAY:
		return
	# super.update(): GameGroup.update() over [mBullets, mSquares]
	_group_update(bullets)
	_group_update(squares)
	_overlap(bullets, squares)
	var left := 0
	for b in bullets:
		if not b.overlaps(bounds):
			b.active = false
		if not b.active:
			b.x = K_BULLET_W * left
			b.y = H - K_BULLET_H
			left += 1
	if _first_alive(squares) == null:
		switch_state(State.MENU)


func render() -> Array:
	var out: Array = [["bg", bg]]
	if state == State.MENU:
		out.append(["text", "BulletDemo! Click to start.", Vector2(10, 50), 16, TEXT])
		return out
	for group in [bullets, squares]:
		for o: Obj in group:
			if o.exists and o.visible:
				out.append(["rect", Rect2(o.x, o.y, o.w, o.h), o.live_color if o.alive else o.dead_color])
	return out


func mouse_pressed(mx: int, _my: int) -> void:
	if state == State.MENU:
		switch_state(State.PLAY)
		return
	var b := _first_inactive(bullets)
	if b != null:
		b.fire(mx, H - K_BULLET_H * 2)


func mouse_released(_mx: int, _my: int) -> void:
	pass


func mouse_dragged(_mx: int, _my: int) -> void:
	pass
