extends RefCounted
## Pixel sprites + palette from artifact BjKJn834. Drawn as ImageTextures.

const PALETTE := {
	"0": Color8(0x0d, 0x0a, 0x14),
	"1": Color8(0x2b, 0x25, 0x36),
	"2": Color8(0x4a, 0x43, 0x60),
	"3": Color8(0x6e, 0x65, 0x82),
	"4": Color8(0xf4, 0xe9, 0xd0),
	"5": Color8(0xf2, 0xb0, 0x3d),
	"6": Color8(0xc7, 0x7d, 0x2a),
	"7": Color8(0x7b, 0xc8, 0x6c),
	"8": Color8(0x4f, 0x9e, 0x54),
	"9": Color8(0x6a, 0xd0, 0xe0),
	"a": Color8(0x3f, 0x8f, 0xb0),
	"b": Color8(0xe0, 0x6a, 0x9c),
	"c": Color8(0xb0, 0x3f, 0x6e),
	"d": Color8(0x8a, 0x6f, 0x4f),
	"e": Color8(0x5e, 0x4a, 0x33),
	"f": Color8(0xe0, 0x5a, 0x4a),
	"g": Color8(0xe8, 0xd2, 0x4a),
	"h": Color8(0x9b, 0x6c, 0xd6),
	"i": Color8(0xc8, 0xc4, 0xd8),
	"j": Color8(0x2e, 0x7d, 0x44),
}

const C_PAGE := Color8(0x07, 0x06, 0x0c)
const C_STAGE := Color8(0x14, 0x10, 0x1c)
const C_PANEL := Color8(0x1c, 0x17, 0x26)
const C_BORDER := Color8(0x4f, 0x47, 0x69)
const C_TEXT := Color8(0xf4, 0xe9, 0xd0)
const C_MUTED := Color8(0x9a, 0x90, 0xb0)
const C_DIM := Color8(0x6e, 0x65, 0x82)
const C_GOLD := Color8(0xf2, 0xb0, 0x3d)
const C_CYAN := Color8(0x6a, 0xd0, 0xe0)
const C_BLUE := Color8(0x3f, 0x8f, 0xb0)
const C_GREEN := Color8(0x7b, 0xc8, 0x6c)
const C_GREEN_BTN := Color8(0x2e, 0x7d, 0x44)
const C_RED := Color8(0xe0, 0x5a, 0x4a)
const C_NAV_ACTIVE := Color8(0x2e, 0x27, 0x40)
const C_SOIL := Color8(0x5e, 0x4a, 0x33)
const C_SOIL2 := Color8(0x8a, 0x6f, 0x4f)
const C_GRASS := Color8(0x2e, 0x5d, 0x3a)
const C_GRASS2 := Color8(0x4f, 0x9e, 0x54)
const C_WATER := Color8(0x3f, 0x8f, 0xb0)
const C_ROCK := Color8(0x4a, 0x43, 0x60)

const SPRITES := {
	"ship": [
		".......00.......", "......0440......", "......0440......", "......0440......",
		".....049940.....", ".....049940.....", ".....044440.....", "....04444440....",
		"....04444440....", "...0444444440...", "...0455555540...", "...0444444440...",
		"..044444444440..", "..040044004400..", ".040..0440..040.", "......g..g......",
	],
	"station": [
		"......0000......", "....00....00....", "...0..3333..0...", "..0..3iiii3..0..",
		"..0.3iaaaai3.0..", "..0.3ia99ai3.0..", "..0.3ia99ai3.0..", "..0.3iaaaai3.0..",
		"..0..3iiii3..0..", "...0..3333..0...", "....00....00....", ".......00.......",
		"....0000000.....", "...0.......0....", "...0.......0....", "................",
	],
	"sprout": [
		"........", "...7....", "..7.7...", "...8....", "..787...", "...8....", "..888...", "........",
	],
	"drop": [
		"...0....", "..090...", "..090...", ".09990..", ".09990..", ".099a0..", "..000...", "........",
	],
	"fuel": [
		".000000.", ".064460.", ".066660.", ".055550.", ".055550.", ".0g55g0.", ".066660.", ".000000.",
	],
	"ore": [
		"........", "..000...", ".0ii30..", "0iaai30.", "0aaaii0.", ".0aai0..", "..000...", "........",
	],
	"crew": [
		"..0000..", ".066660.", ".044440.", ".040040.", ".044440.", ".04bb40.", ".044440.", "..0000..",
	],
	"cargo": [
		"00000000", "06655660", "06655660", "00000000", "06655660", "06655660", "00000000", "........",
	],
	"radar": [
		"..0aa0..", ".0a99a0.", "0a9999a0", "0a99g9a0", "0a9999a0", ".0a99a0.", "..0aa0..", "....0...",
	],
	"book": [
		".000000.", "04444440", "04555540", "04444440", "04555540", "04444440", "04555540", ".000000.",
	],
	"star": [
		"...5....", "...5....", ".5.5.5..", "..555...", "5555555.", "..555...", ".5.5.5..", "...5....",
	],
	"glowmelon": [
		"................", "......7.........", "......8.........", "....88888.......",
		"...8777j778.....", "..877j77j778....", ".8777j77j7778...", ".877j77j77j78...",
		".8777j77j7778...", ".877j77j77j78...", ".8777j77j7778...", "..877j77j778....",
		"...87777778.....", "....888888......", "................", "................",
	],
	"voidwheat": [
		".......5........", "......555.......", ".....55655......", ".....55655......",
		"......555.......", ".....55655......", ".....55655......", "......555.......",
		".....55655......", "......666.......", ".......6........", ".......6........",
		"......868.......", ".....8.6.8......", "....8..6..8.....", "................",
	],
	"starberry": [
		"................", "......78........", ".....788........", "......b.........",
		"....bbbbb.......", "...bcbbbcb......", "...bbbbbbb......", "....bbbbb.......",
		"...bbbbbbb......", "..bcbbbbbcb.....", "..bbbbbbbbb.....", "...bbbbbbb......",
		"....bbbbb.......", ".....bbb........", "................", "................",
	],
	"astrospud": [
		"................", ".....dddd.......", "...dd6dddd......", "..ddddddddd.....",
		"..d6ddddd6d.....", ".ddddddddddd....", ".dd6dddddddd....", ".ddddd6ddddd....",
		"..dddddddd6d....", "..d6dddddddd....", "...dddddddd.....", "....dddddd......",
		".....dddd.......", "................", "................", "................",
	],
	"nebulakelp": [
		".....9..........", "....99.9........", "...9.999........", "....99.99.......",
		"...99.9.........", "....9.99........", "...99.9.........", "....9a99........",
		"...9a.9.........", "....a99.........", "...9a.a.........", "....aa..........",
		".....a..........", "....8a8.........", "...8...8........", "................",
	],
	## Simple pixel tractor (custom — not in mock).
	"tractor": [
		"................", "................", "......5555......", ".....555555.....",
		"....55555555....", "...55gg55gg55...", "...5555555555...", "..555555555555..",
		"..550055550055..", ".55000055000055.", ".50000050000005.", ".50000050000005.",
		"..500005000005..", "...0000..0000...", "................", "................",
	],
}

static var _cache: Dictionary = {}


static func sprite(name: String) -> ImageTexture:
	if _cache.has(name):
		return _cache[name]
	if not SPRITES.has(name):
		return null
	var rows: Array = SPRITES[name]
	var h: int = rows.size()
	var w: int = str(rows[0]).length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row := str(rows[y])
		for x in mini(w, row.length()):
			var ch := row[x]
			if ch == ".":
				continue
			if PALETTE.has(ch):
				img.set_pixel(x, y, PALETTE[ch])
	var tex := ImageTexture.create_from_image(img)
	_cache[name] = tex
	return tex


static func planet_tex(kind: String) -> ImageTexture:
	var key := "planet_" + kind
	if _cache.has(key):
		return _cache[key]
	var base: Color
	var light: Color
	var ocean: Color
	var shadow: Color
	match kind:
		"lush":
			base = Color8(0x4f, 0x9e, 0x54); light = Color8(0x7b, 0xc8, 0x6c)
			ocean = Color8(0x3f, 0x8f, 0xb0); shadow = Color8(0x2e, 0x5d, 0x3a)
		"rock":
			base = Color8(0x8a, 0x6f, 0x4f); light = Color8(0xb0, 0x8a, 0x5f)
			ocean = Color8(0x6e, 0x65, 0x82); shadow = Color8(0x4a, 0x3a, 0x28)
		"ice":
			base = Color8(0x9f, 0xd8, 0xe0); light = Color8(0xe8, 0xf6, 0xf8)
			ocean = Color8(0x6a, 0xd0, 0xe0); shadow = Color8(0x5a, 0x8f, 0xa0)
		_:
			base = Color8(0x6e, 0x65, 0x82); light = Color8(0xc8, 0xc4, 0xd8)
			ocean = Color8(0x3f, 0x8f, 0xb0); shadow = Color8(0x2b, 0x25, 0x36)
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := 7.5
	var cy := 7.5
	var r := 7.7
	for y in size:
		for x in size:
			var dx := float(x) - cx
			var dy := float(y) - cy
			var d := sqrt(dx * dx + dy * dy)
			if d > r:
				continue
			var n := sin(x * 1.8 + y) + cos(x * 0.7 - y * 1.4)
			var col := base
			if n > 0.8:
				col = light
			elif n < -0.8:
				col = ocean
			if dx + dy < -5.0:
				col = light
			if dx + dy > 5.5:
				col = shadow
			if d > r - 1.0:
				col = shadow
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
