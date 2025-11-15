# Nebula environmental effects and configurations
# Defines gas cloud properties, effects, and tactical considerations
class_name NebulaData
extends WCSDataResource

# Basic nebula properties
@export var nebula_name: String = ""
@export var nebula_type: int = 0  # 0=Gas Cloud, 1=Asteroid Field, 2=Dust, 3=Ion Storm
@export var primary_gas: String = "" # Cross-reference to chemistry data
@export var gas_density: float = 0.5  # 0.0-1.0 density scale
@export var visual_opacity: float = 0.3  # 0.0-1.0 visibility obstruction
@export var color_tint: Color = Color(0.8, 0.6, 0.4, 0.3)  # Atmospheric color

# Physical effects on ships
@export var max_velocity_reduction: float = 0.2  # Percent of normal speed
@export var maneuverability_reduction: float = 0.3  # Percent of normal maneuvering
@export var shield_effectiveness_modifier: float = 0.9  # 1.0=full effectiveness
@export var weapon_range_modifier: float = 0.8  # Percent of normal range
@export var energy_drain_rate: float = 0.02  # Energy per second drain

# Sensor and communication effects
@export var sensor_range_modifier: float = 0.5  # Radar/contact range reduction
@export var communication_interference: float = 0.7  # 0.0-1.0 comm disruption
@export var stealth_bonus: float = 0.5  # Additional stealth effectiveness
@export var miss_tracking_modifier: float = 0.6  # Missile guidance interference

# Tactical properties
@export var makes_ships_invisible: bool = false  # Complete cloak from sensors
@export var damps_shields: bool = false  # Actively drains shields
@export var scrambles_weapons: bool = false  # Causes weapon malfunctions
@export var blocks_beams: bool = false  # Stops beam weapon transmission
@export var collision_damage_nebula: bool = false  # Causes hull damage

# Visual effects
@export var fog_effect: String = "" # Cross-reference to particle system resource
@export var particle_effect: String = "" # Cross-reference to particle system resource
@export var lightning_effect: String = "" # Cross-reference to effect for ion storms
@export var particle_density: int = 50  # Particles per cubic meter
@export var wind_velocity: Vector3 = Vector3.ZERO  # Movement vector
@export var turbulence_strength: float = 0.2  # 0.0-1.0 movement chaos

# Environmental hazards
@export var radiation_damage: float = 0.0  # Hull damage per second
@export var shield_damage_rate: float = 0.0  # Shield drain per second
@export var electrical_damage_chance: float = 0.01  # Per second subsystems damage chance
@export var hull_tracker_damage: float = 0.05  # Armor degradation per second

# Navigation hazards
@export var debris_density: float = 0.0  # Collision chance modifier
@export var gravitational_anomalies: bool = false  # Random acceleration effects
@export var magnetic_disturbances: bool = false  # Navigation system interference

func get_tactical_severity() -> float:
	"""Calculate overall tactical impact severity (0.0-1.0)"""
	var severity = 0.0

	# Movement penalties
	severity += max_velocity_reduction * 0.2
	severity += maneuverability_reduction * 0.2

	# Combat penalties
	severity += (1.0 - weapon_range_modifier) * 0.15
	severity += (1.0 - shield_effectiveness_modifier) * 0.15
	severity += (1.0 - sensor_range_modifier) * 0.15

	# Severe penalties
	if makes_ships_invisible:
		severity += 0.4
	if damps_shields:
		severity += 0.3
	if blocks_beams:
		severity += 0.25

	# Environmental damage
	severity += clamp(radiation_damage / 5.0, 0.0, 0.3)
	severity += clamp(shield_damage_rate / 10.0, 0.0, 0.2)

	return clamp(severity, 0.0, 1.0)

func is_safe_for_prolonged_stay() -> bool:
	"""Determine if ships can operate safely for extended periods"""
	return radiation_damage < 1.0 and shield_damage_rate < 2.0 and electrical_damage_chance < 0.05

func get_visibility_concealment() -> float:
	"""Calculate how much the nebula conceals ship visibility"""
	var concealment = visual_opacity * 0.6
	concealment += (1.0 - sensor_range_modifier) * 0.4
	if makes_ships_invisible:
		concealment = 1.0  # Complete invisibility
	return clamp(concealment, 0.0, 1.0)

func apply_to_ship(ship_stats: ShipStats) -> Dictionary:
	"""
	Apply nebula effects to ship stats
	Returns modified stats dictionary for visual feedback
	"""
	var effects_applied = {
		"velocity_reduction": max_velocity_reduction,
		"maneuverability_reduction": maneuverability_reduction,
		"shield_modifier": shield_effectiveness_modifier,
		"range_modifier": weapon_range_modifier,
		"sensor_range_modifier": sensor_range_modifier,
		"energy_drain": energy_drain_rate
	}

	# Calculate actual modified values
	effects_applied["effective_velocity"] = ship_stats.max_velocity * (1.0 - effects_applied["velocity_reduction"])
	effects_applied["effective_shields"] = ship_stats.shield_strength * effects_applied["shield_modifier"]
	effects_applied["weapon_range"] = ship_stats.max_weapon_energy * effects_applied["range_modifier"]

	return effects_applied

func validate() -> bool:
	"""Validate nebula configuration"""
	validation_errors.clear()
	conversion_notes.clear()

	# Call parent validation
	if not super.validate():
		return false

	# Validate effect modifiers are reasonable
	var modifiers = [
		max_velocity_reduction, maneuverability_reduction, shield_effectiveness_modifier,
		weapon_range_modifier, sensor_range_modifier, visual_opacity
	]

	for modifier in modifiers:
		if modifier < 0.0 or modifier > 1.0:
			_add_validation_error("Effect modifiers must be between 0.0 and 1.0")
			break

	# Validate hazard rates are non-negative
	if radiation_damage < 0 or shield_damage_rate < 0 or electrical_damage_chance < 0:
		_add_validation_error("Damage rates cannot be negative")

	# Validate cross-references
	validate_effect_reference("fog_effect")
	validate_effect_reference("particle_effect")
	validate_effect_reference("lightning_effect")

	return validation_errors.size() == 0