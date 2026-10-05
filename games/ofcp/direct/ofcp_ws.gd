extends Node
## Thin JSON-over-WebSocket transport for the live OFCP server.
##
## Browser (Web export): the browser sets the Origin header itself. The live
## server only accepts https://tangentstorm.github.io (plus localhost origins).
## Native (editor / desktop / headless): Godot sends no Origin by default, so
## the server answers 403. We send the dev Origin "http://localhost", which the
## server explicitly allows for local development (see ofcp server-origin.ts).

signal opened
signal closed(code: int, reason: String)
signal message_received(msg: Dictionary)

const DEFAULT_URL := "wss://ofcp.tangentcode.com/ws"
const NATIVE_DEV_ORIGIN := "http://localhost"

var url := DEFAULT_URL
var _peer: WebSocketPeer = null
var _last_state := WebSocketPeer.STATE_CLOSED


func is_open() -> bool:
	return _peer != null and _peer.get_ready_state() == WebSocketPeer.STATE_OPEN


func connect_to_server(p_url: String = DEFAULT_URL) -> Error:
	close()
	url = p_url
	_peer = WebSocketPeer.new()
	_peer.inbound_buffer_size = 1 << 18
	if not OS.has_feature("web"):
		_peer.handshake_headers = PackedStringArray(["Origin: " + NATIVE_DEV_ORIGIN])
	var err := _peer.connect_to_url(url)
	if err != OK:
		_peer = null
		return err
	_last_state = WebSocketPeer.STATE_CONNECTING
	set_process(true)
	return OK


func close() -> void:
	if _peer != null:
		_peer.close(1000, "client closed")
		_peer = null
	_last_state = WebSocketPeer.STATE_CLOSED


func send_msg(msg: Dictionary) -> bool:
	if not is_open():
		return false
	return _peer.send_text(JSON.stringify(msg)) == OK


func _process(_delta: float) -> void:
	if _peer == null:
		return
	_peer.poll()
	var state := _peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if _last_state != WebSocketPeer.STATE_OPEN:
			_last_state = state
			opened.emit()
		while _peer != null and _peer.get_available_packet_count() > 0:
			var text := _peer.get_packet().get_string_from_utf8()
			var parsed = JSON.parse_string(text)
			if parsed is Dictionary:
				message_received.emit(parsed)
	elif state == WebSocketPeer.STATE_CLOSED:
		var code := _peer.get_close_code()
		var reason := _peer.get_close_reason()
		_peer = null
		_last_state = state
		closed.emit(code, reason)
	else:
		_last_state = state
