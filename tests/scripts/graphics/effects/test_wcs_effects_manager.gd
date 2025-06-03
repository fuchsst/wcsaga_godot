extends GdUnitTestSuite

## Tests for WCS Effects Manager functionality
## Tests effect creation, management, and performance optimization

var effects_manager: WCSEffectsManager

func before_test():
	effects_manager = WCSEffectsManager.new()
	add_child(effects_manager)

func after_test():
	if effects_manager:
		effects_manager.queue_free()

func test_effects_manager_initialization():
	assert_that(effects_manager).is_not_null()
	assert_that(effects_manager.effect_pools).is_not_empty()
	assert_that(effects_manager.effect_templates).is_not_empty()

func test_create_weapon_effect():
	var start_pos = Vector3(0, 0, 0)
	var end_pos = Vector3(10, 0, 0)
	var color = Color.RED
	
	var effect_id = effects_manager.create_weapon_effect("laser", start_pos, end_pos, color, 2.0)
	
	assert_that(effect_id).is_not_empty()
	assert_that(effects_manager.active_effects).contains_key(effect_id)
	
	var effect_data = effects_manager.active_effects[effect_id]
	assert_that(effect_data["type"]).is_equal(WCSEffectsManager.EffectType.WEAPON_LASER_BEAM)

func test_create_explosion_effect():
	var position = Vector3(5, 5, 5)
	
	var effect_id = effects_manager.create_explosion_effect(position, "large", 2.0, 4.0)
	
	assert_that(effect_id).is_not_empty()
	assert_that(effects_manager.active_effects).contains_key(effect_id)
	
	var effect_data = effects_manager.active_effects[effect_id]
	assert_that(effect_data["type"]).is_equal(WCSEffectsManager.EffectType.EXPLOSION_LARGE)

func test_create_engine_effect():
	var ship_node = Node3D.new()
	add_child(ship_node)
	
	var engine_positions = [Vector3(0, 0, -2), Vector3(1, 0, -2)]
	var effect_ids = effects_manager.create_engine_effect(ship_node, engine_positions, "standard", 1.5)
	
	assert_that(effect_ids.size()).is_equal(2)
	for effect_id in effect_ids:
		assert_that(effect_id).is_not_empty()
		assert_that(effects_manager.active_effects).contains_key(effect_id)
	
	ship_node.queue_free()

func test_create_shield_impact_effect():
	var shield_node = MeshInstance3D.new()
	shield_node.mesh = SphereMesh.new()
	add_child(shield_node)
	
	var impact_pos = Vector3(1, 1, 0)
	var effect_id = effects_manager.create_shield_impact_effect(impact_pos, shield_node, 2.0)
	
	assert_that(effect_id).is_not_empty()
	assert_that(effects_manager.active_effects).contains_key(effect_id)
	
	shield_node.queue_free()

func test_destroy_effect():
	var position = Vector3(0, 0, 0)
	var effect_id = effects_manager.create_explosion_effect(position, "small")
	
	assert_that(effects_manager.active_effects).contains_key(effect_id)
	
	effects_manager.destroy_effect(effect_id)
	
	assert_that(effects_manager.active_effects).not_contains_key(effect_id)

func test_effect_quality_settings():
	# Test low quality
	effects_manager.set_quality_level(1)
	assert_that(effects_manager.quality_level).is_equal(1)
	assert_that(effects_manager.particle_quality_multiplier).is_equal(0.5)
	assert_that(effects_manager.max_active_effects).is_equal(48)
	
	# Test high quality
	effects_manager.set_quality_level(3)
	assert_that(effects_manager.quality_level).is_equal(3)
	assert_that(effects_manager.particle_quality_multiplier).is_equal(1.0)
	assert_that(effects_manager.max_active_effects).is_equal(80)

func test_effect_templates():
	# Check that templates are loaded
	assert_that(effects_manager.effect_templates).contains_key("laser_red")
	assert_that(effects_manager.effect_templates).contains_key("fighter_explosion")
	assert_that(effects_manager.effect_templates).contains_key("standard_engine")
	assert_that(effects_manager.effect_templates).contains_key("standard_shield")

func test_effect_pool_integration():
	# Test that effect pools are properly integrated
	assert_that(effects_manager.effect_pools).contains_key(WCSEffectsManager.EffectType.EXPLOSION_SMALL)
	assert_that(effects_manager.effect_pools).contains_key(WCSEffectsManager.EffectType.WEAPON_LASER_BEAM)
	
	var pool = effects_manager.effect_pools[WCSEffectsManager.EffectType.EXPLOSION_SMALL]
	assert_that(pool).is_not_null()
	assert_that(pool).is_instanceof(WCSEffectPool)

func test_get_effect_statistics():
	var stats = effects_manager.get_effect_statistics()
	
	assert_that(stats).is_not_null()
	assert_that(stats).contains_keys([
		"active_effects",
		"max_effects", 
		"quality_level",
		"particle_multiplier",
		"effect_templates",
		"pool_statistics"
	])

func test_clear_all_effects():
	# Create some effects
	var effect_id1 = effects_manager.create_explosion_effect(Vector3.ZERO, "small")
	var effect_id2 = effects_manager.create_explosion_effect(Vector3(10, 0, 0), "medium")
	
	assert_that(effects_manager.active_effects.size()).is_greater_equal(2)
	
	effects_manager.clear_all_effects()
	
	assert_that(effects_manager.active_effects.size()).is_equal(0)

func test_weapon_effect_types():
	var position = Vector3.ZERO
	var end_pos = Vector3(10, 0, 0)
	
	# Test different weapon types
	var laser_id = effects_manager.create_weapon_effect("laser", position, end_pos)
	var plasma_id = effects_manager.create_weapon_effect("plasma", position, end_pos)
	var missile_id = effects_manager.create_weapon_effect("missile", position, end_pos)
	
	assert_that(laser_id).is_not_empty()
	assert_that(plasma_id).is_not_empty()  
	assert_that(missile_id).is_not_empty()
	
	# Verify correct effect types
	assert_that(effects_manager.active_effects[laser_id]["type"]).is_equal(WCSEffectsManager.EffectType.WEAPON_LASER_BEAM)
	assert_that(effects_manager.active_effects[plasma_id]["type"]).is_equal(WCSEffectsManager.EffectType.WEAPON_PLASMA_BOLT)
	assert_that(effects_manager.active_effects[missile_id]["type"]).is_equal(WCSEffectsManager.EffectType.WEAPON_MISSILE_TRAIL)

func test_explosion_effect_types():
	var position = Vector3.ZERO
	
	# Test different explosion types
	var small_id = effects_manager.create_explosion_effect(position, "small")
	var medium_id = effects_manager.create_explosion_effect(position, "medium")
	var large_id = effects_manager.create_explosion_effect(position, "large") 
	var capital_id = effects_manager.create_explosion_effect(position, "capital")
	var asteroid_id = effects_manager.create_explosion_effect(position, "asteroid")
	
	# Verify correct effect types
	assert_that(effects_manager.active_effects[small_id]["type"]).is_equal(WCSEffectsManager.EffectType.EXPLOSION_SMALL)
	assert_that(effects_manager.active_effects[medium_id]["type"]).is_equal(WCSEffectsManager.EffectType.EXPLOSION_MEDIUM)
	assert_that(effects_manager.active_effects[large_id]["type"]).is_equal(WCSEffectsManager.EffectType.EXPLOSION_LARGE)
	assert_that(effects_manager.active_effects[capital_id]["type"]).is_equal(WCSEffectsManager.EffectType.EXPLOSION_CAPITAL)
	assert_that(effects_manager.active_effects[asteroid_id]["type"]).is_equal(WCSEffectsManager.EffectType.EXPLOSION_ASTEROID)

func test_engine_effect_types():
	var ship_node = Node3D.new()
	add_child(ship_node)
	
	var engine_positions = [Vector3(0, 0, -2)]
	
	# Test different engine types
	var standard_ids = effects_manager.create_engine_effect(ship_node, engine_positions, "standard")
	var afterburner_ids = effects_manager.create_engine_effect(ship_node, engine_positions, "afterburner")
	var alien_ids = effects_manager.create_engine_effect(ship_node, engine_positions, "alien")
	
	assert_that(standard_ids.size()).is_equal(1)
	assert_that(afterburner_ids.size()).is_equal(1)
	assert_that(alien_ids.size()).is_equal(1)
	
	# Verify effect types
	assert_that(effects_manager.active_effects[standard_ids[0]]["type"]).is_equal(WCSEffectsManager.EffectType.ENGINE_EXHAUST)
	assert_that(effects_manager.active_effects[afterburner_ids[0]]["type"]).is_equal(WCSEffectsManager.EffectType.ENGINE_AFTERBURNER)
	assert_that(effects_manager.active_effects[alien_ids[0]]["type"]).is_equal(WCSEffectsManager.EffectType.ENGINE_EXHAUST)
	
	ship_node.queue_free()

func test_effect_automatic_cleanup():
	# Create effect with short lifetime
	var properties = {
		"lifetime": 0.1,  # Very short lifetime
		"scale": 1.0,
		"color_primary": Color.RED
	}
	
	var effect_id = effects_manager.create_effect(WCSEffectsManager.EffectType.EXPLOSION_SMALL, Vector3.ZERO, properties)
	
	assert_that(effect_id).is_not_empty()
	assert_that(effects_manager.active_effects).contains_key(effect_id)
	
	# Wait for automatic cleanup
	await get_tree().create_timer(0.2).timeout
	
	assert_that(effects_manager.active_effects).not_contains_key(effect_id)

func test_effect_signals():
	var signal_received = false
	var received_effect_id = ""
	
	effects_manager.effect_created.connect(func(effect_id: String, effect_node: Node3D):
		signal_received = true
		received_effect_id = effect_id
	)
	
	var effect_id = effects_manager.create_explosion_effect(Vector3.ZERO, "small")
	
	# Give signal time to propagate
	await get_tree().process_frame
	
	assert_that(signal_received).is_true()
	assert_that(received_effect_id).is_equal(effect_id)

func test_effect_id_generation():
	# Test that effect IDs are unique
	var effect_id1 = effects_manager.create_explosion_effect(Vector3.ZERO, "small")
	var effect_id2 = effects_manager.create_explosion_effect(Vector3.ZERO, "small")
	
	assert_that(effect_id1).is_not_equal(effect_id2)
	assert_that(effect_id1).is_not_empty()
	assert_that(effect_id2).is_not_empty()

func test_performance_monitoring():
	# Create many effects to test performance monitoring
	var effect_ids: Array[String] = []
	
	for i in range(10):
		var effect_id = effects_manager.create_explosion_effect(Vector3(i, 0, 0), "small")
		effect_ids.append(effect_id)
	
	var stats = effects_manager.get_effect_statistics()
	assert_that(stats["active_effects"]).is_greater_equal(10)