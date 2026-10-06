extends Control
## TermGrid — 80×25 CP437 character-cell terminal (JKVM-style CHB/FGB/BGB).
## Glyphs: IBM VGA 8×16 from arcade/assets/ibm_vga_8x16.png (dosfont.py).
## Colors: xterm-256 indices (0..15 = ANSI). Palette idx 3 = VGA brown.

signal cell_clicked(col: int, row: int, button: int)
signal cell_hovered(col: int, row: int)  ## (-1, -1) when the mouse leaves

const ATLAS_PATH := "res://arcade/assets/ibm_vga_8x16.png"
const GLYPH_W := 8
const GLYPH_H := 16
const ATLAS_COLS := 32

## CP437 byte → Unicode (IBM code page 437). Plain Array so it is a GDScript const.
const CP437_UNICODE := [
	0x0000, 0x263A, 0x263B, 0x2665, 0x2666, 0x2663, 0x2660, 0x2022, 0x25D8, 0x25CB, 0x25D9, 0x2642, 0x2640, 0x266A, 0x266B, 0x263C,
	0x25BA, 0x25C4, 0x2195, 0x203C, 0x00B6, 0x00A7, 0x25AC, 0x21A8, 0x2191, 0x2193, 0x2192, 0x2190, 0x221F, 0x2194, 0x25B2, 0x25BC,
	0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027, 0x0028, 0x0029, 0x002A, 0x002B, 0x002C, 0x002D, 0x002E, 0x002F,
	0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037, 0x0038, 0x0039, 0x003A, 0x003B, 0x003C, 0x003D, 0x003E, 0x003F,
	0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047, 0x0048, 0x0049, 0x004A, 0x004B, 0x004C, 0x004D, 0x004E, 0x004F,
	0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057, 0x0058, 0x0059, 0x005A, 0x005B, 0x005C, 0x005D, 0x005E, 0x005F,
	0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067, 0x0068, 0x0069, 0x006A, 0x006B, 0x006C, 0x006D, 0x006E, 0x006F,
	0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077, 0x0078, 0x0079, 0x007A, 0x007B, 0x007C, 0x007D, 0x007E, 0x2302,
	0x00C7, 0x00FC, 0x00E9, 0x00E2, 0x00E4, 0x00E0, 0x00E5, 0x00E7, 0x00EA, 0x00EB, 0x00E8, 0x00EF, 0x00EE, 0x00EC, 0x00C4, 0x00C5,
	0x00C9, 0x00E6, 0x00C6, 0x00F4, 0x00F6, 0x00F2, 0x00FB, 0x00F9, 0x00FF, 0x00D6, 0x00DC, 0x00A2, 0x00A3, 0x00A5, 0x20A7, 0x0192,
	0x00E1, 0x00ED, 0x00F3, 0x00FA, 0x00F1, 0x00D1, 0x00AA, 0x00BA, 0x00BF, 0x2310, 0x00AC, 0x00BD, 0x00BC, 0x00A1, 0x00AB, 0x00BB,
	0x2591, 0x2592, 0x2593, 0x2502, 0x2524, 0x2561, 0x2562, 0x2556, 0x2555, 0x2563, 0x2551, 0x2557, 0x255D, 0x255C, 0x255B, 0x2510,
	0x2514, 0x2534, 0x252C, 0x251C, 0x2500, 0x253C, 0x255E, 0x255F, 0x255A, 0x2554, 0x2569, 0x2566, 0x2560, 0x2550, 0x256C, 0x2567,
	0x2568, 0x2564, 0x2565, 0x2559, 0x2558, 0x2552, 0x2553, 0x256B, 0x256A, 0x2518, 0x250C, 0x2588, 0x2584, 0x258C, 0x2590, 0x2580,
	0x03B1, 0x00DF, 0x0393, 0x03C0, 0x03A3, 0x03C3, 0x00B5, 0x03C4, 0x03A6, 0x0398, 0x03A9, 0x03B4, 0x221E, 0x03C6, 0x03B5, 0x2229,
	0x2261, 0x00B1, 0x2265, 0x2264, 0x2320, 0x2321, 0x00F7, 0x2248, 0x00B0, 0x2219, 0x00B7, 0x221A, 0x207F, 0x00B2, 0x25A0, 0x00A0,
]


@export var grid_wh := Vector2i(80, 25)
## Integer scale of the 8×16 VGA cell (2 → 16×32, stage 1280×800).
@export var pixel_scale := 2
@export var cell_wh := Vector2(16, 32)
@export var font_size := 24  ## unused with VGA atlas; kept for API compat

var CHB := PackedInt32Array()
var FGB := PackedByteArray()
var BGB := PackedByteArray()
var pal: PackedColorArray = make_palette()

var _hover := Vector2i(-1, -1)
var _atlas: Texture2D
var _u2cp := {}  ## unicode → CP437 index


func _init() -> void:
	_build_u2cp()
	cell_wh = Vector2(GLYPH_W * pixel_scale, GLYPH_H * pixel_scale)
	cscr()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	cell_wh = Vector2(GLYPH_W * pixel_scale, GLYPH_H * pixel_scale)
	custom_minimum_size = Vector2(grid_wh) * cell_wh
	_atlas = load(ATLAS_PATH) as Texture2D
	mouse_exited.connect(func() -> void: _set_hover(Vector2i(-1, -1)))


func _build_u2cp() -> void:
	_u2cp.clear()
	for i in CP437_UNICODE.size():
		var u: int = CP437_UNICODE[i]
		if not _u2cp.has(u):
			_u2cp[u] = i
	# Common aliases / ASCII already covered; ensure space.
	_u2cp[32] = 32


func cscr(fg: int = 7, bg: int = 0) -> void:
	var n := grid_wh.x * grid_wh.y
	CHB.resize(n); CHB.fill(32)
	FGB.resize(n); FGB.fill(fg)
	BGB.resize(n); BGB.fill(bg)
	queue_redraw()


func put(x: int, y: int, ch: String, fg: int = 7, bg: int = 0) -> void:
	if x < 0 or y < 0 or x >= grid_wh.x or y >= grid_wh.y:
		return
	var p := y * grid_wh.x + x
	CHB[p] = ch.unicode_at(0) if ch != "" else 32
	FGB[p] = fg
	BGB[p] = bg
	queue_redraw()


func put_cp(x: int, y: int, cp: int, fg: int = 7, bg: int = 0) -> void:
	## Write by CP437 byte (0..255); stores matching Unicode in CHB.
	if x < 0 or y < 0 or x >= grid_wh.x or y >= grid_wh.y:
		return
	var p := y * grid_wh.x + x
	var u: int = CP437_UNICODE[cp & 0xFF] if cp >= 0 and cp < 256 else 32
	CHB[p] = u
	FGB[p] = fg
	BGB[p] = bg
	queue_redraw()


func puts(x: int, y: int, s: String, fg: int = 7, bg: int = 0) -> int:
	for i in s.length():
		put(x + i, y, s[i], fg, bg)
	return x + s.length()


func char_at(x: int, y: int) -> String:
	return char(CHB[y * grid_wh.x + x])


func fg_at(x: int, y: int) -> int:
	return FGB[y * grid_wh.x + x]


func row_text(y: int) -> String:
	var s := ""
	for x in grid_wh.x:
		s += char_at(x, y)
	return s


func cell_at(pos: Vector2) -> Vector2i:
	var c := Vector2i((pos / cell_wh).floor())
	if c.x < 0 or c.y < 0 or c.x >= grid_wh.x or c.y >= grid_wh.y:
		return Vector2i(-1, -1)
	return c


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_set_hover(cell_at(e.position))
	elif e is InputEventMouseButton and e.pressed:
		var c := cell_at(e.position)
		if c.x >= 0 and e.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			cell_clicked.emit(c.x, c.y, e.button_index)
			accept_event()


func _set_hover(c: Vector2i) -> void:
	if c != _hover:
		_hover = c
		cell_hovered.emit(c.x, c.y)


func _cp_of(u: int) -> int:
	if _u2cp.has(u):
		return int(_u2cp[u])
	if u >= 32 and u <= 126:
		return u
	return 63  ## '?'


func _draw() -> void:
	if _atlas == null:
		_atlas = load(ATLAS_PATH) as Texture2D
	draw_rect(Rect2(Vector2.ZERO, Vector2(grid_wh) * cell_wh), pal[0])
	for y in grid_wh.y:
		for x in grid_wh.x:
			var p := y * grid_wh.x + x
			var xy := Vector2(x, y) * cell_wh
			var bg_i: int = BGB[p]
			if bg_i != 0:
				draw_rect(Rect2(xy, cell_wh), pal[bg_i])
			var u: int = CHB[p]
			if u == 32 or FGB[p] == BGB[p]:
				continue
			var cp := _cp_of(u)
			var sx := (cp % ATLAS_COLS) * GLYPH_W
			var sy := (cp / ATLAS_COLS) * GLYPH_H
			var src := Rect2(sx, sy, GLYPH_W, GLYPH_H)
			if _atlas:
				draw_texture_rect_region(_atlas, Rect2(xy, cell_wh), src, pal[FGB[p]])



## CPU blit of the current buffers into an Image (tests / screenshots).
func render_to_image() -> Image:
	if _atlas == null:
		_atlas = load(ATLAS_PATH) as Texture2D
	var w := grid_wh.x * int(cell_wh.x)
	var h := grid_wh.y * int(cell_wh.y)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(pal[0])
	var atlas_img: Image = _atlas.get_image() if _atlas else null
	if atlas_img == null:
		return img
	var cw := int(cell_wh.x)
	var ch := int(cell_wh.y)
	for y in grid_wh.y:
		for x in grid_wh.x:
			var p := y * grid_wh.x + x
			var dx := x * cw
			var dy := y * ch
			if BGB[p] != 0:
				img.fill_rect(Rect2i(dx, dy, cw, ch), pal[BGB[p]])
			var u: int = CHB[p]
			if u == 32 or FGB[p] == BGB[p]:
				continue
			var cp := _cp_of(u)
			var sx := (cp % ATLAS_COLS) * GLYPH_W
			var sy := (cp / ATLAS_COLS) * GLYPH_H
			var glyph := atlas_img.get_region(Rect2i(sx, sy, GLYPH_W, GLYPH_H))
			if cw != GLYPH_W or ch != GLYPH_H:
				glyph.resize(cw, ch, Image.INTERPOLATE_NEAREST)
			var fg: Color = pal[FGB[p]]
			for gy in ch:
				for gx in cw:
					var s := glyph.get_pixel(gx, gy)
					if s.a > 0.5:
						img.set_pixel(dx + gx, dy + gy, fg)
	return img

static func make_palette() -> PackedColorArray:
	var res := PackedColorArray()
	var ansi := [
		0x000000, # black
		0xaa0000, # red
		0x00aa00, # green
		0xaa5500, # VGA brown (was xterm dark-yellow)
		0x0000aa, # blue
		0xaa00aa, # magenta
		0x00aaaa, # cyan
		0xaaaaaa, # gray
		0x555555, # dark gray
		0xff5555, # light red
		0x55ff55, # light green
		0xffff55, # yellow
		0x5555ff, # light blue
		0xff55ff, # light magenta
		0x55ffff, # light cyan
		0xffffff ]# white
	for a in ansi:
		res.append(Color.hex(a * 0x100 + 0xff))
	var ramp := [0x00, 0x5F, 0x87, 0xAF, 0xD7, 0xFF]
	for r in ramp:
		for g in ramp:
			for b in ramp:
				res.append(Color.hex(((r << 16) + (g << 8) + b) * 0x100 + 0xff))
	var grays := [
		0x00, 0x12, 0x1C, 0x26, 0x30, 0x3A, 0x44, 0x4E,
		0x58, 0x62, 0x6C, 0x76, 0x80, 0x8A, 0x94, 0x9E,
		0xA8, 0xB2, 0xBC, 0xC6, 0xD0, 0xDA, 0xE4, 0xEE]
	for v in grays:
		res.append(Color.hex(((v << 16) + (v << 8) + v) * 0x100 + 0xff))
	return res
