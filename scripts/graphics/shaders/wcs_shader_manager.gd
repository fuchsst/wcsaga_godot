class_name WCSShaderManager
extends Node

## Central management for WCS shader compilation and effect processing
## Converts WCS visual effects to modern Godot shaders with GPU acceleration

signal shader_compiled(shader_name: String, success: bool)
signal shader_loading_completed(total_shaders: int, failed_shaders: int)
signal shader_parameter_updated(shader_name: String, parameter: String, value: Variant)
signal effect_created(effect_id: String, effect_type: String)
signal effect_destroyed(effect_id: String)
signal effect_animation_completed(effect_id: String)
signal shader_performance_warning(shader_name: String, frame_time: float)
signal effect_quality_adjusted(quality_level: int)

var shader_cache: Dictionary = {}
var shader_templates: Dictionary = {}
var active_effects: Dictionary = {}
var effect_pools: Dictionary = {}
var fallback_shader: Shader
var current_quality_level: int = 2
var effect_id_counter: int = 0

# Performance tracking
var shader_performance_data: Dictionary = {}

func _ready() -> void:
	name = "WCSShaderManager"
	_create_fallback_shader()
	load_wcs_shader_library()
	setup_effect_pools()
	print("WCSShaderManager: Initialized with shader library and effect pools")

func _create_fallback_shader() -> void:
	# Create a simple fallback shader for when shaders fail to load
	var fallback_code: String = """
shader_type spatial;

uniform vec3 fallback_color : source_color = vec3(1.0, 0.0, 1.0);

void fragment() {
	ALBEDO = fallback_color;
	EMISSION = fallback_color * 0.3;
}
"""
	fallback_shader = Shader.new()
	fallback_shader.code = fallback_code
	print("WCSShaderManager: Fallback shader created")

func load_wcs_shader_library() -> void:
	var shader_paths: Array[String] = [
		"res://shaders/materials/ship_hull.gdshader",
		"res://shaders/weapons/laser_beam.gdshader",
		"res://shaders/weapons/plasma_bolt.gdshader",
		"res://shaders/weapons/missile_trail.gdshader",
		"res://shaders/weapons/weapon_impact.gdshader",
		"res://shaders/effects/energy_shield.gdshader",
		"res://shaders/effects/engine_trail.gdshader",
		"res://shaders/effects/explosion_core.gdshader",
		"res://shaders/effects/explosion_debris.gdshader",
		"res://shaders/environment/nebula.gdshader",
		"res://shaders/environment/space_dust.gdshader",
		"res://shaders/post_processing/bloom_filter.gdshader",
		"res://shaders/post_processing/motion_blur.gdshader"
	]
	
	var loaded_count: int = 0
	var failed_count: int = 0
	
	for shader_path in shader_paths:
		if ResourceLoader.exists(shader_path):
			var shader: Shader = load(shader_path)
			if shader:
				var shader_name: String = shader_path.get_file().get_basename()
				shader_cache[shader_name] = shader
				loaded_count += 1
				shader_compiled.emit(shader_name, true)
				print("WCSShaderManager: Loaded shader: ", shader_name)
			else:
				failed_count += 1
				push_error("Failed to load shader: " + shader_path)
				shader_compiled.emit(shader_path.get_file().get_basename(), false)
		else:
			# Shader file doesn't exist yet, create placeholder
			var shader_name: String = shader_path.get_file().get_basename()
			shader_cache[shader_name] = fallback_shader
			print("WCSShaderManager: Using fallback for missing shader: ", shader_name)
	
	shader_loading_completed.emit(loaded_count, failed_count)
	print("WCSShaderManager: Shader library loaded - %d succeeded, %d failed" % [loaded_count, failed_count])

func setup_effect_pools() -> void:
	# Pre-create pools for common effects to avoid runtime allocation
	effect_pools = {
		"laser_beam": [],
		"plasma_bolt": [],
		"missile_trail": [],
		"explosion_small": [],
		"explosion_large": [],
		"shield_impact": [],
		"engine_trail": [],
		"weapon_impact": []
	}
	
	# Pre-populate some pools with reusable nodes
	for pool_type in effect_pools.keys():
		for i in range(5):  # 5 instances per pool
			var effect_node: MeshInstance3D = _create_pool_effect_node(pool_type)
			effect_node.visible = false
			add_child(effect_node)
			effect_pools[pool_type].append(effect_node)
	
	print("WCSShaderManager: Effect pools created with pre-allocated instances")

func _create_pool_effect_node(effect_type: String) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = effect_type + "_pooled"
	
	match effect_type:
		"laser_beam", "plasma_bolt":
			node.mesh = BoxMesh.new()
		"explosion_small", "explosion_large":
			node.mesh = SphereMesh.new()
		"missile_trail", "engine_trail":
			node.mesh = CylinderMesh.new()
		_:
			node.mesh = QuadMesh.new()
	
	return node

func get_shader(shader_name: String) -> Shader:
	if shader_name in shader_cache:
		return shader_cache[shader_name]
	
	push_warning("Shader not found: " + shader_name + ", using fallback")
	return fallback_shader

func create_material_with_shader(shader_name: String, parameters: Dictionary = {}) -> ShaderMaterial:
	var shader: Shader = get_shader(shader_name)
	if not shader:
		return null
	
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	
	# Apply shader parameters
	for param_name in parameters:
		material.set_shader_parameter(param_name, parameters[param_name])
		shader_parameter_updated.emit(shader_name, param_name, parameters[param_name])
	
	return material

func create_weapon_effect(weapon_type: String, start_pos: Vector3, end_pos: Vector3, 
                         color: Color = Color.RED, intensity: float = 1.0) -> Node3D:
	var effect_id: String = _generate_effect_id()
	var effect_node: Node3D
	
	match weapon_type.to_lower():
		"laser":
			effect_node = _create_laser_beam_effect(start_pos, end_pos, color, intensity)
		"plasma":
			effect_node = _create_plasma_bolt_effect(start_pos, end_pos, color, intensity)
		"missile":
			effect_node = _create_missile_trail_effect(start_pos, end_pos, color, intensity)
		_:
			push_error("Unknown weapon type: " + weapon_type)
			return null
	
	if effect_node:
		active_effects[effect_id] = effect_node
		effect_created.emit(effect_id, weapon_type)
		
		# Set up automatic cleanup
		var effect_lifetime: float = 0.2  # Default short lifetime for weapon effects
		match weapon_type.to_lower():
			"missile":
				effect_lifetime = 2.0  # Longer trail for missiles
			"plasma":
				effect_lifetime = 0.5
		
		get_tree().create_timer(effect_lifetime).timeout.connect(
			func(): _cleanup_effect(effect_id)
		)
	
	return effect_node

func create_shield_impact_effect(impact_pos: Vector3, shield_node: Node3D, 
                                intensity: float = 1.0) -> void:
	var shield_material: ShaderMaterial = null
	
	# Try to get existing shield material
	if shield_node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = shield_node as MeshInstance3D
		shield_material = mesh_instance.get_surface_override_material(0) as ShaderMaterial
	
	# Create shield material if none exists
	if not shield_material:
		shield_material = create_material_with_shader("energy_shield", {
			"shield_strength": 1.0,
			"shield_color": Vector3(0.0, 0.5, 1.0),
			"pulse_speed": 3.0
		})
		if shield_node is MeshInstance3D:
			(shield_node as MeshInstance3D).set_surface_override_material(0, shield_material)
	
	# Convert world position to local space if needed
	var local_impact_pos: Vector3 = shield_node.to_local(impact_pos)
	
	# Animate shield impact
	shield_material.set_shader_parameter("impact_position", local_impact_pos)
	shield_material.set_shader_parameter("impact_intensity", intensity)
	shield_material.set_shader_parameter("impact_radius", 0.1)
	
	# Create impact animation
	var tween: Tween = shield_node.create_tween()
	tween.parallel().tween_method(
		func(value): shield_material.set_shader_parameter("impact_intensity", value),
		intensity, 0.0, 1.0
	)
	tween.parallel().tween_method(
		func(value): shield_material.set_shader_parameter("impact_radius", value),
		0.1, 2.0, 1.0
	)
	
	var effect_id: String = _generate_effect_id()
	effect_created.emit(effect_id, "shield_impact")
	
	# Clean up after animation
	tween.finished.connect(func(): effect_animation_completed.emit(effect_id))

func create_explosion_effect(position: Vector3, explosion_type: String, 
                           scale_factor: float = 1.0) -> Node3D:
	var explosion_node: MeshInstance3D = _get_pooled_effect("explosion_" + explosion_type)
	if not explosion_node:
		explosion_node = MeshInstance3D.new()
		explosion_node.mesh = SphereMesh.new()
	
	# Configure explosion mesh
	var sphere_mesh: SphereMesh = explosion_node.mesh as SphereMesh
	sphere_mesh.radius = 1.0 * scale_factor
	sphere_mesh.height = 2.0 * scale_factor
	
	# Create explosion material
	var explosion_material: ShaderMaterial = create_material_with_shader("explosion_core", {
		"explosion_scale": scale_factor,
		"explosion_intensity": 2.0,
		"explosion_color": Vector3(1.0, 0.5, 0.0)  # Orange
	})
	
	explosion_node.material_override = explosion_material
	explosion_node.global_position = position
	explosion_node.visible = true
	
	# Animate explosion sequence
	_animate_explosion_sequence(explosion_node, explosion_type, scale_factor)
	
	var effect_id: String = _generate_effect_id()
	active_effects[effect_id] = explosion_node
	effect_created.emit(effect_id, "explosion_" + explosion_type)
	
	return explosion_node

func create_engine_trail_effect(ship_node: Node3D, engine_points: Array[Vector3], 
                               trail_color: Color = Color.CYAN, intensity: float = 1.0) -> Array[Node3D]:
	var trail_nodes: Array[Node3D] = []
	
	for engine_pos in engine_points:
		var trail_node: MeshInstance3D = _get_pooled_effect("engine_trail")
		if not trail_node:
			trail_node = MeshInstance3D.new()
			trail_node.mesh = CylinderMesh.new()
		
		# Configure trail geometry
		var cylinder_mesh: CylinderMesh = trail_node.mesh as CylinderMesh
		cylinder_mesh.top_radius = 0.1
		cylinder_mesh.bottom_radius = 0.3
		cylinder_mesh.height = 2.0
		
		# Create trail material
		var trail_material: ShaderMaterial = create_material_with_shader("engine_trail", {
			"trail_color": Vector3(trail_color.r, trail_color.g, trail_color.b),
			"trail_intensity": intensity,
			"scroll_speed": 2.0,
			"flicker_rate": 8.0
		})
		
		trail_node.material_override = trail_material
		trail_node.position = engine_pos
		trail_node.visible = true
		
		# Attach to ship
		ship_node.add_child(trail_node)
		trail_nodes.append(trail_node)
		
		var effect_id: String = _generate_effect_id()
		active_effects[effect_id] = trail_node
		effect_created.emit(effect_id, "engine_trail")
	
	return trail_nodes

func _create_laser_beam_effect(start_pos: Vector3, end_pos: Vector3, 
                              color: Color, intensity: float) -> MeshInstance3D:
	var beam_node: MeshInstance3D = _get_pooled_effect("laser_beam")
	if not beam_node:
		beam_node = MeshInstance3D.new()
		beam_node.mesh = BoxMesh.new()
	
	# Configure beam geometry
	var beam_length: float = start_pos.distance_to(end_pos)
	var box_mesh: BoxMesh = beam_node.mesh as BoxMesh
	box_mesh.size = Vector3(0.05, 0.05, beam_length)
	
	# Create beam material
	var beam_material: ShaderMaterial = create_material_with_shader("laser_beam", {
		"beam_color": Vector3(color.r, color.g, color.b),
		"beam_intensity": intensity,
		"beam_width": 1.0,
		"flicker_speed": 5.0,
		"energy_variation": 0.2
	})
	
	beam_node.material_override = beam_material
	beam_node.visible = true
	
	# Position and orient beam
	var beam_center: Vector3 = (start_pos + end_pos) * 0.5
	beam_node.global_position = beam_center
	beam_node.look_at(end_pos, Vector3.UP)
	
	# Animate beam lifecycle
	var tween: Tween = beam_node.create_tween()
	tween.tween_method(
		func(value): beam_material.set_shader_parameter("beam_intensity", value),
		intensity, 0.0, 0.1
	)
	
	return beam_node

func _create_plasma_bolt_effect(start_pos: Vector3, end_pos: Vector3, 
                               color: Color, intensity: float) -> MeshInstance3D:
	var bolt_node: MeshInstance3D = _get_pooled_effect("plasma_bolt")
	if not bolt_node:
		bolt_node = MeshInstance3D.new()
		bolt_node.mesh = SphereMesh.new()
	
	# Configure bolt geometry
	var sphere_mesh: SphereMesh = bolt_node.mesh as SphereMesh
	sphere_mesh.radius = 0.2
	sphere_mesh.height = 0.4
	
	# Create plasma material
	var plasma_material: ShaderMaterial = create_material_with_shader("plasma_bolt", {
		"plasma_color": Vector3(color.r, color.g, color.b),
		"plasma_intensity": intensity,
		"energy_core_size": 0.6,
		"plasma_flicker": 0.3
	})
	
	bolt_node.material_override = plasma_material
	bolt_node.global_position = start_pos
	bolt_node.visible = true
	
	# Animate movement from start to end
	var travel_time: float = 0.3
	var tween: Tween = bolt_node.create_tween()
	tween.tween_property(bolt_node, "global_position", end_pos, travel_time)
	
	return bolt_node

func _create_missile_trail_effect(start_pos: Vector3, end_pos: Vector3, 
                                 color: Color, intensity: float) -> MeshInstance3D:
	var trail_node: MeshInstance3D = _get_pooled_effect("missile_trail")
	if not trail_node:
		trail_node = MeshInstance3D.new()
		trail_node.mesh = CylinderMesh.new()
	
	# Configure trail geometry
	var trail_length: float = start_pos.distance_to(end_pos)
	var cylinder_mesh: CylinderMesh = trail_node.mesh as CylinderMesh
	cylinder_mesh.top_radius = 0.05
	cylinder_mesh.bottom_radius = 0.15
	cylinder_mesh.height = trail_length
	
	# Create trail material
	var trail_material: ShaderMaterial = create_material_with_shader("missile_trail", {
		"trail_color": Vector3(color.r, color.g, color.b),
		"exhaust_intensity": intensity,
		"heat_distortion": 0.1,
		"particle_density": 0.8
	})
	
	trail_node.material_override = trail_material
	trail_node.visible = true
	
	# Position and orient trail
	var trail_center: Vector3 = (start_pos + end_pos) * 0.5
	trail_node.global_position = trail_center
	trail_node.look_at(end_pos, Vector3.UP)
	
	return trail_node

func _animate_explosion_sequence(explosion_node: MeshInstance3D, explosion_type: String, scale: float) -> void:
	var material: ShaderMaterial = explosion_node.material_override as ShaderMaterial
	if not material:
		return
	
	# Multi-stage explosion animation
	var tween: Tween = explosion_node.create_tween()
	tween.set_parallel(true)
	
	# Stage 1: Initial explosion flash
	tween.tween_method(
		func(value): material.set_shader_parameter("explosion_intensity", value),
		2.0, 4.0, 0.1
	)
	
	# Stage 2: Expansion
	tween.tween_method(
		func(value): explosion_node.scale = Vector3.ONE * value,
		1.0, scale * 2.0, 0.8
	)
	
	# Stage 3: Fade out
	tween.tween_method(
		func(value): material.set_shader_parameter("explosion_intensity", value),
		4.0, 0.0, 0.7
	).set_delay(0.3)
	
	# Different timings for different explosion types
	match explosion_type:
		"large":
			tween.tween_property(explosion_node, "scale", Vector3.ONE * scale * 3.0, 1.5)
		"small":
			tween.tween_property(explosion_node, "scale", Vector3.ONE * scale * 1.5, 0.8)

func _get_pooled_effect(effect_type: String) -> MeshInstance3D:
	if effect_type in effect_pools and not effect_pools[effect_type].is_empty():
		var effect_node: MeshInstance3D = effect_pools[effect_type].pop_back()
		return effect_node
	return null

func _return_to_pool(effect_node: MeshInstance3D, effect_type: String) -> void:
	effect_node.visible = false
	effect_node.material_override = null
	effect_node.scale = Vector3.ONE
	
	if effect_type in effect_pools:
		effect_pools[effect_type].append(effect_node)

func apply_quality_settings(quality_level: int) -> void:
	current_quality_level = quality_level
	
	# Adjust shader complexity based on quality
	for effect_id in active_effects:
		var effect: Node3D = active_effects[effect_id]
		_adjust_effect_quality(effect, quality_level)
	
	effect_quality_adjusted.emit(quality_level)
	print("WCSShaderManager: Applied quality level ", quality_level)

func _adjust_effect_quality(effect: Node3D, quality: int) -> void:
	if not effect is MeshInstance3D:
		return
	
	var mesh_instance: MeshInstance3D = effect as MeshInstance3D
	var material: ShaderMaterial = mesh_instance.material_override as ShaderMaterial
	if not material:
		return
	
	# Adjust shader parameters based on quality
	match quality:
		0, 1:  # Low quality
			material.set_shader_parameter("effect_complexity", 0.5)
			material.set_shader_parameter("particle_count", 50)
			material.set_shader_parameter("detail_level", 0.3)
		2:     # Medium quality
			material.set_shader_parameter("effect_complexity", 0.75)
			material.set_shader_parameter("particle_count", 100)
			material.set_shader_parameter("detail_level", 0.6)
		3, 4:  # High/Ultra quality
			material.set_shader_parameter("effect_complexity", 1.0)
			material.set_shader_parameter("particle_count", 200)
			material.set_shader_parameter("detail_level", 1.0)

func _generate_effect_id() -> String:
	effect_id_counter += 1
	return "effect_" + str(effect_id_counter)

func _cleanup_effect(effect_id: String) -> void:
	if effect_id in active_effects:
		var effect_node: Node3D = active_effects[effect_id]
		active_effects.erase(effect_id)
		effect_destroyed.emit(effect_id)
		
		# Return to pool if it's a pooled effect
		if effect_node is MeshInstance3D:
			var mesh_instance: MeshInstance3D = effect_node as MeshInstance3D
			var effect_type: String = _get_effect_type_from_node(mesh_instance)
			if effect_type in effect_pools:
				_return_to_pool(mesh_instance, effect_type)
				return
		
		# Otherwise just free the node
		if effect_node and is_instance_valid(effect_node):
			effect_node.queue_free()

func _get_effect_type_from_node(node: MeshInstance3D) -> String:
	if node.mesh is BoxMesh:
		return "laser_beam"
	elif node.mesh is SphereMesh:
		return "explosion_small"
	elif node.mesh is CylinderMesh:
		return "missile_trail"
	else:
		return "unknown"

func get_active_effect_count() -> int:
	return active_effects.size()

func clear_all_effects() -> void:
	for effect_id in active_effects.keys():
		_cleanup_effect(effect_id)
	print("WCSShaderManager: Cleared all active effects")

func get_shader_cache_stats() -> Dictionary:
	return {
		"total_shaders": shader_cache.size(),
		"active_effects": active_effects.size(),
		"pool_usage": _get_pool_usage_stats()
	}

func _get_pool_usage_stats() -> Dictionary:
	var stats: Dictionary = {}
	for pool_type in effect_pools:
		stats[pool_type] = effect_pools[pool_type].size()
	return stats