extends RefCounted
## Toroidal Zombie Herder — GameMaker room simulation (no rendering).
##
## Recreates the GM:S 1.x semantics the original relied on, one call to
## step() per room step (room speed 30):
##   1. mouse (global left button) : obj_hero  action_potential_step(mouse, walk_speed=10, solid only)
##   2. step                       : obj_hero  MoveHero.gml
##                                   obj_zombie action_potential_step(obj_hero.x/y, 2, solid only)
##   3. outside room               : obj_hero, obj_zombie action_wrap(both)
##   4. collisions                 : obj_hero+obj_coin -> score += 10, destroy coin
##                                   obj_hero+obj_zombie -> room_restart (score survives,
##                                   it's GM's global `score`)
##                                   obj_zombie+obj_trap -> destroy both
## Solid objects: obj_wall, obj_zombie. Masks match the .sprite.gmx bboxes.

const Room0 := preload("res://games/toroidal_zombie_herder/direct/room0.gd")

const W := Room0.WIDTH
const H := Room0.HEIGHT

enum { WALL, HERO, ZOMBIE, COIN, TRAP, SCORE }

const KIND_BY_NAME := {
	"obj_wall": WALL, "obj_hero": HERO, "obj_zombie": ZOMBIE,
	"obj_coin": COIN, "obj_trap": TRAP, "obj_score": SCORE,
}

## Collision bbox relative to the sprite origin, half-open [l, r+1) in px
## (from bbox_left/right/top/bottom minus xorig/yorigin). Hero mask is an ellipse.
const MASK := {
	WALL: Rect2(-14, -14, 28, 28),    # spr_wall  2..29 / 2..29, origin 16
	HERO: Rect2(-11, -14, 24, 27),    # spr_hero  5..28 / 2..28, origin 16, ellipse
	ZOMBIE: Rect2(-12, -15, 26, 30),  # spr_zombie 4..29 / 1..30, origin 16
	COIN: Rect2(-4, -4, 8, 8),        # coin 0..7, origin 4
	TRAP: Rect2(-16, -16, 32, 32),    # spr_trap 0..31, origin 16
}
const SOLID := [WALL, ZOMBIE]

const HERO_WALK_SPEED := 10.0  # obj_hero Create: walk_speed = 10 (mouse only)
const ZOMBIE_SPEED := 2.0
# mp_potential_settings defaults
const PS_MAXROT := 30.0
const PS_ROTSTEP := 10.0
const PS_AHEAD := 3.0


class Inst:
	var kind: int
	var x: float
	var y: float
	var sx: float = 1.0
	var sy: float = 1.0
	var direction: float = 0.0
	var alive := true

	func _init(k: int, px: float, py: float, psx := 1.0, psy := 1.0) -> void:
		kind = k; x = px; y = py; sx = psx; sy = psy

	func bbox_at(px: float, py: float) -> Rect2:
		var m: Rect2 = MASK.get(kind, Rect2())
		return Rect2(px + m.position.x * sx, py + m.position.y * sy, m.size.x * sx, m.size.y * sy)

	func bbox() -> Rect2:
		return bbox_at(x, y)


var instances: Array = []   # Array[Inst], creation order
var hero: Inst
var score := 0              # GM global: persists across room_restart
var restarts := 0
var steps := 0


func _init() -> void:
	room_start()


func room_start() -> void:
	instances.clear()
	hero = null
	for row in Room0.INSTANCES:
		var inst := Inst.new(KIND_BY_NAME[row[0]], row[1], row[2], row[3], row[4])
		instances.append(inst)
		if inst.kind == HERO and hero == null:
			hero = inst


func of_kind(kind: int) -> Array:
	return instances.filter(func(i): return i.alive and i.kind == kind)


## input keys: up, down, left, right (bool), mouse_down (bool), mouse (Vector2, room px)
func step(input: Dictionary) -> void:
	steps += 1
	# 1. mouse event (global left button held)
	if input.get("mouse_down", false):
		var m: Vector2 = input.get("mouse", Vector2.ZERO)
		potential_step(hero, m.x, m.y, HERO_WALK_SPEED)
	# 2. step events, object order (obj_hero before obj_zombie)
	move_hero(input)
	for z in of_kind(ZOMBIE):
		potential_step(z, hero.x, hero.y, ZOMBIE_SPEED)
	# 3. outside room -> wrap
	for i in instances:
		if i.alive and (i.kind == HERO or i.kind == ZOMBIE) and _outside_room(i):
			_wrap(i)
	# 4. collisions
	var restart := false
	for c in of_kind(COIN):
		if c.alive and _collide(hero, hero.x, hero.y, c):
			score += 10
			c.alive = false
	for z in of_kind(ZOMBIE):
		if _collide(hero, hero.x, hero.y, z):
			restart = true
	for z in of_kind(ZOMBIE):
		for t in of_kind(TRAP):
			if z.alive and t.alive and _collide(z, z.x, z.y, t):
				z.alive = false
				t.alive = false
	instances = instances.filter(func(i): return i.alive)
	if restart:   # room_restart takes effect at the end of the step
		restarts += 1
		room_start()


## scripts/MoveHero.gml, line for line.
func move_hero(input: Dictionary) -> void:
	var du := 8.0
	var dx := 0.0
	var dy := 0.0
	if input.get("up", false): dy -= du
	if input.get("down", false): dy += du
	if input.get("left", false): dx -= du
	if input.get("right", false): dx += du

	while absf(dx) + absf(dy) > 4 and not place_free(hero, hero.x + dx, hero.y + dy):
		dx -= signf(dx); dy -= signf(dy)
	var nx := hero.x + dx
	var ny := hero.y + dy
	if nx < 0: nx = W + nx
	if nx > W: nx = fmod(nx, W)
	if ny < 0: ny = H + ny
	if ny > H: ny = fmod(ny, H)
	if place_free(hero, nx, ny):
		hero.x = nx; hero.y = ny

	if dx == 0:
		var gw := 32.0
		var hgw := 16.0  # grid width for snapping
		dx = fmod(hero.x, gw)
		if dx < hgw: hero.x -= dx
		else: hero.x += gw - dx
	if dy == 0:
		var gh := 32.0
		var hgh := 16.0  # grid height for snapping
		dy = fmod(hero.y, gh)
		if dy < hgh: hero.y -= dy
		else: hero.y += gh - dy


## place_free(x, y): no solid instance overlaps `who` placed at (x, y).
func place_free(who: Inst, px: float, py: float) -> bool:
	for o in instances:
		if o == who or not o.alive or not (o.kind in SOLID):
			continue
		if _collide(who, px, py, o):
			return false
	return true


## action_potential_step(tx, ty, speed, solid only) — GM8/GM:S mp_potential_step
## with default mp_potential_settings(30, 10, 3, true).
func potential_step(who: Inst, tx: float, ty: float, speed: float) -> bool:
	var ox := who.x
	var oy := who.y
	if ox == tx and oy == ty:
		return true
	var dist := Vector2(tx - ox, ty - oy).length()
	var dir := fposmod(rad_to_deg(atan2(oy - ty, tx - ox)), 360.0)
	if dist <= speed:
		if place_free(who, tx, ty):
			who.x = tx; who.y = ty; who.direction = dir
			return true
		return false
	var diff := 0.0
	while true:
		var d := fposmod(dir - diff, 360.0)
		var change := fposmod(d - who.direction, 360.0)
		if change <= PS_MAXROT or change >= 360.0 - PS_MAXROT:
			var xs := speed * cos(deg_to_rad(d))
			var ys := -speed * sin(deg_to_rad(d))
			if place_free(who, ox + xs * PS_AHEAD, oy + ys * PS_AHEAD) \
					and place_free(who, ox + xs, oy + ys):
				who.x = ox + xs; who.y = oy + ys; who.direction = d
				return false
		# 0, +10, -10, +20, -20, ... < 180
		if diff <= 0.0:
			diff = -diff + PS_ROTSTEP
			if diff >= 180.0:
				break
		else:
			diff = -diff
	who.direction = fposmod(who.direction + PS_MAXROT, 360.0)  # rotate on the spot
	return false


func _collide(a: Inst, ax: float, ay: float, b: Inst) -> bool:
	var ra: Rect2 = a.bbox_at(ax, ay)
	var rb: Rect2 = b.bbox()
	if not (ra.position.x < rb.end.x and rb.position.x < ra.end.x
			and ra.position.y < rb.end.y and rb.position.y < ra.end.y):
		return false
	if a.kind == HERO:
		return _ellipse_hits_rect(ra, rb)
	if b.kind == HERO:
		return _ellipse_hits_rect(rb, ra)
	return true


## Ellipse inscribed in `e` vs axis-aligned rect `r`.
static func _ellipse_hits_rect(e: Rect2, r: Rect2) -> bool:
	var c := e.get_center()
	var rx := e.size.x * 0.5
	var ry := e.size.y * 0.5
	var px := clampf(c.x, r.position.x, r.end.x)
	var py := clampf(c.y, r.position.y, r.end.y)
	var nx := (px - c.x) / rx
	var ny := (py - c.y) / ry
	return nx * nx + ny * ny < 1.0


func _outside_room(i: Inst) -> bool:
	var b: Rect2 = i.bbox()
	return b.end.x <= 0 or b.position.x >= W or b.end.y <= 0 or b.position.y >= H


## action_wrap(both)
func _wrap(i: Inst) -> void:
	var b: Rect2 = i.bbox()
	if b.end.x <= 0: i.x += W
	elif b.position.x >= W: i.x -= W
	if b.end.y <= 0: i.y += H
	elif b.position.y >= H: i.y -= H
