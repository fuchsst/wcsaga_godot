class_name TargetDataProcessor
extends RefCounted

## EPIC-012 HUD-005: Target Data Processor
## Processes and validates target data from various sources for the targeting system

signal data_processed(target_id: String, data: Dictionary)
signal data_validation_failed(target_id: String, errors: Array)
signal cache_updated(cache_size: int)

# Data processing configuration
@export var enable_data_validation: bool = true
@export var cache_max_size: int = 50
@export var cache_expiry_time: float = 10.0
@export var data_freshness_threshold: float = 2.0

# Data cache
var target_data_cache: Dictionary = {}
var cache_timestamps: Dictionary = {}
var data_sources: Array[String] = ["ship_status", "targeting_data", "sensor_data", "tactical_data"]

# Validation rules
var validation_rules: Dictionary = {
	"required_fields": ["name", "position", "class"],
	"numeric_fields": ["hull_percentage", "shield_percentage", "distance"],
	"vector_fields": ["position", "velocity"],
	"range_limits": {
		"hull_percentage": {"min": 0.0, "max": 100.0},
		"shield_percentage": {"min": 0.0, "max": 100.0},
		"distance": {"min": 0.0, "max": 100000.0}
	}
}

func _init() -> void:
	print("TargetDataProcessor: Initialized")

## Process target data from various sources
func process_target_data(target: Node) -> Dictionary:
	if not target:
		return {}
	
	var target_id = _get_target_id(target)
	var current_time = Time.get_time_dict_from_system()["unix"]
	
	# Check cache first
	if _is_cache_valid(target_id, current_time):
		return target_data_cache[target_id].duplicate()
	
	# Collect data from all sources
	var raw_data = _collect_raw_data(target)
	
	# Process and merge data
	var processed_data = _merge_data_sources(raw_data)
	
	# Validate processed data
	if enable_data_validation:
		var validation_result = _validate_target_data(processed_data)
		if not validation_result.is_valid:
			data_validation_failed.emit(target_id, validation_result.errors)
			print("TargetDataProcessor: Validation failed for target %s: %s" % [target_id, validation_result.errors])
			return {}
	
	# Enhance data with calculated fields
	processed_data = _enhance_data(processed_data, target)
	
	# Cache the processed data
	_cache_data(target_id, processed_data, current_time)
	
	data_processed.emit(target_id, processed_data)
	print("TargetDataProcessor: Processed data for target %s" % target_id)
	
	return processed_data

## Collect raw data from all available sources
func _collect_raw_data(target: Node) -> Dictionary:
	var raw_data = {}
	
	# Ship status data
	raw_data["ship_status"] = _collect_ship_status_data(target)
	
	# Targeting data
	raw_data["targeting_data"] = _collect_targeting_data(target)
	
	# Sensor data
	raw_data["sensor_data"] = _collect_sensor_data(target)
	
	# Tactical data
	raw_data["tactical_data"] = _collect_tactical_data(target)
	
	return raw_data

## Collect ship status data
func _collect_ship_status_data(target: Node) -> Dictionary:
	var data = {}
	
	# Basic identification
	data["name"] = _safe_call(target, "get_ship_name", target.name)
	data["class"] = _safe_call(target, "get_ship_class", "Unknown")
	data["type"] = _safe_call(target, "get_ship_type", "Unknown")
	
	# Position and movement
	data["position"] = _safe_call(target, "get_global_position", Vector3.ZERO)
	data["velocity"] = _safe_call(target, "get_velocity", Vector3.ZERO)
	data["rotation"] = _safe_call(target, "get_global_rotation", Vector3.ZERO)
	
	# Health status
	data["hull_percentage"] = _safe_call(target, "get_hull_percentage", 100.0)
	data["shield_percentage"] = _safe_call(target, "get_shield_percentage", 0.0)
	data["hull_points"] = _safe_call(target, "get_hull_points", 100.0)
	data["shield_points"] = _safe_call(target, "get_shield_points", 0.0)
	
	# Shield quadrants
	if target.has_method("get_shield_quadrants"):
		data["shield_quadrants"] = target.get_shield_quadrants()
	else:
		var base_shield = data["shield_percentage"]
		data["shield_quadrants"] = [base_shield/4, base_shield/4, base_shield/4, base_shield/4]
	
	# Subsystem status
	data["subsystems"] = _safe_call(target, "get_subsystem_status", {})
	
	return data

## Collect targeting data
func _collect_targeting_data(target: Node) -> Dictionary:
	var data = {}
	
	# Team/hostility information
	data["team"] = _safe_call(target, "get_team", 0)
	data["hostility"] = _safe_call(target, "get_hostility_status", "unknown")
	data["is_targetable"] = _safe_call(target, "is_targetable", true)
	data["is_friendly"] = _safe_call(target, "is_friendly", false)
	
	# Weapon information
	data["weapons"] = _safe_call(target, "get_weapon_loadout", [])
	data["weapon_status"] = _safe_call(target, "get_weapon_status", {})
	
	# Mission data
	data["mission_priority"] = _safe_call(target, "get_mission_priority", 5)
	data["objective_type"] = _safe_call(target, "get_objective_type", "none")
	
	return data

## Collect sensor data
func _collect_sensor_data(target: Node) -> Dictionary:
	var data = {}
	
	# Calculate distance from player (would use actual player reference in real implementation)
	data["distance"] = 1000.0  # Default distance
	data["relative_velocity"] = Vector3.ZERO
	
	# Sensor detection data
	data["sensor_signature"] = _safe_call(target, "get_sensor_signature", 1.0)
	data["stealth_level"] = _safe_call(target, "get_stealth_level", 0.0)
	data["jamming_level"] = _safe_call(target, "get_jamming_level", 0.0)
	
	# Cargo and equipment (if scannable)
	if target.has_method("is_cargo_scannable") and target.is_cargo_scannable():
		data["cargo"] = _safe_call(target, "get_cargo_info", {})
	else:
		data["cargo"] = {}
	
	return data

## Collect tactical data
func _collect_tactical_data(target: Node) -> Dictionary:
	var data = {}
	
	# Movement characteristics
	data["max_speed"] = _safe_call(target, "get_max_speed", 100.0)
	data["acceleration"] = _safe_call(target, "get_max_acceleration", 50.0)
	data["turn_rate"] = _safe_call(target, "get_turn_rate", 1.0)
	
	# Combat characteristics
	data["armor_class"] = _safe_call(target, "get_armor_class", "light")
	data["shield_recharge_rate"] = _safe_call(target, "get_shield_recharge_rate", 5.0)
	data["engine_efficiency"] = _safe_call(target, "get_engine_efficiency", 1.0)
	
	# AI behavior data
	data["ai_behavior"] = _safe_call(target, "get_ai_behavior", "standard")
	data["aggression_level"] = _safe_call(target, "get_aggression_level", 0.5)
	data["evasion_skill"] = _safe_call(target, "get_evasion_skill", 0.5)
	
	return data

## Merge data from different sources
func _merge_data_sources(raw_data: Dictionary) -> Dictionary:
	var merged_data = {}
	
	# Merge all data sources with priority (later sources override earlier ones)
	var source_priority = ["ship_status", "sensor_data", "targeting_data", "tactical_data"]
	
	for source in source_priority:
		if raw_data.has(source):
			var source_data = raw_data[source]
			for key in source_data:
				merged_data[key] = source_data[key]
	
	# Add metadata
	merged_data["data_timestamp"] = Time.get_time_dict_from_system()["unix"]
	merged_data["data_sources"] = raw_data.keys()
	merged_data["processing_version"] = "1.0.0"
	
	return merged_data

## Enhance data with calculated fields
func _enhance_data(data: Dictionary, target: Node) -> Dictionary:
	var enhanced_data = data.duplicate()
	
	# Calculate derived values
	enhanced_data["speed"] = enhanced_data.get("velocity", Vector3.ZERO).length()
	enhanced_data["range_category"] = _categorize_range(enhanced_data.get("distance", 0.0))
	enhanced_data["threat_category"] = _categorize_threat(enhanced_data)
	enhanced_data["engagement_difficulty"] = _calculate_engagement_difficulty(enhanced_data)
	
	# Calculate shield total from quadrants
	if enhanced_data.has("shield_quadrants"):
		var quadrants = enhanced_data["shield_quadrants"]
		var total = 0.0
		for value in quadrants:
			total += value
		enhanced_data["shield_total"] = total
	
	# Calculate heading and bearing
	var velocity = enhanced_data.get("velocity", Vector3.ZERO)
	if velocity.length() > 0.1:
		enhanced_data["heading"] = atan2(velocity.z, velocity.x)
	else:
		enhanced_data["heading"] = 0.0
	
	# Calculate time-based predictions
	enhanced_data["predicted_position_1s"] = _predict_position(enhanced_data, 1.0)
	enhanced_data["predicted_position_3s"] = _predict_position(enhanced_data, 3.0)
	enhanced_data["predicted_position_5s"] = _predict_position(enhanced_data, 5.0)
	
	return enhanced_data

## Validate target data
func _validate_target_data(data: Dictionary) -> Dictionary:
	var result = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	# Check required fields
	for field in validation_rules["required_fields"]:
		if not data.has(field):
			result.errors.append("Missing required field: %s" % field)
			result.is_valid = false
	
	# Validate numeric fields
	for field in validation_rules["numeric_fields"]:
		if data.has(field):
			var value = data[field]
			if not (value is float or value is int):
				result.errors.append("Field %s is not numeric: %s" % [field, typeof(value)])
				result.is_valid = false
	
	# Validate vector fields
	for field in validation_rules["vector_fields"]:
		if data.has(field):
			var value = data[field]
			if not value is Vector3:
				result.errors.append("Field %s is not a Vector3: %s" % [field, typeof(value)])
				result.is_valid = false
	
	# Validate ranges
	for field in validation_rules["range_limits"]:
		if data.has(field):
			var value = data[field]
			var limits = validation_rules["range_limits"][field]
			if value < limits["min"] or value > limits["max"]:
				result.warnings.append("Field %s out of expected range: %s (expected %s-%s)" % [field, value, limits["min"], limits["max"]])
	
	# Validate data freshness
	if data.has("data_timestamp"):
		var current_time = Time.get_time_dict_from_system()["unix"]
		var data_age = current_time - data["data_timestamp"]
		if data_age > data_freshness_threshold:
			result.warnings.append("Data is stale: %s seconds old" % data_age)
	
	return result

## Cache management
func _cache_data(target_id: String, data: Dictionary, timestamp: float) -> void:
	# Check cache size limit
	if target_data_cache.size() >= cache_max_size:
		_cleanup_old_cache_entries()
	
	target_data_cache[target_id] = data.duplicate()
	cache_timestamps[target_id] = timestamp
	
	cache_updated.emit(target_data_cache.size())

func _is_cache_valid(target_id: String, current_time: float) -> bool:
	if not target_data_cache.has(target_id):
		return false
	
	if not cache_timestamps.has(target_id):
		return false
	
	var cache_age = current_time - cache_timestamps[target_id]
	return cache_age < cache_expiry_time

func _cleanup_old_cache_entries() -> void:
	var current_time = Time.get_time_dict_from_system()["unix"]
	var to_remove: Array[String] = []
	
	# Find expired entries
	for target_id in cache_timestamps:
		var cache_age = current_time - cache_timestamps[target_id]
		if cache_age > cache_expiry_time:
			to_remove.append(target_id)
	
	# Remove expired entries
	for target_id in to_remove:
		target_data_cache.erase(target_id)
		cache_timestamps.erase(target_id)
	
	# If still over limit, remove oldest entries
	if target_data_cache.size() >= cache_max_size:
		var sorted_by_age: Array = []
		for target_id in cache_timestamps:
			sorted_by_age.append({"id": target_id, "timestamp": cache_timestamps[target_id]})
		
		sorted_by_age.sort_custom(func(a, b): return a.timestamp < b.timestamp)
		
		var to_remove_count = target_data_cache.size() - cache_max_size + 5  # Remove extra to avoid frequent cleanup
		for i in range(min(to_remove_count, sorted_by_age.size())):
			var entry = sorted_by_age[i]
			target_data_cache.erase(entry.id)
			cache_timestamps.erase(entry.id)
	
	print("TargetDataProcessor: Cache cleanup complete - %d entries remaining" % target_data_cache.size())

## Utility functions
func _safe_call(target: Node, method_name: String, default_value) -> Variant:
	if target.has_method(method_name):
		return target.call(method_name)
	else:
		return default_value

func _get_target_id(target: Node) -> String:
	return str(target.get_instance_id())

func _categorize_range(distance: float) -> String:
	if distance < 500.0:
		return "close"
	elif distance < 2000.0:
		return "medium"
	elif distance < 5000.0:
		return "long"
	else:
		return "extreme"

func _categorize_threat(data: Dictionary) -> String:
	var hull = data.get("hull_percentage", 100.0)
	var weapons_count = data.get("weapons", []).size()
	var ship_class = data.get("class", "unknown").to_lower()
	
	if hull < 25.0:
		return "minimal"
	elif "capital" in ship_class or "dreadnought" in ship_class:
		return "extreme"
	elif "cruiser" in ship_class or weapons_count > 5:
		return "high"
	elif "fighter" in ship_class or weapons_count > 2:
		return "moderate"
	else:
		return "low"

func _calculate_engagement_difficulty(data: Dictionary) -> float:
	var difficulty = 0.5  # Base difficulty
	
	# Adjust for distance
	var distance = data.get("distance", 1000.0)
	if distance > 3000.0:
		difficulty += 0.2
	elif distance < 500.0:
		difficulty += 0.1
	
	# Adjust for speed
	var speed = data.get("speed", 0.0)
	if speed > 150.0:
		difficulty += 0.2
	
	# Adjust for shields
	var shields = data.get("shield_percentage", 0.0)
	if shields > 75.0:
		difficulty += 0.1
	
	return clampf(difficulty, 0.0, 1.0)

func _predict_position(data: Dictionary, time: float) -> Vector3:
	var position = data.get("position", Vector3.ZERO)
	var velocity = data.get("velocity", Vector3.ZERO)
	return position + velocity * time

## Public interface
func get_cached_data(target_id: String) -> Dictionary:
	return target_data_cache.get(target_id, {})

func clear_cache() -> void:
	target_data_cache.clear()
	cache_timestamps.clear()
	cache_updated.emit(0)
	print("TargetDataProcessor: Cache cleared")

func get_cache_statistics() -> Dictionary:
	var current_time = Time.get_time_dict_from_system()["unix"]
	var expired_count = 0
	
	for timestamp in cache_timestamps.values():
		if current_time - timestamp > cache_expiry_time:
			expired_count += 1
	
	return {
		"cache_size": target_data_cache.size(),
		"expired_entries": expired_count,
		"cache_hit_rate": 0.0,  # Would track in real implementation
		"average_data_age": _calculate_average_data_age(current_time)
	}

func _calculate_average_data_age(current_time: float) -> float:
	if cache_timestamps.is_empty():
		return 0.0
	
	var total_age = 0.0
	for timestamp in cache_timestamps.values():
		total_age += current_time - timestamp
	
	return total_age / cache_timestamps.size()
