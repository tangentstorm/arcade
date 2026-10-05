class_name OfcpPlayProfile
extends RefCounted
## Venue / FL rule packs: cash (aka normal), windfall, progressive.


static func profiles() -> Dictionary:
	return {
		"normal": _make("normal", "cash / normal", true, true, true, false, 14, 40, 50),
		"cash": _make("cash", "cash (alias of normal)", true, true, true, false, 14, 40, 50),
		"windfall": _make("windfall", "3-max windfall mini", true, false, true, false, 14, 22, 35),
		"progressive": _make("progressive", "progressive FL cards", true, true, true, true, 14, 40, 50),
	}


static func _make(
	id: String,
	label: String,
	fl_stay_trips_top: bool,
	fl_stay_mid_fh: bool,
	fl_stay_quads_bot: bool,
	progressive_fl_cards: bool,
	default_fl_cards: int,
	fl_entry_bonus: int,
	fl_trips_bonus: int,
) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"flStayTripsTop": fl_stay_trips_top,
		"flStayMidFullHouse": fl_stay_mid_fh,
		"flStayQuadsBottom": fl_stay_quads_bot,
		"progressiveFlCards": progressive_fl_cards,
		"defaultFlCards": default_fl_cards,
		"flEntryBonus": fl_entry_bonus,
		"flTripsBonus": fl_trips_bonus,
	}


static func resolve(id = null) -> Dictionary:
	var all_p: Dictionary = profiles()
	if id == null or str(id) == "":
		return all_p["normal"]
	var key: String = str(id)
	if key == "cash":
		return all_p["cash"]
	if all_p.has(key):
		return all_p[key]
	return all_p["normal"]


static func qualifies_for_fantasyland_repeat(board: Dictionary, profile_id = "normal") -> bool:
	var profile: Dictionary = resolve(profile_id)
	if OfcpScoring.is_fouled(board):
		return false

	if profile["flStayTripsTop"]:
		var top_rank: Dictionary = OfcpHandEval.evaluate3(board["top"])
		if top_rank["category"] >= OfcpTypes.HandCategory.THREE_OF_A_KIND:
			return true
	if profile["flStayMidFullHouse"]:
		var mid_rank: Dictionary = OfcpHandEval.evaluate5(board["middle"])
		if mid_rank["category"] >= OfcpTypes.HandCategory.FULL_HOUSE:
			return true
	if profile["flStayQuadsBottom"]:
		var bot_rank: Dictionary = OfcpHandEval.evaluate5(board["bottom"])
		if bot_rank["category"] >= OfcpTypes.HandCategory.FOUR_OF_A_KIND:
			return true
	return false


static func fantasyland_card_count(board: Dictionary, profile_id = "normal") -> int:
	var profile: Dictionary = resolve(profile_id)
	if OfcpScoring.is_fouled(board) or not profile["progressiveFlCards"]:
		return profile["defaultFlCards"]

	var top_rank: Dictionary = OfcpHandEval.evaluate3(board["top"])
	if top_rank["category"] >= OfcpTypes.HandCategory.THREE_OF_A_KIND:
		return 17
	if top_rank["category"] == OfcpTypes.HandCategory.PAIR:
		var v: int = top_rank["kickers"][0]
		if v >= OfcpTypes.RANK_VALUES["A"]:
			return 16
		if v >= OfcpTypes.RANK_VALUES["K"]:
			return 15
		if v >= OfcpTypes.RANK_VALUES["Q"]:
			return 14
	return profile["defaultFlCards"]
