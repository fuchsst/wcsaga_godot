class_name WeaponFiringIntegration
extends Node

## Integration system for combat maneuvers and weapon firing solutions
## Coordinates maneuver execution with optimal weapon timing and targeting

enum FireMode {
	SINGLE_SHOT,        # Single precise shots
	BURST_FIRE,         # Short controlled bursts
	SUSTAINED_FIRE,     # Continuous fire during engagement
	SUPPRESSION_FIRE,   # Area suppression fire
	ALPHA_STRIKE        # All weapons at once
}

enum WeaponTiming {
	IMMEDIATE,          # Fire as soon as possible
	OPTIMAL_RANGE,      # Fire at optimal weapon range
	PERFECT_LEAD,       # Fire only with perfect lead solution
	MANEUVER_SYNC,      # Fire synchronized with maneuver phase
	OPPORTUNITY         # Fire when target presents opportunity
}

@export var default_fire_mode: FireMode = FireMode.BURST_FIRE
@export var default_timing: WeaponTiming = WeaponTiming.OPTIMAL_RANGE
@export var convergence_distance: float = 500.0
@export var skill_integration: bool = true

var current_firing_solution: Dictionary = {}
var weapon_groups: Dictionary = {}
var ammo_management: Dictionary = {}
var heat_management: Dictionary = {}
var last_fire_time: float = 0.0
var burst_count: int = 0
var continuous_fire_time: float = 0.0

# Weapon effectiveness tracking
var weapon_accuracy_history: Array[float] = []
var damage_effectiveness: Dictionary = {}

signal weapon_fired(weapon_group: int, target: Node3D, hit_probability: float)
signal firing_solution_updated(solution: Dictionary)
signal weapon_overheat(weapon_group: int)
signal ammo_low(weapon_group: int, remaining_percent: float)

func _ready() -> void:
	_initialize_weapon_systems()

func _initialize_weapon_systems() -> void:
	# Initialize weapon group configurations
	weapon_groups = {
		0: {"type": "primary", "convergence": convergence_distance, "heat": 0.0, "max_heat": 100.0},
		1: {"type": "secondary", "convergence": convergence_distance * 1.2, "heat": 0.0, "max_heat": 80.0}
	}
	
	# Initialize ammo tracking
	ammo_management = {
		0: {"current": 100, "max": 100, "type": "energy"},
		1: {"current": 20, "max": 20, "type": "missile"}
	}

func calculate_integrated_firing_solution(
	ai_agent: Node,
	target: Node3D,
	maneuver_data: Dictionary,
	weapon_group: int = 0
) -> Dictionary:
	"""Calculate weapon firing solution integrated with current maneuver"""
	
	var ship_pos: Vector3 = ai_agent.global_position if ai_agent.has_method("global_position") else Vector3.ZERO
	var ship_velocity: Vector3 = _get_ship_velocity(ai_agent)
	var target_pos: Vector3 = target.global_position
	var target_velocity: Vector3 = _get_target_velocity(target)
	
	# Get weapon specifications
	var weapon_data: Dictionary = weapon_groups.get(weapon_group, {})
	var projectile_speed: float = _get_projectile_speed(weapon_group)
	var weapon_range: float = _get_weapon_range(weapon_group)
	var convergence_dist: float = weapon_data.get("convergence", convergence_distance)
	
	# Calculate base firing solution
	var firing_solution: Dictionary = ManeuverCalculator.calculate_weapon_firing_solution(
		ship_pos, ship_velocity, target_pos, target_velocity, projectile_speed, 1.0
	)
	
	# Integrate with maneuver context
	firing_solution = _integrate_maneuver_context(firing_solution, maneuver_data)
	
	# Apply skill-based modifications
	if skill_integration and ai_agent.has_method("get_skill_system"):
		var skill_system: CombatSkillSystem = ai_agent.get_skill_system()
		if skill_system:
			firing_solution = skill_system.apply_gunnery_skill_variations(firing_solution)
	
	# Add weapon-specific adjustments
	firing_solution["weapon_group"] = weapon_group
	firing_solution["convergence_distance"] = convergence_dist
	firing_solution["heat_level"] = weapon_data.get("heat", 0.0)
	firing_solution["ammo_remaining"] = ammo_management.get(weapon_group, {}).get("current", 0)
	
	# Calculate firing timing based on maneuver phase
	firing_solution["optimal_firing_time"] = _calculate_optimal_firing_time(maneuver_data, firing_solution)
	
	current_firing_solution = firing_solution
	firing_solution_updated.emit(firing_solution)
	
	return firing_solution

func _integrate_maneuver_context(base_solution: Dictionary, maneuver_data: Dictionary) -> Dictionary:
	"""Integrate firing solution with current maneuver context"""
	var integrated_solution: Dictionary = base_solution.duplicate(true)
	
	var maneuver_type: String = maneuver_data.get("maneuver_type", "")
	var maneuver_phase: String = maneuver_data.get("phase", "")
	var maneuver_velocity: Vector3 = maneuver_data.get("velocity", Vector3.ZERO)
	var distance_to_target: float = maneuver_data.get("distance_to_target", 1000.0)
	
	# Adjust for maneuver-specific factors
	match maneuver_type:
		"attack_run":
			integrated_solution = _apply_attack_run_adjustments(integrated_solution, maneuver_data)
		"strafe_pass":
			integrated_solution = _apply_strafe_pass_adjustments(integrated_solution, maneuver_data)
		"pursuit_attack":
			integrated_solution = _apply_pursuit_adjustments(integrated_solution, maneuver_data)
		"evasive_maneuver":
			integrated_solution = _apply_evasive_adjustments(integrated_solution, maneuver_data)
	
	# Phase-specific adjustments
	match maneuver_phase:
		"approach":
			integrated_solution["fire_probability"] = 0.1  # Low probability during approach
		"attack":
			integrated_solution["fire_probability"] = 1.0  # High probability during attack
		"breakaway":
			integrated_solution["fire_probability"] = 0.3  # Medium probability during breakaway
		"positioning":
			integrated_solution["fire_probability"] = 0.0  # No firing during positioning
	
	# Velocity adjustments
	var relative_velocity: Vector3 = maneuver_velocity - base_solution.get("target_velocity", Vector3.ZERO)
	integrated_solution["relative_velocity_factor"] = clamp(relative_velocity.length() / 100.0, 0.5, 2.0)
	
	return integrated_solution

func _apply_attack_run_adjustments(solution: Dictionary, maneuver_data: Dictionary) -> Dictionary:
	"""Apply attack run specific firing adjustments"""
	var adjusted_solution: Dictionary = solution.duplicate(true)
	
	var attack_phase: String = maneuver_data.get("attack_phase", "approach")
	var attack_type: String = maneuver_data.get("attack_run_type", "head_on")
	
	match attack_phase:
		"approach":
			adjusted_solution["hit_probability"] *= 0.8  # Reduced accuracy during approach
			adjusted_solution["recommended_fire_mode"] = FireMode.SINGLE_SHOT
		"attack":
			adjusted_solution["hit_probability"] *= 1.2  # Improved accuracy during attack
			adjusted_solution["recommended_fire_mode"] = FireMode.BURST_FIRE
		"breakaway":
			adjusted_solution["hit_probability"] *= 0.6  # Poor accuracy during breakaway
			adjusted_solution["recommended_fire_mode"] = FireMode.SUPPRESSION_FIRE
	
	# Attack type adjustments
	match attack_type:
		"head_on":
			adjusted_solution["convergence_bonus"] = 1.2
		"high_angle", "low_angle":
			adjusted_solution["convergence_bonus"] = 0.9
		"beam_attack":
			adjusted_solution["convergence_bonus"] = 0.8
		"quarter_attack":
			adjusted_solution["convergence_bonus"] = 1.1
	
	return adjusted_solution

func _apply_strafe_pass_adjustments(solution: Dictionary, maneuver_data: Dictionary) -> Dictionary:
	"""Apply strafe pass specific firing adjustments"""
	var adjusted_solution: Dictionary = solution.duplicate(true)
	
	var strafe_phase: String = maneuver_data.get("strafe_phase", "positioning")
	var strafe_direction: String = maneuver_data.get("strafe_direction", "left")
	
	match strafe_phase:
		"positioning":
			adjusted_solution["hit_probability"] *= 0.3
			adjusted_solution["recommended_fire_mode"] = FireMode.SINGLE_SHOT
		"strafing":
			adjusted_solution["hit_probability"] *= 1.1
			adjusted_solution["recommended_fire_mode"] = FireMode.SUSTAINED_FIRE
		"recovery":
			adjusted_solution["hit_probability"] *= 0.5
			adjusted_solution["recommended_fire_mode"] = FireMode.BURST_FIRE
	
	# Strafe direction affects lead calculation
	var direction_modifier: float = 1.0
	match strafe_direction:
		"left", "right":
			direction_modifier = 1.1  # Lateral strafing is effective
		"vertical_up", "vertical_down":
			direction_modifier = 0.9  # Vertical strafing is harder
	
	adjusted_solution["hit_probability"] *= direction_modifier
	adjusted_solution["strafe_lead_compensation"] = direction_modifier
	
	return adjusted_solution

func _apply_pursuit_adjustments(solution: Dictionary, maneuver_data: Dictionary) -> Dictionary:
	"""Apply pursuit attack specific firing adjustments"""
	var adjusted_solution: Dictionary = solution.duplicate(true)
	
	var pursuit_mode: String = maneuver_data.get("pursuit_mode", "aggressive")
	var pursuit_state: String = maneuver_data.get("pursuit_state", "engaging")
	
	match pursuit_mode:
		"aggressive":
			adjusted_solution["hit_probability"] *= 1.1
			adjusted_solution["recommended_fire_mode"] = FireMode.BURST_FIRE
		"cautious":
			adjusted_solution["hit_probability"] *= 0.9
			adjusted_solution["recommended_fire_mode"] = FireMode.SINGLE_SHOT
		"stalking":
			adjusted_solution["hit_probability"] *= 0.8
			adjusted_solution["recommended_fire_mode"] = FireMode.SINGLE_SHOT
		"herding":
			adjusted_solution["hit_probability"] *= 0.7
			adjusted_solution["recommended_fire_mode"] = FireMode.SUPPRESSION_FIRE
	
	# State-specific adjustments
	match pursuit_state:
		"closing":
			adjusted_solution["fire_priority"] = 0.3
		"engaging":
			adjusted_solution["fire_priority"] = 1.0
		"repositioning":
			adjusted_solution["fire_priority"] = 0.2
		"maintaining":
			adjusted_solution["fire_priority"] = 0.8
	
	return adjusted_solution

func _apply_evasive_adjustments(solution: Dictionary, maneuver_data: Dictionary) -> Dictionary:
	"""Apply evasive maneuver firing adjustments"""
	var adjusted_solution: Dictionary = solution.duplicate(true)
	
	# During evasive maneuvers, firing is opportunistic only
	adjusted_solution["hit_probability"] *= 0.4
	adjusted_solution["fire_priority"] = 0.2
	adjusted_solution["recommended_fire_mode"] = FireMode.SINGLE_SHOT
	adjusted_solution["opportunistic_only"] = true
	
	return adjusted_solution

func _calculate_optimal_firing_time(maneuver_data: Dictionary, firing_solution: Dictionary) -> float:
	"""Calculate optimal time to fire based on maneuver progression"""
	var maneuver_type: String = maneuver_data.get("maneuver_type", "")
	var phase_progress: float = maneuver_data.get("phase_progress", 0.0)
	var distance_to_target: float = maneuver_data.get("distance_to_target", 1000.0)
	
	var optimal_time: float = 0.0
	
	match maneuver_type:
		"attack_run":
			# Fire during mid-attack phase
			if phase_progress > 0.4 and phase_progress < 0.8:
				optimal_time = 0.1  # Fire soon
			else:
				optimal_time = 2.0  # Wait
		
		"strafe_pass":
			# Fire continuously during strafe
			if phase_progress > 0.2 and phase_progress < 0.9:
				optimal_time = 0.0  # Fire immediately
			else:
				optimal_time = 1.0
		
		"pursuit_attack":
			# Fire when in optimal range
			if distance_to_target < convergence_distance * 1.5:
				optimal_time = 0.2
			else:
				optimal_time = 1.0
		
		_:
			optimal_time = 0.5  # Default timing
	
	return optimal_time

func execute_weapon_fire(
	ai_agent: Node,
	target: Node3D,
	weapon_group: int = 0,
	fire_mode: FireMode = FireMode.BURST_FIRE
) -> bool:
	"""Execute weapon fire with current firing solution"""
	
	# Check if weapon can fire
	if not _can_fire_weapon(weapon_group):
		return false
	
	# Get current firing solution
	var solution: Dictionary = current_firing_solution
	if solution.is_empty():
		solution = calculate_integrated_firing_solution(ai_agent, target, {}, weapon_group)
	
	# Check firing conditions
	if not _verify_firing_conditions(solution, ai_agent, target):
		return false
	
	# Execute fire based on mode
	var fire_success: bool = false
	match fire_mode:
		FireMode.SINGLE_SHOT:
			fire_success = _execute_single_shot(ai_agent, weapon_group, solution)
		FireMode.BURST_FIRE:
			fire_success = _execute_burst_fire(ai_agent, weapon_group, solution)
		FireMode.SUSTAINED_FIRE:
			fire_success = _execute_sustained_fire(ai_agent, weapon_group, solution)
		FireMode.SUPPRESSION_FIRE:
			fire_success = _execute_suppression_fire(ai_agent, weapon_group, solution)
		FireMode.ALPHA_STRIKE:
			fire_success = _execute_alpha_strike(ai_agent, solution)
	
	if fire_success:
		_update_weapon_state(weapon_group, fire_mode)
		weapon_fired.emit(weapon_group, target, solution.get("hit_probability", 0.5))
	
	return fire_success

func _can_fire_weapon(weapon_group: int) -> bool:
	"""Check if weapon group can fire"""
	var weapon_data: Dictionary = weapon_groups.get(weapon_group, {})
	var ammo_data: Dictionary = ammo_management.get(weapon_group, {})
	
	# Check heat level
	var heat_level: float = weapon_data.get("heat", 0.0)
	var max_heat: float = weapon_data.get("max_heat", 100.0)
	if heat_level >= max_heat * 0.95:
		weapon_overheat.emit(weapon_group)
		return false
	
	# Check ammo
	var current_ammo: int = ammo_data.get("current", 0)
	if current_ammo <= 0:
		return false
	
	# Check ammo warning
	var max_ammo: int = ammo_data.get("max", 100)
	var ammo_percent: float = float(current_ammo) / float(max_ammo)
	if ammo_percent < 0.2:
		ammo_low.emit(weapon_group, ammo_percent)
	
	# Check fire rate limit
	var current_time: float = Time.get_time_from_start()
	var min_fire_interval: float = _get_min_fire_interval(weapon_group)
	if current_time - last_fire_time < min_fire_interval:
		return false
	
	return true

func _verify_firing_conditions(solution: Dictionary, ai_agent: Node, target: Node3D) -> bool:
	"""Verify that firing conditions are met"""
	
	# Check hit probability threshold
	var hit_probability: float = solution.get("hit_probability", 0.0)
	if hit_probability < 0.3:  # Minimum threshold
		return false
	
	# Check fire priority
	var fire_priority: float = solution.get("fire_priority", 1.0)
	if fire_priority < 0.5:
		return false
	
	# Check if opportunistic only and conditions aren't perfect
	if solution.get("opportunistic_only", false) and hit_probability < 0.8:
		return false
	
	# Check line of sight (if ship controller has method)
	if ai_agent.has_method("has_line_of_sight"):
		if not ai_agent.has_line_of_sight(target):
			return false
	
	# Check weapon convergence
	var distance_to_target: float = solution.get("distance_to_target", 1000.0)
	var convergence_dist: float = solution.get("convergence_distance", convergence_distance)
	if distance_to_target > convergence_dist * 2.0:
		return false
	
	return true

func _execute_single_shot(ai_agent: Node, weapon_group: int, solution: Dictionary) -> bool:
	"""Execute single precise shot"""
	if ai_agent.has_method("fire_weapons"):
		ai_agent.fire_weapons(weapon_group)
		_consume_ammo(weapon_group, 1)
		_add_heat(weapon_group, 10.0)
		return true
	return false

func _execute_burst_fire(ai_agent: Node, weapon_group: int, solution: Dictionary) -> bool:
	"""Execute controlled burst fire"""
	var burst_size: int = _get_burst_size(weapon_group)
	var success: bool = false
	
	for i in range(burst_size):
		if _can_fire_weapon(weapon_group):
			if ai_agent.has_method("fire_weapons"):
				ai_agent.fire_weapons(weapon_group)
				_consume_ammo(weapon_group, 1)
				_add_heat(weapon_group, 8.0)
				success = true
			await get_tree().create_timer(0.1).timeout  # Burst interval
		else:
			break
	
	return success

func _execute_sustained_fire(ai_agent: Node, weapon_group: int, solution: Dictionary) -> bool:
	"""Execute sustained fire"""
	if ai_agent.has_method("fire_weapons"):
		ai_agent.fire_weapons(weapon_group)
		_consume_ammo(weapon_group, 2)  # Higher ammo consumption
		_add_heat(weapon_group, 15.0)  # Higher heat generation
		return true
	return false

func _execute_suppression_fire(ai_agent: Node, weapon_group: int, solution: Dictionary) -> bool:
	"""Execute suppression fire"""
	if ai_agent.has_method("fire_weapons"):
		ai_agent.fire_weapons(weapon_group)
		_consume_ammo(weapon_group, 3)  # High ammo consumption
		_add_heat(weapon_group, 20.0)  # High heat generation
		return true
	return false

func _execute_alpha_strike(ai_agent: Node, solution: Dictionary) -> bool:
	"""Execute all weapons at once"""
	var success: bool = false
	for weapon_group in weapon_groups.keys():
		if _can_fire_weapon(weapon_group):
			if _execute_single_shot(ai_agent, weapon_group, solution):
				success = true
	return success

func _update_weapon_state(weapon_group: int, fire_mode: FireMode) -> void:
	"""Update weapon state after firing"""
	last_fire_time = Time.get_time_from_start()
	
	match fire_mode:
		FireMode.BURST_FIRE:
			burst_count += 1
		FireMode.SUSTAINED_FIRE:
			continuous_fire_time += 0.1
		_:
			burst_count = 0
			continuous_fire_time = 0.0

func _consume_ammo(weapon_group: int, amount: int) -> void:
	"""Consume ammunition"""
	var ammo_data: Dictionary = ammo_management.get(weapon_group, {})
	var current_ammo: int = ammo_data.get("current", 0)
	ammo_data["current"] = max(0, current_ammo - amount)

func _add_heat(weapon_group: int, heat_amount: float) -> void:
	"""Add heat to weapon"""
	var weapon_data: Dictionary = weapon_groups.get(weapon_group, {})
	var current_heat: float = weapon_data.get("heat", 0.0)
	weapon_data["heat"] = min(weapon_data.get("max_heat", 100.0), current_heat + heat_amount)

func _get_projectile_speed(weapon_group: int) -> float:
	"""Get projectile speed for weapon group"""
	var weapon_data: Dictionary = weapon_groups.get(weapon_group, {})
	match weapon_data.get("type", "primary"):
		"primary":
			return 800.0  # Typical laser speed
		"secondary":
			return 400.0  # Typical missile speed
		_:
			return 600.0

func _get_weapon_range(weapon_group: int) -> float:
	"""Get effective range for weapon group"""
	var weapon_data: Dictionary = weapon_groups.get(weapon_group, {})
	match weapon_data.get("type", "primary"):
		"primary":
			return 1200.0
		"secondary":
			return 2000.0
		_:
			return 1000.0

func _get_min_fire_interval(weapon_group: int) -> float:
	"""Get minimum fire interval for weapon group"""
	var weapon_data: Dictionary = weapon_groups.get(weapon_group, {})
	match weapon_data.get("type", "primary"):
		"primary":
			return 0.2  # 5 rounds per second
		"secondary":
			return 1.0  # 1 round per second
		_:
			return 0.3

func _get_burst_size(weapon_group: int) -> int:
	"""Get burst size for weapon group"""
	var weapon_data: Dictionary = weapon_groups.get(weapon_group, {})
	match weapon_data.get("type", "primary"):
		"primary":
			return 3
		"secondary":
			return 1
		_:
			return 2

func _get_ship_velocity(ai_agent: Node) -> Vector3:
	"""Get ship velocity from AI agent"""
	if ai_agent.has_method("get_velocity"):
		return ai_agent.get_velocity()
	elif ai_agent.has_method("get_linear_velocity"):
		return ai_agent.get_linear_velocity()
	return Vector3.ZERO

func _get_target_velocity(target: Node3D) -> Vector3:
	"""Get target velocity"""
	if target.has_method("get_velocity"):
		return target.get_velocity()
	elif target.has_method("get_linear_velocity"):
		return target.get_linear_velocity()
	return Vector3.ZERO

func update_heat_dissipation(delta: float) -> void:
	"""Update weapon heat dissipation"""
	for weapon_group in weapon_groups.keys():
		var weapon_data: Dictionary = weapon_groups[weapon_group]
		var current_heat: float = weapon_data.get("heat", 0.0)
		var dissipation_rate: float = 20.0  # Heat per second
		weapon_data["heat"] = max(0.0, current_heat - dissipation_rate * delta)

func get_weapon_status() -> Dictionary:
	"""Get current weapon system status"""
	return {
		"weapon_groups": weapon_groups,
		"ammo_management": ammo_management,
		"heat_management": heat_management,
		"current_firing_solution": current_firing_solution,
		"last_fire_time": last_fire_time,
		"burst_count": burst_count,
		"continuous_fire_time": continuous_fire_time
	}