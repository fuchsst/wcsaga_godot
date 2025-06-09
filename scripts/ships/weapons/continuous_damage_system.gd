class_name ContinuousDamageSystem
extends Node

## SHIP-013 AC2: Continuous Damage System
## Applies time-stamped damage every 170ms with collision tracking and friendly fire protection
## Manages continuous beam weapon damage delivery with WCS-authentic timing

# EPIC-002 Asset Core Integration
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const TeamTypes = preload("res://addons/wcs_asset_core/constants/team_types.gd")

# Signals
signal damage_applied(beam_id: String, target: Node, damage_amount: float)
signal damage_blocked(beam_id: String, target: Node, reason: String)
signal damage_interval_processed(beam_id: String, targets_hit: int)
signal friendly_fire_prevented(beam_id: String, target: Node)

# Damage timing configuration
var damage_interval: float = 0.17  # 170ms WCS standard
var damage_timing_tolerance: float = 0.01  # 10ms tolerance for timing accuracy

# Active beam tracking
var registered_beams: Dictionary = {}  # beam_id -> beam_damage_data
var beam_collision_history: Dictionary = {}  # beam_id -> Array[collision_data]
var damage_application_timers: Dictionary = {}  # beam_id -> next_damage_time

# Collision tracking for damage prevention
var collision_timestamps: Dictionary = {}  # "beam_id:target_id" -> last_damage_time
var collision_damage_totals: Dictionary = {}  # "beam_id:target_id" -> total_damage

# Friendly fire management
var friendly_fire_enabled: bool = false
var team_damage_matrix: Dictionary = {}

# Performance tracking
var damage_performance_stats: Dictionary = {
	"total_damage_applications": 0,
	"blocked_damage_attempts": 0,
	"friendly_fire_blocks": 0,
	"collision_duplicates_prevented": 0,
	"active_beam_count": 0
}

# Configuration
@export var enable_damage_debugging: bool = false
@export var enable_collision_tracking: bool = true
@export var enable_friendly_fire_protection: bool = true
@export var max_collision_history_per_beam: int = 100
@export var collision_cleanup_interval: float = 10.0

# System references
var beam_weapon_system: BeamWeaponSystem = null
var damage_manager: Node = null  # Reference to ship damage manager if available

# Update timer
var cleanup_timer: float = 0.0

func _ready() -> void:
	_setup_continuous_damage_system()
	_initialize_team_damage_matrix()

## Initialize continuous damage system
func initialize_damage_system(interval: float = 0.17) -> void:
	damage_interval = interval
	
	if enable_damage_debugging:
		print("ContinuousDamageSystem: Initialized with %.3fs damage interval" % damage_interval)

## Register beam weapon for continuous damage
func register_beam_weapon(beam_id: String, beam_data: Dictionary) -> void:
	var damage_data = _create_beam_damage_data(beam_id, beam_data)
	registered_beams[beam_id] = damage_data
	
	# Initialize damage timer
	var current_time = Time.get_ticks_msec() / 1000.0
	damage_application_timers[beam_id] = current_time + damage_interval
	
	# Initialize collision tracking
	beam_collision_history[beam_id] = []
	
	damage_performance_stats["active_beam_count"] = registered_beams.size()
	
	if enable_damage_debugging:
		print("ContinuousDamageSystem: Registered beam %s for continuous damage" % beam_id)

## Unregister beam weapon
func unregister_beam_weapon(beam_id: String) -> void:
	if registered_beams.has(beam_id):
		registered_beams.erase(beam_id)
		damage_application_timers.erase(beam_id)
		
		# Clean up collision history
		beam_collision_history.erase(beam_id)
		_cleanup_collision_timestamps(beam_id)
		
		damage_performance_stats["active_beam_count"] = registered_beams.size()
		
		if enable_damage_debugging:
			print("ContinuousDamageSystem: Unregistered beam %s" % beam_id)

## Process beam collision for damage application
func process_beam_collision(beam_id: String, collision_data: Dictionary) -> bool:
	if not registered_beams.has(beam_id):
		return false
	
	var beam_damage_data = registered_beams[beam_id]
	var target = collision_data.get("target", null)
	var collision_point = collision_data.get("collision_point", Vector3.ZERO)
	var collision_normal = collision_data.get("collision_normal", Vector3.UP)
	
	if not target or not is_instance_valid(target):
		return false
	
	# Check if it's time to apply damage
	var current_time = Time.get_ticks_msec() / 1000.0
	var next_damage_time = damage_application_timers.get(beam_id, 0.0)
	
	if current_time < next_damage_time:
		# Not yet time for damage application
		return false
	
	# Check for duplicate collision prevention
	if enable_collision_tracking and _is_duplicate_collision(beam_id, target, current_time):
		damage_performance_stats["collision_duplicates_prevented"] += 1
		return false
	
	# Check friendly fire protection
	if enable_friendly_fire_protection and _is_friendly_fire(beam_damage_data, target):
		friendly_fire_prevented.emit(beam_id, target)
		damage_performance_stats["friendly_fire_blocks"] += 1
		return false
	
	# Apply damage
	var damage_amount = beam_damage_data.get("damage_per_interval", 25.0)
	var damage_applied = _apply_beam_damage(beam_id, target, damage_amount, collision_point, collision_normal)
	
	if damage_applied:
		# Update damage timing
		damage_application_timers[beam_id] = current_time + damage_interval
		
		# Track collision for duplicate prevention
		if enable_collision_tracking:
			_track_collision(beam_id, target, current_time, damage_amount)
		
		# Add to collision history
		_add_collision_to_history(beam_id, collision_data)
		
		damage_performance_stats["total_damage_applications"] += 1
		damage_applied.emit(beam_id, target, damage_amount)
		
		if enable_damage_debugging:
			print("ContinuousDamageSystem: Applied %.1f damage from beam %s to %s" % [
				damage_amount, beam_id, target.name if target.has_method("get", "name") else "target"
			])
		
		return true
	else:
		damage_performance_stats["blocked_damage_attempts"] += 1
		damage_blocked.emit(beam_id, target, "damage_application_failed")
		return false

## Get beam damage statistics
func get_beam_damage_statistics(beam_id: String) -> Dictionary:
	if not registered_beams.has(beam_id):
		return {}
	
	var beam_data = registered_beams[beam_id]
	var collision_history = beam_collision_history.get(beam_id, [])
	
	return {
		"beam_id": beam_id,
		"total_collisions": collision_history.size(),
		"damage_per_interval": beam_data.get("damage_per_interval", 0.0),
		"total_damage_dealt": beam_data.get("total_damage_dealt", 0.0),
		"targets_hit": beam_data.get("targets_hit", []).size(),
		"next_damage_time": damage_application_timers.get(beam_id, 0.0),
		"time_until_next_damage": max(0.0, damage_application_timers.get(beam_id, 0.0) - (Time.get_ticks_msec() / 1000.0))
	}

## Get system performance statistics
func get_damage_performance_statistics() -> Dictionary:
	return damage_performance_stats.duplicate()

## Setup continuous damage system
func _setup_continuous_damage_system() -> void:
	registered_beams.clear()
	beam_collision_history.clear()
	damage_application_timers.clear()
	collision_timestamps.clear()
	collision_damage_totals.clear()
	
	cleanup_timer = 0.0
	
	# Reset performance stats
	damage_performance_stats = {
		"total_damage_applications": 0,
		"blocked_damage_attempts": 0,
		"friendly_fire_blocks": 0,
		"collision_duplicates_prevented": 0,
		"active_beam_count": 0
	}

## Initialize team damage matrix
func _initialize_team_damage_matrix() -> void:
	# Define which teams can damage which teams
	team_damage_matrix = {
		TeamTypes.Type.FRIENDLY: {
			TeamTypes.Type.FRIENDLY: false,  # No friendly fire
			TeamTypes.Type.HOSTILE: true,    # Can damage hostiles
			TeamTypes.Type.NEUTRAL: false,   # Cannot damage neutrals
			TeamTypes.Type.UNKNOWN: true     # Can damage unknowns
		},
		TeamTypes.Type.HOSTILE: {
			TeamTypes.Type.FRIENDLY: true,   # Can damage friendlies
			TeamTypes.Type.HOSTILE: false,   # No friendly fire among hostiles
			TeamTypes.Type.NEUTRAL: false,   # Cannot damage neutrals
			TeamTypes.Type.UNKNOWN: true     # Can damage unknowns
		},
		TeamTypes.Type.NEUTRAL: {
			TeamTypes.Type.FRIENDLY: false,  # Cannot damage anyone
			TeamTypes.Type.HOSTILE: false,
			TeamTypes.Type.NEUTRAL: false,
			TeamTypes.Type.UNKNOWN: false
		},
		TeamTypes.Type.UNKNOWN: {
			TeamTypes.Type.FRIENDLY: true,   # Can damage all
			TeamTypes.Type.HOSTILE: true,
			TeamTypes.Type.NEUTRAL: true,
			TeamTypes.Type.UNKNOWN: true
		}
	}

## Create beam damage data structure
func _create_beam_damage_data(beam_id: String, beam_data: Dictionary) -> Dictionary:
	var config = beam_data.get("config", {})
	
	return {
		"beam_id": beam_id,
		"beam_type": beam_data.get("beam_type", 0),
		"damage_per_interval": config.get("damage_per_interval", 25.0),
		"damage_type": DamageTypes.Type.ENERGY,  # Beams are energy damage
		"firing_ship": beam_data.get("firing_ship", null),
		"team": _get_ship_team(beam_data.get("firing_ship", null)),
		"penetration_count": 0,
		"total_damage_dealt": 0.0,
		"targets_hit": [],
		"last_damage_time": 0.0,
		"creation_time": Time.get_ticks_msec() / 1000.0
	}

## Check if collision is duplicate within damage interval
func _is_duplicate_collision(beam_id: String, target: Node, current_time: float) -> bool:
	var target_id = _get_target_id(target)
	var collision_key = "%s:%s" % [beam_id, target_id]
	
	if collision_timestamps.has(collision_key):
		var last_damage_time = collision_timestamps[collision_key]
		var time_since_last_damage = current_time - last_damage_time
		
		# If less than damage interval has passed, it's a duplicate
		return time_since_last_damage < (damage_interval - damage_timing_tolerance)
	
	return false

## Check if damage would be friendly fire
func _is_friendly_fire(beam_damage_data: Dictionary, target: Node) -> bool:
	if not friendly_fire_enabled:
		return false
	
	var firing_team = beam_damage_data.get("team", TeamTypes.Type.UNKNOWN)
	var target_team = _get_ship_team(target)
	
	# Check team damage matrix
	if team_damage_matrix.has(firing_team) and team_damage_matrix[firing_team].has(target_team):
		return not team_damage_matrix[firing_team][target_team]
	
	# Default: no friendly fire (conservative approach)
	return firing_team == target_team

## Apply beam damage to target
func _apply_beam_damage(beam_id: String, target: Node, damage_amount: float, collision_point: Vector3, collision_normal: Vector3) -> bool:
	var beam_data = registered_beams[beam_id]
	
	# Check if target can receive damage
	if not target.has_method("apply_damage") and not target.has_method("apply_hull_damage"):
		return false
	
	# Create damage data
	var damage_data = {
		"damage_amount": damage_amount,
		"damage_type": DamageTypes.Type.ENERGY,
		"source": beam_data.get("firing_ship", null),
		"collision_point": collision_point,
		"collision_normal": collision_normal,
		"beam_id": beam_id,
		"is_beam_damage": true,
		"damage_time": Time.get_ticks_msec() / 1000.0
	}
	
	# Apply damage using available method
	var damage_applied = false
	if target.has_method("apply_damage"):
		damage_applied = target.apply_damage(damage_data)
	elif target.has_method("apply_hull_damage"):
		damage_applied = target.apply_hull_damage(damage_amount)
	
	# Update beam damage statistics
	if damage_applied:
		beam_data["total_damage_dealt"] += damage_amount
		beam_data["last_damage_time"] = damage_data["damage_time"]
		
		# Track unique targets
		if target not in beam_data["targets_hit"]:
			beam_data["targets_hit"].append(target)
	
	return damage_applied

## Track collision for duplicate prevention
func _track_collision(beam_id: String, target: Node, current_time: float, damage_amount: float) -> void:
	var target_id = _get_target_id(target)
	var collision_key = "%s:%s" % [beam_id, target_id]
	
	collision_timestamps[collision_key] = current_time
	
	# Track total damage to this target
	if not collision_damage_totals.has(collision_key):
		collision_damage_totals[collision_key] = 0.0
	collision_damage_totals[collision_key] += damage_amount

## Add collision to beam history
func _add_collision_to_history(beam_id: String, collision_data: Dictionary) -> void:
	if not beam_collision_history.has(beam_id):
		beam_collision_history[beam_id] = []
	
	var history = beam_collision_history[beam_id]
	var collision_entry = {
		"target": collision_data.get("target", null),
		"collision_point": collision_data.get("collision_point", Vector3.ZERO),
		"collision_time": Time.get_ticks_msec() / 1000.0,
		"damage_applied": true
	}
	
	history.append(collision_entry)
	
	# Limit history size
	if history.size() > max_collision_history_per_beam:
		history.remove_at(0)

## Get target identifier
func _get_target_id(target: Node) -> String:
	if target.has_method("get_instance_id"):
		return str(target.get_instance_id())
	elif target.has_method("get"):
		return target.name
	else:
		return str(target.get_instance_id())

## Get ship team
func _get_ship_team(ship: Node) -> int:
	if not ship or not is_instance_valid(ship):
		return TeamTypes.Type.UNKNOWN
	
	if ship.has_method("get_team"):
		return ship.get_team()
	elif ship.has_property("team"):
		return ship.team
	elif ship.has_property("ship_team"):
		return ship.ship_team
	
	return TeamTypes.Type.UNKNOWN

## Clean up collision timestamps for beam
func _cleanup_collision_timestamps(beam_id: String) -> void:
	var keys_to_remove: Array[String] = []
	
	for key in collision_timestamps.keys():
		if key.begins_with(beam_id + ":"):
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		collision_timestamps.erase(key)
		collision_damage_totals.erase(key)

## Clean up old collision data
func _cleanup_old_collision_data() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var cleanup_threshold = current_time - (damage_interval * 10)  # Keep 10 intervals of history
	
	var keys_to_remove: Array[String] = []
	
	for key in collision_timestamps.keys():
		if collision_timestamps[key] < cleanup_threshold:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		collision_timestamps.erase(key)
		collision_damage_totals.erase(key)

## Process interval damage for all active beams
func _process_interval_damage() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	for beam_id in registered_beams.keys():
		var next_damage_time = damage_application_timers.get(beam_id, 0.0)
		
		# Check if it's time for this beam's next damage interval
		if current_time >= next_damage_time:
			var targets_hit = _process_beam_interval_damage(beam_id, current_time)
			damage_interval_processed.emit(beam_id, targets_hit)

## Process damage interval for specific beam
func _process_beam_interval_damage(beam_id: String, current_time: float) -> int:
	# This would be called when beam collision detection finds targets
	# The actual collision detection is handled by BeamCollisionDetector
	# This method updates the next damage time
	
	damage_application_timers[beam_id] = current_time + damage_interval
	
	# Return number of targets that would be hit (actual collision detection happens elsewhere)
	var collision_history = beam_collision_history.get(beam_id, [])
	var recent_collisions = 0
	
	for collision in collision_history:
		var collision_time = collision.get("collision_time", 0.0)
		if current_time - collision_time < damage_interval:
			recent_collisions += 1
	
	return recent_collisions

## Set friendly fire mode
func set_friendly_fire_enabled(enabled: bool) -> void:
	friendly_fire_enabled = enabled
	
	if enable_damage_debugging:
		print("ContinuousDamageSystem: Friendly fire %s" % ("enabled" if enabled else "disabled"))

## Get collision history for beam
func get_beam_collision_history(beam_id: String) -> Array:
	return beam_collision_history.get(beam_id, []).duplicate()

## Process frame updates
func _process(delta: float) -> void:
	cleanup_timer += delta
	
	# Process interval damage
	_process_interval_damage()
	
	# Periodic cleanup
	if cleanup_timer >= collision_cleanup_interval:
		cleanup_timer = 0.0
		_cleanup_old_collision_data()