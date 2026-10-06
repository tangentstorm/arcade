extends Node
## Optional move-animation builder (editor helper from gd-chesscoach). Kept for the
## recorded "fool's mate" AnimationPlayer library; not required for FEN play.

@export var player: AnimationPlayer
@export var pieces: Node
@export var board: Node
@export var animation_name: String
@export_multiline var json_moves: String = ""

const MOVE_DUR := 0.2


func parse_moves() -> Array:
	return JSON.parse_string(json_moves)


func get_square(sq: String) -> ColorRect:
	return board.find_child(sq)


func sq_pos(sq: String) -> Vector2:
	return get_square(sq).global_position


func ensure_track(anim: Animation, track_path: String) -> int:
	for i in range(anim.get_track_count()):
		if str(anim.track_get_path(i)) == track_path:
			return i
	var ix := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(ix, track_path)
	return ix


func add_capture_keyframe(sprite: String, t: float) -> void:
	var anim := get_animation()
	var track := ensure_track(anim, "pieces/" + sprite + ":modulate")
	anim.track_insert_key(track, t - 0.1, 0xffffffff)
	anim.track_insert_key(track, t + 0.1, 0xffffff00)


func add_move_keyframe(id: String, t: float, p0: Vector2, p1: Vector2) -> void:
	var anim := get_animation()
	var track := ensure_track(anim, "pieces/" + id + ":position")
	anim.track_insert_key(track, t, p0)
	anim.track_insert_key(track, t + MOVE_DUR, p1)


func get_animation() -> Animation:
	if not player.has_animation(animation_name):
		push_error("no such animation")
	return player.get_animation(animation_name)


func clear_animation() -> void:
	var anim := get_animation()
	while anim.get_track_count() > 0:
		anim.remove_track(0)


func build_animation() -> void:
	var game = parse_moves()
	clear_animation()
	var t := 0.0
	for move in game:
		var delay := 0.25
		var sprite: String = move[4]
		var sq0: String = move[5]
		var sq1: String = move[6]
		var extra: Dictionary = move[7]
		t += delay
		add_move_keyframe(sprite, t, sq_pos(sq0), sq_pos(sq1))
		if extra.has("castle"):
			var rook = extra["castle"][0]
			var rsq0 = extra["castle"][1]
			var rsq1 = extra["castle"][2]
			add_move_keyframe(rook, t, sq_pos(rsq0), sq_pos(rsq1))
		t += MOVE_DUR
		if extra.has("capture"):
			add_capture_keyframe(extra["capture"], t)
	get_animation().length = t + 1
