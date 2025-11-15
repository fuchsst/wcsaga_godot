# NebulaData - Comprehensive Nebula Environmental Resource
# Represents gas cloud, ion storm, and space weather effects with detailed
# physics modeling and tactical impact analysis for Wing Commander Saga

class_name NebulaData
extends WCSBaseResource

# === BASIC NEBULA PROPERTIES ===
@export_group("Identity", "identity_")
@export var nebula_name: String = ""                     # Nebula designation/name
@export var nebula_classification: int = 0               # 0=Gas Cloud, 1=Ion Storm, 2=Dust Cloud, 3=Radiation Field
@export var primary_chemical_composition: String = ""     # Cross-reference to chemistry data
@export var secondary_chemical_composition: String = ""   # Cross-reference to chemistry data
@export var gas_density_normalized: float = 0.5           # 0.0-1.0 density scale
@export var visual_opacity_coefficient: float = 0.3       # 0.0-1.0 visibility obstruction
@export var nebula_tint_color: Color = Color(0.8, 0.6, 0.4, 0.3)  # Atmospheric color tint

# === SHIP PERFORMANCE IMPACT ===
@export_group("Ship Performance", "performance_")
@export var max_velocity_reduction: float = 0.2           # Percent reduction in maximum velocity
@export var maneuverability_reduction: float = 0.3        # Percent reduction in maneuverability
@export var shield_effectiveness_multiplier: float = 0.9  # Shield effectiveness multiplier
@export var weapon_range_modifier: float = 0.8            # Weapon range multiplier
@export var weapon_damage_modifier: float = 1.0           # Weapon damage multiplier
@export var energy_consumption_multiplier: float = 1.2     # Energy drain rate multiplier
@export var fuel_consumption_increase: float = 0.1        # Additional fuel consumption
@export var weapon_accuracy_penalty: float = 0.2          # Accuracy reduction (0.0-1.0)
@export var subsystem_performance_degradation: float = 0.1  # System efficiency reduction

# === SENSOR AND COMMUNICATION ===
@export_group("Sensors & Comms", "sensor_")
@export var radar_sensor_range_reduction: float = 0.5      # Radar/contact range reduction
@export var subspace_sensor_range_reduction: float = 0.3   # Subspace sensor interference
@export var target_lock_difficulty_increase: float = 0.4   # Difficulty acquiring target locks
@export var missile_tracking_interference: float = 0.6     # Missile guidance interference
@export var communications_interference_severity: float = 0.7  # Communication disruption
@export var stealth_effectiveness_boost: float = 0.5      # Additional stealth effectiveness
@export var electronic_warfare_interference: float = 0.3   # ECM/ECCM interference

# === SEVERE ENVIRONMENTAL EFFECTS ===
@export_group("Severe Effects", "severe_")
@export var causes_sensor_blackout: bool = false         # Complete sensor failure
@export var actively_drains_shields: bool = false        # Actively drains shield energy
@export var causes_weapon_malfunctions: bool = false     # Random weapon failures
@export var blocks_beam_weapons: bool = false            # Stops beam weapon transmission
@export var disrupts_navigation_systems: bool = false    # Causes navigation errors
@export var disables_shield_generators: bool = false     # Shields cannot regenerate
@export var affects_fighter_scale_only: bool = false     # Only affects smaller ships
@export var affects_capital_scale_only: bool = false     # Only affects capital ships

# === ENVIRONMENTAL DAMAGE ===
@export_group("Environmental Damage", "damage_")
@export var continuous_radiation_damage: float = 0.0     # Hull damage per second
@export var shield_drain_rate_per_second: float = 0.0    # Shield drain per second
@export var electrical_malfunction_rate: float = 0.01    # Per second subsystem malfunction chance
@export var armor_corrosion_rate: float = 0.0           # Armor degradation per second
@export var engine_degradation_rate: float = 0.0         # Engine efficiency loss per second
@export var exposure_accumulation_rate: float = 0.02     # Damage accumulation rate

# === WEATHER EFFECTS ===
@export_group("Space Weather", "weather_")
@export var ion_storm_intensity: float = 0.0             # Ion storm severity (0.0-1.0)
@export var electromagnetic_pulse_frequency: float = 0.0  # EMP events per minute
@export var cosmic_ray_intensity: float = 0.0            # High-energy particle flux
@export var solar_wind_modifier: float = 1.0             # Solar wind intensity multiplier
@export var magnetic_field_turbulence: float = 0.0       # Field disturbance level
@export var gravity_wave_disturbance: float = 0.0        # Gravitational fluctuations
@export var temporal_anomaly_severity: float = 0.0       # Time dilation effects

# === VISUAL EFFECTS ===
@export_group("Visual Effects", "visual_")
@export var particle_system_reference: String = ""       # Cross-reference to particle system
@export var fog_system_reference: String = ""            # Cross-reference to fog system
@export var lightning_effect_reference: String = ""      # Cross-reference to lightning effect
@export var electrical_discharge_reference: String = ""  # Cross-reference to discharge effect
@export var color_shift_intensity: float = 0.5           # Color distortion strength
@export var parallax_effect_strength: float = 0.3        # Visual depth effect
@export var particle_density_per_cubic_meter: int = 50   # Particle concentration
@export var particle_velocity_vector: Vector3 = Vector3.ZERO  # Constant particle motion
@export var turbulence_force_factor: float = 0.2         # Particle turbulence strength

# === TACTICAL IMPLICATIONS ===
@export_group("Tactical", "tactical_")
@export var ambush_effectiveness_bonus: float = 0.3      # Bonus to ambush success
@export var pursuit_difficulty_increase: float = 0.4      # Difficulty of pursuit
@export var formation_flying_penalty: float = 0.2         # Formation flying penalties
@export var tactical_retreat_penalty: float = 0.1         # Retreat difficulty
@export var resource_extraction_boost: float = 0.0        # Mining/survey bonuses
@export var anomaly_research_bonus: float = 0.5          # Scientific research bonuses
@export var navigation_hazard_multiplier: float = 1.5     # Plotting course difficulty

# === NAVIGATION HAZARDS ===
@export_group("Navigation", "nav_")
@export var asteroid_density_bonus: float = 0.0           # Additional asteroid chance
@export var gravity_well_interference: float = 0.0        # Hyperspace jump interference
@export var micro_debris_hazard: float = 0.0             # Micro-collision chance
@export var ionization_static_interference: float = 0.0   # Navigation system static
@export var localized_gravity_distortion: bool = false    # Gravity anomalies
@export var recommended_safety_margins: Array[String] = []     # Recommended protocols
@export var emergency_exit_routes: Array[Vector3] = []    # Safe exit vectors

# === PERFORMANCE AND SCALING ===
@export_group("Performance", "perf_")
@export var effect_rendering_distance_km: float = 5.0     # Max distance for effects
@export var particle_culling_distance_km: float = 3.0     # Distance beyond which particles culled
@export var lod_transition_distances: Array[float] = [1.0, 3.0, 8.0]  # Level of detail transitions
@export var physics_optimization_level: int = 2            # 0=Low, 1=Medium, 2=High, 3=Ultra
@export var cpu_performance_impact: float = 0.3            # Performance cost estimate
@export var gpu_performance_impact: float = 0.4            # Rendering cost estimate

# === FIELD GENERATION ===
@export_group("Generation", "gen_")
@export var nebula_generation_seed: int = 0               # Random generation seed
@export var turbulence_generation_method: int = 0          # 0=Simplex, 1=Perlin, 2=Cellular
@export var field_geometry_type: int = 0                  # 0=Spherical, 1=Toroidal, 2=Cylindrical, 3=Amorphous
@export var density_gradient_exponent: float = 1.0        # Falloff rate from center
@export var fractal_noise_octaves: int = 4                # Detail level for noise
@export var fractal_noise_frequency: float = 0.5          # Base frequency for noise

# Validation signals
signal weather_conditions_changed()
signal tactical_impact_changed()
signal visual_appearance_changed()
signal hazard_level_changed()

# ================== VALIDATION METHODS ==================

func get_resource_type() -> String:
	return "nebula_data"

func validate() -> bool:
	"""Comprehensive nebula validation with physics simulation"""
	validation_errors.clear()
	validation_warnings.clear()

	# Call parent validation first
	if not super.validate():
		return false

	# Validate basic properties
	_validate_basic_properties()
	_validate_ship_performance_impact()
	_validate_sensor_and_communication()
	_validate_severe_environmental_effects()
	_validate_environmental_damage()
	_validate_weather_effects()
	_validate_visual_effects()
	_validate_tactical_implications()
	_validate_navigation_hazards()
	_validate_performance_settings()
	_validate_generation_parameters()

	# Final validation status
	is_valid = validation_errors.size() == 0
	validation_status_changed.emit(is_valid)

	return is_valid

func _validate_basic_properties() -> void:
	"""Validate basic nebula properties"""
	if nebula_name.is_empty():
		_add_validation_warning("Nebula name not specified")

	if nebula_classification < 0 or nebula_classification > 3:
		_add_validation_error("Nebula classification must be between 0 and 3")

	if gas_density_normalized < 0 or gas_density_normalized > 1:
		_add_validation_error("Gas density must be between 0.0 and 1.0")

	if visual_opacity_coefficient < 0 or visual_opacity_coefficient > 1:
		_add_validation_error("Visual opacity coefficient must be between 0.0 and 1.0")

	# Validate chemical composition references
	if not primary_chemical_composition.is_empty():
		add_cross_reference_dependency(primary_chemical_composition)
	if not secondary_chemical_composition.is_empty():
		add_cross_reference_dependency(secondary_chemical_composition)

func _validate_ship_performance_impact() -> void:
	"""Validate ship performance impact parameters"""
	var impact_params = [
		max_velocity_reduction,
		maneuverability_reduction,
		weapon_accuracy_penalty,
		subsystem_performance_degradation
	]

	for param in impact_params:
		if param < 0 or param > 1:
			_add_validation_error("Performance impact parameters must be between 0.0 and 1.0")

	# Validate multipliers - can exceed 1.0 for extreme effects
	if shield_effectiveness_multiplier < 0:
		_add_validation_error("Shield effectiveness multiplier cannot be negative")

	if weapon_damage_modifier < 0:
		_add_validation_error("Weapon damage modifier cannot be negative")

	if energy_consumption_multiplier < 1:
		_add_validation_warning("Energy consumption multiplier should normally be >= 1.0")

	if fuel_consumption_increase < 0:
		_add_validation_error("Fuel consumption increase cannot be negative")

func _validate_sensor_and_communication() -> void:
	"""Validate sensor and communication interference"""
	var sensor_params = [
		radar_sensor_range_reduction,
		subspace_sensor_range_reduction,
		target_lock_difficulty_increase,
		missile_tracking_interference,
		communications_interference_severity,
		electronic_warfare_interference
	]

	for param in sensor_params:
		if param < 0 or param > 1:
			_add_validation_error("Sensor/communication parameters must be between 0.0 and 1.0")

	if stealth_effectiveness_boost < 0:
		_add_validation_error("Stealth effectiveness boost cannot be negative")

func _validate_severe_environmental_effects() -> void:
	"""Validate severe environmental effect flags"""
	# Check for conflicting flags
	if affects_fighter_scale_only and affects_capital_scale_only:
		_add_validation_error("Cannot affect only fighters and only capital ships simultaneously")

	# Validate flags against technology levels
	if has_cloaking_technology and nebula_classification != 2:
		_add_validation_warning("Advanced stealth technology may not be appropriate for all nebula types")

func _validate_environmental_damage() -> void:
	"""Validate environmental damage parameters"""
	var damage_params = [
		continuous_radiation_damage,
		shield_drain_rate_per_second,
		armor_corrosion_rate,
		engine_degradation_rate,
		exposure_accumulation_rate
	]

	for param in damage_params:
		if param < 0:
			_add_validation_error("Environmental damage parameters cannot be negative")

	# Validate malfunction rates
	if electrical_malfunction_rate < 0 or electrical_malfunction_rate > 1:
		_add_validation_error("Electrical malfunction rate must be between 0.0 and 1.0")

	# Warn about high damage values
	if continuous_radiation_damage > 5.0:
		_add_validation_warning("Very high radiation damage may make nebula unsurvivable")

func _validate_weather_effects() -> void:
	"""Validate space weather parameters"""
	var weather_params = [
		ion_storm_intensity,
		cosmic_ray_intensity,
		magnetic_field_turbulence,
		gravity_wave_disturbance
	]

	for param in weather_params:
		if param < 0 or param > 1:
			_add_validation_error("Weather effect parameters must be between 0.0 and 1.0")

	# Validate EMP frequency
	if electromagnetic_pulse_frequency < 0:
		_add_validation_error("Electromagnetic pulse frequency cannot be negative")

	if temporal_anomaly_severity < 0 or temporal_anomaly_severity > 1:
		_add_validation_error("Temporal anomaly severity must be between 0.0 and 1.0")

	if solar_wind_modifier < 0:
		_add_validation_error("Solar wind modifier cannot be negative")

func _validate_visual_effects() -> void:
"""Validate visual effect references"""
	var effect_refs = [
		particle_system_reference,
		fog_system_reference,
		lightning_effect_reference,
		electrical_discharge_reference
	]

	for effect_ref in effect_refs:
		if not effect_ref.is_empty():
			add_cross_reference_dependency(effect_ref)

	# Validate visual parameters
	if color_shift_intensity < 0 or color_shift_intensity > 1:
		_add_validation_error("Color shift intensity must be between 0.0 and 1.0")

	if parallax_effect_strength < 0 or parallax_effect_strength > 1:
		_add_validation_error("Parallax effect strength must be between 0.0 and 1.0")

	if particle_density_per_cubic_meter < 0:
		_add_validation_error("Particle density cannot be negative")

	if turbulence_force_factor < 0 or turbulence_force_factor > 1:
		_add_validation_error("Turbulence force factor must be between 0.0 and 1.0")

func _validate_tactical_implications() -> void:
	"""Validate tactical combat effects"""
	var tactical_params = [
		ambush_effectiveness_bonus,
		pursuit_difficulty_increase,
		formation_flying_penalty,
		tactical_retreat_penalty
	]

	for param in tactical_params:
		if param < 0 or param > 1:
			_add_validation_error("Tactical parameters must be between 0.0 and 1.0")

	if resource_extraction_boost < 0:
		_add_validation_error("Resource extraction boost cannot be negative")

	if anomaly_research_bonus < 0:
		_add_validation_error("Anomaly research bonus cannot be negative")

	if navigation_hazard_multiplier < 1:
		_add_validation_warning("Navigation hazard multiplier should normally be >= 1.0")

func _validate_navigation_hazards() -> void:
	"""Validate navigation hazard parameters"""
	var nav_hazards = [
		asteroid_density_bonus,
		gravity_well_interference,
		micro_debris_hazard,
		ionization_static_interference
	]

	for hazard in nav_hazards:
		if hazard < 0 or hazard > 1:
			_add_validation_error("Navigation hazard parameters must be between 0.0 and 1.0")

	# Validate emergency exit routes
	for exit_vector in emergency_exit_routes:
		if exit_vector.length() == 0:
			_add_validation_warning("Emergency exit route vector has zero length")

func _validate_performance_settings() -> void:
	"""Validate performance optimization settings"""
	if effect_rendering_distance_km <= 0:
		_add_validation_error("Effect rendering distance must be positive")

	if particle_culling_distance_km <= 0:
		_add_validation_error("Particle culling distance must be positive")

	if physics_optimization_level < 0 or physics_optimization_level > 3:
		_add_validation_error("Physics optimization level must be between 0 and 3")

	if cpu_performance_impact < 0 or cpu_performance_impact > 1:
		_add_validation_error("CPU performance impact must be between 0.0 and 1.0")

	if gpu_performance_impact < 0 or gpu_performance_impact > 1:
		_add_validation_error("GPU performance impact must be between 0.0 and 1.0")

	# Validate LOD transitions
	if lod_transition_distances.size() < 2:
		_add_validation_warning("At least 2 LOD transition distances recommended")

	for i in range(lod_transition_distances.size() - 1):
		if lod_transition_distances[i] >= lod_transition_distances[i + 1]:
			_add_validation_error("LOD transition distances must be in ascending order")

func _validate_generation_parameters() -> void:
	"""Validate field generation parameters"""
	valid_generation_methods = [0, 1, 2]
	if not turbulence_generation_method in valid_generation_methods:
		_add_validation_error("Turbulence generation method must be 0, 1, or 2")

	if field_geometry_type < 0 or field_geometry_type > 3:
		_add_validation_error("Field geometry type must be between 0 and 3")

	if density_gradient_exponent <= 0:
		_add_validation_error("Density gradient exponent must be positive")

	if fractal_noise_octaves < 1:
		_add_validation_error("Fractal noise octaves must be at least 1")

	if fractal_noise_frequency <= 0:
		_add_validation_error("Fractal noise frequency must be positive")

# ================== ENVIRONMENTAL IMPACT CALCULATION ==================

func calculate_environmental_impact(ship_stats: ShipStats) -> Dictionary:
	"""
	Calculate comprehensive environmental impact on a ship.

	Returns detailed impact analysis:
	{
		velocity_impact: float,
		maneuverability_impact: float,
		shield_impact: float,
		weapon_impact: float,
		sensor_impact: float,
		communication_impact: float,
		energy_drain_rate: float,
		fuel_drain_rate: float,
		damage_per_second: float,
		malfunction_chance_per_second: float,
		tactical_severity_score: float
	}
	"""
	var impact = {
		"velocity_impact": max_velocity_reduction,
		"maneuverability_impact": maneuverability_reduction,
		"shield_impact": 1.0 - shield_effectiveness_multiplier,
		"weapon_impact": 1.0 - weapon_range_modifier,
		"sensor_impact": 1.0 - radar_sensor_range_reduction,
		"communication_impact": communications_interference_severity,
		"energy_drain_rate": energy_consumption_multiplier,
		"fuel_drain_rate": fuel_consumption_increase,
		"damage_per_second": continuous_radiation_damage,
		"malfunction_chance_per_second": electrical_malfunction_rate,
		"tactical_severity_score": calculate_tactical_severity()
	}

	# Apply ship size modifiers
	if affects_fighter_scale_only:
		if ship_stats.ship_role == 0:  # Fighter
			pass  # Full effects
		else:
			# Reduce effects for larger ships
			var scale_factor = 0.3
			for key in impact.keys():
				if key != "tactical_severity_score":
					impact[key] *= scale_factor

	elif affects_capital_scale_only:
		if ship_stats.ship_role == 2:  # Capital
			pass  # Full effects
		else:
			# Reduce effects for smaller ships
			var scale_factor = 0.2
			for key in impact.keys():
				if key != "tactical_severity_score":
					impact[key] *= scale_factor

	return impact

func apply_damage_to_ship(ship_instance: Node3D, delta_time: float) -> Dictionary:
	"""Apply environmental damage to a ship over time"""
	var damage_applied = {
		"radiation_damage": 0.0,
		"shield_drain": 0.0,
		"subsystems_affected": [],
		"armor_corrosion": 0.0,
		"engine_degradation": 0.0
	}

	# Apply radiation damage
	if continuous_radiation_damage > 0:
		damage_applied["radiation_damage"] = continuous_radiation_damage * delta_time

	# Apply shield drain
	if shield_drain_rate_per_second > 0 and actively_drains_shields:
		damage_applied["shield_drain"] = shield_drain_rate_per_second * delta_time

	# Apply electrical malfunctions
	if electrical_malfunction_rate > 0:
		var malfunction_roll = randf()
		if malfunction_roll < electrical_malfunction_rate * delta_time:
			# Random subsystem malfunction occurred
			var subsystems = ["weapons", "engines", "sensors", "shields", "life_support"]
			var affected = subsystems[randi() % subsystems.size()]
			damage_applied["subsystems_affected"].append(affected)

	# Apply armor corrosion
	if armor_corrosion_rate > 0:
		damage_applied["armor_corrosion"] = armor_corrosion_rate * delta_time

	# Apply engine degradation
	if engine_degradation_rate > 0:
		damage_applied["engine_degradation"] = engine_degradation_rate * delta_time

	return damage_applied

func calculate_tactical_severity() -> float:
	"""Calculate overall tactical impact severity (0.0-1.0)"""
	var severity = 0.0

	# Movement penalties
	severity += max_velocity_reduction * 0.2
	severity += maneuverability_reduction * 0.2

	# Combat penalties
	severity += (1.0 - weapon_range_modifier) * 0.15
	severity += (1.0 - shield_effectiveness_multiplier) * 0.15
	severity += (1.0 - radar_sensor_range_reduction) * 0.15

	# Severe penalties
	var severe_penalty = 0.0
	if causes_sensor_blackout: severe_penalty += 0.4
	if actively_drains_shields: severe_penalty += 0.3
	if blocks_beam_weapons: severe_penalty += 0.25
	if disrupts_navigation_systems: severe_penalty += 0.2
	if disables_shield_generators: severe_penalty += 0.35

	severity += severe_penalty

	# Environmental damage
	severity += clamp(continuous_radiation_damage / 5.0, 0.0, 0.3)
	severity += clamp(shield_drain_rate_per_second / 10.0, 0.0, 0.2)

	# Weather effects
	severity += clamp(ion_storm_intensity * 0.15, 0.0, 0.15)
	severity += clamp(cosmic_ray_intensity * 0.1, 0.0, 0.1)

	return clamp(severity, 0.0, 1.0)

func get_visibility_concealment() -> float:
	"""Calculate combat concealment effectiveness (0.0-1.0)"""
	var concealment = visual_opacity_coefficient * 0.4
	concealment += (1.0 - radar_sensor_range_reduction) * 0.3
	concealment += stealth_effectiveness_boost * 0.3

	if causes_sensor_blackout:
		concealment = 1.0  # Complete invisibility

	return clamp(concealment, 0.0, 1.0)

func is_safe_for_prolonged_exposure() -> bool:
	"""Determine if ships can safely operate for extended periods"""
	return (continuous_radiation_damage < 0.5 and
		    shield_drain_rate_per_second < 1.0 and
		    electrical_malfunction_rate < 0.02 and
		    calculate_tactical_severity() < 0.4 and
		    not causes_sensor_blackout)

func get_recommended_ship_class() -> String:
	"""Get recommended ship class for this nebula"""
	var severity = calculate_tactical_severity()

	if severity > 0.7:
		return "Heavy Fighter, Bomber, or Capital Ship"
	elif severity > 0.5:
		return "Medium Fighter or Heavy Fighter"
	elif severity > 0.3:
		return "Light Fighter or Medium Fighter"
	else:
		return "Any Ship Class"

# ================== UTILITY METHODS ==================

func get_nebula_classification_name() -> String:
	"""Get human-readable nebula classification name"""
	var classifications = ["Gas Cloud", "Ion Storm", "Dust Cloud", "Radiation Field"]
	if nebula_classification >= 0 and nebula_classification < classifications.size():
		return classifications[nebula_classification]
	return "Unknown Nebula Type"

func get_weather_severity_description() -> String:
	"""Get human-readable weather severity description"""
	var weather_score = (ion_storm_intensity * 0.4 +
		                    cosmic_ray_intensity * 0.3 +
		                    magnetic_field_turbulence * 0.2 +
		                    temporal_anomaly_severity * 0.1)

	if weather_score > 0.7:
		return "Extreme Weather Conditions"
	elif weather_score > 0.5:
		return "Severe Weather Conditions"
	elif weather_score > 0.3:
		return "Moderate Weather Conditions"
	elif weather_score > 0.1:
		return "Mild Weather Conditions"
	else:
		return "Clear Conditions"

func generate_mission_briefing_impact() -> String:
	"""Generate mission briefing text about nebula impact"""
	var severity = calculate_tactical_severity()
	var classification = get_nebula_classification_name()
	var weather = get_weather_severity_description()

	var briefing = "Mission area contains %s conditions. " % classification
	briefing += "Environment severity: %.0f%%. " % (severity * 100)
	briefing += "Weather status: %s. " % weather

	if max_velocity_reduction > 0.3:
		briefing += "Expect reduced maneuverability. "

	if causes_sensor_blackout:
		briefing += "Complete sensor blackout anticipated. "

	if actively_drains_shields:
		briefing += "Active shield drain detected. "

	if continuous_radiation_damage > 1.0:
		briefing += "Radiation hazard present. "

	return briefing

func get_performance_impact_estimate() -> Dictionary:
	"""Get estimated performance impact of visual effects"""
	return {
		"cpu_impact": cpu_performance_impact,
		"gpu_impact": gpu_performance_impact,
		"total_impact": cpu_performance_impact + gpu_performance_impact,
		"category": "Moderate" if (cpu_performance_impact + gpu_performance_impact) < 0.7 else "High",
		"recommended_quality": "High" if (cpu_performance_impact + gpu_performance_impact) < 0.5 else "Medium"
	}

func create_environmental_report() -> Dictionary:
	"""Create comprehensive environmental report"""
	return {
		"nebula_info": {
			"name": nebula_name,
			"classification": get_nebula_classification_name(),
			"severity_score": calculate_tactical_severity(),
			"weather_conditions": get_weather_severity_description()
		},
		"ship_performance": {
			"velocity_reduction": max_velocity_reduction,
			"shield_effectiveness": shield_effectiveness_multiplier,
			"sensor_range": radar_sensor_range_reduction,
			"weapon_range": weapon_range_modifier
		},
		"hazards": {
			"environmental_damage_rate": continuous_radiation_damage,
			"shield_drain_rate": shield_drain_rate_per_second,
			"malfunction_probability": electrical_malfunction_rate,
			"safe_for_prolonged_exposure": is_safe_for_prolonged_exposure()
		},
		"tactical_implications": {
			"stealth_boost": stealth_effectiveness_boost,
			"ambush_bonus": ambush_effectiveness_bonus,
			"concealment_effectiveiveness": get_visibility_concealment(),
			"recommended_ship_class": get_recommended_ship_class()
		},
		"performance": get_performance_impact_estimate()
	}

func calculate_exposure_accumulated_damage(exposure_duration_seconds: float) -> float:
	"""Calculate total damage from exposure over time"""
	var base_exposure_damage = continuous_radiation_damage * exposure_duration_seconds
	var accumulated_factor = 1.0

	# Damage accumulates faster with exposure
	if exposure_accumulation_rate > 0:
		accumulated_factor = 1.0 + (exposure_accumulation_rate * exposure_duration_seconds)

	return base_exposure_damage * accumulated_factor

func is_mission_compatible(mission_type: String) -> Dictionary:
	"""Check if this nebula is compatible with mission type"""
	var compatibility = {
		"compatible": true,
		"difficulty_modification": 1.0,
		"recommended_approach": "Standard",
		"warnings": []
	}

	match mission_type:
		"Reconnaissance":
			if radar_sensor_range_reduction > 0.8:
				compatibility["compatible"] = false
				compatibility["warnings"].append("Sensor interference too severe for recon")
			compatibility["recommended_approach"] = "Close-range visual scanning"

			"Dogfighting":
		if calculate_tactical_severity() > 0.6:
		compatibility["warnings"].append("High tactical severity affects dogfighting")
		compatibility["recommended_approach"] = "Short-range energy weapons only"

	"Bomber Strike":
		if blocks_beam_weapons and weapon_range_modifier < 0.7:
			compatibility["warnings"].append("Long-range weapons severely limited")
			compatibility["recommended_approach"] = "Close-range bombing run"

		"Sniper Mission":
	if radar_sensor_range_reduction > 0.5 or weapon_range_modifier < 0.8:
			compatibility["compatible"] = false
			compatibility["warnings"].append("Range and sensors too compromised for sniper role")

		"Escort":
	if formation_flying_penalty > 0.3:
		compatibility["warnings"].append("Formation flying severely penalized")

	_:
		compatibility["warnings"].append("Mission compatibility analysis incomplete")

	compatibility["difficulty_modification"] = 1.0 + (calculate_tactical_severity() * 0.5)

	return compatibility