class_name OfcpTypes
extends RefCounted
## Card / board / game types for Pineapple OFCP. Cards are Dictionaries {rank, suit}.

const RANKS: Array[String] = ["2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"]
const SUITS: Array[String] = ["h", "d", "c", "s"]

const RANK_VALUES: Dictionary = {
	"2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8,
	"9": 9, "T": 10, "J": 11, "Q": 12, "K": 13, "A": 14,
}

enum HandCategory {
	HIGH_CARD = 0,
	PAIR = 1,
	TWO_PAIR = 2,
	THREE_OF_A_KIND = 3,
	STRAIGHT = 4,
	FLUSH = 5,
	FULL_HOUSE = 6,
	FOUR_OF_A_KIND = 7,
	STRAIGHT_FLUSH = 8,
	ROYAL_FLUSH = 9,
}

const CATEGORY_NAMES: Dictionary = {
	0: "HIGH_CARD",
	1: "PAIR",
	2: "TWO_PAIR",
	3: "THREE_OF_A_KIND",
	4: "STRAIGHT",
	5: "FLUSH",
	6: "FULL_HOUSE",
	7: "FOUR_OF_A_KIND",
	8: "STRAIGHT_FLUSH",
	9: "ROYAL_FLUSH",
}

const PHASE_WAITING := "WAITING"
const PHASE_INITIAL_DEAL := "INITIAL_DEAL"
const PHASE_INITIAL_PLACE := "INITIAL_PLACE"
const PHASE_PINEAPPLE_DEAL := "PINEAPPLE_DEAL"
const PHASE_PINEAPPLE_PLACE := "PINEAPPLE_PLACE"
const PHASE_SCORING := "SCORING"
const PHASE_GAME_OVER := "GAME_OVER"


static func make_card(rank: String, suit: String) -> Dictionary:
	return {"rank": rank, "suit": suit}


static func card_to_string(card: Dictionary) -> String:
	return str(card["rank"]) + str(card["suit"])


static func string_to_card(s: String) -> Dictionary:
	return {"rank": s.substr(0, 1), "suit": s.substr(1, 1)}


static func cards_from_strings(strs: Array) -> Array:
	var out: Array = []
	for s in strs:
		out.append(string_to_card(str(s)))
	return out


static func cards_to_strings(cards: Array) -> Array:
	var out: Array = []
	for c in cards:
		out.append(card_to_string(c))
	return out


static func cards_equal(a: Dictionary, b: Dictionary) -> bool:
	return a["rank"] == b["rank"] and a["suit"] == b["suit"]


static func make_hand_rank(category: int, kickers: Array) -> Dictionary:
	return {"category": category, "kickers": kickers}


static func create_empty_board() -> Dictionary:
	return {"top": [], "middle": [], "bottom": []}


static func board_from_strings(top: Array, middle: Array, bottom: Array) -> Dictionary:
	return {
		"top": cards_from_strings(top),
		"middle": cards_from_strings(middle),
		"bottom": cards_from_strings(bottom),
	}


static func board_card_count(board: Dictionary) -> int:
	return board["top"].size() + board["middle"].size() + board["bottom"].size()


static func row_capacity(row: String) -> int:
	return 3 if row == "top" else 5


static func row_is_full(board: Dictionary, row: String) -> bool:
	return board[row].size() >= row_capacity(row)


static func board_is_full(board: Dictionary) -> bool:
	return board["top"].size() == 3 and board["middle"].size() == 5 and board["bottom"].size() == 5


static func rank_value(rank: String) -> int:
	return RANK_VALUES[rank]
