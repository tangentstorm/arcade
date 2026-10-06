extends RefCounted
## Kill 'Em All — GameMaker: Studio 1.x room simulation (no rendering).
##
## room0 (1024x768, colour 1835008, speed 30, no views), creation order:
##   objShip  (sprite1, 64x64 disc)  at (480,416)
##   objBlast (sprite0, 64x64 arc)   at (480,416)  — the "gun", aimed at the mouse
##   events   (spr_mouse)            at (32,32)
##     Create -> scripts/init.gml   : centre objShip, zero heading/velocity
##     Step   -> scripts/step.gml   : steer, aim, move, fire
##     Draw   -> scripts/mousepos.gml: "x:<mouse_x>, y:<mouse_y>" at (10,10)
##   objBullet (bullet, 8x8): no events; created by step.gml with speed 10.
##
## step() runs one GM step: Step event (step.gml), then GM's built-in motion
## update for every instance with a speed (the bullets, including ones created
## this step).

const W := 1024
const H := 768
const SPEED := 30          ## room0 <speed>
const MAXSPEED := 10.0     ## step.gml
const GUN_RADIUS := 30.0   ## step.gml: gr
const KICKBACK := 0.05     ## step.gml: kb
const BULLET_SPEED := 10.0
## Not in the original (GM keeps every bullet forever): bullets this far outside
## the room can never come back, so they're dropped to keep memory bounded.
const CULL_MARGIN := 64.0


class Bullet:
	var x: float
	var y: float
	var direction: float   ## degrees, GM convention (CCW, 0 = right, y down)

	func _init(px: float, py: float, d: float) -> void:
		x = px; y = py; direction = d


# objShip
var ship_x := 480.0
var ship_y := 416.0
var hx := 0
var hy := 0
var dx := 0.0
var dy := 0.0
# objBlast
var blast_x := 480.0
var blast_y := 416.0
var blast_angle := 0.0     ## image_angle, degrees CCW
var bullets: Array[Bullet] = []
var mouse := Vector2.ZERO  ## mouse_x / mouse_y in room coordinates
var fired := 0             ## total bullets created (stats/tests only)
var steps := 0


func _init() -> void:
	room_start()


## Room start: instances at their room positions, then events' Create runs init.gml.
func room_start() -> void:
	ship_x = 480; ship_y = 416
	blast_x = 480; blast_y = 416; blast_angle = 0
	bullets.clear()
	fired = 0
	steps = 0
	# init.gml
	ship_x = W >> 1
	ship_y = H >> 1
	hx = 0; hy = 0; dx = 0; dy = 0


## GM point_direction: degrees CCW with y pointing down, in [0, 360).
static func point_direction(x1: float, y1: float, x2: float, y2: float) -> float:
	return fposmod(rad_to_deg(atan2(-(y2 - y1), x2 - x1)), 360.0)


## input: {"left","right","up","down","fire": bool, "mouse": Vector2 (room coords)}
func step(input: Dictionary = {}) -> void:
	mouse = input.get("mouse", mouse)
	_step_script(input)
	# built-in motion (objBullet: direction a, speed 10)
	var keep: Array[Bullet] = []
	for b in bullets:
		var r := deg_to_rad(b.direction)
		b.x += cos(r) * BULLET_SPEED
		b.y -= sin(r) * BULLET_SPEED
		if b.x > -CULL_MARGIN and b.x < W + CULL_MARGIN \
				and b.y > -CULL_MARGIN and b.y < H + CULL_MARGIN:
			keep.append(b)
	bullets = keep
	steps += 1


## scripts/step.gml, line for line (with objShip).
func _step_script(input: Dictionary) -> void:
	# calculate new heading:
	hx = 0
	if input.get("left", false): hx -= 1
	if input.get("right", false): hx += 1
	hy = 0
	if input.get("up", false): hy -= 1
	if input.get("down", false): hy += 1
	# velocity based on heading, location based on velocity
	if hx != 0 or hy != 0:
		var h := atan2(hy, hx)
		dy += sin(h); dx += cos(h)
	else:
		dx *= 0.99; dy *= 0.99
	# gun angle based on mouse position:
	var a := point_direction(ship_x, ship_y, mouse.x, mouse.y)
	blast_angle = a
	# friction and max velocity
	dx = clampf(dx, -MAXSPEED, MAXSPEED); dy = clampf(dy, -MAXSPEED, MAXSPEED)
	ship_x += dx; ship_y += dy; blast_x = ship_x; blast_y = ship_y
	# firing has slight kickback
	if input.get("fire", false):
		var r := deg_to_rad(a)
		dx -= cos(r) * KICKBACK; dy += sin(r) * KICKBACK
		bullets.append(Bullet.new(ship_x + GUN_RADIUS * cos(r), ship_y - GUN_RADIUS * sin(r), a))
		fired += 1
