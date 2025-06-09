class_name CollisionLayers
extends RefCounted

## WCS Collision Layer Definitions and Physics Constants
## Based on WCS collision system analysis and Godot physics best practices
## Provides organized collision detection for different object categories

## Collision layer bit positions (0-31 available in Godot)
## These define which collision layers objects belong to
enum Layer {
	# Core object layers (bits 0-9)
	SHIPS = 0,              # Player and AI ships
	WEAPONS = 1,            # Projectiles, missiles, beams
	DEBRIS = 2,             # Ship debris and floating objects
	ASTEROIDS = 3,          # Environmental asteroids and rocks
	EFFECTS = 4,            # Explosions, shockwaves, visual effects
	ENVIRONMENT = 5,        # Static environment objects
	TRIGGERS = 6,           # Mission triggers and zones
	SHIELDS = 7,            # Shield collision detection
	BEAMS = 8,              # Beam weapons (special collision)
	COUNTERMEASURES = 9,    # Countermeasure deployables
	
	# Ship subcategories (bits 10-15)
	FIGHTERS = 10,          # Fighter craft
	BOMBERS = 11,           # Bomber craft
	CAPITALS = 12,          # Capital ships and large vessels
	CAPITAL_SHIPS = 12,     # Alias for compatibility
	SUPPORT = 13,           # Support ships (repair, rearm)
	CARGO = 14,             # Cargo vessels and containers
	INSTALLATIONS = 15,     # Space stations and installations
	
	# Weapon subcategories (bits 16-21)
	PRIMARY_WEAPONS = 16,   # Primary weapon projectiles
	SECONDARY_WEAPONS = 17, # Secondary weapon projectiles
	TURRET_WEAPONS = 18,    # Turret-fired projectiles
	BEAM_WEAPONS = 19,      # Beam weapon collision
	MISSILE_WEAPONS = 20,   # Missile and torpedo projectiles
	POINT_DEFENSE = 21,     # Point defense system projectiles
	
	# System and utility layers (bits 22-31)
	OBSERVERS = 22,         # Observer cameras and multiplayer ghosts
	WAYPOINTS = 23,         # Navigation waypoints
	JUMP_NODES = 24,        # Jump nodes and warp points
	SENSORS = 25,           # Sensor arrays and detection equipment
	DOCKING = 26,           # Docking bays and attachment points
	SHIELDS_INNER = 27,     # Inner shield collision layer
	PHYSICS_ONLY = 28,      # Physics simulation without gameplay collision
	DEBUG_OBJECTS = 29,     # Debug visualization objects
	UI_3D = 30,             # 3D UI elements in game world
	RESERVED = 31           # Reserved for future use
}

## Collision mask combinations for different object types
## These define what each object type can collide WITH
enum Mask {
	# Ship collision masks
	SHIP_STANDARD = (1 << Layer.SHIPS) | (1 << Layer.WEAPONS) | (1 << Layer.DEBRIS) | 
					(1 << Layer.ASTEROIDS) | (1 << Layer.ENVIRONMENT) | (1 << Layer.SHIELDS),
	
	SHIP_FIGHTER = (1 << Layer.SHIPS) | (1 << Layer.CAPITALS) | (1 << Layer.WEAPONS) | 
				   (1 << Layer.DEBRIS) | (1 << Layer.ASTEROIDS) | (1 << Layer.ENVIRONMENT) | 
				   (1 << Layer.SHIELDS) | (1 << Layer.BEAMS),
	
	SHIP_CAPITAL = (1 << Layer.SHIPS) | (1 << Layer.FIGHTERS) | (1 << Layer.BOMBERS) | 
				   (1 << Layer.WEAPONS) | (1 << Layer.DEBRIS) | (1 << Layer.ASTEROIDS) | 
				   (1 << Layer.ENVIRONMENT) | (1 << Layer.SHIELDS),
	
	SHIP_SUPPORT = (1 << Layer.SHIPS) | (1 << Layer.DEBRIS) | (1 << Layer.ASTEROIDS) | 
				   (1 << Layer.ENVIRONMENT) | (1 << Layer.SHIELDS),
	
	# Weapon collision masks
	WEAPON_STANDARD = (1 << Layer.SHIPS) | (1 << Layer.SHIELDS) | (1 << Layer.DEBRIS) | 
					  (1 << Layer.ASTEROIDS) | (1 << Layer.ENVIRONMENT),
	
	WEAPON_BEAM = (1 << Layer.SHIPS) | (1 << Layer.SHIELDS) | (1 << Layer.ASTEROIDS) | 
				  (1 << Layer.ENVIRONMENT),
	
	WEAPON_MISSILE = (1 << Layer.SHIPS) | (1 << Layer.SHIELDS) | (1 << Layer.DEBRIS) | 
					 (1 << Layer.ASTEROIDS) | (1 << Layer.ENVIRONMENT) | (1 << Layer.COUNTERMEASURES),
	
	WEAPON_POINT_DEFENSE = (1 << Layer.WEAPONS) | (1 << Layer.MISSILE_WEAPONS) | 
						   (1 << Layer.COUNTERMEASURES),
	
	# Environment collision masks
	DEBRIS_STANDARD = (1 << Layer.SHIPS) | (1 << Layer.WEAPONS) | (1 << Layer.DEBRIS) | 
					  (1 << Layer.ASTEROIDS) | (1 << Layer.ENVIRONMENT),
	
	ASTEROID_STANDARD = (1 << Layer.SHIPS) | (1 << Layer.WEAPONS) | (1 << Layer.DEBRIS) | 
						(1 << Layer.ASTEROIDS) | (1 << Layer.ENVIRONMENT),
	
	ENVIRONMENT_STATIC = (1 << Layer.SHIPS) | (1 << Layer.WEAPONS) | (1 << Layer.DEBRIS) | 
						 (1 << Layer.ASTEROIDS),
	
	# Effect collision masks
	EXPLOSION_DAMAGE = (1 << Layer.SHIPS) | (1 << Layer.SHIELDS),
	
	SHOCKWAVE_PHYSICS = (1 << Layer.SHIPS) | (1 << Layer.DEBRIS) | (1 << Layer.WEAPONS),
	
	# Shield collision masks
	SHIELD_OUTER = (1 << Layer.WEAPONS) | (1 << Layer.DEBRIS) | (1 << Layer.ASTEROIDS) | 
				   (1 << Layer.BEAMS),
	
	SHIELD_INNER = (1 << Layer.WEAPONS) | (1 << Layer.BEAMS),
	
	# Trigger and system masks
	TRIGGER_AREA = (1 << Layer.SHIPS) | (1 << Layer.FIGHTERS) | (1 << Layer.BOMBERS) | 
				   (1 << Layer.CAPITALS),
	
	SENSOR_DETECTION = (1 << Layer.SHIPS) | (1 << Layer.WEAPONS) | (1 << Layer.ASTEROIDS),
	
	WAYPOINT_NAVIGATION = (1 << Layer.SHIPS),
	
	DOCKING_BAY = (1 << Layer.SHIPS) | (1 << Layer.FIGHTERS) | (1 << Layer.BOMBERS) | 
				  (1 << Layer.SUPPORT),
	
	# Special masks
	PHYSICS_ALL = 0xFFFFFFFF,  # Collides with everything (use sparingly)
	PHYSICS_NONE = 0,          # Collides with nothing
	DEBUG_VISUALIZATION = (1 << Layer.DEBUG_OBJECTS),
	
	UI_INTERACTION = (1 << Layer.UI_3D)
}

## Collision priority levels for performance optimization
enum Priority {
	CRITICAL = 0,     # Player ship, immediate threats - every frame
	HIGH = 1,         # Active combat - 60 FPS
	MEDIUM = 2,       # Nearby objects - 30 FPS  
	LOW = 3,          # Background objects - 15 FPS
	MINIMAL = 4       # Very distant objects - 5 FPS
}

## Collision shape complexity levels for LOD
enum ShapeComplexity {
	POINT = 0,        # Point collision (particles, effects)
	SPHERE = 1,       # Sphere collision (simple objects)
	CAPSULE = 2,      # Capsule collision (missiles, beams)
	BOX = 3,          # Box collision (cargo, simple ships)
	HULL = 4,         # Convex hull (fighters, small ships)
	MESH = 5,         # Triangle mesh (capitals, detailed collision)
	COMPOUND = 6      # Multiple shapes (complex ships with subsystems)
}

## Layer name mappings for debugging and editor display
static var LAYER_NAMES: Dictionary = {
	Layer.SHIPS: "Ships",
	Layer.WEAPONS: "Weapons", 
	Layer.DEBRIS: "Debris",
	Layer.ASTEROIDS: "Asteroids",
	Layer.EFFECTS: "Effects",
	Layer.ENVIRONMENT: "Environment",
	Layer.TRIGGERS: "Triggers",
	Layer.SHIELDS: "Shields",
	Layer.BEAMS: "Beams",
	Layer.COUNTERMEASURES: "Countermeasures",
	Layer.FIGHTERS: "Fighters",
	Layer.BOMBERS: "Bombers",
	Layer.CAPITALS: "Capitals",
	Layer.SUPPORT: "Support",
	Layer.CARGO: "Cargo",
	Layer.INSTALLATIONS: "Installations",
	Layer.PRIMARY_WEAPONS: "Primary Weapons",
	Layer.SECONDARY_WEAPONS: "Secondary Weapons",
	Layer.TURRET_WEAPONS: "Turret Weapons",
	Layer.BEAM_WEAPONS: "Beam Weapons",
	Layer.MISSILE_WEAPONS: "Missile Weapons",
	Layer.POINT_DEFENSE: "Point Defense",
	Layer.OBSERVERS: "Observers",
	Layer.WAYPOINTS: "Waypoints",
	Layer.JUMP_NODES: "Jump Nodes",
	Layer.SENSORS: "Sensors",
	Layer.DOCKING: "Docking",
	Layer.SHIELDS_INNER: "Shields Inner",
	Layer.PHYSICS_ONLY: "Physics Only",
	Layer.DEBUG_OBJECTS: "Debug Objects",
	Layer.UI_3D: "UI 3D",
	Layer.RESERVED: "Reserved"
}

## Collision performance constants from WCS analysis
const DEFAULT_COLLISION_CHECK_DELAY_MS: int = 25    # Standard collision check interval
const QUICK_COLLISION_CHECK_DELAY_MS: int = 0       # Immediate collision check
const EXTENDED_COLLISION_CHECK_DELAY_MS: int = 100   # Distant object collision check
const MIN_COLLISION_PAIRS: int = 2500                # Initial collision pair allocation
const COLLISION_PAIRS_BUMP: int = 1000               # Collision pair increment

## Distance thresholds for collision optimization
const NEAR_COLLISION_DISTANCE: float = 100.0        # Close proximity collision
const MEDIUM_COLLISION_DISTANCE: float = 500.0      # Medium distance collision
const FAR_COLLISION_DISTANCE: float = 2000.0        # Far distance collision
const VERY_FAR_COLLISION_DISTANCE: float = 5000.0   # Very far collision (minimal)

## Shield collision constants
const MAX_SHIELD_SECTIONS: int = 4                  # Shield quadrants per object
const SHIELD_COLLISION_TOLERANCE: float = 0.1       # Shield collision precision
const SHIELD_RECHARGE_DELAY_MS: int = 1000          # Shield recharge delay

## Beam weapon collision constants
const BEAM_COLLISION_SEGMENTS: int = 32             # Beam collision subdivision
const BEAM_MAX_LENGTH: float = 10000.0              # Maximum beam range
const BEAM_WIDTH_TOLERANCE: float = 0.5             # Beam collision width

## Debris and particle collision constants
const DEBRIS_COLLISION_LIFETIME_MS: int = 30000     # Debris collision lifetime
const PARTICLE_COLLISION_THRESHOLD: float = 1.0     # Minimum size for particle collision
const MAX_DEBRIS_OBJECTS: int = 200                 # Maximum debris with collision

## Utility functions

static func get_layer_name(layer: Layer) -> String:
	"""Get human-readable name for a collision layer.
	
	Args:
		layer: Collision layer enum value
	
	Returns:
		Human-readable layer name or "Unknown" if not found
	"""
	return LAYER_NAMES.get(layer, "Unknown Layer")

static func create_layer_bit(layer: Layer) -> int:
	"""Create a bitmask for a single collision layer.
	
	Args:
		layer: Collision layer enum value
	
	Returns:
		Bitmask with only the specified layer bit set
	"""
	return 1 << layer

static func combine_layers(layers: Array[Layer]) -> int:
	"""Combine multiple collision layers into a single bitmask.
	
	Args:
		layers: Array of collision layer enum values
	
	Returns:
		Combined bitmask with all specified layer bits set
	"""
	var combined_mask: int = 0
	
	for layer in layers:
		combined_mask |= (1 << layer)
	
	return combined_mask

static func has_layer(mask: int, layer: Layer) -> bool:
	"""Check if a collision mask includes a specific layer.
	
	Args:
		mask: Collision mask bitmask
		layer: Layer to check for
	
	Returns:
		true if the mask includes the specified layer
	"""
	return (mask & (1 << layer)) != 0

static func add_layer(mask: int, layer: Layer) -> int:
	"""Add a collision layer to an existing mask.
	
	Args:
		mask: Current collision mask
		layer: Layer to add
	
	Returns:
		Updated collision mask with the layer added
	"""
	return mask | (1 << layer)

static func remove_layer(mask: int, layer: Layer) -> int:
	"""Remove a collision layer from an existing mask.
	
	Args:
		mask: Current collision mask
		layer: Layer to remove
	
	Returns:
		Updated collision mask with the layer removed
	"""
	return mask & ~(1 << layer)

static func get_ship_collision_mask(ship_type: int) -> int:
	"""Get appropriate collision mask for a ship type.
	
	Args:
		ship_type: Ship type from ObjectTypes.Type
	
	Returns:
		Collision mask appropriate for the ship type
	"""
	# Import ObjectTypes for type checking
	const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
	
	match ship_type:
		ObjectTypes.Type.FIGHTER:
			return Mask.SHIP_FIGHTER
		ObjectTypes.Type.BOMBER:
			return Mask.SHIP_FIGHTER  # Bombers use similar collision to fighters
		ObjectTypes.Type.CAPITAL:
			return Mask.SHIP_CAPITAL
		ObjectTypes.Type.SUPPORT:
			return Mask.SHIP_SUPPORT
		_:
			return Mask.SHIP_STANDARD

static func get_weapon_collision_mask(weapon_type: int) -> int:
	"""Get appropriate collision mask for a weapon type.
	
	Args:
		weapon_type: Weapon type from ObjectTypes.Type
	
	Returns:
		Collision mask appropriate for the weapon type
	"""
	const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
	
	match weapon_type:
		ObjectTypes.Type.BEAM:
			return Mask.WEAPON_BEAM
		ObjectTypes.Type.COUNTERMEASURE:
			return Mask.WEAPON_POINT_DEFENSE
		_:
			# Check if it's a missile-type weapon
			if weapon_type == ObjectTypes.Type.WEAPON:
				return Mask.WEAPON_MISSILE
			else:
				return Mask.WEAPON_STANDARD

static func get_collision_priority_for_distance(distance: float) -> Priority:
	"""Determine collision priority based on distance from player.
	
	Args:
		distance: Distance from player or camera
	
	Returns:
		Appropriate collision priority level
	"""
	if distance <= NEAR_COLLISION_DISTANCE:
		return Priority.CRITICAL
	elif distance <= MEDIUM_COLLISION_DISTANCE:
		return Priority.HIGH
	elif distance <= FAR_COLLISION_DISTANCE:
		return Priority.MEDIUM
	elif distance <= VERY_FAR_COLLISION_DISTANCE:
		return Priority.LOW
	else:
		return Priority.MINIMAL

static func get_shape_complexity_for_distance(distance: float) -> ShapeComplexity:
	"""Determine appropriate collision shape complexity based on distance.
	
	Args:
		distance: Distance from player or camera
	
	Returns:
		Appropriate collision shape complexity level
	"""
	if distance <= NEAR_COLLISION_DISTANCE:
		return ShapeComplexity.MESH  # Full detail collision
	elif distance <= MEDIUM_COLLISION_DISTANCE:
		return ShapeComplexity.HULL  # Convex hull collision
	elif distance <= FAR_COLLISION_DISTANCE:
		return ShapeComplexity.BOX   # Box collision
	else:
		return ShapeComplexity.SPHERE # Simple sphere collision

static func get_collision_check_delay_ms(priority: Priority) -> int:
	"""Get collision check delay based on priority level.
	
	Args:
		priority: Collision priority level
	
	Returns:
		Delay in milliseconds between collision checks
	"""
	match priority:
		Priority.CRITICAL:
			return QUICK_COLLISION_CHECK_DELAY_MS
		Priority.HIGH:
			return DEFAULT_COLLISION_CHECK_DELAY_MS
		Priority.MEDIUM:
			return DEFAULT_COLLISION_CHECK_DELAY_MS * 2
		Priority.LOW:
			return EXTENDED_COLLISION_CHECK_DELAY_MS
		Priority.MINIMAL:
			return EXTENDED_COLLISION_CHECK_DELAY_MS * 2
		_:
			return DEFAULT_COLLISION_CHECK_DELAY_MS

static func is_valid_layer(layer: Layer) -> bool:
	"""Validate that a collision layer is within valid range.
	
	Args:
		layer: Collision layer enum value
	
	Returns:
		true if layer is valid for Godot physics system
	"""
	return layer >= Layer.SHIPS and layer <= Layer.RESERVED

static func get_all_layers() -> Array[Layer]:
	"""Get all available collision layers.
	
	Returns:
		Array of all collision layer enum values
	"""
	var layers: Array[Layer] = []
	for layer_value in LAYER_NAMES.keys():
		layers.append(layer_value)
	
	return layers

static func get_priority_name(priority: Priority) -> String:
	"""Get human-readable name for a collision priority.
	
	Args:
		priority: Priority enum value
	
	Returns:
		Human-readable priority name
	"""
	match priority:
		Priority.CRITICAL:
			return "Critical"
		Priority.HIGH:
			return "High"
		Priority.MEDIUM:
			return "Medium"
		Priority.LOW:
			return "Low"
		Priority.MINIMAL:
			return "Minimal"
		_:
			return "Unknown"

static func get_shape_complexity_name(complexity: ShapeComplexity) -> String:
	"""Get human-readable name for a shape complexity level.
	
	Args:
		complexity: Shape complexity enum value
	
	Returns:
		Human-readable complexity name
	"""
	match complexity:
		ShapeComplexity.POINT:
			return "Point"
		ShapeComplexity.SPHERE:
			return "Sphere"
		ShapeComplexity.CAPSULE:
			return "Capsule"
		ShapeComplexity.BOX:
			return "Box"
		ShapeComplexity.HULL:
			return "Hull"
		ShapeComplexity.MESH:
			return "Mesh"
		ShapeComplexity.COMPOUND:
			return "Compound"
		_:
			return "Unknown"
