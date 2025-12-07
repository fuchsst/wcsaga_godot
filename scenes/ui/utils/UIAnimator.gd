extends Node

# UIAnimator.gd
# Handles UI animations and sound effects

@onready var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready():
	add_child(audio_player)
	audio_player.bus = "Interface"

func open_window(window_node: Control):
	window_node.visible = true
	# Start state: a thin horizontal line with 0 opacity
	window_node.scale = Vector2(0.1, 0.01)
	window_node.modulate.a = 0.0

	# Ensure pivoting from center
	window_node.pivot_offset = window_node.size / 2.0

	var tween = create_tween()
	tween.set_parallel(true)

	# 1. Expand Width (Horizontal Scan)
	tween.tween_property(window_node, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# 2. Expand Height (Vertical Fill - slightly delayed)
	tween.tween_property(window_node, "scale:y", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1)

	# 3. Fade In
	tween.tween_property(window_node, "modulate:a", 1.0, 0.2)

	play_sound("open")

func close_window(window_node: Control, callback: Callable):
	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(window_node, "modulate:a", 0.0, 0.2)
	tween.tween_property(window_node, "scale:y", 0.01, 0.2).set_trans(Tween.TRANS_EXPO)

	tween.chain().tween_callback(callback)
	play_sound("close")

func play_sound(sound_name: String):
	# Play UI sound effects using the Interface audio bus
	# TODO: Load actual sound files
	# For now, just log
	match sound_name:
		"open":
			print("Playing UI open sound")
		"close":
			print("Playing UI close sound")
		"click":
			print("Playing UI click sound")
		"cancel":
			print("Playing UI cancel sound")
		_:
			print("Playing UI sound: ", sound_name)
