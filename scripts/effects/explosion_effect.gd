# scripts/effects/explosion_effect.gd
extends Node3D
class_name ExplosionEffect

# Configurable properties
@export var lifetime: float = 1.5 # Default lifetime in seconds
@export var scale_with_radius: bool = true # Whether particles/light scale with input radius

# Node references (Assign in editor)
@onready var particles: GPUParticles3D = $GPUParticles # Assuming node named GPUParticles
@onready var light: OmniLight3D = $OmniLight # Assuming node named OmniLight
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer # Assuming node named AudioPlayer
# @onready var animation_player: AnimationPlayer = $AnimationPlayer # Optional

var _time_elapsed: float = 0.0

func _ready():
	# Ensure particles are set to one-shot if not already configured
	if particles:
		particles.one_shot = true
		particles.emitting = true # Start emitting immediately

	# Play sound if assigned
	if audio_player and is_instance_valid(audio_player.stream):
		audio_player.play()

	# Start light flash (can be refined with AnimationPlayer)
	if light:
		light.visible = true
		# Create a simple fade-out tween for the light
		var tween = create_tween()
		tween.tween_property(light, "light_energy", 0.0, lifetime * 0.5).set_delay(lifetime * 0.1) # Start fading after initial flash
		tween.tween_callback(func(): light.visible = false) # Hide light after fade

	# Set timer to automatically destroy the effect node
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()


func setup_explosion(type: EffectManager.ExplosionType, radius: float = 1.0):
	# Optional: Adjust properties based on type and radius
	# This needs the ExplosionType enum to be defined properly, likely in GlobalConstants
	# For now, just scale based on radius if enabled.
	if scale_with_radius:
		# Scale particles emission amount, size, light energy/range based on radius
		if particles:
			# Example: particles.amount *= clamp(radius / 10.0, 0.5, 5.0) # Scale amount
			# Example: particles.process_material.scale_min *= radius * 0.1
			# Example: particles.process_material.scale_max *= radius * 0.1
			pass # Requires specific ParticleProcessMaterial setup
		if light:
			# Example: light.omni_range = radius * 2.0
			# Example: light.light_energy *= clamp(radius / 10.0, 0.5, 3.0)
			pass

	# TODO: Load specific sound/particle material based on 'type' if needed

# Note: _process(delta) is not strictly needed if using Timer for lifetime
# and AnimationPlayer/Tween for animations. Add it back if complex per-frame logic is required.
# func _process(delta):
# 	_time_elapsed += delta
# 	if _time_elapsed >= lifetime:
# 		queue_free()
