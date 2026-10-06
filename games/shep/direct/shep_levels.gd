extends RefCounted
## Shep: level data and the engine-free rules from the original source.
##
## parse_svg() is Game1.parseSVG / addPolyXml / addPocket / addSpinner / addDoor
## minus the physaxe calls: it turns an Illustrator SVG into a list of items
## using the same color code. The level-select tables come from console.mxml
## (ordLevel, getLevelName, getLevelText, unlockLevels, showLevelInfo), and the
## clock comes from FlashClock.hx.

const LevelPack := preload("res://games/shep/direct/level_pack.gd")

## Game1 config
const TIME_LIMIT := 120          ## seconds per level
const BORDER := 25.0             ## thickness of the four boundary walls
const W := 800.0
const H := 575.0
const SHEP_RADIUS := 20.0        ## cuebot: phx.Circle(20)
const FUSE_RADIUS := 15.0        ## smallball: phx.Circle(15)
const POCKET_RADIUS := 15.0      ## pocket body: phx.Circle(15)
const POCKET_ZONE := 60.0        ## debug-only 60x60 "zone" box around each pocket
const SPINNER_SIZE := Vector2(15, 175)  ## hard coded because of the sprite
const SPINNER_VELOCITY := 0.03   ## radians per frame
const DEFAULT_START := Vector2(10, 10)  ## new phx.Body(10, 10) before setPos

## parseSVG's color code
const GREEN := "#00FF00"
const RED := "#FF0000"
const BLUE := "#0000FF"
const CYAN := "#00FFFF"
const DARK_CYAN := "#009999"
const MAGENTA := "#FF00FF"       ## addPolyXml: floatyWall (crates / cargo)

## Item kinds produced by parse_svg
const WALL_RECT := "wall_rect"
const WALL_POLY := "wall_poly"
const FLOATER := "floater"
const POCKET := "pocket"
const DOOR := "door"
const SPINNER := "spinner"
const FUSE := "fuse"

const LEVEL_COUNT := 10          ## levels/0000.svg .. 0009.svg
const MENU_LEVELS := 9           ## console.mxml has buttons Level 1..9


## console.mxml ordLevel: menu position (1..9) -> svg number. 0008.svg (the
## "debug level") is not on the menu.
static func ord_level(ord: int) -> int:
	match ord:
		1: return 0
		2: return 1
		3: return 3
		4: return 9
		5: return 4
		6: return 6
		7: return 7
		8: return 5
		9: return 2
	return 0


static func level_name(ord: int) -> String:
	match ord:
		1: return "AIRLOCK CONTROL"
		2: return "HVAC SYSTEMS"
		3: return "CARGO HOLD"
		4: return "BREAK ROOM"
		5: return "MAIN TORQUE CONTROL"
		6: return "DRILL IDLE TORQUE CONTROL"
		7: return "AUTOMATED CONTROL SYSTEM"
		8: return "CHECKPOINT"
		9: return "WASTE BYPRODUCT STORAGE"
	return ""


static func level_text(ord: int) -> String:
	match ord:
		1: return ("In order to avoid explosive decompression throughout the\n"
				+ "ship, please restore power & control here first.")
		2: return ("This facility handles life support and stores liquid O2\n"
				+ "DO NOT TAUNT LIQUID OXYGEN STORAGE FACILITY.")
		3: return ("These valuable mineral containers are ready for delivery.\n"
				+ "Please handle with care, as they are roughly fourteen \n"
				+ "thousand times more valuable than you.")
		4: return "As an unmanned vessel, the OM-NOM-NOM stores fuses here."
		5: return "This controls the torque to the asteroid drill units."
		6: return ("Each rotating system connects to a drill sub-assembly to\n"
				+ "manage torque-draw-latency, AKA the drillsplosion effect.")
		7: return ("The brains of the mining process, these systems are quite\n"
				+ "valuable - try not to destroy anything.")
		8: return "Pass through this chamber to reach the forward bulkheads."
		9: return ("The mining process produces many materials of limited\n"
				+ "value. Some of these containers store radioactive waste.\n"
				+ "Others may be mobile for shielding.")
	return ""


## Game1.loadLevel: which bg/fg art goes with each svg. FG0003 and FG0009 are
## blank.png in assets.swfml, and level 8 reuses the level 9 art ("debug level").
static func bg_name(level: int) -> String:
	match level:
		8, 9: return "bg0009"
		_: return "bg%04d" % level if level >= 0 and level <= 7 else ""


static func fg_name(level: int) -> String:
	match level:
		0, 1, 2, 4, 5, 6, 7: return "fg%04d" % level
	return ""  # 3, 8, 9: blank.png


## ---- scores (SharedObject "shep_scores": level_N = seconds left) ----------

## console.mxml unlockLevels: Level 1 is always open, Level i needs the svg
## behind Level i-1 to have a saved score.
static func is_unlocked(ord: int, scores: Dictionary) -> bool:
	if ord == 1:
		return true
	return scores.has(ord_level(ord - 1))


## unlockLevels shows the trophy when raw_score(9) exists. That's svg 9, which is
## menu Level 4, not the last level. Kept as-is (see PORT.md).
static func shows_trophy(scores: Dictionary) -> bool:
	return scores.has(9)


## showLevelInfo: best time is 120 - seconds left.
static func best_time_text(level: int, scores: Dictionary) -> String:
	if not scores.has(level):
		return "No Best Time Yet!"
	return "Best Time: %d seconds" % (TIME_LIMIT - int(scores[level]))


## Game1.updateHighScores: keep the larger seconds-left value. Returns true when
## the score was saved.
static func record_score(scores: Dictionary, level: int, secs_left: int) -> bool:
	if scores.has(level) and secs_left <= int(scores[level]):
		return false
	scores[level] = secs_left
	return true


## ---- clock (FlashClock) ------------------------------------------------------

## FlashClock.updateCount: ceil(timeLeft), floored at 0.
static func time_count(time_left: float) -> int:
	return maxi(0, ceili(time_left))


## FlashClock.toString: MM:SS.
static func clock_text(count: int) -> String:
	var mins := count / 60
	var secs := count % 60
	return "%d%d:%d%d" % [mins / 10, mins % 10, secs / 10, secs % 10]


## Game1.updateClock: which alert plays when the displayed second changes.
## Returns "" above 30 seconds, otherwise alert1 / alert2 / alert3 / alert3x2.
static func alert_for(count: int) -> String:
	if count > 30:
		return ""
	if count <= 5:
		return "alert3x2"
	if count <= 10:
		return "alert3"
	if count <= 20:
		return "alert2"
	return "alert1"


## Game1.updateClock red alert: (1 + sin(timeLeft*5)) * 0.40.
static func red_alert_v(time_left: float) -> float:
	return (1.0 + sin(time_left * 5.0)) * 0.40


## ---- steering (Game1.calcVector) --------------------------------------------

## A vector from the bot toward the mouse with length sqrt(r). Like the original,
## a mouse exactly above or below the bot gives (0, rise) instead.
static func calc_vector(from: Vector2, to: Vector2, r: float) -> Vector2:
	var rise := to.y - from.y
	var run := to.x - from.x
	if run == 0.0:
		return Vector2(0, rise)
	var m := rise / run
	var vx := sqrt(r) / sqrt(m * m + 1.0)
	vx *= 1.0 if to.x > from.x else -1.0
	return Vector2(vx, m * vx)


## Game1.drawVector: the bot sprite's rotation (degrees) for a calcVector result.
static func aim_rotation_deg(v: Vector2) -> float:
	if v.x == 0.0:
		return 0.0 if v.y <= 0.0 else 180.0
	var deg := 90.0 + rad_to_deg(atan(v.y / v.x))
	if v.x < 0.0:
		deg += 180.0
	return deg


## shepClipVector: unit vector the bot sprite faces (sprite points up).
static func facing(rotation_deg: float) -> Vector2:
	var r := deg_to_rad(rotation_deg - 90.0)
	return Vector2(cos(r), sin(r))


## ---- SVG ---------------------------------------------------------------------

static func level_svg(level: int) -> String:
	if level < 0 or level >= LevelPack.SVG.size():
		return ""
	return LevelPack.SVG[level]


## The parsed level: {"start": Vector2, "items": Array[Dictionary]}.
## Items come out in parseSVG order: every <rect>, then every <polygon>, then
## every <circle>. Only direct children of <svg> count (Xml.elementsNamed), so
## the border <line>s inside <g> are ignored, as are <polyline>s.
static func parse_svg(xml_text: String) -> Dictionary:
	var rects: Array[Dictionary] = []
	var polys: Array[Dictionary] = []
	var circles: Array[Dictionary] = []
	var parser := XMLParser.new()
	if xml_text.is_empty() or parser.open_buffer(xml_text.to_utf8_buffer()) != OK:
		return {"start": DEFAULT_START, "items": []}
	var depth := 0
	while parser.read() == OK:
		var t := parser.get_node_type()
		if t == XMLParser.NODE_ELEMENT:
			var name := parser.get_node_name()
			if depth == 1:
				var attrs := {}
				for i in parser.get_attribute_count():
					attrs[parser.get_attribute_name(i)] = parser.get_attribute_value(i)
				match name:
					"rect": rects.append(attrs)
					"polygon": polys.append(attrs)
					"circle": circles.append(attrs)
			if not parser.is_empty():
				depth += 1
		elif t == XMLParser.NODE_ELEMENT_END:
			depth -= 1

	var items: Array[Dictionary] = []
	var start := DEFAULT_START
	for a in rects:
		var x := _num(a, "x")
		var y := _num(a, "y")
		var w := _num(a, "width")
		var h := _num(a, "height")
		var rect := Rect2(x, y, w, h)
		var c := rect.get_center()
		match a.get("fill", ""):
			GREEN: items.append({"kind": POCKET, "pos": c, "code": 0})
			CYAN: items.append({"kind": POCKET, "pos": c, "code": 1})
			DARK_CYAN: items.append({"kind": DOOR, "rect": rect})
			BLUE: items.append({"kind": SPINNER, "pos": c, "horizontal": w > h})
			_: items.append({"kind": WALL_RECT, "rect": rect})
	for a in polys:
		var item := _poly_item(a)
		if not item.is_empty():
			items.append(item)
	for a in circles:
		var c := Vector2(_num(a, "cx"), _num(a, "cy"))
		var fill: String = a.get("fill", "")
		if fill == GREEN:
			start = c  # green is the hero
		else:
			# anything else is a fuseball. Red circles become the plain fuse
			# (BallClip, cyan glow, code 0); every other color becomes the red
			# fuse (RedBallClip, red glow, code 1), as in the original.
			items.append({"kind": FUSE, "pos": c, "code": 0 if fill == RED else 1})
	return {"start": start, "items": items}


static func parse_level(level: int) -> Dictionary:
	return parse_svg(level_svg(level))


## addPolyXml: vertices recentered on their average. Magenta polygons float
## (8 vertices: cargo box, otherwise: hex crate); every other polygon is a wall.
static func _poly_item(a: Dictionary) -> Dictionary:
	var raw: String = a.get("points", "")
	var pts := PackedVector2Array()
	# Illustrator wraps long point lists across lines, so split on any
	# whitespace (the original split on " ").
	for pair in raw.strip_edges().replace("\n", " ").replace("\t", " ").replace("\r", " ").split(" ", false):
		var xy := pair.split(",")
		if xy.size() >= 2:
			var p := Vector2(xy[0].to_float(), xy[1].to_float())
			# drop repeated vertices (0007.svg has a couple); physaxe would
			# have made a zero-length edge out of them
			if pts.is_empty() or pts[pts.size() - 1].distance_to(p) > 0.01:
				pts.append(p)
	if pts.size() > 2 and pts[0].distance_to(pts[pts.size() - 1]) <= 0.01:
		pts.remove_at(pts.size() - 1)
	if pts.size() < 3:
		return {}
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var local := PackedVector2Array()
	for p in pts:
		local.append(p - c)
	if a.get("fill", "") == MAGENTA:
		return {"kind": FLOATER, "center": c, "points": local,
			"clip": "cargo" if local.size() == 8 else "crate"}
	return {"kind": WALL_POLY, "center": c, "points": local}


static func _num(a: Dictionary, key: String) -> float:
	return String(a.get(key, "0")).to_float()


## Shoelace area (absolute) for mass = area * density.
static func poly_area(pts: PackedVector2Array) -> float:
	var s := 0.0
	for i in pts.size():
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		s += p.x * q.y - q.x * p.y
	return absf(s) * 0.5


static func count_kind(level: Dictionary, kind: String, code := -1) -> int:
	var n := 0
	for it in level["items"]:
		if it["kind"] == kind and (code < 0 or int(it.get("code", -1)) == code):
			n += 1
	return n
