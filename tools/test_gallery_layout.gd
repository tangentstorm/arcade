extends SceneTree
## Headless check: the gallery fits the window at common sizes (no side overflow),
## across several card-count fixtures, not just the current registry size.
## Run: godot --headless --path . --script res://tools/test_gallery_layout.gd
## Gotchas this guards: docs/GALLERY_LAYOUT.md

const SIZES := [Vector2(1280, 800), Vector2(1024, 570), Vector2(800, 600), Vector2(600, 800), Vector2(1920, 1080), Vector2(1280, 800)]
## name -> card count (-1 = the real registry, built by main.gd itself).
## overflow: far more rows than any window, so the vertical bar is always shown.
const FIXTURES := [["registry", -1], ["empty", 0], ["one", 1], ["few", 3], ["many", 24], ["overflow", 120]]

var _host: Control
var _arc: Control
var _f := 0
var _fx := 0
var _i := -1
var _fail := 0
var _checks := 0


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
		_fx += 1
		_i = 0
		if _fx >= FIXTURES.size():
			print("layout: %d checks, %d fixtures x %d sizes, %d failed" % [_checks, FIXTURES.size(), SIZES.size(), _fail])
			quit(1 if _fail else 0)
			return true
		_load_fixture(FIXTURES[_fx][1])
	_host.size = SIZES[_i]
	return false


## Replace the gallery with `n` real cards, cycling registry ids (dupes are fine:
## keys are made unique, each card still reads its own entry via game_id).
func _load_fixture(n: int) -> void:
	var gl: GridContainer = _arc.get_node("%GameList")
	for child in gl.get_children():
		gl.remove_child(child)
		child.queue_free()
	_arc._cards.clear()
	var ids := _registry_ids()
	for k in n:
		var id := ids[k % ids.size()]
		var card: PanelContainer = _arc._make_card(id)
		gl.add_child(card)
		_arc._cards["%s#%d" % [id, k]] = card
		_arc._update_card(card, id)
	_arc._reflow_columns()


func _expected_count() -> int:
	var n: int = FIXTURES[_fx][1]
	if n >= 0:
		return n
	return _registry_ids().size()


## Gallery ids as main.gd shows them (autoloads are not compile-time names in --script).
func _registry_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in root.get_node("GameRegistry").title_ids():
		if id != "_template":
			ids.append(id)
	return ids


func _check(win: Vector2) -> void:
	_checks += 1
	var fx: String = FIXTURES[_fx][0]
	var sc: ScrollContainer = _arc.get_node("%Scroll")
	var gl: GridContainer = _arc.get_node("%GameList")
	var hdr: Control = _arc.get_node("Margin/VBox/Header")
	var bar := sc.get_v_scroll_bar()
	var vbw := bar.size.x if bar.visible else 0.0
	var s := sc.get_global_rect()
	var g := gl.get_global_rect()
	var h := hdr.get_global_rect()
	var why: Array[String] = []
	if h.position.x < 0.0 or h.end.x > win.x:
		why.append("header %s outside window" % h)
	if s.position.x < 0.0 or s.end.x > win.x:
		why.append("scroll %s outside window" % s)
	if g.end.x + vbw > s.end.x + 0.5:
		why.append("grid %s + bar %.0f past scroll %s" % [g, vbw, s])
	if sc.get_h_scroll_bar().visible:
		why.append("horizontal scrollbar visible")
	var n := gl.get_child_count()
	if n != _expected_count():
		why.append("%d cards, want %d" % [n, _expected_count()])
	for c in gl.get_children():
		var r := (c as Control).get_global_rect()
		if r.position.x < s.position.x - 0.5 or r.end.x + vbw > s.end.x + 0.5:
			why.append("card %s past scroll %s" % [r, s])
			break
	# Content taller than the viewport must scroll vertically (not grow the page).
	if g.size.y > s.size.y + 0.5 and not bar.visible:
		why.append("grid %.0f tall in %.0f scroll but no vertical bar" % [g.size.y, s.size.y])
	# The bar's range must cover the grid, or the last rows are unreachable.
	if bar.visible and bar.max_value + 0.5 < g.size.y:
		why.append("vbar range %.0f < grid %.0f tall (stale scroll range)" % [bar.max_value, g.size.y])
	if fx == "overflow" and not bar.visible:
		why.append("overflow fixture without vertical bar")
	if s.end.y > win.y + 0.5:
		why.append("scroll %s below window" % s)
	if why.is_empty():
		print("ok: gallery fits %s [%s: %d cards] (%d cols, grid %.0f / scroll %.0f%s)" % [win, fx, n, gl.columns, g.size.x, s.size.x, ", vbar" if bar.visible else ""])
	else:
		print("SMOKE FAIL: gallery overflows %s [%s]: %s" % [win, fx, "; ".join(why)])
		_fail += 1
