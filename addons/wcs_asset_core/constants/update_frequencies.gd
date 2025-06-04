class_name UpdateFrequencies
extends RefCounted

## WCS Update Frequency and LOD System Constants
## Based on WCS performance analysis and Godot optimization best practices
## Provides dynamic Level-of-Detail (LOD) system for object updates and rendering

## Update frequency levels for performance optimization
enum Frequency {
	CRITICAL = 0,      # 60 FPS - Player ship, immediate threats, active combat
	HIGH = 1,          # 30 FPS - Nearby objects, secondary threats
	MEDIUM = 2,        # 15 FPS - Medium distance objects, background activity
	LOW = 3,           # 5 FPS - Distant objects, minimal activity
	MINIMAL = 4,       # 1 FPS - Very distant objects, dormant systems
	SUSPENDED = 5      # 0 FPS - Paused objects, out of range systems
}

## LOD (Level of Detail) levels for different systems
enum LODLevel {
	MAXIMUM = 0,       # Full detail - all systems active
	HIGH_DETAIL = 1,   # High detail - most systems active
	MEDIUM_DETAIL = 2, # Medium detail - essential systems only
	LOW_DETAIL = 3,    # Low detail - minimal systems
	MINIMAL_DETAIL = 4,# Minimal detail - basic representation only
	CULLED = 5         # Culled - not processed or rendered
}

## Distance thresholds for LOD calculations (in Godot units)
enum DistanceThreshold {
	IMMEDIATE = 0,     # 0-50 units - Player vicinity
	NEAR = 1,          # 50-200 units - Close combat range
	MEDIUM = 2,        # 200-1000 units - Medium engagement range
	FAR = 3,           # 1000-5000 units - Long range
	VERY_FAR = 4,      # 5000-20000 units - Very distant
	EXTREME = 5        # 20000+ units - Extreme distance
}

## System categories for selective LOD
enum SystemCategory {
	CORE = 0,          # Core object systems (position, physics)
	VISUAL = 1,        # Visual systems (rendering, effects)
	AUDIO = 2,         # Audio systems (sound effects, music)
	AI = 3,            # AI systems (behavior, pathfinding)
	PHYSICS = 4,       # Physics systems (collision, movement)
	NETWORKING = 5,    # Network synchronization systems
	PARTICLE = 6,      # Particle and effect systems
	ANIMATION = 7,     # Animation and interpolation systems
	SUBSYSTEM = 8,     # Ship subsystem management
	UI = 9             # UI and HUD systems
}

## Update timing constants (in milliseconds)
const UPDATE_FREQUENCY_MS: Dictionary = {
	Frequency.CRITICAL: 16,      # ~60 FPS (16.67ms)
	Frequency.HIGH: 33,          # ~30 FPS (33.33ms)
	Frequency.MEDIUM: 66,        # ~15 FPS (66.67ms)
	Frequency.LOW: 200,          # ~5 FPS (200ms)
	Frequency.MINIMAL: 1000,     # ~1 FPS (1000ms)
	Frequency.SUSPENDED: -1      # No updates
}

## Distance thresholds in Godot units
const DISTANCE_THRESHOLDS: Dictionary = {
	DistanceThreshold.IMMEDIATE: 50.0,
	DistanceThreshold.NEAR: 200.0,
	DistanceThreshold.MEDIUM: 1000.0,
	DistanceThreshold.FAR: 5000.0,
	DistanceThreshold.VERY_FAR: 20000.0,
	DistanceThreshold.EXTREME: 100000.0
}

## Performance limits for different object counts
const PERFORMANCE_LIMITS: Dictionary = {
	"max_critical_objects": 10,     # Maximum objects at critical frequency
	"max_high_objects": 50,         # Maximum objects at high frequency
	"max_medium_objects": 200,      # Maximum objects at medium frequency
	"max_low_objects": 500,         # Maximum objects at low frequency
	"max_minimal_objects": 1000,    # Maximum objects at minimal frequency
	"total_object_limit": 2000      # WCS maximum object limit
}

## LOD system configuration
const LOD_CONFIG: Dictionary = {
	"distance_fade_factor": 0.8,        # Distance fade multiplier
	"performance_scaling": true,        # Enable performance-based scaling
	"dynamic_adjustment": true,         # Enable dynamic LOD adjustment
	"frame_time_target_ms": 16.67,     # Target frame time (60 FPS)
	"performance_buffer": 0.2,         # Performance headroom (20%)
	"update_budget_ms": 5.0,           # Maximum time for LOD updates per frame
	"distance_check_interval_ms": 100   # How often to recalculate distances
}

## System-specific LOD configurations
const SYSTEM_LOD_CONFIG: Dictionary = {
	SystemCategory.CORE: {
		"always_update": true,
		"min_frequency": Frequency.MEDIUM,
		"distance_multiplier": 1.0
	},
	SystemCategory.VISUAL: {
		"always_update": false,
		"min_frequency": Frequency.MINIMAL,
		"distance_multiplier": 1.0,
		"culling_enabled": true
	},
	SystemCategory.AUDIO: {
		"always_update": false,
		"min_frequency": Frequency.LOW,
		"distance_multiplier": 0.5,  # Audio travels farther
		"max_audio_distance": 2000.0
	},
	SystemCategory.AI: {
		"always_update": false,
		"min_frequency": Frequency.LOW,
		"distance_multiplier": 1.2,  # AI needs less frequent updates at distance
		"combat_multiplier": 0.5     # More frequent during combat
	},
	SystemCategory.PHYSICS: {
		"always_update": true,
		"min_frequency": Frequency.HIGH,
		"distance_multiplier": 1.0,
		"collision_distance_factor": 0.8
	},
	SystemCategory.NETWORKING: {
		"always_update": false,
		"min_frequency": Frequency.MEDIUM,
		"distance_multiplier": 1.0,
		"interpolation_enabled": true
	},
	SystemCategory.PARTICLE: {
		"always_update": false,
		"min_frequency": Frequency.MINIMAL,
		"distance_multiplier": 0.8,
		"max_particles_distance": 1500.0
	},
	SystemCategory.ANIMATION: {
		"always_update": false,
		"min_frequency": Frequency.MINIMAL,
		"distance_multiplier": 1.0,
		"blend_distance": 500.0
	},
	SystemCategory.SUBSYSTEM: {
		"always_update": false,
		"min_frequency": Frequency.LOW,
		"distance_multiplier": 1.5,
		"detail_threshold": 300.0
	},
	SystemCategory.UI: {
		"always_update": true,
		"min_frequency": Frequency.HIGH,
		"distance_multiplier": 0.3   # UI follows player closely
	}
}

## Object type specific LOD overrides
const OBJECT_TYPE_LOD_OVERRIDES: Dictionary = {
	# Ships get priority treatment
	"ship_base_frequency": Frequency.HIGH,
	"ship_combat_frequency": Frequency.CRITICAL,
	"capital_ship_frequency": Frequency.MEDIUM,
	
	# Weapons need frequent updates when active
	"weapon_active_frequency": Frequency.CRITICAL,
	"weapon_idle_frequency": Frequency.MINIMAL,
	"beam_weapon_frequency": Frequency.CRITICAL,
	
	# Effects can be more aggressively culled
	"effect_frequency": Frequency.MEDIUM,
	"explosion_frequency": Frequency.HIGH,
	"particle_frequency": Frequency.LOW,
	
	# Environment objects update less frequently
	"debris_frequency": Frequency.LOW,
	"asteroid_frequency": Frequency.MINIMAL,
	"waypoint_frequency": Frequency.MINIMAL
}

## Performance monitoring thresholds
const PERFORMANCE_THRESHOLDS: Dictionary = {
	"frame_time_warning_ms": 20.0,      # Warning when frame time exceeds this
	"frame_time_critical_ms": 30.0,     # Critical when frame time exceeds this
	"object_count_warning": 1500,       # Warning object count
	"object_count_critical": 1800,      # Critical object count
	"memory_warning_mb": 400,           # Memory usage warning
	"memory_critical_mb": 500           # Memory usage critical
}

## Frequency name mappings for debugging
static var FREQUENCY_NAMES: Dictionary = {
	Frequency.CRITICAL: "Critical",
	Frequency.HIGH: "High",
	Frequency.MEDIUM: "Medium", 
	Frequency.LOW: "Low",
	Frequency.MINIMAL: "Minimal",
	Frequency.SUSPENDED: "Suspended"
}

## LOD level name mappings
static var LOD_LEVEL_NAMES: Dictionary = {
	LODLevel.MAXIMUM: "Maximum",
	LODLevel.HIGH_DETAIL: "High Detail",
	LODLevel.MEDIUM_DETAIL: "Medium Detail",
	LODLevel.LOW_DETAIL: "Low Detail",
	LODLevel.MINIMAL_DETAIL: "Minimal Detail",
	LODLevel.CULLED: "Culled"
}

## Distance threshold name mappings
static var DISTANCE_NAMES: Dictionary = {
	DistanceThreshold.IMMEDIATE: "Immediate",
	DistanceThreshold.NEAR: "Near",
	DistanceThreshold.MEDIUM: "Medium",
	DistanceThreshold.FAR: "Far",
	DistanceThreshold.VERY_FAR: "Very Far",
	DistanceThreshold.EXTREME: "Extreme"
}

## System category name mappings
static var SYSTEM_CATEGORY_NAMES: Dictionary = {
	SystemCategory.CORE: "Core",
	SystemCategory.VISUAL: "Visual",
	SystemCategory.AUDIO: "Audio",
	SystemCategory.AI: "AI",
	SystemCategory.PHYSICS: "Physics",
	SystemCategory.NETWORKING: "Networking",
	SystemCategory.PARTICLE: "Particle",
	SystemCategory.ANIMATION: "Animation",
	SystemCategory.SUBSYSTEM: "Subsystem",
	SystemCategory.UI: "UI"
}

## Utility functions

static func get_frequency_name(frequency: Frequency) -> String:
	"""Get human-readable name for an update frequency.
	
	Args:
		frequency: Update frequency enum value
	
	Returns:
		Human-readable frequency name
	"""
	return FREQUENCY_NAMES.get(frequency, "Unknown")

static func get_lod_level_name(lod_level: LODLevel) -> String:
	"""Get human-readable name for a LOD level.
	
	Args:
		lod_level: LOD level enum value
	
	Returns:
		Human-readable LOD level name
	"""
	return LOD_LEVEL_NAMES.get(lod_level, "Unknown")

static func get_distance_threshold_name(threshold: DistanceThreshold) -> String:
	"""Get human-readable name for a distance threshold.
	
	Args:
		threshold: Distance threshold enum value
	
	Returns:
		Human-readable threshold name
	"""
	return DISTANCE_NAMES.get(threshold, "Unknown")

static func get_system_category_name(category: SystemCategory) -> String:
	"""Get human-readable name for a system category.
	
	Args:
		category: System category enum value
	
	Returns:
		Human-readable category name
	"""
	return SYSTEM_CATEGORY_NAMES.get(category, "Unknown")

static func get_update_interval_ms(frequency: Frequency) -> int:
	"""Get update interval in milliseconds for a frequency level.
	
	Args:
		frequency: Update frequency enum value
	
	Returns:
		Update interval in milliseconds, or -1 for suspended
	"""
	return UPDATE_FREQUENCY_MS.get(frequency, 1000)

static func get_frequency_for_distance(distance: float) -> Frequency:
	"""Determine appropriate update frequency based on distance.
	
	Args:
		distance: Distance from player or camera
	
	Returns:
		Appropriate update frequency level
	"""
	if distance <= DISTANCE_THRESHOLDS[DistanceThreshold.IMMEDIATE]:
		return Frequency.CRITICAL
	elif distance <= DISTANCE_THRESHOLDS[DistanceThreshold.NEAR]:
		return Frequency.HIGH
	elif distance <= DISTANCE_THRESHOLDS[DistanceThreshold.MEDIUM]:
		return Frequency.MEDIUM
	elif distance <= DISTANCE_THRESHOLDS[DistanceThreshold.FAR]:
		return Frequency.LOW
	elif distance <= DISTANCE_THRESHOLDS[DistanceThreshold.VERY_FAR]:
		return Frequency.MINIMAL
	else:
		return Frequency.SUSPENDED

static func get_lod_level_for_distance(distance: float) -> LODLevel:
	"""Determine appropriate LOD level based on distance.
	
	Args:
		distance: Distance from player or camera
	
	Returns:
		Appropriate LOD level
	"""
	if distance <= DISTANCE_THRESHOLDS[DistanceThreshold.IMMEDIATE]:
		return LODLevel.MAXIMUM
	elif distance <= DISTANCE_THRESHOLDS[DistanceThreshold.NEAR]:
		return LODLevel.HIGH_DETAIL
	elif distance <= DISTANCE_THRESHOLDS[DistanceThreshold.MEDIUM]:
		return LODLevel.MEDIUM_DETAIL
	elif distance <= DISTANCE_THRESHOLDS[DistanceThreshold.FAR]:
		return LODLevel.LOW_DETAIL
	elif distance <= DISTANCE_THRESHOLDS[DistanceThreshold.VERY_FAR]:
		return LODLevel.MINIMAL_DETAIL
	else:
		return LODLevel.CULLED

static func get_distance_threshold(distance: float) -> DistanceThreshold:
	"""Get the distance threshold category for a given distance.
	
	Args:
		distance: Distance value to categorize
	
	Returns:
		Distance threshold category
	"""
	if distance <= DISTANCE_THRESHOLDS[DistanceThreshold.IMMEDIATE]:
		return DistanceThreshold.IMMEDIATE
	elif distance <= DISTANCE_THRESHOLDS[DistanceThreshold.NEAR]:
		return DistanceThreshold.NEAR
	elif distance <= DISTANCE_THRESHOLDS[DistanceThreshold.MEDIUM]:
		return DistanceThreshold.MEDIUM
	elif distance <= DISTANCE_THRESHOLDS[DistanceThreshold.FAR]:
		return DistanceThreshold.FAR
	elif distance <= DISTANCE_THRESHOLDS[DistanceThreshold.VERY_FAR]:
		return DistanceThreshold.VERY_FAR
	else:
		return DistanceThreshold.EXTREME

static func should_update_system(category: SystemCategory, distance: float, frequency: Frequency) -> bool:
	"""Determine if a system category should update at the given distance and frequency.
	
	Args:
		category: System category to check
		distance: Distance from player
		frequency: Current update frequency
	
	Returns:
		true if the system should update
	"""
	var config: Dictionary = SYSTEM_LOD_CONFIG.get(category, {})
	
	# Always update if configured to do so
	if config.get("always_update", false):
		return true
	
	# Check minimum frequency requirement
	var min_frequency: Frequency = config.get("min_frequency", Frequency.MINIMAL)
	if frequency > min_frequency:
		return false
	
	# Check distance-based rules
	var distance_multiplier: float = config.get("distance_multiplier", 1.0)
	var effective_distance: float = distance * distance_multiplier
	
	# Special handling for different categories
	match category:
		SystemCategory.AUDIO:
			var max_audio_distance: float = config.get("max_audio_distance", 2000.0)
			return effective_distance <= max_audio_distance
		
		SystemCategory.PARTICLE:
			var max_particle_distance: float = config.get("max_particles_distance", 1500.0)
			return effective_distance <= max_particle_distance
		
		SystemCategory.UI:
			# UI follows player more closely
			return effective_distance <= DISTANCE_THRESHOLDS[DistanceThreshold.MEDIUM]
		
		_:
			# Default distance-based logic
			return effective_distance <= DISTANCE_THRESHOLDS[DistanceThreshold.VERY_FAR]

static func adjust_frequency_for_performance(base_frequency: Frequency, performance_factor: float) -> Frequency:
	"""Adjust update frequency based on current performance.
	
	Args:
		base_frequency: Base frequency level
		performance_factor: Performance factor (1.0 = normal, >1.0 = poor performance)
	
	Returns:
		Adjusted frequency level
	"""
	if performance_factor <= 1.0:
		return base_frequency
	
	# Reduce frequency when performance is poor
	var adjusted_level: int = int(base_frequency) + int(performance_factor)
	return min(adjusted_level, Frequency.SUSPENDED) as Frequency

static func get_object_type_frequency(object_type: int, is_active: bool = true) -> Frequency:
	"""Get recommended update frequency for a specific object type.
	
	Args:
		object_type: Object type from ObjectTypes.Type
		is_active: Whether the object is currently active
	
	Returns:
		Recommended update frequency
	"""
	const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
	
	if not is_active:
		return Frequency.MINIMAL
	
	match object_type:
		ObjectTypes.Type.SHIP, ObjectTypes.Type.FIGHTER, ObjectTypes.Type.BOMBER:
			return OBJECT_TYPE_LOD_OVERRIDES.get("ship_base_frequency", Frequency.HIGH)
		
		ObjectTypes.Type.CAPITAL:
			return OBJECT_TYPE_LOD_OVERRIDES.get("capital_ship_frequency", Frequency.MEDIUM)
		
		ObjectTypes.Type.WEAPON:
			return OBJECT_TYPE_LOD_OVERRIDES.get("weapon_active_frequency", Frequency.CRITICAL)
		
		ObjectTypes.Type.BEAM:
			return OBJECT_TYPE_LOD_OVERRIDES.get("beam_weapon_frequency", Frequency.CRITICAL)
		
		ObjectTypes.Type.FIREBALL, ObjectTypes.Type.SHOCKWAVE:
			return OBJECT_TYPE_LOD_OVERRIDES.get("explosion_frequency", Frequency.HIGH)
		
		ObjectTypes.Type.EFFECT:
			return OBJECT_TYPE_LOD_OVERRIDES.get("effect_frequency", Frequency.MEDIUM)
		
		ObjectTypes.Type.DEBRIS:
			return OBJECT_TYPE_LOD_OVERRIDES.get("debris_frequency", Frequency.LOW)
		
		ObjectTypes.Type.ASTEROID:
			return OBJECT_TYPE_LOD_OVERRIDES.get("asteroid_frequency", Frequency.MINIMAL)
		
		ObjectTypes.Type.WAYPOINT:
			return OBJECT_TYPE_LOD_OVERRIDES.get("waypoint_frequency", Frequency.MINIMAL)
		
		_:
			return Frequency.MEDIUM

static func is_frequency_valid(frequency: Frequency) -> bool:
	"""Validate that an update frequency is within valid range.
	
	Args:
		frequency: Update frequency enum value
	
	Returns:
		true if frequency is valid
	"""
	return frequency >= Frequency.CRITICAL and frequency <= Frequency.SUSPENDED

static func is_lod_level_valid(lod_level: LODLevel) -> bool:
	"""Validate that a LOD level is within valid range.
	
	Args:
		lod_level: LOD level enum value
	
	Returns:
		true if LOD level is valid
	"""
	return lod_level >= LODLevel.MAXIMUM and lod_level <= LODLevel.CULLED

static func calculate_performance_factor(frame_time_ms: float) -> float:
	"""Calculate performance factor based on current frame time.
	
	Args:
		frame_time_ms: Current frame time in milliseconds
	
	Returns:
		Performance factor (1.0 = normal, >1.0 = poor performance)
	"""
	var target_frame_time: float = LOD_CONFIG["frame_time_target_ms"]
	return max(1.0, frame_time_ms / target_frame_time)

static func get_all_frequencies() -> Array[Frequency]:
	"""Get all available update frequencies.
	
	Returns:
		Array of all update frequency enum values
	"""
	var frequencies: Array[Frequency] = []
	for frequency_value in FREQUENCY_NAMES.keys():
		frequencies.append(frequency_value)
	
	return frequencies

static func get_all_lod_levels() -> Array[LODLevel]:
	"""Get all available LOD levels.
	
	Returns:
		Array of all LOD level enum values
	"""
	var lod_levels: Array[LODLevel] = []
	for lod_value in LOD_LEVEL_NAMES.keys():
		lod_levels.append(lod_value)
	
	return lod_levels