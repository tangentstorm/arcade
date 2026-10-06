extends RefCounted
## Spiders v. Aliens: Direct edition simulation.
## A port of com/tangentcode/sva/*.as (AS3 + Flixel 2.55, Ludum Dare 21, 2011) plus the parts
## of Flixel 2.55 the game leans on: FlxObject.updateMotion / separateX / separateY,
## FlxTilemap.overlapsWithCallback / ray, FlxG.overlap / collide, FlxCamera follow + shake,
## TeleType. One step() is one Flixel frame at the fixed 60 Hz (FlxG.elapsed = 1/60).
## Rendering lives in game.gd; this file never touches a node.

const Level := preload("res://games/spiders_v_aliens/direct/level_alien_ship.gd")

const DT := 1.0 / 60.0
const STAGE_W := 640
const STAGE_H := 480
const CELL_W := 16
const CELL_H := 20

# SvA.N/S/W/E (also the grabber frame order)
const DIR_N := 0
const DIR_S := 1
const DIR_W := 2
const DIR_E := 3

enum { MENU, OPENING1, OPENING2, PLAY, DEATH, WIN }

const OVERLAP_BIAS := 4.0
const NO_MAX := 10000.0
const BIG := 1.79769e308  # Number.MAX_VALUE

const HUD_HEIGHT := 64
const HUD_PADDING := 4
const HERO_MAX_HEALTH := 5
const HERO_STUN := 2.5
const REBOOT_LENGTH := 0.5
const BULLET_SPEED := 75.0
const GRID := 64.0

const OPENING1_TEXT := "The Dentists grabbed me outside the Rushmore spaceport.\nThey had me on their table. I should have been a dead man.\n\nBut then..."
const OPENING2_TEXT := "Turns out Dentists don't much care for Arnaxian spider venom.\nGut spiders. Sick. All this time I thought it was acid reflux.\n\nI crack a smile as the anesthesia finally takes control.\nThe world goes dark..."


class Obj:
	var kind := ""
	var x := 0.0
	var y := 0.0
	var w := 16.0
	var h := 20.0
	var lx := 0.0
	var ly := 0.0
	var vx := 0.0
	var vy := 0.0
	var ax := 0.0
	var ay := 0.0
	var dragx := 0.0
	var dragy := 0.0
	var maxvx := 10000.0
	var maxvy := 10000.0
	var mass := 1.0
	var immovable := false
	var solid := true
	var exists := true
	var alive := true
	var visible := true
	var health := 1.0
	var frame := 0
	var captive := false
	# Powered / Machine
	var has_power := false
	var reboot_count := 0.0
	var send_power: Array = []
	var other_side: Obj = null
	# Avatar
	var grabbers: Array = []
	# Hero
	var was_hurt := false
	var stun := 0.0
	# Grabber
	var owner: Obj = null
	var content: Obj = null
	var done := false
	# Narration
	var text := ""
	# Tilemap (kind == "Tilemap")
	var tm_name := ""
	var data: PackedInt32Array
	var wt := 0
	var ht := 0
	var tw := 16
	var th := 20
	var collide_idx := 1
	var draw_idx := 1
	var has_solid := false
	# rendering (scrollFactor, angle, scale, offset)
	var sf := 1.0
	var angle := 0.0
	var scale_x := 1.0
	var scale_y := 1.0
	var off_x := 0.0
	var off_y := 0.0

	func _init(p_kind := "", px := 0.0, py := 0.0) -> void:
		kind = p_kind
		x = px
		y = py
		lx = px
		ly = py

	func is_tilemap() -> bool:
		return kind == "Tilemap"

	func is_capturable() -> bool:
		return kind == "Alien" or kind == "Spider"

	func is_machine() -> bool:
		return kind == "KeyBox" or kind == "Portal" or kind == "Cannon" or kind == "SwitchBox"

	func is_avatar() -> bool:
		return kind == "Hero" or kind == "Geist"

	func kill() -> void:
		exists = false
		alive = false


class TeleType:
	var full := ""
	var text := ""
	var counter := 0
	var finished := true

	func set_full(t: String) -> void:
		text = ""
		counter = 0
		full = t
		finished = t.length() == 0

	func update() -> void:
		if not finished:
			text = full.substr(0, counter)
			counter += 1
			finished = counter > full.length()


var rng := RandomNumberGenerator.new()
var state := MENU
var _requested := MENU
var frame_count := 0

# input for the current step
var _held := {}
var _just := {}

# play state
var hero: Obj
var geist: Obj
var exit_obj: Obj
var tm_outside: Obj
var tm_env: Obj
var tm_deco: Obj
var tm_geistwall: Obj
var master_layer: Array = []   # flattened masterLayer, in DAME layer order
var mobiles_group: Array = []
var machinery_group: Array = []
var spiders: Array = []
var aliens: Array = []
var machines: Array = []
var keys: Array = []
var boxes: Array = []
var pickups: Array = []
var bullets: Array = []
var narration: Array = []
var grabber_list: Array = []    # mGrabbers: hero N,S,W,E then geist N,S,W,E
var dispensed: Array = []       # objects add()ed to the state after create()
var hud_hearts: Array = []
var hud_text := TeleType.new()
var _old_text := ""
var _new_text := ""
var _grab_last := [false, false, false, false]
var toggle_cam := false
var cam_target: Obj

# camera
var scroll_x := 0.0
var scroll_y := 0.0
var shake_x := 0.0
var shake_y := 0.0
var _shake_t := 0.0
var _shake_i := 0.0
const BOUNDS_W := CELL_W * 40 * 4   # 2560
const BOUNDS_H := CELL_H * 25 * 4   # 2000

# menu / opening text
var opening_type := TeleType.new()

# events for the audio layer
var music_start := false
var music_on := false


func _init(start_state := MENU, seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	_requested = start_state
	_switch(start_state)


## Obj is RefCounted; grabbers <-> owner and portal twins form cycles.
## Call when dropping a world (game.gd does on _exit_tree).
func dispose() -> void:
	_break_cycles()


func _break_cycles() -> void:
	for o in master_layer:
		o.grabbers = []
		o.other_side = null
		o.send_power = []
	for g in grabber_list:
		g.owner = null
		g.content = null


## Input: {"held": {name: bool}, "just": {name: bool}} with names
## up/down/left/right, w/a/s/d, comma/o/e, g, space.
func step(input := {}) -> void:
	_held = input.get("held", {})
	_just = input.get("just", {})
	music_start = false
	if _requested != state:
		_switch(_requested)
	frame_count += 1
	match state:
		MENU:
			if _just.get("space", false):
				_requested = OPENING1
		OPENING1:
			opening_type.update()
			if _just.get("space", false):
				_requested = OPENING2
		OPENING2:
			opening_type.update()
			if _just.get("space", false):
				_requested = PLAY
		PLAY:
			_play_update()
		DEATH, WIN:
			if _held.get("space", false):
				_requested = MENU


func _switch(s: int) -> void:
	state = s
	_requested = s
	scroll_x = 0.0
	scroll_y = 0.0
	shake_x = 0.0
	shake_y = 0.0
	_shake_t = 0.0
	match s:
		OPENING1:
			opening_type.set_full(OPENING1_TEXT)
		OPENING2:
			opening_type.set_full(OPENING2_TEXT)
		PLAY:
			_create_play()


# ----------------------------------------------------------------------------- level
func _make_tilemap(row: Array) -> Obj:
	var t := Obj.new("Tilemap", row[1], row[2])
	t.tm_name = row[0]
	t.tw = row[3]
	t.th = row[4]
	t.sf = row[5]
	t.collide_idx = row[7]
	t.draw_idx = row[8]
	match t.tm_name:
		"Outside":
			t.data = PackedInt32Array(Level.MAP_OUTSIDE)
			t.wt = Level.MAP_OUTSIDE_W
		"Environment":
			t.data = PackedInt32Array(Level.MAP_ENVIRONMENT)
			t.wt = Level.MAP_ENVIRONMENT_W
		"Decorations":
			t.data = PackedInt32Array(Level.MAP_DECORATIONS)
			t.wt = Level.MAP_DECORATIONS_W
		"GeistWall":
			t.data = PackedInt32Array(Level.MAP_GEISTWALL)
			t.wt = Level.MAP_GEISTWALL_W
	t.ht = t.data.size() / t.wt
	for v in t.data:
		if v >= t.collide_idx:
			t.has_solid = true
			break
	t.w = t.wt * t.tw
	t.h = t.ht * t.th
	t.immovable = true
	return t


func _make_sprite(kind: String, px: float, py: float) -> Obj:
	var o := Obj.new(kind, px, py)
	match kind:
		"Hero", "Geist":
			o.maxvx = 100.0
			o.maxvy = 100.0
			o.dragx = 750.0
			o.dragy = 750.0
			if kind == "Hero":
				o.health = HERO_MAX_HEALTH
			else:
				o.solid = false
			for d in 4:
				var g := Obj.new("Grabber")
				g.frame = d
				g.owner = o
				g.exists = false
				position_obj(g, d, o)
				o.grabbers.append(g)
		"Alien":
			o.maxvx = 75.0
			o.maxvy = 75.0
			o.dragx = 500.0
			o.dragy = 500.0
		"Box":
			o.dragx = 150.0
			o.dragy = 150.0
		"KeyBox", "Portal", "Cannon", "SwitchBox":
			o.immovable = true
			o.mass = BIG
			o.maxvx = 0.0
			o.maxvy = 0.0
			o.dragx = BIG
			o.dragy = BIG
			# Powered(): startPowered() ? addPower() : cutPower()
			if kind == "KeyBox" or kind == "SwitchBox":
				cut_power(o)
			else:
				add_power(o)
		"HeroShip":
			o.w = 80.0
			o.h = 50.0
	return o


func _create_play() -> void:
	_break_cycles()
	master_layer = []
	mobiles_group = []
	machinery_group = []
	spiders = []
	aliens = []
	machines = []
	keys = []
	boxes = []
	pickups = []
	bullets = []
	narration = []
	grabber_list = []
	dispensed = []
	hud_hearts = []
	hero = null
	geist = null
	exit_obj = null
	_grab_last = [false, false, false, false]
	toggle_cam = false
	_old_text = ""
	_new_text = ""
	hud_text = TeleType.new()

	tm_outside = _make_tilemap(Level.TILEMAPS[0])
	tm_env = _make_tilemap(Level.TILEMAPS[1])
	tm_deco = _make_tilemap(Level.TILEMAPS[2])
	tm_geistwall = _make_tilemap(Level.TILEMAPS[3])
	tm_geistwall.visible = false

	# addShapesForLayerNarration -> onAddObject(TextData) -> new Narration
	for n in Level.NARRATION:
		var s := Obj.new("Narration", n[0], n[1])
		s.w = n[2]
		s.h = n[3]
		s.text = n[4]
		narration.append(s)

	var linked := {}
	for layer in [Level.MOBILES, Level.MACHINERY]:
		var group: Array = mobiles_group if layer == Level.MOBILES else machinery_group
		for row in layer:
			var o := _make_sprite(row[0], row[1], row[2])
			# addSpriteToLayer: angle + scale (HeroShip is 3 x 2.8, rotated 270.2)
			o.angle = row[4]
			if row[5] != 1.0 or row[6] != 1.0:
				o.scale_x = row[5]
				o.scale_y = row[6]
				var fw := o.w
				var fh := o.h
				o.w *= o.scale_x
				o.h *= o.scale_y
				o.off_x -= (o.w - fw) / 2.0
				o.off_y -= (o.h - fh) / 2.0
			group.append(o)
			if row[3] >= 0:
				linked[row[3]] = o
			_on_add_object(o, row[7])
	for l in Level.LINKS:
		var a: Obj = linked[l[0]]
		var b: Obj = linked[l[1]]
		if a.kind == "Portal":
			a.other_side = b
			b.other_side = a
		elif a.is_machine():
			a.send_power.append(b)

	master_layer = [tm_outside, tm_env]
	master_layer.append_array(mobiles_group)
	master_layer.append_array(machinery_group)
	master_layer.append(tm_deco)
	master_layer.append(tm_geistwall)

	assert(hero != null and geist != null)
	grabber_list.append_array(hero.grabbers)
	grabber_list.append_array(geist.grabbers)
	for g in grabber_list:
		reposition(g)
	cam_target = hero

	# HUD hearts
	hero.health = HERO_MAX_HEALTH
	for i in HERO_MAX_HEALTH:
		var hh := Obj.new("Heart",
				STAGE_W - HUD_PADDING - (HERO_MAX_HEALTH + 0.5 - i) * CELL_W,
				STAGE_H - HUD_HEIGHT + HUD_PADDING)
		hh.sf = 0.0
		hud_hearts.append(hh)

	_camera_update()
	music_start = true
	music_on = true


func _on_add_object(o: Obj, props: Dictionary) -> void:
	if o.dragx == 0.0:
		o.dragx = 50.0
		o.dragy = 50.0
	var start_dead: bool = props.get("startDead", false)
	var has_pow: bool = props.get("hasPower", false)
	match o.kind:
		"Alien":
			aliens.append(o)
			if start_dead:
				alien_hurt(o)
		"Box":
			boxes.append(o)
		"Exit":
			exit_obj = o
		"Hero":
			hero = o
		"Geist":
			geist = o
		"Key":
			keys.append(o)
		"KeyBox", "Portal", "Cannon", "SwitchBox":
			machines.append(o)
			if has_pow:
				add_power(o)
			else:
				cut_power(o)
		"Heart":
			pickups.append(o)
		"Spider":
			spiders.append(o)


## mDraggable: boxes, keys, spiders, aliens
func draggable() -> Array:
	var a: Array = boxes.duplicate()
	a.append_array(keys)
	a.append_array(spiders)
	a.append_array(aliens)
	return a


## mMobiles: hero + mDraggable
func mobiles() -> Array:
	var a: Array = [hero]
	a.append_array(draggable())
	return a


func weapons() -> Array:
	var a: Array = spiders.duplicate()
	a.append_array(bullets)
	return a


# ----------------------------------------------------------------------------- SvA helpers
static func sgn(a: float) -> int:
	if a < 0:
		return -1
	if a > 0:
		return 1
	return 0


static func move_to(o: Obj, px: float, py: float) -> void:
	o.x = px
	o.y = py
	o.lx = px
	o.ly = py


static func position_obj(what: Obj, dir: int, rel: Obj) -> void:
	var cx := rel.x + rel.w / 2.0 - what.w / 2.0
	var cy := rel.y + rel.h / 2.0 - what.h / 2.0
	match dir:
		DIR_N: move_to(what, cx, rel.y - what.h)
		DIR_S: move_to(what, cx, rel.y + rel.h)
		DIR_W: move_to(what, rel.x - what.w, cy)
		DIR_E: move_to(what, rel.x + rel.w, cy)


# ----------------------------------------------------------------------------- Powered / Machine
func add_power(o: Obj) -> void:
	o.has_power = true
	o.frame = 1
	for p in o.send_power:
		add_power(p)


func cut_power(o: Obj) -> void:
	o.has_power = false
	o.frame = 0
	for p in o.send_power:
		cut_power(p)


func reboot(o: Obj) -> void:
	cut_power(o)
	o.reboot_count = REBOOT_LENGTH


func machine_activate(m: Obj, dir: int, by_whom: Obj) -> Obj:
	match m.kind:
		"Portal":
			if m.has_power and m.other_side != null:
				position_obj(by_whom, dir, m.other_side)
			return null
		"KeyBox":
			return null
		"SwitchBox":
			if m.has_power:
				cut_power(m)
			else:
				add_power(m)
			return null
		"Cannon":
			if not m.has_power:
				return null
			var b := Obj.new("Bullet")
			position_obj(b, dir, m)
			reboot(m)
			match dir:
				DIR_N: b.vy = -BULLET_SPEED
				DIR_S: b.vy = BULLET_SPEED
				DIR_E: b.vx = BULLET_SPEED
				DIR_W: b.vx = -BULLET_SPEED
			return b
	return null


# ----------------------------------------------------------------------------- Grabber
func reposition(g: Obj) -> void:
	var ox := g.x
	var oy := g.y
	position_obj(g, g.frame, g.owner)
	if g.content != null and g.content.exists:
		move_to(g.content, g.content.x + g.x - ox, g.content.y + g.y - oy)


func grab(g: Obj, thing: Obj) -> void:
	if thing == null:
		if g.content != null and g.content.is_capturable():
			g.content.captive = false
		if g.content != null:
			g.content.vx = g.owner.vx
			g.content.vy = g.owner.vy
	elif thing.is_capturable():
		thing.captive = true
	g.content = thing


# ----------------------------------------------------------------------------- hurt
func alien_hurt(a: Obj) -> void:
	if a.alive:
		a.alive = false
		a.frame = 1


func hero_hurt(damage: float) -> void:
	hero.stun = HERO_STUN
	hero.was_hurt = true
	hero.health -= damage
	if hero.health <= 0:
		hero.kill()
	if not hero.alive:
		_requested = DEATH


func hurt(o: Obj, damage: float) -> void:
	if o.kind == "Alien":
		alien_hurt(o)
	elif o.kind == "Hero":
		hero_hurt(damage)
	else:
		o.health -= damage
		if o.health <= 0:
			o.kill()


# ----------------------------------------------------------------------------- PlayState.update
func _play_update() -> void:
	var gk := [
		_held.get("w", false) or _held.get("comma", false),
		_held.get("s", false) or _held.get("o", false),
		_held.get("a", false),
		_held.get("d", false) or _held.get("e", false),
	]
	var avatars := [hero, geist]
	for dir in 4:
		for av in avatars:
			var g: Obj = av.grabbers[dir]
			reposition(g)
			if gk[dir]:
				g.exists = true
				g.done = false
				if not _grab_last[dir]:
					overlap([g], machines, _on_grab_machine)
					overlap([g], draggable(), _on_grab_draggable)
			else:
				g.exists = false
				grab(g, null)
		_grab_last[dir] = gk[dir]

	_chase_hero(aliens, 50.0)
	_chase_hero(spiders, 15.0, 25.0)

	for av in avatars:
		av.ax = 0.0
		av.ay = 0.0
	if _held.get("up", false):
		for av in avatars: av.ay += -200.0
	if _held.get("left", false):
		for av in avatars: av.ax += -200.0
	if _held.get("down", false):
		for av in avatars: av.ay += 200.0
	if _held.get("right", false):
		for av in avatars: av.ax += 200.0

	if _just.get("g", false):
		toggle_cam = not toggle_cam
		cam_target = geist if toggle_cam else hero

	geist.solid = true
	collide([tm_geistwall], [geist])
	geist.solid = false

	overlap([hero], [exit_obj], _on_reach_exit)
	overlap([hero], pickups, _on_pickup)
	overlap(keys, machines, _on_key_vs_machine)
	collide(master_layer, mobiles(), _on_collide)
	overlap(weapons(), aliens, _on_kill_alien)
	collide(bullets, master_layer, _on_bullet_vs_anything)

	_narrate()

	if hero.was_hurt:
		_shake(0.02, 0.5)
		hero.was_hurt = false

	# super.update(): every member, in add() order: preUpdate, update, postUpdate(motion)
	for o in master_layer:
		_update_obj(o)
	for g in grabber_list:
		_update_obj(g)
	for n in narration:
		_update_obj(n)
	hud_text.update()
	for o in dispensed:
		_update_obj(o)

	_camera_update()


## Number of full HUD hearts (Heart.frame 0) per updateHearts().
func heart_frame(i: int) -> int:
	return 1 if i + 1 > hero.health else 0


func _update_obj(o: Obj) -> void:
	if not o.exists or o.is_tilemap():
		return
	o.lx = o.x
	o.ly = o.y
	if o.is_machine():
		if o.reboot_count > 0 and not o.has_power:
			o.reboot_count -= DT
			if o.reboot_count <= 0:
				add_power(o)
	elif o.kind == "Hero":
		if o.stun > 0:
			o.stun -= DT
		if o.stun < 0:
			o.stun = 0.0
	_update_motion(o)


static func _compute_velocity(v: float, a: float, d: float, mx: float) -> float:
	if a != 0:
		v += a * DT
	elif d != 0:
		var dd := d * DT
		if v - dd > 0:
			v = v - dd
		elif v + dd < 0:
			v += dd
		else:
			v = 0.0
	if v != 0 and mx != NO_MAX:
		if v > mx:
			v = mx
		elif v < -mx:
			v = -mx
	return v


static func _update_motion(o: Obj) -> void:
	var vd := (_compute_velocity(o.vx, o.ax, o.dragx, o.maxvx) - o.vx) / 2.0
	o.vx += vd
	var delta := o.vx * DT
	o.vx += vd
	o.x += delta
	vd = (_compute_velocity(o.vy, o.ay, o.dragy, o.maxvy) - o.vy) / 2.0
	o.vy += vd
	delta = o.vy * DT
	o.vy += vd
	o.y += delta


func _chase_hero(group: Array, speed: float, too_close := 0.0) -> void:
	for s in group:
		if s.alive and not s.captive and ray(tm_env, s.x, s.y, hero.x, hero.y):
			if too_close > 0 and Vector2(hero.lx, hero.ly).distance_to(Vector2(s.lx, s.ly)) < too_close:
				s.ax = sgn(hero.x - s.x) * speed * -2.0
				s.ay = sgn(hero.y - s.y) * speed * -2.0
			else:
				s.ax = sgn(hero.x - s.x) * speed
				s.ay = sgn(hero.y - s.y) * speed
		else:
			s.ax = 0.0
			s.ay = 0.0


func _narrate() -> void:
	_new_text = ""
	overlap([hero], narration, _on_narration)
	if _new_text != _old_text:
		_old_text = _new_text
		hud_text.set_full(_new_text)


# ----------------------------------------------------------------------------- callbacks
func _on_narration(_h: Obj, n: Obj) -> void:
	_new_text = n.text


func _on_reach_exit(_h: Obj, _e: Obj) -> void:
	_requested = WIN


func _on_pickup(_h: Obj, thing: Obj) -> void:
	if thing.kind == "Heart":
		hero_hurt(-1)
	thing.kill()


func _on_key_vs_machine(key: Obj, m: Obj) -> void:
	if m.kind == "KeyBox" and not m.has_power:
		add_power(m)
		key.kill()


func _on_grab_draggable(g: Obj, thing: Obj) -> void:
	if not g.done:
		grab(g, thing)
		if thing.kind == "Alien" and thing.alive and g.owner == hero:
			hero_hurt(1)


func _on_grab_machine(g: Obj, m: Obj) -> void:
	if not g.done:
		var d := machine_activate(m, g.frame, g.owner)
		if d != null:
			position_obj(d, g.frame, m)
			dispensed.append(d)
			if d.kind == "Bullet":
				bullets.append(d)
		g.done = true


## typeof() is "object" for every AS3 object, so the "alphabetical" sort always
## swaps: a = o2, b = o1.
func _on_collide(o1: Obj, o2: Obj) -> void:
	if o1.is_tilemap() or o2.is_tilemap():
		return
	var a := o2
	var b := o1
	if a.kind == "Alien" and b.kind == "Hero":
		_on_alien_vs_hero(a)
	elif a.kind == "Alien" and b.kind == "Spider":
		_on_spider_vs_alien(b, a)
	elif a.kind == "Alien" and b.kind == "Bullet":
		_on_bullet_vs_anything(b, a)
	elif a.kind == "Key" and b.kind == "SwitchBox":
		_on_key_vs_machine(a, b)


func _on_alien_vs_hero(alien: Obj) -> void:
	if alien.alive and hero.stun == 0:
		hero_hurt(1)
		hero.vx = -hero.vx
		hero.vy = -hero.vy


func _on_spider_vs_alien(spider: Obj, alien: Obj) -> void:
	if alien.alive:
		alien_hurt(alien)
		spider.kill()


func _on_kill_alien(weapon: Obj, alien: Obj) -> void:
	if weapon.kind == "Bullet":
		_on_bullet_vs_anything(weapon, alien)
	elif weapon.kind == "Spider":
		_on_spider_vs_alien(weapon, alien)


func _on_bullet_vs_anything(bullet: Obj, organic: Obj) -> void:
	if organic.kind == "Alien" and not organic.alive:
		organic.exists = false
	elif organic.is_capturable() or organic.kind == "Hero":
		hurt(organic, 1)
	bullet.kill()


# ----------------------------------------------------------------------------- camera
func _shake(intensity: float, duration: float) -> void:
	_shake_i = intensity
	_shake_t = duration
	shake_x = 0.0
	shake_y = 0.0


func _camera_update() -> void:
	if cam_target != null:
		# STYLE_LOCKON: focusOn(target.getMidpoint())
		var mx := cam_target.x + cam_target.w * 0.5
		var my := cam_target.y + cam_target.h * 0.5
		mx += 0.0000001 if mx > 0 else -0.0000001
		my += 0.0000001 if my > 0 else -0.0000001
		scroll_x = mx - STAGE_W * 0.5
		scroll_y = my - STAGE_H * 0.5
	scroll_x = clampf(scroll_x, 0.0, BOUNDS_W - STAGE_W)
	scroll_y = clampf(scroll_y, 0.0, BOUNDS_H - STAGE_H)
	if _shake_t > 0:
		_shake_t -= DT
		if _shake_t <= 0:
			shake_x = 0.0
			shake_y = 0.0
		else:
			shake_x = rng.randf() * _shake_i * STAGE_W * 2 - _shake_i * STAGE_W
			shake_y = rng.randf() * _shake_i * STAGE_H * 2 - _shake_i * STAGE_H


# ----------------------------------------------------------------------------- FlxTilemap.ray
func ray(t: Obj, sx: float, sy: float, ex: float, ey: float) -> bool:
	var step := float(mini(t.tw, t.th))
	var dx := ex - sx
	var dy := ey - sy
	var dist := sqrt(dx * dx + dy * dy)
	var steps := int(ceil(dist / step))
	if steps <= 0:
		return true
	var stx := dx / steps
	var sty := dy / steps
	var cx := sx - stx - t.x
	var cy := sy - sty - t.y
	for i in steps:
		cx += stx
		cy += sty
		if cx < 0 or cx > t.w or cy < 0 or cy > t.h:
			continue
		var tx := int(cx / t.tw)
		var ty := int(cy / t.th)
		if tx >= t.wt or ty >= t.ht:
			continue
		if t.data[ty * t.wt + tx] >= t.collide_idx:
			var tpx := tx * t.tw
			var tpy := ty * t.th
			var lx := cx - stx
			var ly := cy - sty
			var q := float(tpx)
			if dx < 0:
				q += t.tw
			var ry := ly + sty * ((q - lx) / stx) if stx != 0 else NAN
			if ry > tpy and ry < tpy + t.th:
				return false
			q = float(tpy)
			if dy < 0:
				q += t.th
			var rx := lx + stx * ((q - ly) / sty) if sty != 0 else NAN
			if rx > tpx and rx < tpx + t.tw:
				return false
			return true
	return true


# ----------------------------------------------------------------------------- FlxG.overlap / collide
func collide(a_list: Array, b_list: Array, notify := Callable()) -> bool:
	return overlap(a_list, b_list, notify, true)


## FlxQuadTree with both lists: every A object (in order) against every B object
## whose swept hull overlaps it. A uniform grid stands in for the quadtree;
## candidates are visited in B-list order.
func overlap(a_list: Array, b_list: Array, notify := Callable(), separate := false) -> bool:
	var b_objs: Array = []
	var big: Array = []
	for o in b_list:
		if o == null or not o.exists or not o.solid:
			continue
		if o.is_tilemap():
			big.append(b_objs.size())
		b_objs.append(o)
	if b_objs.is_empty():
		return false
	var grid := {}
	var grid_moving := {}  # only B objects that moved this frame
	var grid_built := false
	var all_b: Array = range(b_objs.size())
	var result := false
	for a_any in a_list:
		if a_any == null:
			continue
		var a: Obj = a_any
		if not a.exists or not a.solid:
			continue
		if separate and a.is_tilemap() and not a.has_solid:
			continue  # no tile can separate, so nothing is ever processed
		var cand: Array
		if a.is_tilemap() or b_objs.size() <= 8:
			cand = all_b
		else:
			if not grid_built:
				grid_built = true
				for idx in b_objs.size():
					var o: Obj = b_objs[idx]
					if o.is_tilemap():
						continue
					var ox0 := minf(o.x, o.lx)
					var oy0 := minf(o.y, o.ly)
					var ox1 := maxf(o.x, o.lx) + o.w
					var oy1 := maxf(o.y, o.ly) + o.h
					var moving := o.x != o.lx or o.y != o.ly
					for gx in range(int(floor(ox0 / GRID)), int(floor(ox1 / GRID)) + 1):
						for gy in range(int(floor(oy0 / GRID)), int(floor(oy1 / GRID)) + 1):
							var k := gx * 65536 + gy
							if grid.has(k):
								grid[k].append(idx)
							else:
								grid[k] = [idx]
							if moving:
								if grid_moving.has(k):
									grid_moving[k].append(idx)
								else:
									grid_moving[k] = [idx]
			# collide() between two motionless objects is a no-op, so a still A
			# only needs the B objects that moved (tilemaps never move)
			var still := separate and a.x == a.lx and a.y == a.ly
			var g: Dictionary = grid_moving if still else grid
			var seen := {}
			var ax0 := minf(a.x, a.lx)
			var ay0 := minf(a.y, a.ly)
			var ax1 := maxf(a.x, a.lx) + a.w
			var ay1 := maxf(a.y, a.ly) + a.h
			for gx in range(int(floor(ax0 / GRID)), int(floor(ax1 / GRID)) + 1):
				for gy in range(int(floor(ay0 / GRID)), int(floor(ay1 / GRID)) + 1):
					var k := gx * 65536 + gy
					if g.has(k):
						for i in g[k]:
							seen[i] = true
			if not still:
				for i in big:
					seen[i] = true
			if seen.is_empty():
				continue
			cand = seen.keys()
			cand.sort()
		var processed := false
		for i in cand:
			if not a.exists or not a.solid:
				break
			var b: Obj = b_objs[i]
			if b == a or not b.exists or not b.solid:
				continue
			if separate and not processed and a.x == a.lx and a.y == a.ly and b.x == b.lx and b.y == b.ly:
				continue  # nothing moved: no separation and nothing to notify yet
			# swept hulls
			var hax := minf(a.x, a.lx)
			var hay := minf(a.y, a.ly)
			var haw := a.w + absf(a.x - a.lx)
			var hah := a.h + absf(a.y - a.ly)
			var hbx := minf(b.x, b.lx)
			var hby := minf(b.y, b.ly)
			if hax + haw > hbx and hax < hbx + b.w + absf(b.x - b.lx) \
					and hay + hah > hby and hay < hby + b.h + absf(b.y - b.ly):
				if not separate:
					processed = true
				elif a.x == a.lx and a.y == a.ly and b.x == b.lx and b.y == b.ly:
					pass  # nothing moved: separateX/Y both see d1 == d2 and return false
				elif _separate(a, b):
					processed = true
				if processed and notify.is_valid():
					notify.call(a, b)
		result = result or processed
	return result


func _separate(o1: Obj, o2: Obj) -> bool:
	var sx := _sep_axis(o1, o2, true)
	var sy := _sep_axis(o1, o2, false)
	return sx or sy


var _tile := Obj.new("Tile")


func _sep_axis(o1: Obj, o2: Obj, ax_x: bool) -> bool:
	if o1.immovable and o2.immovable:
		return false
	if o1.is_tilemap():
		return _tiles_with(o1, o2, ax_x, false)
	if o2.is_tilemap():
		return _tiles_with(o2, o1, ax_x, true)
	return _sep_x(o1, o2) if ax_x else _sep_y(o1, o2)


## FlxTilemap.overlapsWithCallback(Object, separateX/Y, flip)
func _tiles_with(t: Obj, o: Obj, ax_x: bool, flip: bool) -> bool:
	if o.immovable or not t.has_solid:
		return false  # every tile is immovable
	# a tile never moves, so with no motion on this axis d1 == d2 and nothing separates
	if (o.x == o.lx) if ax_x else (o.y == o.ly):
		return false
	var sel_x := int(floor((o.x - t.x) / t.tw))
	var sel_y := int(floor((o.y - t.y) / t.th))
	var sel_w := sel_x + int(ceil(o.w / t.tw)) + 1
	var sel_h := sel_y + int(ceil(o.h / t.th)) + 1
	sel_x = maxi(sel_x, 0)
	sel_y = maxi(sel_y, 0)
	sel_w = mini(sel_w, t.wt)
	sel_h = mini(sel_h, t.ht)
	var results := false
	var tile := _tile
	tile.w = t.tw
	tile.h = t.th
	tile.immovable = true
	for row in range(sel_y, sel_h):
		for col in range(sel_x, sel_w):
			if t.data[row * t.wt + col] < t.collide_idx:
				continue
			tile.x = t.x + col * t.tw
			tile.y = t.y + row * t.th
			tile.lx = tile.x
			tile.ly = tile.y
			tile.vx = 0.0
			tile.vy = 0.0
			var found: bool
			if flip:
				found = _sep_x(o, tile) if ax_x else _sep_y(o, tile)
			else:
				found = _sep_x(tile, o) if ax_x else _sep_y(tile, o)
			if found:
				results = true
	return results


func _sep_x(o1: Obj, o2: Obj) -> bool:
	var imm1 := o1.immovable
	var imm2 := o2.immovable
	if imm1 and imm2:
		return false
	var overlap_amt := 0.0
	var d1 := o1.x - o1.lx
	var d2 := o2.x - o2.lx
	if d1 != d2:
		var d1a := absf(d1)
		var d2a := absf(d2)
		var r1x := o1.x - (d1 if d1 > 0 else 0.0)
		var r1w := o1.w + (d1 if d1 > 0 else -d1)
		var r2x := o2.x - (d2 if d2 > 0 else 0.0)
		var r2w := o2.w + (d2 if d2 > 0 else -d2)
		if r1x + r1w > r2x and r1x < r2x + r2w and o1.ly + o1.h > o2.ly and o1.ly < o2.ly + o2.h:
			var max_ov := d1a + d2a + OVERLAP_BIAS
			if d1 > d2:
				overlap_amt = o1.x + o1.w - o2.x
				if overlap_amt > max_ov:
					overlap_amt = 0.0
			elif d1 < d2:
				overlap_amt = o1.x - o2.w - o2.x
				if -overlap_amt > max_ov:
					overlap_amt = 0.0
	if overlap_amt == 0.0:
		return false
	var v1 := o1.vx
	var v2 := o2.vx
	if not imm1 and not imm2:
		overlap_amt *= 0.5
		o1.x -= overlap_amt
		o2.x += overlap_amt
		var n1 := sqrt((v2 * v2 * o2.mass) / o1.mass) * (1.0 if v2 > 0 else -1.0)
		var n2 := sqrt((v1 * v1 * o1.mass) / o2.mass) * (1.0 if v1 > 0 else -1.0)
		var avg := (n1 + n2) * 0.5
		o1.vx = avg   # + (n1 - avg) * elasticity(0)
		o2.vx = avg
	elif not imm1:
		o1.x -= overlap_amt
		o1.vx = v2
	else:
		o2.x += overlap_amt
		o2.vx = v1
	return true


func _sep_y(o1: Obj, o2: Obj) -> bool:
	var imm1 := o1.immovable
	var imm2 := o2.immovable
	if imm1 and imm2:
		return false
	var overlap_amt := 0.0
	var d1 := o1.y - o1.ly
	var d2 := o2.y - o2.ly
	if d1 != d2:
		var d1a := absf(d1)
		var d2a := absf(d2)
		var r1y := o1.y - (d1 if d1 > 0 else 0.0)
		var r1h := o1.h + d1a
		var r2y := o2.y - (d2 if d2 > 0 else 0.0)
		var r2h := o2.h + d2a
		if o1.x + o1.w > o2.x and o1.x < o2.x + o2.w and r1y + r1h > r2y and r1y < r2y + r2h:
			var max_ov := d1a + d2a + OVERLAP_BIAS
			if d1 > d2:
				overlap_amt = o1.y + o1.h - o2.y
				if overlap_amt > max_ov:
					overlap_amt = 0.0
			elif d1 < d2:
				overlap_amt = o1.y - o2.h - o2.y
				if -overlap_amt > max_ov:
					overlap_amt = 0.0
	if overlap_amt == 0.0:
		return false
	var v1 := o1.vy
	var v2 := o2.vy
	if not imm1 and not imm2:
		overlap_amt *= 0.5
		o1.y -= overlap_amt
		o2.y += overlap_amt
		var n1 := sqrt((v2 * v2 * o2.mass) / o1.mass) * (1.0 if v2 > 0 else -1.0)
		var n2 := sqrt((v1 * v1 * o1.mass) / o2.mass) * (1.0 if v1 > 0 else -1.0)
		var avg := (n1 + n2) * 0.5
		o1.vy = avg
		o2.vy = avg
	elif not imm1:
		o1.y -= overlap_amt
		o1.vy = v2
	else:
		o2.y += overlap_amt
		o2.vy = v1
	return true
