class_name ObjectTypeData
extends BaseAssetData

## WCS Object Type Metadata and Classification System
## Based on WCS object type analysis and Godot integration requirements
## Provides comprehensive object classification metadata for all space objects

## Object behavior categories
enum BehaviorCategory {
	ENTITY = 0,        # Active game entities (ships, weapons, etc.)
	ENVIRONMENT = 1,   # Environmental objects (asteroids, debris)
	SYSTEM = 2,        # System objects (waypoints, triggers, etc.)
	EFFECT = 3,        # Visual/audio effects
	UI = 4             # User interface elements
}

## Object lifecycle phases
enum LifecyclePhase {
	CREATION = 0,      # Object is being created
	INITIALIZATION = 1, # Object is initializing systems
	ACTIVE = 2,        # Object is actively updating
	DORMANT = 3,       # Object is dormant but alive
	DYING = 4,         # Object is in destruction sequence
	DEAD = 5           # Object is dead and ready for cleanup
}

## Render priority levels
enum RenderPriority {
	BACKGROUND = 0,    # Background objects (asteroids, distant debris)
	STANDARD = 1,      # Standard objects (most ships, weapons)
	IMPORTANT = 2,     # Important objects (player ship, objectives)
	CRITICAL = 3,      # Critical objects (explosions, immediate threats)
	UI_OVERLAY = 4     # UI overlays and effects
}

## Core object type properties
@export_group("Type Information")
@export var object_type: int = 0                          # ObjectTypes.Type enum value
@export var wcs_type_id: int = 0                          # Original WCS type ID
@export var type_name: String = ""                        # Human-readable type name
@export var object_category: int = 0                      # ObjectTypes.Category enum value
@export var behavior_category: BehaviorCategory = BehaviorCategory.ENTITY

## Classification and metadata
@export_group("Classification")
@export var is_ship: bool = false                         # Ship or ship-like entity
@export var is_weapon: bool = false                       # Weapon or projectile
@export var is_effect: bool = false                       # Visual or audio effect
@export var is_environment: bool = false                  # Environmental object
@export var is_mission_critical: bool = false             # Mission-critical object
@export var is_player_controllable: bool = false          # Can be controlled by player
@export var is_ai_controllable: bool = false              # Can be controlled by AI

## Physics and collision properties
@export_group("Physics")
@export var has_physics: bool = true                      # Uses physics simulation
@export var has_collision: bool = true                    # Participates in collision detection
@export var collision_layer: int = 1                      # Default collision layer
@export var collision_mask: int = 1                       # Default collision mask
@export var default_mass: float = 1.0                     # Default mass for physics
@export var physics_profile_path: String = ""             # Path to default PhysicsProfile resource

## Rendering and visual properties
@export_group("Rendering")
@export var is_renderable: bool = true                    # Should be rendered
@export var has_lod: bool = true                          # Uses level-of-detail system
@export var render_priority: RenderPriority = RenderPriority.STANDARD
@export var max_render_distance: float = 10000.0          # Maximum render distance
@export var shadow_caster: bool = true                    # Casts shadows
@export var shadow_receiver: bool = true                  # Receives shadows

## Update and performance properties
@export_group("Performance")
@export var default_update_frequency: int = 1             # UpdateFrequencies.Frequency enum
@export var uses_object_pooling: bool = false             # Can be pooled for performance
@export var max_pool_size: int = 100                      # Maximum objects in pool
@export var supports_instancing: bool = false             # Supports GPU instancing
@export var memory_footprint_kb: float = 100.0           # Estimated memory usage

## Lifecycle and behavior properties
@export_group("Lifecycle")
@export var default_lifetime: float = -1.0                # Default lifetime (-1 = infinite)
@export var auto_cleanup: bool = true                     # Automatically clean up when dead
@export var respawnable: bool = false                     # Can be respawned
@export var persistent: bool = false                      # Survives scene changes
@export var network_synchronized: bool = false            # Synchronized over network

## Audio properties
@export_group("Audio")
@export var has_audio: bool = false                       # Can emit audio
@export var max_audio_sources: int = 1                    # Maximum simultaneous audio sources
@export var audio_priority: int = 50                      # Audio priority (0-100)
@export var max_audio_distance: float = 1000.0           # Maximum audio distance

## Special capabilities and flags
@export_group("Capabilities")
@export var can_dock: bool = false                        # Can dock with other objects
@export var can_be_targeted: bool = true                  # Can be targeted by weapons/AI
@export var can_take_damage: bool = true                  # Can receive damage
@export var has_shields: bool = false                     # Has shield system
@export var has_subsystems: bool = false                  # Has destructible subsystems
@export var can_warp: bool = false                        # Can warp in/out

## Factory and creation properties
@export_group("Factory")
@export var factory_class: String = ""                    # Factory class name for creation
@export var scene_path: String = ""                       # Path to object scene file
@export var script_path: String = ""                      # Path to object script file
@export var default_prefab_path: String = ""              # Path to default prefab

## Validation and constraints
@export_group("Constraints")
@export var min_spawn_distance: float = 0.0               # Minimum spawn distance from other objects
@export var max_spawn_distance: float = 50000.0           # Maximum spawn distance
@export var requires_clear_space: bool = false            # Requires clear space to spawn
@export var spawn_group_limit: int = -1                   # Maximum instances per group (-1 = unlimited)

## Custom metadata and extensions
@export_group("Custom")
@export var custom_flags: int = 0                         # Custom object flags
@export var custom_properties: Dictionary = {}            # Additional custom properties
@export var editor_metadata: Dictionary = {}              # Editor-specific metadata

## Static factory methods for common object types

static func create_ship_type_data(ship_type: String) -> ObjectTypeData:
	"""Create object type data for ship entities.
	
	Args:
		ship_type: Specific ship type identifier
	
	Returns:
		ObjectTypeData configured for ship objects
	"""
	var data: ObjectTypeData = ObjectTypeData.new()
	
	const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
	const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")
	const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")
	
	data.object_type = ObjectTypes.Type.SHIP
	data.type_name = ship_type + " Ship"
	data.object_category = ObjectTypes.Category.SHIP_CATEGORY
	data.behavior_category = BehaviorCategory.ENTITY
	
	data.is_ship = true
	data.is_ai_controllable = true
	data.has_physics = true
	data.has_collision = true
	data.collision_layer = CollisionLayers.Layer.SHIPS
	data.collision_mask = CollisionLayers.Mask.SHIP_STANDARD
	data.default_mass = 50.0
	
	data.is_renderable = true
	data.has_lod = true
	data.render_priority = RenderPriority.STANDARD
	data.shadow_caster = true
	data.shadow_receiver = true
	
	data.default_update_frequency = UpdateFrequencies.Frequency.HIGH
	data.can_be_targeted = true
	data.can_take_damage = true
	data.has_shields = true
	data.has_subsystems = true
	data.can_warp = true
	
	data.has_audio = true
	data.max_audio_sources = 4
	data.audio_priority = 75
	
	return data

static func create_weapon_type_data(weapon_type: String) -> ObjectTypeData:
	"""Create object type data for weapon projectiles.
	
	Args:
		weapon_type: Specific weapon type identifier
	
	Returns:
		ObjectTypeData configured for weapon objects
	"""
	var data: ObjectTypeData = ObjectTypeData.new()
	
	const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
	const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")
	const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")
	
	data.object_type = ObjectTypes.Type.WEAPON
	data.type_name = weapon_type + " Weapon"
	data.object_category = ObjectTypes.Category.WEAPON_CATEGORY
	data.behavior_category = BehaviorCategory.ENTITY
	
	data.is_weapon = true
	data.has_physics = true
	data.has_collision = true
	data.collision_layer = CollisionLayers.Layer.WEAPONS
	data.collision_mask = CollisionLayers.Mask.WEAPON_STANDARD
	data.default_mass = 0.5
	
	data.is_renderable = true
	data.has_lod = true
	data.render_priority = RenderPriority.STANDARD
	data.shadow_caster = false
	data.shadow_receiver = false
	
	data.default_update_frequency = UpdateFrequencies.Frequency.CRITICAL
	data.default_lifetime = 10.0  # Weapons have limited lifetime
	data.uses_object_pooling = true
	data.max_pool_size = 500
	data.auto_cleanup = true
	
	data.can_be_targeted = false
	data.can_take_damage = false
	data.has_shields = false
	
	return data

static func create_debris_type_data() -> ObjectTypeData:
	"""Create object type data for debris objects.
	
	Returns:
		ObjectTypeData configured for debris objects
	"""
	var data: ObjectTypeData = ObjectTypeData.new()
	
	const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
	const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")
	const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")
	
	data.object_type = ObjectTypes.Type.DEBRIS
	data.type_name = "Debris"
	data.object_category = ObjectTypes.Category.ENVIRONMENT_CATEGORY
	data.behavior_category = BehaviorCategory.ENVIRONMENT
	
	data.is_environment = true
	data.has_physics = true
	data.has_collision = true
	data.collision_layer = CollisionLayers.Layer.DEBRIS
	data.collision_mask = CollisionLayers.Mask.DEBRIS_STANDARD
	data.default_mass = 5.0
	
	data.is_renderable = true
	data.has_lod = true
	data.render_priority = RenderPriority.BACKGROUND
	data.shadow_caster = false
	data.shadow_receiver = true
	
	data.default_update_frequency = UpdateFrequencies.Frequency.LOW
	data.default_lifetime = 60.0  # Debris cleans up after 1 minute
	data.uses_object_pooling = true
	data.max_pool_size = 200
	data.auto_cleanup = true
	
	data.can_be_targeted = false
	data.can_take_damage = false
	data.has_shields = false
	
	return data

static func create_effect_type_data(effect_type: String) -> ObjectTypeData:
	"""Create object type data for visual effects.
	
	Args:
		effect_type: Specific effect type identifier
	
	Returns:
		ObjectTypeData configured for effect objects
	"""
	var data: ObjectTypeData = ObjectTypeData.new()
	
	const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
	const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")
	const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")
	
	data.object_type = ObjectTypes.Type.EFFECT
	data.type_name = effect_type + " Effect"
	data.object_category = ObjectTypes.Category.EFFECT_CATEGORY
	data.behavior_category = BehaviorCategory.EFFECT
	
	data.is_effect = true
	data.has_physics = false
	data.has_collision = false
	data.default_mass = 0.0
	
	data.is_renderable = true
	data.has_lod = true
	data.render_priority = RenderPriority.STANDARD
	data.shadow_caster = false
	data.shadow_receiver = false
	
	data.default_update_frequency = UpdateFrequencies.Frequency.MEDIUM
	data.default_lifetime = 5.0  # Effects are usually short-lived
	data.uses_object_pooling = true
	data.max_pool_size = 100
	data.auto_cleanup = true
	
	data.can_be_targeted = false
	data.can_take_damage = false
	data.has_shields = false
	
	data.has_audio = true
	data.max_audio_sources = 2
	data.audio_priority = 60
	
	return data

static func create_waypoint_type_data() -> ObjectTypeData:
	"""Create object type data for waypoint objects.
	
	Returns:
		ObjectTypeData configured for waypoint objects
	"""
	var data: ObjectTypeData = ObjectTypeData.new()
	
	const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
	const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")
	
	data.object_type = ObjectTypes.Type.WAYPOINT
	data.type_name = "Waypoint"
	data.object_category = ObjectTypes.Category.MISSION_CATEGORY
	data.behavior_category = BehaviorCategory.SYSTEM
	
	data.has_physics = false
	data.has_collision = false
	data.is_renderable = false  # Invisible in game, visible in editor
	
	data.default_update_frequency = UpdateFrequencies.Frequency.MINIMAL
	data.persistent = true  # Waypoints persist across scene changes
	
	data.can_be_targeted = false
	data.can_take_damage = false
	data.has_shields = false
	
	data.editor_metadata["editor_visible"] = true
	data.editor_metadata["editor_icon"] = "waypoint_icon"
	
	return data

## Utility methods

func get_behavior_category_name() -> String:
	"""Get human-readable name for the behavior category.
	
	Returns:
		String name of the behavior category
	"""
	match behavior_category:
		BehaviorCategory.ENTITY:
			return "Entity"
		BehaviorCategory.ENVIRONMENT:
			return "Environment"
		BehaviorCategory.SYSTEM:
			return "System"
		BehaviorCategory.EFFECT:
			return "Effect"
		BehaviorCategory.UI:
			return "UI"
		_:
			return "Unknown"

func get_lifecycle_phase_name(phase: LifecyclePhase) -> String:
	"""Get human-readable name for a lifecycle phase.
	
	Args:
		phase: Lifecycle phase enum value
	
	Returns:
		String name of the lifecycle phase
	"""
	match phase:
		LifecyclePhase.CREATION:
			return "Creation"
		LifecyclePhase.INITIALIZATION:
			return "Initialization"
		LifecyclePhase.ACTIVE:
			return "Active"
		LifecyclePhase.DORMANT:
			return "Dormant"
		LifecyclePhase.DYING:
			return "Dying"
		LifecyclePhase.DEAD:
			return "Dead"
		_:
			return "Unknown"

func get_render_priority_name() -> String:
	"""Get human-readable name for the render priority.
	
	Returns:
		String name of the render priority
	"""
	match render_priority:
		RenderPriority.BACKGROUND:
			return "Background"
		RenderPriority.STANDARD:
			return "Standard"
		RenderPriority.IMPORTANT:
			return "Important"
		RenderPriority.CRITICAL:
			return "Critical"
		RenderPriority.UI_OVERLAY:
			return "UI Overlay"
		_:
			return "Unknown"

func should_use_lod_at_distance(distance: float) -> bool:
	"""Check if LOD should be used at the given distance.
	
	Args:
		distance: Distance from player or camera
	
	Returns:
		true if LOD should be applied
	"""
	if not has_lod:
		return false
	
	const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")
	
	var threshold: float = UpdateFrequencies.DISTANCE_THRESHOLDS[UpdateFrequencies.DistanceThreshold.NEAR]
	return distance > threshold

func get_collision_layer_name() -> String:
	"""Get human-readable name for the collision layer.
	
	Returns:
		String name of the collision layer
	"""
	const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")
	return CollisionLayers.get_layer_name(collision_layer)

func get_update_frequency_name() -> String:
	"""Get human-readable name for the update frequency.
	
	Returns:
		String name of the update frequency
	"""
	const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")
	return UpdateFrequencies.get_frequency_name(default_update_frequency)

func is_valid_for_pooling() -> bool:
	"""Check if this object type is suitable for object pooling.
	
	Returns:
		true if object pooling is beneficial
	"""
	return uses_object_pooling and default_lifetime > 0.0 and auto_cleanup

func requires_network_sync() -> bool:
	"""Check if this object type requires network synchronization.
	
	Returns:
		true if network sync is needed
	"""
	return network_synchronized and (is_ship or is_weapon or is_mission_critical)

func get_estimated_memory_mb() -> float:
	"""Get estimated memory usage in megabytes.
	
	Returns:
		Estimated memory usage in MB
	"""
	return memory_footprint_kb / 1024.0

func copy_from_base_data(base_data: ObjectTypeData) -> void:
	"""Copy properties from a base object type data.
	
	Args:
		base_data: Base ObjectTypeData to copy from
	"""
	if not base_data:
		return
	
	# Copy base properties
	object_type = base_data.object_type
	object_category = base_data.object_category
	behavior_category = base_data.behavior_category
	
	# Copy physics properties
	has_physics = base_data.has_physics
	has_collision = base_data.has_collision
	collision_layer = base_data.collision_layer
	collision_mask = base_data.collision_mask
	default_mass = base_data.default_mass
	
	# Copy rendering properties
	is_renderable = base_data.is_renderable
	has_lod = base_data.has_lod
	render_priority = base_data.render_priority
	shadow_caster = base_data.shadow_caster
	shadow_receiver = base_data.shadow_receiver
	
	# Copy performance properties
	default_update_frequency = base_data.default_update_frequency
	uses_object_pooling = base_data.uses_object_pooling
	max_pool_size = base_data.max_pool_size

func _validate_implementation() -> ValidationResult:
	"""Validate the object type data configuration.
	
	Returns:
		ValidationResult with validation status and any errors
	"""
	var result: ValidationResult = ValidationResult.new(self.file_path, self.get_asset_type_name())
	result.clear()
	
	# Validate basic properties
	if type_name.is_empty():
		result.add_error("Object type name cannot be empty")
	
	if object_type < 0:
		result.add_error("Object type must be a valid enum value")
	
	# Validate physics properties
	if has_physics and default_mass <= 0.0:
		result.add_error("Objects with physics must have positive mass")
	
	if has_collision and not has_physics:
		result.add_warning("Collision without physics may cause issues")
	
	# Validate render properties
	if is_renderable and max_render_distance <= 0.0:
		result.add_error("Renderable objects must have positive render distance")
	
	# Validate lifetime properties
	if default_lifetime == 0.0:
		result.add_error("Object lifetime cannot be zero (use -1 for infinite)")
	
	if uses_object_pooling and max_pool_size <= 0:
		result.add_error("Object pooling requires positive pool size")
	
	# Validate audio properties
	if has_audio and max_audio_sources <= 0:
		result.add_error("Audio objects must have positive audio source count")
	
	return result

func get_asset_type() -> int:
	"""Get the asset type for this object type data.
	
	Returns:
		AssetTypes.Type enum value
	"""
	const AssetTypes = preload("res://addons/wcs_asset_core/constants/asset_types.gd")
	return AssetTypes.Type.TABLE_DATA

func get_display_name() -> String:
	"""Get display name for this object type data.
	
	Returns:
		Human-readable display name
	"""
	if not type_name.is_empty():
		return type_name
	else:
		return "Object Type Data"

func get_description() -> String:
	"""Get description of this object type data.
	
	Returns:
		Detailed description string
	"""
	var desc: String = "Object Type: %s\n" % type_name
	desc += "Category: %s\n" % get_behavior_category_name()
	desc += "Physics: %s\n" % ("Yes" if has_physics else "No")
	desc += "Collision: %s\n" % ("Yes" if has_collision else "No")
	desc += "Renderable: %s\n" % ("Yes" if is_renderable else "No")
	desc += "Update Frequency: %s\n" % get_update_frequency_name()
	
	if default_lifetime > 0.0:
		desc += "Lifetime: %.1fs\n" % default_lifetime
	
	if uses_object_pooling:
		desc += "Pool Size: %d\n" % max_pool_size
	
	return desc
