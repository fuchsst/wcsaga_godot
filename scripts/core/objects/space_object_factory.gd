class_name SpaceObjectFactory
extends RefCounted

## Enhanced space object factory with comprehensive type registration and asset integration.
## Integrates with ObjectManager and applies physics profiles from wcs_asset_core addon.
## Supports WCS-compatible object types and creation templates with error handling.
## Based on WCS source/code/object/object.cpp creation patterns.

# MANDATORY: Asset core integration - NO local type definitions allowed (AC2, AC4)
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const ObjectTypeData = preload("res://addons/wcs_asset_core/structures/object_type_data.gd")
const PhysicsProfile = preload("res://addons/wcs_asset_core/resources/object/physics_profile.gd")
const WCSAssetLoader = preload("res://addons/wcs_asset_core/loaders/asset_loader.gd")

# Signals for factory events and SEXP integration (AC8)
signal object_creation_requested(object_type: ObjectTypes.Type, creation_data: Dictionary)
signal object_created(space_object: BaseSpaceObject, object_type: ObjectTypes.Type)
signal creation_failed(object_type: ObjectTypes.Type, error_message: String)

# Type registration for factory patterns (AC1, AC4)
static var registered_types: Dictionary = {}
static var creation_templates: Dictionary = {}
static var physics_profile_cache: Dictionary = {}

# SEXP system integration for dynamic object creation (AC8)
static var sexp_creation_queue: Array[Dictionary] = []
static var sexp_enabled: bool = false

## Create a space object with specified type and configuration (AC1, AC3, AC7)
static func create_space_object(object_type: ObjectTypes.Type, creation_data: Dictionary = {}) -> BaseSpaceObject:
	# Validate object type using asset core (AC2)
	if not ObjectTypes.is_valid_type(object_type):
		push_error("SpaceObjectFactory: Invalid object type %d" % object_type)
		creation_failed.emit(object_type, "Invalid object type")
		return null
	
	# Check if type is registered for creation (AC4, AC7)
	if not is_object_type_registered(object_type):
		push_error("SpaceObjectFactory: Object type %s not registered for creation" % ObjectTypes.get_type_name(object_type))
		creation_failed.emit(object_type, "Object type not registered")
		return null
	
	# Emit creation request signal for SEXP integration (AC8)
	object_creation_requested.emit(object_type, creation_data)
	
	# Load BaseSpaceObject class
	const BaseSpaceObjectScript = preload("res://scripts/core/objects/base_space_object.gd")
	var space_object: BaseSpaceObject = BaseSpaceObjectScript.new()
	
	# Get creation template for the type (AC5)
	var template: Dictionary = get_creation_template(object_type)
	if template.is_empty():
		push_warning("SpaceObjectFactory: No creation template found for type %s, using defaults" % ObjectTypes.get_type_name(object_type))
	
	# Set object type using asset core constants (AC2)
	space_object.object_type_enum = object_type
	space_object.object_type = ObjectTypes.get_type_name(object_type)
	
	# Apply physics profile from asset core (AC3, AC5)
	var physics_profile: PhysicsProfile = get_physics_profile_for_type(object_type)
	if physics_profile:
		space_object.physics_profile = physics_profile
	else:
		push_warning("SpaceObjectFactory: No physics profile available for type %s" % ObjectTypes.get_type_name(object_type))
	
	# Apply creation template properties (AC5)
	_apply_creation_template(space_object, template, creation_data)
	
	# Load asset data if specified (AC3)
	if creation_data.has("asset_path"):
		var asset_data: Resource = WCSAssetLoader.load_asset(creation_data["asset_path"])
		if asset_data:
			space_object.initialize_from_data(asset_data)
		else:
			push_warning("SpaceObjectFactory: Failed to load asset data from %s" % creation_data["asset_path"])
	
	# Initialize object with default or enhanced initialization (AC6)
	if creation_data.get("deferred_init", false):
		# Deferred initialization - object created but not fully initialized
		space_object.initialization_deferred = true
	else:
		# Immediate initialization
		var init_result: bool = space_object.initialize_space_object_enhanced(object_type, physics_profile, creation_data)
		if not init_result:
			push_error("SpaceObjectFactory: Failed to initialize space object of type %s" % ObjectTypes.get_type_name(object_type))
			creation_failed.emit(object_type, "Object initialization failed")
			space_object.queue_free()
			return null
	
	# Emit creation success signal
	object_created.emit(space_object, object_type)
	
	return space_object

## Get physics profile for object type from asset core (cached) (AC3, AC5)
static func get_physics_profile_for_type(object_type: ObjectTypes.Type) -> PhysicsProfile:
	# Check cache first for performance
	if physics_profile_cache.has(object_type):
		return physics_profile_cache[object_type]
	
	var profile: PhysicsProfile
	
	# Create physics profiles based on WCS object types (AC3)
	match object_type:
		ObjectTypes.Type.SHIP, ObjectTypes.Type.FIGHTER, ObjectTypes.Type.BOMBER:
			profile = PhysicsProfile.create_fighter_profile()
		ObjectTypes.Type.CAPITAL, ObjectTypes.Type.INSTALLATION:
			profile = PhysicsProfile.create_capital_profile()
		ObjectTypes.Type.SUPPORT:
			profile = PhysicsProfile.create_support_profile()
		ObjectTypes.Type.WEAPON:
			profile = PhysicsProfile.create_weapon_profile()
		ObjectTypes.Type.DEBRIS:
			profile = PhysicsProfile.create_debris_profile()
		ObjectTypes.Type.ASTEROID:
			profile = PhysicsProfile.create_asteroid_profile()
		ObjectTypes.Type.BEAM:
			profile = PhysicsProfile.create_beam_profile()
		ObjectTypes.Type.EFFECT, ObjectTypes.Type.FIREBALL, ObjectTypes.Type.SHOCKWAVE:
			profile = PhysicsProfile.create_effect_profile()
		ObjectTypes.Type.CARGO:
			profile = PhysicsProfile.create_cargo_profile()
		ObjectTypes.Type.WAYPOINT, ObjectTypes.Type.JUMP_NODE, ObjectTypes.Type.NAVBUOY:
			profile = PhysicsProfile.create_navigation_profile()
		_:
			# Default profile for other types
			profile = PhysicsProfile.new()
			profile.use_godot_physics = true
			profile.mass = 1.0
			profile.linear_damping = 0.1
			profile.angular_damping = 0.1
			profile.gravity_scale = 0.0
	
	# Cache the profile for performance
	physics_profile_cache[object_type] = profile
	return profile

## Type registration system for factory patterns (AC4)
static func register_object_type(object_type: ObjectTypes.Type, template_data: Dictionary = {}) -> bool:
	"""Register an object type for creation with optional template.
	
	Args:
		object_type: Object type from ObjectTypes.Type enum
		template_data: Default properties and configuration for the type
	
	Returns:
		true if registration successful
	"""
	if not ObjectTypes.is_valid_type(object_type):
		push_error("SpaceObjectFactory: Cannot register invalid object type %d" % object_type)
		return false
	
	registered_types[object_type] = true
	creation_templates[object_type] = template_data
	
	return true

## Check if object type is registered for creation (AC4, AC7)
static func is_object_type_registered(object_type: ObjectTypes.Type) -> bool:
	"""Check if an object type is registered for creation.
	
	Args:
		object_type: Object type to check
	
	Returns:
		true if type is registered
	"""
	return registered_types.has(object_type) and registered_types[object_type]

## Get creation template for object type (AC5)
static func get_creation_template(object_type: ObjectTypes.Type) -> Dictionary:
	"""Get creation template for a registered object type.
	
	Args:
		object_type: Object type to get template for
	
	Returns:
		Template dictionary with default properties
	"""
	return creation_templates.get(object_type, {})

## Set creation template for object type (AC5)
static func set_creation_template(object_type: ObjectTypes.Type, template_data: Dictionary) -> void:
	"""Set creation template for a registered object type.
	
	Args:
		object_type: Object type to set template for
		template_data: Template properties and configuration
	"""
	if is_object_type_registered(object_type):
		creation_templates[object_type] = template_data
	else:
		push_warning("SpaceObjectFactory: Cannot set template for unregistered type %s" % ObjectTypes.get_type_name(object_type))

## Apply creation template to space object (AC5)
static func _apply_creation_template(space_object: BaseSpaceObject, template: Dictionary, creation_data: Dictionary) -> void:
	"""Apply creation template properties to a space object.
	
	Args:
		space_object: Object to apply template to
		template: Template data with default properties
		creation_data: Override data from creation request
	"""
	# Merge template with creation data (creation_data takes precedence)
	var merged_data: Dictionary = template.duplicate()
	for key in creation_data.keys():
		merged_data[key] = creation_data[key]
	
	# Apply common properties
	if merged_data.has("max_health"):
		space_object.max_health = merged_data["max_health"]
	
	if merged_data.has("collision_radius"):
		space_object.collision_radius = merged_data["collision_radius"]
	
	if merged_data.has("position"):
		space_object.space_position = merged_data["position"]
	
	if merged_data.has("velocity"):
		space_object.space_velocity = merged_data["velocity"]
	
	if merged_data.has("orientation"):
		space_object.space_orientation = merged_data["orientation"]
	
	# Apply object-specific flags
	if merged_data.has("flags"):
		space_object.object_flags = merged_data["flags"]
	
	if merged_data.has("physics_enabled"):
		space_object.physics_enabled = merged_data["physics_enabled"]

## Create ship object with ship data from asset core (AC1, AC3)
static func create_ship_object(ship_data: Resource = null, ship_class_name: String = "") -> BaseSpaceObject:
	"""Create a ship object with proper asset integration.
	
	Args:
		ship_data: ShipData resource or null to load by name
		ship_class_name: Ship class name for asset loading
	
	Returns:
		Configured ship object or null on failure
	"""
	# Load ship data from asset core if needed (AC3)
	var actual_ship_data: Resource = ship_data
	if not actual_ship_data and ship_class_name != "":
		actual_ship_data = WCSAssetLoader.load_asset("ships/" + ship_class_name + ".tres")
	
	# Determine ship type based on ship data
	var ship_type: ObjectTypes.Type = ObjectTypes.Type.SHIP
	if actual_ship_data and actual_ship_data.has_method("get_ship_type"):
		var type_name: String = actual_ship_data.get_ship_type().to_lower()
		if type_name.contains("fighter"):
			ship_type = ObjectTypes.Type.FIGHTER
		elif type_name.contains("bomber"):
			ship_type = ObjectTypes.Type.BOMBER
		elif type_name.contains("capital"):
			ship_type = ObjectTypes.Type.CAPITAL
		elif type_name.contains("support"):
			ship_type = ObjectTypes.Type.SUPPORT
	
	# Create ship with configuration
	var creation_data: Dictionary = {}
	if actual_ship_data:
		creation_data["asset_path"] = "ships/" + ship_class_name + ".tres"
		if actual_ship_data.has_method("get_mass"):
			creation_data["mass"] = actual_ship_data.get_mass()
		if actual_ship_data.has_method("get_hull_strength"):
			creation_data["max_health"] = actual_ship_data.get_hull_strength()
	
	var ship: BaseSpaceObject = create_space_object(ship_type, creation_data)
	return ship

## Create weapon object with weapon data from asset core (AC1, AC3)
static func create_weapon_object(weapon_data: Resource = null, weapon_class_name: String = "") -> BaseSpaceObject:
	"""Create a weapon object with proper asset integration.
	
	Args:
		weapon_data: WeaponData resource or null to load by name
		weapon_class_name: Weapon class name for asset loading
	
	Returns:
		Configured weapon object or null on failure
	"""
	# Load weapon data from asset core if needed (AC3)
	var actual_weapon_data: Resource = weapon_data
	if not actual_weapon_data and weapon_class_name != "":
		actual_weapon_data = WCSAssetLoader.load_asset("weapons/" + weapon_class_name + ".tres")
	
	# Prepare creation data
	var creation_data: Dictionary = {}
	if actual_weapon_data:
		creation_data["asset_path"] = "weapons/" + weapon_class_name + ".tres"
		if actual_weapon_data.has_method("get_lifetime"):
			creation_data["lifetime"] = actual_weapon_data.get_lifetime()
		if actual_weapon_data.has_method("get_mass"):
			creation_data["mass"] = actual_weapon_data.get_mass()
		if actual_weapon_data.has_method("get_speed"):
			creation_data["velocity"] = Vector3(0, 0, actual_weapon_data.get_speed())
	
	var weapon: BaseSpaceObject = create_space_object(ObjectTypes.Type.WEAPON, creation_data)
	return weapon

## Create asteroid object with configuration (AC1)
static func create_asteroid_object(asteroid_config: Dictionary = {}) -> BaseSpaceObject:
	"""Create an asteroid object with specified configuration.
	
	Args:
		asteroid_config: Configuration data for asteroid properties
	
	Returns:
		Configured asteroid object
	"""
	var creation_data: Dictionary = asteroid_config.duplicate()
	
	# Apply asteroid-specific defaults
	if not creation_data.has("max_health"):
		creation_data["max_health"] = 100.0
	if not creation_data.has("collision_radius"):
		creation_data["collision_radius"] = 5.0
	
	# Apply size scaling if specified
	if creation_data.has("size_scale"):
		var scale: float = creation_data["size_scale"]
		creation_data["collision_radius"] = creation_data["collision_radius"] * scale
		creation_data["max_health"] = creation_data["max_health"] * (scale * scale)  # Volume scaling
	
	var asteroid: BaseSpaceObject = create_space_object(ObjectTypes.Type.ASTEROID, creation_data)
	return asteroid

## Create debris objects from destruction (AC1)
static func create_debris_objects(source_object: BaseSpaceObject, debris_count: int = 3) -> Array[BaseSpaceObject]:
	"""Create debris objects from a destroyed source object.
	
	Args:
		source_object: Object that was destroyed
		debris_count: Number of debris pieces to create
	
	Returns:
		Array of debris objects
	"""
	var debris_pieces: Array[BaseSpaceObject] = []
	
	if not source_object:
		push_warning("SpaceObjectFactory: Cannot create debris from null source object")
		return debris_pieces
	
	for i in range(debris_count):
		var creation_data: Dictionary = {
			"max_health": source_object.max_health * 0.1,  # 10% of original health
			"collision_radius": source_object.collision_radius * 0.3,  # Smaller pieces
			"position": source_object.space_position + Vector3(
				randf_range(-2.0, 2.0),
				randf_range(-2.0, 2.0),
				randf_range(-2.0, 2.0)
			),
			"velocity": Vector3(
				randf_range(-10.0, 10.0),
				randf_range(-10.0, 10.0),
				randf_range(-10.0, 10.0)
			)
		}
		
		var debris: BaseSpaceObject = create_space_object(ObjectTypes.Type.DEBRIS, creation_data)
		if debris:
			debris_pieces.append(debris)
	
	return debris_pieces

## SEXP system integration for dynamic object creation (AC8)
static func enable_sexp_integration() -> void:
	"""Enable SEXP system integration for mission scripting.
	"""
	sexp_enabled = true

static func disable_sexp_integration() -> void:
	"""Disable SEXP system integration.
	"""
	sexp_enabled = false

static func create_object_from_sexp(sexp_data: Dictionary) -> BaseSpaceObject:
	"""Create object from SEXP mission script data.
	
	Args:
		sexp_data: Object creation data from SEXP expression
	
	Returns:
		Created object or null on failure
	"""
	if not sexp_enabled:
		push_warning("SpaceObjectFactory: SEXP integration disabled")
		return null
	
	# Parse object type from SEXP data
	var type_name: String = sexp_data.get("type", "")
	var object_type: ObjectTypes.Type = ObjectTypes.parse_type_from_string(type_name)
	
	if object_type == ObjectTypes.Type.NONE:
		push_error("SpaceObjectFactory: Invalid object type in SEXP data: %s" % type_name)
		return null
	
	# Convert SEXP data to creation data
	var creation_data: Dictionary = {}
	if sexp_data.has("position"):
		creation_data["position"] = sexp_data["position"]
	if sexp_data.has("orientation"):
		creation_data["orientation"] = sexp_data["orientation"]
	if sexp_data.has("ship_class"):
		creation_data["asset_path"] = "ships/" + sexp_data["ship_class"] + ".tres"
	if sexp_data.has("weapon_class"):
		creation_data["asset_path"] = "weapons/" + sexp_data["weapon_class"] + ".tres"
	
	return create_space_object(object_type, creation_data)

## Register custom physics profile for type (AC5)
static func register_physics_profile(object_type: ObjectTypes.Type, profile: PhysicsProfile) -> void:
	"""Register a custom physics profile for an object type.
	
	Args:
		object_type: Object type to register profile for
		profile: Physics profile resource
	"""
	physics_profile_cache[object_type] = profile

## Clear physics profile cache
static func clear_physics_profile_cache() -> void:
	"""Clear all cached physics profiles.
	"""
	physics_profile_cache.clear()

## Initialize factory with default object types (AC4)
static func initialize_factory() -> void:
	"""Initialize factory with default WCS object type registrations.
	"""
	# Register core WCS object types with default templates
	register_object_type(ObjectTypes.Type.SHIP, {
		"max_health": 100.0,
		"collision_radius": 2.0,
		"physics_enabled": true
	})
	
	register_object_type(ObjectTypes.Type.FIGHTER, {
		"max_health": 75.0,
		"collision_radius": 1.5,
		"physics_enabled": true
	})
	
	register_object_type(ObjectTypes.Type.BOMBER, {
		"max_health": 120.0,
		"collision_radius": 2.5,
		"physics_enabled": true
	})
	
	register_object_type(ObjectTypes.Type.CAPITAL, {
		"max_health": 5000.0,
		"collision_radius": 50.0,
		"physics_enabled": true
	})
	
	register_object_type(ObjectTypes.Type.SUPPORT, {
		"max_health": 200.0,
		"collision_radius": 3.0,
		"physics_enabled": true
	})
	
	register_object_type(ObjectTypes.Type.WEAPON, {
		"max_health": 1.0,
		"collision_radius": 0.1,
		"physics_enabled": true,
		"lifetime": 10.0
	})
	
	register_object_type(ObjectTypes.Type.DEBRIS, {
		"max_health": 10.0,
		"collision_radius": 0.5,
		"physics_enabled": true
	})
	
	register_object_type(ObjectTypes.Type.ASTEROID, {
		"max_health": 100.0,
		"collision_radius": 5.0,
		"physics_enabled": true
	})
	
	register_object_type(ObjectTypes.Type.CARGO, {
		"max_health": 50.0,
		"collision_radius": 1.0,
		"physics_enabled": true
	})
	
	register_object_type(ObjectTypes.Type.WAYPOINT, {
		"max_health": 1.0,
		"collision_radius": 0.5,
		"physics_enabled": false
	})
	
	register_object_type(ObjectTypes.Type.JUMP_NODE, {
		"max_health": 1.0,
		"collision_radius": 10.0,
		"physics_enabled": false
	})
	
	print("SpaceObjectFactory: Initialized with %d registered object types" % registered_types.size())

## Get all registered object types (AC4)
static func get_registered_object_types() -> Array[ObjectTypes.Type]:
	"""Get all registered object types.
	
	Returns:
		Array of registered object type enum values
	"""
	var types: Array[ObjectTypes.Type] = []
	for object_type in registered_types.keys():
		types.append(object_type)
	return types

## Validate factory configuration (AC7)
static func validate_factory_configuration() -> bool:
	"""Validate that factory is properly configured.
	
	Returns:
		true if configuration is valid
	"""
	var errors: Array[String] = []
	
	# Check that core types are registered
	var required_types: Array[ObjectTypes.Type] = [
		ObjectTypes.Type.SHIP,
		ObjectTypes.Type.WEAPON,
		ObjectTypes.Type.DEBRIS,
		ObjectTypes.Type.ASTEROID
	]
	
	for required_type in required_types:
		if not is_object_type_registered(required_type):
			errors.append("Required type not registered: %s" % ObjectTypes.get_type_name(required_type))
	
	# Check that physics profiles are available
	for object_type in registered_types.keys():
		var profile: PhysicsProfile = get_physics_profile_for_type(object_type)
		if not profile:
			errors.append("No physics profile available for type: %s" % ObjectTypes.get_type_name(object_type))
	
	# Report errors
	if not errors.is_empty():
		push_error("SpaceObjectFactory validation failed:")
		for error in errors:
			push_error("  - %s" % error)
		return false
	
	return true

## Get factory debug information (AC7)
static func get_debug_info() -> Dictionary:
	"""Get debug information about factory state.
	
	Returns:
		Dictionary with factory status information
	"""
	return {
		"registered_types": registered_types.keys(),
		"registered_type_names": get_registered_object_types().map(func(t): return ObjectTypes.get_type_name(t)),
		"cached_profiles": physics_profile_cache.keys(),
		"cache_size": physics_profile_cache.size(),
		"sexp_enabled": sexp_enabled,
		"sexp_queue_size": sexp_creation_queue.size(),
		"template_count": creation_templates.size()
	}