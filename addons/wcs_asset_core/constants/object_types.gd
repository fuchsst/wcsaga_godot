class_name ObjectTypes
extends RefCounted

## WCS Object Type Definitions and Constants
## Based on WCS source/code/object/object.h and object.cpp
## Provides complete object classification system for space objects

## Core object types from WCS object.h (lines 30-46)
## These match the original WCS OBJ_* constants for compatibility
enum Type {
	# Core object types (matching WCS defines)
	NONE = 0,           # unused object
	SHIP = 1,           # a ship (player, AI, capital ships)
	WEAPON = 2,         # a laser, missile, beam, etc
	FIREBALL = 3,       # an explosion or destruction effect
	START = 4,          # a starting point marker (player start, etc)
	WAYPOINT = 5,       # a waypoint object (navigation, AI pathfinding)
	DEBRIS = 6,         # a flying piece of ship debris
	COUNTERMEASURE = 7, # countermeasures (was commented out in WCS, restored for completeness)
	GHOST = 8,          # placeholder for when a player dies
	POINT = 9,          # generic object type to display a point in FRED
	SHOCKWAVE = 10,     # a shockwave from explosions
	WING = 11,          # not really a type used anywhere, but needed for FRED
	OBSERVER = 12,      # used for multiplayer observers
	ASTEROID = 13,      # an asteroid, a big rock, like debris
	JUMP_NODE = 14,     # a jump node object, used in FRED and missions
	BEAM = 15,          # beam weapons (special rendering and physics)
	
	# Extended types for Godot-specific functionality
	EFFECT = 100,       # Visual effects (particles, trails, etc)
	TRIGGER = 101,      # Invisible trigger zones for mission events
	CARGO = 102,        # Cargo containers and mission objectives
	SUPPORT = 103,      # Support ships (repair, rearm, etc)
	CAPITAL = 104,      # Large capital ships (special physics handling)
	FIGHTER = 105,      # Fighter craft (optimized collision and AI)
	BOMBER = 106,       # Bomber craft (different AI behavior)
	INSTALLATION = 107, # Space installations and bases
	NAVBUOY = 108,      # Navigation buoys and markers
	SENSOR = 109,       # Sensor objects and scanning equipment
	
	# Maximum type value for validation
	MAX_TYPE = 110
}

## Object flags from WCS object.h (lines 102-125)
## These control object behavior and rendering properties
enum Flags {
	RENDERS = 1 << 0,               # Object renders to screen
	COLLIDES = 1 << 1,              # Object participates in collision detection
	PHYSICS = 1 << 2,               # Object moves with standard physics
	SHOULD_BE_DEAD = 1 << 3,        # Object marked for deletion
	INVULNERABLE = 1 << 4,          # Object cannot take damage
	PROTECTED = 1 << 5,             # Mission-critical, don't auto-kill
	PLAYER_SHIP = 1 << 6,           # Player controlled ship
	NO_SHIELDS = 1 << 7,            # Object has no shield system
	JUST_UPDATED = 1 << 8,          # Multiplayer update received this frame
	COULD_BE_PLAYER = 1 << 9,       # Selectable for joining players
	WAS_RENDERED = 1 << 10,         # Rendered this frame (for optimization)
	NOT_IN_COLL = 1 << 11,          # Not in collision detection list
	BEAM_PROTECTED = 1 << 12,       # Don't fire beam weapons at this object
	SPECIAL_WARPIN = 1 << 13,       # Special warp-in effect enabled
	DOCKED_ALREADY_HANDLED = 1 << 14, # Docked object movement handled
	TARGETABLE_AS_BOMB = 1 << 15,   # Can be targeted as bomb/missile
	
	# Extended flags for Godot functionality
	GODOT_MANAGED = 1 << 20,        # Object managed by Godot physics system
	LOD_ENABLED = 1 << 21,          # Level-of-detail system enabled
	POOLED_OBJECT = 1 << 22,        # Object uses object pooling
	NETWORKED = 1 << 23,            # Object synchronized over network
	SCRIPTED = 1 << 24,             # Object has script behavior attached
	AUDIO_ENABLED = 1 << 25,        # Object can emit audio
	PARTICLE_EMITTER = 1 << 26,     # Object emits particle effects
	SHADOW_CASTER = 1 << 27,        # Object casts shadows
	LIGHT_RECEIVER = 1 << 28,       # Object receives lighting
	OCCLUDER = 1 << 29              # Object can occlude other objects
}

## Physics behavior flags from WCS physics.h (lines 18-32)
## Controls how objects interact with the physics system
enum PhysicsFlags {
	ACCELERATES = 1 << 1,           # Object can accelerate
	USE_VEL = 1 << 2,               # Use existing velocity vector
	AFTERBURNER_ON = 1 << 3,        # Afterburner currently engaged
	SLIDE_ENABLED = 1 << 4,         # Descent-style sliding enabled
	REDUCED_DAMP = 1 << 5,          # Reduced damping coefficient
	IN_SHOCKWAVE = 1 << 6,          # Currently affected by shockwave
	DEAD_DAMP = 1 << 7,             # Death damping applied
	AFTERBURNER_WAIT = 1 << 8,      # Afterburner cooldown period
	CONST_VEL = 1 << 9,             # Constant velocity (no acceleration)
	WARP_IN = 1 << 10,              # Currently warping into mission
	SPECIAL_WARP_IN = 1 << 11,      # Special warp-in effect
	WARP_OUT = 1 << 12,             # Currently warping out of mission
	SPECIAL_WARP_OUT = 1 << 13,     # Special warp-out effect
	BOOSTER_ON = 1 << 14,           # Booster system engaged
	GLIDING = 1 << 15,              # Gliding mode (reduced control)
	
	# Extended physics flags for Godot
	GODOT_RIGIDBODY = 1 << 20,      # Uses Godot RigidBody3D physics
	CUSTOM_PHYSICS = 1 << 21,       # Uses custom physics implementation
	GRAVITY_AFFECTED = 1 << 22,     # Affected by gravitational fields
	MAGNETIC_AFFECTED = 1 << 23,    # Affected by magnetic fields
	MOMENTUM_CONSERVED = 1 << 24,   # Newtonian momentum conservation
	ATMOSPHERIC_DRAG = 1 << 25,     # Atmospheric drag effects
	RELATIVISTIC = 1 << 26,         # Relativistic physics corrections
	QUANTUM_TUNNELING = 1 << 27     # Quantum tunneling effects (sci-fi)
}

## Object category groupings for organization and optimization
enum Category {
	NONE = 0,
	SHIP_CATEGORY = 1,
	WEAPON_CATEGORY = 2,
	EFFECT_CATEGORY = 3,
	ENVIRONMENT_CATEGORY = 4,
	SYSTEM_CATEGORY = 5,
	MISSION_CATEGORY = 6
}

## Object update priorities for LOD system
enum Priority {
	CRITICAL = 0,    # Player ship, immediate threats
	HIGH = 1,        # Active combat participants
	MEDIUM = 2,      # Nearby objects, secondary threats
	LOW = 3,         # Background objects, distant entities
	MINIMAL = 4      # Very distant or inactive objects
}

## WCS object type names from object.cpp (lines 83-103)
static var TYPE_NAMES: Dictionary = {
	Type.NONE: "None",
	Type.SHIP: "Ship",
	Type.WEAPON: "Weapon",
	Type.FIREBALL: "Fireball",
	Type.START: "Start",
	Type.WAYPOINT: "Waypoint",
	Type.DEBRIS: "Debris",
	Type.COUNTERMEASURE: "Countermeasure",
	Type.GHOST: "Ghost",
	Type.POINT: "Point",
	Type.SHOCKWAVE: "Shockwave",
	Type.WING: "Wing",
	Type.OBSERVER: "Observer",
	Type.ASTEROID: "Asteroid",
	Type.JUMP_NODE: "Jump Node",
	Type.BEAM: "Beam",
	
	# Extended type names
	Type.EFFECT: "Effect",
	Type.TRIGGER: "Trigger",
	Type.CARGO: "Cargo",
	Type.SUPPORT: "Support",
	Type.CAPITAL: "Capital",
	Type.FIGHTER: "Fighter",
	Type.BOMBER: "Bomber",
	Type.INSTALLATION: "Installation",
	Type.NAVBUOY: "Navigation Buoy",
	Type.SENSOR: "Sensor"
}

## Object category mappings
static var TYPE_CATEGORIES: Dictionary = {
	Type.NONE: Category.NONE,
	Type.SHIP: Category.SHIP_CATEGORY,
	Type.WEAPON: Category.WEAPON_CATEGORY,
	Type.FIREBALL: Category.EFFECT_CATEGORY,
	Type.START: Category.SYSTEM_CATEGORY,
	Type.WAYPOINT: Category.MISSION_CATEGORY,
	Type.DEBRIS: Category.ENVIRONMENT_CATEGORY,
	Type.COUNTERMEASURE: Category.WEAPON_CATEGORY,
	Type.GHOST: Category.SYSTEM_CATEGORY,
	Type.POINT: Category.SYSTEM_CATEGORY,
	Type.SHOCKWAVE: Category.EFFECT_CATEGORY,
	Type.WING: Category.SHIP_CATEGORY,
	Type.OBSERVER: Category.SYSTEM_CATEGORY,
	Type.ASTEROID: Category.ENVIRONMENT_CATEGORY,
	Type.JUMP_NODE: Category.MISSION_CATEGORY,
	Type.BEAM: Category.WEAPON_CATEGORY,
	
	# Extended categories
	Type.EFFECT: Category.EFFECT_CATEGORY,
	Type.TRIGGER: Category.MISSION_CATEGORY,
	Type.CARGO: Category.MISSION_CATEGORY,
	Type.SUPPORT: Category.SHIP_CATEGORY,
	Type.CAPITAL: Category.SHIP_CATEGORY,
	Type.FIGHTER: Category.SHIP_CATEGORY,
	Type.BOMBER: Category.SHIP_CATEGORY,
	Type.INSTALLATION: Category.ENVIRONMENT_CATEGORY,
	Type.NAVBUOY: Category.MISSION_CATEGORY,
	Type.SENSOR: Category.SYSTEM_CATEGORY
}

## WCS limits and constants from globals.h
const MAX_OBJECTS: int = 2000              # Maximum objects in scene
const MAX_OBJECT_TYPES: int = 16           # Original WCS type count
const UNUSED_OBJNUM: int = -4000           # Invalid object number
const MAX_SHIELD_SECTIONS: int = 4         # Shield quadrants per object
const MAX_OBJECT_SOUNDS: int = 32          # Audio sources per object

# Asset limits from WCS
const MAX_SHIPS: int = 400                 # Maximum ship instances
const MAX_SHIP_CLASSES: int = 130          # Maximum ship class definitions
const MAX_WEAPONS: int = 700               # Maximum weapon instances
const MAX_WEAPON_TYPES: int = 200          # Maximum weapon type definitions
const MAX_POLYGON_MODELS: int = 128        # Maximum 3D models loaded

# Collision system constants
const MIN_COLLISION_PAIRS: int = 2500      # Starting collision pair allocation
const COLLISION_PAIRS_BUMP: int = 1000     # Pair allocation increment
const DEFAULT_COLLISION_DELAY_MS: int = 25 # Default collision check delay
const QUICK_COLLISION_DELAY_MS: int = 0    # Immediate collision check
const EXTENDED_COLLISION_DELAY_MS: int = 100 # Distant object collision delay

## Utility functions

static func get_type_name(object_type: Type) -> String:
	"""Get human-readable name for an object type.
	
	Args:
		object_type: Object type enum value
	
	Returns:
		Human-readable type name or "Unknown" if not found
	"""
	return TYPE_NAMES.get(object_type, "Unknown")

static func get_type_category(object_type: Type) -> Category:
	"""Get the category for an object type.
	
	Args:
		object_type: Object type enum value
	
	Returns:
		Category enum value
	"""
	return TYPE_CATEGORIES.get(object_type, Category.NONE)

static func is_ship_type(object_type: Type) -> bool:
	"""Check if an object type represents a ship or ship-like entity.
	
	Args:
		object_type: Object type enum value
	
	Returns:
		true if type represents a ship
	"""
	return get_type_category(object_type) == Category.SHIP_CATEGORY

static func is_weapon_type(object_type: Type) -> bool:
	"""Check if an object type represents a weapon or projectile.
	
	Args:
		object_type: Object type enum value
	
	Returns:
		true if type represents a weapon
	"""
	return get_type_category(object_type) == Category.WEAPON_CATEGORY

static func is_effect_type(object_type: Type) -> bool:
	"""Check if an object type represents a visual or audio effect.
	
	Args:
		object_type: Object type enum value
	
	Returns:
		true if type represents an effect
	"""
	return get_type_category(object_type) == Category.EFFECT_CATEGORY

static func is_environment_type(object_type: Type) -> bool:
	"""Check if an object type represents environmental objects.
	
	Args:
		object_type: Object type enum value
	
	Returns:
		true if type represents environment
	"""
	return get_type_category(object_type) == Category.ENVIRONMENT_CATEGORY

static func is_mission_type(object_type: Type) -> bool:
	"""Check if an object type is mission-specific.
	
	Args:
		object_type: Object type enum value
	
	Returns:
		true if type is mission-specific
	"""
	return get_type_category(object_type) == Category.MISSION_CATEGORY

static func is_system_type(object_type: Type) -> bool:
	"""Check if an object type is a system or debug object.
	
	Args:
		object_type: Object type enum value
	
	Returns:
		true if type is system/debug
	"""
	return get_type_category(object_type) == Category.SYSTEM_CATEGORY

static func is_valid_type(object_type: Type) -> bool:
	"""Validate that an object type is within valid range.
	
	Args:
		object_type: Object type enum value
	
	Returns:
		true if type is valid
	"""
	return object_type >= Type.NONE and object_type < Type.MAX_TYPE

static func get_types_in_category(category: Category) -> Array[Type]:
	"""Get all object types in a specific category.
	
	Args:
		category: Category enum value
	
	Returns:
		Array of object type enum values in the category
	"""
	var types: Array[Type] = []
	
	for object_type in TYPE_CATEGORIES.keys():
		if TYPE_CATEGORIES[object_type] == category:
			types.append(object_type)
	
	return types

static func parse_type_from_string(type_string: String) -> Type:
	"""Parse object type from string representation.
	
	Args:
		type_string: String representation of type
	
	Returns:
		Parsed object type or Type.NONE if not found
	"""
	var search_string: String = type_string.to_lower().strip_edges()
	
	# Search in type names
	for type_value in TYPE_NAMES.keys():
		var type_name: String = TYPE_NAMES[type_value].to_lower()
		if type_name == search_string:
			return type_value
	
	# Search for partial matches
	for type_value in TYPE_NAMES.keys():
		var type_name: String = TYPE_NAMES[type_value].to_lower()
		if type_name.contains(search_string) or search_string.contains(type_name):
			return type_value
	
	return Type.NONE

static func get_all_types() -> Array[Type]:
	"""Get all available object types.
	
	Returns:
		Array of all object type enum values
	"""
	var types: Array[Type] = []
	for type_value in TYPE_NAMES.keys():
		types.append(type_value)
	
	return types

static func get_category_name(category: Category) -> String:
	"""Get human-readable name for a category.
	
	Args:
		category: Category enum value
	
	Returns:
		Human-readable category name
	"""
	match category:
		Category.NONE:
			return "None"
		Category.SHIP_CATEGORY:
			return "Ship"
		Category.WEAPON_CATEGORY:
			return "Weapon"
		Category.EFFECT_CATEGORY:
			return "Effect"
		Category.ENVIRONMENT_CATEGORY:
			return "Environment"
		Category.SYSTEM_CATEGORY:
			return "System"
		Category.MISSION_CATEGORY:
			return "Mission"
		_:
			return "Unknown"

static func has_flag(flags: int, flag: Flags) -> bool:
	"""Check if object has specific flag set.
	
	Args:
		flags: Object flags bitmask
		flag: Flag to check for
	
	Returns:
		true if flag is set
	"""
	return (flags & flag) != 0

static func set_flag(flags: int, flag: Flags) -> int:
	"""Set a specific flag on object.
	
	Args:
		flags: Current object flags bitmask
		flag: Flag to set
	
	Returns:
		Updated flags bitmask
	"""
	return flags | flag

static func clear_flag(flags: int, flag: Flags) -> int:
	"""Clear a specific flag on object.
	
	Args:
		flags: Current object flags bitmask
		flag: Flag to clear
	
	Returns:
		Updated flags bitmask
	"""
	return flags & ~flag

static func has_physics_flag(physics_flags: int, flag: PhysicsFlags) -> bool:
	"""Check if object has specific physics flag set.
	
	Args:
		physics_flags: Physics flags bitmask
		flag: Physics flag to check for
	
	Returns:
		true if physics flag is set
	"""
	return (physics_flags & flag) != 0

static func set_physics_flag(physics_flags: int, flag: PhysicsFlags) -> int:
	"""Set a specific physics flag on object.
	
	Args:
		physics_flags: Current physics flags bitmask
		flag: Physics flag to set
	
	Returns:
		Updated physics flags bitmask
	"""
	return physics_flags | flag

static func clear_physics_flag(physics_flags: int, flag: PhysicsFlags) -> int:
	"""Clear a specific physics flag on object.
	
	Args:
		physics_flags: Current physics flags bitmask
		flag: Physics flag to clear
	
	Returns:
		Updated physics flags bitmask
	"""
	return physics_flags & ~flag
