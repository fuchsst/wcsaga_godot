# scripts/graphics/post_processing.gd
# Handles custom post-processing effects applied via screen-space shaders.
# Attach this script to the main Camera3D or a Viewport used for rendering.
extends Node

# Preload custom screen-space shaders if needed
# var custom_bloom_shader = preload("res://shaders/custom_bloom_pp.gdshader")
# var vignette_shader = preload("res://shaders/vignette_pp.gdshader")

# Keep track of active custom effects and their materials
var active_effects = {}

func _ready():
	# Connect to signals or initialize based on game settings if necessary
	pass

# Example function to enable a custom effect
func enable_effect(effect_name: String, shader: Shader, parameters: Dictionary = {}):
	if not get_viewport():
		printerr("PostProcessing script needs to be attached to a node within a Viewport.")
		return

	# Check if effect already exists, update parameters or return
	if effect_name in active_effects:
		var material = active_effects[effect_name]
		if material is ShaderMaterial:
			for key in parameters:
				material.set_shader_parameter(key, parameters[key])
		return

	# Create a new ShaderMaterial
	var material = ShaderMaterial.new()
	material.shader = shader
	for key in parameters:
		material.set_shader_parameter(key, parameters[key])

	# Add the material to the Viewport's canvas item material list
	# Note: Godot 4 requires managing post-processing differently,
	# often via CameraAttributes or custom Viewport setups with screen-reading shaders.
	# This approach might need adaptation based on the final rendering pipeline.
	# For CameraAttributes (Godot 4.x):
	# var camera_attributes = CameraAttributesPractical.new() # Or CameraAttributesPhysical
	# camera_attributes.add_material(material)
	# get_viewport().camera_attributes = camera_attributes # This might override WorldEnvironment effects

	# Placeholder: Store the material. Actual application depends on the chosen PP method.
	active_effects[effect_name] = material
	print("Enabled custom post-processing effect: ", effect_name)
	# TODO: Implement actual application of the material to the screen/camera


func disable_effect(effect_name: String):
	if effect_name in active_effects:
		var material = active_effects[effect_name]
		# TODO: Implement removal of the material from the camera/viewport
		active_effects.erase(effect_name)
		print("Disabled custom post-processing effect: ", effect_name)


func update_effect_parameter(effect_name: String, param_name: String, value):
	if effect_name in active_effects:
		var material = active_effects[effect_name]
		if material is ShaderMaterial:
			material.set_shader_parameter(param_name, value)


# Example of how parameters might be updated in _process
# func _process(delta):
#	 if active_effects.has("vignette"):
#		 var intensity = # Calculate intensity based on game state
#		 update_effect_parameter("vignette", "intensity", intensity)
