class_name OfcpGame
extends RefCounted
## Pineapple OFCP game flow (deal / place / score). No UI or WSS.


static func create_player(id: String) -> Dictionary:
	return {
		"id": id,
		"board": OfcpTypes.create_empty_board(),
		"hand": [],
		"discarded": [],
		"fantasyland": false,
		"fantasylandNext": false,
		"fantasylandCards": 14,
		"score": 0,
	}


static func create_game(player_ids: Array, mode: String = "normal", profile: String = "normal") -> Dictionary:
	if player_ids.size() < 2 or player_ids.size() > 3:
		push_error("Game requires 2 or 3 players")
		return {}
	var players: Array = []
	for pid in player_ids:
		players.append(create_player(str(pid)))
	var resolved: Dictionary = OfcpPlayProfile.resolve(profile)
	var scores: Array = []
	for _i in player_ids.size():
		scores.append(0)
	return {
		"phase": OfcpTypes.PHASE_WAITING,
		"players": players,
		"deck": [],
		"currentPlayerIndex": 0,
		"round": 0,
		"dealer": 0,
		"scores": scores,
		"mode": mode,
		"profile": resolved["id"],
	}


## Start a hand. Optional rng: OfcpMulberry32 for deterministic shuffle; else OfcpDeck.shuffle.
static func start_hand(state: Dictionary, rng: OfcpMulberry32 = null) -> Dictionary:
	var fresh: Array = OfcpDeck.create_deck()
	var shuffled: Array
	if rng != null:
		shuffled = rng.shuffle(fresh)
	else:
		shuffled = OfcpDeck.shuffle(fresh)

	var players: Array = []
	for p in state["players"]:
		var np: Dictionary = p.duplicate(true)
		np["board"] = OfcpTypes.create_empty_board()
		np["hand"] = []
		np["discarded"] = []
		np["fantasylandNext"] = false
		players.append(np)

	var start_index: int = (state["dealer"] + 1) % players.size()
	var deck: Array = shuffled.duplicate()

	for i in players.size():
		var idx: int = (start_index + i) % players.size()
		if players[idx]["fantasyland"]:
			var fl_cards: int = players[idx].get("fantasylandCards", OfcpPlayProfile.resolve(state["profile"])["defaultFlCards"])
			players[idx]["hand"] = OfcpDeck.deal(deck, fl_cards)
		else:
			players[idx]["hand"] = OfcpDeck.deal(deck, 5)

	var out: Dictionary = state.duplicate(true)
	out["phase"] = OfcpTypes.PHASE_INITIAL_PLACE
	out["players"] = players
	out["deck"] = deck
	out["currentPlayerIndex"] = start_index
	out["round"] = 0
	return out


static func is_valid_placement(board: Dictionary, placement: Dictionary) -> bool:
	return not OfcpTypes.row_is_full(board, placement["row"])


static func place_initial_cards(
	state: Dictionary,
	player_index: int,
	placements: Array,
	discard = null,
) -> Dictionary:
	var players: Array = []
	for p in state["players"]:
		players.append(p.duplicate(true))
	var player: Dictionary = players[player_index]

	var discards: Array = []
	if discard is Array:
		discards = discard
	elif discard != null:
		discards = [discard]

	if player["fantasyland"]:
		if placements.size() != 13 or discards.size() < 1:
			push_error("Fantasyland player must place 13 cards and discard extras")
			return state
	else:
		if placements.size() != 5:
			push_error("Must place exactly 5 cards initially")
			return state

	var new_board: Dictionary = {
		"top": player["board"]["top"].duplicate(),
		"middle": player["board"]["middle"].duplicate(),
		"bottom": player["board"]["bottom"].duplicate(),
	}
	for p in placements:
		var row: String = p["row"]
		if new_board[row].size() >= OfcpTypes.row_capacity(row):
			push_error("Row %s is full" % row)
			return state
		new_board[row] = new_board[row].duplicate()
		new_board[row].append(p["card"])

	player["board"] = new_board
	player["hand"] = []
	player["discarded"] = discards
	players[player_index] = player

	var all_placed: bool = true
	for p2 in players:
		if p2["hand"].size() != 0:
			all_placed = false
			break

	var out: Dictionary = state.duplicate(true)
	out["players"] = players
	if all_placed:
		out["phase"] = OfcpTypes.PHASE_PINEAPPLE_DEAL
		out["currentPlayerIndex"] = (state["dealer"] + 1) % players.size()
		out["round"] = 1
	else:
		out["currentPlayerIndex"] = (player_index + 1) % players.size()
	return out


static func deal_pineapple(state: Dictionary) -> Dictionary:
	if state["phase"] != OfcpTypes.PHASE_PINEAPPLE_DEAL:
		push_error("Not in pineapple deal phase")
		return state

	var players: Array = []
	for p in state["players"]:
		players.append(p.duplicate(true))
	var idx: int = state["currentPlayerIndex"]
	var player: Dictionary = players[idx]

	if player["fantasyland"] and OfcpTypes.board_is_full(player["board"]):
		var next_index: int = _find_next_pineapple_player(state)
		var skip_out: Dictionary = state.duplicate(true)
		if next_index == -1:
			skip_out["phase"] = OfcpTypes.PHASE_SCORING
		else:
			skip_out["currentPlayerIndex"] = next_index
		return skip_out

	var deck: Array = state["deck"].duplicate()
	var cards: Array = OfcpDeck.deal(deck, 3)
	player["hand"] = cards
	players[idx] = player

	var out: Dictionary = state.duplicate(true)
	out["players"] = players
	out["deck"] = deck
	out["phase"] = OfcpTypes.PHASE_PINEAPPLE_PLACE
	return out


static func place_pineapple_cards(state: Dictionary, player_index: int, action: Dictionary) -> Dictionary:
	if state["phase"] != OfcpTypes.PHASE_PINEAPPLE_PLACE:
		push_error("Not in pineapple place phase")
		return state
	if player_index != state["currentPlayerIndex"]:
		push_error("Not your turn")
		return state

	var players: Array = []
	for p in state["players"]:
		players.append(p.duplicate(true))
	var player: Dictionary = players[player_index]

	var new_board: Dictionary = {
		"top": player["board"]["top"].duplicate(),
		"middle": player["board"]["middle"].duplicate(),
		"bottom": player["board"]["bottom"].duplicate(),
	}
	for p in action["placements"]:
		var row: String = p["row"]
		if new_board[row].size() >= OfcpTypes.row_capacity(row):
			push_error("Row %s is full" % row)
			return state
		new_board[row] = new_board[row].duplicate()
		new_board[row].append(p["card"])

	player["board"] = new_board
	player["hand"] = []
	var discarded: Array = player["discarded"].duplicate()
	discarded.append(action["discard"])
	player["discarded"] = discarded
	players[player_index] = player

	var mid: Dictionary = state.duplicate(true)
	mid["players"] = players
	return _advance_after_pineapple(mid)


static func score_hand(state: Dictionary) -> Dictionary:
	if state["phase"] != OfcpTypes.PHASE_SCORING:
		push_error("Not in scoring phase")
		return state

	var players: Array = []
	for p in state["players"]:
		players.append(p.duplicate(true))
	var scores: Array = state["scores"].duplicate()

	for i in players.size():
		for j in range(i + 1, players.size()):
			var pair: Array = OfcpScoring.score_head_to_head(players[i]["board"], players[j]["board"])
			scores[i] += pair[0]
			scores[j] += pair[1]

	var profile = state.get("profile", "normal")
	for i in players.size():
		var fl_next: bool
		if players[i]["fantasyland"]:
			fl_next = OfcpPlayProfile.qualifies_for_fantasyland_repeat(players[i]["board"], profile)
		else:
			fl_next = OfcpScoring.qualifies_for_fantasyland(players[i]["board"])
		var fl_cards: int = OfcpPlayProfile.resolve(profile)["defaultFlCards"]
		if fl_next:
			fl_cards = OfcpPlayProfile.fantasyland_card_count(players[i]["board"], profile)
		players[i]["fantasylandNext"] = fl_next
		players[i]["fantasylandCards"] = fl_cards

	for i in players.size():
		players[i]["fantasyland"] = players[i]["fantasylandNext"]

	var any_fl: bool = false
	for p in players:
		if p["fantasyland"]:
			any_fl = true
			break
	var new_dealer: int = state["dealer"] if any_fl else (state["dealer"] + 1) % players.size()

	var out: Dictionary = state.duplicate(true)
	out["players"] = players
	out["scores"] = scores
	out["dealer"] = new_dealer
	out["phase"] = OfcpTypes.PHASE_GAME_OVER
	return out


static func get_available_rows(board: Dictionary) -> Array:
	var rows: Array = []
	if board["top"].size() < 3:
		rows.append("top")
	if board["middle"].size() < 5:
		rows.append("middle")
	if board["bottom"].size() < 5:
		rows.append("bottom")
	return rows


static func _find_next_pineapple_player(state: Dictionary) -> int:
	var n: int = state["players"].size()
	var start_idx: int = (state["currentPlayerIndex"] + 1) % n
	for i in n:
		var idx: int = (start_idx + i) % n
		if not OfcpTypes.board_is_full(state["players"][idx]["board"]):
			return idx
	return -1


static func _advance_after_pineapple(state: Dictionary) -> Dictionary:
	var all_full: bool = true
	for p in state["players"]:
		if not OfcpTypes.board_is_full(p["board"]):
			all_full = false
			break
	if all_full:
		var done: Dictionary = state.duplicate(true)
		done["phase"] = OfcpTypes.PHASE_SCORING
		return done

	var next_index: int = _find_next_pineapple_player(state)
	if next_index == -1:
		var done2: Dictionary = state.duplicate(true)
		done2["phase"] = OfcpTypes.PHASE_SCORING
		return done2

	var start_player: int = (state["dealer"] + 1) % state["players"].size()
	var new_round: int = state["round"] + 1 if next_index == start_player else state["round"]
	var out: Dictionary = state.duplicate(true)
	out["phase"] = OfcpTypes.PHASE_PINEAPPLE_DEAL
	out["currentPlayerIndex"] = next_index
	out["round"] = new_round
	return out


## Replay the golden game_flow deal sequence for n players with a seeded RNG.
static func simulate_deal_trace(n_players: int, seed: int) -> Dictionary:
	var rng := OfcpMulberry32.new(seed)
	var shuffled: Array = rng.shuffle(OfcpDeck.create_deck())
	var deck: Array = shuffled.duplicate()
	var dealer: int = 0
	var start_index: int = (dealer + 1) % n_players

	var initial: Array = []
	for i in n_players:
		var idx: int = (start_index + i) % n_players
		var cards: Array = OfcpDeck.deal(deck, 5)
		initial.append({"player": idx, "cards": OfcpTypes.cards_to_strings(cards)})

	var pineapple_rounds: Array = []
	var current: int = start_index
	for round_num in range(1, 5):
		for _t in n_players:
			var dealt: Array = OfcpDeck.deal(deck, 3)
			pineapple_rounds.append({
				"round": round_num,
				"player": current,
				"dealt": OfcpTypes.cards_to_strings(dealt),
			})
			current = (current + 1) % n_players

	return {
		"dealer": dealer,
		"startIndex": start_index,
		"shuffledDeck": OfcpTypes.cards_to_strings(shuffled),
		"initial": initial,
		"pineappleRounds": pineapple_rounds,
		"remainingAfter": OfcpTypes.cards_to_strings(deck),
	}
