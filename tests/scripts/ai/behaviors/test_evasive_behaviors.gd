extends GdUnitTestSuite

## Unit tests for evasive behavior system components

var test_scene: Node3D
var ai_agent: Node
var test_ship: Node3D
var mock_threat: Node3D
var threat_evasion_system: ThreatEvasionSystem
var defensive_coordination: DefensiveCoordinationSystem
var defensive_systems_integration: DefensiveSystemsIntegration

func before_test() -> void:
	_setup_test_environment()

func after_test() -> void:
	_cleanup_test_environment()

# Missile Evasion Tests

func test_evade_missile_action_creation() -> void:
	"""Test missile evasion action creation and setup"""
	var evade_action: EvadeMissileAction = EvadeMissileAction.new()
	evade_action.ai_agent = ai_agent
	evade_action.ship_controller = _create_mock_ship_controller()
	evade_action.missile_threat = mock_threat
	evade_action._setup()
	
	assert_object(evade_action).is_not_null()
	assert_int(evade_action.evasion_duration).is_greater(0)
	assert_object(evade_action.missile_threat).is_equal(mock_threat)

func test_missile_type_analysis() -> void:
	"""Test missile type classification"""
	var evade_action: EvadeMissileAction = EvadeMissileAction.new()
	evade_action.ai_agent = ai_agent
	evade_action.missile_threat = mock_threat
	
	# Test heat-seeking missile detection
	mock_threat.set_meta("missile_type", "heat_seeking")
	evade_action._setup()
	evade_action._analyze_missile_threat()
	
	assert_int(evade_action.missile_type).is_equal(EvadeMissileAction.MissileType.HEAT_SEEKING)

func test_evasion_type_selection() -> void:
	"""Test optimal evasion type selection"""
	var evade_action: EvadeMissileAction = EvadeMissileAction.new()
	evade_action.ai_agent = ai_agent
	evade_action.missile_threat = mock_threat
	evade_action.auto_select_evasion = true
	
	# Test radar-guided missile evasion selection
	mock_threat.set_meta("missile_type", "radar_guided")
	evade_action._setup()
	
	var selected_evasion: EvadeMissileAction.EvasionType = evade_action._select_optimal_evasion()
	assert_that(selected_evasion).is_in([
		EvadeMissileAction.EvasionType.CHAFF_TURN,
		EvadeMissileAction.EvasionType.BARREL_ROLL
	])

func test_missile_evasion_execution() -> void:
	"""Test missile evasion execution"""
	var evade_action: EvadeMissileAction = EvadeMissileAction.new()
	evade_action.ai_agent = ai_agent
	evade_action.ship_controller = _create_mock_ship_controller()
	evade_action.missile_threat = mock_threat
	evade_action._setup()
	
	# Execute one step
	var result: int = evade_action.execute_wcs_action(0.1)
	assert_int(result).is_equal(2)  # RUNNING
	
	# Check that evasion started
	assert_float(evade_action.evasion_start_time).is_greater(0.0)

func test_countermeasure_deployment() -> void:
	"""Test countermeasure deployment logic"""
	var evade_action: EvadeMissileAction = EvadeMissileAction.new()
	evade_action.ai_agent = ai_agent
	evade_action.ship_controller = _create_mock_ship_controller()
	evade_action.missile_threat = mock_threat
	evade_action.missile_type = EvadeMissileAction.MissileType.RADAR_GUIDED
	evade_action.chaff_deployment = true
	
	# Position threat close enough for countermeasure deployment
	mock_threat.global_position = test_ship.global_position + Vector3(300, 0, 0)
	
	evade_action._check_and_deploy_countermeasures()
	
	# Should have deployed chaff
	assert_bool(evade_action.chaff_deployed).is_true()

# Corkscrew Evasion Tests

func test_corkscrew_evasion_creation() -> void:
	"""Test corkscrew evasion action creation"""
	var corkscrew_action: CorkscrewEvasionAction = CorkscrewEvasionAction.new()
	corkscrew_action.ai_agent = ai_agent
	corkscrew_action.ship_controller = _create_mock_ship_controller()
	corkscrew_action._setup()
	
	assert_object(corkscrew_action).is_not_null()
	assert_float(corkscrew_action.duration).is_greater(0.0)
	assert_float(corkscrew_action.spiral_radius).is_greater(0.0)

func test_corkscrew_pattern_selection() -> void:
	"""Test corkscrew pattern selection logic"""
	var corkscrew_action: CorkscrewEvasionAction = CorkscrewEvasionAction.new()
	corkscrew_action.threat_source = mock_threat
	corkscrew_action.auto_pattern_selection = true
	
	# Test close threat scenario
	mock_threat.global_position = test_ship.global_position + Vector3(300, 0, 0)
	corkscrew_action._setup()
	
	var selected_pattern: CorkscrewEvasionAction.CorkscrewPattern = corkscrew_action._select_optimal_pattern()
	assert_int(selected_pattern).is_equal(CorkscrewEvasionAction.CorkscrewPattern.TIGHT_SPIRAL)

func test_corkscrew_axes_initialization() -> void:
	"""Test corkscrew coordinate system initialization"""
	var corkscrew_action: CorkscrewEvasionAction = CorkscrewEvasionAction.new()
	corkscrew_action.threat_source = mock_threat
	corkscrew_action._setup()
	
	assert_that(corkscrew_action.corkscrew_axis.length()).is_greater(0.9)
	assert_that(corkscrew_action.perpendicular_axis_1.length()).is_greater(0.9)
	assert_that(corkscrew_action.perpendicular_axis_2.length()).is_greater(0.9)

func test_corkscrew_execution() -> void:
	"""Test corkscrew pattern execution"""
	var corkscrew_action: CorkscrewEvasionAction = CorkscrewEvasionAction.new()
	corkscrew_action.ai_agent = ai_agent
	corkscrew_action.ship_controller = _create_mock_ship_controller()
	corkscrew_action._setup()
	
	var result: int = corkscrew_action.execute_wcs_action(0.1)
	assert_int(result).is_equal(2)  # RUNNING
	
	# Check pattern started
	assert_float(corkscrew_action.pattern_start_time).is_greater(0.0)

# Jink Pattern Tests

func test_jink_pattern_creation() -> void:
	"""Test jink pattern action creation"""
	var jink_action: JinkPatternAction = JinkPatternAction.new()
	jink_action.ai_agent = ai_agent
	jink_action.ship_controller = _create_mock_ship_controller()
	jink_action._setup()
	
	assert_object(jink_action).is_not_null()
	assert_float(jink_action.jink_duration).is_greater(0.0)
	assert_float(jink_action.change_frequency).is_greater(0.0)

func test_jink_direction_generation() -> void:
	"""Test jink direction generation for different patterns"""
	var jink_action: JinkPatternAction = JinkPatternAction.new()
	jink_action.jink_type = JinkPatternAction.JinkType.RANDOM_WALK
	jink_action._setup()
	
	var random_direction: Vector3 = jink_action._generate_random_direction()
	assert_float(random_direction.length()).is_greater(0.0)
	
	jink_action.jink_type = JinkPatternAction.JinkType.SERPENTINE
	var serpentine_direction: Vector3 = jink_action._generate_serpentine_direction()
	assert_float(serpentine_direction.length()).is_greater(0.0)

func test_jink_execution_and_direction_changes() -> void:
	"""Test jink pattern execution and direction changes"""
	var jink_action: JinkPatternAction = JinkPatternAction.new()
	jink_action.ai_agent = ai_agent
	jink_action.ship_controller = _create_mock_ship_controller()
	jink_action.change_frequency = 0.1  # Very fast changes for testing
	jink_action._setup()
	
	# Execute multiple steps to trigger direction changes
	for i in range(5):
		var result: int = jink_action.execute_wcs_action(0.15)
		assert_int(result).is_equal(2)  # RUNNING
	
	# Should have made at least one direction change
	assert_int(jink_action.direction_change_count).is_greater(0)

func test_jink_unpredictability_calculation() -> void:
	"""Test jink unpredictability factor calculation"""
	var jink_action: JinkPatternAction = JinkPatternAction.new()
	jink_action._setup()
	
	# Add some position history
	jink_action.previous_positions.append(Vector3(0, 0, 0))
	jink_action.previous_positions.append(Vector3(100, 0, 100))
	jink_action.previous_positions.append(Vector3(50, 0, 200))
	jink_action.previous_positions.append(Vector3(150, 0, 150))
	
	jink_action._calculate_unpredictability()
	
	assert_float(jink_action.unpredictability_factor).is_between(0.0, 1.0)

# Emergency Behavior Tests

func test_emergency_behavior_trigger_analysis() -> void:
	"""Test emergency behavior trigger analysis"""
	var emergency_action: EmergencyBehaviorAction = EmergencyBehaviorAction.new()
	emergency_action.ai_agent = ai_agent
	emergency_action.damage_threshold = 0.6
	
	# Mock high damage level
	ai_agent.set_meta("damage_level", 0.8)
	emergency_action._setup()
	
	assert_int(emergency_action.emergency_type).is_equal(EmergencyBehaviorAction.EmergencyType.CRITICAL_DAMAGE)

func test_emergency_response_selection() -> void:
	"""Test emergency response selection logic"""
	var emergency_action: EmergencyBehaviorAction = EmergencyBehaviorAction.new()
	emergency_action.emergency_type = EmergencyBehaviorAction.EmergencyType.CRITICAL_DAMAGE
	emergency_action._setup()
	
	var response: EmergencyBehaviorAction.EmergencyResponse = emergency_action._select_emergency_response()
	assert_that(response).is_in([
		EmergencyBehaviorAction.EmergencyResponse.IMMEDIATE_RETREAT,
		EmergencyBehaviorAction.EmergencyResponse.DAMAGE_CONTROL
	])

func test_emergency_priority_calculation() -> void:
	"""Test emergency priority calculation"""
	var emergency_action: EmergencyBehaviorAction = EmergencyBehaviorAction.new()
	emergency_action.emergency_type = EmergencyBehaviorAction.EmergencyType.LIFE_SUPPORT_FAILURE
	emergency_action._setup()
	
	var priority: float = emergency_action._calculate_emergency_priority()
	assert_float(priority).is_greater(0.8)  # Life support failure should be high priority

func test_system_failure_detection() -> void:
	"""Test system failure detection"""
	var emergency_action: EmergencyBehaviorAction = EmergencyBehaviorAction.new()
	emergency_action.ai_agent = ai_agent
	
	# Mock system status
	emergency_action.ship_status = {
		"engine_status": 0.2,  # Failed engines
		"weapon_systems": 0.05  # Failed weapons
	}
	
	emergency_action._check_system_failures()
	
	assert_that(emergency_action.system_failures).contains("engines")
	assert_that(emergency_action.system_failures).contains("weapons")

# Threat Evasion System Tests

func test_threat_evasion_system_initialization() -> void:
	"""Test threat evasion system initialization"""
	threat_evasion_system = ThreatEvasionSystem.new()
	threat_evasion_system._ready()
	
	assert_object(threat_evasion_system).is_not_null()
	assert_that(threat_evasion_system.threat_prioritization).is_not_empty()

func test_threat_type_analysis() -> void:
	"""Test threat type analysis"""
	threat_evasion_system = ThreatEvasionSystem.new()
	threat_evasion_system._ready()
	
	# Test laser threat
	mock_threat.set_meta("weapon_type", "laser")
	var threat_type: ThreatEvasionSystem.ThreatType = threat_evasion_system._analyze_threat_type(mock_threat, {})
	
	assert_int(threat_type).is_equal(ThreatEvasionSystem.ThreatType.LASER_FIRE)

func test_threat_registration_and_analysis() -> void:
	"""Test threat registration and analysis"""
	threat_evasion_system = ThreatEvasionSystem.new()
	ai_agent.add_child(threat_evasion_system)
	threat_evasion_system._ready()
	
	# Register a high-urgency threat
	var threat_metadata: Dictionary = {
		"threat_type": "missile",
		"urgency": 0.8
	}
	
	threat_evasion_system.register_threat(mock_threat, threat_metadata)
	
	assert_that(threat_evasion_system.active_threats).is_not_empty()

func test_evasion_response_selection() -> void:
	"""Test evasion response selection for different threat types"""
	threat_evasion_system = ThreatEvasionSystem.new()
	threat_evasion_system._ready()
	
	var threat_info: Dictionary = {
		"threat_type": ThreatEvasionSystem.ThreatType.MISSILE,
		"urgency": 0.8,
		"distance": 500.0
	}
	
	var response: ThreatEvasionSystem.EvasionResponse = threat_evasion_system._select_evasion_response(threat_info)
	assert_int(response).is_equal(ThreatEvasionSystem.EvasionResponse.MISSILE_BREAK)

func test_threat_urgency_calculation() -> void:
	"""Test threat urgency calculation"""
	threat_evasion_system = ThreatEvasionSystem.new()
	threat_evasion_system._ready()
	
	var threat_info: Dictionary = {
		"threat_type": ThreatEvasionSystem.ThreatType.TORPEDO,
		"distance": 300.0,
		"time_to_impact": 2.0,
		"threat_node": mock_threat
	}
	
	var urgency: float = threat_evasion_system._calculate_threat_urgency(threat_info)
	assert_float(urgency).is_greater(0.7)  # Close torpedo should be high urgency

# Defensive Coordination Tests

func test_defensive_coordination_initialization() -> void:
	"""Test defensive coordination system initialization"""
	defensive_coordination = DefensiveCoordinationSystem.new()
	defensive_coordination._ready()
	
	assert_object(defensive_coordination).is_not_null()
	assert_that(defensive_coordination.coordinated_ships).is_empty()

func test_ship_registration_and_coordination() -> void:
	"""Test ship registration and coordination establishment"""
	defensive_coordination = DefensiveCoordinationSystem.new()
	defensive_coordination._ready()
	
	var ship1: Node3D = _create_test_ship("Ship1", Vector3(0, 0, 0))
	var ship2: Node3D = _create_test_ship("Ship2", Vector3(200, 0, 0))
	
	defensive_coordination.register_ship(ship1)
	defensive_coordination.register_ship(ship2)
	
	assert_int(defensive_coordination.coordinated_ships.size()).is_equal(2)
	assert_that(defensive_coordination.defensive_positions).has_key(ship1)
	assert_that(defensive_coordination.defensive_positions).has_key(ship2)

func test_defensive_position_assignment() -> void:
	"""Test defensive position assignment for different coordination modes"""
	defensive_coordination = DefensiveCoordinationSystem.new()
	defensive_coordination._ready()
	defensive_coordination.coordination_mode = DefensiveCoordinationSystem.CoordinationMode.MUTUAL_DEFENSE
	
	var ships: Array[Node3D] = []
	for i in range(4):
		var ship: Node3D = _create_test_ship("Ship" + str(i), Vector3(i * 100, 0, 0))
		ships.append(ship)
		defensive_coordination.register_ship(ship)
	
	defensive_coordination._assign_mutual_defense_positions()
	
	# Check that all ships have assigned positions
	for ship in ships:
		assert_that(defensive_coordination.defensive_positions).has_key(ship)
		var position: Vector3 = defensive_coordination.defensive_positions[ship]
		assert_float(position.distance_to(Vector3.ZERO)).is_greater(0.0)

func test_mutual_support_request() -> void:
	"""Test mutual support request system"""
	defensive_coordination = DefensiveCoordinationSystem.new()
	defensive_coordination._ready()
	defensive_coordination.mutual_support_enabled = true
	
	var requester: Node3D = _create_test_ship("Requester", Vector3(0, 0, 0))
	var supporter: Node3D = _create_test_ship("Supporter", Vector3(300, 0, 0))
	
	defensive_coordination.register_ship(requester)
	defensive_coordination.register_ship(supporter)
	
	defensive_coordination.request_mutual_support(requester, mock_threat, 0.8)
	
	assert_that(defensive_coordination.mutual_support_requests).is_not_empty()

func test_formation_integrity_calculation() -> void:
	"""Test formation integrity calculation"""
	defensive_coordination = DefensiveCoordinationSystem.new()
	defensive_coordination._ready()
	
	var ship1: Node3D = _create_test_ship("Ship1", Vector3(0, 0, 0))
	var ship2: Node3D = _create_test_ship("Ship2", Vector3(100, 0, 0))
	
	defensive_coordination.register_ship(ship1)
	defensive_coordination.register_ship(ship2)
	
	# Set assigned positions close to current positions
	defensive_coordination.defensive_positions[ship1] = Vector3(0, 0, 0)
	defensive_coordination.defensive_positions[ship2] = Vector3(100, 0, 0)
	
	defensive_coordination._update_formation_integrity()
	
	assert_float(defensive_coordination.formation_integrity).is_greater(0.8)

# Defensive Systems Integration Tests

func test_defensive_systems_integration_initialization() -> void:
	"""Test defensive systems integration initialization"""
	defensive_systems_integration = DefensiveSystemsIntegration.new()
	defensive_systems_integration._ready()
	
	assert_object(defensive_systems_integration).is_not_null()
	assert_that(defensive_systems_integration.power_distribution).is_not_empty()
	assert_that(defensive_systems_integration.shield_facing_distribution).is_not_empty()

func test_power_mode_configuration() -> void:
	"""Test power mode configuration for different maneuvers"""
	defensive_systems_integration = DefensiveSystemsIntegration.new()
	defensive_systems_integration._ready()
	defensive_systems_integration.auto_power_management = true
	
	defensive_systems_integration._configure_for_missile_evasion()
	
	assert_int(defensive_systems_integration.current_power_mode).is_equal(DefensiveSystemsIntegration.PowerMode.ENGINES_PRIORITY)
	assert_float(defensive_systems_integration.power_distribution.get("engines", 0.0)).is_greater(0.4)

func test_shield_configuration_adjustment() -> void:
	"""Test shield configuration adjustment for threat direction"""
	defensive_systems_integration = DefensiveSystemsIntegration.new()
	defensive_systems_integration._ready()
	defensive_systems_integration.auto_shield_configuration = true
	
	# Test front threat
	var front_threat: Vector3 = Vector3(0, 0, 1)  # Front direction
	defensive_systems_integration._adjust_shields_for_threat_direction(front_threat)
	
	assert_int(defensive_systems_integration.current_shield_config).is_equal(DefensiveSystemsIntegration.ShieldConfiguration.FRONT_HEAVY)

func test_emergency_power_activation() -> void:
	"""Test emergency power mode activation"""
	defensive_systems_integration = DefensiveSystemsIntegration.new()
	defensive_systems_integration._ready()
	
	defensive_systems_integration._configure_for_emergency_behavior()
	
	assert_int(defensive_systems_integration.current_power_mode).is_equal(DefensiveSystemsIntegration.PowerMode.EMERGENCY_SURVIVAL)
	assert_bool(defensive_systems_integration.emergency_mode_active).is_true()

func test_adaptive_shield_distribution() -> void:
	"""Test adaptive shield distribution calculation"""
	defensive_systems_integration = DefensiveSystemsIntegration.new()
	ai_agent.add_child(defensive_systems_integration)
	defensive_systems_integration._ready()
	
	# Mock threat detection
	ai_agent.set_meta("mock_threats", [mock_threat])
	
	defensive_systems_integration._set_shield_configuration(DefensiveSystemsIntegration.ShieldConfiguration.ADAPTIVE)
	
	assert_that(defensive_systems_integration.shield_facing_distribution).has_keys(["front", "rear", "left", "right"])

# Tactical Retreat Tests

func test_tactical_retreat_creation() -> void:
	"""Test tactical retreat action creation"""
	var retreat_action: TacticalRetreatAction = TacticalRetreatAction.new()
	retreat_action.ai_agent = ai_agent
	retreat_action.ship_controller = _create_mock_ship_controller()
	retreat_action._setup()
	
	assert_object(retreat_action).is_not_null()
	assert_float(retreat_action.retreat_duration).is_greater(0.0)

func test_retreat_trigger_analysis() -> void:
	"""Test retreat trigger analysis"""
	var retreat_action: TacticalRetreatAction = TacticalRetreatAction.new()
	retreat_action.ai_agent = ai_agent
	retreat_action.damage_retreat_threshold = 0.6
	
	# Mock high damage
	ai_agent.set_meta("damage_level", 0.8)
	retreat_action._setup()
	
	assert_int(retreat_action.retreat_trigger).is_equal(TacticalRetreatAction.RetreatTrigger.DAMAGE_THRESHOLD)

func test_retreat_type_selection() -> void:
	"""Test retreat type selection based on conditions"""
	var retreat_action: TacticalRetreatAction = TacticalRetreatAction.new()
	retreat_action.auto_retreat_selection = true
	retreat_action.retreat_trigger = TacticalRetreatAction.RetreatTrigger.CRITICAL_DAMAGE
	
	# Mock severe damage
	ai_agent.set_meta("damage_level", 0.9)
	retreat_action._setup()
	
	var retreat_type: TacticalRetreatAction.RetreatType = retreat_action._select_optimal_retreat_type()
	assert_int(retreat_type).is_equal(TacticalRetreatAction.RetreatType.EMERGENCY_ESCAPE)

func test_retreat_destination_calculation() -> void:
	"""Test retreat destination calculation"""
	var retreat_action: TacticalRetreatAction = TacticalRetreatAction.new()
	retreat_action.ai_agent = ai_agent
	retreat_action._setup()
	
	retreat_action._calculate_retreat_destination()
	
	assert_that(retreat_action.retreat_destination).is_not_equal(Vector3.ZERO)

func test_retreat_route_calculation() -> void:
	"""Test retreat route calculation with waypoints"""
	var retreat_action: TacticalRetreatAction = TacticalRetreatAction.new()
	retreat_action.ai_agent = ai_agent
	retreat_action.retreat_destination = Vector3(3000, 0, 0)
	retreat_action._setup()
	
	retreat_action._calculate_retreat_route()
	
	assert_that(retreat_action.retreat_route).is_not_empty()

# Integration Tests

func test_evasion_system_integration() -> void:
	"""Test integration between different evasion systems"""
	var evade_action: EvadeMissileAction = EvadeMissileAction.new()
	evade_action.ai_agent = ai_agent
	evade_action.ship_controller = _create_mock_ship_controller()
	evade_action.missile_threat = mock_threat
	
	defensive_systems_integration = DefensiveSystemsIntegration.new()
	ai_agent.add_child(defensive_systems_integration)
	defensive_systems_integration._ready()
	
	# Test integration
	defensive_systems_integration.integrate_with_evasive_maneuver("missile_evasion", Vector3(0, 0, 1))
	
	assert_int(defensive_systems_integration.current_power_mode).is_equal(DefensiveSystemsIntegration.PowerMode.ENGINES_PRIORITY)

func test_coordinated_evasion_scenario() -> void:
	"""Test coordinated evasion scenario with multiple ships"""
	defensive_coordination = DefensiveCoordinationSystem.new()
	defensive_coordination._ready()
	
	var ships: Array[Node3D] = []
	for i in range(3):
		var ship: Node3D = _create_test_ship("Ship" + str(i), Vector3(i * 200, 0, 0))
		ships.append(ship)
		defensive_coordination.register_ship(ship)
	
	# Simulate threat to one ship
	defensive_coordination.request_mutual_support(ships[0], mock_threat, 0.8)
	defensive_coordination._update_coordination()
	
	assert_that(defensive_coordination.mutual_support_requests).is_not_empty()

# Helper Methods

func _setup_test_environment() -> void:
	# Create main test scene
	test_scene = Node3D.new()
	test_scene.name = "EvasiveTestScene"
	add_child(test_scene)
	
	# Create mock AI agent
	ai_agent = Node3D.new()
	ai_agent.name = "MockAIAgent"
	ai_agent.position = Vector3.ZERO
	test_scene.add_child(ai_agent)
	
	# Create test ship
	test_ship = Node3D.new()
	test_ship.name = "TestShip"
	test_ship.position = Vector3.ZERO
	test_scene.add_child(test_ship)
	
	# Create mock threat
	mock_threat = Node3D.new()
	mock_threat.name = "MockThreat"
	mock_threat.position = Vector3(500, 0, 0)
	test_scene.add_child(mock_threat)

func _cleanup_test_environment() -> void:
	if test_scene:
		test_scene.queue_free()

func _create_mock_ship_controller() -> Node:
	var controller: Node = Node.new()
	controller.name = "MockShipController"
	
	# Add mock methods via metadata
	controller.set_meta("has_fire_weapons", true)
	controller.set_meta("has_set_throttle", true)
	controller.set_meta("has_deploy_chaff", true)
	controller.set_meta("has_deploy_flares", true)
	controller.set_meta("has_engage_afterburners", true)
	
	return controller

func _create_test_ship(name: String, position: Vector3) -> Node3D:
	var ship: Node3D = Node3D.new()
	ship.name = name
	ship.position = position
	test_scene.add_child(ship)
	return ship