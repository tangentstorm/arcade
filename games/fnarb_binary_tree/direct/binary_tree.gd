extends Control
## fnarbmlyx demos/binary_tree/BinaryTree.gd. Changes: no `@tool`/`class_name`, and the colours are
## GsPalette.d3_category10 inlined (gslib/GsPalette.gd), since gslib/ is not ported.

var colors : Array[Color] = [  # d3 category10
  Color(0x1f77b4ff), Color(0xff7f0eff), Color(0x2ca02cff),  Color(0xd62728ff),
  Color(0x9467bdff), Color(0x8c564bff), Color(0xe377c2ff),  Color(0x7f7f7fff),
  Color(0xbcbd22ff), Color(0x17becfff)]

var node_radius = 16
var gap = 2
var DEPTH = 5

func build_node(xy, depth):
	var width = (node_radius + gap) * (1<<depth)
	if depth:
		var dx = width /2
		var dy = 40
		var lxy = xy + Vector2(+dx, dy)
		var rxy = xy + Vector2(-dx, dy)
		draw_line(xy, lxy, Color.BLACK, 1)
		draw_line(xy, rxy, Color.BLACK, 1)
		build_node(lxy, depth-1)
		build_node(rxy, depth-1)
	draw_circle(xy, node_radius, Color.BLACK)
	draw_circle(xy, node_radius-1.5, colors[DEPTH-depth])

func _draw():
	build_node(size * 0.5, DEPTH)
