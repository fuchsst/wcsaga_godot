@tool
class_name MissionValidationController
extends Node

# Use existing EPIC-002 mission structures
# MissionData, MissionValidationResult, and related classes are from wcs_asset_core addon

## Unified real-time validation controller for GFRED2 mission editor
## Integrates EPIC-001 ValidationResult, EPIC-002 asset validation, EPIC-004 SEXP validation
## Provides comprehensive mission validation with dependency tracking and visual feedback

signal validation_started()
signal validation_progress(percentage: float, current_check: String)
signal validation_completed(result: MissionValidationDetailedResult)
signal dependency_analysis_completed(dependencies: Array[DependencyInfo])
signal asset_dependency_error(asset_path: String, error_message: String)
signal sexp_validation_error(expression: String, error_message: String)

## Validation configuration
@export var enable_real_time_validation: bool = true
@export var validation_delay_ms: int = 500  # Delay before re-validation
@export var max_validation_time_ms: int = 100  # Performance requirement
@export var enable_dependency_tracking: bool = true
@export var enable_visual_indicators: bool = true

## Core system references - direct integration with foundation systems
var asset_validator: Node  # WCSAssetValidator autoload
var sexp_validator: Node  # SexpValidator from EPIC-004 (when available)

## Validation state management
var mission_data: MissionData  # From wcs_asset_core addon
var validation_timer: Timer
var last_validation_time: int = 0
var current_validation_result: MissionValidationDetailedResult
var dependency_graph: DependencyGraph

## Performance tracking
var validation_cache: Dictionary = {}  # Cache validation results for 5 seconds
var cache_timeout_ms: int = 5000

## Dependency tracking
class DependencyInfo:
	extends RefCounted
	
	var object_id: String
	var dependency_type: String  # "asset", "sexp_reference", "object_reference"
	var dependency_path: String
	var is_valid: bool = true
	var error_message: String = ""
	var dependent_objects: Array[String] = []  # Objects that depend on this
	
	func _init(id: String, type: String, path: String) -> void:
		object_id = id
		dependency_type = type
		dependency_path = path

class DependencyGraph:
	extends RefCounted
	
	var nodes: Dictionary = {}  # String -> DependencyInfo
	var edges: Dictionary = {}  # String -> Array[String] (dependencies)
	
	func add_dependency(from_id: String, to_info: DependencyInfo) -> void:
		nodes[to_info.dependency_path] = to_info
		if not edges.has(from_id):
			edges[from_id] = []
		if not edges[from_id].has(to_info.dependency_path):
			edges[from_id].append(to_info.dependency_path)
	
	func get_dependencies(object_id: String) -> Array[DependencyInfo]:
		var deps: Array[DependencyInfo] = []
		var dep_paths: Array[String] = edges.get(object_id, [])
		for path in dep_paths:
			if nodes.has(path):
				deps.append(nodes[path])
		return deps
	
	func get_dependents(dependency_path: String) -> Array[String]:
		var dependents: Array[String] = []
		for object_id in edges.keys():
			var deps: Array[String] = edges[object_id]
			if deps.has(dependency_path):
				dependents.append(object_id)
		return dependents
	
	func clear() -> void:
		nodes.clear()
		edges.clear()

class MissionValidationDetailedResult:
	extends RefCounted
	
	var overall_result: MissionValidationResult  # Use EPIC-002 core validation
	var object_results: Dictionary = {}  # String -> ValidationResult
	var asset_results: Dictionary = {}   # String -> ValidationResult  
	var sexp_results: Dictionary = {}    # String -> ValidationResult
	var dependency_results: Array[DependencyInfo] = []
	var validation_time_ms: int = 0
	var statistics: Dictionary = {}
	
	func _init() -> void:
		overall_result = MissionValidationResult.new()
	
	func is_valid() -> bool:
		return overall_result.is_valid()
	
	func get_total_errors() -> int:
		var total: int = overall_result.get_error_count()
		for result in object_results.values():
			if result.has_method("get_error_count"):
				total += result.get_error_count()
		for result in asset_results.values():
			if result.has_method("get_error_count"):
				total += result.get_error_count()
		for result in sexp_results.values():
			if result.has_method("get_error_count"):
				total += result.get_error_count()
		return total
	
	func get_total_warnings() -> int:
		var total: int = overall_result.get_warning_count()
		for result in object_results.values():
			if result.has_method("get_warning_count"):
				total += result.get_warning_count()
		for result in asset_results.values():
			if result.has_method("get_warning_count"):
				total += result.get_warning_count()
		for result in sexp_results.values():
			if result.has_method("get_warning_count"):
				total += result.get_warning_count()
		return total

func _ready() -> void:
	name = "MissionValidationController"
	
	# Initialize validation timer for real-time validation
	validation_timer = Timer.new()
	validation_timer.wait_time = validation_delay_ms / 1000.0
	validation_timer.one_shot = true
	validation_timer.timeout.connect(_perform_validation)
	add_child(validation_timer)
	
	# Initialize dependency graph
	dependency_graph = DependencyGraph.new()
	
	# Connect to foundation systems
	_initialize_foundation_system_connections()

func _initialize_foundation_system_connections() -> void:
	"""Initialize connections to EPIC-001, EPIC-002, and EPIC-004 systems."""
	
	# Get WCSAssetValidator autoload from EPIC-002
	asset_validator = get_node("/root/WCSAssetValidator")
	if not asset_validator:
		push_warning("MissionValidationController: WCSAssetValidator autoload not found - asset validation disabled")
	
	# Connect to SEXP validator when EPIC-004 is available
	# TODO: Connect to SexpValidator when EPIC-004 is implemented
	# sexp_validator = get_node("/root/SexpValidator")

func set_mission_data(data: MissionData) -> void:
	"""Set mission data and trigger initial validation.
	Args:
		data: Mission data to validate"""
	
	mission_data = data
	
	if mission_data:
		# Connect to mission data changes for real-time validation
		if mission_data.has_signal("data_changed"):
			if not mission_data.data_changed.is_connected(_on_mission_data_changed):
				mission_data.data_changed.connect(_on_mission_data_changed)
		
		# Perform initial validation
		if enable_real_time_validation:
			_schedule_validation()

func _on_mission_data_changed(property: String, old_value: Variant, new_value: Variant) -> void:
	"""Handle mission data changes for real-time validation.
	Args:
		property: Property that changed
		old_value: Previous value
		new_value: New value"""
	
	if enable_real_time_validation:
		_schedule_validation()

func _schedule_validation() -> void:
	"""Schedule validation after delay to avoid excessive validation during rapid changes."""
	
	# Performance requirement: Don't validate more than once per validation_delay_ms
	var current_time: int = Time.get_ticks_msec()
	if current_time - last_validation_time < validation_delay_ms:
		validation_timer.start()
		return
	
	# If enough time has passed, validate immediately
	_perform_validation()

func _perform_validation() -> void:
	"""Perform comprehensive mission validation with performance monitoring."""
	
	if not mission_data:
		return
	
	var start_time: int = Time.get_ticks_msec()
	last_validation_time = start_time
	
	validation_started.emit()
	
	# Create validation result
	current_validation_result = MissionValidationDetailedResult.new()
	
	# Clear dependency graph for fresh analysis
	dependency_graph.clear()
	
	# Use the built-in validation from EPIC-002 MissionData
	var mission_result = mission_data.validate()
	if mission_result is MissionValidationResult:
		current_validation_result.overall_result.merge(mission_result)
	else:
		print("Warning: mission_data.validate() returned unexpected type: ", typeof(mission_result))
	
	# Validation phases with progress reporting
	var phases: Array[Dictionary] = [
		{"name": "Mission Ships", "func": _validate_mission_ships, "weight": 0.4},
		{"name": "Asset Dependencies", "func": _validate_asset_dependencies, "weight": 0.3},
		{"name": "SEXP Expressions", "func": _validate_sexp_expressions, "weight": 0.2},
		{"name": "Performance Analysis", "func": _validate_performance, "weight": 0.1}
	]
	
	var completed_weight: float = 0.0
	
	for phase in phases:
		validation_progress.emit(completed_weight * 100.0, phase.name)
		
		var phase_func: Callable = phase.func
		phase_func.call()
		
		completed_weight += phase.weight
		
		# Performance requirement: abort if taking too long
		var elapsed_time: int = Time.get_ticks_msec() - start_time
		if elapsed_time > max_validation_time_ms:
			current_validation_result.overall_result.add_warning("Validation timeout - some checks skipped")
			break
	
	# Finalize validation
	current_validation_result.validation_time_ms = Time.get_ticks_msec() - start_time
	_calculate_validation_statistics()
	
	validation_completed.emit(current_validation_result)
	dependency_analysis_completed.emit(dependency_graph.nodes.values())

func _validate_mission_ships() -> void:
	"""Validate all mission ships using EPIC-002 validation."""
	
	if not mission_data:
		return
	
	# Validate ships from EPIC-002 structure
	for i in range(mission_data.ships.size()):
		var ship = mission_data.ships[i]
		if not ship:
			continue
		
		var ship_name: String = "ship_%d" % i
		if ship.has("ship_name"):
			ship_name = ship.ship_name
		
		# Use built-in validation if available
		var result: MissionValidationResult
		if ship.has_method("validate"):
			result = ship.validate()
		else:
			result = MissionValidationResult.new()
			if ship.has("ship_name") and ship.ship_name.is_empty():
				result.add_error("Ship name cannot be empty")
		
		current_validation_result.object_results[ship_name] = result
		
		# Track object dependencies
		_track_object_dependencies(ship, ship_name)
		
		# Merge critical errors into overall result
		if not result.is_valid():
			for error in result.get_errors():
				current_validation_result.overall_result.add_error("Ship %s: %s" % [ship_name, error])

func _validate_asset_dependencies() -> void:
	"""Validate asset dependencies using EPIC-002 WCSAssetValidator."""
	
	if not asset_validator:
		current_validation_result.overall_result.add_warning("Asset validation unavailable - WCSAssetValidator not found")
		return
	
	var checked_assets: Dictionary = {}
	
	# Check asset references in ships
	for ship in mission_data.ships:
		if not ship:
			continue
		
		# Ship class asset validation
		if ship.has("ship_class_name") and not ship.ship_class_name.is_empty():
			_validate_asset_reference(ship.ship_class_name, "ship", checked_assets)
	
	# Store asset validation results
	for asset_path in checked_assets.keys():
		var result = checked_assets[asset_path]
		current_validation_result.asset_results[asset_path] = result

func _validate_asset_reference(asset_path: String, asset_type: String, checked_assets: Dictionary) -> void:
	"""Validate individual asset reference.
	Args:
		asset_path: Path to asset
		asset_type: Type of asset for error reporting
		checked_assets: Cache of already checked assets"""
	
	if checked_assets.has(asset_path):
		return
	
	# Use cached validation result if available
	var cache_key: String = "asset_" + asset_path
	var current_time: int = Time.get_ticks_msec()
	
	if validation_cache.has(cache_key):
		var cached_data: Dictionary = validation_cache[cache_key]
		if current_time - cached_data.timestamp < cache_timeout_ms:
			checked_assets[asset_path] = cached_data.result
			return
	
	# Validate asset using EPIC-002 system
	var result: ValidationResult = asset_validator.validate_by_path(asset_path)
	
	# Cache result
	validation_cache[cache_key] = {
		"result": result,
		"timestamp": current_time
	}
	
	checked_assets[asset_path] = result
	
	# Create dependency info
	var dep_info: DependencyInfo = DependencyInfo.new("mission", "asset", asset_path)
	dep_info.is_valid = result.is_valid()
	if not result.is_valid():
		var errors: Array[String] = result.get_errors()
		dep_info.error_message = errors[0] if not errors.is_empty() else "Unknown asset error"
		asset_dependency_error.emit(asset_path, dep_info.error_message)
	
	dependency_graph.add_dependency("mission", dep_info)

func _validate_sexp_expressions() -> void:
	"""Validate SEXP expressions using EPIC-004 system (when available)."""
	
	# TODO: Implement when EPIC-004 SEXP system is available
	# For now, basic string validation
	
	if not mission_data.events:
		return
	
	for i in range(mission_data.events.size()):
		var event = mission_data.events[i]
		if not event:
			continue
		
		var event_id: String = "event_%d" % i
		var result: MissionValidationResult = MissionValidationResult.new()
		
		# Use built-in validation if available
		if event.has_method("validate"):
			var event_result: MissionValidationResult = event.validate()
			result.merge(event_result)
		
		current_validation_result.sexp_results[event_id] = result

func _validate_performance() -> void:
	"""Validate mission performance characteristics."""
	
	# Ship count validation
	var ship_count: int = mission_data.ships.size() if mission_data.ships else 0
	if ship_count > 500:
		current_validation_result.overall_result.add_warning("Large mission with %d ships - may impact performance" % ship_count)
	elif ship_count > 1000:
		current_validation_result.overall_result.add_error("Extremely large mission with %d ships - will impact performance" % ship_count)
	
	# Event count validation
	var event_count: int = mission_data.events.size() if mission_data.events else 0
	if event_count > 100:
		current_validation_result.overall_result.add_warning("Many mission events (%d) - may impact performance" % event_count)

func _track_object_dependencies(obj, object_id: String) -> void:
	"""Track dependencies for a mission object.
	Args:
		obj: Mission object to analyze
		object_id: Unique identifier for the object"""
	
	# Ship class dependency
	var ship_class: String = ""
	if obj.has("ship_class_name"):
		ship_class = obj.ship_class_name
	elif obj.has("ship_class"):
		ship_class = obj.ship_class
	
	if not ship_class.is_empty():
		var dep_info: DependencyInfo = DependencyInfo.new(object_id, "asset", ship_class)
		dependency_graph.add_dependency(object_id, dep_info)

func _calculate_validation_statistics() -> void:
	"""Calculate validation statistics for reporting."""
	
	current_validation_result.statistics = {
		"total_ships": mission_data.ships.size() if mission_data.ships else 0,
		"total_wings": mission_data.wings.size() if mission_data.wings else 0,
		"total_events": mission_data.events.size() if mission_data.events else 0,
		"total_errors": current_validation_result.get_total_errors(),
		"total_warnings": current_validation_result.get_total_warnings(),
		"validation_time_ms": current_validation_result.validation_time_ms,
		"dependencies_tracked": dependency_graph.nodes.size(),
		"asset_references": current_validation_result.asset_results.size(),
		"sexp_expressions": current_validation_result.sexp_results.size()
	}

## Public API

func validate_mission() -> MissionValidationDetailedResult:
	"""Manually trigger mission validation.
	Returns:
		Complete validation result"""
	
	_perform_validation()
	return current_validation_result

func get_current_validation_result() -> MissionValidationDetailedResult:
	"""Get the most recent validation result.
	Returns:
		Current validation result or null if no validation performed"""
	
	return current_validation_result

func get_dependency_graph() -> DependencyGraph:
	"""Get the current dependency graph.
	Returns:
		Dependency graph with all tracked dependencies"""
	
	return dependency_graph

func get_object_dependencies(object_id: String) -> Array[DependencyInfo]:
	"""Get dependencies for a specific object.
	Args:
		object_id: Object to get dependencies for
	Returns:
		Array of dependency information"""
	
	return dependency_graph.get_dependencies(object_id)

func get_asset_dependents(asset_path: String) -> Array[String]:
	"""Get objects that depend on a specific asset.
	Args:
		asset_path: Asset to get dependents for
	Returns:
		Array of object IDs that depend on the asset"""
	
	return dependency_graph.get_dependents(asset_path)

func clear_validation_cache() -> void:
	"""Clear validation cache to force fresh validation."""
	
	validation_cache.clear()

func set_real_time_validation(enabled: bool) -> void:
	"""Enable or disable real-time validation.
	Args:
		enabled: Whether to enable real-time validation"""
	
	enable_real_time_validation = enabled
	
	if not enabled and validation_timer:
		validation_timer.stop()

## Statistics and reporting

func get_validation_statistics() -> Dictionary:
	"""Get validation performance statistics.
	Returns:
		Dictionary with validation statistics"""
	
	if current_validation_result:
		return current_validation_result.statistics.duplicate()
	else:
		return {}

func generate_validation_report() -> String:
	"""Generate human-readable validation report.
	Returns:
		Formatted validation report string"""
	
	if not current_validation_result:
		return "No validation performed yet"
	
	var report: String = "MISSION VALIDATION REPORT\n"
	report += "========================\n\n"
	
	var stats: Dictionary = current_validation_result.statistics
	report += "Summary:\n"
	report += "- Ships: %d\n" % stats.get("total_ships", 0)
	report += "- Wings: %d\n" % stats.get("total_wings", 0)
	report += "- Events: %d\n" % stats.get("total_events", 0)
	report += "- Errors: %d\n" % stats.get("total_errors", 0)
	report += "- Warnings: %d\n" % stats.get("total_warnings", 0)
	report += "- Validation Time: %dms\n" % stats.get("validation_time_ms", 0)
	report += "- Dependencies: %d\n\n" % stats.get("dependencies_tracked", 0)
	
	# Overall issues
	if not current_validation_result.overall_result.is_valid():
		report += "Mission Issues:\n"
		for error in current_validation_result.overall_result.get_errors():
			report += "  ERROR: %s\n" % error
		for warning in current_validation_result.overall_result.get_warnings():
			report += "  WARNING: %s\n" % warning
		report += "\n"
	
	# Ship issues
	var ship_issues: int = 0
	for ship_id in current_validation_result.object_results.keys():
		var result = current_validation_result.object_results[ship_id]
		if result.has_method("is_valid") and not result.is_valid():
			ship_issues += 1
	
	if ship_issues > 0:
		report += "Ship Issues (%d ships affected):\n" % ship_issues
		for ship_id in current_validation_result.object_results.keys():
			var result = current_validation_result.object_results[ship_id]
			if result.has_method("is_valid") and not result.is_valid():
				report += "  %s:\n" % ship_id
				if result.has_method("get_errors"):
					for error in result.get_errors():
						report += "    ERROR: %s\n" % error
		report += "\n"
	
	# Asset issues
	var asset_issues: int = 0
	for asset_path in current_validation_result.asset_results.keys():
		var result = current_validation_result.asset_results[asset_path]
		if result.has_method("is_valid") and not result.is_valid():
			asset_issues += 1
	
	if asset_issues > 0:
		report += "Asset Issues (%d assets affected):\n" % asset_issues
		for asset_path in current_validation_result.asset_results.keys():
			var result = current_validation_result.asset_results[asset_path]
			if result.has_method("is_valid") and not result.is_valid():
				report += "  %s:\n" % asset_path
				if result.has_method("get_errors"):
					for error in result.get_errors():
						report += "    ERROR: %s\n" % error
		report += "\n"
	
	if current_validation_result.is_valid():
		report += "Mission validation PASSED - no critical issues found.\n"
	else:
		report += "Mission validation FAILED - critical issues must be resolved.\n"
	
	return report