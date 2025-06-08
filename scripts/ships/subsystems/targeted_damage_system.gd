class_name TargetedDamageSystem
extends Node

## SHIP-010 AC2: Targeted Damage System
## Allows precise subsystem targeting with hit location calculations and penetration mechanics
## Provides WCS-authentic subsystem targeting for tactical combat depth

# EPIC-002 Asset Core Integration
const SubsystemTypes = preload("res://addons/wcs_asset_core/constants/subsystem_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

# Signals
signal subsystem_targeted(target_ship: Node, subsystem_name: String, hit_probability: float)
signal subsystem_hit_calculated(target_ship: Node, subsystem_name: String, hit_location: Vector3, penetration_chance: float)
signal targeted_damage_applied(target_ship: Node, subsystem_name: String, damage_amount: float)

# Subsystem location and targeting data
var subsystem_locations: Dictionary = {}  # ship -> {subsystem_name -> Vector3}
var subsystem_sizes: Dictionary = {}      # ship -> {subsystem_name -> float (radius)}
var subsystem_armor: Dictionary = {}      # ship -> {subsystem_name -> float (armor thickness)}
var targeting_priorities: Dictionary = {} # ship -> {subsystem_name -> float (priority)}

# Targeting configuration
@export var hit_calculation_enabled: bool = true
@export var penetration_mechanics_enabled: bool = true
@export var debug_visualization: bool = false
@export var targeting_accuracy_modifier: float = 1.0

# Hit location calculation parameters
@export var base_hit_variance: float = 0.5    # Base targeting variance in meters
@export var distance_variance_factor: float = 0.01  # Additional variance per 100m distance
@export var subsystem_size_modifier: float = 0.8    # Larger subsystems easier to hit

# Penetration calculation parameters
@export var armor_penetration_base: float = 1.0
@export var angle_penetration_factor: float = 0.7   # Impact angle affects penetration
@export var weapon_penetration_factors: Dictionary = {
	DamageTypes.Type.KINETIC: 1.2,
	DamageTypes.Type.ENERGY: 0.9,
	DamageTypes.Type.EXPLOSIVE: 1.5,
	DamageTypes.Type.PLASMA: 1.1
}

# Debug visualization
var debug_draw_enabled: bool = false
var hit_markers: Array[Node3D] = []

func _ready() -> void:
	_setup_default_targeting_priorities()

## Initialize targeted damage system for a ship
func initialize_for_ship(ship: Node) -> void:
	if not subsystem_locations.has(ship):
		subsystem_locations[ship] = {}
		subsystem_sizes[ship] = {}
		subsystem_armor[ship] = {}
		targeting_priorities[ship] = {}

## Register subsystem location and targeting properties
func register_subsystem_location(ship: Node, subsystem_name: String, location: Vector3, size: float = 1.0, armor_thickness: float = 1.0) -> bool:
	if not ship:
		push_error("TargetedDamageSystem: Cannot register subsystem for null ship")
		return false
	
	if subsystem_name.is_empty():
		push_error("TargetedDamageSystem: Cannot register subsystem with empty name")
		return false
	
	initialize_for_ship(ship)
	
	subsystem_locations[ship][subsystem_name] = location
	subsystem_sizes[ship][subsystem_name] = size
	subsystem_armor[ship][subsystem_name] = armor_thickness
	
	# Set default priority based on subsystem type
	var subsystem_manager = ship.get_node_or_null("SubsystemManager")
	if subsystem_manager and subsystem_manager.has_method("get_subsystem_type"):
		var subsystem_type = subsystem_manager.get_subsystem_type(subsystem_name)
		targeting_priorities[ship][subsystem_name] = _get_default_priority(subsystem_type)
	else:
		targeting_priorities[ship][subsystem_name] = 1.0
	
	return true

## Calculate targeted damage for a specific subsystem
func calculate_targeted_damage(attacker_ship: Node, target_ship: Node, subsystem_name: String, 
								base_damage: float, damage_type: int, weapon_accuracy: float = 1.0) -> Dictionary:
	var result: Dictionary = {
		"hit": false,
		"damage_applied": 0.0,
		"hit_location": Vector3.ZERO,
		"penetration_success": false,
		"accuracy_modifier": 1.0
	}
	
	if not _validate_targeting_parameters(target_ship, subsystem_name):
		return result
	
	# Calculate hit probability
	var hit_data = _calculate_hit_probability(attacker_ship, target_ship, subsystem_name, weapon_accuracy)
	result["hit"] = hit_data["hit"]
	result["hit_location"] = hit_data["hit_location"]
	result["accuracy_modifier"] = hit_data["accuracy_modifier"]
	
	if not result["hit"]:
		return result
	
	# Calculate penetration mechanics
	var penetration_data = _calculate_penetration_mechanics(attacker_ship, target_ship, subsystem_name, 
															damage_type, hit_data["hit_location"])
	result["penetration_success"] = penetration_data["success"]
	
	if not result["penetration_success"]:
		# Partial damage for failed penetration
		result["damage_applied"] = base_damage * 0.1  # 10% damage for failed penetration
	else:
		# Full damage with penetration modifier
		result["damage_applied"] = base_damage * penetration_data["damage_modifier"]
	
	# Emit targeting signals
	subsystem_targeted.emit(target_ship, subsystem_name, hit_data["hit_probability"])
	subsystem_hit_calculated.emit(target_ship, subsystem_name, result["hit_location"], 
								  penetration_data["penetration_chance"])
	
	if result["damage_applied"] > 0.0:
		targeted_damage_applied.emit(target_ship, subsystem_name, result["damage_applied"])
	
	# Apply debug visualization
	if debug_visualization:
		_add_hit_visualization(target_ship, result["hit_location"], result["penetration_success"])
	
	return result

## Get available subsystems for targeting on a ship
func get_targetable_subsystems(ship: Node) -> Array[String]:
	if not subsystem_locations.has(ship):
		return []
	
	var subsystems: Array[String] = []
	for subsystem_name in subsystem_locations[ship].keys():
		subsystems.append(subsystem_name)
	
	# Sort by targeting priority (highest first)
	subsystems.sort_custom(func(a: String, b: String) -> bool:
		var priority_a = targeting_priorities[ship].get(a, 1.0)
		var priority_b = targeting_priorities[ship].get(b, 1.0)
		return priority_a > priority_b
	)
	
	return subsystems

## Get best subsystem target based on tactical priorities
func get_best_subsystem_target(attacker_ship: Node, target_ship: Node, tactical_preference: String = "balanced") -> String:
	var available_subsystems = get_targetable_subsystems(target_ship)
	if available_subsystems.is_empty():
		return ""
	
	var best_subsystem: String = ""
	var best_score: float = 0.0
	
	for subsystem_name in available_subsystems:
		var score = _calculate_targeting_score(attacker_ship, target_ship, subsystem_name, tactical_preference)
		if score > best_score:
			best_score = score
			best_subsystem = subsystem_name
	
	return best_subsystem

## Calculate subsystem targeting score for AI decision making
func _calculate_targeting_score(attacker_ship: Node, target_ship: Node, subsystem_name: String, tactical_preference: String) -> float:
	var base_priority = targeting_priorities[target_ship].get(subsystem_name, 1.0)
	var hit_data = _calculate_hit_probability(attacker_ship, target_ship, subsystem_name, 1.0)
	var hit_chance = hit_data["hit_probability"]
	
	# Get subsystem health if available
	var health_factor: float = 1.0
	var subsystem_manager = target_ship.get_node_or_null("SubsystemHealthManager")
	if subsystem_manager and subsystem_manager.has_method("get_subsystem_health_percentage"):
		var health_pct = subsystem_manager.get_subsystem_health_percentage(subsystem_name)
		health_factor = health_pct if health_pct > 0.0 else 0.1
	
	var score = base_priority * hit_chance * health_factor
	
	# Apply tactical preference modifiers
	match tactical_preference:
		"disable":
			# Prefer engines and weapons
			if subsystem_name.contains("Engine") or subsystem_name.contains("Weapon"):
				score *= 1.5
		"destroy":
			# Prefer hull and critical systems
			if subsystem_name.contains("Hull") or subsystem_name.contains("Reactor"):
				score *= 1.3
		"capture":
			# Avoid critical systems, prefer weapons
			if subsystem_name.contains("Reactor") or subsystem_name.contains("Hull"):
				score *= 0.5
			elif subsystem_name.contains("Weapon"):
				score *= 1.2
		"balanced":
			# No modification
			pass
	
	return score

## Calculate hit probability and location for subsystem targeting
func _calculate_hit_probability(attacker_ship: Node, target_ship: Node, subsystem_name: String, weapon_accuracy: float) -> Dictionary:
	var subsystem_location = subsystem_locations[target_ship][subsystem_name]
	var subsystem_size = subsystem_sizes[target_ship][subsystem_name]
	
	# Calculate distance between ships
	var distance = attacker_ship.global_position.distance_to(target_ship.global_position)
	
	# Base accuracy calculation
	var distance_modifier = max(0.1, 1.0 - (distance * 0.001))  # Accuracy drops with distance
	var size_modifier = min(2.0, 1.0 + (subsystem_size * subsystem_size_modifier))
	var total_accuracy = weapon_accuracy * distance_modifier * size_modifier * targeting_accuracy_modifier
	
	# Calculate hit variance
	var hit_variance = base_hit_variance + (distance * distance_variance_factor)
	
	# Generate hit location with variance
	var target_position = target_ship.global_position + target_ship.global_transform.basis * subsystem_location
	var variance_offset = Vector3(
		randf_range(-hit_variance, hit_variance),
		randf_range(-hit_variance, hit_variance),
		randf_range(-hit_variance, hit_variance)
	)
	var hit_location = target_position + variance_offset
	
	# Determine if hit succeeds based on accuracy and variance
	var hit_distance = variance_offset.length()
	var hit_threshold = subsystem_size * (total_accuracy * 2.0)  # Larger threshold with better accuracy
	var hit_success = hit_distance <= hit_threshold
	
	# Calculate final hit probability
	var hit_probability = min(0.95, total_accuracy * (hit_threshold / max(hit_distance, 0.1)))
	
	return {
		"hit": hit_success,
		"hit_probability": hit_probability,
		"hit_location": hit_location,
		"accuracy_modifier": total_accuracy,
		"distance": distance,
		"variance": hit_variance
	}

## Calculate armor penetration mechanics
func _calculate_penetration_mechanics(attacker_ship: Node, target_ship: Node, subsystem_name: String, 
									  damage_type: int, hit_location: Vector3) -> Dictionary:
	if not penetration_mechanics_enabled:
		return {"success": true, "penetration_chance": 1.0, "damage_modifier": 1.0}
	
	var subsystem_armor_thickness = subsystem_armor[target_ship].get(subsystem_name, 1.0)
	var weapon_penetration = weapon_penetration_factors.get(damage_type, 1.0)
	
	# Calculate impact angle
	var subsystem_world_location = target_ship.global_position + target_ship.global_transform.basis * subsystem_locations[target_ship][subsystem_name]
	var impact_direction = (hit_location - attacker_ship.global_position).normalized()
	var surface_normal = (subsystem_world_location - target_ship.global_position).normalized()
	var impact_angle = impact_direction.dot(surface_normal)
	
	# Angle modifier (perpendicular hits penetrate better)
	var angle_modifier = lerp(angle_penetration_factor, 1.0, abs(impact_angle))
	
	# Calculate penetration chance
	var penetration_power = armor_penetration_base * weapon_penetration * angle_modifier
	var armor_resistance = subsystem_armor_thickness
	var penetration_chance = min(0.95, penetration_power / armor_resistance)
	
	# Determine if penetration succeeds
	var penetration_success = randf() <= penetration_chance
	
	# Calculate damage modifier based on penetration quality
	var damage_modifier = 1.0
	if penetration_success:
		# Better penetration = more damage
		damage_modifier = lerp(0.8, 1.5, penetration_chance)
	else:
		# Failed penetration = reduced damage
		damage_modifier = 0.1
	
	return {
		"success": penetration_success,
		"penetration_chance": penetration_chance,
		"damage_modifier": damage_modifier,
		"impact_angle": impact_angle,
		"penetration_power": penetration_power,
		"armor_resistance": armor_resistance
	}

## Validate targeting parameters
func _validate_targeting_parameters(target_ship: Node, subsystem_name: String) -> bool:
	if not target_ship:
		push_warning("TargetedDamageSystem: Cannot target null ship")
		return false
	
	if not subsystem_locations.has(target_ship):
		push_warning("TargetedDamageSystem: Ship not registered for targeting: %s" % target_ship.name)
		return false
	
	if not subsystem_locations[target_ship].has(subsystem_name):
		push_warning("TargetedDamageSystem: Subsystem not found for targeting: %s on %s" % [subsystem_name, target_ship.name])
		return false
	
	return true

## Setup default targeting priorities based on subsystem types
func _setup_default_targeting_priorities() -> void:
	# Higher priority = more attractive target
	# These match WCS tactical targeting preferences
	pass

## Get default priority for subsystem type
func _get_default_priority(subsystem_type: int) -> float:
	match subsystem_type:
		SubsystemTypes.Type.WEAPONS, SubsystemTypes.Type.TURRET:
			return 1.2  # High priority - disable enemy firepower
		SubsystemTypes.Type.ENGINE:
			return 1.0  # Medium priority - disable mobility
		SubsystemTypes.Type.RADAR:
			return 0.8  # Medium-low priority - disable targeting
		SubsystemTypes.Type.NAVIGATION:
			return 0.7  # Low priority - disable jump capability
		SubsystemTypes.Type.COMMUNICATION:
			return 0.5  # Lowest priority - disable coordination
		_:
			return 1.0

## Set targeting priority for specific subsystem
func set_subsystem_targeting_priority(ship: Node, subsystem_name: String, priority: float) -> bool:
	if not subsystem_locations.has(ship) or not subsystem_locations[ship].has(subsystem_name):
		return false
	
	targeting_priorities[ship][subsystem_name] = priority
	return true

## Get subsystem targeting information
func get_subsystem_targeting_info(ship: Node, subsystem_name: String) -> Dictionary:
	if not _validate_targeting_parameters(ship, subsystem_name):
		return {}
	
	return {
		"location": subsystem_locations[ship][subsystem_name],
		"size": subsystem_sizes[ship][subsystem_name],
		"armor": subsystem_armor[ship][subsystem_name],
		"priority": targeting_priorities[ship][subsystem_name],
		"world_location": ship.global_position + ship.global_transform.basis * subsystem_locations[ship][subsystem_name]
	}

## Add debug visualization for hit location
func _add_hit_visualization(target_ship: Node, hit_location: Vector3, penetration_success: bool) -> void:
	if not debug_draw_enabled:
		return
	
	# Create debug marker
	var marker = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.2
	marker.mesh = sphere_mesh
	
	# Color based on penetration success
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.GREEN if penetration_success else Color.RED
	material.emission = material.albedo_color * 0.5
	marker.material_override = material
	
	# Position and add to scene
	marker.global_position = hit_location
	target_ship.add_child(marker)
	hit_markers.append(marker)
	
	# Auto-remove after 3 seconds
	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(func(): 
		if marker and is_instance_valid(marker):
			marker.queue_free()
		hit_markers.erase(marker)
	)
	marker.add_child(timer)
	timer.start()

## Clear all debug visualizations
func clear_debug_visualizations() -> void:
	for marker in hit_markers:
		if marker and is_instance_valid(marker):
			marker.queue_free()
	hit_markers.clear()

## Get targeting statistics for analysis
func get_targeting_statistics(ship: Node) -> Dictionary:
	if not subsystem_locations.has(ship):
		return {}
	
	var stats = {
		"total_subsystems": subsystem_locations[ship].size(),
		"subsystem_priorities": targeting_priorities[ship].duplicate(),
		"average_size": 0.0,
		"average_armor": 0.0
	}
	
	if stats["total_subsystems"] > 0:
		var total_size = 0.0
		var total_armor = 0.0
		
		for subsystem_name in subsystem_locations[ship].keys():
			total_size += subsystem_sizes[ship][subsystem_name]
			total_armor += subsystem_armor[ship][subsystem_name]
		
		stats["average_size"] = total_size / stats["total_subsystems"]
		stats["average_armor"] = total_armor / stats["total_subsystems"]
	
	return stats