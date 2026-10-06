extends Panel
## FEN board: pulls sprites from white/black trays onto squares, and clears them back.

@export var black_tray: Node
@export var white_tray: Node

const INIT_FEN := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const FILES := "abcdefgh"


func _ready() -> void:
	if black_tray == null:
		black_tray = get_node_or_null("../black-tray")
	if white_tray == null:
		white_tray = get_node_or_null("../white-tray")
	# Wait for container layout so square.global_position is valid.
	_boot.call_deferred()


func _boot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_reset_pieces_to_trays()
	setup_board(INIT_FEN)


## Move every piece under board/pieces back to its tray and restore visibility.
func _reset_pieces_to_trays() -> void:
	var pieces: Node = get_node("pieces")
	for piece in pieces.get_children():
		_stow(piece)
	organize_trays()


func _stow(piece: Node) -> void:
	var c := str(piece.name)[0]
	var tray: Node = black_tray if c > "Z" else white_tray
	if piece is CanvasItem:
		(piece as CanvasItem).modulate = Color.WHITE
	piece.reparent(tray)


func setup_board(fen: String) -> void:
	clear_board()
	var seen := {}
	for each in "rnbqkpRNBQKP":
		seen[each] = 0
	var y := 8
	for row in fen.split(" ")[0].split("/"):
		var x := 0
		for c in row:
			if c > "0" and c < "9":
				x += int(c)
			else:
				var tray: Node = black_tray if c > "Z" else white_tray
				var piece: Sprite2D = tray.get_node(c + str(seen[c]))
				seen[c] += 1
				var square: ColorRect = get_node("ranks/rank%d/%s%d" % [y, FILES[x], y])
				piece.reparent($pieces)
				piece.global_position = square.global_position
				piece.modulate = Color.WHITE
				x += 1
		y -= 1
	organize_trays()


func clear_board() -> void:
	for piece in get_node("pieces").get_children():
		_stow(piece)
	organize_trays()


func organize_trays() -> void:
	if black_tray and black_tray.has_method("organize"):
		black_tray.organize()
	if white_tray and white_tray.has_method("organize"):
		white_tray.organize()


## Count pieces currently sitting on the board (not in trays).
func pieces_on_board() -> int:
	return get_node("pieces").get_child_count()
