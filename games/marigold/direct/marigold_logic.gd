extends RefCounted
## Marigold Homestead — game state & rules.
## Data tables transcribed from Claude artifact BjKJn834 (notes.json / source.js).
## Homestead is a Starflight-II-style procedural planet surface with tractor driving
## (not the mock's click-to-plant grid).

const STAGE_W := 1280
const STAGE_H := 720

const SEASONS := ["Spring", "Summer", "Fall", "Winter"]

## Crop catalog: grow days of water, seed cost, sell price.
const CROPS := [
	{"id": "starberry", "name": "Starberry", "grow": 5, "seed": 60, "sell": 160, "season": "Spring"},
	{"id": "glowmelon", "name": "Glowmelon", "grow": 4, "seed": 40, "sell": 120, "season": "Summer"},
	{"id": "voidwheat", "name": "Void Wheat", "grow": 3, "seed": 20, "sell": 55, "season": "Fall"},
	{"id": "astrospud", "name": "Astro-Spud", "grow": 3, "seed": 25, "sell": 70, "season": "Winter"},
	{"id": "nebulakelp", "name": "Nebula Kelp", "grow": 6, "seed": 80, "sell": 225, "season": "Any"},
]

const COMMODITIES := [
	{"id": "titanore", "name": "Titan Ore", "buy": 55, "sell": 78},
	{"id": "glimmerspice", "name": "Glimmer Spice", "buy": 90, "sell": 128},
]

const CREW := [
	{"name": "Mira Voss", "role": "Botanist", "wage": 600},
	{"name": "Tomas Kade", "role": "Pilot", "wage": 550},
	{"name": "Old Bex", "role": "Quartermaster", "wage": 500},
]

## Sector chart systems (x/y are % of chart).
const SYSTEMS := [
	{
		"id": "havenport", "name": "Havenport", "kind": "station", "x": 50, "y": 82,
		"links": ["verdance", "cinder"],
		"scan": {
			"biome": "Orbital Trade Hub", "gravity": "0.4g spin", "atmo": "Pressurized",
			"water": "Recycled", "soil": 0, "hazards": "Heavy docking traffic",
			"rec": "Refuel and sell your harvest at fair prices here.",
			"resources": [{"name": "Fuel Cells", "pct": 80}, {"name": "General Trade", "pct": 64}],
		},
	},
	{
		"id": "verdance", "name": "Verdance III", "kind": "lush", "x": 24, "y": 58,
		"links": ["havenport", "tidepool"],
		"scan": {
			"biome": "Temperate Meadowlands", "gravity": "1.0g", "atmo": "Breathable",
			"water": "Abundant", "soil": 88, "hazards": "Mild pollen storms",
			"rec": "Your homestead. Ideal for Starberry & Glowmelon.",
			"resources": [{"name": "Rich Loam", "pct": 88}, {"name": "Fresh Water", "pct": 74}],
		},
	},
	{
		"id": "cinder", "name": "Cinder Reach", "kind": "rock", "x": 76, "y": 60,
		"links": ["havenport", "frostwell"],
		"scan": {
			"biome": "Volcanic Badlands", "gravity": "1.3g", "atmo": "Thin / toxic",
			"water": "Trace", "soil": 22, "hazards": "Heat vents, ashfall",
			"rec": "Mine Titan Ore. Not arable land.",
			"resources": [{"name": "Titan Ore", "pct": 71}, {"name": "Geothermal", "pct": 55}],
		},
	},
	{
		"id": "tidepool", "name": "Tidepool", "kind": "lush", "x": 16, "y": 30,
		"links": ["verdance", "driftmarket"],
		"scan": {
			"biome": "Shallow Ocean World", "gravity": "0.9g", "atmo": "Humid",
			"water": "Oceanic", "soil": 60, "hazards": "Tidal surges",
			"rec": "Best soil chemistry for Nebula Kelp.",
			"resources": [{"name": "Kelp Beds", "pct": 82}, {"name": "Sea Brine", "pct": 48}],
		},
	},
	{
		"id": "frostwell", "name": "Frostwell", "kind": "ice", "x": 84, "y": 28,
		"links": ["cinder", "driftmarket"],
		"scan": {
			"biome": "Glacier Fields", "gravity": "1.1g", "atmo": "Frozen",
			"water": "Locked ice", "soil": 30, "hazards": "Whiteouts, -60C",
			"rec": "Only hardy Astro-Spud survives the cold.",
			"resources": [{"name": "Ice Cores", "pct": 77}, {"name": "Rare Gas", "pct": 41}],
		},
	},
	{
		"id": "driftmarket", "name": "Drift Market", "kind": "station", "x": 50, "y": 14,
		"links": ["tidepool", "frostwell"],
		"scan": {
			"biome": "Free-Port Bazaar", "gravity": "0.3g spin", "atmo": "Pressurized",
			"water": "Imported", "soil": 0, "hazards": "Pirate rumors",
			"rec": "Premium prices for exotic crops & spice.",
			"resources": [{"name": "Luxury Spice", "pct": 62}, {"name": "Salvage", "pct": 50}],
		},
	},
]

## Procedural planet surface (Starflight-II style). Tile world for tractor.
const MAP_W := 64
const MAP_H := 64
const TILE := 16  ## world pixels per tile at 1× (drawn scaled in UI)

## Terrain kinds.
const T_WATER := 0
const T_ROCK := 1
const T_GRASS := 2
const T_SOIL := 3  ## arable

## Tools: plant uses selected seed id; water / harvest are special.
const TOOL_WATER := "water"
const TOOL_HARVEST := "harvest"

var screen: String = "cockpit"
var credits: int = 5000
var fuel: int = 14
var fuel_max: int = 20
var day: int = 1
var month_index: int = 0
var cargo: Dictionary = {}  ## id -> {qty, cost}
var cargo_cap: int = 60
var seeds: Dictionary = {"starberry": 3, "voidwheat": 6, "astrospud": 4}
var selected_seed: String = "starberry"
var tool: String = "starberry"  ## seed id | water | harvest
var current: String = "havenport"
var selected_system: String = "verdance"
var ledger: Array = []  ## [{month, cat, kind, amount}] kind in rev/cogs/exp
var ledger_month: int = 0
var log_lines: Array = ["Welcome aboard the Marigold. Your homestead awaits on Verdance III."]
var hull: float = 100.0

## Homestead crops keyed "x,y" -> {crop, progress, watered, ready}
var plots: Dictionary = {}
## Tractor world position in tile coords (float for smooth move).
var tractor_x: float = 32.0
var tractor_y: float = 32.0
var tractor_facing: Vector2 = Vector2(0, 1)
## Last tile we applied the tool to (avoid spamming same cell every frame).
var _last_tool_tile: Vector2i = Vector2i(-999, -999)

## Cached terrain [y][x] ints.
var terrain: Array = []


func _init() -> void:
	_build_terrain()
	# Park tractor on a soil patch near center.
	for r in range(8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var tx := 32 + dx
				var ty := 32 + dy
				if _in_map(tx, ty) and terrain_at(tx, ty) == T_SOIL:
					tractor_x = float(tx) + 0.5
					tractor_y = float(ty) + 0.5
					return


func _build_terrain() -> void:
	terrain.clear()
	terrain.resize(MAP_H)
	for y in MAP_H:
		var row: Array = []
		row.resize(MAP_W)
		for x in MAP_W:
			row[x] = _terrain_at_gen(x, y)
		terrain[y] = row


func _hash2(x: int, y: int) -> float:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return float(n & 0x7fffffff) / 2147483647.0


func _noise(x: float, y: float) -> float:
	var x0 := int(floor(x))
	var y0 := int(floor(y))
	var fx := x - float(x0)
	var fy := y - float(y0)
	var a := _hash2(x0, y0)
	var b := _hash2(x0 + 1, y0)
	var c := _hash2(x0, y0 + 1)
	var d := _hash2(x0 + 1, y0 + 1)
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uy := fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uy)


func _fbm(x: float, y: float) -> float:
	var v := 0.0
	var amp := 0.5
	var freq := 1.0
	for _i in 4:
		v += amp * _noise(x * freq, y * freq)
		amp *= 0.5
		freq *= 2.0
	return v


func _terrain_at_gen(x: int, y: int) -> int:
	# Fractal height + moisture → Starflight-ish biome patches.
	var h := _fbm(x * 0.08 + 3.1, y * 0.08 + 1.7)
	var m := _fbm(x * 0.11 + 20.0, y * 0.11 + 9.0)
	if h < 0.32:
		return T_WATER
	if h > 0.72 or (h > 0.58 and m < 0.35):
		return T_ROCK
	if m > 0.48 and h > 0.38 and h < 0.62:
		return T_SOIL
	return T_GRASS


func terrain_at(x: int, y: int) -> int:
	if not _in_map(x, y):
		return T_ROCK
	return int(terrain[y][x])


func _in_map(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < MAP_W and y < MAP_H


func plot_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


func get_plot(x: int, y: int) -> Variant:
	return plots.get(plot_key(x, y), null)


func crop_by_id(id: String) -> Dictionary:
	for c in CROPS:
		if c["id"] == id:
			return c
	return {}


func system_by_id(id: String) -> Dictionary:
	for s in SYSTEMS:
		if s["id"] == id:
			return s
	return {}


func is_station(id: String = "") -> bool:
	var sid := id if id != "" else current
	var s := system_by_id(sid)
	return s.get("kind", "") == "station"


func cargo_qty() -> int:
	var n := 0
	for id in cargo:
		n += int(cargo[id]["qty"])
	return n


func cargo_cost_total() -> int:
	var n := 0
	for id in cargo:
		n += int(cargo[id]["cost"])
	return n


func crew_wages() -> int:
	var n := 0
	for c in CREW:
		n += int(c["wage"])
	return n


func push_log(msg: String) -> void:
	log_lines.push_front(msg)
	while log_lines.size() > 5:
		log_lines.pop_back()


func latest_log() -> String:
	return str(log_lines[0]) if log_lines.size() > 0 else ""


func _ledger_add(cat: String, kind: String, amount: int, month: int = -1) -> void:
	var m := month if month >= 0 else month_index
	ledger.append({"month": m, "cat": cat, "kind": kind, "amount": amount})


func set_screen(id: String) -> void:
	screen = id


func set_tool(t: String) -> void:
	tool = t
	if t != TOOL_WATER and t != TOOL_HARVEST:
		selected_seed = t


func buy_seed(id: String) -> void:
	var crop := crop_by_id(id)
	if crop.is_empty():
		return
	var cost: int = int(crop["seed"])
	if credits < cost:
		push_log("Need %d cr for %s seed." % [cost, crop["name"]])
		return
	credits -= cost
	seeds[id] = int(seeds.get(id, 0)) + 1
	_ledger_add("Seeds & Supplies", "exp", cost)
	push_log("Bought 1 %s seed (−%d cr)." % [crop["name"], cost])


func buy_fuel() -> void:
	if fuel >= fuel_max:
		push_log("Fuel tanks are full.")
		return
	if credits < 30:
		push_log("Need 30 cr to refuel.")
		return
	credits -= 30
	fuel += 1
	_ledger_add("Fuel", "exp", 30)
	push_log("Refueled +1 (−30 cr).")


func buy_good(id: String) -> void:
	if not is_station():
		push_log("No market here — dock at a trade station.")
		return
	var good: Dictionary = {}
	for c in COMMODITIES:
		if c["id"] == id:
			good = c
			break
	if good.is_empty():
		return
	var price: int = int(good["buy"])
	if cargo_qty() >= cargo_cap:
		push_log("Cargo hold is full.")
		return
	if credits < price:
		push_log("Need %d cr for %s." % [price, good["name"]])
		return
	credits -= price
	if not cargo.has(id):
		cargo[id] = {"qty": 0, "cost": 0}
	cargo[id]["qty"] = int(cargo[id]["qty"]) + 1
	cargo[id]["cost"] = int(cargo[id]["cost"]) + price
	push_log("Bought 1 %s (−%d cr)." % [good["name"], price])


func sell_good(id: String) -> void:
	if not is_station():
		push_log("No market here — dock at a trade station.")
		return
	if not cargo.has(id) or int(cargo[id]["qty"]) <= 0:
		push_log("None in hold to sell.")
		return
	var price := _sell_price(id)
	if price <= 0:
		push_log("No buyer for that here.")
		return
	var entry: Dictionary = cargo[id]
	var qty: int = int(entry["qty"])
	var avg_cost: int = int(round(float(entry["cost"]) / float(qty))) if qty > 0 else 0
	entry["qty"] = qty - 1
	entry["cost"] = maxi(0, int(entry["cost"]) - avg_cost)
	if int(entry["qty"]) <= 0:
		cargo.erase(id)
	credits += price
	var is_crop := not crop_by_id(id).is_empty()
	_ledger_add("Crop Sales" if is_crop else "Trade Sales", "rev", price)
	if avg_cost > 0:
		_ledger_add("Cost of Goods Sold", "cogs", avg_cost)
	var name := id
	var c := crop_by_id(id)
	if not c.is_empty():
		name = c["name"]
	else:
		for g in COMMODITIES:
			if g["id"] == id:
				name = g["name"]
				break
	push_log("Sold 1 %s (+%d cr)." % [name, price])


func _sell_price(id: String) -> int:
	var c := crop_by_id(id)
	if not c.is_empty():
		return int(c["sell"])
	for g in COMMODITIES:
		if g["id"] == id:
			return int(g["sell"])
	return 0


func select_system(id: String) -> void:
	selected_system = id


func can_jump_to(id: String) -> bool:
	if id == current:
		return false
	var s := system_by_id(current)
	return id in s.get("links", [])


func jump_cost_fuel() -> int:
	return 2


func jump_cost_days() -> int:
	return 1


func plot_course() -> void:
	travel(selected_system)


func travel(to_id: String) -> void:
	if to_id == current:
		push_log("You are already here.")
		return
	if not can_jump_to(to_id):
		push_log("No charted route — choose a linked system.")
		return
	if fuel < jump_cost_fuel():
		push_log("Not enough fuel for the jump. Refuel first.")
		return
	fuel -= jump_cost_fuel()
	var dest := system_by_id(to_id)
	current = to_id
	selected_system = to_id
	_advance_days(jump_cost_days())
	if dest.get("kind", "") == "station":
		if credits >= 150:
			credits -= 150
			_ledger_add("Docking Fees", "exp", 150)
			push_log("Jumped to %s (docking fee 150cr)." % dest["name"])
		else:
			push_log("Jumped to %s (could not pay docking fee)." % dest["name"])
	else:
		push_log("Jumped to %s." % dest["name"])


func end_day() -> void:
	_advance_days(1)
	push_log("Day ended. Crops advanced where watered.")


func _advance_days(n: int) -> void:
	for _i in n:
		_advance_one_day()


func _advance_one_day() -> void:
	for key in plots.keys():
		var p: Dictionary = plots[key]
		if p.get("ready", false):
			continue
		if p.get("watered", false):
			p["progress"] = int(p["progress"]) + 1
			var crop := crop_by_id(str(p["crop"]))
			var need: int = int(crop.get("grow", 99))
			if int(p["progress"]) >= need:
				p["ready"] = true
				p["progress"] = need
		p["watered"] = false
	day += 1
	if day > 28:
		day = 1
		var closed := month_index
		month_index += 1
		var wages := crew_wages()
		var life := 300
		credits -= wages + life
		_ledger_add("Crew Wages", "exp", wages, closed)
		_ledger_add("Life Support", "exp", life, closed)
		ledger_month = month_index
		push_log("Month closed — paid crew wages and life support.")


## Move tractor by delta tiles (float). Applies current tool under wheels.
func drive(dx: float, dy: float) -> void:
	if absf(dx) < 0.0001 and absf(dy) < 0.0001:
		return
	if absf(dx) > absf(dy):
		tractor_facing = Vector2(signf(dx), 0)
	else:
		tractor_facing = Vector2(0, signf(dy))
	var nx := clampf(tractor_x + dx, 0.5, float(MAP_W) - 0.5)
	var ny := clampf(tractor_y + dy, 0.5, float(MAP_H) - 0.5)
	var tx := int(floor(nx))
	var ty := int(floor(ny))
	# Block water / rock for driving (bounce).
	var t := terrain_at(tx, ty)
	if t == T_WATER or t == T_ROCK:
		return
	tractor_x = nx
	tractor_y = ny
	_apply_tool_at(tx, ty)
	# Short trail behind tractor also gets the tool once.
	var trail := Vector2i(tx - int(tractor_facing.x), ty - int(tractor_facing.y))
	if _in_map(trail.x, trail.y):
		var tt := terrain_at(trail.x, trail.y)
		if tt == T_SOIL or tt == T_GRASS:
			_apply_tool_at(trail.x, trail.y)


func apply_tool_here() -> void:
	_last_tool_tile = Vector2i(-999, -999)
	_apply_tool_at(int(floor(tractor_x)), int(floor(tractor_y)))


func _apply_tool_at(tx: int, ty: int) -> void:
	var tile := Vector2i(tx, ty)
	if tile == _last_tool_tile:
		return
	_last_tool_tile = tile
	if tool == TOOL_WATER:
		_water_tile(tx, ty)
	elif tool == TOOL_HARVEST:
		_harvest_tile(tx, ty)
	else:
		_plant_tile(tx, ty, tool)


func _plant_tile(tx: int, ty: int, crop_id: String) -> void:
	if terrain_at(tx, ty) != T_SOIL:
		return
	if get_plot(tx, ty) != null:
		return
	var crop := crop_by_id(crop_id)
	if crop.is_empty():
		return
	var have: int = int(seeds.get(crop_id, 0))
	if have <= 0:
		push_log("Out of %s seeds — buy more from the locker." % crop["name"])
		return
	seeds[crop_id] = have - 1
	plots[plot_key(tx, ty)] = {
		"crop": crop_id, "progress": 0, "watered": false, "ready": false,
	}
	push_log("Planted %s." % crop["name"])


func _water_tile(tx: int, ty: int) -> void:
	var p = get_plot(tx, ty)
	if p == null:
		return
	if p.get("ready", false):
		return
	if p.get("watered", false):
		return
	p["watered"] = true
	push_log("Watered crop.")


func _harvest_tile(tx: int, ty: int) -> void:
	var key := plot_key(tx, ty)
	if not plots.has(key):
		return
	var p: Dictionary = plots[key]
	if not p.get("ready", false):
		return
	if cargo_qty() >= cargo_cap:
		push_log("Cargo hold is full.")
		return
	var crop_id: String = str(p["crop"])
	if not cargo.has(crop_id):
		cargo[crop_id] = {"qty": 0, "cost": 0}
	cargo[crop_id]["qty"] = int(cargo[crop_id]["qty"]) + 1
	# Harvested crops enter at 0 cost (artifact mechanics).
	plots.erase(key)
	var crop := crop_by_id(crop_id)
	push_log("Harvested %s into the hold." % crop.get("name", crop_id))


func water_all() -> void:
	var n := 0
	for key in plots:
		var p: Dictionary = plots[key]
		if p.get("ready", false):
			continue
		if p.get("watered", false):
			continue
		p["watered"] = true
		n += 1
	if n == 0:
		push_log("Nothing needs watering.")
	else:
		push_log("Watered %d crop(s)." % n)


func harvest_all() -> void:
	var n := 0
	var keys: Array = plots.keys()
	for key in keys:
		var p: Dictionary = plots[key]
		if not p.get("ready", false):
			continue
		if cargo_qty() >= cargo_cap:
			push_log("Cargo hold is full.")
			break
		var crop_id: String = str(p["crop"])
		if not cargo.has(crop_id):
			cargo[crop_id] = {"qty": 0, "cost": 0}
		cargo[crop_id]["qty"] = int(cargo[crop_id]["qty"]) + 1
		plots.erase(key)
		n += 1
	if n == 0:
		push_log("No ripe crops to harvest.")
	else:
		push_log("Harvested %d crop(s) into the hold." % n)


func planted_count() -> int:
	return plots.size()


func ready_count() -> int:
	var n := 0
	for key in plots:
		if plots[key].get("ready", false):
			n += 1
	return n


func season_name(m: int = -1) -> String:
	var mi := m if m >= 0 else month_index
	return SEASONS[mi % 4]


func year_num(m: int = -1) -> int:
	var mi := m if m >= 0 else month_index
	return mi / 4 + 1


func date_label() -> String:
	return "%s · Day %d/28" % [season_name(), day]


func get_income(m: int) -> Dictionary:
	var rev_crop := 0
	var rev_trade := 0
	var cogs := 0
	var exp := {"Seeds & Supplies": 0, "Fuel": 0, "Docking Fees": 0, "Crew Wages": 0, "Life Support": 0}
	for e in ledger:
		if int(e["month"]) != m:
			continue
		var amt: int = int(e["amount"])
		match str(e["kind"]):
			"rev":
				if e["cat"] == "Crop Sales":
					rev_crop += amt
				else:
					rev_trade += amt
			"cogs":
				cogs += amt
			"exp":
				if exp.has(e["cat"]):
					exp[e["cat"]] = int(exp[e["cat"]]) + amt
	var total_rev := rev_crop + rev_trade
	var gross := total_rev - cogs
	var total_opex := 0
	for k in exp:
		total_opex += int(exp[k])
	return {
		"rev_crop": rev_crop, "rev_trade": rev_trade, "total_rev": total_rev,
		"cogs": cogs, "gross": gross, "exp": exp, "total_opex": total_opex,
		"net": gross - total_opex,
	}


func get_balance() -> Dictionary:
	var cash := credits
	var inv := cargo_cost_total()
	var ship := 50000
	var assets := cash + inv + ship
	var loan := 30000
	var paid_in := 25000
	var retained := 0
	for m in range(month_index + 1):
		var inc := get_income(m)
		retained += int(inc["net"])
	# Opening equity roughly balances: paid_in + (assets - loan - paid_in) at start.
	# Artifact: liab = loan 30000; equity = paidIn 25000 + retained.
	var equity := paid_in + retained
	var liab_eq := loan + equity
	return {
		"cash": cash, "inv": inv, "ship": ship, "assets": assets,
		"loan": loan, "paid_in": paid_in, "retained": retained,
		"equity": equity, "liab_eq": liab_eq, "balanced": assets == liab_eq,
	}


func jump_status_text() -> String:
	if selected_system == current:
		return "Status: Current location"
	if can_jump_to(selected_system):
		return "Status: In jump range"
	return "Status: No direct route"
