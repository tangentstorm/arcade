extends RefCounted
## BulletDemo: a line-for-line port of course/w02_InvaderSketch/demos/BulletDemo/BulletDemo.pde.
## Click to fire one of three bullets straight up from the mouse x. A bullet that hits a live
## square kills it, and the square turns light gray. There's no win state.
## step() is one Processing draw() frame. render() returns the frame as a draw list.

const W := 300
const H := 300
const FPS := 60

const BG := Color("#3366FF")
const LIVE := Color("#FFFFFF")
const DEAD := Color("#CCCCCC")
const BULLET := Color("#FFCC33")

const K_SQUARE_COUNT := 9
const K_BULLET_W := 10
const K_BULLET_H := 20
const K_BULLET_COUNT := 3
const K_BULLET_SPEED := -3.75


## Bounds + GameObject + Rectangle/Square/Bullet flattened into one class.
class Box:
	var x := 0.0
	var y := 0.0
	var w := 0.0
	var h := 0.0
	var alive := true
	var dx := 0.0
	var dy := 0.0

	func _init(px: float, py: float, pw: float, ph: float) -> void:
		x = px
		y = py
		w = pw
		h = ph

	func x2() -> float:
		return x + w

	func y2() -> float:
		return y + h

	func overlaps(that: Box) -> bool:
		return x < that.x2() and x2() > that.x and y < that.y2() and y2() > that.y

	## Bullet.update(): moves only while alive.
	func bullet_update() -> void:
		if alive:
			y += dy
			x += dx

	func fire(px: float, py: float) -> void:
		x = px
		y = py
		alive = true


var squares: Array[Box] = []
var bullets: Array[Box] = []
var bullets_left := K_BULLET_COUNT
var screen_bounds := Box.new(0, 0, W, H)


func _init() -> void:
	for i in 3:
		for j in 3:
			squares.append(Box.new(75 * i + 50, 75 * j + 50, 25, 25))
	for i in K_BULLET_COUNT:
		var b := Box.new(0, 0, K_BULLET_W, K_BULLET_H)
		b.dy = K_BULLET_SPEED
		b.alive = false
		bullets.append(b)


func step() -> void:
	var left := 0
	for b in bullets:
		if b.overlaps(screen_bounds):
			b.bullet_update()
		else:
			b.alive = false
		if b.alive:
			for sq in squares:
				if sq.alive and b.overlaps(sq):
					sq.alive = false
					b.alive = false
		else:
			# Spent bullets sit in the ammo rack along the bottom-left edge.
			b.x = K_BULLET_W * left
			left += 1
			b.y = H - K_BULLET_H
	bullets_left = left


func render() -> Array:
	var out: Array = [["bg", BG]]
	for sq in squares:
		out.append(["rect", Rect2(sq.x, sq.y, sq.w, sq.h), LIVE if sq.alive else DEAD])
	for b in bullets:
		out.append(["rect", Rect2(b.x, b.y, b.w, b.h), BULLET])
	return out


func next_bullet() -> Box:
	for b in bullets:
		if not b.alive:
			return b
	return bullets[0]


func mouse_pressed(mx: int, _my: int) -> void:
	if bullets_left > 0:
		bullets_left -= 1
		next_bullet().fire(mx, H - K_BULLET_H * 2)


func mouse_released(_mx: int, _my: int) -> void:
	pass


func mouse_dragged(_mx: int, _my: int) -> void:
	pass
