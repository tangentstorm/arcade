extends RefCounted
## OverlapDemo: a line-for-line port of course/w02_InvaderSketch/demos/OverlapDemo/OverlapDemo.pde.
## Drag the nine squares around. Squares that overlap another square turn gray.
## step() is one Processing draw() frame. render() returns the frame as a draw list.

const W := 300
const H := 300
const FPS := 60

const BG := Color("#3366FF")
const WHITE := Color("#FFFFFF")
const GRAY := Color("#999999")

const K_SQUARE_COUNT := 9
const K_PER_ROW := 3
const K_NUM_ROWS := 3


class Square:
	var x := 0.0
	var y := 0.0
	var w := 0.0
	var h := 0.0
	var fill_color := Color("#FFFFFF")

	func _init(px: float, py: float, side: float) -> void:
		x = px
		y = py
		w = side
		h = side

	func x2() -> float:
		return x + w

	func y2() -> float:
		return y + h

	func contains_point(px: float, py: float) -> bool:
		return x <= px and px <= x2() and y <= py and py <= y2()

	func overlaps(that: Square) -> bool:
		return x < that.x2() and x2() > that.x and y < that.y2() and y2() > that.y


var squares: Array[Square] = []
var in_hand: Square = null
var x_off := 0.0
var y_off := 0.0


func _init() -> void:
	# mSquares[i * kPerRow + j] = new Square(75 * i + 50, 75 * j + 50, 25)
	for i in K_NUM_ROWS:
		for j in K_PER_ROW:
			squares.append(Square.new(75 * i + 50, 75 * j + 50, 25))


## draw(): reset to white, then gray every square that overlaps any other (full n² scan).
func step() -> void:
	for s in squares:
		s.fill_color = WHITE
	for i in squares.size():
		for j in squares.size():
			if j != i and squares[i].overlaps(squares[j]):
				squares[i].fill_color = GRAY
				squares[j].fill_color = GRAY


func render() -> Array:
	var out: Array = [["bg", BG]]
	for s in squares:
		out.append(["rect", Rect2(s.x, s.y, s.w, s.h), s.fill_color])
	return out


## Picks the lowest-index square under the mouse, even if a later one is drawn on top of it.
func mouse_pressed(mx: int, my: int) -> void:
	for i in K_SQUARE_COUNT:
		if squares[i].contains_point(mx, my):
			x_off = squares[i].x - mx
			y_off = squares[i].y - my
			in_hand = squares[i]
			break


func mouse_released(_mx: int, _my: int) -> void:
	in_hand = null


func mouse_dragged(mx: int, my: int) -> void:
	if in_hand != null:
		in_hand.x = mx + x_off
		in_hand.y = my + y_off
