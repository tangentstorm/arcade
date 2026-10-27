extends RefCounted
## Kiwi Soccer rules, line for line from sabren/blaze pyweek/ (PyWeek #1, 2005):
## health.py (HealthModel + CalorieBank), statusbox.py (bar heights),
## hero.py (Bird mass/run/jump), states.py (Controller repeat, Scores placement).
## roomphysics.py / room.py physics: a small re-implementation of the pyODE dWorldStep
## behaviour this room depends on (see World below).

# constants.py
const SCREEN := Vector2i(640, 480)
const ROOM_W := 540.0                 ## ROOM.WIDTH
const ROOM_H := 480.0                 ## ROOM.HEIGHT
const THICKNESS := 32.0               ## ROOM.THICKNESS
const GRAVITY := 98.1                 ## PHYSICS.GRAVITY y (px/s^2, y down)
const DRAG := -50000.0                ## PHYSICS.DRAG (force per px/s of x velocity)
const SCALEFORCE := 5000000.0         ## PHYSICS.SCALEFORCE
const ERP := 0.8                      ## PHYSICS.ERP
const CFM := 0.0001                   ## PHYSICS.CFM
const MU := 100.0                     ## PHYSICS.FRICTION -> contact.setMu (a force cap: no dContactApprox1)
const CONTACT_ROWS := 4               ## dBoxBox face-on-face contact: 4 points, each its own joint
const SUBSTEP := 0.01                 ## world.step(0.01), twice per tick
const TICK := 0.02                    ## 2 substeps = one Game.tick
const HERO_RADIUS := 16.0             ## HERO.RADIUS
const JUMPFORCE := -8.0               ## HERO.JUMPFORCE
const SPEED := 10.0                   ## Bird.SPEED
const HERO_START := Vector2(150, 380) ## setPosition((150, ROOM.HEIGHT-100))
const BALL_START := Vector2(50, 50)   ## ball.Ball default position
const CAL_RUN := 3                    ## CALORIES.RUN
const CAL_JUMP := 5                   ## CALORIES.JUMP
const REPEAT_TICKS := 10              ## REPEAT.TICKS
const FOOD := Vector2i(5, 5)          ## Game.tick: eat(Food(5,5)) "hack to lower metabolism"

# HealthModelConfig defaults
const STARTFAT := 5000
const STARTBLOOD := 1000
const BLOODLIMIT := 1000
const EXERTIONRATIO := 20
const LOWBLOODLEVEL := 100
const BLOODRECOVERYRATE := 5
const BASEINSULINRATE := 2
const INSULINRATIO := 10
const INSULIN2FATRATIO := 0.5
const FATMASS := 0.0001

# statusbox.py / constants.IMAGE.STATUS
const BAR_HEIGHT := 376
const BAR_WIDTH := 38
const CARB_POS := Vector2(549, 99)
const FATS_POS := Vector2(596, 99)
const TEXT_POS := Vector2(552, 253)

const RIGHT := 1
const LEFT := -1

var fat := STARTFAT
var blood := STARTBLOOD
## Heights of the two white "black" bars; 1 until the first HEALTH event (StatusBox blackheight).
var blood_black := 1
var fat_black := 1
var starved := false   ## original posts EVENTS.HEALTH.STARVE (a NameError crash there)


## CalorieBank.burnCalories: clamp at 0 and return the shortfall (the exception's calories_short).
static func _burn(bank: int, calories: int) -> Vector2i:
	var left := bank - calories
	if left < 0:
		return Vector2i(0, -left)
	return Vector2i(left, 0)


func exert(level: int) -> void:
	var r := _burn(blood, level * EXERTIONRATIO)
	blood = r.x
	if r.y > 0:
		var f := _burn(fat, r.y)
		fat = f.x
		if f.y > 0:
			starved = true
		_fat_changed()
	_blood_changed()


func eat(sugar: int, fat_cal: int) -> void:
	blood += sugar
	fat += fat_cal
	_fat_changed()
	_blood_changed()


func step() -> void:
	if blood < LOWBLOODLEVEL:
		fat = _burn(fat, BLOODRECOVERYRATE).x
		blood += BLOODRECOVERYRATE
	var penalty := 0
	if blood > BLOODLIMIT:
		penalty = (blood - BLOODLIMIT) * INSULINRATIO
	var insulin := BASEINSULINRATE + penalty
	blood = _burn(blood, insulin).x
	fat += int(insulin * INSULIN2FATRATIO)
	_fat_changed()
	_blood_changed()


## statusbox.figureNewBarBlackSize
static func black_height(value: float, ceiling: float) -> int:
	var pb := 1.0 - value / ceiling
	if pb < 0.0:
		pb = 0.0
	return int(BAR_HEIGHT * pb)


func _blood_changed() -> void:
	blood_black = black_height(blood, 4 * BLOODLIMIT)


func _fat_changed() -> void:
	fat_black = black_height(fat, 4 * STARTFAT)


## hero.Bird.updateMass: ode Mass.setSphere(density = fatmass*fat/fatspace, radius 16).
func mass() -> float:
	return FATMASS * fat * (4.0 / 3.0) * PI * pow(HERO_RADIUS, 3)


## Bird.move: addForce(x*SCALEFORCE, y*SCALEFORCE). ODE clears forces after each 0.01 s
## world.step, so a move() acts for the first substep of the next tick only.
static func move_force(v: Vector2) -> Vector2:
	return v * SCALEFORCE


static func run_force(dir: int) -> Vector2:
	return move_force(Vector2(SPEED * 2 * dir, 0))


static func jump_force() -> Vector2:
	return move_force(Vector2(0, JUMPFORCE))


## states.Controller: posts on key down, then every REPEAT_TICKS ticks re-posts held buttons.
class Controller:
	var buttons_down: Array[String] = []
	var ticks := 0

	func key_down(button: String) -> void:
		buttons_down.append(button)

	func key_up(button: String) -> void:
		buttons_down.erase(button)

	## Returns the buttons re-posted this tick.
	func tick() -> Array[String]:
		ticks += 1
		var out: Array[String] = []
		if ticks >= REPEAT_TICKS:
			ticks = 0
			out = buttons_down.duplicate()
		return out


## states.Scores.kick placement for a new score (list kept best-first).
## The original walks off the front of the list and crashes (IndexError) for a score
## below every entry; here that case appends at the end instead.
static func place_for(scores: Array, score: int) -> int:
	if scores.is_empty():
		return 0
	var high := scores.size() - 1
	while high >= -scores.size() and score < int(scores[high][1]):
		high -= 1
	if high < 0:
		return scores.size()
	return high


static func insert_score(scores: Array, initials: String, score: int) -> Array:
	var out := scores.duplicate(true)
	out.insert(place_for(scores, score), [initials, score])
	if out.size() > 10:
		out = out.slice(0, 10)
	return out


## A 32x32 box body. ODE keeps the boxes level here (rotation stays < 0.001 rad), so only
## translation is modelled.
class Body:
	var pos: Vector2
	var vel := Vector2.ZERO
	var mass := 1.0
	var force := Vector2.ZERO   ## addForce accumulator, cleared after every world.step

	func _init(p: Vector2, m: float) -> void:
		pos = p
		mass = m


## The room's ODE world: gravity 98.1, ERP 0.8, CFM 1e-4, and one solid geom. Room._setupGlass
## builds six glass boxes, but only the pit is kept in a Python reference (self.floor); pyODE
## frees the other five when their locals go out of scope, which removes them from the space.
## So the floor under x 0..540 is all there is, and a kiwi that runs off either end falls forever.
class World:
	const FLOOR_CENTER := Vector2(ROOM_W / 2, ROOM_H + THICKNESS / 2)
	const FLOOR_HALF := Vector2(ROOM_W / 2, THICKNESS / 2)
	const BOX_HALF := Vector2(HERO_RADIUS, HERO_RADIUS)
	var hero: Body
	var ball: Body

	func _init(hero_mass: float) -> void:
		hero = Body.new(HERO_START, hero_mass)
		# loader: outside-geom.svg has no arcs, so the default Ball (an unseen 32x32 block with
		# ODE's default body mass of 1) is dropped in at (50, 50).
		ball = Body.new(BALL_START, 1.0)

	## roomphysics.step: twice { atmosphere(); space.collide(); world.step(0.01) }.
	func tick() -> void:
		for i in 2:
			hero.force.x += hero.vel.x * DRAG
			_step(SUBSTEP)

	## Separating-axis contact between two boxes: [normal (a->b), depth] or [] if apart.
	static func _contact(ca: Vector2, ha: Vector2, cb: Vector2, hb: Vector2) -> Array:
		var d := cb - ca
		var ox := ha.x + hb.x - absf(d.x)
		var oy := ha.y + hb.y - absf(d.y)
		if ox <= 0.0 or oy <= 0.0:
			return []
		if oy <= ox:
			return [Vector2(0, signf(d.y) if d.y != 0.0 else 1.0), oy]
		return [Vector2(signf(d.x) if d.x != 0.0 else 1.0, 0), ox]

	## One dWorldStep: v* = v + h F/m; contact rows solve J v' = ERP*depth/h - CFM*lambda
	## (normal, lambda >= 0) and J v' = -CFM*lambda (two friction rows in 3D, one here,
	## |lambda| <= mu per row); then pos += h v'.
	func _step(h: float) -> void:
		var bodies: Array[Body] = [hero, ball]
		for b in bodies:
			b.vel += h * (Vector2(0, GRAVITY) + b.force / b.mass)
		# rows: [a (Body or null = static floor), b, normal, depth]
		var contacts: Array = []
		for b in bodies:
			var c := _contact(FLOOR_CENTER, FLOOR_HALF, b.pos, BOX_HALF)
			if not c.is_empty():
				contacts.append([null, b, c[0], c[1]])
		var cb := _contact(hero.pos, BOX_HALF, ball.pos, BOX_HALF)
		if not cb.is_empty():
			contacts.append([hero, ball, cb[0], cb[1]])
		var n := float(CONTACT_ROWS)
		var acc: Array = []
		for c in contacts:
			acc.append(Vector2.ZERO)  # x = normal total force, y = friction total force
		for it in 30:
			for i in contacts.size():
				var a: Body = contacts[i][0]
				var b: Body = contacts[i][1]
				var nrm: Vector2 = contacts[i][2]
				var tan := Vector2(-nrm.y, nrm.x)
				var inv := 1.0 / b.mass + (1.0 / a.mass if a else 0.0)
				var va: Vector2 = a.vel if a else Vector2.ZERO
				var rel := b.vel - va
				var f: Vector2 = acc[i]
				# normal row
				var r := ERP * float(contacts[i][3]) / h - CFM * f.x / n - rel.dot(nrm)
				var fx := maxf(0.0, f.x + r / (h * inv + CFM / n))
				var dfx := fx - f.x
				# friction row (constant force cap, independent of the normal force)
				var rt := -CFM * f.y / n - rel.dot(tan)
				var fy := clampf(f.y + rt / (h * inv + CFM / n), -n * MU, n * MU)
				var dfy := fy - f.y
				var imp := (nrm * dfx + tan * dfy) * h
				b.vel += imp / b.mass
				if a:
					a.vel -= imp / a.mass
				acc[i] = Vector2(fx, fy)
		for b in bodies:
			b.pos += h * b.vel
			b.force = Vector2.ZERO
