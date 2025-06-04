class_name EffectProcessor
extends RefCounted

## Runtime shader effect management and animation system
## Handles dynamic shader parameter updates, effect lifecycle, and performance optimization

signal effect_started(effect_id: String, effect_type: String)
signal effect_finished(effect_id: String)
signal effect_parameter_updated(effect_id: String, parameter: String, value: Variant)
signal performance_impact_warning(effect_id: String, impact_level: float)

var active_effects: Dictionary = {}
var effect_tweens: Dictionary = {}
var effect_timers: Dictionary = {}
var performance_tracker: Dictionary = {}
var quality_level: int = 2
var max_concurrent_effects: int = 50

# Performance thresholds
var performance_warning_threshold: float = 16.67  # 60 FPS
var performance_critical_threshold: float = 33.33  # 30 FPS

func _init() -> void:
	WCSShaderLibrary.initialize()
	print("EffectProcessor: Initialized with shader library integration")

## Start a new effect with automatic lifecycle management
func start_effect(effect_id: String, effect_type: String, node: Node3D, 
                 parameters: Dictionary = {}, duration: float = -1.0) -> bool:
	# Check concurrent effect limits
	if active_effects.size() >= max_concurrent_effects:
		_cleanup_oldest_effect()
	
	# Get effect template or create custom effect
	var effect_config: Dictionary
	if WCSShaderLibrary.get_available_templates().has(effect_type):
		effect_config = WCSShaderLibrary.get_effect_template(effect_type)
	else:
		# Try as shader name directly
		var shader_def: Dictionary = WCSShaderLibrary.get_shader_definition(effect_type)
		if shader_def.is_empty():
			push_error("EffectProcessor: Unknown effect type: " + effect_type)
			return false
		effect_config = {
			"shader": effect_type,
			"params": WCSShaderLibrary.get_default_shader_params(effect_type)
		}
	
	# Merge custom parameters
	var final_params: Dictionary = effect_config.get("params", {}).duplicate()
	final_params.merge(parameters)
	
	# Apply quality adjustments
	final_params = WCSShaderLibrary.get_quality_adjusted_params(final_params, quality_level)
	
	# Create and configure shader material
	var material: ShaderMaterial = _create_effect_material(effect_config["shader"], final_params)
	if not material:
		return false
	
	# Apply material to node
	if not _apply_material_to_node(node, material):
		return false
	
	# Store effect data
	var effect_data: Dictionary = {
		"effect_type": effect_type,
		"node": node,
		"material": material,
		"parameters": final_params,
		"start_time": Time.get_ticks_msec() / 1000.0,
		"duration": duration,
		"performance_cost": _estimate_performance_cost(effect_type, final_params)
	}
	
	active_effects[effect_id] = effect_data
	performance_tracker[effect_id] = {
		"frame_count": 0,
		"total_time": 0.0,
		"avg_frame_time": 0.0
	}
	
	# Set up automatic cleanup if duration is specified
	if duration > 0.0:
		_setup_effect_timer(effect_id, duration)
	
	effect_started.emit(effect_id, effect_type)
	print("EffectProcessor: Started effect '%s' (type: %s) with %d parameters" % [effect_id, effect_type, final_params.size()])
	return true

## Update effect parameters dynamically
func update_effect_parameter(effect_id: String, parameter: String, value: Variant, 
                           animate: bool = false, animation_duration: float = 0.5) -> bool:
	if not effect_id in active_effects:
		push_warning("EffectProcessor: Effect not found: " + effect_id)
		return false
	
	var effect_data: Dictionary = active_effects[effect_id]
	var material: ShaderMaterial = effect_data["material"]
	
	if animate and material:
		return _animate_parameter(effect_id, material, parameter, value, animation_duration)
	else:
		if material:
			material.set_shader_parameter(parameter, value)
			effect_data["parameters"][parameter] = value
			effect_parameter_updated.emit(effect_id, parameter, value)
			return true
	
	return false

## Animate parameter changes smoothly
func _animate_parameter(effect_id: String, material: ShaderMaterial, parameter: String, 
                       target_value: Variant, duration: float) -> bool:
	# Clean up existing tween for this parameter
	var tween_key: String = effect_id + "_" + parameter
	if tween_key in effect_tweens:
		var old_tween: Tween = effect_tweens[tween_key]
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	
	# Get current value
	var current_value: Variant = material.get_shader_parameter(parameter)
	if current_value == null:
		current_value = target_value  # Use target as fallback
	
	# Create animation tween
	var tween: Tween = _create_tween()
	if not tween:
		return false
	
	effect_tweens[tween_key] = tween
	
	# Animate based on value type
	if target_value is float:
		tween.tween_method(
			func(value: float): 
				material.set_shader_parameter(parameter, value)
				effect_parameter_updated.emit(effect_id, parameter, value),
			current_value as float, target_value as float, duration
		)
	elif target_value is Vector3:
		tween.tween_method(
			func(value: Vector3):
				material.set_shader_parameter(parameter, value)
				effect_parameter_updated.emit(effect_id, parameter, value),
			current_value as Vector3, target_value as Vector3, duration
		)
	elif target_value is Color:
		tween.tween_method(
			func(value: Color):
				material.set_shader_parameter(parameter, value)
				effect_parameter_updated.emit(effect_id, parameter, value),
			current_value as Color, target_value as Color, duration
		)
	else:
		# For non-animatable types, just set directly
		material.set_shader_parameter(parameter, target_value)
		effect_parameter_updated.emit(effect_id, parameter, target_value)
	
	# Clean up tween when done
	tween.finished.connect(func(): effect_tweens.erase(tween_key))
	
	return true

## Create a tween for animation (placeholder - requires scene tree access)
func _create_tween() -> Tween:
	# This would normally require access to a scene tree node
	# For now, return null and handle gracefully
	push_warning("EffectProcessor: Tween creation requires scene tree access")
	return null

## Stop and clean up an effect
func stop_effect(effect_id: String, fade_out: bool = false, fade_duration: float = 0.3) -> bool:
	if not effect_id in active_effects:
		return false
	
	var effect_data: Dictionary = active_effects[effect_id]
	
	if fade_out:
		# Fade out the effect before cleanup
		var material: ShaderMaterial = effect_data["material"]
		if material:
			# Try to fade common intensity parameters
			for param in ["beam_intensity", "plasma_intensity", "explosion_intensity", "trail_intensity"]:
				var current_value = material.get_shader_parameter(param)
				if current_value != null:
					_animate_parameter(effect_id, material, param, 0.0, fade_duration)
		
		# Schedule cleanup after fade
		_setup_effect_timer(effect_id + "_cleanup", fade_duration)
	else:
		_cleanup_effect(effect_id)
	
	return true

## Get current effect parameters
func get_effect_parameters(effect_id: String) -> Dictionary:
	if effect_id in active_effects:
		return active_effects[effect_id].get("parameters", {})
	return {}

## Get effect performance statistics
func get_effect_performance(effect_id: String) -> Dictionary:
	if effect_id in performance_tracker:
		return performance_tracker[effect_id]
	return {}

## Get all active effect IDs
func get_active_effects() -> Array[String]:
	return active_effects.keys()

## Get effect count for a specific type
func get_effect_count_by_type(effect_type: String) -> int:
	var count: int = 0
	for effect_data in active_effects.values():
		if effect_data.get("effect_type", "") == effect_type:
			count += 1
	return count

## Set quality level and adjust all active effects
func set_quality_level(new_quality: int) -> void:
	quality_level = new_quality
	
	# Adjust concurrent effect limits based on quality
	match quality_level:
		0, 1:  # Low quality
			max_concurrent_effects = 25
		2:     # Medium quality
			max_concurrent_effects = 40
		3, 4:  # High/Ultra quality
			max_concurrent_effects = 75
	
	# Update all active effects with new quality settings
	for effect_id in active_effects:
		_apply_quality_to_effect(effect_id)
	
	print("EffectProcessor: Quality level set to %d, max effects: %d" % [quality_level, max_concurrent_effects])

## Apply quality settings to a specific effect
func _apply_quality_to_effect(effect_id: String) -> void:
	if not effect_id in active_effects:
		return
	
	var effect_data: Dictionary = active_effects[effect_id]
	var material: ShaderMaterial = effect_data["material"]
	var base_params: Dictionary = effect_data["parameters"]
	
	# Apply quality adjustments
	var adjusted_params: Dictionary = WCSShaderLibrary.get_quality_adjusted_params(base_params, quality_level)
	
	# Update material parameters
	if material:
		for param_name in adjusted_params:
			material.set_shader_parameter(param_name, adjusted_params[param_name])

## Monitor performance and issue warnings
func update_performance_monitoring(delta: float) -> void:
	for effect_id in performance_tracker:
		var tracker: Dictionary = performance_tracker[effect_id]
		tracker["frame_count"] += 1
		tracker["total_time"] += delta
		tracker["avg_frame_time"] = tracker["total_time"] / tracker["frame_count"]
		
		# Check for performance issues
		var frame_time_ms: float = tracker["avg_frame_time"] * 1000.0
		if frame_time_ms > performance_warning_threshold:
			performance_impact_warning.emit(effect_id, frame_time_ms)
			
			# Auto-reduce quality for this effect if critical
			if frame_time_ms > performance_critical_threshold:
				_reduce_effect_quality(effect_id)

## Reduce quality for a performance-impacting effect
func _reduce_effect_quality(effect_id: String) -> void:
	if not effect_id in active_effects:
		return
	
	var effect_data: Dictionary = active_effects[effect_id]
	var material: ShaderMaterial = effect_data["material"]
	
	if material:
		# Reduce common performance-impacting parameters
		var reductions: Dictionary = {
			"particle_count": 0.5,
			"detail_level": 0.3,
			"effect_complexity": 0.5,
			"sample_count": 0.5
		}
		
		for param in reductions:
			var current_value = material.get_shader_parameter(param)
			if current_value != null and current_value is float:
				var reduced_value: float = current_value * reductions[param]
				material.set_shader_parameter(param, reduced_value)
		
		print("EffectProcessor: Reduced quality for performance-impacting effect: " + effect_id)

## Create shader material from effect configuration
func _create_effect_material(shader_name: String, parameters: Dictionary) -> ShaderMaterial:
	var shader_def: Dictionary = WCSShaderLibrary.get_shader_definition(shader_name)
	if shader_def.is_empty():
		push_error("EffectProcessor: Shader definition not found: " + shader_name)
		return null
	
	var shader_path: String = shader_def.get("path", "")
	if not ResourceLoader.exists(shader_path):
		push_error("EffectProcessor: Shader file not found: " + shader_path)
		return null
	
	var shader: Shader = load(shader_path)
	if not shader:
		push_error("EffectProcessor: Failed to load shader: " + shader_path)
		return null
	
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	
	# Apply all parameters
	for param_name in parameters:
		material.set_shader_parameter(param_name, parameters[param_name])
	
	return material

## Apply material to appropriate surface of a node
func _apply_material_to_node(node: Node3D, material: ShaderMaterial) -> bool:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		mesh_instance.material_override = material
		return true
	elif node.has_method("set_surface_override_material"):
		node.set_surface_override_material(0, material)
		return true
	else:
		push_warning("EffectProcessor: Node type not supported for material application: " + str(type_string(typeof(node))))
		return false

## Estimate performance cost of an effect
func _estimate_performance_cost(effect_type: String, parameters: Dictionary) -> float:
	var base_cost: float = 1.0
	
	# Cost based on effect category
	var shader_category: String = WCSShaderLibrary.get_shader_category(effect_type)
	match shader_category:
		"weapon":
			base_cost = 0.5  # Generally lightweight
		"effect":
			base_cost = 1.0  # Medium cost
		"post_processing":
			base_cost = 2.0  # Expensive full-screen effects
		"environment":
			base_cost = 1.5  # Volumetric effects
		_:
			base_cost = 1.0
	
	# Adjust for complex parameters
	if "particle_count" in parameters:
		var particle_count: int = parameters["particle_count"]
		base_cost *= 1.0 + (particle_count / 200.0)
	
	if "effect_complexity" in parameters:
		var complexity: float = parameters["effect_complexity"]
		base_cost *= (1.0 + complexity)
	
	return base_cost

## Setup automatic cleanup timer for an effect
func _setup_effect_timer(effect_id: String, duration: float) -> void:
	# Store timer info (in real implementation, this would use Godot Timer or SceneTree timer)
	effect_timers[effect_id] = {
		"duration": duration,
		"start_time": Time.get_ticks_msec() / 1000.0
	}
	
	print("EffectProcessor: Set up cleanup timer for effect '%s' (%.2fs)" % [effect_id, duration])

## Clean up expired effects (should be called from main update loop)
func process_effect_timers(delta: float) -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var expired_timers: Array[String] = []
	
	for timer_id in effect_timers:
		var timer_data: Dictionary = effect_timers[timer_id]
		var elapsed: float = current_time - timer_data["start_time"]
		
		if elapsed >= timer_data["duration"]:
			expired_timers.append(timer_id)
	
	# Process expired timers
	for timer_id in expired_timers:
		effect_timers.erase(timer_id)
		
		if timer_id.ends_with("_cleanup"):
			var effect_id: String = timer_id.replace("_cleanup", "")
			_cleanup_effect(effect_id)
		else:
			_cleanup_effect(timer_id)

## Clean up the oldest effect to make room for new ones
func _cleanup_oldest_effect() -> void:
	if active_effects.is_empty():
		return
	
	var oldest_id: String = ""
	var oldest_time: float = INF
	
	for effect_id in active_effects:
		var effect_data: Dictionary = active_effects[effect_id]
		var start_time: float = effect_data.get("start_time", 0.0)
		if start_time < oldest_time:
			oldest_time = start_time
			oldest_id = effect_id
	
	if not oldest_id.is_empty():
		_cleanup_effect(oldest_id)
		print("EffectProcessor: Cleaned up oldest effect for performance: " + oldest_id)

## Internal cleanup for an effect
func _cleanup_effect(effect_id: String) -> void:
	if not effect_id in active_effects:
		return
	
	var effect_data: Dictionary = active_effects[effect_id]
	var node: Node3D = effect_data.get("node")
	
	# Remove material from node
	if node and is_instance_valid(node):
		if node is MeshInstance3D:
			var mesh_instance: MeshInstance3D = node as MeshInstance3D
			mesh_instance.material_override = null
		elif node.has_method("set_surface_override_material"):
			node.set_surface_override_material(0, null)
	
	# Clean up stored data
	active_effects.erase(effect_id)
	performance_tracker.erase(effect_id)
	
	# Clean up any associated tweens
	for tween_key in effect_tweens.keys():
		if tween_key.begins_with(effect_id + "_"):
			var tween: Tween = effect_tweens[tween_key]
			if tween and tween.is_valid():
				tween.kill()
			effect_tweens.erase(tween_key)
	
	effect_finished.emit(effect_id)
	print("EffectProcessor: Cleaned up effect: " + effect_id)

## Clear all active effects
func clear_all_effects() -> void:
	var effect_ids: Array[String] = active_effects.keys()
	for effect_id in effect_ids:
		_cleanup_effect(effect_id)
	
	effect_timers.clear()
	print("EffectProcessor: Cleared all %d active effects" % effect_ids.size())

## Get overall performance statistics
func get_performance_stats() -> Dictionary:
	var total_effects: int = active_effects.size()
	var total_cost: float = 0.0
	var category_counts: Dictionary = {}
	
	for effect_data in active_effects.values():
		total_cost += effect_data.get("performance_cost", 1.0)
		var effect_type: String = effect_data.get("effect_type", "unknown")
		var category: String = WCSShaderLibrary.get_shader_category(effect_type)
		category_counts[category] = category_counts.get(category, 0) + 1
	
	return {
		"total_effects": total_effects,
		"total_performance_cost": total_cost,
		"average_cost_per_effect": total_cost / max(1.0, total_effects),
		"category_distribution": category_counts,
		"max_concurrent_effects": max_concurrent_effects,
		"quality_level": quality_level
	}