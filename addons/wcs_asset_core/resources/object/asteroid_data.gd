class_name AsteroidData
extends BaseAssetData

## Asteroid and debris object data resource
## Pure data definition for asteroids and space debris - no behavior logic

@export var display_name: String = ""
@export var max_speed: float = 0.0
@export var hitpoints: int = 1
@export var explosion_inner_radius: float = 0.0
@export var explosion_outer_radius: float = 0.0
@export var explosion_damage: float = 0.0
@export var explosion_blast: float = 0.0
@export var detail_distances: Array[int] = []

## Model paths for different LOD levels
@export var lod_0_model: String = ""
@export var lod_1_model: String = ""
@export var lod_2_model: String = ""

## Impact explosion effects
@export var impact_explosion: String = ""
@export var impact_explosion_radius: float = 20.0

func _init() -> void:
	super._init()
	asset_type = AssetTypes.Type.ASTEROID

func get_asset_type_name() -> String:
	return "Asteroid"

func get_display_name() -> String:
	return display_name if display_name else asset_name

func get_model_for_distance(distance: float) -> String:
	"""Get the appropriate model based on viewing distance."""
	if detail_distances.is_empty():
		return lod_0_model
	
	# Use highest detail model for closest distance
	if distance <= detail_distances[0] and not lod_0_model.is_empty():
		return lod_0_model
	elif detail_distances.size() > 1 and distance <= detail_distances[1] and not lod_1_model.is_empty():
		return lod_1_model
	elif detail_distances.size() > 2 and distance <= detail_distances[2] and not lod_2_model.is_empty():
		return lod_2_model
	
	# Return the lowest detail model available for far distances
	if not lod_2_model.is_empty():
		return lod_2_model
	elif not lod_1_model.is_empty():
		return lod_1_model
	else:
		return lod_0_model

func has_explosion() -> bool:
	"""Check if this asteroid has explosion effects."""
	return explosion_damage > 0.0 or explosion_blast > 0.0

func get_validation_errors() -> Array[String]:
	"""Get validation errors for asteroid data.
	Overrides BaseAssetData to provide asteroid-specific validation."""
	
	var errors: Array[String] = super.get_validation_errors()
	
	if hitpoints <= 0:
		errors.append("Asteroid must have positive hitpoints")
	
	if max_speed < 0.0:
		errors.append("Max speed cannot be negative")
	
	if explosion_inner_radius < 0.0:
		errors.append("Explosion inner radius cannot be negative")
	
	if explosion_outer_radius < explosion_inner_radius:
		errors.append("Explosion outer radius must be >= inner radius")
	
	if explosion_damage < 0.0:
		errors.append("Explosion damage cannot be negative")
	
	if explosion_blast < 0.0:
		errors.append("Explosion blast cannot be negative")
	
	# Check if at least one model is defined
	if lod_0_model.is_empty() and lod_1_model.is_empty() and lod_2_model.is_empty():
		errors.append("At least one LOD model must be defined")
	
	# Validate detail distances are in ascending order
	for i in range(1, detail_distances.size()):
		if detail_distances[i] <= detail_distances[i-1]:
			errors.append("Detail distances must be in ascending order")
			break
	
	return errors

func get_memory_size() -> int:
	"""Estimate memory usage for this asteroid data."""
	var base_size: int = super.get_memory_size()
	
	# Add size for strings and arrays
	base_size += display_name.length() * 2  # UTF-16 encoding
	base_size += lod_0_model.length() * 2
	base_size += lod_1_model.length() * 2
	base_size += lod_2_model.length() * 2
	base_size += impact_explosion.length() * 2
	base_size += detail_distances.size() * 4  # int array
	
	# Add base properties (floats and int)
	base_size += 9 * 4  # 8 floats + 1 int
	
	return base_size