extends RefCounted
## Paper-cut topo renderer ported from Claude Design canyon-run.dc-script.js.
## Band 0 (waterline) follows CanyonLogic.walls_at so collision matches the coast.
## Bands 1..5, islands, water waves, jet and boat sprites mirror the mock algorithm.
## No Alchementrix IP. Visual-only islands (no hit tests).

const LogicScript = preload("res://games/canyon_run/direct/canyon_logic.gd")

const LAYERS := 6
const RATES := [1.0, 1.07, 1.15, 1.24, 1.34, 1.45]
const BANDS := [
	Color("6b4f36"), Color("8a6748"), Color("a87f4f"),
	Color("c39655"), Color("dcb46a"), Color("f0dcae"),
]
const WATER_TOP := Color("7ba7c2")
const WATER_BOT := Color("3d6b87")
const SHADOW := Color(38.0 / 255.0, 22.0 / 255.0, 8.0 / 255.0, 0.2)
const COAST_STROKE := Color(20.0 / 255.0, 50.0 / 255.0, 70.0 / 255.0, 0.22)
const STEP_PX := 6.0

var _rng := RandomNumberGenerator.new()
var _bands: Array = []
var _islands: Array = []
var _next_island: float = 900.0
var _seed: int = 1
var time: float = 0.0


func reset(p_seed: int = 1) -> void:
	_seed = p_seed
	_rng.seed = p_seed
	_bands.clear()
	_islands.clear()
	_next_island = 900.0
	time = 0.0
	for i in LAYERS:
		var inset: float = float(i) * 0.05
		var wd0: float = 0.54 - inset * 2.0
		var b: Dictionary = {
			"rate": RATES[i],
			"inset": inset,
			"wmin": maxf(0.1, 0.3 - inset * 2.0),
			"wmax": maxf(0.16, 0.68 - inset * 2.0),
			"rows": [{
				"y": -700.0,
				"c": 0.5,
				"wd": wd0,
				"l": 0.23 + inset,
				"r": 0.77 - inset,
			}],
		}
		_bands.append(b)
	_ensure(3200.0, null)


func sync_seed(p_seed: int) -> void:
	if p_seed != _seed:
		reset(p_seed)


func tick(delta: float) -> void:
	time += delta


func ensure(cam_y: float, logic) -> void:
	_ensure(cam_y + 3200.0, logic)


func _ensure(upto: float, logic) -> void:
	for bi in range(1, LAYERS):
		var b: Dictionary = _bands[bi]
		var rate: float = float(b.rate)
		var cam: float = (upto - 3200.0) * rate if upto > 3200.0 else 0.0
		var need: float = upto * rate + 400.0
		var last: Dictionary = b.rows[b.rows.size() - 1]
		while float(last.y) < need:
			_gen_row(b)
			last = b.rows[b.rows.size() - 1]
		var low: float = cam - 700.0
		while b.rows.size() > 4:
			var r1: Dictionary = b.rows[1]
			if float(r1.y) >= low:
				break
			b.rows.remove_at(0)
	if logic != null:
		while _next_island < upto:
			_next_island += _rng.randf_range(520.0, 1100.0)
			var isle = _make_island(_next_island, logic)
			if isle != null:
				_islands.append(isle)
	var cam0: float = upto - 3200.0
	var kept: Array = []
	for f in _islands:
		if float(f.cy) > cam0 - 700.0:
			kept.append(f)
	_islands = kept


func _gen_row(b: Dictionary) -> void:
	var p: Dictionary = b.rows[b.rows.size() - 1]
	var y: float = float(p.y) + _rng.randf_range(95.0, 180.0)
	var c: float = float(p.c)
	var wd: float = float(p.wd)
	if _rng.randf() > 0.2:
		c = clampf(c + _rng.randf_range(-0.085, 0.085), 0.36, 0.64)
		wd = clampf(wd + _rng.randf_range(-0.1, 0.1), float(b.wmin), float(b.wmax))
	b.rows.append({
		"y": y, "c": c, "wd": wd,
		"l": c - wd * 0.5, "r": c + wd * 0.5,
	})


func _edge_of(rows: Array, side: int, wy: float) -> float:
	if rows.is_empty():
		return 0.5
	var r0: Dictionary = rows[0]
	if wy <= float(r0.y):
		return float(r0.l) if side < 0 else float(r0.r)
	for i in range(1, rows.size()):
		var a: Dictionary = rows[i - 1]
		var b: Dictionary = rows[i]
		if wy <= float(b.y):
			var t: float = (wy - float(a.y)) / maxf(float(b.y) - float(a.y), 0.001)
			if side < 0:
				return float(a.l) + (float(b.l) - float(a.l)) * t
			return float(a.r) + (float(b.r) - float(a.r)) * t
	var L: Dictionary = rows[rows.size() - 1]
	return float(L.l) if side < 0 else float(L.r)


func _coast_norm(logic, wy: float, side: int) -> float:
	var w: Vector2 = logic.walls_at(wy)
	return (w.x if side < 0 else w.y) / LogicScript.STAGE_W


func _make_island(wy: float, logic) -> Variant:
	if logic == null:
		return null
	var l: float = _coast_norm(logic, wy, -1)
	var r: float = _coast_norm(logic, wy, 1)
	if r - l < 0.42:
		return null
	var rx: float = _rng.randf_range(0.032, 0.07)
	var mid: float = _rng.randf_range(l + rx + 0.11, r - rx - 0.11)
	var ry: float = _rng.randf_range(55.0, 125.0)
	var pts := PackedVector2Array()
	for i in 7:
		var a: float = (float(i) / 7.0) * TAU + _rng.randf_range(-0.16, 0.16)
		var k: float = _rng.randf_range(0.74, 1.16)
		pts.append(Vector2(mid + cos(a) * rx * k, wy + sin(a) * ry * k))
	return {"pts": pts, "cx": mid, "cy": wy}


func paint(ci: CanvasItem, logic, origin: Vector2, px: float, bank: float = 0.0) -> void:
	var W: float = LogicScript.STAGE_W
	var H: float = LogicScript.STAGE_H
	var cam_y: float = logic.dist
	ensure(cam_y, logic)

	for i in 24:
		var t: float = float(i) / 23.0
		var c: Color = WATER_TOP.lerp(WATER_BOT, t)
		ci.draw_rect(Rect2(origin + Vector2(0.0, H * t * px), Vector2(W * px, H / 24.0 * px + 1.0)), c)

	_paint_waves(ci, origin, px, cam_y, W, H)
	_paint_walls(ci, logic, origin, px, cam_y, W, H)
	_paint_islands(ci, origin, px, cam_y, W, H)

	for e in logic.enemies:
		var sy: float = logic.screen_y(e.pos.y)
		if sy < -30.0 or sy > H + 30.0:
			continue
		var facing: float = 1.0 if float(e.vx) >= 0.0 else -1.0
		_draw_boat(ci, origin + Vector2(float(e.pos.x), sy) * px, px, facing)

	var S: float = clampf((W * px) / 1250.0, 0.42, 0.9)
	for b in logic.bullets:
		var sy: float = logic.screen_y(b.y)
		if sy < -20.0 or sy > H + 20.0:
			continue
		_draw_shot(ci, origin + Vector2(b.x, sy) * px, S * px)

	var crashed: bool = logic.state == LogicScript.State.CRASHED
	_draw_jet(ci, origin + Vector2(logic.player_x, LogicScript.PLAYER_Y) * px, S * px, bank, crashed)


func _paint_waves(ci: CanvasItem, origin: Vector2, px: float, cam_y: float, W: float, H: float) -> void:
	var layers: Array = [
		{"gap": 34.0, "rate": 0.55, "amp": 4.2, "freq": 0.032, "h": 2.2,
			"col": Color(18.0 / 255.0, 48.0 / 255.0, 66.0 / 255.0, 0.08)},
		{"gap": 24.0, "rate": 0.78, "amp": 3.0, "freq": 0.05, "h": 1.8,
			"col": Color(1, 1, 1, 0.10)},
		{"gap": 17.0, "rate": 1.06, "amp": 1.9, "freq": 0.08, "h": 1.4,
			"col": Color(1, 1, 1, 0.07)},
	]
	for L in layers:
		var rate: float = float(L.rate)
		var gap: float = float(L.gap)
		var amp: float = float(L.amp)
		var freq: float = float(L.freq)
		var hh: float = float(L.h)
		var col: Color = L.col
		var scroll: float = cam_y * rate + time * 14.0 * rate
		var first: float = floorf((scroll - H * 0.12) / gap) * gap
		var n: int = int(ceil(H / gap)) + 3
		for i in n:
			var wy: float = first + float(i) * gap
			var y: float = H - (wy - scroll)
			if y < -8.0 or y > H + 8.0:
				continue
			var x: float = 0.0
			while x < W:
				var yy: float = y + sin((x + wy * 0.6) * freq) * amp
				ci.draw_rect(Rect2(origin + Vector2(x, yy) * px, Vector2(7.0, hh) * px), col)
				x += 7.0


func _paint_walls(ci: CanvasItem, logic, origin: Vector2, px: float, cam_y: float, W: float, H: float) -> void:
	for i in LAYERS:
		var b: Dictionary = _bands[i]
		var cam: float = cam_y * float(b.rate)
		var min_gap: float = float(i) * 0.014
		for side in [-1, 1]:
			var far_x: float = (-0.4 * W) if side < 0 else (1.4 * W)
			var pts := PackedVector2Array()
			var y: float = H + 24.0
			while y > -24.0:
				var wy_band: float = cam + (H - y)
				var wy_coast: float = cam_y + (H - y)
				var own: float
				if i == 0:
					own = _coast_norm(logic, wy_coast, side)
				else:
					own = _edge_of(b.rows, side, wy_band)
				var coast: float = _coast_norm(logic, wy_coast, side)
				var xn: float
				if side < 0:
					xn = minf(own, coast - min_gap)
				else:
					xn = maxf(own, coast + min_gap)
				pts.append(Vector2(xn * W, y))
				y -= STEP_PX
			if pts.is_empty():
				continue
			if i > 0:
				var dx: float = 3.0 if side < 0 else -3.0
				ci.draw_colored_polygon(_wall_poly(pts, far_x, dx, 5.0, origin, px), SHADOW)
			ci.draw_colored_polygon(_wall_poly(pts, far_x, 0.0, 0.0, origin, px), BANDS[i])
			if i == 0:
				_stroke_coast(ci, pts, origin, px)


func _wall_poly(pts: PackedVector2Array, far_x: float, dx: float, dy: float, origin: Vector2, px: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append(origin + Vector2(far_x + dx, pts[0].y + dy) * px)
	for p in pts:
		out.append(origin + Vector2(p.x + dx, p.y + dy) * px)
	out.append(origin + Vector2(far_x + dx, pts[pts.size() - 1].y + dy) * px)
	return out


func _stroke_coast(ci: CanvasItem, pts: PackedVector2Array, origin: Vector2, px: float) -> void:
	for i in range(1, pts.size()):
		ci.draw_line(origin + pts[i - 1] * px, origin + pts[i] * px, COAST_STROKE, 1.4 * px)


func _paint_islands(ci: CanvasItem, origin: Vector2, px: float, cam_y: float, W: float, H: float) -> void:
	for fe in _islands:
		var screen_cy: float = H - (float(fe.cy) - cam_y)
		if screen_cy < -400.0 or screen_cy > H + 400.0:
			continue
		var pts: PackedVector2Array = fe.pts
		var cx: float = float(fe.cx)
		var cy: float = float(fe.cy)
		for i in LAYERS:
			var k: float = 1.0 - float(i) * 0.17
			if k <= 0.12:
				break
			if i > 0:
				ci.draw_colored_polygon(
					_island_poly(pts, cx, cy, k, i, cam_y, H, W, 2.0, 5.0, origin, px), SHADOW)
			ci.draw_colored_polygon(
				_island_poly(pts, cx, cy, k, i, cam_y, H, W, 0.0, 0.0, origin, px), BANDS[i])
		var stroke_pts := PackedVector2Array()
		for p in pts:
			stroke_pts.append(origin + Vector2(p.x * W, H - (p.y - cam_y)) * px)
		var sc := Color(20.0 / 255.0, 50.0 / 255.0, 70.0 / 255.0, 0.2)
		for i in range(1, stroke_pts.size()):
			ci.draw_line(stroke_pts[i - 1], stroke_pts[i], sc, 1.4 * px)
		if stroke_pts.size() >= 2:
			ci.draw_line(stroke_pts[stroke_pts.size() - 1], stroke_pts[0], sc, 1.4 * px)


func _island_poly(
	pts: PackedVector2Array, cx: float, cy: float, k: float, i: int,
	cam_y: float, H: float, W: float, dx: float, dy: float,
	origin: Vector2, px: float
) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		var x: float = (cx + (p.x - cx) * k) * W + dx
		var y: float = H - ((cy + (p.y - cy) * k) - cam_y) - float(i) * 5.0 + dy
		out.append(origin + Vector2(x, y) * px)
	return out


func _draw_shot(ci: CanvasItem, pos: Vector2, s: float) -> void:
	var h: float = 13.0 * s
	var wd: float = 7.0 * s
	ci.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0.0, -h * 0.5),
		pos + Vector2(wd * 0.5, h * 0.5),
		pos + Vector2(-wd * 0.5, h * 0.5),
	]), Color("d9541b"))
	ci.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0.0, -h * 0.18),
		pos + Vector2(wd * 0.28, h * 0.42),
		pos + Vector2(-wd * 0.28, h * 0.42),
	]), Color("ffd21f"))


func _draw_boat(ci: CanvasItem, pos: Vector2, px: float, facing: float) -> void:
	var S: float = clampf((LogicScript.STAGE_W * px) / 1250.0, 0.42, 0.9)
	var sp: float = S * 1.1 * px
	var f: float = 1.0 if facing >= 0.0 else -1.0
	ci.draw_circle(
		pos + Vector2(4.0 * sp, 6.0 * sp), 16.0 * sp * 0.55,
		Color(18.0 / 255.0, 48.0 / 255.0, 70.0 / 255.0, 0.2))
	ci.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-26.0 * f * sp, -6.0 * sp),
		pos + Vector2(20.0 * f * sp, -6.0 * sp),
		pos + Vector2(30.0 * f * sp, 0.0),
		pos + Vector2(20.0 * f * sp, 6.0 * sp),
		pos + Vector2(-26.0 * f * sp, 6.0 * sp),
	]), Color("d8202a"))
	ci.draw_rect(Rect2(pos + Vector2(-26.0 * sp, -1.6 * sp), Vector2(50.0 * sp, 3.4 * sp)), Color("f7f5f0"))
	ci.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-10.0 * f * sp, -6.0 * sp),
		pos + Vector2(2.0 * f * sp, -6.0 * sp),
		pos + Vector2(-2.0 * f * sp, -12.0 * sp),
		pos + Vector2(-8.0 * f * sp, -12.0 * sp),
	]), Color("39454c"))


func _draw_jet(ci: CanvasItem, pos: Vector2, s_ci: float, bank: float, crashed: bool) -> void:
	var s: float = s_ci * 1.25
	var bx: float = clampf(bank, -1.0, 1.0) * 0.12
	var rc: float = cos(bx)
	var sn: float = sin(bx)

	if not crashed:
		for dx in [-7.0, 7.0]:
			ci.draw_colored_polygon(PackedVector2Array([
				pos + Vector2(dx * s * rc - 30.0 * s * sn, dx * s * sn + 30.0 * s * rc),
				pos + Vector2((dx - 3.4) * s * rc - 17.0 * s * sn, (dx - 3.4) * s * sn + 17.0 * s * rc),
				pos + Vector2((dx + 3.4) * s * rc - 17.0 * s * sn, (dx + 3.4) * s * sn + 17.0 * s * rc),
			]), Color("d9541b"))
			ci.draw_colored_polygon(PackedVector2Array([
				pos + Vector2(dx * s * rc - 25.0 * s * sn, dx * s * sn + 25.0 * s * rc),
				pos + Vector2((dx - 1.8) * s * rc - 17.0 * s * sn, (dx - 1.8) * s * sn + 17.0 * s * rc),
				pos + Vector2((dx + 1.8) * s * rc - 17.0 * s * sn, (dx + 1.8) * s * sn + 17.0 * s * rc),
			]), Color("ffd21f"))

	var shadow_p: Vector2 = pos + Vector2(4.0 * s * rc - 8.0 * s * sn, 4.0 * s * sn + 8.0 * s * rc)
	ci.draw_circle(shadow_p, maxf(4.0, 9.0 * s), Color(18.0 / 255.0, 48.0 / 255.0, 66.0 / 255.0, 0.22))

	var wing_col := Color("d7dbdd") if not crashed else Color("d8202a")
	var wing := PackedVector2Array()
	for v in [
		Vector2(0.0, -12.0), Vector2(5.0, 2.0), Vector2(34.0, 15.0), Vector2(34.0, 19.0),
		Vector2(4.0, 14.0), Vector2(-4.0, 14.0), Vector2(-34.0, 19.0), Vector2(-34.0, 15.0),
		Vector2(-5.0, 2.0),
	]:
		wing.append(pos + Vector2(v.x * s * rc - v.y * s * sn, v.x * s * sn + v.y * s * rc))
	ci.draw_colored_polygon(wing, wing_col)

	var shade := PackedVector2Array()
	for v in [Vector2(0.0, -12.0), Vector2(5.0, 2.0), Vector2(34.0, 15.0), Vector2(34.0, 19.0), Vector2(4.0, 14.0)]:
		shade.append(pos + Vector2(v.x * s * rc - v.y * s * sn, v.x * s * sn + v.y * s * rc))
	ci.draw_colored_polygon(shade, Color(90.0 / 255.0, 110.0 / 255.0, 120.0 / 255.0, 0.22))

	var tail_col := Color("c3c9cc") if not crashed else Color("a03030")
	for pair in [
		[Vector2(-12.0, 12.0), Vector2(-18.0, 24.0), Vector2(-7.0, 20.0)],
		[Vector2(12.0, 12.0), Vector2(18.0, 24.0), Vector2(7.0, 20.0)],
	]:
		var tp := PackedVector2Array()
		for v in pair:
			tp.append(pos + Vector2(v.x * s * rc - v.y * s * sn, v.x * s * sn + v.y * s * rc))
		ci.draw_colored_polygon(tp, tail_col)

	var fuse_col := Color("f7f5f0") if not crashed else Color("e08080")
	var fuse := PackedVector2Array()
	for v in [Vector2(0.0, -27.0), Vector2(5.0, -6.0), Vector2(6.5, 18.0), Vector2(-6.5, 18.0), Vector2(-5.0, -6.0)]:
		fuse.append(pos + Vector2(v.x * s * rc - v.y * s * sn, v.x * s * sn + v.y * s * rc))
	ci.draw_colored_polygon(fuse, fuse_col)
	var fuse_shade := PackedVector2Array()
	for v in [Vector2(0.0, -27.0), Vector2(5.0, -6.0), Vector2(6.5, 18.0), Vector2(0.0, 18.0)]:
		fuse_shade.append(pos + Vector2(v.x * s * rc - v.y * s * sn, v.x * s * sn + v.y * s * rc))
	ci.draw_colored_polygon(fuse_shade, Color(120.0 / 255.0, 140.0 / 255.0, 150.0 / 255.0, 0.28))
	var canopy: Vector2 = pos + Vector2(0.0 * rc - (-13.0) * s * sn, 0.0 * sn + (-13.0) * s * rc)
	ci.draw_circle(canopy, maxf(2.0, 3.8 * s), Color("2f4a5a"))


func paint_badge(ci: CanvasItem, origin: Vector2, px: float, font: Font) -> void:
	var pad := Vector2(8.0, 6.0) * px
	var pos: Vector2 = origin + Vector2(10.0, LogicScript.STAGE_H - 36.0) * px
	var title := "CANYON RUN"
	var wip := "WIP"
	var fs: int = int(11.0 * px)
	var tw: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ww: float = font.get_string_size(wip, HORIZONTAL_ALIGNMENT_LEFT, -1, int(9.0 * px)).x
	var box := Rect2(pos, Vector2(tw + ww + pad.x * 3.0, 22.0 * px))
	ci.draw_rect(box, Color(0.05, 0.05, 0.07, 0.92))
	ci.draw_string(font, pos + Vector2(pad.x, 16.0 * px), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffd21f"))
	ci.draw_string(
		font, pos + Vector2(pad.x * 2.0 + tw, 16.0 * px), wip,
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(9.0 * px), Color(1, 1, 1, 0.85))
