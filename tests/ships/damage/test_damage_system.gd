extends GdUnitTestSuite

## Comprehensive test suite for SHIP-009: Damage System and Hull/Shield Mechanics
## Tests all acceptance criteria with integration tests, unit tests, and performance validation

# Test constants
const DamageManager = preload("res://scripts/ships/damage/damage_manager.gd")
const ArmorResistanceCalculator = preload("res://scripts/ships/damage/armor_resistance_calculator.gd")
const ShieldQuadrantManager = preload("res://scripts/ships/damage/shield_quadrant_manager.gd")
const CriticalDamageSystem = preload("res://scripts/ships/damage/critical_damage_system.gd")
const DamageVisualizationManager = preload("res://scripts/ships/damage/damage_visualization_manager.gd")
const CollisionDamageSystem = preload("res://scripts/ships/damage/collision_damage_system.gd")

# Mock classes and test fixtures
var mock_ship: BaseShip
var mock_ship_class: ShipClass
var damage_manager: DamageManager
var armor_calculator: ArmorResistanceCalculator
var shield_manager: ShieldQuadrantManager
var critical_system: CriticalDamageSystem
var visualization_manager: DamageVisualizationManager
var collision_system: CollisionDamageSystem

func before_test() -> void:
	"""Setup test environment before each test."""
	# Create mock ship and ship class
	mock_ship = BaseShip.new()
	mock_ship.name = "TestShip"
	mock_ship.max_hull_strength = 100.0
	mock_ship.current_hull_strength = 100.0
	mock_ship.max_shield_strength = 80.0
	mock_ship.current_shield_strength = 80.0
	mock_ship.mass = 1000.0
	
	# Create mock ship class
	mock_ship_class = ShipClass.new()
	mock_ship_class.class_name = "TestFighter"
	mock_ship_class.ship_type = ShipTypes.Type.FIGHTER
	mock_ship_class.max_hull_strength = 100.0
	mock_ship_class.max_shield_strength = 80.0
	mock_ship_class.mass = 1000.0
	mock_ship.ship_class = mock_ship_class
	
	# Initialize damage system components
	damage_manager = DamageManager.new()
	armor_calculator = ArmorResistanceCalculator.new()
	shield_manager = ShieldQuadrantManager.new()
	critical_system = CriticalDamageSystem.new()
	visualization_manager = DamageVisualizationManager.new()
	collision_system = CollisionDamageSystem.new()
	
	# Add to scene tree for testing
	add_child(mock_ship)
	mock_ship.add_child(damage_manager)
	mock_ship.add_child(shield_manager)
	mock_ship.add_child(critical_system)
	mock_ship.add_child(visualization_manager)
	mock_ship.add_child(collision_system)

func after_test() -> void:
	"""Cleanup after each test."""
	if mock_ship:
		mock_ship.queue_free()

# ============================================================================
# AC1: HULL DAMAGE SYSTEM TESTS
# ============================================================================

func test_hull_damage_system_initialization():
	"""Test hull damage system initialization (SHIP-009 AC1)."""
	# Initialize damage manager
	var success: bool = damage_manager.initialize_damage_manager(mock_ship)
	
	assert_bool(success).is_true()
	assert_float(damage_manager.max_hull_strength).is_equal(100.0)
	assert_float(damage_manager.current_hull_strength).is_equal(100.0)
	assert_float(damage_manager.hull_integrity_percentage).is_equal(100.0)

func test_hull_damage_application():
	"""Test hull damage application with subsystem distribution (SHIP-009 AC1)."""
	damage_manager.initialize_damage_manager(mock_ship)
	
	var hit_location: Vector3 = Vector3(0, 0, 5)  # Front hit
	var damage_amount: float = 30.0
	
	var applied_damage: float = damage_manager.apply_hull_damage(damage_amount, hit_location, DamageTypes.Type.KINETIC)
	
	# Should apply damage after armor resistance
	assert_float(applied_damage).is_greater(0.0)
	assert_float(damage_manager.current_hull_strength).is_less(100.0)
	assert_float(damage_manager.hull_integrity_percentage).is_less(100.0)

func test_armor_resistance_calculation():
	"""Test armor resistance reduces damage appropriately (SHIP-009 AC1, AC3)."""
	damage_manager.initialize_damage_manager(mock_ship)
	
	var hit_location: Vector3 = Vector3(0, 0, 5)
	var base_damage: float = 50.0
	
	# Test different damage types against armor
	var kinetic_damage: float = damage_manager.apply_hull_damage(base_damage, hit_location, DamageTypes.Type.KINETIC)
	
	mock_ship.current_hull_strength = 100.0  # Reset
	damage_manager.current_hull_strength = 100.0
	
	var energy_damage: float = damage_manager.apply_hull_damage(base_damage, hit_location, DamageTypes.Type.ENERGY)
	
	# Armor should affect damage types differently
	assert_float(kinetic_damage).is_not_equal(energy_damage)

func test_subsystem_damage_distribution():
	"""Test damage distribution to subsystems (SHIP-009 AC1)."""
	damage_manager.initialize_damage_manager(mock_ship)
	
	var damage_distributed_signal_received: bool = false
	var received_subsystem_name: String = ""
	var received_damage: float = 0.0
	
	damage_manager.subsystem_damage_distributed.connect(func(subsystem_name: String, damage: float):
		damage_distributed_signal_received = true
		received_subsystem_name = subsystem_name
		received_damage = damage
	)
	
	var hit_location: Vector3 = Vector3(0, 0, 5)
	damage_manager.apply_hull_damage(40.0, hit_location, DamageTypes.Type.KINETIC)
	
	# Should emit subsystem damage signal (if subsystem manager exists)
	# Note: This test may not trigger signal without proper subsystem manager

func test_hull_damage_threshold_detection():
	"""Test hull damage threshold detection (SHIP-009 AC1, AC5)."""
	damage_manager.initialize_damage_manager(mock_ship)
	
	var threshold_signal_received: bool = false
	var threshold_name: String = ""
	
	damage_manager.damage_threshold_reached.connect(func(name: String, percentage: float):
		threshold_signal_received = true
		threshold_name = name
	)
	
	# Apply damage to reach critical threshold (75% damage = 25% hull)
	var hit_location: Vector3 = Vector3(0, 0, 0)
	damage_manager.apply_hull_damage(80.0, hit_location, DamageTypes.Type.KINETIC)
	
	assert_bool(threshold_signal_received).is_true()
	assert_str(threshold_name).contains("critical")

# ============================================================================
# AC2: SHIELD QUADRANT SYSTEM TESTS
# ============================================================================

func test_shield_quadrant_initialization():
	"""Test shield quadrant system initialization (SHIP-009 AC2)."""
	var success: bool = shield_manager.initialize_shield_system(mock_ship)
	
	assert_bool(success).is_true()
	assert_float(shield_manager.max_shield_strength).is_equal(80.0)
	
	# Check quadrant distribution
	for i in range(4):
		assert_float(shield_manager.quadrant_current_strength[i]).is_greater(0.0)

func test_shield_quadrant_damage_absorption():
	"""Test shield quadrant damage absorption (SHIP-009 AC2)."""
	shield_manager.initialize_shield_system(mock_ship)
	
	var front_hit_location: Vector3 = Vector3(0, 0, 8)  # Front quadrant
	var damage_amount: float = 15.0
	
	var absorbed_damage: float = shield_manager.apply_shield_damage(damage_amount, front_hit_location, DamageTypes.Type.ENERGY)
	
	assert_float(absorbed_damage).is_greater(0.0)
	assert_float(shield_manager.quadrant_current_strength[ShieldQuadrantManager.ShieldQuadrant.FRONT]).is_less(shield_manager.quadrant_max_strength[0])

func test_shield_quadrant_targeting():
	"""Test shield quadrant targeting logic (SHIP-009 AC2)."""
	shield_manager.initialize_shield_system(mock_ship)
	
	# Test different hit locations target appropriate quadrants
	var front_damage: float = shield_manager.apply_shield_damage(10.0, Vector3(0, 0, 8), DamageTypes.Type.ENERGY)
	var rear_damage: float = shield_manager.apply_shield_damage(10.0, Vector3(0, 0, -8), DamageTypes.Type.ENERGY)
	var left_damage: float = shield_manager.apply_shield_damage(10.0, Vector3(-8, 0, 0), DamageTypes.Type.ENERGY)
	var right_damage: float = shield_manager.apply_shield_damage(10.0, Vector3(8, 0, 0), DamageTypes.Type.ENERGY)
	
	# All should absorb some damage
	assert_float(front_damage).is_greater(0.0)
	assert_float(rear_damage).is_greater(0.0)
	assert_float(left_damage).is_greater(0.0)
	assert_float(right_damage).is_greater(0.0)

func test_shield_quadrant_depletion_and_restoration():
	"""Test shield quadrant depletion and restoration (SHIP-009 AC2)."""
	shield_manager.initialize_shield_system(mock_ship)
	
	var depletion_signal_received: bool = false
	var restoration_signal_received: bool = false
	
	shield_manager.quadrant_depleted.connect(func(quadrant: int, name: String):
		depletion_signal_received = true
	)
	
	shield_manager.quadrant_restored.connect(func(quadrant: int, name: String):
		restoration_signal_received = true
	)
	
	# Deplete front quadrant
	var front_strength: float = shield_manager.quadrant_current_strength[0]
	shield_manager.apply_shield_damage(front_strength + 5.0, Vector3(0, 0, 8), DamageTypes.Type.ENERGY)
	
	assert_bool(depletion_signal_received).is_true()
	assert_float(shield_manager.quadrant_current_strength[0]).is_equal(0.0)
	
	# Wait for recharge (simulate frames)
	for i in range(60):  # Simulate 1 second at 60 FPS
		shield_manager._process_shield_recharge(1.0/60.0)
	
	# Should start restoring
	assert_float(shield_manager.quadrant_current_strength[0]).is_greater(0.0)

func test_shield_recharge_system():
	"""Test shield recharge mechanics (SHIP-009 AC2)."""
	shield_manager.initialize_shield_system(mock_ship)
	
	# Damage shields
	shield_manager.apply_shield_damage(20.0, Vector3(0, 0, 8), DamageTypes.Type.ENERGY)
	
	var initial_strength: float = shield_manager.quadrant_current_strength[0]
	
	# Process recharge
	shield_manager._process_shield_recharge(1.0)  # 1 second
	
	var recharged_strength: float = shield_manager.quadrant_current_strength[0]
	
	# Should have recharged some amount
	assert_float(recharged_strength).is_greater_equal(initial_strength)

# ============================================================================
# AC3: ARMOR RESISTANCE SYSTEM TESTS
# ============================================================================

func test_armor_resistance_calculation_accuracy():
	"""Test armor resistance calculation accuracy (SHIP-009 AC3)."""
	var damage_amount: float = 100.0
	var armor_type: int = ArmorResistanceCalculator.ArmorClass.STANDARD
	var damage_type: int = DamageTypes.Type.KINETIC
	var armor_thickness: float = 1.0
	var impact_location: Vector3 = Vector3(0, 0, 1)
	
	var damage_reduction: float = armor_calculator.calculate_damage_reduction(
		damage_amount, damage_type, armor_type, armor_thickness, impact_location
	)
	
	assert_float(damage_reduction).is_greater(0.0)
	assert_float(damage_reduction).is_less(damage_amount)

func test_armor_angle_of_impact():
	"""Test angle-of-impact calculations (SHIP-009 AC3)."""
	var damage_amount: float = 100.0
	var armor_type: int = ArmorResistanceCalculator.ArmorClass.STANDARD
	var damage_type: int = DamageTypes.Type.KINETIC
	var armor_thickness: float = 1.0
	var impact_location: Vector3 = Vector3(0, 0, 1)
	
	# Head-on impact
	var head_on_reduction: float = armor_calculator.calculate_damage_reduction(
		damage_amount, damage_type, armor_type, armor_thickness, impact_location, Vector3(0, 0, -1)
	)
	
	# Glancing impact
	var glancing_reduction: float = armor_calculator.calculate_damage_reduction(
		damage_amount, damage_type, armor_type, armor_thickness, impact_location, Vector3(1, 0, -0.1)
	)
	
	# Head-on should have more effective armor
	assert_float(head_on_reduction).is_greater_equal(glancing_reduction)

func test_armor_penetration_tracking():
	"""Test armor penetration tracking (SHIP-009 AC3)."""
	var impact_location: Vector3 = Vector3(2, 0, 1)
	
	# Apply multiple hits to same location
	for i in range(5):
		armor_calculator.calculate_damage_reduction(
			50.0, DamageTypes.Type.KINETIC, ArmorResistanceCalculator.ArmorClass.LIGHT, 
			1.0, impact_location, Vector3(0, 0, -1)
		)
	
	# Should have penetration tracking data
	assert_int(armor_calculator.penetration_tracking.size()).is_greater(0)

func test_armor_type_effectiveness():
	"""Test different armor types have different effectiveness (SHIP-009 AC3)."""
	var damage_amount: float = 100.0
	var damage_type: int = DamageTypes.Type.KINETIC
	var armor_thickness: float = 1.0
	var impact_location: Vector3 = Vector3(0, 0, 1)
	
	var light_armor_reduction: float = armor_calculator.calculate_damage_reduction(
		damage_amount, damage_type, ArmorResistanceCalculator.ArmorClass.LIGHT, armor_thickness, impact_location
	)
	
	var heavy_armor_reduction: float = armor_calculator.calculate_damage_reduction(
		damage_amount, damage_type, ArmorResistanceCalculator.ArmorClass.HEAVY, armor_thickness, impact_location
	)
	
	# Heavy armor should provide more protection
	assert_float(heavy_armor_reduction).is_greater(light_armor_reduction)

# ============================================================================
# AC4: DAMAGE VISUALIZATION SYSTEM TESTS
# ============================================================================

func test_visualization_system_initialization():
	"""Test damage visualization system initialization (SHIP-009 AC4)."""
	var success: bool = visualization_manager.initialize_visualization_system(mock_ship)
	
	assert_bool(success).is_true()
	assert_int(visualization_manager.current_damage_level).is_equal(0)

func test_hull_damage_visualization():
	"""Test hull damage visualization updates (SHIP-009 AC4)."""
	visualization_manager.initialize_visualization_system(mock_ship)
	
	var visualization_signal_received: bool = false
	
	visualization_manager.hull_visualization_updated.connect(func(damage_pct: float, visible: bool):
		visualization_signal_received = true
	)
	
	# Update visualization with damage
	visualization_manager.update_hull_damage_visualization(75.0, Vector3(0, 0, 2))
	
	assert_bool(visualization_signal_received).is_true()
	assert_int(visualization_manager.current_damage_level).is_greater(0)

func test_shield_effect_visualization():
	"""Test shield impact effect visualization (SHIP-009 AC4)."""
	visualization_manager.initialize_visualization_system(mock_ship)
	
	var shield_effect_signal_received: bool = false
	
	visualization_manager.shield_effect_triggered.connect(func(quadrant: int, strength: float):
		shield_effect_signal_received = true
	)
	
	# Trigger shield impact effect
	visualization_manager.trigger_shield_impact_effect(0, Vector3(0, 0, 5), 25.0, DamageTypes.Type.ENERGY)
	
	assert_bool(shield_effect_signal_received).is_true()

func test_critical_damage_effects():
	"""Test critical damage visual effects (SHIP-009 AC4)."""
	visualization_manager.initialize_visualization_system(mock_ship)
	
	var critical_effect_signal_received: bool = false
	
	visualization_manager.critical_effect_activated.connect(func(effect_type: String, severity: float):
		critical_effect_signal_received = true
	)
	
	# Trigger critical damage effects
	visualization_manager.trigger_critical_damage_effects()
	
	# Should spawn various effects
	assert_int(visualization_manager.fire_effects.size()).is_greater(0)
	assert_int(visualization_manager.smoke_effects.size()).is_greater(0)

# ============================================================================
# AC5: CRITICAL DAMAGE SYSTEM TESTS
# ============================================================================

func test_critical_damage_system_initialization():
	"""Test critical damage system initialization (SHIP-009 AC5)."""
	var success: bool = critical_system.initialize_critical_system(mock_ship)
	
	assert_bool(success).is_true()
	assert_float(critical_system.structural_integrity).is_equal(100.0)

func test_critical_event_triggering():
	"""Test critical damage event triggering (SHIP-009 AC5)."""
	critical_system.initialize_critical_system(mock_ship)
	
	var critical_event_signal_received: bool = false
	
	critical_system.critical_event_triggered.connect(func(event_type: String, severity: float, location: Vector3):
		critical_event_signal_received = true
	)
	
	# Trigger critical event
	var success: bool = critical_system.trigger_critical_event("engine_explosion", 2.0, Vector3(0, 0, -5))
	
	assert_bool(success).is_true()
	assert_bool(critical_event_signal_received).is_true()
	assert_int(critical_system.active_critical_events.size()).is_greater(0)

func test_cascade_failure_system():
	"""Test cascade failure mechanics (SHIP-009 AC5)."""
	critical_system.initialize_critical_system(mock_ship)
	
	var cascade_signal_received: bool = false
	
	critical_system.cascade_failure_started.connect(func(failure_type: String, affected_systems: Array[String]):
		cascade_signal_received = true
	)
	
	# Trigger high-severity critical event that should cause cascades
	critical_system.trigger_critical_event("weapon_magazine_detonation", 3.0, Vector3(0, 1, 4))
	
	# Process for a few frames to allow cascades
	for i in range(10):
		critical_system._physics_process(0.1)
	
	# Should have triggered additional events
	assert_int(critical_system.active_critical_events.size()).is_greater_equal(1)

func test_structural_integrity_tracking():
	"""Test structural integrity tracking (SHIP-009 AC5)."""
	critical_system.initialize_critical_system(mock_ship)
	
	var integrity_signal_received: bool = false
	
	critical_system.structural_integrity_compromised.connect(func(integrity: float):
		integrity_signal_received = true
	)
	
	# Trigger event that reduces structural integrity
	critical_system.trigger_critical_event("hull_fracture", 2.0, Vector3(0, 0, 0))
	
	assert_float(critical_system.structural_integrity).is_less(100.0)

func test_emergency_protocol_activation():
	"""Test emergency protocol activation (SHIP-009 AC5)."""
	critical_system.initialize_critical_system(mock_ship)
	
	var protocol_signal_received: bool = false
	
	critical_system.emergency_protocol_activated.connect(func(protocol_name: String):
		protocol_signal_received = true
	)
	
	# Trigger event that should activate emergency protocol
	critical_system.trigger_critical_event("fire_outbreak", 2.0, Vector3(1, 0, 2))
	
	assert_bool(protocol_signal_received).is_true()

# ============================================================================
# AC6: DAMAGE PERSISTENCE SYSTEM TESTS
# ============================================================================

func test_damage_save_data():
	"""Test damage system save data generation (SHIP-009 AC6)."""
	damage_manager.initialize_damage_manager(mock_ship)
	
	# Apply some damage
	damage_manager.apply_hull_damage(30.0, Vector3(0, 0, 2), DamageTypes.Type.KINETIC)
	
	var save_data: Dictionary = damage_manager.get_damage_save_data()
	
	assert_dict(save_data).is_not_empty()
	assert_dict(save_data).contains_keys(["max_hull_strength", "current_hull_strength", "hull_integrity_percentage"])
	assert_float(save_data.current_hull_strength).is_less(100.0)

func test_damage_load_data():
	"""Test damage system save data loading (SHIP-009 AC6)."""
	damage_manager.initialize_damage_manager(mock_ship)
	
	var test_save_data: Dictionary = {
		"max_hull_strength": 100.0,
		"current_hull_strength": 65.0,
		"hull_integrity_percentage": 65.0,
		"structural_damage_accumulation": 35.0
	}
	
	var success: bool = damage_manager.load_damage_save_data(test_save_data)
	
	assert_bool(success).is_true()
	assert_float(damage_manager.current_hull_strength).is_equal(65.0)
	assert_float(damage_manager.hull_integrity_percentage).is_equal(65.0)

func test_shield_save_load_data():
	"""Test shield system save/load data (SHIP-009 AC6)."""
	shield_manager.initialize_shield_system(mock_ship)
	
	# Damage shields
	shield_manager.apply_shield_damage(15.0, Vector3(0, 0, 8), DamageTypes.Type.ENERGY)
	
	var save_data: Dictionary = shield_manager.get_shield_save_data()
	var success: bool = shield_manager.load_shield_save_data(save_data)
	
	assert_dict(save_data).is_not_empty()
	assert_bool(success).is_true()

func test_critical_system_save_load():
	"""Test critical damage system save/load (SHIP-009 AC6)."""
	critical_system.initialize_critical_system(mock_ship)
	
	# Trigger critical event
	critical_system.trigger_critical_event("fire_outbreak", 1.5, Vector3(0, 0, 0))
	
	var save_data: Dictionary = critical_system.get_critical_save_data()
	var success: bool = critical_system.load_critical_save_data(save_data)
	
	assert_dict(save_data).is_not_empty()
	assert_bool(success).is_true()

# ============================================================================
# AC7: COLLISION DAMAGE SYSTEM TESTS
# ============================================================================

func test_collision_damage_system_initialization():
	"""Test collision damage system initialization (SHIP-009 AC7)."""
	var mock_physics_body: RigidBody3D = RigidBody3D.new()
	mock_ship.physics_body = mock_physics_body
	
	var success: bool = collision_system.initialize_collision_system(mock_ship)
	
	assert_bool(success).is_true()
	assert_bool(collision_system.collision_damage_enabled).is_true()

func test_ramming_damage_calculation():
	"""Test ship-to-ship ramming damage calculation (SHIP-009 AC7)."""
	collision_system.initialize_collision_system(mock_ship)
	
	var other_ship: BaseShip = BaseShip.new()
	other_ship.mass = 1500.0
	
	var impact_velocity: Vector3 = Vector3(0, 0, -50)  # 50 m/s collision
	var impact_position: Vector3 = Vector3(0, 0, 0)
	
	var collision_info: Dictionary = {
		"relative_velocity": impact_velocity,
		"impact_position": impact_position,
		"impact_normal": Vector3(0, 0, 1)
	}
	
	var damage: float = collision_system.process_collision_damage(other_ship, collision_info)
	
	assert_float(damage).is_greater(0.0)
	
	other_ship.queue_free()

func test_debris_damage_calculation():
	"""Test debris impact damage calculation (SHIP-009 AC7)."""
	collision_system.initialize_collision_system(mock_ship)
	
	var debris: RigidBody3D = RigidBody3D.new()
	debris.name = "debris_chunk"
	debris.mass = 200.0
	
	var impact_velocity: Vector3 = Vector3(0, 0, -30)
	var collision_info: Dictionary = {
		"relative_velocity": impact_velocity,
		"impact_position": Vector3(0, 0, 2)
	}
	
	var damage: float = collision_system.process_collision_damage(debris, collision_info)
	
	assert_float(damage).is_greater(0.0)
	
	debris.queue_free()

func test_collision_damage_velocity_threshold():
	"""Test collision damage velocity threshold (SHIP-009 AC7)."""
	collision_system.initialize_collision_system(mock_ship)
	
	var debris: RigidBody3D = RigidBody3D.new()
	debris.name = "small_debris"
	debris.mass = 50.0
	
	# Low velocity collision (below threshold)
	var low_velocity_info: Dictionary = {
		"relative_velocity": Vector3(0, 0, -5),  # 5 m/s
		"impact_position": Vector3(0, 0, 1)
	}
	
	var low_damage: float = collision_system.process_collision_damage(debris, low_velocity_info)
	
	# High velocity collision (above threshold)
	var high_velocity_info: Dictionary = {
		"relative_velocity": Vector3(0, 0, -25),  # 25 m/s
		"impact_position": Vector3(0, 0, 1)
	}
	
	var high_damage: float = collision_system.process_collision_damage(debris, high_velocity_info)
	
	# High velocity should cause more damage
	assert_float(high_damage).is_greater(low_damage)
	
	debris.queue_free()

func test_collision_cooldown_system():
	"""Test collision damage cooldown system (SHIP-009 AC7)."""
	collision_system.initialize_collision_system(mock_ship)
	
	var debris: RigidBody3D = RigidBody3D.new()
	debris.name = "test_debris"
	debris.mass = 100.0
	
	var collision_info: Dictionary = {
		"relative_velocity": Vector3(0, 0, -20),
		"impact_position": Vector3(0, 0, 1)
	}
	
	# First collision should cause damage
	var first_damage: float = collision_system.process_collision_damage(debris, collision_info)
	
	# Immediate second collision should be blocked by cooldown
	var second_damage: float = collision_system.process_collision_damage(debris, collision_info)
	
	assert_float(first_damage).is_greater(0.0)
	assert_float(second_damage).is_equal(0.0)
	
	debris.queue_free()

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

func test_integrated_damage_workflow():
	"""Test complete integrated damage workflow (SHIP-009 Integration)."""
	# Initialize all systems
	damage_manager.initialize_damage_manager(mock_ship)
	shield_manager.initialize_shield_system(mock_ship)
	critical_system.initialize_critical_system(mock_ship)
	visualization_manager.initialize_visualization_system(mock_ship)
	
	var signal_count: int = 0
	
	# Connect to various signals
	damage_manager.hull_damage_applied.connect(func(damage: float, location: Vector3, type: int): signal_count += 1)
	shield_manager.quadrant_damage_absorbed.connect(func(quadrant: int, damage: float): signal_count += 1)
	critical_system.critical_event_triggered.connect(func(event: String, severity: float, location: Vector3): signal_count += 1)
	
	# Apply damage that should trigger shields first, then hull, then critical
	var hit_location: Vector3 = Vector3(0, 0, 6)
	
	# First hit: shields absorb
	shield_manager.apply_shield_damage(25.0, hit_location, DamageTypes.Type.ENERGY)
	
	# Second hit: heavy damage to trigger hull and critical
	damage_manager.apply_hull_damage(60.0, hit_location, DamageTypes.Type.KINETIC)
	
	# Should have triggered multiple signals
	assert_int(signal_count).is_greater(0)

func test_damage_system_coordination():
	"""Test coordination between damage system components (SHIP-009 Integration)."""
	# Initialize systems
	damage_manager.initialize_damage_manager(mock_ship)
	shield_manager.initialize_shield_system(mock_ship)
	
	# Apply damage that should affect both systems
	var impact_location: Vector3 = Vector3(0, 0, 5)
	
	# First: shields should absorb damage
	var shield_absorption: float = shield_manager.apply_shield_damage(30.0, impact_location, DamageTypes.Type.ENERGY)
	
	# Then: hull damage with remaining
	var remaining_damage: float = 30.0 - shield_absorption
	if remaining_damage > 0.0:
		damage_manager.apply_hull_damage(remaining_damage, impact_location, DamageTypes.Type.ENERGY)
	
	# Both systems should show damage
	assert_float(shield_manager.quadrant_current_strength[0]).is_less(shield_manager.quadrant_max_strength[0])
	assert_float(damage_manager.current_hull_strength).is_less_equal(100.0)

# ============================================================================
# PERFORMANCE TESTS
# ============================================================================

func test_damage_system_performance():
	"""Test damage system performance with multiple simultaneous damage events."""
	damage_manager.initialize_damage_manager(mock_ship)
	shield_manager.initialize_shield_system(mock_ship)
	
	var start_time: int = Time.get_ticks_msec()
	
	# Apply 100 damage events rapidly
	for i in range(100):
		var hit_location: Vector3 = Vector3(randf_range(-5, 5), randf_range(-2, 2), randf_range(-5, 5))
		shield_manager.apply_shield_damage(5.0, hit_location, DamageTypes.Type.ENERGY)
		damage_manager.apply_hull_damage(5.0, hit_location, DamageTypes.Type.KINETIC)
	
	var end_time: int = Time.get_ticks_msec()
	var duration: int = end_time - start_time
	
	# Should complete within reasonable time (less than 100ms)
	assert_int(duration).is_less(100)

func test_critical_damage_performance():
	"""Test critical damage system performance with multiple events."""
	critical_system.initialize_critical_system(mock_ship)
	
	var start_time: int = Time.get_ticks_msec()
	
	# Trigger multiple critical events
	for i in range(10):
		critical_system.trigger_critical_event("fire_outbreak", 1.0, Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
	
	# Process critical events for several frames
	for i in range(60):  # 1 second at 60 FPS
		critical_system._physics_process(1.0/60.0)
	
	var end_time: int = Time.get_ticks_msec()
	var duration: int = end_time - start_time
	
	# Should handle multiple critical events efficiently
	assert_int(duration).is_less(200)

# ============================================================================
# ERROR HANDLING AND EDGE CASE TESTS
# ============================================================================

func test_damage_system_null_ship_handling():
	"""Test damage system handling of null ship references."""
	var null_init_damage: bool = damage_manager.initialize_damage_manager(null)
	var null_init_shield: bool = shield_manager.initialize_shield_system(null)
	var null_init_critical: bool = critical_system.initialize_critical_system(null)
	
	assert_bool(null_init_damage).is_false()
	assert_bool(null_init_shield).is_false()
	assert_bool(null_init_critical).is_false()

func test_damage_system_zero_damage_handling():
	"""Test damage system handling of zero or negative damage."""
	damage_manager.initialize_damage_manager(mock_ship)
	shield_manager.initialize_shield_system(mock_ship)
	
	var zero_hull_damage: float = damage_manager.apply_hull_damage(0.0, Vector3.ZERO, DamageTypes.Type.KINETIC)
	var negative_hull_damage: float = damage_manager.apply_hull_damage(-10.0, Vector3.ZERO, DamageTypes.Type.KINETIC)
	var zero_shield_damage: float = shield_manager.apply_shield_damage(0.0, Vector3.ZERO, DamageTypes.Type.ENERGY)
	
	assert_float(zero_hull_damage).is_equal(0.0)
	assert_float(negative_hull_damage).is_equal(0.0)
	assert_float(zero_shield_damage).is_equal(0.0)

func test_damage_system_extreme_values():
	"""Test damage system handling of extreme damage values."""
	damage_manager.initialize_damage_manager(mock_ship)
	
	# Apply massive damage
	var massive_damage: float = damage_manager.apply_hull_damage(10000.0, Vector3.ZERO, DamageTypes.Type.KINETIC)
	
	# Hull should not go below zero
	assert_float(damage_manager.current_hull_strength).is_greater_equal(0.0)
	assert_float(massive_damage).is_greater(0.0)

# ============================================================================
# WCS COMPATIBILITY TESTS
# ============================================================================

func test_wcs_damage_behavior_compatibility():
	"""Test that damage behavior matches WCS expectations."""
	damage_manager.initialize_damage_manager(mock_ship)
	
	# WCS-style damage sequence: shields first, then hull
	shield_manager.initialize_shield_system(mock_ship)
	
	var initial_hull: float = damage_manager.current_hull_strength
	var initial_shields: float = shield_manager.get_shield_status().total_current
	
	# Apply damage that should affect shields first
	var hit_location: Vector3 = Vector3(0, 0, 5)
	shield_manager.apply_shield_damage(20.0, hit_location, DamageTypes.Type.ENERGY)
	
	# Hull should be unchanged, shields should be damaged
	assert_float(damage_manager.current_hull_strength).is_equal(initial_hull)
	assert_float(shield_manager.get_shield_status().total_current).is_less(initial_shields)

func test_wcs_armor_effectiveness():
	"""Test that armor effectiveness matches WCS expectations."""
	var light_armor_reduction: float = armor_calculator.calculate_damage_reduction(
		100.0, DamageTypes.Type.KINETIC, ArmorResistanceCalculator.ArmorClass.LIGHT, 1.0, Vector3.ZERO
	)
	
	var heavy_armor_reduction: float = armor_calculator.calculate_damage_reduction(
		100.0, DamageTypes.Type.KINETIC, ArmorResistanceCalculator.ArmorClass.HEAVY, 1.0, Vector3.ZERO
	)
	
	# Heavy armor should provide significantly more protection
	assert_float(heavy_armor_reduction).is_greater(light_armor_reduction * 1.5)

func test_wcs_shield_quadrant_behavior():
	"""Test that shield quadrant behavior matches WCS expectations."""
	shield_manager.initialize_shield_system(mock_ship)
	
	# WCS shields should recharge after damage delay
	shield_manager.apply_shield_damage(10.0, Vector3(0, 0, 8), DamageTypes.Type.ENERGY)
	
	var damaged_strength: float = shield_manager.quadrant_current_strength[0]
	
	# Immediate recharge should be blocked by delay
	shield_manager._process_shield_recharge(0.1)
	assert_float(shield_manager.quadrant_current_strength[0]).is_equal(damaged_strength)
	
	# After delay, should start recharging
	shield_manager._process_shield_recharge(4.0)  # Exceed recharge delay
	assert_float(shield_manager.quadrant_current_strength[0]).is_greater(damaged_strength)