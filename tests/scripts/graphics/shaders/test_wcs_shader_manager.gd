extends GdUnitTestSuite

## Tests for WCS Shader Manager functionality
## Tests shader loading, compilation, effect creation, and performance management

var shader_manager: WCSShaderManager

func before_test():
	shader_manager = WCSShaderManager.new()
	add_child(shader_manager)

func after_test():
	if shader_manager:
		shader_manager.queue_free()

func test_shader_manager_initialization():
	assert_that(shader_manager).is_not_null()
	assert_that(shader_manager.shader_cache).is_not_null()
	assert_that(shader_manager.effect_pools).is_not_null()
	assert_that(shader_manager.fallback_shader).is_not_null()

func test_fallback_shader_creation():
	var fallback_shader: Shader = shader_manager.fallback_shader
	assert_that(fallback_shader).is_not_null()
	assert_that(fallback_shader.code).contains("fallback_color")

func test_shader_loading():
	# Shader loading should complete without errors
	assert_that(shader_manager.shader_cache.size()).is_greater(0)
	
	# Should have fallback shaders for missing files
	var laser_shader: Shader = shader_manager.get_shader("laser_beam")
	assert_that(laser_shader).is_not_null()

func test_get_shader_functionality():
	# Test getting an existing shader
	var hull_shader: Shader = shader_manager.get_shader("ship_hull")
	assert_that(hull_shader).is_not_null()
	
	# Test getting a non-existent shader returns fallback
	var invalid_shader: Shader = shader_manager.get_shader("non_existent_shader")
	assert_that(invalid_shader).is_same(shader_manager.fallback_shader)

func test_create_material_with_shader():
	var parameters: Dictionary = {
		"beam_color": Vector3(1.0, 0.0, 0.0),
		"beam_intensity": 2.0,
		"beam_width": 1.0
	}
	
	var material: ShaderMaterial = shader_manager.create_material_with_shader("laser_beam", parameters)
	
	assert_that(material).is_not_null()
	assert_that(material.shader).is_not_null()
	# Note: shader parameters can't be easily tested due to Godot internals

func test_effect_pools_setup():
	assert_that(shader_manager.effect_pools.has("laser_beam")).is_true()
	assert_that(shader_manager.effect_pools.has("explosion_small")).is_true()
	assert_that(shader_manager.effect_pools.has("shield_impact")).is_true()
	
	# Each pool should have pre-allocated nodes
	for pool_type in shader_manager.effect_pools.keys():
		var pool: Array = shader_manager.effect_pools[pool_type]
		assert_that(pool.size()).is_greater(0)

func test_create_weapon_effect():
	var start_pos: Vector3 = Vector3(0, 0, 0)
	var end_pos: Vector3 = Vector3(10, 0, 0)
	var color: Color = Color.RED
	
	var laser_effect: Node3D = shader_manager.create_weapon_effect("laser", start_pos, end_pos, color, 2.0)
	
	assert_that(laser_effect).is_not_null()
	assert_that(laser_effect).is_instanceof(MeshInstance3D)
	
	var mesh_instance: MeshInstance3D = laser_effect as MeshInstance3D
	assert_that(mesh_instance.material_override).is_not_null()
	assert_that(mesh_instance.material_override).is_instanceof(ShaderMaterial)

func test_create_explosion_effect():
	var explosion_pos: Vector3 = Vector3(5, 5, 5)
	
	var explosion_effect: Node3D = shader_manager.create_explosion_effect(explosion_pos, "small", 1.5)
	
	assert_that(explosion_effect).is_not_null()
	assert_that(explosion_effect).is_instanceof(MeshInstance3D)
	
	var mesh_instance: MeshInstance3D = explosion_effect as MeshInstance3D
	assert_that(mesh_instance.mesh).is_instanceof(SphereMesh)
	assert_that(mesh_instance.material_override).is_instanceof(ShaderMaterial)

func test_create_engine_trail_effect():
	var ship_node: Node3D = Node3D.new()
	add_child(ship_node)
	
	var engine_points: Array[Vector3] = [Vector3(0, 0, -2), Vector3(1, 0, -2)]
	var trail_color: Color = Color.CYAN
	
	var trail_effects: Array[Node3D] = shader_manager.create_engine_trail_effect(ship_node, engine_points, trail_color, 1.0)
	
	assert_that(trail_effects.size()).is_equal(2)
	
	for trail_effect in trail_effects:
		assert_that(trail_effect).is_not_null()
		assert_that(trail_effect).is_instanceof(MeshInstance3D)
		
		var mesh_instance: MeshInstance3D = trail_effect as MeshInstance3D
		assert_that(mesh_instance.mesh).is_instanceof(CylinderMesh)
	
	ship_node.queue_free()

func test_shield_impact_effect():
	var shield_node: MeshInstance3D = MeshInstance3D.new()
	shield_node.mesh = SphereMesh.new()
	add_child(shield_node)
	
	var impact_pos: Vector3 = Vector3(1, 0, 0)
	
	shader_manager.create_shield_impact_effect(impact_pos, shield_node, 2.0)
	
	# Should have created or updated shield material
	var material: ShaderMaterial = shield_node.get_surface_override_material(0) as ShaderMaterial
	assert_that(material).is_not_null()
	
	shield_node.queue_free()

func test_active_effect_tracking():
	var initial_count: int = shader_manager.get_active_effect_count()
	
	# Create some effects
	var laser_effect: Node3D = shader_manager.create_weapon_effect("laser", Vector3.ZERO, Vector3(5, 0, 0))
	var explosion_effect: Node3D = shader_manager.create_explosion_effect(Vector3(10, 0, 0), "small")
	
	assert_that(shader_manager.get_active_effect_count()).is_greater(initial_count)

func test_effect_cleanup():
	var initial_count: int = shader_manager.get_active_effect_count()
	
	# Create an effect
	var laser_effect: Node3D = shader_manager.create_weapon_effect("laser", Vector3.ZERO, Vector3(5, 0, 0))
	
	# Clear all effects
	shader_manager.clear_all_effects()
	
	assert_that(shader_manager.get_active_effect_count()).is_equal(0)

func test_quality_adjustment():
	# Create an effect
	var laser_effect: Node3D = shader_manager.create_weapon_effect("laser", Vector3.ZERO, Vector3(5, 0, 0))
	
	# Test different quality levels
	shader_manager.apply_quality_settings(0)  # Low quality
	assert_that(shader_manager.current_quality_level).is_equal(0)
	
	shader_manager.apply_quality_settings(3)  # Ultra quality  
	assert_that(shader_manager.current_quality_level).is_equal(3)

func test_shader_cache_stats():
	var stats: Dictionary = shader_manager.get_shader_cache_stats()
	
	assert_that(stats).is_not_null()
	assert_that(stats.has("total_shaders")).is_true()
	assert_that(stats.has("active_effects")).is_true()
	assert_that(stats.has("pool_usage")).is_true()
	
	assert_that(stats["total_shaders"]).is_greater(0)

func test_effect_id_generation():
	var effect1: Node3D = shader_manager.create_weapon_effect("laser", Vector3.ZERO, Vector3(5, 0, 0))
	var effect2: Node3D = shader_manager.create_weapon_effect("plasma", Vector3.ZERO, Vector3(5, 0, 0))
	
	# Different effects should have different IDs (tracked internally)
	assert_that(effect1).is_not_same(effect2)

func test_invalid_weapon_type():
	var invalid_effect: Node3D = shader_manager.create_weapon_effect("invalid_weapon", Vector3.ZERO, Vector3(5, 0, 0))
	
	assert_that(invalid_effect).is_null()

func test_plasma_bolt_effect():
	var plasma_effect: Node3D = shader_manager.create_weapon_effect("plasma", Vector3.ZERO, Vector3(5, 0, 0), Color.GREEN, 1.5)
	
	assert_that(plasma_effect).is_not_null()
	assert_that(plasma_effect).is_instanceof(MeshInstance3D)
	
	var mesh_instance: MeshInstance3D = plasma_effect as MeshInstance3D
	assert_that(mesh_instance.mesh).is_instanceof(SphereMesh)

func test_missile_trail_effect():
	var missile_effect: Node3D = shader_manager.create_weapon_effect("missile", Vector3.ZERO, Vector3(10, 0, 0), Color.ORANGE, 1.0)
	
	assert_that(missile_effect).is_not_null()
	assert_that(missile_effect).is_instanceof(MeshInstance3D)
	
	var mesh_instance: MeshInstance3D = missile_effect as MeshInstance3D
	assert_that(mesh_instance.mesh).is_instanceof(CylinderMesh)

func test_explosion_animation_setup():
	var explosion_effect: Node3D = shader_manager.create_explosion_effect(Vector3.ZERO, "large", 2.0)
	
	assert_that(explosion_effect).is_not_null()
	
	# Should have been configured for large explosion
	var mesh_instance: MeshInstance3D = explosion_effect as MeshInstance3D
	var sphere_mesh: SphereMesh = mesh_instance.mesh as SphereMesh
	assert_that(sphere_mesh.radius).is_equal(2.0)  # scale_factor applied
	assert_that(sphere_mesh.height).is_equal(4.0)  # 2.0 * scale_factor

func test_pooled_effect_reuse():
	# Create and destroy multiple effects to test pooling
	for i in range(3):
		var effect: Node3D = shader_manager.create_weapon_effect("laser", Vector3.ZERO, Vector3(5, 0, 0))
		shader_manager.clear_all_effects()
	
	# Pool should still have effects available
	var pool_stats: Dictionary = shader_manager.get_shader_cache_stats()["pool_usage"]
	assert_that(pool_stats.has("laser_beam")).is_true()