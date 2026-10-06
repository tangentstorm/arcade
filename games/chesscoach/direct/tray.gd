extends Panel
## Off-board piece tray. organize() packs children into an 8-wide grid of 48px cells.

func organize() -> void:
	var i := 0
	var cols := 8
	var gap_size := 2
	var cell_size := 48
	for child in get_children():
		var x := (i % cols) * (cell_size + gap_size)
		var y := int(floor(float(i) / float(cols))) * (cell_size + gap_size)
		y -= 6  # original visual nudge
		child.position = Vector2(x, y)
		i += 1
