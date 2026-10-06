extends ScrollContainer

const names = {
	'teddy': 'Teddy Tetraminus',
	'ernie': 'Ernie Goldsmile',
	'ivan' : 'Ivan C. Punchko' }

const icons = {
	'teddy': preload("res://games/ld48/direct/sprites/teddy-chat.png"),
	'ernie': preload("res://games/ld48/direct/sprites/ernie-chat.png"),
	'ivan' : preload("res://games/ld48/direct/sprites/ivan-chat.png")}


func _on_room0_speak(who, msg):
	var card = $"../card".duplicate()
	var cast_name = names.get(who)
	if cast_name == null: push_error('unknown cast member: ' + who)
	else:
		var text = "[b]" + cast_name + "[/b]\n[color=#ccc]" + msg + "[/color]"
		var icon = icons[who]
		card.get_node("box/icon").texture = icon
		card.get_node("text").text = text
		card.visible = true
		$vbox.add_child(card)
