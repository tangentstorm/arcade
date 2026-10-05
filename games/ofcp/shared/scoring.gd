class_name OfcpScoring
extends RefCounted
## Foul, royalties, head-to-head / multi-way scoring, Fantasyland entry.


static func is_fouled(board: Dictionary) -> bool:
	if board["top"].size() < 3 or board["middle"].size() < 5 or board["bottom"].size() < 5:
		return false
	var top_rank: Dictionary = OfcpHandEval.evaluate3(board["top"])
	var mid_rank: Dictionary = OfcpHandEval.evaluate5(board["middle"])
	var bot_rank: Dictionary = OfcpHandEval.evaluate5(board["bottom"])
	if OfcpHandEval.compare_hands(top_rank, mid_rank) > 0:
		return true
	if OfcpHandEval.compare_hands(mid_rank, bot_rank) > 0:
		return true
	return false


static func bottom_royalties(cards: Array) -> int:
	var rank: Dictionary = OfcpHandEval.evaluate5(cards)
	match rank["category"]:
		OfcpTypes.HandCategory.ROYAL_FLUSH:
			return 25
		OfcpTypes.HandCategory.STRAIGHT_FLUSH:
			return 15
		OfcpTypes.HandCategory.FOUR_OF_A_KIND:
			return 10
		OfcpTypes.HandCategory.FULL_HOUSE:
			return 6
		OfcpTypes.HandCategory.FLUSH:
			return 4
		OfcpTypes.HandCategory.STRAIGHT:
			return 2
		_:
			return 0


static func middle_royalties(cards: Array) -> int:
	var rank: Dictionary = OfcpHandEval.evaluate5(cards)
	match rank["category"]:
		OfcpTypes.HandCategory.ROYAL_FLUSH:
			return 50
		OfcpTypes.HandCategory.STRAIGHT_FLUSH:
			return 30
		OfcpTypes.HandCategory.FOUR_OF_A_KIND:
			return 20
		OfcpTypes.HandCategory.FULL_HOUSE:
			return 12
		OfcpTypes.HandCategory.FLUSH:
			return 8
		OfcpTypes.HandCategory.STRAIGHT:
			return 4
		OfcpTypes.HandCategory.THREE_OF_A_KIND:
			return 2
		_:
			return 0


static func top_royalties(cards: Array) -> int:
	var rank: Dictionary = OfcpHandEval.evaluate3(cards)
	if rank["category"] == OfcpTypes.HandCategory.THREE_OF_A_KIND:
		return rank["kickers"][0] - 2 + 10
	if rank["category"] == OfcpTypes.HandCategory.PAIR:
		var pair_value: int = rank["kickers"][0]
		if pair_value >= 6:
			return pair_value - 5
	return 0


static func total_royalties(board: Dictionary) -> int:
	if is_fouled(board):
		return 0
	return top_royalties(board["top"]) + middle_royalties(board["middle"]) + bottom_royalties(board["bottom"])


static func evaluate_row(board: Dictionary, row: String) -> Dictionary:
	if row == "top":
		return OfcpHandEval.evaluate3(board["top"])
	if row == "middle":
		return OfcpHandEval.evaluate5(board["middle"])
	return OfcpHandEval.evaluate5(board["bottom"])


## Returns [scoreA, scoreB] zero-sum.
static func score_head_to_head(board_a: Dictionary, board_b: Dictionary) -> Array:
	var a_fouled: bool = is_fouled(board_a)
	var b_fouled: bool = is_fouled(board_b)

	if a_fouled and b_fouled:
		return [0, 0]

	if a_fouled:
		var b_roy: int = total_royalties(board_b)
		return [-(6 + b_roy), 6 + b_roy]
	if b_fouled:
		var a_roy: int = total_royalties(board_a)
		return [6 + a_roy, -(6 + a_roy)]

	var rows: Array[String] = ["top", "middle", "bottom"]
	var a_wins: int = 0
	var b_wins: int = 0
	for row in rows:
		var cmp: int = OfcpHandEval.compare_hands(evaluate_row(board_a, row), evaluate_row(board_b, row))
		if cmp > 0:
			a_wins += 1
		elif cmp < 0:
			b_wins += 1

	var a_score: int = a_wins - b_wins
	var b_score: int = b_wins - a_wins

	if a_wins == 3:
		a_score += 3
		b_score -= 3
	if b_wins == 3:
		b_score += 3
		a_score -= 3

	var a_roy2: int = total_royalties(board_a)
	var b_roy2: int = total_royalties(board_b)
	a_score += a_roy2 - b_roy2
	b_score += b_roy2 - a_roy2

	return [a_score, b_score]


static func score_vs_opponents(ai_board: Dictionary, opp_boards: Array) -> int:
	var total: int = 0
	for opp in opp_boards:
		var pair: Array = score_head_to_head(ai_board, opp)
		total += pair[0]
	return total


static func qualifies_for_fantasyland(board: Dictionary) -> bool:
	if is_fouled(board):
		return false
	if board["top"].size() < 3:
		return false
	var top_rank: Dictionary = OfcpHandEval.evaluate3(board["top"])
	if top_rank["category"] == OfcpTypes.HandCategory.THREE_OF_A_KIND:
		return true
	if top_rank["category"] == OfcpTypes.HandCategory.PAIR and top_rank["kickers"][0] >= OfcpTypes.RANK_VALUES["Q"]:
		return true
	return false


static func scoring_breakdown(board_a: Dictionary, board_b: Dictionary) -> Dictionary:
	var a_fouled: bool = is_fouled(board_a)
	var b_fouled: bool = is_fouled(board_b)
	var rows: Array[String] = ["top", "middle", "bottom"]
	var a_wins: int = 0
	var b_wins: int = 0
	var row_results_a: Array = []
	var row_results_b: Array = []

	for row in rows:
		var winner: String = "tie"
		if a_fouled and b_fouled:
			winner = "tie"
		elif a_fouled:
			winner = "B"
			b_wins += 1
		elif b_fouled:
			winner = "A"
			a_wins += 1
		else:
			var cmp: int = OfcpHandEval.compare_hands(evaluate_row(board_a, row), evaluate_row(board_b, row))
			if cmp > 0:
				winner = "A"
				a_wins += 1
			elif cmp < 0:
				winner = "B"
				b_wins += 1
		row_results_a.append({"row": row, "winner": winner})
		row_results_b.append({"row": row, "winner": winner})

	var scoop = null
	if a_wins == 3:
		scoop = "A"
	elif b_wins == 3:
		scoop = "B"
	var scoop_bonus: int = 3 if scoop != null else 0

	var a_roy: int = 0 if a_fouled else total_royalties(board_a)
	var b_roy: int = 0 if b_fouled else total_royalties(board_b)

	var net: int = a_wins - b_wins
	if scoop == "A":
		net += 3
	if scoop == "B":
		net -= 3
	net += a_roy - b_roy

	return {
		"playerA": {"fouled": a_fouled, "totalRoyalties": a_roy, "rows": row_results_a},
		"playerB": {"fouled": b_fouled, "totalRoyalties": b_roy, "rows": row_results_b},
		"rowWins": {"A": a_wins, "B": b_wins},
		"scoop": scoop,
		"scoopBonus": scoop_bonus,
		"netScore": net,
	}


static func hand_name(rank: Dictionary) -> String:
	var cat: int = rank["category"]
	var kickers: Array = rank["kickers"]
	var value_names: Dictionary = {
		2: "2", 3: "3", 4: "4", 5: "5", 6: "6", 7: "7", 8: "8",
		9: "9", 10: "T", 11: "J", 12: "Q", 13: "K", 14: "A",
	}
	var hand_names: Dictionary = {
		0: "High Card", 1: "Pair", 2: "Two Pair", 3: "Three of a Kind",
		4: "Straight", 5: "Flush", 6: "Full House", 7: "Four of a Kind",
		8: "Straight Flush", 9: "Royal Flush",
	}
	var base: String = hand_names[cat]
	if cat == OfcpTypes.HandCategory.PAIR:
		return "Pair of %ss" % value_names[kickers[0]]
	if cat == OfcpTypes.HandCategory.TWO_PAIR:
		return "Two Pair %ss and %ss" % [value_names[kickers[0]], value_names[kickers[1]]]
	if cat == OfcpTypes.HandCategory.THREE_OF_A_KIND:
		return "Trip %ss" % value_names[kickers[0]]
	if cat == OfcpTypes.HandCategory.FULL_HOUSE:
		return "Full House %ss over %ss" % [value_names[kickers[0]], value_names[kickers[1]]]
	if cat == OfcpTypes.HandCategory.FOUR_OF_A_KIND:
		return "Quad %ss" % value_names[kickers[0]]
	if cat == OfcpTypes.HandCategory.HIGH_CARD:
		return "%s High" % value_names[kickers[0]]
	if cat == OfcpTypes.HandCategory.STRAIGHT or cat == OfcpTypes.HandCategory.STRAIGHT_FLUSH:
		return "%s (%s high)" % [base, value_names[kickers[0]]]
	return base
