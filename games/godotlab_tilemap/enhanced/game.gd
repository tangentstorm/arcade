extends Node2D
## GodotLab Tilemap (Enhanced). Presentation makeover of the Direct Kenney tilemap test level.
## The level is Direct `game.tscn` (shared `tilemap.gd` / `tile_data.gd` / `player.gd`),
## instanced as-is in its native 1280×720 SubViewport and shown at ¾ in a clipped field
## (stretch=false + Control.scale). The tile replay, the p1 alien's walk / jump / gravity /
## respawn and the fixed camera all stay Direct. Enhanced hides Direct's plain HUD labels and
## owns the 1280×720 letterbox chrome, sky backdrop, HUD, minimap, title card and juice, all
## derived by *observing* the Direct nodes (player position / velocity / is_on_floor /
## respawns, TileMapLayer cells). No rules here. Esc → PauseOverlay. No Alchementrix IP.

const DIRECT := preload("res://games/godotlab_tilemap/direct/game.tscn")
const TilemapScript := preload("res://games/godotlab_tilemap/direct/tilemap.gd")
const PlayerScript := preload("res://games/godotlab_tilemap/direct/player.gd")
const TileData3 := preload("res://games/godotlab_tilemap/direct/tile_data.gd")

const STAGE := Vector2(1280, 720)
## Direct is authored for the arcade's 1280×720 view; show it at ¾ in a clipped field.
const VP_SIZE := Vector2(1280, 720)
const FIELD := Vector2(960, 540)
const FIELD_POS := Vector2(40, 96)
const CELL := 72.0
## Original Godot 3 autotile coord whose region lies past the sheet (drew nothing).
const BLANK_ATLAS := Vector2i(12, 9)

const BG_TOP := Color(0.05, 0.07, 0.12)
const BG_BOT := Color(0.09, 0.12, 0.10)
const SKY_TOP := Color(0.36, 0.62, 0.90)
const SKY_BOT := Color(0.80, 0.90, 0.98)
const HILL_FAR := Color(0.55, 0.74, 0.62)
const HILL_NEAR := Color(0.40, 0.62, 0.42)
const PANEL := Color(0.08, 0.11, 0.12, 0.94)
const FRAME := Color(0.55, 0.85, 0.45)   ## Kenney grass green
const INK := Color(0.94, 0.97, 0.92)
const MUTED := Color(0.60, 0.70, 0.62)
const GOLD := Color(1.0, 0.82, 0.30)
const DIRT := Color(0.80, 0.58, 0.36)
const SKY_C := Color(0.55, 0.80, 1.0)
const DANGER := Color(1.0, 0.42, 0.38)

enum { TITLE, PLAY }

var state := TITLE
var demo: Node2D = null   ## Direct game.tscn root (tilemap.gd)
var player: CharacterBody2D = null
var layer: TileMapLayer = null
var show_grid := false

## View-only presentation state, derived from the Direct nodes.
var jumps := 0
var landings := 0
var respawns_seen := 0
var walk_puffs := 0
var distance := 0.0        ## px walked on the ground
var peak_height := 0.0     ## best jump height above take-off, px
var best_air := 0.0        ## longest airtime, s
var _was_floor := false
var _air_t := 0.0
var _takeoff_y := 0.0
var _min_y := 0.0
var _max_fall := 0.0
var _last_pos := Vector2.ZERO
var _last_respawns := 0
var _walk_dust_t := 0.0
var _cell := Vector2i.ZERO
var _land_ring := 0.0
var _land_cell := Vector2i.ZERO
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _ghosts: Array[Dictionary] = []
var _ghost_t := 0.0
var _banner := ""
var _banner_t := 0.0
var _blank_cells: Array[Vector2i] = []

var _host: Control
var _vp_box: SubViewportContainer
var _viewport: SubViewport
var _field_clip: Control  ## clips in-field juice to the level view
var _field_fx: Node2D     ## in-field juice (dust, trails, shadow, grid) above Direct
var _fx: Node2D           ## stage-wide juice (flash, banner) above everything in the field
var _minimap: Panel
var _ui: CanvasLayer
var _hud: Control
var _cards := {}
var _pos_label: Label
var _state_label: Label
var _cell_label: Label
var _stats_label: Label
var _level_label: Label
var _font: Font
var _panel_style := StyleBoxFlat.new()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_panel_style.bg_color = PANEL
	_panel_style.border_color = Color(FRAME, 0.55)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(14)
	for row in TileData3.decode():
		if row[1] == BLANK_ATLAS:
			_blank_cells.append(row[0])
	_build_stage()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_set_state(TITLE)


func _layout() -> void:
	var size := get_viewport_rect().size
	var s := minf(size.x / STAGE.x, size.y / STAGE.y)
	if s <= 0.0:
		return
	scale = Vector2(s, s)
	position = ((size - STAGE * s) * 0.5).floor()
	if _ui:
		_ui.transform = Transform2D(0.0, scale, 0.0, position)


func _set_state(s: int) -> void:
	state = s
	_cards["title"].visible = s == TITLE
	_hud.visible = s == PLAY
	_vp_box.visible = s == PLAY
	if s == PLAY and demo == null:
		_load_demo()
	if s == PLAY:
		_banner = "WALK THE LEVEL"
		_banner_t = 1.8
		_flash = 0.4
		_flash_color = FRAME
		_burst(FIELD_POS + FIELD * 0.5, FRAME, 18, 220.0)


func _load_demo() -> void:
	demo = DIRECT.instantiate() as Node2D
	_viewport.add_child(demo)
	player = demo.get_node("Player") as CharacterBody2D
	layer = demo.get_node("TileMap") as TileMapLayer
	# Enhanced owns the HUD; Direct's hint / credit labels are re-drawn in the side panel.
	var direct_hud := demo.get_node_or_null("Hud") as CanvasLayer
	if direct_hud:
		direct_hud.visible = false
	_last_pos = player.position
	_last_respawns = player.respawns
	_was_floor = false
	_takeoff_y = player.position.y
	_min_y = player.position.y
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var e := event as InputEventKey
	if state == TITLE:
		if e.keycode in [KEY_ENTER, KEY_SPACE]:
			_set_state(PLAY)
			get_viewport().set_input_as_handled()
		return
	if e.keycode == KEY_R:
		_restart()
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_G:
		show_grid = not show_grid
		get_viewport().set_input_as_handled()


func _restart() -> void:
	_particles.clear()
	_floaters.clear()
	_ghosts.clear()
	jumps = 0
	landings = 0
	respawns_seen = 0
	walk_puffs = 0
	distance = 0.0
	peak_height = 0.0
	best_air = 0.0
	_air_t = 0.0
	_max_fall = 0.0
	if demo != null:
		_viewport.remove_child(demo)
		demo.queue_free()
		demo = null
		player = null
		layer = null
	_set_state(PLAY)


func _process(delta: float) -> void:
	_time += delta
	_shake = maxf(0.0, _shake - delta * 2.8)
	_flash = maxf(0.0, _flash - delta * 2.2)
	_banner_t = maxf(0.0, _banner_t - delta)
	_land_ring = maxf(0.0, _land_ring - delta * 2.0)
	_animate_fx(delta)
	if state == PLAY and player != null:
		_refresh_hud()
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 7.0 * _shake * _shake
	if _host:
		_host.position = sh
	if _field_fx:
		_field_fx.queue_redraw()
	if _field_clip:
		_field_clip.position = FIELD_POS + sh
	if _fx:
		_fx.position = sh
		_fx.queue_redraw()
	if _minimap:
		_minimap.queue_redraw()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if state == PLAY and player != null and is_instance_valid(player):
		_watch_player(delta)


## Presentation only: read the Direct player's state and fire juice.
func _watch_player(delta: float) -> void:
	var p := player.position
	var on_floor := player.is_on_floor()
	var feet := world_to_stage(p)
	_cell = Vector2i(floori(p.x / CELL), floori((p.y - 1.0) / CELL))

	if player.respawns != _last_respawns:
		_last_respawns = player.respawns
		respawns_seen += 1
		var lost := world_to_stage(_last_pos)
		lost = Vector2(clampf(lost.x, FIELD_POS.x + 12, FIELD_POS.x + FIELD.x - 12),
				FIELD_POS.y + FIELD.y - 14)
		_burst(lost, DANGER, 14, 200.0)
		_floater("fell!", lost + Vector2(-14, -20), DANGER)
		_burst(feet + Vector2(0, -30), SKY_C, 20, 240.0)
		_floater("respawn", feet + Vector2(-26, -96), SKY_C)
		_banner = "RESPAWN #%d" % respawns_seen
		_banner_t = 1.4
		_flash = 0.5
		_flash_color = SKY_C
		_shake = 0.45
		_was_floor = false
		_takeoff_y = p.y
		_min_y = p.y
		_max_fall = 0.0
		_air_t = 0.0
		_last_pos = p
		return

	if on_floor and not _was_floor:
		landings += 1
		var impact := clampf(_max_fall / 1400.0, 0.15, 1.0)
		_dust(feet, int(6 + 14 * impact), 80.0 + 160.0 * impact)
		_land_ring = 1.0
		_land_cell = Vector2i(floori(p.x / CELL), floori((p.y + 1.0) / CELL))
		if impact > 0.6:
			_shake = maxf(_shake, 0.25 * impact)
		best_air = maxf(best_air, _air_t)
		if _takeoff_y - _min_y > 8.0:
			var h := _takeoff_y - _min_y
			if h > peak_height + 0.5:
				peak_height = h
				_floater("peak %.1f tiles" % (h / CELL), feet + Vector2(-40, -110), GOLD)
		_max_fall = 0.0
		_air_t = 0.0
	elif not on_floor and _was_floor:
		_takeoff_y = _last_pos.y
		_min_y = p.y
		_air_t = 0.0
		if player.velocity.y < 0.0:
			jumps += 1
			_dust(feet, 8, 120.0)
			_floater("jump", feet + Vector2(-16, -104), GOLD)
	if not on_floor:
		_air_t += delta
		_min_y = minf(_min_y, p.y)
		_max_fall = maxf(_max_fall, player.velocity.y)
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = 0.05
			_add_ghost()
	else:
		var dx := absf(p.x - _last_pos.x)
		if dx > CELL:
			dx = 0.0  ## a teleport (test / respawn), not a walk
		distance += dx
		if dx > 0.5:
			_walk_dust_t -= delta
			if _walk_dust_t <= 0.0:
				_walk_dust_t = 0.16
				walk_puffs += 1
				_dust(feet + Vector2(-signf(p.x - _last_pos.x) * 14.0, 0), 3, 50.0)
	_was_floor = on_floor
	_last_pos = p


## World (Direct canvas) → enhanced stage, through Direct's camera and the ¾ field scale.
func world_to_stage(world: Vector2) -> Vector2:
	var vp_pos := world
	if _viewport:
		vp_pos = _viewport.canvas_transform * world
	return FIELD_POS + vp_pos * (FIELD / VP_SIZE)


func field_scale() -> float:
	return FIELD.x / VP_SIZE.x


## Top of the first solid cell at or below the player's feet in the same column (world y), or NAN.
func ground_below(world: Vector2) -> float:
	if layer == null:
		return NAN
	var cx := floori(world.x / CELL)
	var cy := floori((world.y - 1.0) / CELL)
	for y in range(cy, cy + 16):
		if layer.get_cell_source_id(Vector2i(cx, y)) != -1:
			return y * CELL
	return NAN


func _state_name() -> String:
	if player == null:
		return "-"
	if not player.is_on_floor():
		return "AIRBORNE ^" if player.velocity.y < 0.0 else "AIRBORNE v"
	if absf(player.velocity.x) > 1.0:
		return "WALKING"
	return "STANDING"


func _refresh_hud() -> void:
	if _pos_label == null or player == null:
		return
	var p := player.position
	var v := player.velocity
	_pos_label.text = "pos  %5.0f, %4.0f\nvel  %5.0f, %4.0f" % [p.x, p.y, v.x, v.y]
	_state_label.text = _state_name()
	_state_label.add_theme_color_override("font_color",
			FRAME if player.is_on_floor() else GOLD)
	var cell_src := layer.get_cell_source_id(_cell + Vector2i(0, 1)) if layer else -1
	_cell_label.text = "cell %s  %s" % [str(_cell), "on tile" if cell_src != -1 else "over void"]
	_stats_label.text = "jumps     %d\nlandings  %d\nrespawns  %d\npeak      %.1f tiles\nairtime   %.2f s\nwalked    %.1f tiles" % [
		jumps, landings, respawns_seen, peak_height / CELL, best_air, distance / CELL]
	if demo != null:
		_level_label.text = "placed %d  |  blank %d" % [demo.placed, demo.skipped_blank]


# --- draw ---------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, STAGE), BG_TOP)
	for i in 24:
		var t := float(i) / 24.0
		var c := BG_TOP.lerp(BG_BOT, t)
		c.a = 0.6
		draw_rect(Rect2(0, STAGE.y * t, STAGE.x, STAGE.y / 24.0 + 1.0), c)
	draw_circle(Vector2(120, 90), 160, Color(0.30, 0.55, 0.25, 0.10))
	draw_circle(Vector2(STAGE.x - 90, STAGE.y - 70), 190, Color(0.60, 0.42, 0.20, 0.10))
	if state != PLAY:
		return
	var fr := Rect2(FIELD_POS - Vector2(14, 14), FIELD + Vector2(28, 28))
	draw_rect(fr, Color(0.06, 0.08, 0.07))
	_draw_sky()
	_draw_backing()
	draw_rect(fr.grow(-5), Color(FRAME.r, FRAME.g, FRAME.b, 0.55), false, 2.0)
	var corner := Color(GOLD.r, GOLD.g, GOLD.b, 0.75)
	draw_rect(Rect2(fr.position, Vector2(28, 3)), corner)
	draw_rect(Rect2(fr.position, Vector2(3, 28)), corner)
	draw_rect(Rect2(fr.end - Vector2(28, 3), Vector2(28, 3)), corner)
	draw_rect(Rect2(fr.end - Vector2(3, 28), Vector2(3, 28)), corner)


## Sky backdrop behind the transparent Direct viewport, with gentle parallax on the player.
func _draw_sky() -> void:
	var f := Rect2(FIELD_POS, FIELD)
	for i in 20:
		var t := float(i) / 20.0
		draw_rect(Rect2(f.position.x, f.position.y + f.size.y * t, f.size.x, f.size.y / 20.0 + 1.0),
				SKY_TOP.lerp(SKY_BOT, t))
	var px := 0.0
	if player != null:
		px = player.position.x - 470.0
	draw_circle(f.position + Vector2(f.size.x - 120, 80), 46, Color(1.0, 0.95, 0.70, 0.9))
	draw_circle(f.position + Vector2(f.size.x - 120, 80), 70, Color(1.0, 0.95, 0.70, 0.18))
	for i in 5:
		var cx := fposmod(float(i) * 230.0 + _time * (10.0 + i * 3.0) - px * 0.05, f.size.x + 200.0) - 100.0
		var cy := 60.0 + fmod(float(i) * 53.0, 140.0)
		for k in 3:
			var cp := f.position + Vector2(cx + k * 26.0, cy - (12.0 if k == 1 else 0.0))
			var rad := 24.0 - absf(k - 1.0) * 5.0
			# Fade out near the field edges instead of spilling over the frame.
			var edge := minf(cp.x - f.position.x, f.end.x - cp.x) - rad
			if edge > 0.0:
				draw_circle(cp, rad, Color(1, 1, 1, 0.75 * clampf(edge / 40.0, 0.0, 1.0)))
	_draw_hills(f, f.size.y * 0.62, 70.0, HILL_FAR, px * 0.08, 0.006)
	_draw_hills(f, f.size.y * 0.76, 60.0, HILL_NEAR, px * 0.16, 0.011)


## Dark mortar behind Direct's painted cells, so the original 72-px-grid seams read as
## grout instead of letting the sky show through them.
func _draw_backing() -> void:
	if layer == null:
		return
	var step := CELL * field_scale()
	var clip := Rect2(FIELD_POS, FIELD)
	for c in layer.get_used_cells():
		var r := Rect2(world_to_stage(Vector2(c) * CELL), Vector2(step, step)).intersection(clip)
		if r.has_area():
			draw_rect(r, Color(0.30, 0.20, 0.13))


func _draw_hills(f: Rect2, base_y: float, amp: float, col: Color, shift: float, freq: float) -> void:
	var pts := PackedVector2Array()
	var steps := 48
	for i in steps + 1:
		var x := f.size.x * float(i) / steps
		var y := base_y - amp * (0.5 + 0.5 * sin((x + shift) * freq + 1.3)) \
				- amp * 0.3 * sin((x + shift) * freq * 2.7)
		pts.append(f.position + Vector2(x, clampf(y, 0.0, f.size.y)))
	pts.append(f.position + Vector2(f.size.x, f.size.y))
	pts.append(f.position + Vector2(0, f.size.y))
	draw_colored_polygon(pts, col)


## In-field overlay above the Direct SubViewport, clipped to the field (FieldClip/FieldFx).
func _draw_field_fx() -> void:
	if state == PLAY and demo != null:
		var clip := Rect2(FIELD_POS, FIELD)
		if show_grid:
			_draw_grid(clip)
		if _land_ring > 0.0:
			var top := world_to_stage(Vector2(_land_cell.x * CELL, _land_cell.y * CELL))
			var w := CELL * field_scale()
			var a := _land_ring
			_field_fx.draw_rect(Rect2(top - Vector2(w, 0), Vector2(w * 3.0, 4.0)), Color(GOLD, 0.45 * a))
			_field_fx.draw_rect(Rect2(top, Vector2(w, w)).grow(4.0 * (1.0 - a)), Color(GOLD, 0.8 * a), false, 2.0)
		_draw_shadow()
		for g in _ghosts:
			var gc := Color(SKY_C.r, SKY_C.g, SKY_C.b, 0.35 * clampf(g.life / g.max, 0.0, 1.0))
			_field_fx.draw_texture_rect_region(g.tex, g.rect, g.src, gc)
		var feet := world_to_stage(player.position)
		if clip.has_point(feet):
			_field_fx.draw_circle(feet + Vector2(0, -32), 34.0, Color(1.0, 1.0, 0.8, 0.08 + 0.04 * sin(_time * 4.0)))
		else:
			var edge := Vector2(clampf(feet.x, clip.position.x + 14, clip.end.x - 14),
					clampf(feet.y, clip.position.y + 14, clip.end.y - 14))
			_field_fx.draw_circle(edge, 9.0, Color(DANGER, 0.8 + 0.2 * sin(_time * 12.0)))
			var arrow := "v" if feet.y > clip.end.y else "^" if feet.y < clip.position.y else "!"
			var below := 1.0 if feet.y < clip.position.y else -1.0
			_field_fx.draw_string(_font, edge + Vector2(-6, 6 + 22 * below), arrow,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 18, DANGER)
	for p in _particles:
		var col: Color = p.color
		col.a *= clampf(p.life / p.max, 0.0, 1.0)
		_field_fx.draw_circle(p.pos, p.size, col)
	for f in _floaters:
		var col2: Color = f.color
		col2.a *= clampf(f.life / f.max, 0.0, 1.0)
		_field_fx.draw_string(_font, f.pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(f.size), col2)


## Stage-wide overlay (flash + banner), above the field.
func _draw_fx() -> void:
	if _flash > 0.0:
		var fc := _flash_color
		fc.a = _flash * 0.28
		_fx.draw_rect(Rect2(Vector2.ZERO, STAGE), fc)
	if _banner_t > 0.0:
		var a := clampf(_banner_t / 0.4, 0.0, 1.0)
		var r := Rect2(FIELD_POS.x + FIELD.x * 0.5 - 160, FIELD_POS.y + 24, 320, 44)
		_fx.draw_rect(r, Color(0.05, 0.08, 0.06, 0.85 * a))
		_fx.draw_rect(r, Color(GOLD, 0.8 * a), false, 2.0)
		_fx.draw_string(_font, r.position + Vector2(0, 29), _banner, HORIZONTAL_ALIGNMENT_CENTER,
				r.size.x, 20, Color(GOLD, a))


func _draw_shadow() -> void:
	var gy := ground_below(player.position)
	if is_nan(gy):
		return
	var h := maxf(0.0, gy - player.position.y)
	var k := clampf(1.0 - h / 400.0, 0.2, 1.0)
	var c := world_to_stage(Vector2(player.position.x, gy))
	var w := 26.0 * k
	var pts := PackedVector2Array()
	for i in 16:
		var ang := TAU * i / 16.0
		pts.append(c + Vector2(cos(ang) * w, sin(ang) * w * 0.28))
	_field_fx.draw_colored_polygon(pts, Color(0, 0, 0, 0.35 * k))


## G: the 72-px cell grid, with the 170 blank (12, 9) cells of the original outlined.
func _draw_grid(clip: Rect2) -> void:
	var k := field_scale()
	var tl := world_to_stage(Vector2.ZERO)
	var step := CELL * k
	var x := fposmod(tl.x - clip.position.x, step) + clip.position.x
	while x < clip.end.x:
		_field_fx.draw_line(Vector2(x, clip.position.y), Vector2(x, clip.end.y), Color(1, 1, 1, 0.12), 1.0)
		x += step
	var y := fposmod(tl.y - clip.position.y, step) + clip.position.y
	while y < clip.end.y:
		_field_fx.draw_line(Vector2(clip.position.x, y), Vector2(clip.end.x, y), Color(1, 1, 1, 0.12), 1.0)
		y += step
	for c in _blank_cells:
		var p := world_to_stage(Vector2(c) * CELL)
		var r := Rect2(p, Vector2(step, step)).grow(-3)
		if clip.encloses(r):
			_field_fx.draw_rect(r, Color(DANGER, 0.30), false, 1.0)
	for c in layer.get_used_cells():
		var p2 := world_to_stage(Vector2(c) * CELL)
		var r2 := Rect2(p2, Vector2(step, step)).grow(-2)
		if clip.encloses(r2):
			_field_fx.draw_rect(r2, Color(FRAME, 0.5), false, 1.0)
	var lp := world_to_stage(Vector2(_cell) * CELL)
	var cr := Rect2(lp, Vector2(step, step))
	if clip.encloses(cr):
		_field_fx.draw_rect(cr, Color(GOLD, 0.7), false, 2.0)


## Minimap of the level's painted cells (+ blank cells faintly) and the player, drawn on its HUD panel.
func _draw_minimap() -> void:
	if state != PLAY or layer == null or player == null:
		return
	var m := _minimap
	var r := Rect2(12, 26, m.size.x - 24, m.size.y - 38)
	m.draw_string(_font, Vector2(12, 20), "MINIMAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	m.draw_rect(r, Color(0.20, 0.32, 0.42, 0.9))
	m.draw_rect(r, Color(FRAME, 0.4), false, 1.0)
	var used := layer.get_used_cells()
	var lo := Vector2i(999, 999)
	var hi := Vector2i(-999, -999)
	for c in used:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	lo -= Vector2i(3, 2)
	hi += Vector2i(3, 2)
	var span := Vector2(hi - lo + Vector2i.ONE)
	var cs := minf((r.size.x - 8.0) / span.x, (r.size.y - 8.0) / span.y)
	var origin := r.position + (r.size - span * cs) * 0.5
	for c in _blank_cells:
		if c.x >= lo.x and c.x <= hi.x and c.y >= lo.y and c.y <= hi.y:
			m.draw_rect(Rect2(origin + Vector2(c - lo) * cs, Vector2(cs, cs)).grow(-1), Color(DANGER, 0.18))
	for c in used:
		var top := layer.get_cell_source_id(c + Vector2i(0, -1)) == -1
		m.draw_rect(Rect2(origin + Vector2(c - lo) * cs, Vector2(cs, cs)).grow(-0.5), FRAME if top else DIRT)
	var pp := origin + (player.position / CELL - Vector2(lo)) * cs - Vector2(0, cs * 0.6)
	pp = Vector2(clampf(pp.x, r.position.x + 5, r.end.x - 5), clampf(pp.y, r.position.y + 5, r.end.y - 5))
	m.draw_circle(pp, 3.5 + sin(_time * 6.0), GOLD)


# --- FX helpers ---------------------------------------------------------------

func _add_ghost() -> void:
	var spr := player.get_node_or_null("Sprite") as Sprite2D
	if spr == null or spr.texture == null:
		return
	var k := field_scale()
	var src := spr.region_rect
	var feet := world_to_stage(player.position)
	var dest := Rect2(feet + Vector2(-src.size.x * 0.5, -src.size.y) * k, src.size * k)
	if spr.flip_h:
		dest = Rect2(dest.position.x + dest.size.x, dest.position.y, -dest.size.x, dest.size.y)
	_ghosts.append({"tex": spr.texture, "rect": dest, "src": src, "life": 0.3, "max": 0.3})


func _dust(at: Vector2, n: int, speed: float) -> void:
	for i in n:
		var ang := randf_range(PI * 1.05, PI * 1.95)
		var sp := randf_range(0.3, 1.0) * speed
		_particles.append({
			"pos": at + Vector2(randf_range(-10, 10), -2),
			"vel": Vector2(cos(ang) * sp * 1.4, sin(ang) * sp * 0.5),
			"life": randf_range(0.3, 0.6),
			"max": 0.6,
			"color": Color(0.95, 0.88, 0.72, 0.8),
			"size": randf_range(2.0, 4.5),
			"grav": 60.0,
		})


func _burst(at: Vector2, color: Color, n: int, speed: float) -> void:
	for i in n:
		var ang := randf() * TAU
		var sp := randf_range(0.3, 1.0) * speed
		_particles.append({
			"pos": at,
			"vel": Vector2(cos(ang), sin(ang)) * sp,
			"life": randf_range(0.35, 0.7),
			"max": 0.7,
			"color": color,
			"size": randf_range(2.0, 5.0),
			"grav": 20.0,
		})


func _floater(text: String, at: Vector2, color: Color) -> void:
	_floaters.append({
		"pos": at,
		"life": 1.0,
		"max": 1.0,
		"text": text,
		"color": color,
		"size": 14.0,
	})


func _animate_fx(delta: float) -> void:
	var i := 0
	while i < _particles.size():
		var p: Dictionary = _particles[i]
		p.life -= delta
		p.pos += p.vel * delta
		p.vel.y += p.grav * delta
		p.vel *= 0.96
		if p.life <= 0.0:
			_particles.remove_at(i)
		else:
			_particles[i] = p
			i += 1
	i = 0
	while i < _floaters.size():
		var f: Dictionary = _floaters[i]
		f.life -= delta
		f.pos.y -= 24.0 * delta
		if f.life <= 0.0:
			_floaters.remove_at(i)
		else:
			_floaters[i] = f
			i += 1
	i = 0
	while i < _ghosts.size():
		var g: Dictionary = _ghosts[i]
		g.life -= delta
		if g.life <= 0.0:
			_ghosts.remove_at(i)
		else:
			_ghosts[i] = g
			i += 1


# --- UI build -----------------------------------------------------------------

func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "DirectVP"
	_viewport.size = Vector2i(VP_SIZE)
	# Transparent so Enhanced's sky shows behind Direct's tiles (Direct's grey clear is replaced).
	_viewport.transparent_bg = true
	_viewport.handle_input_locally = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.own_world_3d = true

	# Native 1280×720 Direct view, shown at ¾ via Control.scale (not stretch).
	# stretch=true would resize the SubViewport to the field and break VP_SIZE / camera framing.
	_vp_box = SubViewportContainer.new()
	_vp_box.name = "LevelView"
	_vp_box.position = FIELD_POS
	_vp_box.size = VP_SIZE
	_vp_box.stretch = false
	_vp_box.scale = FIELD / VP_SIZE
	_vp_box.visible = false
	_vp_box.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_vp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp_box.add_child(_viewport)

	_host = Control.new()
	_host.name = "StageHost"
	_host.size = STAGE
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)
	_host.add_child(_vp_box)

	_field_clip = Control.new()
	_field_clip.name = "FieldClip"
	_field_clip.position = FIELD_POS
	_field_clip.size = FIELD
	_field_clip.clip_contents = true
	_field_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_field_clip)
	_field_fx = Node2D.new()
	_field_fx.name = "FieldFx"
	_field_fx.position = -FIELD_POS  ## draw in stage coordinates
	_field_fx.draw.connect(_draw_field_fx)
	_field_clip.add_child(_field_fx)

	_fx = Node2D.new()
	_fx.name = "Fx"
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "UI"
	add_child(_ui)

	_hud = Control.new()
	_hud.name = "Hud"
	_hud.size = STAGE
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_hud)

	var head := _panel(Rect2(26, 16, 420, 62))
	_hud.add_child(head)
	head.add_child(_label("GODOTLAB TILEMAP", 22, GOLD, Vector2(16, 8)))
	head.add_child(_label("Kenney test level | Enhanced", 13, MUTED, Vector2(18, 38)))

	var live := _panel(Rect2(1036, 96, 216, 216))
	_hud.add_child(live)
	live.add_child(_label("PLAYER", 11, MUTED, Vector2(12, 10)))
	_state_label = _label("-", 18, FRAME, Vector2(12, 30))
	live.add_child(_state_label)
	_pos_label = _label("pos\nvel", 13, INK, Vector2(12, 64))
	live.add_child(_pos_label)
	_cell_label = _label("cell", 12, MUTED, Vector2(12, 112))
	live.add_child(_cell_label)
	live.add_child(_label("LEVEL", 11, MUTED, Vector2(12, 144)))
	_level_label = _label("placed 0  |  blank 0", 12, INK, Vector2(12, 162))
	live.add_child(_level_label)
	live.add_child(_label("original tile_data, replayed", 10, MUTED, Vector2(12, 184)))

	_minimap = _panel(Rect2(1036, 318, 216, 156))
	_minimap.name = "Minimap"
	_minimap.draw.connect(_draw_minimap)
	_hud.add_child(_minimap)

	var stats := _panel(Rect2(1036, 480, 216, 156))
	_hud.add_child(stats)
	stats.add_child(_label("RUN", 11, MUTED, Vector2(12, 10)))
	_stats_label = _label("", 13, INK, Vector2(12, 28))
	stats.add_child(_stats_label)

	var back := _btn("Back to Arcade", Vector2(26, 660), Vector2(160, 36))
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(GameRegistry.return_to_arcade)
	_hud.add_child(back)
	_hud.add_child(_label("<-/-> A/D walk | Space/^/W jump | G grid | R reload | Esc pause",
			13, MUTED, Vector2(204, 668)))
	_hud.add_child(_label("Art: Platformer Deluxe by Kenney (CC0)", 12, MUTED, Vector2(1000, 670)))

	var card := _panel(Rect2(STAGE.x * 0.5 - 310, STAGE.y * 0.5 - 170, 620, 340))
	card.name = "TitleCard"
	_ui.add_child(card)
	_cards["title"] = card
	card.add_child(_label("GODOTLAB TILEMAP", 28, GOLD, Vector2(36, 34)))
	card.add_child(_label("Enhanced edition", 16, FRAME, Vector2(36, 78)))
	card.add_child(_label(
		"The original Kenney tilemap test level and the pack's p1 alien,\nunchanged underneath: same tiles, same walk / jump / respawn.\nNow with a sky, landing dust, jump trails, a minimap and stats.\nG shows the tile grid and the 170 blank cells of the original.",
		14, INK, Vector2(36, 114)))
	var start := _btn("Start", Vector2(36, 236), Vector2(120, 40))
	start.focus_mode = Control.FOCUS_NONE
	start.pressed.connect(func(): _set_state(PLAY))
	card.add_child(start)
	card.add_child(_label("Enter / Space  to begin", 14, MUTED, Vector2(180, 246)))
	var title_back := _btn("Back to Arcade", Vector2(36, 288), Vector2(160, 32))
	title_back.focus_mode = Control.FOCUS_NONE
	title_back.pressed.connect(GameRegistry.return_to_arcade)
	card.add_child(title_back)


func _panel(r: Rect2) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.add_theme_stylebox_override("panel", _panel_style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(text: String, size: int, color: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _btn(text: String, pos: Vector2, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	for stn in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		var base := Color(0.14, 0.26, 0.16)
		s.bg_color = base.lightened(0.15) if stn == "hover" else base.darkened(0.15) if stn == "pressed" else base
		s.border_color = FRAME
		s.set_border_width_all(2)
		s.set_corner_radius_all(10)
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 4
		s.content_margin_bottom = 6
		b.add_theme_stylebox_override(stn, s)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	return b
