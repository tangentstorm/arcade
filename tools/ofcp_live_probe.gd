extends SceneTree
## MANUAL live check (not part of smoke/CI): plays one hand vs the AI on the live
## server using the Direct client's transport + view model.
##   godot --headless --path . --script res://tools/ofcp_live_probe.gd [-- wss://...]
## Native Godot sends Origin http://localhost (allowed by the server for dev).

const OfcpWs := preload("res://games/ofcp/direct/ofcp_ws.gd")
const OfcpTable := preload("res://games/ofcp/direct/ofcp_table.gd")

var ws
var table := OfcpTable.new()
var hinted := false
var done := false
var t0 := 0


func _initialize() -> void:
	var url: String = OfcpWs.DEFAULT_URL
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		url = args[0]
	ws = OfcpWs.new()
	root.add_child(ws)
	ws.message_received.connect(_on_msg)
	ws.closed.connect(func(code, reason):
		if not done:
			print("LIVE FAIL: closed %d %s" % [code, reason])
			quit(1))
	t0 = Time.get_ticks_msec()
	print("connecting ", url)
	ws.connect_to_server(url)


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - t0 > 90000:
		print("LIVE FAIL: timeout")
		quit(1)
	return false


func _on_msg(m: Dictionary) -> void:
	var t: String = m.get("type", "")
	print("<< ", t, " ", m.get("phase", ""), " ", m.get("message", ""))
	match t:
		"waiting":
			ws.send_msg({"type": "start_vs_ai", "aiCount": 1, "mode": "normal"})
		"ready":
			ws.send_msg({"type": "start_game"})
		"game_state":
			table.apply_state(m)
			if table.is_game_over():
				done = true
				print("hand over: scores=%s net=%s" % [m.get("scores"), table.breakdown(0).get("netScore")])
				print("LIVE OK")
				ws.close()
				quit(0)
			elif table.is_my_turn():
				if not hinted:
					hinted = true
					ws.send_msg({"type": "get_hint"})
				else:
					_submit()
		"hint":
			if table.apply_hint(m):
				print("   hint applied: ", table.build_submit())
				ws.send_msg(table.build_submit())
			else:
				_submit()
		"error":
			print("LIVE FAIL: server error ", m.get("message"))
			quit(1)


func _submit() -> void:
	table.auto_fill()
	ws.send_msg(table.build_submit())
