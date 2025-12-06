# Ship instance representing complete integrated ship system
# Bridges converted data (TRES) with Godot scene system
class_name ShipInstance
extends Node

# Ship identification
var instance_id: String = ""
var ship_class: String = ""
var instance_name: String = ""
var faction: String = ""
var pilot_name: String = ""

# Core TRES data references
var ship_stats: ShipStats = null # Converted ship data from TBL
var species_data: SpeciesData = null # Associated species data

# System integration components
var physics_data: ShipPhysicsData = null # Physics state and properties
var weapon_systems: Array[WeaponSystem] = [] # Integrated weapon systems
var visual_instance: Node3D = null # Visual/model representation
var audio_data: ShipAudioData = null # Audio cues and effects
var mission_data: Dictionary = {} # Mission-specific data

# Current state
var current_position: Vector3 = Vector3.ZERO
var current_velocity: Vector3 = Vector3.ZERO
var current_rotation: Vector3 = Vector3.ZERO
var current_angular_velocity: Vector3 = Vector3.ZERO

# Health and damage system
var current_hitpoints: int = 100
var current_shield_strength: float = 0.0
var current_weapon_energy: float = 0.0
var current_afterburner_fuel: float = 0.0
var damage_feedback: Array[DamageResult] = []
var last_damage_time: float = 0.0

# Systemsstatus
var systems_online: bool = true
var shield_generators_online: bool = true
var weapon_systems_online: bool = true
var engine_systems_online: bool = true
var life_support_online: bool = true
var sensors_online: bool = true
var communications_online: bool = true

var subsystem_damage_status: Dictionary = {} # Subsystem name -> damage percent

# Performancetracking
var last_access_time: float = 0.0
var frame_count: int = 0
var performance_stats: Dictionary = {
	"ai_calculations": 0,
	"physics_updates": 0,
	"collision_checks": 0,
	"weapon_fires": 0,
	"weapon_fires": 0,
	"damage_applications": 0
}

var update_frame_count: int = 0


# Visualeffects
var shield_effect: Node = null
var engine_trail_effect: Node = null
var weapon_flash_effects: Array = []
var damage_spark_effects: Array = []

# TRES - basedgamemechanics
func initialize_from_tres_data() -> void:
	"""Initialize ship based on converted TRES data"""
	if not ship_stats:
		push_error("Ship stats not available for initialization")
		return

	# Initialize from ship stats
	current_hitpoints = ship_stats.hull_hitpoints
	current_shield_strength = ship_stats.shield_strength
	current_weapon_energy = ship_stats.max_weapon_energy
	current_afterburner_fuel = ship_stats.max_afterburner_fuel

	# Initialize subsystem status
	for subsystem in ship_stats.subsystem_hitpoints.keys():
		subsystem_damage_status[subsystem] = 0.0

	# Load species data if available
	if ship_stats.species and not ship_stats.species.is_empty():
		load_species_data()

	# Post-initialization
	apply_tres_validations()
	connect_internal_signals()

func load_species_data() -> void:
	"""Load associated species data for faction-specific behavior"""
	if ship_stats.species and ResourceLoader.exists(ship_stats.species):
		species_data = load(ship_stats.species)

func apply_tres_validations() -> bool:
	"""Apply validations based on TRES data integrity"""
	if not ship_stats:
		return false

	# Validate required fields exist
	if ship_stats.ship_class.is_empty():
		push_error("Ship class not defined in TRES data")
		return false

	if ship_stats.model_file.is_empty():
		push_error("Model file not referenced in TRES data")
		return false

	# Validate weapon systems
	if ship_stats.allowed_primary_weapons.is_empty() and ship_stats.allowed_secondary_weapons.is_empty():
		push_warning("No weapons defined for ship: %s" % ship_class)

	return true

func connect_internal_signals() -> void:
	"""Connect internal signals for system integration"""
	# Add signal connections for various events
	pass

# TRES-based ship mechanics
func apply_damage(damage_type: String, damage_amount: float, impact_point: Vector3, damage_source) -> DamageResult:
	"""Apply damage based on TRES ship armor and shield data"""
	performance_stats["damage_applications"] += 1
	last_damage_time = Time.get_ticks_msec() / 1000.0

	var damage_result = calculate_tres_based_damage(damage_type, damage_amount, impact_point)

	# Apply damage to appropriate systems
	var actual_damage = damage_result.actual_damage
	var shield_damage = damage_result.shield_damage
	var hull_damage = damage_result.hull_damage
	var subsystem_damage = damage_result.subsystem_damage

	# Apply to shields first
	var shield_reduction = min(current_shield_strength, shield_damage)
	current_shield_strength -= shield_reduction
	actual_damage -= shield_reduction * ship_stats.shield_effectiveness_modifier

	# Apply to hull
	var hull_reduction = min(current_hitpoints, actual_damage)
	current_hitpoints -= hull_reduction

	# Apply subsystem damage
	apply_subsystem_damage(subsystem_damage, impact_point)

	damage_result.post_shield_damage = hull_reduction
	damage_result.final_hull_damage = hull_reduction
	damage_result.shield_absorbed = shield_reduction

	damage_feedback.append(damage_result)

	# Limit damage feedback buffer
	if damage_feedback.size() > 10:
		damage_feedback.pop_front()

	return damage_result

func calculate_tres_based_damage(damage_type: String, damage_amount: float, impact_point: Vector3) -> DamageResult:
	"""Calculate damage using TRES armor and shield data"""
	var result = DamageResult.new()
	result.damage_type = damage_type
	result.original_damage = damage_amount
	result.impact_point = impact_point

	# Calculate impact angle and surface multipliers
	var impact_normal = Vector3(0, 0, 1) # Simplified - would be calculated from geometry
	var impact_angle = calculate_impact_angle(impact_point, impact_normal)

	# Apply armor multipliers based on hit location
	var fore_mult = ship_stats.armor_thickness.get("fore_cm", 1.0)
	var aft_mult = ship_stats.armor_thickness.get("aft_cm", 1.0)
	var left_mult = ship_stats.armor_thickness.get("left_cm", 1.0)
	var right_mult = ship_stats.armor_thickness.get("right_cm", 1.0)

	# Use angle to determine which armor face
	result.surface_multiplier = 1.0 # Simplified calculation

	# Apply shield effectiveness
	var shield_modifier = 1.0 - (current_shield_strength / max(ship_stats.shield_strength, 1.0))
	result.shield_damage = damage_amount * shield_modifier

	# Calculate final damage
	result.actual_damage = damage_amount * result.surface_multiplier * (1.0 - shield_modifier * 0.1)
	result.is_shield_hit = current_shield_strength > 0
	result.is_destabilized = result.actual_damage > ship_stats.hull_hitpoints * 0.1

	return result

func calculate_impact_angle(impact_point: Vector3, impact_normal: Vector3) -> float:
	"""Calculate the angle of impact for armor calculation"""
	# Simplified implementation - would use actual ship geometry
	return 0.0

func apply_subsystem_damage(damage: Dictionary, impact_point: Vector3) -> void:
	"""Apply damage to specific subsystems based on impact location"""
	for subsystem_name in damage.keys():
		var subsystem_damage = damage[subsystem_name]
		if subsystem_name in subsystem_damage_status:
			subsystem_damage_status[subsystem_name] = min(1.0, subsystem_damage_status[subsystem_name] + subsystem_damage)

	# Update system status based on subsystem damage
	update_system_status_from_subsystems()

func update_system_status_from_subsystems() -> void:
	"""Update main system status based on subsystem damage"""
	if not ship_stats or not species_data:
		return

	var total_damage_percentage = 0.0
	var damage_count = 0

	for subsystem_damage in subsystem_damage_status.values():
		total_damage_percentage += subsystem_damage
		damage_count += 1

	var average_damage = total_damage_percentage / max(damage_count, 1.0)

	# Update main systems based on overall damage
	systems_online = average_damage < 0.9
	shield_generators_online = average_damage < 0.7
	weapon_systems_online = average_damage < 0.8
	engine_systems_online = average_damage < 0.6 # Engines fail fastest
	life_support_online = average_damage < 0.5
	sensors_online = average_damage < 0.3
	communications_online = average_damage < 0.2

# Ship systems management
func update_ai_behavior(delta: float, target_info: Dictionary) -> void:
	"""Update AI behavior based on species and ship characteristics"""
	if not species_data:
		return

	performance_stats["ai_calculations"] += 1

	# Base behavior on species characteristics
	var aggression_level = species_data.ai_aggressiveness
	var skill_level = species_data.ai_skill_level
	var optimal_range = species_data.preferred_combat_range

	# Modify behavior based on ship damage
	var damage_factor = 1.0 - (current_hitpoints / max(ship_stats.hull_hitpoints, 1.0))
	aggression_level *= (1.0 - damage_factor * 0.5) # Damage reduces aggression

	# Implement AI behavior logic here
	pass

func update_weapon_systems(delta: float) -> void:
	"""Update all weapon systems based on TRES data"""
	if not weapon_systems_online:
		return

	for weapon_system in weapon_systems:
		weapon_system.update(delta)

func update_shield_regeneration(delta: float) -> void:
	"""Update shield regeneration based on TRES data"""
	if not shield_generators_online:
		return

	var regen_rate = ship_stats.shield_regen_rate
	var max_shields = ship_stats.shield_strength

	current_shield_strength = min(max_shields, current_shield_strength + regen_rate * delta)

func update_energy_management(delta: float) -> void:
	"""Update weapon energy regeneration based on TRES data"""
	if not engine_systems_online:
		return

	var energy_regen = ship_stats.energy_regen_rate
	var max_energy = ship_stats.max_weapon_energy

	current_weapon_energy = min(max_energy, current_weapon_energy + energy_regen * delta)

# Physics and movement
func update_physics_data(delta: float, input_state: Dictionary) -> ShipPhysicsUpdate:
	"""Update physics based on TRES ship characteristics"""
	if not physics_data or not engine_systems_online:
		return ShipPhysicsUpdate.new()

	performance_stats["physics_updates"] += 1

	var physics_update = ShipPhysicsUpdate.new()
	physics_update.delta_time = delta
	physics_update.input_thrust = input_state.get("thrust", 0.0)
	physics_update.input_roll = input_state.get("roll", 0.0)
	physics_update.input_pitch = input_state.get("pitch", 0.0)
	physics_update.input_yaw = input_state.get("yaw", 0.0)

	# Use TRES data for limits
	physics_update.max_velocity = ship_stats.max_velocity
	physics_update.max_angular_velocity = Vector3(
		360.0 / max(ship_stats.rotation_time.x, 0.001),
		360.0 / max(ship_stats.rotation_time.y, 0.001),
		360.0 / max(ship_stats.rotation_time.z, 0.001)
	)

	return physics_update

func update_visual_effects(delta: float) -> void:
	"""Update all visual effects based on current state"""
	if not visual_instance:
		return

	# Update shield effects
	if shield_effect:
		update_shield_visual_effect()

	# Update engine trail effects
	if engine_trail_effect:
		update_engine_trail_effect()

	# Update damage effects
	update_damage_effects()

func update_shield_visual_effect() -> void:
	"""Update shield visual effect based on shield strength"""
	if not shield_effect:
		return

	var shield_percentage = current_shield_strength / max(ship_stats.shield_strength, 1.0)
	var is_active = shield_percentage > 0.1 and shield_generators_online

	# Update shader parameters, particle effects, etc.
	pass

func update_engine_trail_effect() -> void:
	"""Update engine trail based on current thrust"""
	if not engine_trail_effect:
		return

	# Update trail opacity, length, color based on thrust percentage
	pass

func update_damage_effects() -> void:
	"""Update damage spark effects based on damage recentness"""
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last_damage = current_time - last_damage_time

	if time_since_last_damage < 2.0: # Show effects for 2 seconds after damage
		# Show spark effects
		pass

# Navigation and targeting (TRES-based)
func calculate_targeting_solution(target_info: Dictionary) -> Dictionary:
	"""Calculate targeting solution based on TRES weapon and ship data"""
	if not weapon_systems_online or weapon_systems.is_empty():
		return {"valid": false, "error": "No weapon systems available"}

	var solution = {
		"valid": true,
		"weapon_solutions": {},
		"optimal_weapon": "",
		"engagement_range": 0.0,
		"hit_probability": 0.0
	}

	for weapon_system in weapon_systems:
		var weapon_solution = calculate_weapon_targeting_solution(weapon_system, target_info)
		solution.weapon_solutions[weapon_system.weapon_class] = weapon_solution

	# Find optimal weapon based on TRES data
	solution.optimal_weapon = find_optimal_weapon_for_target(target_info, solution.weapon_solutions)

	return solution

func calculate_weapon_targeting_solution(weapon_system: WeaponSystem, target_info: Dictionary) -> Dictionary:
	"""Calculate targeting solution for specific weapon"""
	if not weapon_system.weapon_data:
		return {"valid": false, "error": "No weapon data"}

	var weapon_data = weapon_system.weapon_data
	var range_factor = 1.0 - (current_position.distance_to(target_info.position) / weapon_data.range_meters)
	var velocity_factor = min(1.0, target_info.velocity.length() / weapon_data.velocity_mps)
	var skill_factor = 1.0 # Would use pilot skill

	var hit_probability = range_factor * velocity_factor * skill_factor

	return {
		"valid": true,
		"range_factor": range_factor,
		"velocity_factor": velocity_factor,
		"hit_probability": hit_probability,
		"expected_damage": weapon_data.base_damage_energy * hit_probability
	}

func find_optimal_weapon_for_target(target_info: Dictionary, weapon_solutions: Dictionary) -> String:
	"""Find the best weapon for the target based on TRES data"""
	var best_weapon = ""
	var best_score = 0.0

	for weapon_name in weapon_solutions.keys():
		var solution = weapon_solutions[weapon_name]
		if solution.hit_probability > best_score:
			best_score = solution.hit_probability
			best_weapon = weapon_name

	return best_weapon

# API for external systems
func get_ship_status() -> Dictionary:
	"""Get comprehensive ship status"""
	return {
		"instance_id": instance_id,
		"ship_class": ship_class,
		"position": current_position,
		"velocity": current_velocity,
		"rotation": current_rotation,
		"hitpoints": {
			"current": current_hitpoints,
			"maximum": ship_stats.hull_hitpoints if ship_stats else 0,
			"percentage": float(current_hitpoints) / max(ship_stats.hull_hitpoints if ship_stats else 1, 1.0)
		},
		"shields": {
			"current": current_shield_strength,
			"maximum": ship_stats.shield_strength if ship_stats else 0,
			"percentage": current_shield_strength / max(ship_stats.shield_strength if ship_stats else 1, 1.0)
		},
		"energy": {
			"weapon_energy": current_weapon_energy,
			"afterburner_fuel": current_afterburner_fuel
		},
		"systems": {
			"systems_online": systems_online,
			"shields_online": shield_generators_online,
			"weapons_online": weapon_systems_online,
			"engines_online": engine_systems_online,
			"life_support_online": life_support_online,
			"sensors_online": sensors_online,
			"communications_online": communications_online
		},
		"facilities": species_data.species_name if species_data else "Unknown",
		"performance_stats": performance_stats.duplicate(true),
		"last_access": last_access_time
	}

func get_weapon_systems() -> Array[WeaponSystem]:
	"""Get all weapon systems"""
	return weapon_systems.duplicate(true)

func get_animation_data() -> Dictionary:
	"""Get POF-based animation data"""
	if not ship_stats or not ship_stats.model_file:
		return {}

	# This would load actual POF geometry and skeletal data
	return {
		"model_path": ship_stats.model_file,
		"animation_banks": [],
		"subsystem_objects": ship_stats.subsystem_hitpoints.keys() if ship_stats else []
	}

func is_alive() -> bool:
	"""Check if ship is still functional"""
	return current_hitpoints > 0 and systems_online and life_support_online

func is_heavily_damaged() -> bool:
	"""Check if ship is heavily damaged based on various criteria"""
	var hull_percentage = float(current_hitpoints) / max(ship_stats.hull_hitpoints if ship_stats else 1, 1.0)
	var system_damage = 1.0 - (bool_array_to_int([systems_online, shield_generators_online, weapon_systems_online, engine_systems_online]) / 4.0)

	return hull_percentage < 0.25 or system_damage > 0.5

func bool_array_to_int(bool_array: Array) -> int:
	"""Convert boolean array to integer count"""
	var count = 0
	for value in bool_array:
		if value:
			count += 1
	return count

func _ready() -> void:
	"""Initialize ship instance"""
	last_access_time = Time.get_unix_time_from_system()

func _process(delta: float) -> void:
	"""Update ship instance"""
	frame_count += 1
	update_frame_count += 1

	# Update TRES-based systems
	update_shield_regeneration(delta)
	update_energy_management(delta)
	update_visual_effects(delta)

	# Update last access time
	last_access_time = Time.get_unix_time_from_system()

func _physics_process(delta: float) -> void:
	"""Physics updates for ship instance"""
	if engine_systems_online:
		update_physics_data(delta, {})

func _exit_tree() -> void:
	"""Cleanup ship instance"""
	# Cleanup visual effects
	if shield_effect:
		shield_effect.queue_free()
	if engine_trail_effect:
		engine_trail_effect.queue_free()
	for effect in weapon_flash_effects + damage_spark_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	weapon_flash_effects.clear()
	damage_spark_effects.clear()