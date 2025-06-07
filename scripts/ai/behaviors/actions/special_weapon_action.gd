class_name SpecialWeaponAction
extends WCSBTAction

## Special weapon usage behavior tree action
## Handles missiles, torpedoes, bombs, and capital ship weapons with specialized tactics

enum SpecialWeaponType {
	HEAT_SEEKING_MISSILE,   # Standard heat-seeking missiles
	RADAR_GUIDED_MISSILE,   # Radar-guided missiles
	HEAVY_TORPEDO,          # Anti-capital ship torpedoes
	CLUSTER_BOMB,           # Area denial cluster bombs
	GUIDED_BOMB,            # Precision guided bombs
	ANTI_FIGHTER_MISSILE,   # Specialized anti-fighter missiles
	CAPITAL_TURRET,         # Capital ship turret weapons
	POINT_DEFENSE,          # Point defense systems
	SPECIAL_ORDNANCE        # Unique/special weapons
}

enum TargetClass {
	FIGHTER,                # Small, agile targets
	BOMBER,                 # Medium attack craft
	CORVETTE,               # Small capital ships
	FRIGATE,                # Medium capital ships
	DESTROYER,              # Large capital ships
	CRUISER,                # Heavy capital ships
	BATTLESHIP,             # Massive capital ships
	TRANSPORT,              # Civilian/cargo vessels
	INSTALLATION            # Stationary targets
}

enum TacticalSituation {
	ONE_ON_ONE,             # Single combat
	OUTNUMBERED,            # Fighting multiple enemies
	SQUADRON_SUPPORT,       # With allied support
	ESCORT_DUTY,            # Protecting friendlies
	CAPITAL_ASSAULT,        # Attacking capital ships
	DEFENSIVE_SCREEN,       # Defending position
	STRIKE_MISSION,         # Offensive strike
	EMERGENCY_COMBAT        # Survival situation
}

@export var weapon_type: SpecialWeaponType = SpecialWeaponType.HEAT_SEEKING_MISSILE
@export var auto_weapon_selection: bool = true
@export var target_priority_threshold: float = 0.6
@export var ammunition_conservation: bool = true
@export var tactical_awareness: bool = true

var lock_acquisition_time: float = 0.0
var lock_established: bool = false
var target_lock_quality: float = 0.0
var weapon_ready: bool = false
var launch_window_open: bool = false
var last_special_weapon_use: float = 0.0

# Special weapon specifications
var weapon_specifications: Dictionary = {
	SpecialWeaponType.HEAT_SEEKING_MISSILE: {
		"lock_time": 1.5,
		"lock_range": 2500.0,
		"guidance_accuracy": 0.8,
		"damage_vs_fighter": 2.0,
		"damage_vs_bomber": 1.8,
		"damage_vs_capital": 0.6,
		"ammo_cost": 1,
		"cooldown_time": 3.0,
		"preferred_targets": [TargetClass.FIGHTER, TargetClass.BOMBER],
		"heat_signature_required": 0.3
	},
	SpecialWeaponType.RADAR_GUIDED_MISSILE: {
		"lock_time": 2.0,
		"lock_range": 3000.0,
		"guidance_accuracy": 0.9,
		"damage_vs_fighter": 1.5,
		"damage_vs_bomber": 2.2,
		"damage_vs_capital": 1.0,
		"ammo_cost": 1,
		"cooldown_time": 4.0,
		"preferred_targets": [TargetClass.BOMBER, TargetClass.CORVETTE],
		"radar_signature_required": 0.4
	},
	SpecialWeaponType.HEAVY_TORPEDO: {
		"lock_time": 3.5,
		"lock_range": 4000.0,
		"guidance_accuracy": 0.7,
		"damage_vs_fighter": 0.8,
		"damage_vs_bomber": 1.2,
		"damage_vs_capital": 3.5,
		"ammo_cost": 1,
		"cooldown_time": 8.0,
		"preferred_targets": [TargetClass.CORVETTE, TargetClass.FRIGATE, TargetClass.DESTROYER, TargetClass.CRUISER, TargetClass.BATTLESHIP],
		"subsystem_targeting": true
	},
	SpecialWeaponType.CLUSTER_BOMB: {
		"lock_time": 1.0,
		"lock_range": 1500.0,
		"guidance_accuracy": 0.6,
		"damage_vs_fighter": 1.8,
		"damage_vs_bomber": 2.5,
		"damage_vs_capital": 1.5,
		"ammo_cost": 1,
		"cooldown_time": 6.0,
		"area_effect": true,
		"area_radius": 150.0,
		"preferred_situations": [TacticalSituation.OUTNUMBERED, TacticalSituation.DEFENSIVE_SCREEN]
	}
}

signal special_weapon_lock_acquired(weapon_type: SpecialWeaponType, target: Node3D, lock_quality: float)
signal special_weapon_fired(weapon_type: SpecialWeaponType, target: Node3D, launch_parameters: Dictionary)
signal special_weapon_lock_lost(weapon_type: SpecialWeaponType, target: Node3D, reason: String)
signal special_weapon_unavailable(weapon_type: SpecialWeaponType, reason: String)
signal tactical_weapon_recommendation(recommended_weapon: SpecialWeaponType, situation: TacticalSituation)

func _setup() -> void:
	super._setup()
	lock_acquisition_time = 0.0
	lock_established = false
	target_lock_quality = 0.0
	weapon_ready = false
	launch_window_open = false
	last_special_weapon_use = 0.0

func execute_wcs_action(delta: float) -> int:
	var target: Node3D = get_current_target()
	if not target:
		return 0  # FAILURE - No target
	
	# Auto-select optimal special weapon if enabled
	if auto_weapon_selection:
		var optimal_weapon: SpecialWeaponType = _select_optimal_special_weapon(target)
		if optimal_weapon != weapon_type:
			weapon_type = optimal_weapon
			_reset_weapon_state()
	
	# Check if special weapon is available and appropriate
	if not _validate_special_weapon_usage(target):
		return 0  # FAILURE - Weapon not suitable
	
	# Handle weapon lock acquisition process
	var lock_result: int = _process_weapon_lock(target, delta)
	if lock_result == 0:  # Lock failed
		return 0  # FAILURE
	elif lock_result == 2:  # Lock in progress
		return 2  # RUNNING
	
	# Lock established - evaluate launch window
	if not _evaluate_launch_window(target):
		return 2  # RUNNING - Wait for better opportunity
	
	# Execute special weapon launch
	var launch_result: bool = _execute_special_weapon_launch(target)
	if not launch_result:
		return 0  # FAILURE - Launch failed
	
	# Update weapon usage tracking
	_update_weapon_usage_tracking()
	
	return 1  # SUCCESS - Weapon launched

func _select_optimal_special_weapon(target: Node3D) -> SpecialWeaponType:
	"""Select optimal special weapon for current target and situation"""
	var target_class: TargetClass = _determine_target_class(target)
	var tactical_situation: TacticalSituation = _assess_tactical_situation()
	var available_weapons: Array[SpecialWeaponType] = _get_available_special_weapons()
	
	var best_weapon: SpecialWeaponType = weapon_type
	var best_score: float = 0.0
	
	for weapon in available_weapons:
		var score: float = _calculate_weapon_effectiveness_score(weapon, target_class, tactical_situation)
		if score > best_score:
			best_score = score
			best_weapon = weapon
	
	return best_weapon

func _calculate_weapon_effectiveness_score(weapon: SpecialWeaponType, target_class: TargetClass, situation: TacticalSituation) -> float:
	"""Calculate effectiveness score for weapon against specific target and situation"""
	var specs: Dictionary = weapon_specifications.get(weapon, {})
	var score: float = 0.0
	
	# Base damage effectiveness
	var damage_key: String = "damage_vs_" + _get_target_category(target_class)
	var damage_effectiveness: float = specs.get(damage_key, 1.0)
	score += damage_effectiveness * 0.4
	
	# Target preference bonus
	var preferred_targets: Array = specs.get("preferred_targets", [])
	if target_class in preferred_targets:
		score += 0.3
	
	# Situational appropriateness
	var preferred_situations: Array = specs.get("preferred_situations", [])
	if situation in preferred_situations:
		score += 0.2
	
	# Availability factor
	var ammo_count: int = _get_weapon_ammo_count(weapon)
	if ammo_count <= 0:
		return 0.0  # No ammo
	
	var ammo_factor: float = min(1.0, ammo_count / 3.0)  # Scale based on available ammo
	score *= ammo_factor
	
	# Range appropriateness
	var distance: float = get_ship_position().distance_to(get_current_target().global_position)
	var lock_range: float = specs.get("lock_range", 2000.0)
	var range_factor: float = 1.0
	if distance > lock_range:
		range_factor = 0.0  # Out of range
	elif distance > lock_range * 0.8:
		range_factor = 0.5  # At edge of range
	
	score *= range_factor
	
	return score

func _validate_special_weapon_usage(target: Node3D) -> bool:
	"""Validate that special weapon usage is appropriate for current situation"""
	var specs: Dictionary = weapon_specifications.get(weapon_type, {})
	
	# Check ammunition availability
	var ammo_count: int = _get_weapon_ammo_count(weapon_type)
	if ammo_count <= 0:
		special_weapon_unavailable.emit(weapon_type, "No ammunition remaining")
		return false
	
	# Check cooldown
	var current_time: float = Time.get_time_from_start()
	var cooldown_time: float = specs.get("cooldown_time", 3.0)
	if current_time - last_special_weapon_use < cooldown_time:
		special_weapon_unavailable.emit(weapon_type, "Weapon on cooldown")
		return false
	
	# Check target priority if conservation is enabled
	if ammunition_conservation:
		var target_priority: float = _assess_target_priority(target)
		if target_priority < target_priority_threshold:
			special_weapon_unavailable.emit(weapon_type, "Target priority too low for special weapon")
			return false
	
	# Check range
	var distance: float = get_ship_position().distance_to(target.global_position)
	var lock_range: float = specs.get("lock_range", 2000.0)
	if distance > lock_range:
		special_weapon_unavailable.emit(weapon_type, "Target out of lock range")
		return false
	
	# Check target signature requirements
	if not _check_target_signature_requirements(target, specs):
		special_weapon_unavailable.emit(weapon_type, "Target signature insufficient")
		return false
	
	return true

func _process_weapon_lock(target: Node3D, delta: float) -> int:
	"""Process weapon lock acquisition"""
	var specs: Dictionary = weapon_specifications.get(weapon_type, {})
	var lock_time_required: float = specs.get("lock_time", 2.0)
	
	if not lock_established:
		# Start or continue lock acquisition
		lock_acquisition_time += delta
		
		# Calculate lock quality during acquisition
		target_lock_quality = _calculate_lock_quality_progress(target, lock_acquisition_time, lock_time_required)
		
		if lock_acquisition_time >= lock_time_required:
			# Lock acquisition complete
			lock_established = true
			weapon_ready = true
			special_weapon_lock_acquired.emit(weapon_type, target, target_lock_quality)
			return 1  # Lock established
		else:
			return 2  # Lock in progress
	else:
		# Maintain existing lock
		target_lock_quality = _maintain_target_lock(target, delta)
		
		if target_lock_quality < 0.3:
			# Lock lost
			_reset_weapon_state()
			special_weapon_lock_lost.emit(weapon_type, target, "Lock quality degraded")
			return 0  # Lock failed
		
		return 1  # Lock maintained

func _calculate_lock_quality_progress(target: Node3D, acquisition_time: float, required_time: float) -> float:
	"""Calculate lock quality during acquisition process"""
	var base_progress: float = acquisition_time / required_time
	var distance: float = get_ship_position().distance_to(target.global_position)
	var target_velocity: Vector3 = _get_target_velocity(target)
	var target_signature: float = _get_target_signature_strength(target)
	
	# Distance factor (closer is better)
	var distance_factor: float = clamp(1.0 - distance / 3000.0, 0.3, 1.0)
	
	# Velocity factor (slower targets easier to lock)
	var velocity_factor: float = clamp(1.0 - target_velocity.length() / 400.0, 0.4, 1.0)
	
	# Signature factor
	var signature_factor: float = clamp(target_signature, 0.3, 1.0)
	
	# Angle factor (facing target is better)
	var angle_factor: float = _calculate_angle_factor(target)
	
	return base_progress * distance_factor * velocity_factor * signature_factor * angle_factor

func _maintain_target_lock(target: Node3D, delta: float) -> float:
	"""Maintain target lock quality"""
	var current_quality: float = target_lock_quality
	var distance: float = get_ship_position().distance_to(target.global_position)
	var target_velocity: Vector3 = _get_target_velocity(target)
	var signature_strength: float = _get_target_signature_strength(target)
	
	# Base degradation over time
	var degradation_rate: float = 0.1 * delta  # 10% per second base
	
	# Distance affects lock stability
	var distance_factor: float = clamp(1.0 - distance / 4000.0, 0.2, 1.0)
	
	# Target maneuvers affect lock
	var maneuver_factor: float = clamp(1.0 - target_velocity.length() / 500.0, 0.3, 1.0)
	
	# Signature jamming or countermeasures
	var signature_factor: float = clamp(signature_strength, 0.2, 1.0)
	
	# Calculate quality change
	var quality_change: float = degradation_rate * distance_factor * maneuver_factor * signature_factor
	
	# Line of sight check
	if not _has_clear_line_of_sight(target):
		quality_change *= 3.0  # Rapid degradation without LOS
	
	return clamp(current_quality - quality_change, 0.0, 1.0)

func _evaluate_launch_window(target: Node3D) -> bool:
	"""Evaluate if launch window is optimal"""
	var specs: Dictionary = weapon_specifications.get(weapon_type, {})
	
	# Check lock quality threshold
	if target_lock_quality < 0.7:
		return false
	
	# Check tactical timing
	if not _check_tactical_launch_timing(target):
		return false
	
	# Check target vulnerability window
	if not _check_target_vulnerability_window(target):
		return false
	
	# Check friendly fire risk
	if _assess_friendly_fire_risk(target) > 0.1:
		return false
	
	# Weapon-specific launch conditions
	match weapon_type:
		SpecialWeaponType.HEAT_SEEKING_MISSILE:
			return _check_heat_seeking_conditions(target)
		
		SpecialWeaponType.RADAR_GUIDED_MISSILE:
			return _check_radar_guided_conditions(target)
		
		SpecialWeaponType.HEAVY_TORPEDO:
			return _check_torpedo_launch_conditions(target)
		
		SpecialWeaponType.CLUSTER_BOMB:
			return _check_cluster_bomb_conditions(target)
		
		_:
			return true

func _execute_special_weapon_launch(target: Node3D) -> bool:
	"""Execute special weapon launch"""
	var specs: Dictionary = weapon_specifications.get(weapon_type, {})
	
	# Calculate launch parameters
	var launch_params: Dictionary = _calculate_launch_parameters(target, specs)
	
	# Execute launch through ship controller
	var launch_success: bool = false
	
	if ship_controller and ship_controller.has_method("launch_special_weapon"):
		launch_success = ship_controller.launch_special_weapon(
			_get_weapon_group_for_special_weapon(weapon_type),
			target,
			launch_params
		)
	elif ship_controller and ship_controller.has_method("fire_weapon_at_target"):
		launch_success = ship_controller.fire_weapon_at_target(
			_get_weapon_group_for_special_weapon(weapon_type),
			target
		)
	
	if launch_success:
		special_weapon_fired.emit(weapon_type, target, launch_params)
		_consume_ammunition()
	
	return launch_success

func _calculate_launch_parameters(target: Node3D, specs: Dictionary) -> Dictionary:
	"""Calculate launch parameters for special weapon"""
	var params: Dictionary = {}
	var target_pos: Vector3 = target.global_position
	var target_velocity: Vector3 = _get_target_velocity(target)
	var distance: float = get_ship_position().distance_to(target_pos)
	
	# Basic targeting information
	params["target_position"] = target_pos
	params["target_velocity"] = target_velocity
	params["launch_distance"] = distance
	params["lock_quality"] = target_lock_quality
	
	# Weapon-specific parameters
	match weapon_type:
		SpecialWeaponType.HEAT_SEEKING_MISSILE:
			params["guidance_mode"] = "heat_seeking"
			params["heat_signature"] = _get_target_heat_signature(target)
		
		SpecialWeaponType.RADAR_GUIDED_MISSILE:
			params["guidance_mode"] = "radar_guided"
			params["radar_signature"] = _get_target_radar_signature(target)
		
		SpecialWeaponType.HEAVY_TORPEDO:
			params["guidance_mode"] = "torpedo"
			params["subsystem_target"] = _select_optimal_subsystem(target)
			params["approach_vector"] = _calculate_optimal_approach_vector(target)
		
		SpecialWeaponType.CLUSTER_BOMB:
			params["guidance_mode"] = "area_denial"
			params["burst_altitude"] = 100.0
			params["cluster_pattern"] = "standard"
	
	# Calculate intercept solution using advanced firing solutions
	var firing_solution: Dictionary = AdvancedFiringSolutions.calculate_firing_solution(
		get_ship_position(),
		get_ship_velocity(),
		target_pos,
		target_velocity,
		_get_weapon_class_for_special_weapon(weapon_type),
		specs,
		_get_target_analysis_data(target)
	)
	
	params.merge(firing_solution)
	
	return params

# Weapon-specific launch condition checks

func _check_heat_seeking_conditions(target: Node3D) -> bool:
	"""Check conditions for heat-seeking missile launch"""
	var heat_signature: float = _get_target_heat_signature(target)
	var required_signature: float = weapon_specifications[weapon_type].get("heat_signature_required", 0.3)
	
	if heat_signature < required_signature:
		return false
	
	# Check for heat interference
	var heat_interference: float = _assess_heat_interference()
	return heat_interference < 0.5

func _check_radar_guided_conditions(target: Node3D) -> bool:
	"""Check conditions for radar-guided missile launch"""
	var radar_signature: float = _get_target_radar_signature(target)
	var required_signature: float = weapon_specifications[weapon_type].get("radar_signature_required", 0.4)
	
	if radar_signature < required_signature:
		return false
	
	# Check for ECM interference
	var ecm_interference: float = _assess_ecm_interference()
	return ecm_interference < 0.6

func _check_torpedo_launch_conditions(target: Node3D) -> bool:
	"""Check conditions for torpedo launch"""
	var distance: float = get_ship_position().distance_to(target.global_position)
	
	# Torpedoes need minimum distance to arm
	if distance < 800.0:
		return false
	
	# Check target size (torpedoes work better on larger targets)
	var target_size: float = _get_target_size_factor(target)
	if target_size < 2.0:  # Too small for torpedoes
		return false
	
	# Check target velocity (torpedoes struggle with very fast targets)
	var target_velocity: Vector3 = _get_target_velocity(target)
	if target_velocity.length() > 300.0:
		return false
	
	return true

func _check_cluster_bomb_conditions(target: Node3D) -> bool:
	"""Check conditions for cluster bomb deployment"""
	var distance: float = get_ship_position().distance_to(target.global_position)
	
	# Cluster bombs need close range
	if distance > 1200.0:
		return false
	
	# Check for multiple targets in area (cluster bombs are area weapons)
	var nearby_enemies: Array[Node3D] = _get_enemies_in_radius(target.global_position, 200.0)
	
	# More effective against multiple targets
	return nearby_enemies.size() >= 1

# Target analysis and assessment functions

func _determine_target_class(target: Node3D) -> TargetClass:
	"""Determine target class for weapon selection"""
	if target.has_method("get_ship_class"):
		var ship_class: String = target.get_ship_class().to_lower()
		return _map_ship_class_to_target_class(ship_class)
	
	# Fallback: estimate from size
	var size_factor: float = _get_target_size_factor(target)
	if size_factor < 2.0:
		return TargetClass.FIGHTER
	elif size_factor < 10.0:
		return TargetClass.BOMBER
	elif size_factor < 50.0:
		return TargetClass.CORVETTE
	else:
		return TargetClass.FRIGATE

func _assess_tactical_situation() -> TacticalSituation:
	"""Assess current tactical situation"""
	var enemy_count: int = _count_nearby_enemies()
	var ally_count: int = _count_nearby_allies()
	
	if enemy_count == 1 and ally_count == 0:
		return TacticalSituation.ONE_ON_ONE
	elif enemy_count > ally_count + 1:
		return TacticalSituation.OUTNUMBERED
	elif ally_count > 0:
		return TacticalSituation.SQUADRON_SUPPORT
	else:
		return TacticalSituation.STRIKE_MISSION

func _assess_target_priority(target: Node3D) -> float:
	"""Assess target priority for special weapon usage"""
	if ai_agent and ai_agent.has_method("get_target_priority"):
		return ai_agent.get_target_priority(target)
	
	# Fallback assessment
	var threat_level: float = _assess_target_threat_level(target)
	var mission_value: float = _get_target_mission_value(target)
	
	return (threat_level + mission_value) / 2.0

func _check_target_signature_requirements(target: Node3D, specs: Dictionary) -> bool:
	"""Check if target meets signature requirements for weapon"""
	match weapon_type:
		SpecialWeaponType.HEAT_SEEKING_MISSILE:
			var heat_sig: float = _get_target_heat_signature(target)
			var required: float = specs.get("heat_signature_required", 0.3)
			return heat_sig >= required
		
		SpecialWeaponType.RADAR_GUIDED_MISSILE:
			var radar_sig: float = _get_target_radar_signature(target)
			var required: float = specs.get("radar_signature_required", 0.4)
			return radar_sig >= required
		
		_:
			return true

func _check_tactical_launch_timing(target: Node3D) -> bool:
	"""Check if tactical timing is optimal for launch"""
	# Check if target is in vulnerable state
	var target_vulnerability: float = _assess_target_vulnerability(target)
	if target_vulnerability < 0.3:
		return false
	
	# Check if friendly units are clear
	var friendly_clear: bool = _check_friendly_units_clear(target)
	if not friendly_clear:
		return false
	
	return true

func _check_target_vulnerability_window(target: Node3D) -> bool:
	"""Check if target is in vulnerable state"""
	var shield_level: float = _get_target_shield_level(target)
	var evasion_state: bool = _is_target_evading(target)
	
	# Prefer targets with low shields
	if shield_level > 0.8:
		return false
	
	# Avoid targets actively evading
	if evasion_state:
		return false
	
	return true

func _assess_friendly_fire_risk(target: Node3D) -> float:
	"""Assess risk of friendly fire"""
	var risk: float = 0.0
	var target_pos: Vector3 = target.global_position
	var ship_pos: Vector3 = get_ship_position()
	var to_target: Vector3 = target_pos - ship_pos
	
	# Check for friendlies between shooter and target
	var friendlies: Array[Node3D] = _get_nearby_friendlies()
	for friendly in friendlies:
		var to_friendly: Vector3 = friendly.global_position - ship_pos
		var friendly_distance: float = to_friendly.length()
		var target_distance: float = to_target.length()
		
		# Only check friendlies between shooter and target
		if friendly_distance < target_distance:
			var angle_to_friendly: float = to_target.normalized().angle_to(to_friendly.normalized())
			if angle_to_friendly < PI / 12.0:  # Within 15 degrees
				risk += 0.3
	
	return clamp(risk, 0.0, 1.0)

# Helper functions for weapon and target data

func _get_weapon_class_for_special_weapon(weapon: SpecialWeaponType) -> AdvancedFiringSolutions.WeaponClass:
	"""Map special weapon type to firing solution weapon class"""
	match weapon:
		SpecialWeaponType.HEAT_SEEKING_MISSILE, SpecialWeaponType.RADAR_GUIDED_MISSILE, SpecialWeaponType.ANTI_FIGHTER_MISSILE:
			return AdvancedFiringSolutions.WeaponClass.GUIDED_MISSILE
		SpecialWeaponType.HEAVY_TORPEDO:
			return AdvancedFiringSolutions.WeaponClass.TORPEDO
		SpecialWeaponType.CLUSTER_BOMB, SpecialWeaponType.GUIDED_BOMB:
			return AdvancedFiringSolutions.WeaponClass.AREA_WEAPON
		_:
			return AdvancedFiringSolutions.WeaponClass.GUIDED_MISSILE

func _get_target_analysis_data(target: Node3D) -> Dictionary:
	"""Get target analysis data for firing solutions"""
	return {
		"velocity": _get_target_velocity(target),
		"size_factor": _get_target_size_factor(target),
		"heat_signature": _get_target_heat_signature(target),
		"radar_signature": _get_target_radar_signature(target),
		"evasion_capability": _assess_target_evasion_capability(target),
		"vulnerability": _assess_target_vulnerability(target)
	}

func _get_available_special_weapons() -> Array[SpecialWeaponType]:
	"""Get list of available special weapons"""
	var available: Array[SpecialWeaponType] = []
	
	for weapon_type in SpecialWeaponType.values():
		if _get_weapon_ammo_count(weapon_type) > 0:
			available.append(weapon_type)
	
	return available

func _get_weapon_ammo_count(weapon: SpecialWeaponType) -> int:
	"""Get ammunition count for special weapon"""
	var weapon_group: int = _get_weapon_group_for_special_weapon(weapon)
	
	if ship_controller and ship_controller.has_method("get_weapon_ammo"):
		return ship_controller.get_weapon_ammo(weapon_group)
	
	# Fallback
	return 5

func _get_weapon_group_for_special_weapon(weapon: SpecialWeaponType) -> int:
	"""Map special weapon to weapon group index"""
	match weapon:
		SpecialWeaponType.HEAT_SEEKING_MISSILE, SpecialWeaponType.ANTI_FIGHTER_MISSILE:
			return 2
		SpecialWeaponType.RADAR_GUIDED_MISSILE:
			return 2
		SpecialWeaponType.HEAVY_TORPEDO:
			return 3
		SpecialWeaponType.CLUSTER_BOMB, SpecialWeaponType.GUIDED_BOMB:
			return 4
		_:
			return 2

func _get_target_category(target_class: TargetClass) -> String:
	"""Get target category string for damage lookup"""
	match target_class:
		TargetClass.FIGHTER, TargetClass.BOMBER:
			return "fighter"
		TargetClass.CORVETTE, TargetClass.FRIGATE, TargetClass.TRANSPORT:
			return "bomber"
		_:
			return "capital"

func _map_ship_class_to_target_class(ship_class: String) -> TargetClass:
	"""Map ship class string to target class enum"""
	if "fighter" in ship_class:
		return TargetClass.FIGHTER
	elif "bomber" in ship_class:
		return TargetClass.BOMBER
	elif "corvette" in ship_class:
		return TargetClass.CORVETTE
	elif "frigate" in ship_class:
		return TargetClass.FRIGATE
	elif "destroyer" in ship_class:
		return TargetClass.DESTROYER
	elif "cruiser" in ship_class:
		return TargetClass.CRUISER
	elif "battleship" in ship_class:
		return TargetClass.BATTLESHIP
	elif "transport" in ship_class:
		return TargetClass.TRANSPORT
	else:
		return TargetClass.FIGHTER

# Target signature and status functions (placeholders for integration)

func _get_target_velocity(target: Node3D) -> Vector3:
	if target.has_method("get_velocity"):
		return target.get_velocity()
	return Vector3.ZERO

func _get_target_size_factor(target: Node3D) -> float:
	if target.has_method("get_mass"):
		return target.get_mass() / 100.0
	return 1.0

func _get_target_heat_signature(target: Node3D) -> float:
	if target.has_method("get_heat_signature"):
		return target.get_heat_signature()
	return 0.5

func _get_target_radar_signature(target: Node3D) -> float:
	if target.has_method("get_radar_signature"):
		return target.get_radar_signature()
	return 0.6

func _get_target_signature_strength(target: Node3D) -> float:
	match weapon_type:
		SpecialWeaponType.HEAT_SEEKING_MISSILE:
			return _get_target_heat_signature(target)
		SpecialWeaponType.RADAR_GUIDED_MISSILE:
			return _get_target_radar_signature(target)
		_:
			return 0.7

func _assess_target_evasion_capability(target: Node3D) -> float:
	var velocity: Vector3 = _get_target_velocity(target)
	var speed: float = velocity.length()
	return clamp(speed / 300.0, 0.0, 1.0)

func _assess_target_vulnerability(target: Node3D) -> float:
	if target.has_method("get_damage_level"):
		return target.get_damage_level()
	return 0.5

func _assess_target_threat_level(target: Node3D) -> float:
	if target.has_method("get_threat_rating"):
		return target.get_threat_rating()
	return 0.5

func _get_target_mission_value(target: Node3D) -> float:
	if ai_agent and ai_agent.has_method("get_target_mission_priority"):
		return ai_agent.get_target_mission_priority(target)
	return 0.5

func _get_target_shield_level(target: Node3D) -> float:
	if target.has_method("get_shield_percentage"):
		return target.get_shield_percentage()
	return 0.5

func _is_target_evading(target: Node3D) -> bool:
	# Check if target is performing evasive maneuvers
	return false

func _select_optimal_subsystem(target: Node3D) -> String:
	# For torpedo targeting
	return "engines"

func _calculate_optimal_approach_vector(target: Node3D) -> Vector3:
	# Calculate best approach for torpedo
	return Vector3.BACK

func _calculate_angle_factor(target: Node3D) -> float:
	var ship_forward: Vector3 = get_ship_forward_vector()
	var to_target: Vector3 = (target.global_position - get_ship_position()).normalized()
	var angle: float = ship_forward.angle_to(to_target)
	return max(0.3, 1.0 - angle / PI)

func _has_clear_line_of_sight(target: Node3D) -> bool:
	# Line of sight check
	return true

func _assess_heat_interference() -> float:
	# Check for heat sources that might interfere with heat-seeking
	return 0.2

func _assess_ecm_interference() -> float:
	# Check for ECM jamming
	return 0.3

func _get_enemies_in_radius(position: Vector3, radius: float) -> Array[Node3D]:
	# Get enemies within radius
	return []

func _count_nearby_enemies() -> int:
	return 2

func _count_nearby_allies() -> int:
	return 1

func _get_nearby_friendlies() -> Array[Node3D]:
	return []

func _check_friendly_units_clear(target: Node3D) -> bool:
	return true

func _reset_weapon_state() -> void:
	"""Reset weapon state for new lock attempt"""
	lock_acquisition_time = 0.0
	lock_established = false
	target_lock_quality = 0.0
	weapon_ready = false
	launch_window_open = false

func _consume_ammunition() -> void:
	"""Consume ammunition after successful launch"""
	last_special_weapon_use = Time.get_time_from_start()

func _update_weapon_usage_tracking() -> void:
	"""Update weapon usage statistics"""
	pass

func get_lock_status() -> Dictionary:
	"""Get current lock status information"""
	return {
		"lock_established": lock_established,
		"lock_quality": target_lock_quality,
		"lock_time": lock_acquisition_time,
		"weapon_ready": weapon_ready,
		"weapon_type": SpecialWeaponType.keys()[weapon_type]
	}

func force_weapon_selection(weapon: SpecialWeaponType) -> void:
	"""Force selection of specific special weapon"""
	weapon_type = weapon
	_reset_weapon_state()