class_name OfcpMulberry32
extends RefCounted
## Exact mulberry32 PRNG matching the golden generator (JS Math.imul + >>> semantics).

var _t: int = 0


func _init(seed: int = 0) -> void:
	_t = _u32(seed)


func next_float() -> float:
	# t = (t + 0x6d2b79f5) >>> 0
	_t = _u32(_t + 0x6D2B79F5)
	# r = Math.imul(t ^ (t >>> 15), 1 | t)
	var r: int = _imul32(_t ^ (_t >> 15), 1 | _t)
	# r = (r + Math.imul(r ^ (r >>> 7), 61 | r)) ^ r
	var r_u: int = _u32(r)
	r = _i32(r + _imul32(r ^ (r_u >> 7), 61 | r)) ^ _i32(r)
	# return ((r ^ (r >>> 14)) >>> 0) / 4294967296
	return float(_u32(_i32(r) ^ (_u32(r) >> 14))) / 4294967296.0


## Fisher–Yates shuffle identical to src/deck.ts, using this RNG instead of Math.random.
func shuffle(arr: Array) -> Array:
	var result: Array = arr.duplicate()
	var i: int = result.size() - 1
	while i > 0:
		var j: int = int(next_float() * (i + 1))
		var tmp = result[i]
		result[i] = result[j]
		result[j] = tmp
		i -= 1
	return result


static func _u32(x: int) -> int:
	return x & 0xFFFFFFFF


static func _i32(x: int) -> int:
	var u: int = x & 0xFFFFFFFF
	if u >= 0x80000000:
		return u - 0x100000000
	return u


## Math.imul — multiply as signed 32-bit, return signed 32-bit.
static func _imul32(a: int, b: int) -> int:
	return _i32(_i32(a) * _i32(b))
