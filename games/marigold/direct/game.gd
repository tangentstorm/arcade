extends Control
## Marigold Homestead - Direct edition (Godot 4).
## Starflight II x Farming Simulator mashup. Pixel OS chrome from Claude artifact
## BjKJn834; Homestead is a tractor-driven fractal planet map (not click-grid).

const Logic := preload("res://games/marigold/direct/marigold_logic.gd")
const Gfx := preload("res://games/marigold/direct/marigold_gfx.gd")

const W := Logic.STAGE_W
const H := Logic.STAGE_H
const TOP := 54
const SIDE := 186
const LOG_H := 28
const FONT_PATH := "res://games/marigold/direct/fonts/nokiafc22.ttf"

var state: Logic = Logic.new()
var _font: Font
var _font_sm: Font
var _s := 1.0
var _ox := 0.0
var _oy := 0.0
var _cam := Vector2.ZERO
var _stars: Array = []  ## {x,y,ph}
var _hover_nav := -1
var _click_rects: Array = []  ## {rect, id, arg}
var _mouse_stage := Vector2.ZERO
var _action_held := false

const NAV := [
	{"id": "cockpit", "label": "Cockpit", "icon": "ship"},
	{"id": "homestead", "label": "Homestead", "icon": "sprout"},
	{"id": "survey", "label": "Survey", "icon": "radar"},
	{"id": "market", "label": "Market", "icon": "star"},
	{"id": "ship", "label": "Ship & Crew", "icon": "cargo"},
	{"id": "ledger", "label": "Ledger", "icon": "book"},
]


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	else:
		_font = ThemeDB.fallback_font
	_font_sm = _font
	for i in 46:
		_stars.append({
			"x": randf(), "y": randf(), "ph": randf() * TAU,
		})
	resized.connect(queue_redraw)
	_fit()
	_center_cam()


func _fit() -> void:
	var sz := size
	_s = minf(sz.x / float(W), sz.y / float(H))
	_ox = (sz.x - W * _s) * 0.5
	_oy = (sz.y - H * _s) * 0.5


func _center_cam() -> void:
	_cam = Vector2(state.tractor_x * Logic.TILE, state.tractor_y * Logic.TILE)


func _process(delta: float) -> void:
	if state.screen == "homestead":
		var dx := 0.0
		var dy := 0.0
		if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
			dx -= 1.0
		if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
			dx += 1.0
		if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
			dy -= 1.0
		if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
			dy += 1.0
		if dx != 0.0 or dy != 0.0:
			var len := sqrt(dx * dx + dy * dy)
			dx /= len
			dy /= len
			var speed := 5.5 * delta  ## tiles/sec
			state.drive(dx * speed, dy * speed)
			_cam = _cam.lerp(
				Vector2(state.tractor_x * Logic.TILE, state.tractor_y * Logic.TILE),
				clampf(10.0 * delta, 0.0, 1.0)
			)
		# Space applies tool under tractor without moving.
		if Input.is_key_pressed(KEY_SPACE):
			if not _action_held:
				_action_held = true
				state.apply_tool_here()
		else:
			_action_held = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_stage = _to_stage(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_stage = _to_stage(event.position)
		_handle_click(_mouse_stage)


func _to_stage(p: Vector2) -> Vector2:
	return Vector2((p.x - _ox) / _s, (p.y - _oy) / _s)


func _handle_click(p: Vector2) -> void:
	for item in _click_rects:
		var r: Rect2 = item["rect"]
		if r.has_point(p):
			_activate(str(item["id"]), item.get("arg", null))
			return


func _activate(id: String, arg: Variant) -> void:
	match id:
		"nav":
			state.set_screen(str(arg))
			if str(arg) == "homestead":
				_center_cam()
		"end_day":
			state.end_day()
		"plot_course":
			state.plot_course()
		"refuel":
			state.buy_fuel()
		"select_system":
			state.select_system(str(arg))
		"tool":
			state.set_tool(str(arg))
		"buy_seed":
			state.buy_seed(str(arg))
		"water_all":
			state.water_all()
		"harvest_all":
			state.harvest_all()
		"buy_good":
			state.buy_good(str(arg))
		"sell_good":
			state.sell_good(str(arg))
		"ledger_prev":
			state.ledger_month = maxi(0, state.ledger_month - 1)
		"ledger_next":
			state.ledger_month = mini(state.month_index, state.ledger_month + 1)
	queue_redraw()


func _draw() -> void:
	_fit()
	_click_rects.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Gfx.C_PAGE)
	draw_set_transform(Vector2(_ox, _oy), 0.0, Vector2(_s, _s))
	draw_rect(Rect2(0, 0, W, H), Gfx.C_STAGE)
	_draw_top_bar()
	_draw_sidebar()
	_draw_log()
	var content := Rect2(SIDE + 8, TOP + 8, W - SIDE - 16, H - TOP - LOG_H - 16)
	match state.screen:
		"cockpit":
			_draw_cockpit(content)
		"homestead":
			_draw_homestead(content)
		"survey":
			_draw_survey(content)
		"market":
			_draw_market(content)
		"ship":
			_draw_ship(content)
		"ledger":
			_draw_ledger(content)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _txt(pos: Vector2, text: String, col: Color, px: int = 14) -> void:
	draw_string(_font, pos + Vector2(0, px), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _txt_c(pos: Vector2, text: String, col: Color, px: int = 14) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(_font, pos + Vector2(-w * 0.5, px), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _panel(r: Rect2, fill: Color = Gfx.C_PANEL) -> void:
	draw_rect(r, fill)
	draw_rect(r, Gfx.C_BORDER, false, 2.0)


func _btn(r: Rect2, label: String, id: String, arg: Variant = null, style: String = "green") -> void:
	var bg := Gfx.C_GREEN_BTN
	var fg := Color8(0xea, 0xfb, 0xe8)
	var border := Gfx.C_GREEN
	match style:
		"cyan":
			bg = Color8(0x1a, 0x3a, 0x48); fg = Gfx.C_CYAN; border = Gfx.C_CYAN
		"gold":
			bg = Color8(0x4a, 0x3a, 0x1e); fg = Color8(0xf7, 0xd0, 0x89); border = Gfx.C_GOLD
		"muted":
			bg = Color8(0x22, 0x1c, 0x30); fg = Gfx.C_DIM; border = Gfx.C_DIM
		"nav":
			bg = Gfx.C_NAV_ACTIVE; fg = Gfx.C_GOLD; border = Gfx.C_GOLD
		"nav_idle":
			bg = Color(0, 0, 0, 0); fg = Gfx.C_MUTED; border = Color(0, 0, 0, 0)
	draw_rect(r, bg)
	if border.a > 0.01:
		draw_rect(r, border, false, 2.0)
	var px := 11
	var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(_font, Vector2(r.position.x + (r.size.x - tw) * 0.5, r.position.y + r.size.y * 0.5 + px * 0.35),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, fg)
	_click_rects.append({"rect": r, "id": id, "arg": arg})


func _bar(r: Rect2, frac: float, fill: Color) -> void:
	draw_rect(r, Color8(0x1a, 0x14, 0x24))
	var f := clampf(frac, 0.0, 1.0)
	if f > 0.0:
		draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), fill)
	draw_rect(r, Gfx.C_BORDER, false, 1.0)


func _draw_top_bar() -> void:
	draw_rect(Rect2(0, 0, W, TOP), Color8(0x0e, 0x0a, 0x16))
	draw_line(Vector2(0, TOP), Vector2(W, TOP), Gfx.C_BORDER, 3.0)
	_txt(Vector2(16, 16), "MARIGOLD homestead OS", Gfx.C_GOLD, 16)
	_txt(Vector2(340, 18), "%s cr" % _fmt(state.credits), Gfx.C_GOLD, 14)
	# Fuel
	_txt(Vector2(520, 12), "FUEL", Gfx.C_CYAN, 10)
	_bar(Rect2(560, 18, 100, 12), float(state.fuel) / float(state.fuel_max), Gfx.C_CYAN)
	_txt(Vector2(668, 16), "%d/%d" % [state.fuel, state.fuel_max], Gfx.C_CYAN, 12)
	# Cargo
	_txt(Vector2(760, 12), "HOLD", Gfx.C_GOLD, 10)
	_bar(Rect2(800, 18, 100, 12), float(state.cargo_qty()) / float(state.cargo_cap), Gfx.C_GOLD)
	_txt(Vector2(908, 16), "%d/%d" % [state.cargo_qty(), state.cargo_cap], Gfx.C_TEXT, 12)
	_txt(Vector2(1040, 18), state.date_label(), Gfx.C_GREEN, 14)


func _draw_sidebar() -> void:
	draw_rect(Rect2(0, TOP, SIDE, H - TOP - LOG_H), Color8(0x0e, 0x0a, 0x16))
	draw_line(Vector2(SIDE, TOP), Vector2(SIDE, H - LOG_H), Gfx.C_BORDER, 3.0)
	var y := TOP + 16.0
	for i in NAV.size():
		var n: Dictionary = NAV[i]
		var r := Rect2(10, y, SIDE - 20, 36)
		var active: bool = state.screen == str(n["id"])
		_btn(r, n["label"], "nav", n["id"], "nav" if active else "nav_idle")
		var tex: Texture2D = Gfx.sprite(str(n["icon"]))
		if tex:
			draw_texture_rect(tex, Rect2(14, y + 6, 24, 24), false)
		y += 44.0
	_txt(Vector2(12, H - LOG_H - 90), "Drive tractor on soil.", Gfx.C_GREEN, 10)
	_txt(Vector2(12, H - LOG_H - 76), "Tool applies under wheels.", Gfx.C_GREEN, 10)
	_btn(Rect2(12, H - LOG_H - 56, SIDE - 24, 40), "END DAY", "end_day", null, "green")


func _draw_log() -> void:
	draw_rect(Rect2(0, H - LOG_H, W, LOG_H), Color8(0x0a, 0x08, 0x12))
	draw_line(Vector2(0, H - LOG_H), Vector2(W, H - LOG_H), Gfx.C_BORDER, 2.0)
	_txt(Vector2(12, H - LOG_H + 6), "LOG", Gfx.C_GOLD, 12)
	_txt(Vector2(56, H - LOG_H + 6), state.latest_log(), Gfx.C_TEXT, 12)


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-" if n < 0 else "") + out


# ─── Cockpit ───────────────────────────────────────────────────────────────

func _draw_cockpit(content: Rect2) -> void:
	var left := Rect2(content.position, Vector2(content.size.x - 280, content.size.y))
	var right := Rect2(content.position.x + content.size.x - 268, content.position.y, 260, content.size.y)
	_panel(left)
	_txt(left.position + Vector2(12, 10), "SECTOR CHART - MARIGOLD REACH", Gfx.C_CYAN, 14)
	var map_r := Rect2(left.position.x + 12, left.position.y + 36, left.size.x - 24, left.size.y - 60)
	draw_rect(map_r, Color8(0x0a, 0x08, 0x14))
	# stars
	for s in _stars:
		var sx := map_r.position.x + float(s["x"]) * map_r.size.x
		var sy := map_r.position.y + float(s["y"]) * map_r.size.y
		var a := 0.4 + 0.6 * absf(sin(Time.get_ticks_msec() * 0.002 + float(s["ph"])))
		draw_rect(Rect2(sx, sy, 2, 2), Color(Gfx.C_TEXT, a))
	# links
	for sys in Logic.SYSTEMS:
		var a := _sys_pos(sys, map_r)
		for lid in sys["links"]:
			var other := state.system_by_id(lid)
			if other.is_empty():
				continue
			if str(sys["id"]) > str(other["id"]):
				continue
			var b := _sys_pos(other, map_r)
			draw_dashed_line(a, b, Gfx.C_DIM, 1.0, 6.0)
	# systems
	for sys in Logic.SYSTEMS:
		var p := _sys_pos(sys, map_r)
		var kind: String = str(sys["kind"])
		var tex: Texture2D
		if kind == "station":
			tex = Gfx.sprite("station")
		else:
			tex = Gfx.planet_tex(kind if kind in ["lush", "rock", "ice"] else "lush")
		var sz := 28.0
		if tex:
			draw_texture_rect(tex, Rect2(p.x - sz * 0.5, p.y - sz * 0.5, sz, sz), false)
		var sid: String = str(sys["id"])
		if sid == state.current:
			draw_rect(Rect2(p.x - 18, p.y - 18, 36, 36), Gfx.C_CYAN, false, 2.0)
		if sid == state.selected_system:
			draw_rect(Rect2(p.x - 20, p.y - 20, 40, 40), Gfx.C_GOLD, false, 2.0)
		_txt_c(Vector2(p.x, p.y + 18), str(sys["name"]), Gfx.C_TEXT, 10)
		_click_rects.append({"rect": Rect2(p.x - 20, p.y - 20, 40, 40), "id": "select_system", "arg": sid})
	_txt(left.position + Vector2(12, left.size.y - 22), "Linked routes shown. Click a system to plot a course.", Gfx.C_MUTED, 10)

	# Selected system card
	var sel := state.system_by_id(state.selected_system)
	var card1 := Rect2(right.position.x, right.position.y, right.size.x, 280)
	_panel(card1)
	_txt(card1.position + Vector2(12, 10), "SELECTED SYSTEM", Gfx.C_GOLD, 12)
	if not sel.is_empty():
		var kind2: String = str(sel["kind"])
		var ptex: Texture2D = Gfx.sprite("station") if kind2 == "station" else Gfx.planet_tex(kind2)
		if ptex:
			draw_texture_rect(ptex, Rect2(card1.position.x + 90, card1.position.y + 40, 64, 64), false)
		_txt(card1.position + Vector2(12, 120), str(sel["name"]), Gfx.C_GREEN, 16)
		var scan: Dictionary = sel["scan"]
		_txt(card1.position + Vector2(12, 144), str(sel["kind"]).capitalize() + " . " + str(scan.get("biome", "")), Gfx.C_MUTED, 11)
		var st := state.jump_status_text()
		_txt(card1.position + Vector2(12, 170), st, Gfx.C_GREEN if "range" in st or "Current" in st else Gfx.C_RED, 12)
		_txt(card1.position + Vector2(12, 194), "Jump cost: %d fuel . %d day" % [state.jump_cost_fuel(), state.jump_cost_days()], Gfx.C_TEXT, 12)
		_btn(Rect2(card1.position.x + 12, card1.position.y + 230, card1.size.x - 24, 36), "PLOT COURSE", "plot_course", null, "green")

	var card2 := Rect2(right.position.x, right.position.y + 292, right.size.x, right.size.y - 292)
	_panel(card2)
	_txt(card2.position + Vector2(12, 10), "SHIP STATUS", Gfx.C_GOLD, 12)
	var cur := state.system_by_id(state.current)
	_txt(card2.position + Vector2(12, 40), "Location: %s" % cur.get("name", "?"), Gfx.C_TEXT, 12)
	_txt(card2.position + Vector2(12, 68), "Hull", Gfx.C_MUTED, 11)
	_bar(Rect2(card2.position.x + 60, card2.position.y + 70, 140, 12), state.hull / 100.0, Gfx.C_GREEN)
	_txt(card2.position + Vector2(208, 68), "%d%%" % int(state.hull), Gfx.C_GREEN, 11)
	_txt(card2.position + Vector2(12, 96), "Fuel", Gfx.C_MUTED, 11)
	_bar(Rect2(card2.position.x + 60, card2.position.y + 98, 140, 12), float(state.fuel) / float(state.fuel_max), Gfx.C_CYAN)
	_txt(card2.position + Vector2(208, 96), "%d/%d" % [state.fuel, state.fuel_max], Gfx.C_CYAN, 11)
	_btn(Rect2(card2.position.x + 12, card2.position.y + 130, card2.size.x - 24, 32), "REFUEL +1 (30cr)", "refuel", null, "cyan")


func _sys_pos(sys: Dictionary, map_r: Rect2) -> Vector2:
	return Vector2(
		map_r.position.x + float(sys["x"]) / 100.0 * map_r.size.x,
		map_r.position.y + float(sys["y"]) / 100.0 * map_r.size.y
	)


# ─── Homestead (tractor + fractal planet) ───────────────────────────────────

func _draw_homestead(content: Rect2) -> void:
	var map_w := content.size.x - 260
	var map_r := Rect2(content.position.x, content.position.y, map_w, content.size.y)
	var locker := Rect2(content.position.x + map_w + 8, content.position.y, 252, content.size.y)
	_panel(map_r)
	_txt(map_r.position + Vector2(12, 8), "VERDANCE III - HOMESTEAD SURFACE", Gfx.C_CYAN, 13)
	_txt(map_r.position + Vector2(map_r.size.x - 180, 8),
		"%d planted . %d ready" % [state.planted_count(), state.ready_count()], Gfx.C_GOLD, 11)

	var view := Rect2(map_r.position.x + 8, map_r.position.y + 32, map_r.size.x - 16, map_r.size.y - 84)
	draw_rect(view, Color8(0x0c, 0x18, 0x10))
	# Clip via manual bounds
	var scale := 2.0  ## pixels on screen per world pixel
	var tile_px := Logic.TILE * scale
	var cam_px := _cam * scale
	var origin := view.position + view.size * 0.5 - cam_px

	var x0 := int(floor((-origin.x + view.position.x) / tile_px)) - 1
	var y0 := int(floor((-origin.y + view.position.y) / tile_px)) - 1
	var x1 := int(ceil((view.end.x - origin.x) / tile_px)) + 1
	var y1 := int(ceil((view.end.y - origin.y) / tile_px)) + 1
	x0 = clampi(x0, 0, Logic.MAP_W - 1)
	y0 = clampi(y0, 0, Logic.MAP_H - 1)
	x1 = clampi(x1, 0, Logic.MAP_W)
	y1 = clampi(y1, 0, Logic.MAP_H)

	for ty in range(y0, y1):
		for tx in range(x0, x1):
			var rp := origin + Vector2(tx * tile_px, ty * tile_px)
			var cell := Rect2(rp, Vector2(tile_px - 1, tile_px - 1))
			if not view.intersects(cell):
				continue
			var t := state.terrain_at(tx, ty)
			var col := Gfx.C_GRASS
			match t:
				Logic.T_WATER:
					col = Gfx.C_WATER
				Logic.T_ROCK:
					col = Gfx.C_ROCK
				Logic.T_SOIL:
					col = Gfx.C_SOIL if ((tx + ty) % 2 == 0) else Gfx.C_SOIL2
				Logic.T_GRASS:
					col = Gfx.C_GRASS if ((tx + ty) % 2 == 0) else Gfx.C_GRASS2
			# Clip draw to view
			var clipped := cell.intersection(view)
			if clipped.size.x > 0 and clipped.size.y > 0:
				draw_rect(clipped, col)
			var plot = state.get_plot(tx, ty)
			if plot != null:
				_draw_crop_on_tile(rp, tile_px, plot, view)

	# Tractor
	var tr_px := origin + Vector2(state.tractor_x * tile_px - tile_px * 0.5, state.tractor_y * tile_px - tile_px * 0.5)
	var ttex := Gfx.sprite("tractor")
	var tr := Rect2(tr_px, Vector2(tile_px, tile_px))
	if view.intersects(tr) and ttex:
		draw_texture_rect(ttex, tr, false)
		# facing indicator
		var tip := tr_px + Vector2(tile_px * 0.5, tile_px * 0.5) + state.tractor_facing * (tile_px * 0.45)
		draw_circle(tip, 3.0, Gfx.C_GOLD)

	_txt(map_r.position + Vector2(12, map_r.size.y - 44), "WASD/Arrows drive . Space applies tool under tractor", Gfx.C_MUTED, 10)
	_btn(Rect2(map_r.position.x + 12, map_r.position.y + map_r.size.y - 36, 140, 28), "WATER ALL", "water_all", null, "cyan")
	_btn(Rect2(map_r.position.x + 160, map_r.position.y + map_r.size.y - 36, 140, 28), "HARVEST ALL", "harvest_all", null, "gold")

	# Seed / tool locker
	_panel(locker)
	_txt(locker.position + Vector2(10, 8), "TOOL / SEED LOCKER", Gfx.C_GOLD, 12)
	_txt(locker.position + Vector2(10, 28), "Select tool, then drive.", Gfx.C_MUTED, 10)
	var ly := locker.position.y + 52.0
	# Water / Harvest tools
	for tool_def in [
		{"id": Logic.TOOL_WATER, "name": "WATER", "hint": "Drive to water crops"},
		{"id": Logic.TOOL_HARVEST, "name": "HARVEST", "hint": "Drive to pick ripe"},
	]:
		var active: bool = state.tool == str(tool_def["id"])
		var rr := Rect2(locker.position.x + 8, ly, locker.size.x - 16, 44)
		draw_rect(rr, Gfx.C_NAV_ACTIVE if active else Gfx.C_PANEL)
		draw_rect(rr, Gfx.C_GOLD if active else Gfx.C_BORDER, false, 2.0)
		_txt(rr.position + Vector2(8, 8), str(tool_def["name"]), Gfx.C_CYAN if tool_def["id"] == Logic.TOOL_WATER else Gfx.C_GOLD, 12)
		_txt(rr.position + Vector2(8, 24), str(tool_def["hint"]), Gfx.C_MUTED, 9)
		_click_rects.append({"rect": rr, "id": "tool", "arg": tool_def["id"]})
		ly += 50.0

	for crop in Logic.CROPS:
		var cid: String = str(crop["id"])
		var active2: bool = state.tool == cid
		var rr2 := Rect2(locker.position.x + 8, ly, locker.size.x - 16, 56)
		if rr2.end.y > locker.end.y - 8:
			break
		draw_rect(rr2, Gfx.C_NAV_ACTIVE if active2 else Color8(0x18, 0x14, 0x22))
		draw_rect(rr2, Gfx.C_GOLD if active2 else Gfx.C_BORDER, false, 2.0)
		var stex: Texture2D = Gfx.sprite(cid)
		if stex:
			draw_texture_rect(stex, Rect2(rr2.position.x + 4, rr2.position.y + 8, 32, 32), false)
		_txt(rr2.position + Vector2(42, 6), str(crop["name"]), Gfx.C_TEXT, 11)
		_txt(rr2.position + Vector2(42, 22), "%dd water . sells %dcr" % [int(crop["grow"]), int(crop["sell"])], Gfx.C_MUTED, 9)
		_txt(rr2.position + Vector2(42, 36), "x%d  .  %s" % [int(state.seeds.get(cid, 0)), crop["season"]], Gfx.C_GREEN, 9)
		_click_rects.append({"rect": Rect2(rr2.position, Vector2(rr2.size.x - 70, rr2.size.y)), "id": "tool", "arg": cid})
		_btn(Rect2(rr2.end.x - 66, rr2.position.y + 14, 58, 28), "BUY", "buy_seed", cid, "green")
		# smaller buy label with price via log on hover - show cost under
		_txt(rr2.end + Vector2(-64, 40), "%dcr" % int(crop["seed"]), Gfx.C_MUTED, 8)
		ly += 60.0


func _draw_crop_on_tile(rp: Vector2, tile_px: float, plot: Dictionary, view: Rect2) -> void:
	var crop_id: String = str(plot["crop"])
	var crop := state.crop_by_id(crop_id)
	var ready: bool = plot.get("ready", false)
	var watered: bool = plot.get("watered", false)
	if watered and not ready:
		var wet := Rect2(rp, Vector2(tile_px - 1, tile_px - 1)).intersection(view)
		if wet.size.x > 0:
			draw_rect(wet, Color(Gfx.C_BLUE, 0.35))
	var tex: Texture2D
	if ready:
		tex = Gfx.sprite(crop_id)
	else:
		tex = Gfx.sprite("sprout")
	if tex:
		var s := tile_px * (0.9 if ready else 0.7)
		var tr := Rect2(rp.x + (tile_px - s) * 0.5, rp.y + (tile_px - s) * 0.5, s, s)
		if view.intersects(tr):
			draw_texture_rect(tex, tr, false)
	var prog := "%d/%d" % [int(plot["progress"]), int(crop.get("grow", 0))]
	if ready:
		_txt(rp + Vector2(2, tile_px - 14), "!", Gfx.C_GOLD, 12)
	else:
		_txt(rp + Vector2(2, tile_px - 12), prog, Gfx.C_TEXT, 8)


# ─── Survey ────────────────────────────────────────────────────────────────

func _draw_survey(content: Rect2) -> void:
	var cur := state.system_by_id(state.current)
	var left := Rect2(content.position, Vector2(content.size.x * 0.48, content.size.y))
	var right := Rect2(content.position.x + left.size.x + 8, content.position.y, content.size.x - left.size.x - 8, content.size.y)
	_panel(left)
	_txt(left.position + Vector2(12, 10), "SURVEY SCAN", Gfx.C_CYAN, 14)
	if cur.is_empty():
		return
	var kind: String = str(cur["kind"])
	var tex: Texture2D = Gfx.sprite("station") if kind == "station" else Gfx.planet_tex(kind)
	if tex:
		draw_texture_rect(tex, Rect2(left.position.x + left.size.x * 0.5 - 64, left.position.y + 80, 128, 128), false)
	_txt_c(Vector2(left.position.x + left.size.x * 0.5, left.position.y + 230), str(cur["name"]), Gfx.C_TEXT, 20)
	_txt_c(Vector2(left.position.x + left.size.x * 0.5, left.position.y + 258), str(kind).capitalize(), Gfx.C_MUTED, 12)
	var scan: Dictionary = cur["scan"]
	var rec_r := Rect2(left.position.x + 16, left.position.y + 300, left.size.x - 32, 80)
	_panel(rec_r, Color8(0x14, 0x1c, 0x16))
	_txt(rec_r.position + Vector2(10, 10), "RECOMMENDATION", Gfx.C_GREEN, 11)
	_wrap(rec_r.position + Vector2(10, 30), str(scan.get("rec", "")), Gfx.C_GREEN, 11, rec_r.size.x - 20)

	var top_r := Rect2(right.position.x, right.position.y, right.size.x, right.size.y * 0.55)
	var bot_r := Rect2(right.position.x, right.position.y + top_r.size.y + 8, right.size.x, right.size.y - top_r.size.y - 8)
	_panel(top_r)
	_txt(top_r.position + Vector2(12, 10), "PLANETARY READOUT", Gfx.C_GOLD, 12)
	var rows := [
		["Biome", str(scan.get("biome", ""))],
		["Gravity", str(scan.get("gravity", ""))],
		["Atmosphere", str(scan.get("atmo", ""))],
		["Water", str(scan.get("water", ""))],
		["Hazards", str(scan.get("hazards", ""))],
	]
	var yy := top_r.position.y + 40.0
	for row in rows:
		_txt(Vector2(top_r.position.x + 12, yy), str(row[0]), Gfx.C_MUTED, 11)
		var col := Gfx.C_RED if row[0] == "Hazards" else Gfx.C_TEXT
		_txt(Vector2(top_r.position.x + 130, yy), str(row[1]), col, 11)
		yy += 22.0
	_txt(Vector2(top_r.position.x + 12, yy + 8), "Soil arability", Gfx.C_MUTED, 11)
	var soil: float = float(scan.get("soil", 0)) / 100.0
	_bar(Rect2(top_r.position.x + 130, yy + 10, 160, 12), soil, Gfx.C_GREEN)
	_txt(Vector2(top_r.position.x + 300, yy + 8), "%d%%" % int(scan.get("soil", 0)), Gfx.C_TEXT, 11)

	_panel(bot_r)
	_txt(bot_r.position + Vector2(12, 10), "DETECTED RESOURCES", Gfx.C_GOLD, 12)
	yy = bot_r.position.y + 40.0
	for res in scan.get("resources", []):
		_txt(Vector2(bot_r.position.x + 12, yy), str(res["name"]), Gfx.C_TEXT, 12)
		_bar(Rect2(bot_r.position.x + 12, yy + 20, bot_r.size.x - 24, 14), float(res["pct"]) / 100.0, Gfx.C_CYAN)
		_txt(Vector2(bot_r.position.x + bot_r.size.x - 50, yy), "%d%%" % int(res["pct"]), Gfx.C_CYAN, 11)
		yy += 48.0


func _wrap(pos: Vector2, text: String, col: Color, px: int, width: float) -> void:
	var words := text.split(" ")
	var line := ""
	var y := pos.y
	for w in words:
		var trial := (line + " " + w).strip_edges()
		if _font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width and line != "":
			_txt(Vector2(pos.x, y), line, col, px)
			y += px + 4
			line = w
		else:
			line = trial
	if line != "":
		_txt(Vector2(pos.x, y), line, col, px)


# ─── Market ────────────────────────────────────────────────────────────────

func _draw_market(content: Rect2) -> void:
	_panel(content)
	var at := state.system_by_id(state.current)
	var title := "MARKET TERMINAL - %s" % at.get("name", "?")
	_txt(content.position + Vector2(12, 10), title, Gfx.C_GOLD, 14)
	if not state.is_station():
		_txt(content.position + Vector2(12, 40), "No exchange at this system. Dock at Havenport or Drift Market.", Gfx.C_RED, 13)
		return
	_txt(content.position + Vector2(12, 36), "Live exchange prices. Buy commodities low, sell your harvest high.", Gfx.C_MUTED, 11)
	_txt(content.position + Vector2(content.size.x - 200, 12),
		"Hold %d/%d . %s cr" % [state.cargo_qty(), state.cargo_cap, _fmt(state.credits)], Gfx.C_TEXT, 11)

	var headers := ["COMMODITY", "CLASS", "BUY", "SELL", "HELD"]
	var cols := [280.0, 120.0, 140.0, 140.0, 80.0]
	var x0 := content.position.x + 20.0
	var y := content.position.y + 70.0
	var x := x0
	for i in headers.size():
		_txt(Vector2(x, y), headers[i], Gfx.C_MUTED, 11)
		x += cols[i]
	y += 28.0
	draw_line(Vector2(x0, y - 6), Vector2(content.end.x - 20, y - 6), Gfx.C_BORDER, 1.0)

	# Commodities
	for g in Logic.COMMODITIES:
		_market_row(x0, y, cols, str(g["name"]), "Commodity", Gfx.C_CYAN,
			str(g["id"]), int(g["buy"]), int(g["sell"]), true)
		y += 40.0
	# Harvests
	for c in Logic.CROPS:
		_market_row(x0, y, cols, str(c["name"]), "Harvest", Gfx.C_GREEN,
			str(c["id"]), -1, int(c["sell"]), false)
		y += 40.0


func _market_row(x0: float, y: float, cols: Array, name: String, cls: String, cls_col: Color,
		id: String, buy: int, sell: int, can_buy: bool) -> void:
	var held := 0
	if state.cargo.has(id):
		held = int(state.cargo[id]["qty"])
	var x := x0
	_txt(Vector2(x, y + 8), name, Gfx.C_TEXT, 12)
	x += cols[0]
	_txt(Vector2(x, y + 8), cls, cls_col, 11)
	x += cols[1]
	if can_buy and buy > 0:
		_btn(Rect2(x, y, 110, 28), "%d  BUY" % buy, "buy_good", id, "cyan")
	else:
		_txt(Vector2(x + 8, y + 8), "-", Gfx.C_DIM, 12)
	x += cols[2]
	if sell > 0:
		var style := "gold" if held > 0 else "muted"
		_btn(Rect2(x, y, 110, 28), "%d  SELL" % sell, "sell_good", id, style)
	else:
		_txt(Vector2(x + 8, y + 8), "-", Gfx.C_DIM, 12)
	x += cols[3]
	_txt(Vector2(x, y + 8), str(held), Gfx.C_TEXT, 12)


# ─── Ship & Crew ───────────────────────────────────────────────────────────

func _draw_ship(content: Rect2) -> void:
	var left := Rect2(content.position, Vector2(content.size.x * 0.55, content.size.y * 0.62))
	var right := Rect2(content.position.x + left.size.x + 8, content.position.y, content.size.x - left.size.x - 8, left.size.y)
	var bot := Rect2(content.position.x, content.position.y + left.size.y + 8, content.size.x, content.size.y - left.size.y - 8)
	_panel(left)
	_txt(left.position + Vector2(12, 10), "CARGO HOLD", Gfx.C_GOLD, 14)
	_txt(left.position + Vector2(left.size.x - 120, 12), "%d/%d units" % [state.cargo_qty(), state.cargo_cap], Gfx.C_MUTED, 11)
	if state.cargo.is_empty():
		_txt(left.position + Vector2(24, 80), "Hold is empty. Harvest crops or buy goods to fill it.", Gfx.C_MUTED, 12)
	else:
		var yy := left.position.y + 48.0
		for id in state.cargo:
			var e: Dictionary = state.cargo[id]
			var label: String = id
			var c := state.crop_by_id(id)
			if not c.is_empty():
				label = c["name"]
			else:
				for g in Logic.COMMODITIES:
					if g["id"] == id:
						label = g["name"]
						break
			_txt(Vector2(left.position.x + 20, yy), "%s  x%d  (cost %d)" % [label, int(e["qty"]), int(e["cost"])], Gfx.C_TEXT, 12)
			yy += 24.0
	_bar(Rect2(left.position.x + 16, left.end.y - 28, left.size.x - 32, 12),
		float(state.cargo_qty()) / float(state.cargo_cap), Gfx.C_GOLD)

	_panel(right)
	_txt(right.position + Vector2(12, 10), "CREW ROSTER", Gfx.C_GOLD, 14)
	var cy := right.position.y + 48.0
	for member in Logic.CREW:
		var tex := Gfx.sprite("crew")
		if tex:
			draw_texture_rect(tex, Rect2(right.position.x + 16, cy, 28, 28), false)
		_txt(Vector2(right.position.x + 52, cy + 2), str(member["name"]), Gfx.C_TEXT, 12)
		_txt(Vector2(right.position.x + 52, cy + 18), str(member["role"]), Gfx.C_MUTED, 10)
		_txt(Vector2(right.position.x + right.size.x - 110, cy + 8), "%d / month" % int(member["wage"]), Gfx.C_RED, 11)
		cy += 48.0
	_txt(Vector2(right.position.x + 16, right.end.y - 36),
		"Monthly overhead: %d cr (wages + life support)" % (state.crew_wages() + 300), Gfx.C_MUTED, 10)

	_panel(bot)
	_txt(bot.position + Vector2(12, 10), "SHIP SYSTEMS - S.S. MARIGOLD", Gfx.C_GOLD, 13)
	_txt(bot.position + Vector2(20, 48), "Hull", Gfx.C_MUTED, 11)
	_bar(Rect2(bot.position.x + 80, bot.position.y + 50, 280, 14), state.hull / 100.0, Gfx.C_GREEN)
	_txt(bot.position + Vector2(370, 48), "%d%%" % int(state.hull), Gfx.C_GREEN, 11)
	_txt(bot.position + Vector2(20, 80), "Fuel", Gfx.C_MUTED, 11)
	_bar(Rect2(bot.position.x + 80, bot.position.y + 82, 280, 14), float(state.fuel) / float(state.fuel_max), Gfx.C_CYAN)
	_txt(bot.position + Vector2(370, 80), "%d/%d" % [state.fuel, state.fuel_max], Gfx.C_CYAN, 11)
	_txt(bot.position + Vector2(20, 112), "Hold", Gfx.C_MUTED, 11)
	_bar(Rect2(bot.position.x + 80, bot.position.y + 114, 280, 14), float(state.cargo_qty()) / float(state.cargo_cap), Gfx.C_GOLD)
	_txt(bot.position + Vector2(370, 112), "%d/%d" % [state.cargo_qty(), state.cargo_cap], Gfx.C_TEXT, 11)


# ─── Ledger ────────────────────────────────────────────────────────────────

func _draw_ledger(content: Rect2) -> void:
	_panel(content)
	_txt(content.position + Vector2(12, 10), "THE BOOKS", Gfx.C_GOLD, 16)
	var m := state.ledger_month
	_btn(Rect2(content.position.x + 200, content.position.y + 8, 36, 28), "<", "ledger_prev", null, "cyan")
	_txt(content.position + Vector2(250, 12), "%s . Year %d" % [state.season_name(m), state.year_num(m)], Gfx.C_TEXT, 13)
	_btn(Rect2(content.position.x + 420, content.position.y + 8, 36, 28), ">", "ledger_next", null, "cyan")

	var inc := state.get_income(m)
	var bal := state.get_balance()
	var left := Rect2(content.position.x + 16, content.position.y + 50, content.size.x * 0.48 - 16, content.size.y - 66)
	var right := Rect2(content.position.x + content.size.x * 0.52, content.position.y + 50, content.size.x * 0.48 - 16, content.size.y - 66)
	_panel(left, Color8(0x14, 0x1c, 0x16))
	_txt(left.position + Vector2(12, 10), "INCOME STATEMENT", Gfx.C_GREEN, 13)
	_txt(left.position + Vector2(12, 32), "For %s . Year %d" % [state.season_name(m), state.year_num(m)], Gfx.C_MUTED, 10)
	var y := left.position.y + 60.0
	y = _ledger_line(left.position.x + 12, y, left.size.x - 24, "Crop Sales", int(inc["rev_crop"]))
	y = _ledger_line(left.position.x + 12, y, left.size.x - 24, "Trade Sales", int(inc["rev_trade"]))
	y = _ledger_line(left.position.x + 12, y, left.size.x - 24, "Total Revenue", int(inc["total_rev"]), true)
	y += 8
	y = _ledger_line(left.position.x + 12, y, left.size.x - 24, "Cost of Goods Sold", int(inc["cogs"]))
	y = _ledger_line(left.position.x + 12, y, left.size.x - 24, "Gross Profit", int(inc["gross"]), true)
	y += 8
	var exp: Dictionary = inc["exp"]
	for k in ["Seeds & Supplies", "Fuel", "Docking Fees", "Crew Wages", "Life Support"]:
		y = _ledger_line(left.position.x + 12, y, left.size.x - 24, k, int(exp.get(k, 0)), false, Gfx.C_RED)
	y = _ledger_line(left.position.x + 12, y, left.size.x - 24, "Total Operating Expenses", int(inc["total_opex"]))
	y = _ledger_line(left.position.x + 12, y + 8, left.size.x - 24, "NET INCOME", int(inc["net"]), true, Gfx.C_GREEN)

	_panel(right, Color8(0x16, 0x14, 0x22))
	var bal_ok: bool = bool(bal["balanced"])
	_txt(right.position + Vector2(12, 10), "BALANCE SHEET", Gfx.C_CYAN, 13)
	_txt(right.position + Vector2(12, 32), "Current position  " + ("BALANCED OK" if bal_ok else "OFF"), Gfx.C_GREEN if bal_ok else Gfx.C_RED, 10)
	y = right.position.y + 60.0
	_txt(Vector2(right.position.x + 12, y), "ASSETS", Gfx.C_GOLD, 11)
	y += 22
	y = _ledger_line(right.position.x + 12, y, right.size.x - 24, "Cash & Credits", int(bal["cash"]))
	y = _ledger_line(right.position.x + 12, y, right.size.x - 24, "Inventory (at cost)", int(bal["inv"]))
	y = _ledger_line(right.position.x + 12, y, right.size.x - 24, "Ship & Equipment", int(bal["ship"]))
	y = _ledger_line(right.position.x + 12, y, right.size.x - 24, "Total Assets", int(bal["assets"]), true)
	y += 12
	_txt(Vector2(right.position.x + 12, y), "LIABILITIES", Gfx.C_GOLD, 11)
	y += 22
	y = _ledger_line(right.position.x + 12, y, right.size.x - 24, "Ship Loan", int(bal["loan"]))
	y += 12
	_txt(Vector2(right.position.x + 12, y), "EQUITY", Gfx.C_GOLD, 11)
	y += 22
	y = _ledger_line(right.position.x + 12, y, right.size.x - 24, "Paid-in Capital", int(bal["paid_in"]))
	y = _ledger_line(right.position.x + 12, y, right.size.x - 24, "Retained Earnings", int(bal["retained"]))
	_ledger_line(right.position.x + 12, y + 8, right.size.x - 24, "Liab. + Equity", int(bal["liab_eq"]), true)


func _ledger_line(x: float, y: float, w: float, label: String, amount: int, bold: bool = false, col: Color = Gfx.C_TEXT) -> float:
	var c := Gfx.C_GOLD if bold else col
	_txt(Vector2(x, y), label, c, 11 if not bold else 12)
	var s := _fmt(amount)
	var tw := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(_font, Vector2(x + w - tw, y + 11), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c)
	return y + 20.0
