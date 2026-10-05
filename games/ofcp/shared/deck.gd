class_name OfcpDeck
extends RefCounted
## 52-card deck: create, shuffle (Math.random or seeded), deal from index 0.


static func create_deck() -> Array:
	var deck: Array = []
	for suit in OfcpTypes.SUITS:
		for rank in OfcpTypes.RANKS:
			deck.append(OfcpTypes.make_card(rank, suit))
	return deck


## Fisher–Yates using Godot randf() (production). Golden tests use OfcpMulberry32.shuffle.
static func shuffle(deck: Array) -> Array:
	var result: Array = deck.duplicate()
	var i: int = result.size() - 1
	while i > 0:
		var j: int = int(randf() * (i + 1))
		var tmp = result[i]
		result[i] = result[j]
		result[j] = tmp
		i -= 1
	return result


## Deal n cards from the front of the deck. Mutates deck. Returns dealt cards.
static func deal(deck: Array, n: int) -> Array:
	if deck.size() < n:
		push_error("Cannot deal %d cards, only %d remaining" % [n, deck.size()])
		return []
	var dealt: Array = []
	for _i in n:
		dealt.append(deck.pop_front())
	return dealt
