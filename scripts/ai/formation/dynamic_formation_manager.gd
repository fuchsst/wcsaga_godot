class_name DynamicFormationManager
extends Node

## Advanced formation management with dynamic formation changes and tactical adaptation.
## Handles complex formation types, smooth transitions, and multi-squadron coordination.

signal formation_transition_started(formation_id: String, old_type: int, new_type: int)
signal formation_transition_completed(formation_id: String, new_type: int, transition_time: float)
signal formation_adaptation_triggered(formation_id: String, trigger_reason: String, adaptation: Dictionary)
signal tactical_formation_selected(formation_id: String, formation_type: int, tactical_context: Dictionary)
signal multi_squadron_coordination_established(coordinator_id: String, squadrons: Array[String])
signal formation_effectiveness_updated(formation_id: String, effectiveness: float, factors: Dictionary)

## Advanced formation types for tactical situations
enum AdvancedFormationType {
	# Existing basic formations (0-6)
	DIAMOND = 0,
	VIC = 1,
	LINE_ABREAST = 2,
	COLUMN = 3,
	FINGER_FOUR = 4,
	WALL = 5,
	CUSTOM = 6,
	
	# Advanced tactical formations (7+)
	COMBAT_SPREAD,           ## Wide combat formation for engagement
	DEFENSIVE_CIRCLE,        ## Circular formation for all-around defense
	ESCORT_SCREEN,           ## Capital ship escort formation
	STRIKE_WEDGE,           ## Penetration formation for strike missions
	DEFENSIVE_LAYERS,        ## Multi-layer defensive formation
	PATROL_SWEEP,           ## Wide sweep formation for patrol/search
	MISSILE_SCREEN,         ## Anti-missile defensive formation
	PURSUIT_LINE,           ## High-speed pursuit formation
	BOMBER_ESCORT,          ## Specialized bomber protection formation
	CAPITAL_ASSAULT,        ## Large formation for capital ship attack
	RECON_DISPERSION,       ## Wide dispersal for reconnaissance
	EMERGENCY_SCATTER,      ## Rapid dispersal for emergency situations
	TACTICAL_ENVELOPMENT,   ## Encirclement formation for target isolation
	FLEET_BATTLE_LINE,      ## Large-scale fleet engagement formation
	MULTI_SQUADRON_GRID     ## Grid formation for multiple squadrons
}

## Formation transition types
enum TransitionType {
	IMMEDIATE,     ## Instant formation change (emergency)
	SMOOTH,        ## Gradual transition maintaining effectiveness
	STAGED,        ## Multi-phase transition with intermediate formations
	ADAPTIVE       ## Context-aware transition based on tactical situation
}

## Tactical situation assessment factors
enum TacticalFactor {
	THREAT_LEVEL,
	TERRAIN_DENSITY,
	MISSION_PHASE,
	DAMAGE_STATUS,
	ENERGY_LEVELS,
	ENEMY_FORMATION,
	FRIENDLY_SUPPORT,
	ENGAGEMENT_RANGE,
	MANEUVER_SPACE,
	TIME_PRESSURE
}

## Formation effectiveness factors
enum EffectivenessFactor {
	POSITIONING_ACCURACY,
	COVERAGE_OPTIMIZATION,
	TACTICAL_SYNERGY,
	COORDINATION_QUALITY,
	ADAPTATION_RESPONSIVENESS,
	COMBAT_READINESS,
	DEFENSIVE_STRENGTH,
	OFFENSIVE_POTENTIAL
}

## Dynamic formation information structure
class DynamicFormation extends RefCounted:
	var formation_id: String
	var current_type: AdvancedFormationType
	var target_type: AdvancedFormationType
	var base_formation: FormationManager.Formation
	var transition_state: TransitionState
	var adaptation_parameters: Dictionary = {}
	var tactical_context: Dictionary = {}
	var effectiveness_metrics: Dictionary = {}
	var damage_adaptations: Array[Dictionary] = []
	var custom_patterns: Array[Dictionary] = []
	var squadron_coordination: Dictionary = {}
	
	func _init(id: String, formation: FormationManager.Formation) -> void:
		formation_id = id
		base_formation = formation
		current_type = formation.formation_type as AdvancedFormationType
		target_type = current_type
		transition_state = TransitionState.new()
		_initialize_adaptation_parameters()
		_initialize_effectiveness_metrics()
	
	func _initialize_adaptation_parameters() -> void:
		adaptation_parameters = {
			"threat_sensitivity": 0.7,
			"damage_adaptation_threshold": 0.3,
			"terrain_awareness": 0.8,
			"mission_priority_weight": 1.0,
			"energy_conservation": 0.5,
			"coordination_tolerance": 0.8
		}
	
	func _initialize_effectiveness_metrics() -> void:
		effectiveness_metrics = {
			"overall_effectiveness": 1.0,
			"positioning_score": 1.0,
			"coverage_score": 1.0,
			"tactical_advantage": 1.0,
			"coordination_quality": 1.0,
			"adaptation_success_rate": 1.0
		}

## Formation transition state tracking
class TransitionState extends RefCounted:
	var is_transitioning: bool = false
	var transition_type: TransitionType
	var start_time: float = 0.0
	var target_completion_time: float = 0.0
	var progress: float = 0.0
	var intermediate_positions: Array[Vector3] = []
	var ship_transition_states: Dictionary = {}
	var transition_effectiveness: float = 1.0
	
	func start_transition(t_type: TransitionType, duration: float) -> void:
		is_transitioning = true
		transition_type = t_type
		start_time = Time.get_time_from_start()
		target_completion_time = start_time + duration
		progress = 0.0
		ship_transition_states.clear()
	
	func update_progress() -> void:
		if not is_transitioning:
			return
		
		var current_time: float = Time.get_time_from_start()
		var elapsed: float = current_time - start_time
		var total_duration: float = target_completion_time - start_time
		
		if total_duration > 0.0:
			progress = clamp(elapsed / total_duration, 0.0, 1.0)
		else:
			progress = 1.0
	
	func complete_transition() -> void:
		is_transitioning = false
		progress = 1.0
		ship_transition_states.clear()

## Multi-squadron coordination structure
class SquadronCoordinator extends RefCounted:
	var coordinator_id: String
	var coordinated_squadrons: Array[String] = []
	var coordination_pattern: Dictionary = {}
	var overall_formation_type: AdvancedFormationType
	var squadron_roles: Dictionary = {}
	var coordination_effectiveness: float = 1.0
	
	func _init(id: String) -> void:
		coordinator_id = id

# Formation management
var formation_manager: FormationManager
var wing_coordination_manager: WingCoordinationManager
var dynamic_formations: Dictionary = {}
var squadron_coordinators: Dictionary = {}
var formation_templates: Dictionary = {}
var formation_transition_queue: Array[Dictionary] = []

# Tactical assessment
var tactical_analyzer: TacticalSituationAnalyzer
var effectiveness_calculator: FormationEffectivenessCalculator
var adaptation_engine: FormationAdaptationEngine

# Configuration
@export var transition_update_rate: float = 0.1  # 10 FPS for transition updates
@export var effectiveness_update_interval: float = 1.0  # Update effectiveness every second
@export var adaptation_check_interval: float = 2.0  # Check for adaptations every 2 seconds
@export var multi_squadron_coordination_range: float = 5000.0  # Range for squadron coordination

# Performance tracking
var formation_performance_stats: Dictionary = {}

func _ready() -> void:
	_initialize_dynamic_formation_system()
	_setup_formation_templates()
	_initialize_tactical_components()

func _initialize_dynamic_formation_system() -> void:
	# Get necessary systems
	formation_manager = get_node("/root/AIManager/FormationManager") as FormationManager
	wing_coordination_manager = get_node("/root/AIManager/WingCoordinationManager") as WingCoordinationManager
	
	# Initialize tactical components
	tactical_analyzer = TacticalSituationAnalyzer.new()
	add_child(tactical_analyzer)
	
	effectiveness_calculator = FormationEffectivenessCalculator.new()
	add_child(effectiveness_calculator)
	
	adaptation_engine = FormationAdaptationEngine.new()
	add_child(adaptation_engine)
	
	# Initialize performance tracking
	formation_performance_stats = {
		"formations_created": 0,
		"transitions_completed": 0,
		"adaptations_triggered": 0,
		"squadron_coordinations": 0,
		"average_effectiveness": 0.0,
		"transition_success_rate": 0.0
	}

func _setup_formation_templates() -> void:
	# Advanced formation templates with tactical parameters
	formation_templates[AdvancedFormationType.COMBAT_SPREAD] = {
		"name": "Combat Spread",
		"optimal_ship_count": 6,
		"spacing_multiplier": 1.5,
		"tactical_purpose": "engagement",
		"adaptation_priority": 0.8,
		"transition_difficulty": 0.6
	}
	
	formation_templates[AdvancedFormationType.DEFENSIVE_CIRCLE] = {
		"name": "Defensive Circle",
		"optimal_ship_count": 8,
		"spacing_multiplier": 1.2,
		"tactical_purpose": "defense",
		"adaptation_priority": 0.9,
		"transition_difficulty": 0.7
	}
	
	formation_templates[AdvancedFormationType.ESCORT_SCREEN] = {
		"name": "Escort Screen",
		"optimal_ship_count": 12,
		"spacing_multiplier": 2.0,
		"tactical_purpose": "escort",
		"adaptation_priority": 0.7,
		"transition_difficulty": 0.5
	}
	
	formation_templates[AdvancedFormationType.STRIKE_WEDGE] = {
		"name": "Strike Wedge",
		"optimal_ship_count": 5,
		"spacing_multiplier": 0.8,
		"tactical_purpose": "assault",
		"adaptation_priority": 0.9,
		"transition_difficulty": 0.8
	}
	
	formation_templates[AdvancedFormationType.DEFENSIVE_LAYERS] = {
		"name": "Defensive Layers",
		"optimal_ship_count": 15,
		"spacing_multiplier": 1.8,
		"tactical_purpose": "area_defense",
		"adaptation_priority": 0.6,
		"transition_difficulty": 0.9
	}
	
	formation_templates[AdvancedFormationType.PATROL_SWEEP] = {
		"name": "Patrol Sweep",
		"optimal_ship_count": 8,
		"spacing_multiplier": 3.0,
		"tactical_purpose": "patrol",
		"adaptation_priority": 0.5,
		"transition_difficulty": 0.4
	}
	
	formation_templates[AdvancedFormationType.MISSILE_SCREEN] = {
		"name": "Missile Screen",
		"optimal_ship_count": 10,
		"spacing_multiplier": 1.0,
		"tactical_purpose": "missile_defense",
		"adaptation_priority": 0.9,
		"transition_difficulty": 0.7
	}
	
	formation_templates[AdvancedFormationType.PURSUIT_LINE] = {
		"name": "Pursuit Line",
		"optimal_ship_count": 4,
		"spacing_multiplier": 0.6,
		"tactical_purpose": "pursuit",
		"adaptation_priority": 0.8,
		"transition_difficulty": 0.5
	}
	
	formation_templates[AdvancedFormationType.BOMBER_ESCORT] = {
		"name": "Bomber Escort",
		"optimal_ship_count": 6,
		"spacing_multiplier": 1.3,
		"tactical_purpose": "bomber_support",
		"adaptation_priority": 0.7,
		"transition_difficulty": 0.6
	}
	
	formation_templates[AdvancedFormationType.CAPITAL_ASSAULT] = {
		"name": "Capital Assault",
		"optimal_ship_count": 18,
		"spacing_multiplier": 1.0,
		"tactical_purpose": "capital_attack",
		"adaptation_priority": 0.9,
		"transition_difficulty": 1.0
	}

func _initialize_tactical_components() -> void:
	# Initialize tactical analyzer with parameters
	tactical_analyzer.initialize_analysis_parameters({
		"threat_assessment_range": 3000.0,
		"terrain_analysis_resolution": 100.0,
		"situation_update_frequency": 0.5,
		"tactical_factor_weights": _get_default_tactical_weights()
	})
	
	# Initialize effectiveness calculator
	effectiveness_calculator.initialize_calculation_parameters({
		"positioning_weight": 0.25,
		"coverage_weight": 0.20,
		"tactical_weight": 0.25,
		"coordination_weight": 0.20,
		"adaptation_weight": 0.10
	})
	
	# Initialize adaptation engine
	adaptation_engine.initialize_adaptation_parameters({
		"adaptation_threshold": 0.6,
		"emergency_threshold": 0.3,
		"transition_smoothness": 0.8,
		"learning_rate": 0.1
	})

func _get_default_tactical_weights() -> Dictionary:
	return {
		TacticalFactor.THREAT_LEVEL: 0.25,
		TacticalFactor.TERRAIN_DENSITY: 0.15,
		TacticalFactor.MISSION_PHASE: 0.20,
		TacticalFactor.DAMAGE_STATUS: 0.15,
		TacticalFactor.ENERGY_LEVELS: 0.10,
		TacticalFactor.ENEMY_FORMATION: 0.15
	}

func _process(delta: float) -> void:
	_update_formation_transitions(delta)
	_check_formation_adaptations()
	_update_effectiveness_metrics()
	_process_multi_squadron_coordination()

func _update_formation_transitions(delta: float) -> void:
	# Update all active formation transitions
	for formation_id in dynamic_formations:
		var dynamic_formation: DynamicFormation = dynamic_formations[formation_id]
		if dynamic_formation.transition_state.is_transitioning:
			_process_formation_transition(dynamic_formation, delta)

func _process_formation_transition(dynamic_formation: DynamicFormation, delta: float) -> void:
	var transition_state: TransitionState = dynamic_formation.transition_state
	transition_state.update_progress()
	
	# Calculate intermediate positions based on transition type
	match transition_state.transition_type:
		TransitionType.IMMEDIATE:
			_execute_immediate_transition(dynamic_formation)
		TransitionType.SMOOTH:
			_execute_smooth_transition(dynamic_formation, delta)
		TransitionType.STAGED:
			_execute_staged_transition(dynamic_formation, delta)
		TransitionType.ADAPTIVE:
			_execute_adaptive_transition(dynamic_formation, delta)
	
	# Check if transition is complete
	if transition_state.progress >= 1.0:
		_complete_formation_transition(dynamic_formation)

## Creates an advanced dynamic formation
func create_dynamic_formation(leader: Node3D, formation_type: AdvancedFormationType, spacing: float = 0.0, members: Array[Node3D] = []) -> String:
	# Create base formation through formation manager
	var base_formation_id: String = formation_manager.create_formation(
		leader, 
		formation_type as FormationManager.FormationType, 
		spacing
	)
	
	if base_formation_id.is_empty():
		return ""
	
	# Add members to base formation
	for member in members:
		formation_manager.add_ship_to_formation(base_formation_id, member)
	
	# Create dynamic formation wrapper
	var base_formation: FormationManager.Formation = formation_manager.get_formation(base_formation_id)
	var dynamic_formation: DynamicFormation = DynamicFormation.new(base_formation_id, base_formation)
	dynamic_formation.current_type = formation_type
	
	# Apply advanced formation pattern if beyond basic types
	if formation_type > AdvancedFormationType.CUSTOM:
		_apply_advanced_formation_pattern(dynamic_formation)
	
	dynamic_formations[base_formation_id] = dynamic_formation
	formation_performance_stats["formations_created"] += 1
	
	return base_formation_id

## Initiates a formation transition
func initiate_formation_transition(formation_id: String, new_formation_type: AdvancedFormationType, transition_type: TransitionType = TransitionType.SMOOTH) -> bool:
	if not dynamic_formations.has(formation_id):
		return false
	
	var dynamic_formation: DynamicFormation = dynamic_formations[formation_id]
	
	# Skip if already transitioning to this type
	if dynamic_formation.transition_state.is_transitioning and dynamic_formation.target_type == new_formation_type:
		return false
	
	var old_type: AdvancedFormationType = dynamic_formation.current_type
	dynamic_formation.target_type = new_formation_type
	
	# Calculate transition duration based on complexity
	var transition_duration: float = _calculate_transition_duration(old_type, new_formation_type, transition_type)
	
	# Start transition
	dynamic_formation.transition_state.start_transition(transition_type, transition_duration)
	
	formation_transition_started.emit(formation_id, old_type, new_formation_type)
	
	return true

func _calculate_transition_duration(old_type: AdvancedFormationType, new_type: AdvancedFormationType, transition_type: TransitionType) -> float:
	var base_duration: float = 5.0  # 5 seconds base
	
	# Get transition difficulty from templates
	var old_difficulty: float = formation_templates.get(old_type, {"transition_difficulty": 0.5}).get("transition_difficulty", 0.5)
	var new_difficulty: float = formation_templates.get(new_type, {"transition_difficulty": 0.5}).get("transition_difficulty", 0.5)
	
	var complexity_factor: float = (old_difficulty + new_difficulty) * 0.5
	
	# Adjust based on transition type
	match transition_type:
		TransitionType.IMMEDIATE:
			return 0.1  # Nearly instant
		TransitionType.SMOOTH:
			return base_duration * complexity_factor
		TransitionType.STAGED:
			return base_duration * complexity_factor * 1.5
		TransitionType.ADAPTIVE:
			return base_duration * complexity_factor * 1.2
		_:
			return base_duration

func _execute_immediate_transition(dynamic_formation: DynamicFormation) -> void:
	# Immediate transition - snap to new formation
	dynamic_formation.current_type = dynamic_formation.target_type
	_apply_advanced_formation_pattern(dynamic_formation)
	dynamic_formation.transition_state.complete_transition()

func _execute_smooth_transition(dynamic_formation: DynamicFormation, delta: float) -> void:
	# Smooth interpolated transition between formations
	var progress: float = dynamic_formation.transition_state.progress
	
	# Calculate intermediate positions
	_calculate_transition_intermediate_positions(dynamic_formation, progress)
	
	# Update formation positions with interpolated values
	_apply_intermediate_formation_positions(dynamic_formation)

func _execute_staged_transition(dynamic_formation: DynamicFormation, delta: float) -> void:
	# Multi-stage transition with intermediate formations
	var progress: float = dynamic_formation.transition_state.progress
	var stage_count: int = 3  # Three-stage transition
	var current_stage: int = int(progress * stage_count)
	
	# Apply stage-specific formation adjustments
	_apply_staged_formation_adjustments(dynamic_formation, current_stage, stage_count)

func _execute_adaptive_transition(dynamic_formation: DynamicFormation, delta: float) -> void:
	# Context-aware adaptive transition
	var tactical_context: Dictionary = tactical_analyzer.analyze_formation_context(dynamic_formation)
	var adaptation_factor: float = _calculate_adaptation_factor(tactical_context)
	
	# Adjust transition based on tactical situation
	_apply_adaptive_transition_adjustments(dynamic_formation, adaptation_factor)

func _complete_formation_transition(dynamic_formation: DynamicFormation) -> void:
	var old_type: AdvancedFormationType = dynamic_formation.current_type
	var transition_time: float = Time.get_time_from_start() - dynamic_formation.transition_state.start_time
	
	dynamic_formation.current_type = dynamic_formation.target_type
	dynamic_formation.transition_state.complete_transition()
	
	# Apply final formation pattern
	_apply_advanced_formation_pattern(dynamic_formation)
	
	# Update performance stats
	formation_performance_stats["transitions_completed"] += 1
	
	formation_transition_completed.emit(dynamic_formation.formation_id, dynamic_formation.current_type, transition_time)

func _apply_advanced_formation_pattern(dynamic_formation: DynamicFormation) -> void:
	var formation_type: AdvancedFormationType = dynamic_formation.current_type
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	
	# Apply advanced pattern based on type
	match formation_type:
		AdvancedFormationType.COMBAT_SPREAD:
			_apply_combat_spread_pattern(dynamic_formation)
		AdvancedFormationType.DEFENSIVE_CIRCLE:
			_apply_defensive_circle_pattern(dynamic_formation)
		AdvancedFormationType.ESCORT_SCREEN:
			_apply_escort_screen_pattern(dynamic_formation)
		AdvancedFormationType.STRIKE_WEDGE:
			_apply_strike_wedge_pattern(dynamic_formation)
		AdvancedFormationType.DEFENSIVE_LAYERS:
			_apply_defensive_layers_pattern(dynamic_formation)
		AdvancedFormationType.PATROL_SWEEP:
			_apply_patrol_sweep_pattern(dynamic_formation)
		AdvancedFormationType.MISSILE_SCREEN:
			_apply_missile_screen_pattern(dynamic_formation)
		AdvancedFormationType.PURSUIT_LINE:
			_apply_pursuit_line_pattern(dynamic_formation)
		AdvancedFormationType.BOMBER_ESCORT:
			_apply_bomber_escort_pattern(dynamic_formation)
		AdvancedFormationType.CAPITAL_ASSAULT:
			_apply_capital_assault_pattern(dynamic_formation)
		_:
			# Use base formation manager for basic types
			base_formation.update_formation_positions()

func _apply_combat_spread_pattern(dynamic_formation: DynamicFormation) -> void:
	# Wide combat formation optimized for engagement
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var member_count: int = base_formation.members.size()
	var spacing: float = base_formation.formation_spacing * 1.5
	
	if not is_instance_valid(base_formation.leader):
		return
	
	var leader_pos: Vector3 = base_formation.leader.global_position
	var leader_forward: Vector3 = base_formation._get_ship_forward(base_formation.leader)
	var leader_right: Vector3 = leader_forward.cross(Vector3.UP).normalized()
	
	base_formation.formation_positions.clear()
	base_formation.formation_orientations.clear()
	
	# Create wide spread optimized for combat
	for i in range(member_count):
		var angle: float = (i * 2.0 * PI) / max(member_count, 3)
		var radius: float = spacing * (1.0 + (i % 2) * 0.3)  # Staggered distances
		
		var x_offset: float = cos(angle) * radius
		var z_offset: float = sin(angle) * radius * 0.6  # Flattened for better coverage
		
		var position: Vector3 = leader_pos + leader_right * x_offset + leader_forward * z_offset
		base_formation.formation_positions.append(position)
		base_formation.formation_orientations.append(leader_forward)

func _apply_defensive_circle_pattern(dynamic_formation: DynamicFormation) -> void:
	# Circular formation for all-around defense
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var member_count: int = base_formation.members.size()
	var spacing: float = base_formation.formation_spacing * 1.2
	
	if not is_instance_valid(base_formation.leader):
		return
	
	var leader_pos: Vector3 = base_formation.leader.global_position
	
	base_formation.formation_positions.clear()
	base_formation.formation_orientations.clear()
	
	# Create defensive circle around leader
	for i in range(member_count):
		var angle: float = (i * 2.0 * PI) / member_count
		var radius: float = spacing
		
		var x_offset: float = cos(angle) * radius
		var z_offset: float = sin(angle) * radius
		
		var position: Vector3 = leader_pos + Vector3(x_offset, 0, z_offset)
		var orientation: Vector3 = (leader_pos - position).normalized()  # Face center
		
		base_formation.formation_positions.append(position)
		base_formation.formation_orientations.append(orientation)

func _apply_escort_screen_pattern(dynamic_formation: DynamicFormation) -> void:
	# Large escort formation for capital ship protection
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var member_count: int = base_formation.members.size()
	var spacing: float = base_formation.formation_spacing * 2.0
	
	if not is_instance_valid(base_formation.leader):
		return
	
	var leader_pos: Vector3 = base_formation.leader.global_position
	var leader_forward: Vector3 = base_formation._get_ship_forward(base_formation.leader)
	var leader_right: Vector3 = leader_forward.cross(Vector3.UP).normalized()
	
	base_formation.formation_positions.clear()
	base_formation.formation_orientations.clear()
	
	# Create layered escort screen
	var layers: int = min(3, (member_count + 3) / 4)
	var ships_per_layer: int = member_count / layers
	var ship_index: int = 0
	
	for layer in range(layers):
		var layer_distance: float = spacing * (layer + 1)
		var layer_ships: int = ships_per_layer
		if layer == layers - 1:  # Last layer gets remaining ships
			layer_ships = member_count - ship_index
		
		for ship in range(layer_ships):
			if ship_index >= member_count:
				break
			
			var angle: float = (ship * 2.0 * PI) / layer_ships
			var x_offset: float = cos(angle) * layer_distance
			var z_offset: float = sin(angle) * layer_distance * 0.8
			
			var position: Vector3 = leader_pos + leader_right * x_offset + leader_forward * z_offset
			base_formation.formation_positions.append(position)
			base_formation.formation_orientations.append(leader_forward)
			
			ship_index += 1

func _apply_strike_wedge_pattern(dynamic_formation: DynamicFormation) -> void:
	# Penetration formation for strike missions
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var member_count: int = base_formation.members.size()
	var spacing: float = base_formation.formation_spacing * 0.8
	
	if not is_instance_valid(base_formation.leader):
		return
	
	var leader_pos: Vector3 = base_formation.leader.global_position
	var leader_forward: Vector3 = base_formation._get_ship_forward(base_formation.leader)
	var leader_right: Vector3 = leader_forward.cross(Vector3.UP).normalized()
	
	base_formation.formation_positions.clear()
	base_formation.formation_orientations.clear()
	
	# Create wedge formation with leader at point
	for i in range(member_count):
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var tier: int = (i + 1) / 2
		
		var x_offset: float = side * spacing * (tier + 1) * 0.7
		var z_offset: float = -spacing * tier * 0.5
		
		var position: Vector3 = leader_pos + leader_right * x_offset + leader_forward * z_offset
		base_formation.formation_positions.append(position)
		base_formation.formation_orientations.append(leader_forward)

func _apply_defensive_layers_pattern(dynamic_formation: DynamicFormation) -> void:
	# Multi-layer defensive formation
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var member_count: int = base_formation.members.size()
	var spacing: float = base_formation.formation_spacing * 1.8
	
	if not is_instance_valid(base_formation.leader):
		return
	
	var leader_pos: Vector3 = base_formation.leader.global_position
	var leader_forward: Vector3 = base_formation._get_ship_forward(base_formation.leader)
	var leader_right: Vector3 = leader_forward.cross(Vector3.UP).normalized()
	
	base_formation.formation_positions.clear()
	base_formation.formation_orientations.clear()
	
	# Create three defensive layers
	var layers: Array[Array] = [[], [], []]
	for i in range(member_count):
		layers[i % 3].append(i)
	
	var layer_distances: Array[float] = [spacing * 0.8, spacing * 1.3, spacing * 2.0]
	
	for layer_idx in range(3):
		var layer_ships: Array = layers[layer_idx]
		var layer_distance: float = layer_distances[layer_idx]
		
		for ship_idx in range(layer_ships.size()):
			var ship: int = layer_ships[ship_idx]
			var angle: float = (ship_idx * 2.0 * PI) / max(layer_ships.size(), 1)
			
			var x_offset: float = cos(angle) * layer_distance
			var z_offset: float = sin(angle) * layer_distance * 0.6
			
			var position: Vector3 = leader_pos + leader_right * x_offset + leader_forward * z_offset
			base_formation.formation_positions.append(position)
			base_formation.formation_orientations.append(leader_forward)

func _apply_patrol_sweep_pattern(dynamic_formation: DynamicFormation) -> void:
	# Wide sweep formation for patrol and search
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var member_count: int = base_formation.members.size()
	var spacing: float = base_formation.formation_spacing * 3.0
	
	if not is_instance_valid(base_formation.leader):
		return
	
	var leader_pos: Vector3 = base_formation.leader.global_position
	var leader_forward: Vector3 = base_formation._get_ship_forward(base_formation.leader)
	var leader_right: Vector3 = leader_forward.cross(Vector3.UP).normalized()
	
	base_formation.formation_positions.clear()
	base_formation.formation_orientations.clear()
	
	# Create wide line formation for maximum coverage
	for i in range(member_count):
		var side_position: float = (i - (member_count - 1) * 0.5)
		var x_offset: float = side_position * spacing
		var z_offset: float = abs(side_position) * spacing * 0.1  # Slight curve
		
		var position: Vector3 = leader_pos + leader_right * x_offset + leader_forward * z_offset
		base_formation.formation_positions.append(position)
		base_formation.formation_orientations.append(leader_forward)

func _apply_missile_screen_pattern(dynamic_formation: DynamicFormation) -> void:
	# Anti-missile defensive screen formation
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var member_count: int = base_formation.members.size()
	var spacing: float = base_formation.formation_spacing
	
	if not is_instance_valid(base_formation.leader):
		return
	
	var leader_pos: Vector3 = base_formation.leader.global_position
	var leader_forward: Vector3 = base_formation._get_ship_forward(base_formation.leader)
	var leader_right: Vector3 = leader_forward.cross(Vector3.UP).normalized()
	
	base_formation.formation_positions.clear()
	base_formation.formation_orientations.clear()
	
	# Create overlapping coverage zones
	var coverage_zones: int = min(3, (member_count + 2) / 3)
	var ships_per_zone: int = member_count / coverage_zones
	var ship_index: int = 0
	
	for zone in range(coverage_zones):
		var zone_center: Vector3 = leader_pos + leader_forward * (zone - 1) * spacing * 0.5
		var zone_ships: int = ships_per_zone
		if zone == coverage_zones - 1:
			zone_ships = member_count - ship_index
		
		for ship in range(zone_ships):
			if ship_index >= member_count:
				break
			
			var angle: float = (ship * 2.0 * PI) / zone_ships
			var radius: float = spacing * 0.8
			
			var x_offset: float = cos(angle) * radius
			var z_offset: float = sin(angle) * radius * 0.4
			
			var position: Vector3 = zone_center + leader_right * x_offset + leader_forward * z_offset
			base_formation.formation_positions.append(position)
			base_formation.formation_orientations.append(leader_forward)
			
			ship_index += 1

func _apply_pursuit_line_pattern(dynamic_formation: DynamicFormation) -> void:
	# High-speed pursuit formation
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var member_count: int = base_formation.members.size()
	var spacing: float = base_formation.formation_spacing * 0.6
	
	if not is_instance_valid(base_formation.leader):
		return
	
	var leader_pos: Vector3 = base_formation.leader.global_position
	var leader_forward: Vector3 = base_formation._get_ship_forward(base_formation.leader)
	var leader_right: Vector3 = leader_forward.cross(Vector3.UP).normalized()
	
	base_formation.formation_positions.clear()
	base_formation.formation_orientations.clear()
	
	# Create tight pursuit line
	for i in range(member_count):
		var tier: int = i / 2
		var side: float = 1.0 if i % 2 == 0 else -1.0
		
		var x_offset: float = side * spacing * 0.5
		var z_offset: float = -spacing * tier
		
		var position: Vector3 = leader_pos + leader_right * x_offset + leader_forward * z_offset
		base_formation.formation_positions.append(position)
		base_formation.formation_orientations.append(leader_forward)

func _apply_bomber_escort_pattern(dynamic_formation: DynamicFormation) -> void:
	# Specialized bomber protection formation
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var member_count: int = base_formation.members.size()
	var spacing: float = base_formation.formation_spacing * 1.3
	
	if not is_instance_valid(base_formation.leader):
		return
	
	var leader_pos: Vector3 = base_formation.leader.global_position
	var leader_forward: Vector3 = base_formation._get_ship_forward(base_formation.leader)
	var leader_right: Vector3 = leader_forward.cross(Vector3.UP).normalized()
	var leader_up: Vector3 = Vector3.UP
	
	base_formation.formation_positions.clear()
	base_formation.formation_orientations.clear()
	
	# Create escort positions around bomber(s)
	for i in range(member_count):
		var escort_role: String = _determine_escort_role(i, member_count)
		var position: Vector3
		
		match escort_role:
			"high_cover":
				position = leader_pos + leader_up * spacing + leader_right * (i - member_count * 0.5) * spacing * 0.5
			"low_cover":
				position = leader_pos + leader_up * (-spacing * 0.5) + leader_right * (i - member_count * 0.5) * spacing * 0.5
			"flanking":
				var side: float = 1.0 if i % 2 == 0 else -1.0
				position = leader_pos + leader_right * side * spacing + leader_forward * spacing * 0.3
			_:
				position = leader_pos + leader_forward * (-spacing) + leader_right * (i - member_count * 0.5) * spacing * 0.3
		
		base_formation.formation_positions.append(position)
		base_formation.formation_orientations.append(leader_forward)

func _determine_escort_role(ship_index: int, total_ships: int) -> String:
	var role_distribution: float = float(ship_index) / float(total_ships)
	
	if role_distribution < 0.3:
		return "high_cover"
	elif role_distribution < 0.6:
		return "flanking"
	elif role_distribution < 0.8:
		return "low_cover"
	else:
		return "trailing"

func _apply_capital_assault_pattern(dynamic_formation: DynamicFormation) -> void:
	# Large formation for capital ship attack
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var member_count: int = base_formation.members.size()
	var spacing: float = base_formation.formation_spacing
	
	if not is_instance_valid(base_formation.leader):
		return
	
	var leader_pos: Vector3 = base_formation.leader.global_position
	var leader_forward: Vector3 = base_formation._get_ship_forward(base_formation.leader)
	var leader_right: Vector3 = leader_forward.cross(Vector3.UP).normalized()
	
	base_formation.formation_positions.clear()
	base_formation.formation_orientations.clear()
	
	# Create multi-wave assault formation
	var waves: int = min(3, (member_count + 5) / 6)
	var ships_per_wave: int = member_count / waves
	var ship_index: int = 0
	
	for wave in range(waves):
		var wave_distance: float = -spacing * wave * 1.5
		var wave_width: float = spacing * (wave + 1) * 0.8
		var wave_ships: int = ships_per_wave
		if wave == waves - 1:
			wave_ships = member_count - ship_index
		
		for ship in range(wave_ships):
			if ship_index >= member_count:
				break
			
			var ship_position: float = (ship - (wave_ships - 1) * 0.5)
			var x_offset: float = ship_position * wave_width / max(wave_ships - 1, 1)
			var z_offset: float = wave_distance
			
			var position: Vector3 = leader_pos + leader_right * x_offset + leader_forward * z_offset
			base_formation.formation_positions.append(position)
			base_formation.formation_orientations.append(leader_forward)
			
			ship_index += 1

func _calculate_transition_intermediate_positions(dynamic_formation: DynamicFormation, progress: float) -> void:
	# Calculate intermediate positions during smooth transitions
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var current_positions: Array[Vector3] = base_formation.formation_positions.duplicate()
	
	# Calculate target positions for new formation type
	var temp_type: AdvancedFormationType = dynamic_formation.current_type
	dynamic_formation.current_type = dynamic_formation.target_type
	_apply_advanced_formation_pattern(dynamic_formation)
	var target_positions: Array[Vector3] = base_formation.formation_positions.duplicate()
	dynamic_formation.current_type = temp_type
	
	# Interpolate between current and target positions
	var intermediate_positions: Array[Vector3] = []
	for i in range(min(current_positions.size(), target_positions.size())):
		var current_pos: Vector3 = current_positions[i]
		var target_pos: Vector3 = target_positions[i]
		var intermediate_pos: Vector3 = current_pos.lerp(target_pos, _ease_transition(progress))
		intermediate_positions.append(intermediate_pos)
	
	dynamic_formation.transition_state.intermediate_positions = intermediate_positions

func _ease_transition(progress: float) -> float:
	# Smooth easing function for transitions
	return progress * progress * (3.0 - 2.0 * progress)  # Smoothstep

func _apply_intermediate_formation_positions(dynamic_formation: DynamicFormation) -> void:
	# Apply intermediate positions during transition
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	base_formation.formation_positions = dynamic_formation.transition_state.intermediate_positions.duplicate()

func _apply_staged_formation_adjustments(dynamic_formation: DynamicFormation, current_stage: int, total_stages: int) -> void:
	# Apply stage-specific adjustments for staged transitions
	var adjustment_factor: float = float(current_stage) / float(total_stages)
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	
	# Modify spacing based on stage
	var original_spacing: float = base_formation.formation_spacing
	var stage_spacing: float = original_spacing * (1.0 + adjustment_factor * 0.5)
	base_formation.formation_spacing = stage_spacing
	
	# Apply formation pattern with modified parameters
	_apply_advanced_formation_pattern(dynamic_formation)
	
	# Restore original spacing
	base_formation.formation_spacing = original_spacing

func _apply_adaptive_transition_adjustments(dynamic_formation: DynamicFormation, adaptation_factor: float) -> void:
	# Apply adaptive adjustments based on tactical situation
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	
	# Adjust transition speed based on tactical pressure
	if adaptation_factor > 0.8:  # High tactical pressure
		dynamic_formation.transition_state.target_completion_time *= 0.7  # Faster transition
	elif adaptation_factor < 0.3:  # Low tactical pressure
		dynamic_formation.transition_state.target_completion_time *= 1.3  # Slower, smoother transition

func _calculate_adaptation_factor(tactical_context: Dictionary) -> float:
	# Calculate adaptation factor based on tactical context
	var threat_factor: float = tactical_context.get("threat_level", 0.5)
	var urgency_factor: float = tactical_context.get("urgency", 0.5)
	var coordination_factor: float = tactical_context.get("coordination_difficulty", 0.5)
	
	return (threat_factor + urgency_factor + coordination_factor) / 3.0

func _check_formation_adaptations() -> void:
	# Check if formations need adaptation based on tactical situation
	for formation_id in dynamic_formations:
		var dynamic_formation: DynamicFormation = dynamic_formations[formation_id]
		if dynamic_formation.transition_state.is_transitioning:
			continue  # Skip formations already transitioning
		
		var tactical_context: Dictionary = tactical_analyzer.analyze_formation_context(dynamic_formation)
		var adaptation_needed: Dictionary = adaptation_engine.evaluate_adaptation_needs(dynamic_formation, tactical_context)
		
		if adaptation_needed.get("adaptation_required", false):
			_trigger_formation_adaptation(dynamic_formation, adaptation_needed)

func _trigger_formation_adaptation(dynamic_formation: DynamicFormation, adaptation: Dictionary) -> void:
	var recommended_type: AdvancedFormationType = adaptation.get("recommended_formation", dynamic_formation.current_type)
	var urgency: float = adaptation.get("urgency", 0.5)
	
	# Select transition type based on urgency
	var transition_type: TransitionType = TransitionType.SMOOTH
	if urgency > 0.8:
		transition_type = TransitionType.IMMEDIATE
	elif urgency > 0.6:
		transition_type = TransitionType.ADAPTIVE
	else:
		transition_type = TransitionType.STAGED
	
	# Initiate adaptation
	if initiate_formation_transition(dynamic_formation.formation_id, recommended_type, transition_type):
		formation_performance_stats["adaptations_triggered"] += 1
		formation_adaptation_triggered.emit(
			dynamic_formation.formation_id,
			adaptation.get("trigger_reason", "tactical_adaptation"),
			adaptation
		)

func _update_effectiveness_metrics() -> void:
	# Update formation effectiveness metrics
	for formation_id in dynamic_formations:
		var dynamic_formation: DynamicFormation = dynamic_formations[formation_id]
		var effectiveness: Dictionary = effectiveness_calculator.calculate_formation_effectiveness(dynamic_formation)
		
		dynamic_formation.effectiveness_metrics = effectiveness
		
		var overall_effectiveness: float = effectiveness.get("overall_effectiveness", 0.0)
		formation_effectiveness_updated.emit(formation_id, overall_effectiveness, effectiveness)

func _process_multi_squadron_coordination() -> void:
	# Process multi-squadron coordination
	for coordinator_id in squadron_coordinators:
		var coordinator: SquadronCoordinator = squadron_coordinators[coordinator_id]
		_update_squadron_coordination(coordinator)

## Creates multi-squadron coordination
func create_multi_squadron_coordination(squadron_formations: Array[String], coordination_pattern: Dictionary = {}) -> String:
	var coordinator_id: String = "coord_" + str(squadron_coordinators.size())
	var coordinator: SquadronCoordinator = SquadronCoordinator.new(coordinator_id)
	
	coordinator.coordinated_squadrons = squadron_formations
	coordinator.coordination_pattern = coordination_pattern
	coordinator.overall_formation_type = coordination_pattern.get("formation_type", AdvancedFormationType.FLEET_BATTLE_LINE)
	
	# Assign roles to squadrons
	for i in range(squadron_formations.size()):
		var squadron_id: String = squadron_formations[i]
		coordinator.squadron_roles[squadron_id] = _determine_squadron_role(i, squadron_formations.size())
	
	squadron_coordinators[coordinator_id] = coordinator
	formation_performance_stats["squadron_coordinations"] += 1
	
	multi_squadron_coordination_established.emit(coordinator_id, squadron_formations)
	
	return coordinator_id

func _determine_squadron_role(squadron_index: int, total_squadrons: int) -> String:
	var role_distribution: float = float(squadron_index) / float(total_squadrons)
	
	if role_distribution < 0.2:
		return "vanguard"
	elif role_distribution < 0.4:
		return "main_force"
	elif role_distribution < 0.6:
		return "support"
	elif role_distribution < 0.8:
		return "reserve"
	else:
		return "rear_guard"

func _update_squadron_coordination(coordinator: SquadronCoordinator) -> void:
	# Update coordination between squadrons
	var overall_effectiveness: float = 0.0
	var valid_squadrons: int = 0
	
	for squadron_id in coordinator.coordinated_squadrons:
		if dynamic_formations.has(squadron_id):
			var squadron_formation: DynamicFormation = dynamic_formations[squadron_id]
			overall_effectiveness += squadron_formation.effectiveness_metrics.get("overall_effectiveness", 0.0)
			valid_squadrons += 1
	
	if valid_squadrons > 0:
		coordinator.coordination_effectiveness = overall_effectiveness / valid_squadrons

## Gets formation status information
func get_dynamic_formation_status(formation_id: String) -> Dictionary:
	if not dynamic_formations.has(formation_id):
		return {}
	
	var dynamic_formation: DynamicFormation = dynamic_formations[formation_id]
	return {
		"formation_id": formation_id,
		"current_type": AdvancedFormationType.keys()[dynamic_formation.current_type],
		"target_type": AdvancedFormationType.keys()[dynamic_formation.target_type],
		"is_transitioning": dynamic_formation.transition_state.is_transitioning,
		"transition_progress": dynamic_formation.transition_state.progress,
		"effectiveness_metrics": dynamic_formation.effectiveness_metrics,
		"adaptation_parameters": dynamic_formation.adaptation_parameters,
		"tactical_context": dynamic_formation.tactical_context
	}

## Gets formation performance statistics
func get_formation_performance_statistics() -> Dictionary:
	return formation_performance_stats.duplicate()

## Destroys a dynamic formation
func destroy_dynamic_formation(formation_id: String) -> bool:
	if not dynamic_formations.has(formation_id):
		return false
	
	# Destroy base formation
	formation_manager.destroy_formation(formation_id)
	
	# Remove from dynamic formations
	dynamic_formations.erase(formation_id)
	
	# Remove from squadron coordinators
	for coordinator_id in squadron_coordinators:
		var coordinator: SquadronCoordinator = squadron_coordinators[coordinator_id]
		if formation_id in coordinator.coordinated_squadrons:
			coordinator.coordinated_squadrons.erase(formation_id)
	
	return true