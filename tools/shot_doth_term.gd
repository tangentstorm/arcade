extends SceneTree
## CPU-blit Doth Direct TermGrid → games/doth/source/doth-direct-termgrid.png

const GameScript := preload("res://games/doth/direct/game.gd")
const TermGrid := preload("res://games/_shared/term_grid.gd")

func _initialize() -> void:
	var term: Control = TermGrid.new()
	term.pixel_scale = 2
	term.cell_wh = Vector2(16, 32)
	term._build_u2cp()
	term.cscr()
	# Minimal host mirroring game.gd draw path without needing a window.
	var game = GameScript.new()
	game.term = term
	game.world.start_play("starter")
	game._elapsed = 12.0
	game._redraw()
	var img: Image = term.render_to_image()
	var path := ProjectSettings.globalize_path("res://games/doth/source/doth-direct-termgrid.png")
	var err := img.save_png(path)
	print("shot_doth_term: ", path, " ", img.get_width(), "x", img.get_height(), " err=", err)
	print("row0: ", term.row_text(0))
	print("row1c:", term.row_text(1).substr(71, 9))
	print("row18:", term.row_text(18).substr(72, 7))
	print("row23:", term.row_text(23))
	# Free
	term.free()
	quit(0 if err == OK else 1)
