extends SceneTree
## Headless check: the gallery fits the window at common sizes (no side overflow).
## Run: godot --headless --path . --script res://tools/test_gallery_layout.gd

const SIZES := [Vector2(1280, 800), Vector2(1024, 570), Vector2(800, 600), Vector2(600, 800), Vector2(1920, 1080), Vector2(1280, 800)]

var _host: Control
var _arc: Control
var _f := 0
var _i := -1
var _fail := 0


func _initialize() -> void:
	_host = Control.new()
	root.add_child(_host)
	_arc = (load("res://arcade/main.tscn") as PackedScene).instantiate()
	_host.add_child(_arc)


func _process(_d: float) -> bool:
	_f += 1
	if _f % 10 != 0:
		return false
	if _i >= 0:
		_check(SIZES[_i])
	_i += 1
	if _i >= SIZES.size():
		quit(1 if _fail else 0)
		return true
	_host.size = SIZES[_i]
	return false


func _check(win: Vector2) -> void:
	var sc: ScrollContainer = _arc.get_node("%Scroll")
	var gl: GridContainer = _arc.get_node("%GameList")
	var hdr: Control = _arc.get_node("Margin/VBox/Header")
	var bar := sc.get_v_scroll_bar()
	var vbw := bar.size.x if bar.visible else 0.0
	var s := sc.get_global_rect()
	var g := gl.get_global_rect()
	var h := hdr.get_global_rect()
	var ok := h.position.x >= 0.0 and h.end.x <= win.x \
		and s.position.x >= 0.0 and s.end.x <= win.x \
		and g.end.x + vbw <= s.end.x + 0.5
	if ok:
		print("ok: gallery fits %s (%d cols, grid %.0f / scroll %.0f)" % [win, gl.columns, g.size.x, s.size.x])
	else:
		print("SMOKE FAIL: gallery overflows %s: header %s scroll %s grid %s" % [win, h, s, g])
		_fail += 1
