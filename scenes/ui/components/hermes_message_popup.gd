@tool
extends PopupPanel

@export_multiline var message_text: String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$MarginContainer/Description.text = message_text


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_button_pressed() -> void:
	$".".hide()
