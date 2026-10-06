extends Control
## Spiders v. Aliens Enhanced: HUD and screens, drawn at the arcade's native 1280x720 (not the
## pixel-scaled stage), so text and panels stay crisp. Reads the shared simulation through
## `game` (game.gd); never mutates it.

const Logic := preload("res://games/spiders_v_aliens/direct/sva_logic.gd")
const Level := preload("res://games/spiders_v_aliens/direct/level_alien_ship.gd")
const DIR := "res://games/spiders_v_aliens/direct/"
const FONT_FILE := preload(DIR + "fonts/nokiafc22.ttf")
const HEART := preload(DIR + "sprites/heart.png")
const OPENING1_IMG := preload(DIR + "sprites/opening-01.png")
const OPENING2_IMG := preload(DIR + "sprites/opening-02.png")
const SHIP := preload(DIR + "sprites/ship.png")
const CAST := [
	[preload(DIR + "sprites/hero.png"), "Ernie"],
	[preload(DIR + "sprites/spider.png"), "gut spider"],
	[preload(DIR + "sprites/alien.png"), "Dentist"],
	[preload(DIR + "sprites/geist.png"), "mimeogeist"],
]

const INK := Color(0.93, 0.96, 1.0)
const DIM := Color(0.62, 0.70, 0.82)
const NEON := Color(0.30, 0.95, 1.0)
const WARN := Color(1.0, 0.70, 0.30)
const DANGER := Color(1.0, 0.35, 0.35)
const GOOD := Color(0.45, 1.0, 0.60)
const PANEL := Color(0.03, 0.05, 0.10, 0.82)

const MAP_SCALE := 2.0

var game = null
var font: FontFile
var map_full: Image
var map_fog: Image
var map_tex: ImageTexture
var _box: StyleBoxFlat
var _vignette: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = FONT_FILE.duplicate()
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_box = StyleBoxFlat.new()
	_box.set_corner_radius_all(6)
	_box.set_border_width_all(2)
	_box.shadow_size = 6
	_box.shadow_color = Color(0, 0, 0, 0.45)
	_vignette = GradientTexture2D.new()
	_vignette.width = 256
	_vignette.height = 256
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.5)
	_vignette.fill_to = Vector2(1.05, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.75))
	g.add_point(0.55, Color(0, 0, 0, 0.0))
	_vignette.gradient = g
	_build_map()


# --- minimap ------------------------------------------------------------------
func _build_map() -> void:
	var w: int = Level.MAP_ENVIRONMENT_W
	var data: Array = Level.MAP_ENVIRONMENT
	var h: int = data.size() / w
	var collide: int = Level.TILEMAPS[1][7]
	map_full = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for i in data.size():
		var v: int = data[i]
		var c := Color(0, 0, 0, 0)
		if v >= collide:
			c = Color(0.15, 0.75, 0.95, 1.0)
		elif v >= 1:
			c = Color(0.20, 0.24, 0.33, 0.95)
		map_full.set_pixel(i % w, i / w, c)
	map_fog = Image.create(w, h, false, Image.FORMAT_RGBA8)
	map_tex = ImageTexture.create_from_image(map_fog)


func reset_map() -> void:
	if map_fog == null:
		return
	map_fog.fill(Color(0, 0, 0, 0))
	map_tex.update(map_fog)


func _tile_of(p: Vector2) -> Vector2i:
	var row: Array = Level.TILEMAPS[1]
	return Vector2i(int(floor((p.x - row[1]) / row[3])), int(floor((p.y - row[2]) / row[4])))


func _reveal(p: Vector2) -> void:
	var t := _tile_of(p)
	var r := Rect2i(t - Vector2i(14, 9), Vector2i(29, 19))
	r = r.intersection(Rect2i(Vector2i.ZERO, map_full.get_size()))
	if r.size.x > 0 and r.size.y > 0:
		map_fog.blit_rect(map_full, r, r.position)


func revealed(p: Vector2) -> bool:
	var t := _tile_of(p)
	if t.x < 0 or t.y < 0 or t.x >= map_fog.get_width() or t.y >= map_fog.get_height():
		return false
	return map_fog.get_pixelv(t).a > 0.0


# --- text helpers ------------------------------------------------------------
func _text(p: Vector2, s: String, sz := 16, col := INK, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	if s.is_empty():
		return
	draw_string(font, (p + Vector2(0, font.get_ascent(sz))).floor(), s, align, width, sz, col)


func _text_shadow(p: Vector2, s: String, sz := 16, col := INK, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var o := maxf(1.0, floor(sz / 8.0))
	_text(p + Vector2(o, o), s, sz, Color(0, 0, 0, col.a * 0.85), align, width)
	_text(p, s, sz, col, align, width)


func _center(y: float, s: String, sz := 16, col := INK) -> void:
	_text_shadow(Vector2(0, y), s, sz, col, HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _glow_title(y: float, s: String, sz: int) -> void:
	for d in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		_text(Vector2(0, y) + d, s, sz, Color(NEON, 0.22), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_text(Vector2(0, y + 4), s, sz, Color(0, 0, 0, 0.8), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_text(Vector2(0, y), s, sz, INK, HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _panel(r: Rect2, border := NEON, fill := PANEL) -> void:
	_box.bg_color = fill
	_box.border_color = Color(border, border.a * 0.75)
	draw_style_box(_box, r)


func _keycap(p: Vector2, key: String, col := INK) -> float:
	var w := maxf(22.0, font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 10.0)
	var r := Rect2(p, Vector2(w, 22))
	draw_rect(r, Color(0.08, 0.1, 0.16, 0.95))
	draw_rect(r, Color(col, 0.9), false, 2.0)
	_text(p + Vector2(0, 3), key, 16, col, HORIZONTAL_ALIGNMENT_CENTER, w)
	return w


func _wrap_lines(s: String, sz: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" "):
			var trial := word if line.is_empty() else line + " " + word
			if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > width and not line.is_empty():
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return out


func _blink(rate := 2.0) -> bool:
	return fmod(game.time * rate, 1.0) < 0.6


# --- draw ---------------------------------------------------------------------
func _draw() -> void:
	if game == null:
		return
	var w = game.world
	var vr: Rect2 = game.view_rect()
	draw_texture_rect(_vignette, vr, false)
	match w.state:
		Logic.MENU:
			_draw_menu()
		Logic.OPENING1, Logic.OPENING2:
			_draw_opening(w)
		Logic.PLAY:
			_draw_play(w)
		Logic.DEATH:
			_draw_play(w, false)
			_draw_death(w)
		Logic.WIN:
			_draw_play(w, false)
			_draw_win(w)
	if game.hurt_flash > 0.0:
		draw_rect(vr, Color(0.9, 0.05, 0.05, 0.28 * game.hurt_flash))
	if game.fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, game.fade))


func _draw_menu() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.01, 0.04, 0.45))
	var cy := size.y * 0.5
	_center(cy - 250, "ERNIE GOLDSMILE, ATTORNEY AT LAW", 16, DIM)
	_center(cy - 222, "in:", 16, DIM)
	_glow_title(cy - 190, "SPIDERS v. ALIENS", 48)
	_center(cy - 120, "ENHANCED EDITION", 16, NEON)
	# the cast, bobbing
	var n := CAST.size()
	var span := 150.0
	var x0 := size.x * 0.5 - span * (n - 1) * 0.5
	for i in n:
		var tex: Texture2D = CAST[i][0]
		var bob := sin(game.time * 2.2 + i * 1.3) * 4.0
		var p := Vector2(x0 + i * span - 24, cy - 70 + bob)
		draw_circle(p + Vector2(24, 30), 38.0, Color(0.55, 0.75, 0.95, 0.18))
		draw_circle(p + Vector2(24, 30), 30.0, Color(0.70, 0.85, 1.0, 0.22))
		draw_texture_rect_region(tex, Rect2(p + Vector2(3, 6), Vector2(48, 60)), Rect2(0, 0, 16, 20), Color(0, 0, 0, 0.4))
		draw_texture_rect_region(tex, Rect2(p, Vector2(48, 60)), Rect2(0, 0, 16, 20))
		_text_shadow(Vector2(x0 + i * span - 70, cy + 0), CAST[i][1], 16, DIM, HORIZONTAL_ALIGNMENT_CENTER, 140)
	# controls card
	var card := Rect2(size.x * 0.5 - 330, cy + 40, 660, 150)
	_panel(card)
	var rows := [
		[["Arrows"], "move (the mimeogeist copies you)"],
		[["W", "A", "S", "D"], "hold to grab / drag / use machines"],
		[["G"], "mimeogeist camera"],
		[["M", "H"], "map  /  grab hints"],
	]
	var y := card.position.y + 16
	for r in rows:
		var x := card.position.x + 24
		for k in r[0]:
			x += _keycap(Vector2(x, y), k, NEON) + 6
		_text_shadow(Vector2(card.position.x + 250, y + 3), r[1], 16, INK)
		y += 32
	_text(Vector2(card.position.x, card.end.y + 6), "Dvorak: , O A E also grab", 8, DIM, HORIZONTAL_ALIGNMENT_RIGHT, card.size.x)
	if _blink():
		_center(size.y - 108, "PRESS SPACE TO BEGIN", 24, INK)
	_center(size.y - 72, "Enter: skip the prologue      Esc: pause / back to arcade", 16, DIM)
	_center(size.y - 36, "Ludum Dare 21 \"Escape\" - Michal J Wallace, 2011", 8, Color(DIM, 0.8))


func _draw_opening(w) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.01, 0.04, 0.6))
	var img: Texture2D = OPENING1_IMG if w.state == Logic.OPENING1 else OPENING2_IMG
	var art := Rect2(96, 92, 540, 520)
	_panel(art.grow(10), NEON, Color(0, 0, 0, 0.9))
	draw_texture_rect(img, art, false)
	var tx := Rect2(680, 150, 520, 420)
	_panel(tx)
	var part := "PROLOGUE  1 / 2" if w.state == Logic.OPENING1 else "PROLOGUE  2 / 2"
	_text_shadow(tx.position + Vector2(24, 20), part, 16, NEON)
	var tt = w.opening_type
	var lines := _wrap_lines(tt.text, 16, tx.size.x - 48)
	var y := tx.position.y + 64
	for i in lines.size():
		_text_shadow(Vector2(tx.position.x + 24, y), lines[i], 16, INK)
		y += 26
	if tt.finished and _blink():
		var last := lines[lines.size() - 1] if lines.size() > 0 else ""
		var lx := font.get_string_size(last, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_rect(Rect2(tx.position.x + 26 + lx, y - 24, 10, 18), NEON)
	_center(size.y - 70, "Space: continue      Enter: skip to the ship", 16, DIM)


func _draw_play(w, interactive := true) -> void:
	var vr: Rect2 = game.view_rect()
	# hearts (top-left)
	var hp: float = w.hero.health
	var hx := vr.position.x + 24
	var hy := vr.position.y + 20
	_panel(Rect2(hx - 12, hy - 10, 252, 108), NEON, Color(0.03, 0.05, 0.1, 0.6))
	for i in Logic.HERO_MAX_HEALTH:
		var frame := 1 if i + 1 > hp else 0
		var pulse := 1.0
		if frame == 0 and hp <= 1.0:
			pulse = 1.0 + 0.12 * sin(game.time * 9.0)
		var sz := Vector2(32, 40) * pulse
		var p := Vector2(hx + i * 36, hy) - (sz - Vector2(32, 40)) * 0.5
		draw_texture_rect_region(HEART, Rect2(p, sz), Rect2(frame * 16, 0, 16, 20))
	if hp > Logic.HERO_MAX_HEALTH:
		_text_shadow(Vector2(hx + 5 * 36 - 4, hy + 10), "+%d" % int(hp - Logic.HERO_MAX_HEALTH), 16, GOOD)
	var locks := "LOCKS %d/%d" % [game.locks_open(), game.locks_total()]
	_text_shadow(Vector2(hx, hy + 48), locks, 16, GOOD if game.locks_open() > 0 else DIM)
	_text_shadow(Vector2(hx + 112, hy + 48), "DENTISTS %d" % game.alive_aliens(), 16, DIM)
	_text_shadow(Vector2(hx, hy + 70), _clock(game.play_time), 16, DIM)
	if w.toggle_cam and interactive:
		_center(vr.position.y + 24, "MIMEOGEIST CAMERA  (G to return)", 16, Color(0.8, 0.6, 1.0))
	if game.show_map:
		_draw_map(w, vr)
	if interactive and game.show_hints:
		_draw_prompts(w)
	_draw_narration(w, vr)


func _clock(t: float) -> String:
	var s := int(t)
	return "TIME %d:%02d" % [s / 60, s % 60]


func _draw_map(w, vr: Rect2) -> void:
	if Engine.get_process_frames() % 6 == 0 or map_tex.get_size() == Vector2.ZERO:
		_reveal(Vector2(w.hero.x, w.hero.y))
		if w.geist != null:
			_reveal(Vector2(w.geist.x, w.geist.y))
		map_tex.update(map_fog)
	var msz := Vector2(map_full.get_size()) * MAP_SCALE
	var mp := Vector2(vr.end.x - msz.x - 22, vr.position.y + 20)
	_panel(Rect2(mp - Vector2(10, 10), msz + Vector2(20, 34)), NEON, Color(0.02, 0.03, 0.07, 0.72))
	draw_texture_rect(map_tex, Rect2(mp, msz), false)
	var to_map := func(p: Vector2) -> Vector2:
		var row: Array = Level.TILEMAPS[1]
		return mp + Vector2((p.x - row[1]) / row[3], (p.y - row[2]) / row[4]) * MAP_SCALE
	# camera frame
	var tl: Vector2 = to_map.call(game.cam_topleft)
	var br: Vector2 = to_map.call(game.cam_topleft + game.VIEW)
	var cam := Rect2(tl, br - tl).intersection(Rect2(mp, msz))
	draw_rect(cam, Color(1, 1, 1, 0.25), false, 1.0)
	for k in w.keys:
		if k.exists and revealed(Vector2(k.x, k.y)):
			draw_rect(Rect2(to_map.call(Vector2(k.x, k.y)) - Vector2(2, 2), Vector2(5, 5)), Color(1.0, 0.85, 0.2))
	for m in w.machines:
		if m.kind == "KeyBox" and revealed(Vector2(m.x, m.y)):
			draw_rect(Rect2(to_map.call(Vector2(m.x, m.y)) - Vector2(2, 2), Vector2(5, 5)), GOOD if m.has_power else DANGER)
	if w.exit_obj != null and revealed(Vector2(w.exit_obj.x, w.exit_obj.y)):
		draw_rect(Rect2(to_map.call(Vector2(w.exit_obj.x, w.exit_obj.y)) - Vector2(3, 3), Vector2(7, 7)), GOOD, false, 2.0)
	if w.geist != null:
		draw_circle(to_map.call(Vector2(w.geist.x + 8, w.geist.y + 10)), 3.0, Color(0.75, 0.55, 1.0))
	var hp: Vector2 = to_map.call(Vector2(w.hero.x + 8, w.hero.y + 10))
	draw_circle(hp, 5.0 if _blink(3.0) else 3.5, Color(1.0, 0.75, 0.2))
	_text(Vector2(mp.x, mp.y + msz.y + 6), "M: hide map", 8, DIM)
	var lx := mp.x + msz.x - 112
	for item in [[Color(1.0, 0.85, 0.2), "key"], [DANGER, "lock"], [GOOD, "exit"]]:
		draw_rect(Rect2(lx, mp.y + msz.y + 9, 5, 5), item[0])
		_text(Vector2(lx + 8, mp.y + msz.y + 6), item[1], 8, DIM)
		lx += 38


func _draw_prompts(w) -> void:
	var av = w.cam_target
	if av == null:
		return
	var s: float = game.view_scale()
	var mid: Vector2 = game.world_to_screen(Vector2(av.x + av.w * 0.5, av.y + av.h * 0.5))
	for p in game.prompts:
		var dir: int = p["dir"]
		var col := NEON
		if p["danger"]:
			col = DANGER
		elif not p["active"]:
			col = WARN
		elif p["held"]:
			col = Color(1.0, 0.95, 0.5)
		var label: String = p["text"]
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var bw := tw + 22 + 16
		var bh := 30.0
		# park the prompt just beyond the thing it talks about, never on top of it
		var t = p["target"]
		var tr := Rect2(game.world_to_screen(Vector2(t.x, t.y)), Vector2(t.w, t.h) * s)
		var at := mid
		match dir:
			Logic.DIR_N:
				at = Vector2(tr.get_center().x - bw * 0.5, tr.position.y - bh - 6)
			Logic.DIR_S:
				at = Vector2(tr.get_center().x - bw * 0.5, tr.end.y + 6)
			Logic.DIR_W:
				at = Vector2(tr.position.x - bw - 6, tr.get_center().y - bh * 0.5)
			_:
				at = Vector2(tr.end.x + 6, tr.get_center().y - bh * 0.5)
		at = at.floor()
		_panel(Rect2(at, Vector2(bw, bh)), col, Color(0.02, 0.04, 0.08, 0.85))
		_keycap(at + Vector2(4, 4), p["key"], col)
		_text_shadow(at + Vector2(32, 7), label, 16, col)


func _draw_narration(w, vr: Rect2) -> void:
	var tt = w.hud_text
	if tt.full.is_empty():
		return
	var pw := minf(860.0, vr.size.x - 80)
	var lines := _wrap_lines(tt.full, 16, pw - 120)
	var ph := 34.0 + lines.size() * 26.0
	var r := Rect2(vr.position.x + (vr.size.x - pw) * 0.5, vr.end.y - ph - 24, pw, ph)
	_panel(r, Color(1.0, 0.8, 0.45), Color(0.04, 0.04, 0.08, 0.86))
	# little portrait of Ernie
	var hero_tex: Texture2D = CAST[0][0]
	draw_texture_rect_region(hero_tex, Rect2(r.position + Vector2(18, 14), Vector2(48, 60)), Rect2(0, 0, 16, 20))
	var shown := _wrap_lines(tt.text, 16, pw - 120)
	var y := r.position.y + 18
	for i in shown.size():
		_text_shadow(Vector2(r.position.x + 92, y), shown[i], 16, INK)
		y += 26
	if tt.finished and _blink():
		var last := shown[shown.size() - 1] if shown.size() > 0 else ""
		var lx := font.get_string_size(last, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_rect(Rect2(r.position.x + 94 + lx, y - 24, 10, 18), Color(1.0, 0.8, 0.45))


func _draw_death(w) -> void:
	var vr: Rect2 = game.view_rect()
	draw_rect(vr, Color(0.25, 0.0, 0.02, 0.5))
	var card := Rect2(size.x * 0.5 - 300, size.y * 0.5 - 130, 600, 250)
	_panel(card, DANGER)
	_glow_title(card.position.y + 28, "GAME OVER", 48)
	_center(card.position.y + 100, "The Dentists got their appointment.", 16, DIM)
	_center(card.position.y + 130, "%s     Dentists down: %d" % [_clock(game.play_time), maxi(0, game.aliens_at_start - game.alive_aliens())], 16, INK)
	_center(card.position.y + 178, "R: retry now      Space: title screen", 16, NEON if _blink() else INK)


func _draw_win(w) -> void:
	var vr: Rect2 = game.view_rect()
	draw_rect(vr, Color(0.0, 0.06, 0.04, 0.55))
	# the Consolas breaks away
	var t := fmod(game.time * 0.25, 1.0)
	var sp := Vector2(lerpf(vr.position.x - 200, vr.end.x + 40, t), vr.position.y + 90 + sin(game.time * 2.0) * 10)
	draw_set_transform(sp + Vector2(80, 50), deg_to_rad(180.0), Vector2(2, 2))
	draw_texture_rect(SHIP, Rect2(Vector2(-40, -25), Vector2(80, 50)), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var card := Rect2(size.x * 0.5 - 330, size.y * 0.5 - 110, 660, 250)
	_panel(card, GOOD)
	_glow_title(card.position.y + 28, "YOU ESCAPED!", 48)
	_center(card.position.y + 100, "The Consolas breaks free of the Dentist ship.", 16, DIM)
	var hp := int(w.hero.health)
	_center(card.position.y + 132, "%s     Hearts left: %d     Dentists down: %d" % [_clock(game.play_time), hp, maxi(0, game.aliens_at_start - game.alive_aliens())], 16, INK)
	_center(card.position.y + 180, "Space: title screen", 16, GOOD if _blink() else INK)
