extends Node3D

## Mock target for testing HUD-008 multi-target tracking components
## Provides all the methods and properties expected by the tracking system

var target_type: String = "fighter"
var relationship: String = "hostile"
var threat_level: float = 0.5
var hull_percentage: float = 100.0
var shield_percentage: float = 100.0
var velocity: Vector3 = Vector3.ZERO
var radar_cross_section: float = 100.0
var is_stealth_mode: bool = false
var jamming_strength: float = 0.0
var weapon_systems: Array[String] = ["laser", "missile"]
var disabled_subsystems: Array[String] = []

## Setup mock target with basic parameters
func setup_mock_target(type: String, rel: String, threat: float):
	target_type = type
	relationship = rel
	threat_level = threat
	
	# Set appropriate defaults based on type
	match type:
		"fighter":
			radar_cross_section = 100.0
			weapon_systems = ["laser", "missile"]
		"bomber":
			radar_cross_section = 300.0
			weapon_systems = ["torpedo", "bomb"]
		"capital":
			radar_cross_section = 10000.0
			weapon_systems = ["beam", "flak", "torpedo"]
		"missile":
			radar_cross_section = 10.0
			weapon_systems = []

## Required methods for tracking system integration

func get_target_global_position() -> Vector3:
	return global_position

func get_velocity() -> Vector3:
	return velocity

func get_object_type() -> String:
	return target_type

func get_ship_name() -> String:
	return name

func get_ship_type() -> String:
	return target_type

func get_hull_percentage() -> float:
	return hull_percentage

func get_shield_percentage() -> float:
	return hull_percentage

func get_radar_cross_section() -> float:
	return radar_cross_section

func is_hostile_to_ship(player_ship: Node) -> bool:
	return relationship == "hostile"

func is_friendly_to_ship(player_ship: Node) -> bool:
	return relationship == "friendly"

func is_stealthed() -> bool:
	return is_stealth_mode

func get_ecm_strength() -> float:
	return jamming_strength

func get_weapon_systems() -> Array[String]:
	return weapon_systems

func is_actively_emitting() -> bool:
	return not is_stealth_mode

func get_visual_signature() -> Dictionary:
	return {
		"features": ["generic_ship", target_type],
		"size_class": _get_size_class()
	}

func _get_size_class() -> String:
	match target_type:
		"missile":
			return "tiny"
		"fighter":
			return "small"
		"bomber":
			return "medium"
		"capital":
			return "large"
		_:
			return "medium"

func respond_to_iff() -> Dictionary:
	return {
		"code": _get_iff_code(),
		"authenticity": 0.9
	}

func _get_iff_code() -> String:
	match relationship:
		"friendly":
			return "FREN001"
		"hostile":
			return "HOST001"
		_:
			return "UNKN001"

## Simulation methods for testing

func simulate_movement(delta: float):
	# Simple linear movement for testing
	global_position += velocity * delta

func simulate_damage(damage_amount: float):
	hull_percentage = max(0.0, hull_percentage - damage_amount)
	
	# Simulate subsystem damage
	if hull_percentage < 50.0 and disabled_subsystems.is_empty():
		disabled_subsystems.append("weapons")
	
	if hull_percentage < 25.0 and "engines" not in disabled_subsystems:
		disabled_subsystems.append("engines")

func simulate_shield_damage(damage_amount: float):
	shield_percentage = max(0.0, shield_percentage - damage_amount)

func set_stealth_mode(enabled: bool):
	is_stealth_mode = enabled
	if enabled:
		radar_cross_section *= 0.1
	else:
		radar_cross_section *= 10.0

func set_jamming_strength(strength: float):
	jamming_strength = clamp(strength, 0.0, 1.0)

func change_relationship(new_relationship: String):
	relationship = new_relationship

func add_weapon_system(weapon: String):
	if weapon not in weapon_systems:
		weapon_systems.append(weapon)

func remove_weapon_system(weapon: String):
	weapon_systems.erase(weapon)

func disable_subsystem(subsystem: String):
	if subsystem not in disabled_subsystems:
		disabled_subsystems.append(subsystem)

func repair_subsystem(subsystem: String):
	disabled_subsystems.erase(subsystem)

## Additional properties for advanced testing

var custom_properties: Dictionary = {}

func set_custom_property(key: String, value):
	custom_properties[key] = value

func get_custom_property(key: String, default_value = null):
	return custom_properties.get(key, default_value)

func has_custom_property(key: String) -> bool:
	return custom_properties.has(key)