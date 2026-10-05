extends Control
## Template stub (enhanced edition). Copy games/_template/ to start a new port.
## Esc is handled globally by the PauseOverlay autoload.


func _ready() -> void:
	%BackButton.pressed.connect(GameRegistry.return_to_arcade)
	%BackButton.grab_focus()
