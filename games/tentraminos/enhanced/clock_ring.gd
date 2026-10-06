extends Control
## Tentraminos Enhanced: the 10-second round clock as a ring with a big readout.

const Logic := preload("res://games/tentraminos/direct/tentraminos_logic.gd")

var g  # game.gd


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if g == null or g.game == null:
		return
	var game = g.game
	var c := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 10.0
	var ms: float = g.display_clock_ms()
	var frac := clampf(ms / (10.0 * Logic.SECONDS), 0.0, 1.0)
	var playing: bool = g.started and game.next == Logic.PLAYING
	var t: float = g.time
	var col := Color("#16d2bd")
	if playing and ms <= 3000.0:
		col = Color("#f57900").lerp(Color("#ff3b3b"), 1.0 - ms / 3000.0)
	draw_circle(c, radius + 8.0, Color("#10131d"))
	draw_arc(c, radius, 0.0, TAU, 72, Color(1, 1, 1, 0.08), 12.0, true)
	if frac > 0.0:
		var start := -PI * 0.5
		draw_arc(c, radius, start, start + TAU * frac, 72, col, 12.0, true)
		var tip := c + Vector2(cos(start + TAU * frac), sin(start + TAU * frac)) * radius
		draw_circle(tip, 8.0, col.lightened(0.3))
	var font := get_theme_default_font()
	var big := ""
	var small := "seconds"
	if not g.started:
		big = "10"
		small = "ready"
	elif game.next == Logic.THEEND:
		big = "-"
		small = "game over"
	elif game.paused:
		big = "II"
		small = "paused"
	elif playing:
		big = "%.1f" % (ms / 1000.0)
	else:
		big = "v"
		small = "dropping"
	var fs := 52
	var scale_pulse := 1.0
	if playing and ms <= 3000.0:
		scale_pulse = 1.0 + 0.08 * maxf(0.0, sin(t * TAU * 1.0))
	draw_set_transform(c, 0.0, Vector2.ONE * scale_pulse)
	draw_string(font, Vector2(-radius, fs * 0.3), big, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0,
			fs, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	draw_string(font, c + Vector2(-radius, fs * 0.3 + 26), small, HORIZONTAL_ALIGNMENT_CENTER,
			radius * 2.0, 15, Color(1, 1, 1, 0.55))
