extends RefCounted
## Procedural pixel tile atlas for Doth Direct (SvA-like, not 1-bit, not CP437).
## 16×16 tiles, nearest-neighbour friendly. No third-party art.

const TILE := 16
const COLS := 8

enum Id { FLOOR, WALL, HERO, COIN, GEM, HEART, AMMO, BOULDER, TITLE_BRICK }


static func build_atlas() -> ImageTexture:
	var img := Image.create(COLS * TILE, TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_paint_floor(img, Id.FLOOR)
	_paint_wall(img, Id.WALL)
	_paint_hero(img, Id.HERO)
	_paint_coin(img, Id.COIN)
	_paint_gem(img, Id.GEM)
	_paint_heart(img, Id.HEART)
	_paint_ammo(img, Id.AMMO)
	_paint_boulder(img, Id.BOULDER)
	var tex := ImageTexture.create_from_image(img)
	return tex


static func src(id: int) -> Rect2:
	return Rect2(id * TILE, 0, TILE, TILE)


static func _px(img: Image, base: Vector2i, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= TILE or y >= TILE:
		return
	img.set_pixel(base.x + x, base.y + y, c)


static func _fill(img: Image, base: Vector2i, c: Color) -> void:
	for y in TILE:
		for x in TILE:
			_px(img, base, x, y, c)


static func _paint_floor(img: Image, id: int) -> void:
	var b := Vector2i(id * TILE, 0)
	var a := Color(0.12, 0.18, 0.28)
	var d := Color(0.10, 0.15, 0.24)
	for y in TILE:
		for x in TILE:
			_px(img, b, x, y, a if ((x + y) % 4 < 2) else d)
	# subtle grit
	_px(img, b, 3, 5, Color(0.16, 0.22, 0.32))
	_px(img, b, 11, 9, Color(0.16, 0.22, 0.32))


static func _paint_wall(img: Image, id: int) -> void:
	var b := Vector2i(id * TILE, 0)
	# blue brick (echoes dtitle.cel brick field, not copied pixels)
	var mortar := Color(0.15, 0.20, 0.35)
	var brick := Color(0.28, 0.42, 0.78)
	var hi := Color(0.40, 0.55, 0.92)
	var sh := Color(0.18, 0.28, 0.55)
	_fill(img, b, mortar)
	for row in 4:
		var y0 := row * 4
		var shift := 0 if row % 2 == 0 else 4
		for col in range(-1, 5):
			var x0 := col * 8 + shift
			for yy in range(1, 3):
				for xx in range(1, 7):
					var c := brick
					if yy == 1 and xx <= 2:
						c = hi
					elif yy == 2 and xx >= 5:
						c = sh
					_px(img, b, x0 + xx, y0 + yy, c)


static func _paint_hero(img: Image, id: int) -> void:
	var b := Vector2i(id * TILE, 0)
	_fill(img, b, Color(0, 0, 0, 0))
	# yellow adventurer (doth_a hero atr $0E)
	var body := Color(0.95, 0.85, 0.25)
	var outline := Color(0.35, 0.25, 0.05)
	var cloak := Color(0.20, 0.55, 0.90)
	for y in range(4, 14):
		for x in range(5, 11):
			_px(img, b, x, y, body)
	for x in range(6, 10):
		_px(img, b, x, 3, body)
		_px(img, b, x, 14, cloak)
	for y in range(5, 12):
		_px(img, b, 4, y, outline)
		_px(img, b, 11, y, outline)
	_px(img, b, 7, 6, Color(0.1, 0.1, 0.1))
	_px(img, b, 9, 6, Color(0.1, 0.1, 0.1))


static func _paint_coin(img: Image, id: int) -> void:
	var b := Vector2i(id * TILE, 0)
	_fill(img, b, Color(0, 0, 0, 0))
	var gold := Color(0.95, 0.80, 0.15)
	var dark := Color(0.70, 0.50, 0.05)
	for y in range(4, 12):
		for x in range(4, 12):
			var dx := x - 7.5
			var dy := y - 7.5
			if dx * dx + dy * dy <= 16.0:
				_px(img, b, x, y, gold if dx + dy < 2 else dark)
	_px(img, b, 7, 7, Color(1, 0.95, 0.5))
	_px(img, b, 8, 7, Color(1, 0.95, 0.5))


static func _paint_gem(img: Image, id: int) -> void:
	var b := Vector2i(id * TILE, 0)
	_fill(img, b, Color(0, 0, 0, 0))
	var gem := Color(0.85, 0.20, 0.35)  # gematr $04 red-ish
	var hi := Color(1.0, 0.55, 0.65)
	# diamond
	for i in range(0, 6):
		for x in range(8 - i, 8 + i + 1):
			_px(img, b, x, 3 + i, gem if i > 1 else hi)
	for i in range(0, 5):
		for x in range(4 + i, 12 - i + 1):
			_px(img, b, x, 9 + i, gem)


static func _paint_heart(img: Image, id: int) -> void:
	var b := Vector2i(id * TILE, 0)
	_fill(img, b, Color(0, 0, 0, 0))
	var red := Color(0.90, 0.18, 0.28)
	var dots := [
		Vector2i(5, 5), Vector2i(6, 4), Vector2i(7, 5), Vector2i(8, 4), Vector2i(9, 5),
		Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6), Vector2i(9, 6), Vector2i(10, 6),
		Vector2i(4, 7), Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7), Vector2i(8, 7), Vector2i(9, 7), Vector2i(10, 7),
		Vector2i(5, 8), Vector2i(6, 8), Vector2i(7, 8), Vector2i(8, 8), Vector2i(9, 8),
		Vector2i(6, 9), Vector2i(7, 9), Vector2i(8, 9), Vector2i(7, 10),
	]
	for p in dots:
		_px(img, b, p.x, p.y, red)


static func _paint_ammo(img: Image, id: int) -> void:
	var b := Vector2i(id * TILE, 0)
	_fill(img, b, Color(0, 0, 0, 0))
	var shell := Color(0.75, 0.75, 0.70)
	var tip := Color(0.95, 0.55, 0.15)
	for y in range(4, 13):
		_px(img, b, 7, y, shell)
		_px(img, b, 8, y, shell)
	_px(img, b, 7, 3, tip)
	_px(img, b, 8, 3, tip)
	_px(img, b, 6, 12, shell)
	_px(img, b, 9, 12, shell)


static func _paint_boulder(img: Image, id: int) -> void:
	var b := Vector2i(id * TILE, 0)
	_fill(img, b, Color(0, 0, 0, 0))
	var rock := Color(0.55, 0.52, 0.48)
	var dark := Color(0.35, 0.32, 0.30)
	var hi := Color(0.72, 0.70, 0.65)
	for y in range(3, 14):
		for x in range(3, 13):
			var dx := x - 7.5
			var dy := y - 8.0
			if dx * dx + dy * dy <= 22.0:
				var c := rock
				if dx + dy < -2:
					c = hi
				elif dx + dy > 3:
					c = dark
				_px(img, b, x, y, c)
