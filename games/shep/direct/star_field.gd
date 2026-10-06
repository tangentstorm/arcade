extends Node2D
## StarField.hx: black sky with 5 layers of 100 stars drifting right, 24 fps.
## Layer c moves 1px every c frames. counter % 0 is NaN in Flash, so layer 0
## never moves. Star color is 0x333333 * (5 - c): white for the still layer,
## down to dark gray.

const LAYERS := 5
const PER_LAYER := 100
const FPS := 24.0

var w := 800.0
var h := 575.0
var paused := false
var stars: Array = []      ## [layer][i] -> Vector2
var counter := 0
var _acc := 0.0


func _ready() -> void:
	for i in LAYERS:
		var layer: Array[Vector2] = []
		for j in PER_LAYER:
			layer.append(Vector2(randi() % int(w), randi() % int(h)))
		stars.append(layer)


func _process(delta: float) -> void:
	if paused:
		return
	_acc += delta
	var stepped := false
	while _acc >= 1.0 / FPS:
		_acc -= 1.0 / FPS
		_tick()
		stepped = true
	if stepped:
		queue_redraw()


func _tick() -> void:
	counter += 1
	for c in range(1, LAYERS):
		if counter % c != 0:
			continue
		var layer: Array = stars[c]
		for i in PER_LAYER:
			var s: Vector2 = layer[i] + Vector2(1, 0)
			if s.y > h:
				s = Vector2(randi() % int(w), 0)
			if s.x > w:
				s = Vector2(0, randi() % int(h))
			layer[i] = s


func _draw() -> void:
	draw_rect(Rect2(0, 0, 850, h), Color.BLACK)
	for c in LAYERS:
		var v := 0.2 * (5 - (c % 5))
		var col := Color(v, v, v)
		for s in stars[c]:
			draw_rect(Rect2(s, Vector2(2, 1)), col)
