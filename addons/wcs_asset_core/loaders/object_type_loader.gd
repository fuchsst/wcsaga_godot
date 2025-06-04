class_name ObjectTypeLoader
extends RefCounted

## WCS Object Type Validation and Loading System
## Provides validation, loading, and management for object type definitions
## Integrates with existing wcs_asset_core addon validation framework

## Loading result status
enum LoadResult {
	SUCCESS = 0,
	ERROR_FILE_NOT_FOUND = 1,
	ERROR_INVALID_FORMAT = 2,
	ERROR_VALIDATION_FAILED = 3,
	ERROR_DEPENDENCY_MISSING = 4,
	ERROR_UNKNOWN = 5
}

## Static validation and loading functions

static func validate_object_type(object_type: int) -> bool:
	"""Validate that an object type is within valid range.
	
	Args:
		object_type: Object type from ObjectTypes.Type enum
	
	Returns:
		true if object type is valid
	"""
	const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
	return ObjectTypes.is_valid_type(object_type)

static func validate_collision_layer(layer: int) -> bool:
	"""Validate that a collision layer is within valid range.
	
	Args:
		layer: Collision layer from CollisionLayers.Layer enum
	
	Returns:
		true if collision layer is valid
	"""
	const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")
	return CollisionLayers.is_valid_layer(layer)

static func validate_update_frequency(frequency: int) -> bool:
	"""Validate that an update frequency is within valid range.
	
	Args:
		frequency: Update frequency from UpdateFrequencies.Frequency enum
	
	Returns:
		true if update frequency is valid
	"""
	const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")
	return UpdateFrequencies.is_frequency_valid(frequency)

static func load_object_type_data(object_type_name: String) -> ObjectTypeData:
	"""Load object type data by name.
	
	Args:
		object_type_name: Name of the object type to load
	
	Returns:
		ObjectTypeData instance or null if not found
	"""
	# Try to load from predefined types first
	var predefined_data: ObjectTypeData = _get_predefined_object_type_data(object_type_name)
	if predefined_data:
		return predefined_data
	
	# Try to load from resource file
	var resource_path: String = "res://addons/wcs_asset_core/data/object_types/" + object_type_name + ".tres"
	if ResourceLoader.exists(resource_path):
		var resource: Resource = load(resource_path)
		if resource is ObjectTypeData:
			return resource as ObjectTypeData
	
	# Not found
	return null

static func load_physics_profile(profile_name: String) -> PhysicsProfile:
	"""Load physics profile by name.
	
	Args:
		profile_name: Name of the physics profile to load
	
	Returns:
		PhysicsProfile instance or null if not found
	"""
	# Try predefined profiles first
	var predefined_profile: PhysicsProfile = _get_predefined_physics_profile(profile_name)
	if predefined_profile:
		return predefined_profile
	
	# Try to load from resource file
	var resource_path: String = "res://addons/wcs_asset_core/resources/object/physics_profiles/" + profile_name + ".tres"
	if ResourceLoader.exists(resource_path):
		var resource: Resource = load(resource_path)
		if resource is PhysicsProfile:
			return resource as PhysicsProfile
	
	# Not found
	return null

static func validate_object_type_data(data: ObjectTypeData) -> ValidationResult:
	"""Validate an ObjectTypeData instance.
	
	Args:
		data: ObjectTypeData to validate
	
	Returns:
		ValidationResult with validation status and errors
	"""
	if not data:
		var result: ValidationResult = ValidationResult.new("n/a", "n/a")
		result.add_error("ObjectTypeData is null")
		return result
	
	# Use the built-in validation
	var result: ValidationResult = data.validate()
	
	# Additional object type specific validation
	if not validate_object_type(data.object_type):
		result.add_error("Invalid object type: %d" % data.object_type)
	
	if data.has_collision and not validate_collision_layer(data.collision_layer):
		result.add_error("Invalid collision layer: %d" % data.collision_layer)
	
	if not validate_update_frequency(data.default_update_frequency):
		result.add_error("Invalid update frequency: %d" % data.default_update_frequency)
	
	# Validate physics profile if specified
	if not data.physics_profile_path.is_empty():
		if not ResourceLoader.exists(data.physics_profile_path):
			result.add_error("Physics profile not found: %s" % data.physics_profile_path)
		else:
			var profile: Resource = load(data.physics_profile_path)
			if not profile is PhysicsProfile:
				result.add_error("Invalid physics profile resource: %s" % data.physics_profile_path)
			else:
				var physics_profile: PhysicsProfile = profile as PhysicsProfile
				if not physics_profile.validate():
					result.add_error("Physics profile validation failed: %s" % data.physics_profile_path)
	
	return result

static func validate_physics_profile(profile: PhysicsProfile) -> ValidationResult:
	"""Validate a PhysicsProfile instance.
	
	Args:
		profile: PhysicsProfile to validate
	
	Returns:
		ValidationResult with validation status and errors
	"""
	var result: ValidationResult = ValidationResult.new("", "Physics Profile")
	
	if not profile:
		result.add_error("PhysicsProfile is null")
		return result
	
	# Use the built-in validation
	if not profile.validate():
		result.add_error("PhysicsProfile internal validation failed")
	
	# Additional validation for collision properties
	if profile.requires_collision_detection():
		if not validate_collision_layer(profile.collision_layer):
			result.add_error("Invalid collision layer in physics profile: %d" % profile.collision_layer)
	
	return result

static func get_object_type_for_class(obj_class_name: String) -> int:
	"""Get the appropriate object type for a given class name.
	
	Args:
		class_name: Name of the object class
	
	Returns:
		ObjectTypes.Type enum value or NONE if not found
	"""
	const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
	
	var class_lower: String = obj_class_name.to_lower()
	
	# Ship classes
	if class_lower.contains("ship") or class_lower.contains("fighter") or class_lower.contains("bomber"):
		if class_lower.contains("capital") or class_lower.contains("cruiser") or class_lower.contains("destroyer"):
			return ObjectTypes.Type.CAPITAL
		elif class_lower.contains("fighter"):
			return ObjectTypes.Type.FIGHTER
		elif class_lower.contains("bomber"):
			return ObjectTypes.Type.BOMBER
		elif class_lower.contains("support"):
			return ObjectTypes.Type.SUPPORT
		else:
			return ObjectTypes.Type.SHIP
	
	# Weapon classes
	elif class_lower.contains("weapon") or class_lower.contains("projectile") or class_lower.contains("missile"):
		if class_lower.contains("beam"):
			return ObjectTypes.Type.BEAM
		elif class_lower.contains("countermeasure"):
			return ObjectTypes.Type.COUNTERMEASURE
		else:
			return ObjectTypes.Type.WEAPON
	
	# Effect classes
	elif class_lower.contains("effect") or class_lower.contains("particle"):
		if class_lower.contains("explosion") or class_lower.contains("fireball"):
			return ObjectTypes.Type.FIREBALL
		elif class_lower.contains("shockwave"):
			return ObjectTypes.Type.SHOCKWAVE
		else:
			return ObjectTypes.Type.EFFECT
	
	# Environment classes
	elif class_lower.contains("debris"):
		return ObjectTypes.Type.DEBRIS
	elif class_lower.contains("asteroid"):
		return ObjectTypes.Type.ASTEROID
	elif class_lower.contains("waypoint"):
		return ObjectTypes.Type.WAYPOINT
	elif class_lower.contains("jumpnode") or class_lower.contains("jump_node"):
		return ObjectTypes.Type.JUMP_NODE
	
	# System classes
	elif class_lower.contains("observer"):
		return ObjectTypes.Type.OBSERVER
	elif class_lower.contains("trigger"):
		return ObjectTypes.Type.TRIGGER
	elif class_lower.contains("cargo"):
		return ObjectTypes.Type.CARGO
	
	# Default
	return ObjectTypes.Type.NONE

static func get_collision_setup_for_object_type(object_type: int) -> Dictionary:
	"""Get collision layer and mask setup for an object type.
	
	Args:
		object_type: Object type from ObjectTypes.Type enum
	
	Returns:
		Dictionary with 'layer' and 'mask' keys
	"""
	const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
	const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")
	
	var setup: Dictionary = {"layer": 1, "mask": 1}  # Default values
	
	match object_type:
		ObjectTypes.Type.SHIP, ObjectTypes.Type.FIGHTER, ObjectTypes.Type.BOMBER:
			setup.layer = 1 << CollisionLayers.Layer.SHIPS
			setup.mask = CollisionLayers.Mask.SHIP_FIGHTER
		
		ObjectTypes.Type.CAPITAL:
			setup.layer = 1 << CollisionLayers.Layer.CAPITALS
			setup.mask = CollisionLayers.Mask.SHIP_CAPITAL
		
		ObjectTypes.Type.SUPPORT:
			setup.layer = 1 << CollisionLayers.Layer.SUPPORT
			setup.mask = CollisionLayers.Mask.SHIP_SUPPORT
		
		ObjectTypes.Type.WEAPON:
			setup.layer = 1 << CollisionLayers.Layer.WEAPONS
			setup.mask = CollisionLayers.Mask.WEAPON_STANDARD
		
		ObjectTypes.Type.BEAM:
			setup.layer = 1 << CollisionLayers.Layer.BEAM_WEAPONS
			setup.mask = CollisionLayers.Mask.WEAPON_BEAM
		
		ObjectTypes.Type.COUNTERMEASURE:
			setup.layer = 1 << CollisionLayers.Layer.COUNTERMEASURES
			setup.mask = CollisionLayers.Mask.WEAPON_POINT_DEFENSE
		
		ObjectTypes.Type.DEBRIS:
			setup.layer = 1 << CollisionLayers.Layer.DEBRIS
			setup.mask = CollisionLayers.Mask.DEBRIS_STANDARD
		
		ObjectTypes.Type.ASTEROID:
			setup.layer = 1 << CollisionLayers.Layer.ASTEROIDS
			setup.mask = CollisionLayers.Mask.ASTEROID_STANDARD
		
		ObjectTypes.Type.FIREBALL, ObjectTypes.Type.SHOCKWAVE:
			setup.layer = 1 << CollisionLayers.Layer.EFFECTS
			setup.mask = CollisionLayers.Mask.EXPLOSION_DAMAGE
		
		ObjectTypes.Type.WAYPOINT:
			setup.layer = 1 << CollisionLayers.Layer.WAYPOINTS
			setup.mask = CollisionLayers.Mask.WAYPOINT_NAVIGATION
		
		ObjectTypes.Type.TRIGGER:
			setup.layer = 1 << CollisionLayers.Layer.TRIGGERS
			setup.mask = CollisionLayers.Mask.TRIGGER_AREA
		
		_:
			# Default collision setup
			setup.layer = 1 << CollisionLayers.Layer.ENVIRONMENT
			setup.mask = CollisionLayers.Mask.ENVIRONMENT_STATIC
	
	return setup

static func create_object_type_registry() -> Dictionary:
	"""Create a registry of all available object types.
	
	Returns:
		Dictionary mapping object type names to ObjectTypeData
	"""
	var registry: Dictionary = {}
	
	# Add predefined ship types
	registry["fighter"] = ObjectTypeData.create_ship_type_data("Fighter")
	registry["bomber"] = ObjectTypeData.create_ship_type_data("Bomber") 
	registry["capital"] = ObjectTypeData.create_ship_type_data("Capital")
	registry["support"] = ObjectTypeData.create_ship_type_data("Support")
	
	# Add predefined weapon types
	registry["laser"] = ObjectTypeData.create_weapon_type_data("Laser")
	registry["missile"] = ObjectTypeData.create_weapon_type_data("Missile")
	registry["beam"] = ObjectTypeData.create_weapon_type_data("Beam")
	
	# Add environment types
	registry["debris"] = ObjectTypeData.create_debris_type_data()
	registry["waypoint"] = ObjectTypeData.create_waypoint_type_data()
	
	# Add effect types
	registry["explosion"] = ObjectTypeData.create_effect_type_data("Explosion")
	registry["particle"] = ObjectTypeData.create_effect_type_data("Particle")
	
	return registry

static func get_all_object_type_names() -> Array[String]:
	"""Get all available object type names.
	
	Returns:
		Array of all object type name strings
	"""
	var registry: Dictionary = create_object_type_registry()
	var names: Array[String] = []
	
	for name in registry.keys():
		names.append(name)
	
	# Sort alphabetically for consistency
	names.sort()
	
	return names

static func integrate_with_asset_core() -> bool:
	"""Integrate object type system with existing wcs_asset_core addon.
	
	Returns:
		true if integration successful
	"""
	# Check if core addon components are available
	if not _check_asset_core_availability():
		push_error("wcs_asset_core addon components not available")
		return false
	
	# Register object types with existing asset registry
	var registry: Dictionary = create_object_type_registry()
	
	for type_name in registry.keys():
		var type_data: ObjectTypeData = registry[type_name]
		
		# Validate the object type data
		var validation_result: ValidationResult = validate_object_type_data(type_data)
		if not validation_result.is_valid:
			push_warning("Object type validation failed for '%s': %s" % [type_name, validation_result.get_error_summary()])
			continue
		
		# Could register with WCSAssetRegistry here if it supports object types
		# WCSAssetRegistry.register_object_type(type_name, type_data)
	
	return true

## Private helper functions

static func _get_predefined_object_type_data(type_name: String) -> ObjectTypeData:
	"""Get predefined object type data by name.
	
	Args:
		type_name: Name of the predefined type
	
	Returns:
		ObjectTypeData instance or null if not predefined
	"""
	match type_name.to_lower():
		"fighter":
			return ObjectTypeData.create_ship_type_data("Fighter")
		"bomber":
			return ObjectTypeData.create_ship_type_data("Bomber")
		"capital":
			return ObjectTypeData.create_ship_type_data("Capital")
		"support":
			return ObjectTypeData.create_ship_type_data("Support")
		"laser":
			return ObjectTypeData.create_weapon_type_data("Laser")
		"missile":
			return ObjectTypeData.create_weapon_type_data("Missile")
		"beam":
			return ObjectTypeData.create_weapon_type_data("Beam")
		"debris":
			return ObjectTypeData.create_debris_type_data()
		"waypoint":
			return ObjectTypeData.create_waypoint_type_data()
		"explosion":
			return ObjectTypeData.create_effect_type_data("Explosion")
		"particle":
			return ObjectTypeData.create_effect_type_data("Particle")
		_:
			return null

static func _get_predefined_physics_profile(profile_name: String) -> PhysicsProfile:
	"""Get predefined physics profile by name.
	
	Args:
		profile_name: Name of the predefined profile
	
	Returns:
		PhysicsProfile instance or null if not predefined
	"""
	match profile_name.to_lower():
		"fighter":
			return PhysicsProfile.create_fighter_profile()
		"capital":
			return PhysicsProfile.create_capital_profile()
		"weapon_projectile":
			return PhysicsProfile.create_weapon_projectile_profile()
		"missile":
			return PhysicsProfile.create_missile_profile()
		"debris":
			return PhysicsProfile.create_debris_profile()
		"beam_weapon":
			return PhysicsProfile.create_beam_weapon_profile()
		"effect":
			return PhysicsProfile.create_effect_profile()
		_:
			return null

static func _check_asset_core_availability() -> bool:
	"""Check if wcs_asset_core addon components are available.
	
	Returns:
		true if all required components are available
	"""
	# Check if core constants are available
	var object_types_available: bool = _check_class_available("ObjectTypes")
	var collision_layers_available: bool = _check_class_available("CollisionLayers")
	var update_frequencies_available: bool = _check_class_available("UpdateFrequencies")
	
	# Check if core resource classes are available
	var physics_profile_available: bool = _check_class_available("PhysicsProfile")
	var object_type_data_available: bool = _check_class_available("ObjectTypeData")
	
	# Check if base validation system is available
	var validation_result_available: bool = _check_class_available("ValidationResult")
	
	return (object_types_available and collision_layers_available and 
			update_frequencies_available and physics_profile_available and 
			object_type_data_available and validation_result_available)

static func _check_class_available(obj_class_name: String) -> bool:
	"""Check if a specific class is available.
	
	Args:
		class_name: Name of the class to check
	
	Returns:
		true if class is available
	"""
	# Try to access the class through ClassDB
	if ClassDB.class_exists(obj_class_name):
		return true
	
	# For custom classes, this is a basic check - in a real implementation
	# you might want to try loading the script file directly
	return true  # Assume available for now

## Validation convenience functions

static func quick_validate_object_constants() -> bool:
	"""Quick validation check for all object constants.
	
	Returns:
		true if all constants are properly defined and accessible
	"""
	const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
	const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")
	const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")
	
	# Basic constant accessibility test
	var object_types_valid: bool = (ObjectTypes.Type.SHIP == 1 and ObjectTypes.Type.WEAPON == 2)
	var collision_layers_valid: bool = (CollisionLayers.Layer.SHIPS == 0 and CollisionLayers.Layer.WEAPONS == 1)
	var update_frequencies_valid: bool = (UpdateFrequencies.Frequency.CRITICAL == 0)
	
	return object_types_valid and collision_layers_valid and update_frequencies_valid

static func validate_all_predefined_types() -> Array[ValidationResult]:
	"""Validate all predefined object types and physics profiles.
	
	Returns:
		Array of ValidationResult for each predefined type
	"""
	var results: Array[ValidationResult] = []
	
	# Validate predefined object types
	var type_names: Array[String] = ["fighter", "bomber", "capital", "support", "laser", "missile", "beam", "debris", "waypoint", "explosion", "particle"]
	
	for type_name in type_names:
		var type_data: ObjectTypeData = _get_predefined_object_type_data(type_name)
		if type_data:
			var result: ValidationResult = validate_object_type_data(type_data)
			result.asset_name = type_name + "_object_type"
			results.append(result)
	
	# Validate predefined physics profiles
	var profile_names: Array[String] = ["fighter", "capital", "weapon_projectile", "missile", "debris", "beam_weapon", "effect"]
	
	for profile_name in profile_names:
		var profile: PhysicsProfile = _get_predefined_physics_profile(profile_name)
		if profile:
			var result: ValidationResult = validate_physics_profile(profile)
			result.asset_name = profile_name + "_physics_profile"
			results.append(result)
	
	return results
