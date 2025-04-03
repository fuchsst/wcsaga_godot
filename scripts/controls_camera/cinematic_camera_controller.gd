# scripts/controls_camera/cinematic_camera_controller.gd
extends BaseCameraController
class_name CinematicCameraController

## Controller for cameras used in cutscenes or scripted sequences.
## May interact with AnimationPlayer for complex movements.

# --- Node References ---
# @onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

func _ready():
	super._ready()
	# Initialization specific to cinematic cameras if needed


func _physics_process(delta: float):
	# If not controlled by AnimationPlayer, default to base class behavior
	if not get_node_or_null("AnimationPlayer") or not get_node("AnimationPlayer").is_playing():
		super._physics_process(delta)
	# Otherwise, AnimationPlayer handles the transform


func play_animation(animation_name: String):
	var animation_player = get_node_or_null("AnimationPlayer")
	if animation_player and animation_player.has_animation(animation_name):
		# Stop following/targeting when animation plays
		host_object = null
		target_object = null
		set_physics_process(false) # Let AnimationPlayer take control
		animation_player.play(animation_name)
	else:
		printerr("CinematicCameraController: Animation '", animation_name, "' not found or AnimationPlayer missing.")


func stop_animation():
	var animation_player = get_node_or_null("AnimationPlayer")
	if animation_player and animation_player.is_playing():
		animation_player.stop()
		set_physics_process(is_active) # Resume physics process if camera is active


# Override base methods if cinematic cameras behave differently during transitions
# For example, maybe they should ignore host/target during tweens

# func set_position(pos: Vector3, duration: float = 0.0):
# 	super.set_position(pos, duration)
# 	# Additional cinematic-specific logic

# func set_rotation(basis: Basis, duration: float = 0.0):
# 	super.set_rotation(basis, duration)
# 	# Additional cinematic-specific logic
