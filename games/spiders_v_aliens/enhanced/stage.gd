extends SubViewport
## Spiders v. Aliens Enhanced: the world view.
## A SubViewport rendered at an integer multiple (`ss`) of the 854x480 world view, then
## downsampled by game.gd's TextureRect with linear filtering ("sharp bilinear"): every texel
## stays the same size at the arcade's non-integer 1.5x, with no nearest-neighbour shimmer.
##
## Static layers (Outside starfield, Environment, Decorations, GeistWall) are TileMapLayers built
## once from the generated Direct level data; sprites are drawn from the live Direct simulation.
## Lighting is a per-pixel shader (lighting.gdshader) fed with world-space lights each frame.

const Logic := preload("res://games/spiders_v_aliens/direct/sva_logic.gd")
const Level := preload("res://games/spiders_v_aliens/direct/level_alien_ship.gd")
const DIR := "res://games/spiders_v_aliens/direct/"
const LIGHT_SHADER := preload("res://games/spiders_v_aliens/enhanced/lighting.gdshader")
const STARS_SHADER := preload("res://games/spiders_v_aliens/enhanced/stars.gdshader")
const BACKDROP_SHADER := preload("res://games/spiders_v_aliens/enhanced/backdrop.gdshader")

const TILESETS := {
	"Outside": preload(DIR + "sprites/startiles.png"),
	"Environment": preload(DIR + "sprites/environment.png"),
	"Decorations": preload(DIR + "sprites/railings.png"),
	"GeistWall": preload(DIR + "sprites/geistwall.png"),
}
const MAPS := {
	"Outside": [Level.MAP_OUTSIDE, Level.MAP_OUTSIDE_W],
	"Environment": [Level.MAP_ENVIRONMENT, Level.MAP_ENVIRONMENT_W],
	"Decorations": [Level.MAP_DECORATIONS, Level.MAP_DECORATIONS_W],
	"GeistWall": [Level.MAP_GEISTWALL, Level.MAP_GEISTWALL_W],
}
const SPRITES := {
	"Hero": preload(DIR + "sprites/hero.png"),
	"Geist": preload(DIR + "sprites/geist.png"),
	"Spider": preload(DIR + "sprites/spider.png"),
	"Alien": preload(DIR + "sprites/alien.png"),
	"Box": preload(DIR + "sprites/box.png"),
	"Key": preload(DIR + "sprites/key.png"),
	"Heart": preload(DIR + "sprites/heart.png"),
	"Exit": preload(DIR + "sprites/exit.png"),
	"HeroShip": preload(DIR + "sprites/ship.png"),
	"KeyBox": preload(DIR + "sprites/keybox.png"),
	"Portal": preload(DIR + "sprites/portal.png"),
	"Cannon": preload(DIR + "sprites/cannon.png"),
	"SwitchBox": preload(DIR + "sprites/switchbox.png"),
	"Bullet": preload(DIR + "sprites/bullet.png"),
	"Grabber": preload(DIR + "sprites/grabbers.png"),
}

const VIEW := Vector2(854, 480)
const MAX_LIGHTS := 32
## Decorations tiles 13/14/15 are the left cap / middle / right cap of a fluorescent fixture.
const FIXTURE_L := 13
const FIXTURE_R := 15

const AMBIENT_PLAY := Vector3(0.36, 0.40, 0.54)
const AMBIENT_BACKDROP := Vector3(0.30, 0.32, 0.44)

var world: Logic = null
var ss := 2                       ## supersample factor (viewport px per world texel)
var cam_topleft := Vector2.ZERO
var time := 0.0
var show_actors := false
var geist_hint := false           ## faintly show the (normally invisible) GeistWall
var marks: Array = []             ## [{target: Obj, color: Color}] interactables to outline
var fixtures: Array = []          ## Vector3(x, y, length_px) per fluorescent fixture
var light_count := 0

var camera: Camera2D
var layers := {}
var actors: Node2D
var glow: Node2D
var overlay: Node2D
var flares: Node2D
var _backdrop_mat: ShaderMaterial
var _stars_mat: ShaderMaterial
var _mats: Array[ShaderMaterial] = []
var _halo: GradientTexture2D


func _init() -> void:
	size = Vector2i(VIEW) * ss
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	transparent_bg = false
	disable_3d = true
	handle_input_locally = false
	gui_disable_input = true


func _ready() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_mat = ShaderMaterial.new()
	_backdrop_mat.shader = BACKDROP_SHADER
	bg.material = _backdrop_mat
	bg_layer.add_child(bg)

	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camera.position_smoothing_enabled = false
	add_child(camera)

	_halo = GradientTexture2D.new()
	_halo.width = 64
	_halo.height = 64
	_halo.fill = GradientTexture2D.FILL_RADIAL
	_halo.fill_from = Vector2(0.5, 0.5)
	_halo.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.35, Color(1, 1, 1, 0.45))
	_halo.gradient = grad

	_stars_mat = ShaderMaterial.new()
	_stars_mat.shader = STARS_SHADER
	for m in 3:
		var mat := ShaderMaterial.new()
		mat.shader = LIGHT_SHADER
		mat.set_shader_parameter("mode", m)
		_mats.append(mat)

	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	for row in Level.TILEMAPS:
		var layer := _make_layer(row)
		layers[row[0]] = layer
	layers["Outside"].material = _stars_mat
	layers["Environment"].material = _mats[1]
	layers["Decorations"].material = _mats[2]
	layers["GeistWall"].modulate = Color(0.75, 0.5, 1.0, 0.0)

	glow = _canvas("Glow", additive)
	actors = _canvas("Actors", _mats[0])
	overlay = _canvas("Overlay", _mats[0])
	flares = _canvas("Flares", additive)
	# Direct draw order: Outside, Environment, mobiles, machinery, Decorations, (GeistWall),
	# grabbers, then anything dispensed later (bolts). Floor glow slots in under the sprites.
	for n in [layers["Outside"], layers["Environment"], glow, actors, layers["Decorations"],
			layers["GeistWall"], overlay, flares]:
		add_child(n)
	actors.draw.connect(_draw_actors)
	glow.draw.connect(_draw_glow)
	overlay.draw.connect(_draw_overlay)
	flares.draw.connect(_draw_flares)
	_find_fixtures()


func _canvas(n: String, mat: Material) -> Node2D:
	var c := Node2D.new()
	c.name = n
	c.material = mat
	return c


func _make_layer(row: Array) -> TileMapLayer:
	var tm_name: String = row[0]
	var tex: Texture2D = TILESETS[tm_name]
	var tsz := Vector2i(row[3], row[4])
	var ts := TileSet.new()
	ts.tile_size = tsz
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = tsz
	var cols := int(tex.get_width()) / tsz.x
	var rows := int(tex.get_height()) / tsz.y
	for r in rows:
		for c in cols:
			src.create_tile(Vector2i(c, r))
	ts.add_source(src, 0)
	var layer := TileMapLayer.new()
	layer.name = tm_name
	layer.tile_set = ts
	layer.position = Vector2(row[1], row[2])
	var data: Array = MAPS[tm_name][0]
	var w: int = MAPS[tm_name][1]
	var draw_idx: int = row[8]
	for i in data.size():
		var v: int = data[i]
		if v < draw_idx or v >= cols * rows:
			continue
		layer.set_cell(Vector2i(i % w, i / w), 0, Vector2i(v % cols, v / cols))
	return layer


func _find_fixtures() -> void:
	fixtures.clear()
	var row: Array = Level.TILEMAPS[2]
	var data: Array = Level.MAP_DECORATIONS
	var w: int = Level.MAP_DECORATIONS_W
	for i in data.size():
		if data[i] != FIXTURE_L:
			continue
		var c := i % w
		var r := i / w
		var e := c
		while e + 1 < w and data[r * w + e] != FIXTURE_R:
			e += 1
		var len_px: float = float(e - c + 1) * float(row[3])
		fixtures.append(Vector3(row[1] + c * row[3] + len_px / 2.0, row[2] + r * row[4] + row[4] / 2.0, len_px))


func set_supersample(k: int) -> void:
	k = clampi(k, 1, 4)
	if k == ss and size == Vector2i(VIEW) * k:
		return
	ss = k
	size = Vector2i(VIEW) * ss


## Called by game.gd once per rendered frame.
func sync(p_world: Logic, p_cam_topleft: Vector2, p_time: float, p_show_actors: bool) -> void:
	world = p_world
	cam_topleft = p_cam_topleft
	time = p_time
	show_actors = p_show_actors and world != null and world.hero != null
	camera.zoom = Vector2(ss, ss)
	camera.position = cam_topleft
	var outside: TileMapLayer = layers["Outside"]
	var orow: Array = Level.TILEMAPS[0]
	# scrollFactor 0.25: screen = pos - scroll * sf  =>  world = pos + scroll * (1 - sf)
	outside.position = (Vector2(orow[1], orow[2]) + cam_topleft * (1.0 - float(orow[5]))).floor()
	_backdrop_mat.set_shader_parameter("offset", cam_topleft * 0.0004)
	_backdrop_mat.set_shader_parameter("time", time)
	_stars_mat.set_shader_parameter("time", time)
	var gw: TileMapLayer = layers["GeistWall"]
	gw.modulate.a = move_toward(gw.modulate.a, 0.35 if geist_hint and show_actors else 0.0, 0.05)
	_update_lights()
	for n in [glow, actors, overlay, flares]:
		n.visible = show_actors
		n.queue_redraw()


# --- lights -------------------------------------------------------------------
func _view_rect(margin := 0.0) -> Rect2:
	return Rect2(cam_topleft - Vector2(margin, margin), VIEW + Vector2(margin, margin) * 2.0)


func _mid(o) -> Vector2:
	return Vector2(o.x + o.w * 0.5, o.y + o.h * 0.5)


func _update_lights() -> void:
	var cand: Array = []  # [pos, radius, intensity, Color]
	for f in fixtures:
		cand.append([Vector2(f.x, f.y + 14.0), 70.0 + f.z * 0.9, 0.62, Color(0.70, 0.88, 1.0)])
	if show_actors:
		var h = world.hero
		if h.exists:
			cand.append([_mid(h), 175.0, 0.85, Color(1.0, 0.86, 0.62)])
		var g = world.geist
		if g != null and g.exists:
			cand.append([_mid(g), 75.0, 0.6, Color(0.75, 0.55, 1.0)])
		for m in world.machines:
			if not m.exists:
				continue
			match m.kind:
				"Portal":
					if m.has_power:
						cand.append([_mid(m), 52.0, 0.55, Color(0.35, 1.0, 0.55)])
				"Cannon":
					if m.has_power:
						cand.append([_mid(m), 44.0, 0.45, Color(1.0, 0.55, 0.25)])
				"KeyBox", "SwitchBox":
					if m.has_power:
						cand.append([_mid(m), 40.0, 0.45, Color(0.35, 1.0, 0.55)])
					else:
						cand.append([_mid(m), 34.0, 0.4, Color(1.0, 0.25, 0.2)])
		for b in world.bullets:
			if b.exists:
				cand.append([_mid(b), 80.0, 1.1, Color(1.0, 0.2, 0.25)])
		for p in world.pickups:
			if p.exists:
				cand.append([_mid(p), 40.0, 0.5, Color(1.0, 0.45, 0.65)])
		for k in world.keys:
			if k.exists:
				cand.append([_mid(k), 36.0, 0.5, Color(1.0, 0.85, 0.3)])
		if world.exit_obj != null:
			cand.append([_mid(world.exit_obj), 70.0, 0.7, Color(0.4, 1.0, 0.6)])
	var vr := _view_rect()
	var center := cam_topleft + VIEW * 0.5
	var vis: Array = []
	for l in cand:
		var r: float = l[1]
		if vr.grow(r).has_point(l[0]):
			vis.append(l)
	vis.sort_custom(func(a, b): return a[0].distance_squared_to(center) < b[0].distance_squared_to(center))
	var pos := PackedVector4Array()
	var cols := PackedVector4Array()
	pos.resize(MAX_LIGHTS)
	cols.resize(MAX_LIGHTS)
	light_count = mini(vis.size(), MAX_LIGHTS)
	for i in light_count:
		var l: Array = vis[i]
		var c: Color = l[3]
		pos[i] = Vector4(l[0].x, l[0].y, l[1], l[2])
		cols[i] = Vector4(c.r, c.g, c.b, 1.0)
	var amb := AMBIENT_PLAY if show_actors else AMBIENT_BACKDROP
	for mat in _mats:
		mat.set_shader_parameter("light_count", light_count)
		mat.set_shader_parameter("lights", pos)
		mat.set_shader_parameter("light_colors", cols)
		mat.set_shader_parameter("time", time)
		mat.set_shader_parameter("ambient", amb)


# --- sprites ------------------------------------------------------------------
func _frame_size(o) -> Vector2:
	return Vector2(80, 50) if o.kind == "HeroShip" else Vector2(16, 20)


func _visible(o) -> bool:
	if not o.exists or not o.visible:
		return false
	var fs := _frame_size(o)
	var big := maxf(o.w, o.h) + maxf(fs.x, fs.y)
	return _view_rect(big).has_point(Vector2(o.x, o.y))


func _draw_obj(ci: CanvasItem, o, col := Color.WHITE, offset := Vector2.ZERO) -> void:
	var tex: Texture2D = SPRITES[o.kind]
	var fs := _frame_size(o)
	var at := Vector2(floor(o.x - o.off_x), floor(o.y - o.off_y)) + offset
	var src := Rect2(o.frame * fs.x, 0, fs.x, fs.y)
	if o.angle == 0.0 and o.scale_x == 1.0 and o.scale_y == 1.0:
		ci.draw_texture_rect_region(tex, Rect2(at, fs), src, col)
		return
	var origin := fs * 0.5
	ci.draw_set_transform_matrix(Transform2D(deg_to_rad(o.angle), Vector2(o.scale_x, o.scale_y), 0.0, at + origin))
	ci.draw_texture_rect_region(tex, Rect2(-origin, fs), src, col)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func _held_things() -> Dictionary:
	var held := {}
	for g in world.grabber_list:
		if g.exists and g.content != null and g.content.exists:
			held[g.content] = true
	return held


func _draw_actors() -> void:
	if not show_actors:
		return
	var shadow := Color(0, 0, 0, 0.38)
	for o in world.mobiles_group:
		if _visible(o) and o.kind != "HeroShip" and o.kind != "Geist":
			_draw_obj(actors, o, shadow, Vector2(1, 2))
	var held := _held_things()
	var won := world.state == Logic.WIN
	for group in [world.mobiles_group, world.machinery_group]:
		for o in group:
			if not _visible(o):
				continue
			if won and o.kind == "HeroShip":
				continue  # the Consolas has left the dock (hud.gd flies her off)
			var col := Color.WHITE
			if o == world.hero and o.stun > 0.0:
				col.a = 0.35 if int(time * 14.0) % 2 == 0 else 1.0
			elif o.kind == "Geist":
				col = Color(1, 1, 1, 0.78 + 0.12 * sin(time * 3.0))
			if held.has(o):
				_draw_obj(actors, o, Color(0, 0, 0, 0.3), Vector2(2, 4))
				_draw_obj(actors, o, col, Vector2(0, -1))
			else:
				_draw_obj(actors, o, col)


func _draw_overlay() -> void:
	if not show_actors:
		return
	for g in world.grabber_list:
		if _visible(g):
			_draw_obj(overlay, g, Color(1, 1, 1, 0.92))
	for o in world.dispensed:
		if _visible(o):
			_draw_obj(overlay, o)


func _halo_at(ci: CanvasItem, p: Vector2, r: float, c: Color) -> void:
	ci.draw_texture_rect(_halo, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, c)


func _draw_glow() -> void:
	if not show_actors:
		return
	for m in world.machines:
		if not _visible(m):
			continue
		if m.kind == "Portal" and m.has_power:
			_halo_at(glow, _mid(m), 22.0 + 2.0 * sin(time * 4.0 + m.x), Color(0.2, 0.9, 0.45, 0.35))
		elif (m.kind == "KeyBox" or m.kind == "SwitchBox") and not m.has_power:
			_halo_at(glow, _mid(m), 16.0, Color(0.9, 0.15, 0.1, 0.25 + 0.15 * sin(time * 5.0)))
		elif m.kind == "Cannon" and not m.has_power:
			_halo_at(glow, _mid(m), 16.0, Color(1.0, 0.6, 0.1, 0.35))
	for k in world.keys:
		if _visible(k):
			_halo_at(glow, _mid(k), 18.0, Color(1.0, 0.8, 0.2, 0.35))
	for p in world.pickups:
		if _visible(p):
			_halo_at(glow, _mid(p), 16.0 + sin(time * 5.0), Color(1.0, 0.3, 0.5, 0.35))
	if world.exit_obj != null and _visible(world.exit_obj):
		_halo_at(glow, _mid(world.exit_obj), 26.0 + 3.0 * sin(time * 3.0), Color(0.3, 1.0, 0.5, 0.4))
	var g = world.geist
	if g != null and _visible(g):
		_halo_at(glow, _mid(g), 20.0, Color(0.6, 0.4, 1.0, 0.35))


func _draw_flares() -> void:
	if not show_actors:
		return
	for b in world.bullets:
		if _visible(b):
			var p := _mid(b)
			_halo_at(flares, p, 14.0, Color(1.0, 0.2, 0.2, 0.7))
			_halo_at(flares, p - Vector2(b.vx, b.vy) * 0.08, 10.0, Color(1.0, 0.3, 0.2, 0.35))
	# interactable outlines (QoL): additive pulse around whatever a grab key would act on
	var pulse := 0.55 + 0.45 * sin(time * 6.0)
	for m in marks:
		var t = m["target"]
		if t == null or not t.exists:
			continue
		var c: Color = m["color"]
		c.a *= pulse
		flares.draw_rect(Rect2(floor(t.x) - 1.0, floor(t.y) - 1.0, t.w + 2.0, t.h + 2.0), c, false, 1.0)
	for f in fixtures:
		var p := Vector2(f.x, f.y)
		if _view_rect(40.0).has_point(p):
			flares.draw_texture_rect(_halo, Rect2(p - Vector2(f.z * 0.6, 9.0), Vector2(f.z * 1.2, 18.0)), false, Color(0.6, 0.85, 1.0, 0.18))
