# AsteroidData - Comprehensive Asteroid Field Resource
# Represents asteroid field configurations, physics, mining, and environmental hazards
# for Wing Commander Saga asteroid belt and debris field environments

class_name AsteroidData
extends WCSBaseResource

# === BASIC FIELD PROPERTIES ===
@export_group("Field Identity", "field_")
@export var field_name: String = "" # Field designation/name
@export var field_classification: int = 0 # 0=Asteroid Belt, 1=Debris Field, 2=Rocky Nebula
@export var field_density_coefficient: float = 0.3 # 0.0-1.0 density scale
@export var field_diameter_km: float = 10.0 # Field diameter in kilometers
@export var minimum_separation_distance: float = 1.0 # Minimum asteroid spacing (meters)

# === ASTEROID POPULATION ===
@export_group("Size Distribution", "size_")
@export var size_distribution_percentages: Dictionary = { # Size category -> percentage
	"tiny": 0.40, # < 10m diameter
	"small": 0.30, # 10-50m diameter
	"medium": 0.20, # 50-200m diameter
	"large": 0.08, # 200-1000m diameter
	"huge": 0.02 # > 1000m diameter
}
@export var size_variance_factor: float = 0.2 # Random variance in each category
@export var minimum_asteroid_diameter: float = 1.0 # Smallest possible asteroid (meters)
@export var maximum_asteroid_diameter: float = 5000.0 # Largest possible asteroid (meters)
@export var size_weighting_exponent: float = 1.0 # Non-linear size distribution

# === MOVEMENT AND DYNAMICS ===
@export_group("Movement", "movement_")
@export var rotation_speed_range: Vector2 = Vector2(0.1, 2.0) # Degrees per second
@export var orbital_velocity_range: Vector2 = Vector2(0.0, 50.0) # m/s relative to field center
@export var orbital_motion_pattern: int = 0 # 0=Static, 1=Orbital, 2=Random, 3=Flowing
@export var orbital_axis_primary: Vector3 = Vector3(0, 1, 0) # Primary rotation axis
@export var orbital_axis_secondary: Vector3 = Vector3(1, 0, 0) # Secondary rotation axis
@export var turbulence_intensity: float = 0.1 # Movement chaos factor
@export var gravitational_perturbation: float = 0.0 # Gravitational irregularities

# === COLLISION PHYSICS ===
@export_group("Collision", "collision_")
@export var collision_damage_scale: float = 1.0 # Base collision damage multiplier
@export var inter_asteroid_collisions: bool = true # Asteroids can destroy each other
@export var ship_mass_damage_factor: float = 0.5 # Damage scales with ship mass
@export var velocity_damage_exponent: float = 2.0 # Damage scaling with velocity (square law)
@export var minimum_damage_velocity: float = 10.0 # m/s minimum for damage
@export var collision_momentum_transfer: float = 0.8 # Energy transfer coefficient
@export var collision_restitution_coefficient: float = 0.2 # Bounce factor

# === MINING AND RESOURCES ===
@export_group("Mining", "mining_")
@export var supports_mining: bool = false # Asteroids can be mined
@export var mineral_composition_percentages: Dictionary = { # Mineral -> percentage
	"iron": 0.60,
	"nickel": 0.25,
	"cobalt": 0.05,
	"precious_metals": 0.06,
	"rare_earth": 0.03,
	"radioactives": 0.01
}
@export var mining_difficulty_rating: float = 1.0 # Difficulty multiplier (1.0=normal)
@export var base_mining_yield_value: float = 100.0 # Base resource extraction value
@export var mining_equipment_requirements: Array[String] = [] # Equipment needed
@export var mining_hazard_level: int = 0 # 0=Safe, 1=Dangerous, 2=Extreme
@export var mineral_market_values: Dictionary = {} # Mineral -> market price

# === ENVIRONMENTAL HAZARDS ===
@export_group("Hazards", "hazard_")
@export var radiation_level: float = 0.0 # Background radiation level
@export var radiation_damage_per_second: float = 0.0 # Hull damage from radiation
@export var electromagnetic_interference: float = 0.0 # Sensor disruption (0.0-1.0)
@export var communication_blackout_severity: float = 0.0 # Comms interference (0.0-1.0)
@export var magnetic_field_disturbance: float = 0.0 # Navigation system interference
@export var micro_meteorite_density: float = 0.0 # Micrometeorite collision chance
@export var dust_cloud_density: float = 0.0 # Visual/sensor obstruction

# === VISUAL REPRESENTATION ===
@export_group("Visual Effects", "visual_")
@export var asteroid_model_references: Array[String] = [] # Cross-references to 3D models
@export var asteroid_texture_variants: int = 5 # Number of different textures
@export var destruction_effect_reference: String = "" # Cross-reference to effect
@export var impact_effect_reference: String = "" # Cross-reference to effect
@export var particle_field_density: float = 0.2 # Dust/debris density
@export var field_luminosity_factor: float = 0.8 # Brightness modifier
@export var asteroid_surface_reflectivity: float = 0.3 # Material shininess

# === NAVIGATION IMPACT ===
@export_group("Navigation", "nav_")
@export var plot_course_difficulty: float = 0.5 # Difficulty of navigation plotting
@export var hyperspace_interference: float = 0.0 # Jump drive disruption
@export var subspace_interference: float = 0.0 # Subspace comm disruption
@export var astrogation_complexity: int = 0 # Navigation complexity level
@export var recommended_safeties: Array[String] = [] # Recommended safety protocols

# === PERFORMANCE OPTIMIZATION ===
@export_group("Performance", "perf_")
@export var level_of_detail_distance_multiplier: float = 2.0 # Extended LOD distances
@export var physics_simulation_detail: int = 2 # 0=Low, 1=Medium, 2=High, 3=Ultra
@export var collision_mesh_complexity_level: int = 1 # 0=Sphere, 1=Convex, 2=Triangle mesh
@export var maximum_visible_asteroids: int = 100 # Performance visibility limit
@export var culling_distance_km: float = 5.0 # Distance beyond which asteroids culled
@export var batch_rendering_groups: int = 4 # Number of batched rendering groups

# === FIELD GENERATION PARAMETERS ===
@export_group("Generation", "gen_")
@export var random_seed_offset: int = 0 # Random generation seed offset
@export var generation_algorithm: int = 0 # 0=Uniform, 1=Clustered, 2=Ring, 3=Spiral
@export var cluster_density_levy_exponent: float = 1.0 # Clustering distribution parameter
@export var ring_thickness_factor: float = 0.2 # For ring generation
@export var spiral_arms_count: int = 2 # For spiral generation
@export var spiral_tightness: float = 1.0 # For spiral generation

# Validation signals
signal field_properties_changed()
signal mining_conditions_changed()
signal hazard_levels_changed()
signal visual_appearance_changed()

# ================== VALIDATION METHODS ==================

func get_resource_type() -> String:
	return "asteroid_data"

func validate() -> bool:
	"""Comprehensive asteroid field validation"""
	validation_errors.clear()
	validation_warnings.clear()

	# Call parent validation first
	if not super.validate():
		return false

	# Validate basic properties
	_validate_basic_properties()
	_validate_size_distribution()
	_validate_movement_parameters()
	_validate_collision_physics()
	_validate_mining_parameters()
	_validate_hazards()
	_validate_visual_properties()
	_validate_performance_settings()
	_validate_generation_parameters()

	# Final validation status
	is_valid = validation_errors.size() == 0
	validation_status_changed.emit(is_valid)

	return is_valid

func _validate_basic_properties() -> void:
	"""Validate basic field properties"""
	if field_name.is_empty():
		_add_validation_warning("Field name not specified")

	if field_classification < 0 or field_classification > 2:
		_add_validation_error("Field classification must be between 0 and 2")

	if field_density_coefficient < 0 or field_density_coefficient > 1:
		_add_validation_error("Field density coefficient must be between 0.0 and 1.0")

	if field_diameter_km <= 0:
		_add_validation_error("Field diameter must be positive")

	if minimum_separation_distance <= 0:
		_add_validation_error("Minimum separation distance must be positive")

func _validate_size_distribution() -> void:
	"""Validate size distribution configuration"""
	# Check size range consistency
	if minimum_asteroid_diameter >= maximum_asteroid_diameter:
		_add_validation_error("Minimum diameter must be less than maximum diameter")

	# Validate size distribution percentages
	var total_percentage = 0.0
	for category in size_distribution_percentages.keys():
		var percentage = size_distribution_percentages[category]
		if percentage < 0:
			_add_validation_error("Size distribution percentages cannot be negative")
		total_percentage += percentage

	if abs(total_percentage - 1.0) > 0.001:
		_add_validation_error("Size distribution percentages must total 100%")

	# Validate size variance
	if size_variance_factor < 0 or size_variance_factor > 1:
		_add_validation_error("Size variance factor must be between 0.0 and 1.0")

	# Check category consistency with diameter limits
	for category in size_distribution_percentages.keys():
		var percentage = size_distribution_percentages[category]
		if percentage > 0:
			var category_size = get_category_size_range(category)
			if category_size.x < minimum_asteroid_diameter or category_size.y > maximum_asteroid_diameter:
				_add_validation_warning("Size category %s outside diameter bounds" % category)

func _validate_movement_parameters() -> void:
	"""Validate movement and orbital parameters"""
	if orbital_motion_pattern < 0 or orbital_motion_pattern > 3:
		_add_validation_error("Orbital motion pattern must be between 0 and 3")

	# Validate rotation speed range
	if rotation_speed_range.x > rotation_speed_range.y:
		_add_validation_error("Rotation speed range minimum must be less than maximum")

	if rotation_speed_range.x < 0:
		_add_validation_error("Rotation speed cannot be negative")

	# Validate orbital velocity range
	if orbital_velocity_range.x > orbital_velocity_range.y:
		_add_validation_error("Orbital velocity range minimum must be less than maximum")

	if orbital_velocity_range.x < 0:
		_add_validation_error("Orbital velocity cannot be negative")

	# Validate turbulence
	if turbulence_intensity < 0 or turbulence_intensity > 1:
		_add_validation_error("Turbulence intensity must be between 0.0 and 1.0")

	if gravitational_perturbation < 0:
		_add_validation_error("Gravitational perturbation cannot be negative")

func _validate_collision_physics() -> void:
	"""Validate collision physics parameters"""
	if collision_damage_scale < 0:
		_add_validation_error("Collision damage scale cannot be negative")

	if ship_mass_damage_factor < 0:
		_add_validation_error("Ship mass damage factor cannot be negative")

	if velocity_damage_exponent < 0:
		_add_validation_error("Velocity damage exponent cannot be negative")

	if minimum_damage_velocity < 0:
		_add_validation_error("Minimum damage velocity cannot be negative")

	if collision_momentum_transfer < 0 or collision_momentum_transfer > 1:
		_add_validation_error("Collision momentum transfer must be between 0.0 and 1.0")

	if collision_restitution_coefficient < 0 or collision_restitution_coefficient > 1:
		_add_validation_error("Collision restitution coefficient must be between 0.0 and 1.0")

func _validate_mining_parameters() -> void:
	"""Validate mining configuration"""
	if supports_mining:
		# Validate mineral composition
		var mineral_total = 0.0
		for mineral in mineral_composition_percentages.keys():
			var percentage = mineral_composition_percentages[mineral]
			if percentage < 0:
				_add_validation_error("Mineral composition percentages cannot be negative")
			mineral_total += percentage

		if abs(mineral_total - 1.0) > 0.001:
			_add_validation_error("Mineral composition percentages must total 100%")

		if mining_difficulty_rating <= 0:
			_add_validation_error("Mining difficulty rating must be positive")

		if base_mining_yield_value <= 0:
			_add_validation_error("Base mining yield value must be positive")

		if mining_hazard_level < 0 or mining_hazard_level > 2:
			_add_validation_error("Mining hazard level must be between 0 and 2")

		# Validate market values if provided
		if not mineral_market_values.is_empty():
			for mineral in mineral_market_values.keys():
				if mineral_composition_percentages.get(mineral, 0.0) <= 0:
					_add_validation_warning("Market value set for unavailable mineral: %s" % mineral)

func _validate_hazards() -> void:
	"""Validate environmental hazards"""
	var hazard_params = [
		radiation_level,
		radiation_damage_per_second,
		electromagnetic_interference,
		communication_blackout_severity,
		magnetic_field_disturbance,
		micro_meteorite_density,
		dust_cloud_density
	]

	for hazard in hazard_params:
		if hazard < 0:
			_add_validation_error("Hazard parameters cannot be negative")

	if radiation_damage_per_second > 5.0:
		_add_validation_warning("High radiation damage may make field impassable")

	if communication_blackout_severity > 0.9:
		_add_validation_warning("Severe communication blackout will affect gameplay")

func _validate_visual_properties() -> void:
	"""Validate visual effect references"""
	# Validate model references
	for model_ref in asteroid_model_references:
		if not model_ref.is_empty():
			add_cross_reference_dependency(model_ref)

	# Validate effect references
	if not destruction_effect_reference.is_empty():
		add_cross_reference_dependency(destruction_effect_reference)
	if not impact_effect_reference.is_empty():
		add_cross_reference_dependency(impact_effect_reference)

	# Validate texture variants
	if asteroid_texture_variants < 1:
		_add_validation_warning("Asteroid texture variants should be at least 1")

	if field_luminosity_factor <= 0:
		_add_validation_error("Field luminosity factor must be positive")

	if asteroid_surface_reflectivity < 0 or asteroid_surface_reflectivity > 1:
		_add_validation_error("Asteroid surface reflectivity must be between 0.0 and 1.0")

func _validate_performance_settings() -> void:
	"""Validate performance optimization settings"""
	if level_of_detail_distance_multiplier <= 0:
		_add_validation_error("LOD distance multiplier must be positive")

	if physics_simulation_detail < 0 or physics_simulation_detail > 3:
		_add_validation_error("Physics simulation detail must be between 0 and 3")

	if collision_mesh_complexity_level < 0 or collision_mesh_complexity_level > 2:
		_add_validation_error("Collision mesh complexity must be between 0 and 2")

	if maximum_visible_asteroids <= 0:
		_add_validation_error("Maximum visible asteroids must be positive")

	if maximum_visible_asteroids > 500:
		_add_validation_warning("High asteroid count may impact performance")

	if culling_distance_km <= 0:
		_add_validation_error("Culling distance must be positive")

	if batch_rendering_groups < 1:
		_add_validation_error("Batch rendering groups must be at least 1")

func _validate_generation_parameters() -> void:
	"""Validate field generation parameters"""
	if generation_algorithm < 0 or generation_algorithm > 3:
		_add_validation_error("Generation algorithm must be between 0 and 3")

	if cluster_density_levy_exponent <= 0:
		_add_validation_error("Cluster density exponent must be positive")

	if ring_thickness_factor <= 0 or ring_thickness_factor > 1:
		_add_validation_error("Ring thickness factor must be between 0.0 and 1.0")

	if spiral_arms_count < 1:
		_add_validation_error("Spiral arms count must be at least 1")

	if spiral_tightness <= 0:
		_add_validation_error("Spiral tightness must be positive")

# ================== CALCULATION METHODS ==================

func calculate_estimated_asteroid_count() -> int:
	"""
	Estimate total number of asteroids based on density and field size.
	Considers size distribution to account for space occupied by larger asteroids.
	"""
	var field_radius = field_diameter_km / 2.0
	var field_volume_cubic_km = (4.0 / 3.0) * PI * pow(field_radius, 3.0)
	var density_per_cubic_km = field_density_coefficient * 10.0
	var base_count = int(field_volume_cubic_km * density_per_cubic_km)

	# Calculate space required by different size categories
	var space_adjustment_multiplier = 1.0
	for category in size_distribution_percentages.keys():
		var percentage = size_distribution_percentages[category]
		var typical_size = get_typical_size_for_category(category)
		var space_factor = pow(typical_size / 100.0, 2.0) # Approximate area scaling
		space_adjustment_multiplier += (percentage * space_factor * 0.1) # Weighted influence

	var adjusted_count = int(base_count / space_adjustment_multiplier)
	return max(10, adjusted_count) # Minimum reasonable count

func calculate_field_mass_estimate() -> float:
	"""Calculate estimated total mass of the asteroid field in tons"""
	var asteroid_count = calculate_estimated_asteroid_count()
	var average_mass = calculate_average_asteroid_mass()
	return float(asteroid_count) * average_mass

func calculate_average_asteroid_mass() -> float:
	"""Calculate average asteroid mass based on size distribution"""
	var total_mass_contribution = 0.0
	var total_percentage = 0.0

	for category in size_distribution_percentages.keys():
		var percentage = size_distribution_percentages[category]
		if percentage > 0:
			var size_range = get_category_size_range(category)
			var typical_size = (size_range.x + size_range.y) / 2.0
			var volume_cubic_meters = (4.0 / 3.0) * PI * pow(typical_size / 2.0, 3.0)
			var mass_tons = volume_cubic_meters * 2.7 # Rough density of rock
			total_mass_contribution += (mass_tons * percentage)
			total_percentage += percentage

	if total_percentage <= 0:
		return 100.0 # Default fallback

	return total_mass_contribution / total_percentage

func get_category_size_range(category: String) -> Vector2:
	"""Get size range for a category"""
	match category:
		"tiny": return Vector2(1, 10)
		"small": return Vector2(10, 50)
		"medium": return Vector2(50, 200)
		"large": return Vector2(200, 1000)
		"huge": return Vector2(1000, 5000)
		_: return Vector2(1, 10)

func get_typical_size_for_category(category: String) -> float:
	"""Get typical size for a category"""
	var range = get_category_size_range(category)
	return (range.x + range.y) / 2.0

func calculate_collision_damage(
	ship_mass_kg: float,
	impact_velocity_mps: float,
	asteroid_diameter_meters: float,
	impact_angle_degrees: float
) -> float:
	"""Calculate collision damage based on detailed physics"""
	if impact_velocity_mps < minimum_damage_velocity:
		return 0.0

	# Calculate kinetic energy
	var ship_kinetic_energy = 0.5 * ship_mass_kg * pow(impact_velocity_mps, 2.0)

	# Calculate asteroid cross-sectional area
	var asteroid_radius = asteroid_diameter_meters / 2.0
	var cross_sectional_area = PI * pow(asteroid_radius, 2.0)

	# Apply angle-based damage reduction
	var angle_factor = abs(cos(deg_to_rad(impact_angle_degrees)))

	# Scale with asteroid size
	var size_factor = pow(cross_sectional_area, 0.5) / 10.0 # Normalize

	# Calculate final damage
	var damage = (ship_kinetic_energy / 1000.0) * collision_damage_scale * size_factor * angle_factor
	damage *= ship_mass_damage_factor
	damage *= pow(impact_velocity_mps / 100.0, velocity_damage_exponent - 1.0) # Extra velocity scaling

	return max(0.0, damage)

func calculate_mining_yield_from_asteroid(
	asteroid_diameter_meters: float,
	mining_equipment_tier: int,
	mining_skill_multiplier: float
) -> Dictionary:
	"""Calculate mineral extraction yield from specific asteroid"""
	if not supports_mining or mining_equipment_tier <= 0:
		return {}

	# Calculate asteroid volume and total material
	var asteroid_radius = asteroid_diameter_meters / 2.0
	var volume_cubic_meters = (4.0 / 3.0) * PI * pow(asteroid_radius, 3.0)
	var total_material_tons = volume_cubic_meters * 2.7 # Rock density

	# Calculate effective mining yield
	var efficiency = float(mining_equipment_tier) / mining_difficulty_rating
	efficiency *= mining_skill_multiplier
	efficiency = clamp(efficiency, 0.1, 1.0) # Minimum 10% efficiency

	var total_yield_tons = total_material_tons * efficiency
	var base_yield_value = base_mining_yield_value * (asteroid_diameter_meters / 100.0)

	# Distribute yield across minerals
	var yield_distribution = {}
	for mineral in mineral_composition_percentages.keys():
		var percentage = mineral_composition_percentages[mineral]
		if percentage > 0:
			yield_distribution[mineral] = {
				"tons": total_yield_tons * percentage,
				"value": base_yield_value * percentage,
				"percentage": percentage
			}

	return yield_distribution

func get_hazard_severity_score() -> float:
	"""Calculate overall hazard severity score (0.0-1.0)"""
	var hazard_score = 0.0

	# Collision hazard
	hazard_score += field_density_coefficient * 0.3

	# Radiation hazard
	hazard_score += (radiation_damage_per_second / 10.0) * 0.2

	# Environmental hazards
	hazard_score += electromagnetic_interference * 0.15
	hazard_score += communication_blackout_severity * 0.15
	hazard_score += magnetic_field_disturbance * 0.1
	hazard_score += micro_meteorite_density * 0.1

	return clamp(hazard_score, 0.0, 1.0)

func is_safe_for_extended_operations() -> bool:
	"""Determine if field is safe for prolonged mining/survey operations"""
	return (radiation_damage_per_second < 0.5 and
		    mining_hazard_level <= 1 and
		    electromagnetic_interference < 0.8 and
		    communication_blackout_severity < 0.7 and
		    get_hazard_severity_score() < 0.6)

func get_recommended_ship_class() -> String:
	"""Get recommended ship class for this field"""
	var hazard_score = get_hazard_severity_score()
	var density = field_density_coefficient

	if hazard_score > 0.7 or density > 0.8:
		return "Heavy Fighter or Bomber"
	elif hazard_score > 0.4 or density > 0.6:
		return "Medium Fighter"
	elif hazard_score > 0.2 or density > 0.4:
		return "Light Fighter"
	else:
		return "Any Ship Class"

# ================== UTILITY METHODS ==================

func get_supported_minerals() -> Array[String]:
	"""Get list of minerals that can be extracted from this field"""
	var supported_minerals = []
	for mineral in mineral_composition_percentages.keys():
		if mineral_composition_percentages[mineral] > 0:
			supported_minerals.append(mineral)
	return supported_minerals

func get_highest_value_mineral() -> String:
	"""Get the mineral with highest market value in this field"""
	var highest_value_mineral = ""
	var highest_price = 0.0

	for mineral in mineral_market_values.keys():
		if mineral_composition_percentages.get(mineral, 0.0) > 0:
			var price = mineral_market_values[mineral]
			if price > highest_price:
				highest_price = price
				highest_value_mineral = mineral

	return highest_value_mineral

func get_field_classification_name() -> String:
	"""Get human-readable field classification name"""
	var classifications = ["Asteroid Belt", "Debris Field", "Rocky Nebula"]
	if field_classification >= 0 and field_classification < classifications.size():
		return classifications[field_classification]
	return "Unknown Field Type"

func get_recommended_mining_equipment() -> Array[String]:
	"""Get recommended mining equipment for this field"""
	var equipment = ["Standard Mining Laser"]

	if mining_hazard_level >= 2:
		equipment.append_field("Heavy-Duty Mining Equipment")
		equipment.append_field("Advanced Survey Sensors")

	if mining_difficulty_rating > 2.0:
		equipment.append_field("Specialized Extraction Tools")

	if radiation_level > 1.0:
		equipment.append_field("Radiation Shielded Equipment")

	return equipment

func generate_mining_report() -> Dictionary:
	"""Generate comprehensive mining report for this field"""
	return {
		"field_name": field_name,
		"estimated_total_asteroids": calculate_estimated_asteroid_count(),
		"total_mass_estimate_tons": calculate_field_mass_estimate(),
		"supports_mining": supports_mining,
		"mining_difficulty": mining_difficulty_rating,
		"hazard_level": mining_hazard_level,
		"supported_minerals": get_supported_minerals(),
		"highest_value_mineral": get_highest_value_mineral(),
		"hazard_severity_score": get_hazard_severity_score(),
		"safe_for_operations": is_safe_for_extended_operations(),
		"recommended_equipment": get_recommended_mining_equipment()
	}
