class_name OfcpHandEval
extends RefCounted
## 5-card and 3-card (top) hand evaluation + compareHands with min-kicker quirk.


static func evaluate5(cards: Array) -> Dictionary:
	if cards.size() != 5:
		push_error("evaluate5 requires exactly 5 cards, got %d" % cards.size())
		return OfcpTypes.make_hand_rank(OfcpTypes.HandCategory.HIGH_CARD, [])

	var values: Array = []
	for c in cards:
		values.append(OfcpTypes.RANK_VALUES[c["rank"]])
	values.sort()
	values.reverse()  # descending

	var suits: Array = []
	for c in cards:
		suits.append(c["suit"])

	var is_flush: bool = true
	for i in range(1, 5):
		if suits[i] != suits[0]:
			is_flush = false
			break

	var is_straight: bool = _check_straight(values)

	var counts: Dictionary = {}
	for v in values:
		counts[v] = counts.get(v, 0) + 1

	var groups: Array = []
	for rank_val in counts.keys():
		groups.append([rank_val, counts[rank_val]])
	groups.sort_custom(func(a, b):
		if b[1] != a[1]:
			return a[1] > b[1]  # count desc — sort_custom true means a before b
		return a[0] > b[0]  # rank desc
	)

	if is_flush and is_straight:
		var high: int = _straight_high(values)
		if high == 14:
			return OfcpTypes.make_hand_rank(OfcpTypes.HandCategory.ROYAL_FLUSH, [14])
		return OfcpTypes.make_hand_rank(OfcpTypes.HandCategory.STRAIGHT_FLUSH, [high])

	if groups[0][1] == 4:
		return OfcpTypes.make_hand_rank(OfcpTypes.HandCategory.FOUR_OF_A_KIND, [groups[0][0], groups[1][0]])

	if groups[0][1] == 3 and groups[1][1] == 2:
		return OfcpTypes.make_hand_rank(OfcpTypes.HandCategory.FULL_HOUSE, [groups[0][0], groups[1][0]])

	if is_flush:
		return OfcpTypes.make_hand_rank(OfcpTypes.HandCategory.FLUSH, values.duplicate())

	if is_straight:
		return OfcpTypes.make_hand_rank(OfcpTypes.HandCategory.STRAIGHT, [_straight_high(values)])

	if groups[0][1] == 3:
		var kickers: Array = []
		for g in groups.slice(1):
			kickers.append(g[0])
		kickers.sort()
		kickers.reverse()
		var out_k: Array = [groups[0][0]]
		out_k.append_array(kickers)
		return OfcpTypes.make_hand_rank(OfcpTypes.HandCategory.THREE_OF_A_KIND, out_k)

	if groups[0][1] == 2 and groups[1][1] == 2:
		var pairs: Array = [groups[0][0], groups[1][0]]
		pairs.sort()
		pairs.reverse()
		return OfcpTypes.make_hand_rank(OfcpTypes.HandCategory.TWO_PAIR, [pairs[0], pairs[1], groups[2][0]])

	if groups[0][1] == 2:
		var kickers2: Array = []
		for g in groups.slice(1):
			kickers2.append(g[0])
		kickers2.sort()
		kickers2.reverse()
		var out_k2: Array = [groups[0][0]]
		out_k2.append_array(kickers2)
		return OfcpTypes.make_hand_rank(OfcpTypes.HandCategory.PAIR, out_k2)

	return OfcpTypes.make_hand_rank(OfcpTypes.HandCategory.HIGH_CARD, values.duplicate())


## Top row: HIGH_CARD / PAIR / THREE_OF_A_KIND only. Straights and flushes do NOT count.
static func evaluate3(cards: Array) -> Dictionary:
	if cards.size() != 3:
		push_error("evaluate3 requires exactly 3 cards, got %d" % cards.size())
		return OfcpTypes.make_hand_rank(OfcpTypes.HandCategory.HIGH_CARD, [])

	var values: Array = []
	for c in cards:
		values.append(OfcpTypes.RANK_VALUES[c["rank"]])
	values.sort()
	values.reverse()

	var counts: Dictionary = {}
	for v in values:
		counts[v] = counts.get(v, 0) + 1

	var groups: Array = []
	for rank_val in counts.keys():
		groups.append([rank_val, counts[rank_val]])
	groups.sort_custom(func(a, b):
		if b[1] != a[1]:
			return a[1] > b[1]
		return a[0] > b[0]
	)

	if groups[0][1] == 3:
		return OfcpTypes.make_hand_rank(OfcpTypes.HandCategory.THREE_OF_A_KIND, [groups[0][0]])

	if groups[0][1] == 2:
		return OfcpTypes.make_hand_rank(OfcpTypes.HandCategory.PAIR, [groups[0][0], groups[1][0]])

	return OfcpTypes.make_hand_rank(OfcpTypes.HandCategory.HIGH_CARD, values.duplicate())


## Positive if a > b, negative if a < b, 0 if equal.
## Quirk: only compares min(kickers.length) entries — top AKQ can tie mid AKQxx.
static func compare_hands(a: Dictionary, b: Dictionary) -> int:
	if a["category"] != b["category"]:
		return a["category"] - b["category"]
	var ka: Array = a["kickers"]
	var kb: Array = b["kickers"]
	var n: int = mini(ka.size(), kb.size())
	for i in n:
		if ka[i] != kb[i]:
			return ka[i] - kb[i]
	return 0


static func cmp_sign(n: int) -> int:
	if n > 0:
		return 1
	if n < 0:
		return -1
	return 0


static func _check_straight(sorted_values: Array) -> bool:
	# sorted descending
	if sorted_values[0] - sorted_values[4] == 4:
		var uniq: Dictionary = {}
		for v in sorted_values:
			uniq[v] = true
		if uniq.size() == 5:
			return true
	# Wheel A-2-3-4-5
	if (
		sorted_values[0] == 14
		and sorted_values[1] == 5
		and sorted_values[2] == 4
		and sorted_values[3] == 3
		and sorted_values[4] == 2
	):
		return true
	return false


static func _straight_high(sorted_values: Array) -> int:
	if sorted_values[0] == 14 and sorted_values[1] == 5:
		return 5
	return sorted_values[0]
