extends RefCounted
## Spiders v. Aliens Enhanced: contextual grab prompts.
## Read-only queries over the shared Direct simulation (sva_logic.gd): what would each grab key
## do right now? Mirrors PlayState's press-frame order: the first machine a grabber touches is
## activated (and marks the grabber done); otherwise the last draggable it touches is grabbed.
## Never mutates the world, so the rules stay exactly the Direct edition's.

const Logic := preload("res://games/spiders_v_aliens/direct/sva_logic.gd")

## Grab key per direction (Logic.DIR_N/S/W/E), QWERTY; Dvorak , O A E also work.
const KEYCAPS := ["W", "S", "A", "D"]
const DIR_NAMES := ["north", "south", "west", "east"]

const NOUNS := {
	"Box": "crate", "Key": "key", "Spider": "spider", "Alien": "Dentist",
}


## The rect the grabber on `dir` covers (SvA.position(grabber, dir, avatar)).
static func grab_rect(av, dir: int) -> Rect2:
	var w := 16.0
	var h := 20.0
	var cx: float = av.x + av.w / 2.0 - w / 2.0
	var cy: float = av.y + av.h / 2.0 - h / 2.0
	match dir:
		Logic.DIR_N:
			return Rect2(cx, av.y - h, w, h)
		Logic.DIR_S:
			return Rect2(cx, av.y + av.h, w, h)
		Logic.DIR_W:
			return Rect2(av.x - w, cy, w, h)
	return Rect2(av.x + av.w, cy, w, h)


static func _hits(r: Rect2, o) -> bool:
	return o != null and o.exists and o.solid \
			and r.position.x + r.size.x > o.x and r.position.x < o.x + o.w \
			and r.position.y + r.size.y > o.y and r.position.y < o.y + o.h


## What pressing the grab key for `dir` would act on now (machine first, else last draggable).
static func target(world, av, dir: int):
	var r := grab_rect(av, dir)
	for m in world.machines:
		if _hits(r, m):
			return m
	var found = null
	for d in world.draggable():
		if _hits(r, d):
			found = d
	return found


## {text, danger, active} describing what grabbing `t` from `dir` would do.
static func describe(world, av, dir: int, t) -> Dictionary:
	var text := ""
	var danger := false
	var active := true
	match t.kind:
		"Portal":
			if t.has_power and t.other_side != null:
				text = "Teleport"
			else:
				text = "Portal offline"
				active = false
		"SwitchBox":
			text = "Switch off" if t.has_power else "Switch on"
		"Cannon":
			if t.has_power:
				text = "Fire " + DIR_NAMES[dir]
			else:
				text = "Cannon recharging"
				active = false
		"KeyBox":
			if t.has_power:
				text = "Lock open"
				active = false
			else:
				text = "Locked: bring a key"
				active = false
		"Box":
			text = "Drag crate"
		"Key":
			text = "Take key"
		"Spider":
			text = "Grab spider"
		"Alien":
			if t.alive:
				if av == world.hero:
					text = "Dentist! Grabbing bites"
					danger = true
				else:
					text = "Grab Dentist"
			else:
				text = "Drag Dentist"
		_:
			text = "Grab"
	return {"text": text, "danger": danger, "active": active}


## One entry per direction with something to say:
## {dir, key, text, danger, active, held, target(Obj)}.
static func prompts(world, av) -> Array:
	var out: Array = []
	if world == null or av == null or world.state != Logic.PLAY:
		return out
	for dir in 4:
		var g = av.grabbers[dir]
		if g.exists and g.content != null and g.content.exists:
			var noun: String = NOUNS.get(g.content.kind, "it")
			out.append({"dir": dir, "key": KEYCAPS[dir], "held": true, "danger": false,
					"active": true, "target": g.content,
					"text": "Holding %s - let go to fling" % noun})
			continue
		if g.exists:
			continue  # key already held: nothing new happens until it is pressed again
		var t = target(world, av, dir)
		if t == null:
			continue
		var d := describe(world, av, dir, t)
		d["dir"] = dir
		d["key"] = KEYCAPS[dir]
		d["held"] = false
		d["target"] = t
		out.append(d)
	return out
