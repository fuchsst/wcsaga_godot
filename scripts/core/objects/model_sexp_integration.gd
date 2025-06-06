class_name ModelSexpIntegration
extends Node

## SEXP system integration for dynamic model changes in BaseSpaceObject
## Integrates with EPIC-004 SEXP system for mission scripting capabilities
## Provides functions like change-ship-model, set-subsystem-damage, etc. (AC8)

# EPIC-002 Asset Core Integration
const ModelMetadata = preload("res://addons/wcs_asset_core/resources/object/model_metadata.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

# SEXP Integration Signals (AC8)
signal sexp_model_changed(space_object: BaseSpaceObject, old_model: String, new_model: String)
signal sexp_subsystem_modified(space_object: BaseSpaceObject, subsystem_name: String, operation: String)
signal sexp_operation_completed(operation_name: String, success: bool, details: Dictionary)
signal sexp_operation_failed(operation_name: String, error_message: String)

# SEXP function registry for model operations
var _sexp_functions: Dictionary = {}

# Integration components
var model_integration_system: ModelIntegrationSystem = null
var subsystem_integration: ModelSubsystemIntegration = null

# EPIC-004 SEXP system reference
var sexp_manager: Node = null

func _ready() -> void:
	name = "ModelSexpIntegration"
	_initialize_sexp_integration()
	_register_sexp_functions()

## Initialize EPIC-004 SEXP system integration
func _initialize_sexp_integration() -> void:
	# Wait for SEXP addon to be available
	call_deferred("_connect_sexp_system")

func _connect_sexp_system() -> void:
	# Connect to EPIC-004 SEXP system when available
	sexp_manager = get_node_or_null("/root/SexpManager")
	if not sexp_manager:
		# Try addon path
		var sexp_addon: Node = get_node_or_null("/root/SexpSystem")
		if sexp_addon:
			sexp_manager = sexp_addon
	
	if sexp_manager:
		print("ModelSexpIntegration: Connected to EPIC-004 SEXP system")
		_register_with_sexp_manager()
	else:
		push_warning("ModelSexpIntegration: SEXP system not found, functions will be available when SEXP loads")

## Register SEXP functions with the SEXP manager
func _register_with_sexp_manager() -> void:
	if not sexp_manager or not sexp_manager.has_method("register_function"):
		return
	
	# Register model manipulation functions
	for function_name in _sexp_functions.keys():
		var function_data: Dictionary = _sexp_functions[function_name]
		if sexp_manager.has_method("register_function"):
			sexp_manager.register_function(function_name, function_data["callable"], function_data["args"])

## Register SEXP functions for model operations (AC8)
func _register_sexp_functions() -> void:
	# Change ship model function
	_sexp_functions["change-ship-model"] = {
		"callable": _sexp_change_ship_model,
		"args": ["ship_name:string", "new_model_path:string"],
		"description": "Change the 3D model of a ship object"
	}
	
	# Set subsystem damage function
	_sexp_functions["set-subsystem-damage"] = {
		"callable": _sexp_set_subsystem_damage,
		"args": ["ship_name:string", "subsystem_name:string", "damage_percentage:number"],
		"description": "Set damage state of a ship subsystem"
	}
	
	# Repair subsystem function
	_sexp_functions["repair-subsystem"] = {
		"callable": _sexp_repair_subsystem,
		"args": ["ship_name:string", "subsystem_name:string"],
		"description": "Repair a ship subsystem to full health"
	}
	
	# Change model LOD level function
	_sexp_functions["set-model-lod"] = {
		"callable": _sexp_set_model_lod,
		"args": ["ship_name:string", "lod_level:number"],
		"description": "Force specific LOD level for a ship model"
	}
	
	# Get subsystem health function
	_sexp_functions["get-subsystem-health"] = {
		"callable": _sexp_get_subsystem_health,
		"args": ["ship_name:string", "subsystem_name:string"],
		"description": "Get current health percentage of a ship subsystem"
	}
	
	# Check if model exists function
	_sexp_functions["model-exists"] = {
		"callable": _sexp_model_exists,
		"args": ["model_path:string"],
		"description": "Check if a model file exists and can be loaded"
	}
	
	# Apply model animation function
	_sexp_functions["play-model-animation"] = {
		"callable": _sexp_play_model_animation,
		"args": ["ship_name:string", "animation_name:string"],
		"description": "Play a model animation (for animated subsystems)"
	}

## SEXP Function: change-ship-model
func _sexp_change_ship_model(ship_name: String, new_model_path: String) -> bool:
	var space_object: BaseSpaceObject = _find_space_object_by_name(ship_name)
	if not space_object:
		var error_msg: String = "Ship '%s' not found" % ship_name
		push_error("ModelSexpIntegration: " + error_msg)
		sexp_operation_failed.emit("change-ship-model", error_msg)
		return false
	
	# Ensure model integration system is available
	if not model_integration_system:
		model_integration_system = _get_model_integration_system()
		if not model_integration_system:
			var error_msg: String = "Model integration system not available"
			push_error("ModelSexpIntegration: " + error_msg)
			sexp_operation_failed.emit("change-ship-model", error_msg)
			return false
	
	# Store old model path for signal
	var old_model: String = space_object.get_meta("current_model_path", "unknown")
	
	# Change model using model integration system
	var success: bool = model_integration_system.change_model_dynamically(space_object, new_model_path, true)
	
	if success:
		space_object.set_meta("current_model_path", new_model_path)
		sexp_model_changed.emit(space_object, old_model, new_model_path)
		sexp_operation_completed.emit("change-ship-model", true, {
			"ship_name": ship_name,
			"old_model": old_model,
			"new_model": new_model_path
		})
	else:
		var error_msg: String = "Failed to change model for ship '%s' to '%s'" % [ship_name, new_model_path]
		sexp_operation_failed.emit("change-ship-model", error_msg)
	
	return success

## SEXP Function: set-subsystem-damage
func _sexp_set_subsystem_damage(ship_name: String, subsystem_name: String, damage_percentage: float) -> bool:
	var space_object: BaseSpaceObject = _find_space_object_by_name(ship_name)
	if not space_object:
		var error_msg: String = "Ship '%s' not found" % ship_name
		sexp_operation_failed.emit("set-subsystem-damage", error_msg)
		return false
	
	# Ensure subsystem integration is available
	if not subsystem_integration:
		subsystem_integration = _get_subsystem_integration()
		if not subsystem_integration:
			var error_msg: String = "Subsystem integration not available"
			sexp_operation_failed.emit("set-subsystem-damage", error_msg)
			return false
	
	# Clamp damage percentage to valid range
	damage_percentage = clamp(damage_percentage, 0.0, 1.0)
	
	# Calculate damage amount needed to reach target percentage
	var current_health: float = subsystem_integration.get_subsystem_health(space_object, subsystem_name)
	var target_health: float = 1.0 - damage_percentage
	var damage_amount: float = (current_health - target_health) * 100.0  # Convert to damage points
	
	var success: bool = false
	if damage_amount > 0:
		success = subsystem_integration.apply_subsystem_damage(space_object, subsystem_name, damage_amount)
	elif damage_amount < 0:
		# Need to repair subsystem
		success = subsystem_integration.repair_subsystem(space_object, subsystem_name)
		if success and target_health < 1.0:
			# Apply partial damage after repair
			var partial_damage: float = (1.0 - target_health) * 100.0
			success = subsystem_integration.apply_subsystem_damage(space_object, subsystem_name, partial_damage)
	else:
		success = true  # Already at target damage level
	
	if success:
		sexp_subsystem_modified.emit(space_object, subsystem_name, "damage_set")
		sexp_operation_completed.emit("set-subsystem-damage", true, {
			"ship_name": ship_name,
			"subsystem_name": subsystem_name,
			"damage_percentage": damage_percentage
		})
	else:
		var error_msg: String = "Failed to set damage for subsystem '%s' on ship '%s'" % [subsystem_name, ship_name]
		sexp_operation_failed.emit("set-subsystem-damage", error_msg)
	
	return success

## SEXP Function: repair-subsystem
func _sexp_repair_subsystem(ship_name: String, subsystem_name: String) -> bool:
	var space_object: BaseSpaceObject = _find_space_object_by_name(ship_name)
	if not space_object:
		var error_msg: String = "Ship '%s' not found" % ship_name
		sexp_operation_failed.emit("repair-subsystem", error_msg)
		return false
	
	if not subsystem_integration:
		subsystem_integration = _get_subsystem_integration()
		if not subsystem_integration:
			var error_msg: String = "Subsystem integration not available"
			sexp_operation_failed.emit("repair-subsystem", error_msg)
			return false
	
	var success: bool = subsystem_integration.repair_subsystem(space_object, subsystem_name)
	
	if success:
		sexp_subsystem_modified.emit(space_object, subsystem_name, "repaired")
		sexp_operation_completed.emit("repair-subsystem", true, {
			"ship_name": ship_name,
			"subsystem_name": subsystem_name
		})
	else:
		var error_msg: String = "Failed to repair subsystem '%s' on ship '%s'" % [subsystem_name, ship_name]
		sexp_operation_failed.emit("repair-subsystem", error_msg)
	
	return success

## SEXP Function: set-model-lod
func _sexp_set_model_lod(ship_name: String, lod_level: int) -> bool:
	var space_object: BaseSpaceObject = _find_space_object_by_name(ship_name)
	if not space_object:
		var error_msg: String = "Ship '%s' not found" % ship_name
		sexp_operation_failed.emit("set-model-lod", error_msg)
		return false
	
	if not model_integration_system:
		model_integration_system = _get_model_integration_system()
		if not model_integration_system:
			var error_msg: String = "Model integration system not available"
			sexp_operation_failed.emit("set-model-lod", error_msg)
			return false
	
	var success: bool = model_integration_system.set_lod_level(space_object, lod_level)
	
	if success:
		sexp_operation_completed.emit("set-model-lod", true, {
			"ship_name": ship_name,
			"lod_level": lod_level
		})
	else:
		var error_msg: String = "Failed to set LOD level %d for ship '%s'" % [lod_level, ship_name]
		sexp_operation_failed.emit("set-model-lod", error_msg)
	
	return success

## SEXP Function: get-subsystem-health
func _sexp_get_subsystem_health(ship_name: String, subsystem_name: String) -> float:
	var space_object: BaseSpaceObject = _find_space_object_by_name(ship_name)
	if not space_object:
		return -1.0  # Error value
	
	if not subsystem_integration:
		subsystem_integration = _get_subsystem_integration()
		if not subsystem_integration:
			return -1.0
	
	var health: float = subsystem_integration.get_subsystem_health(space_object, subsystem_name)
	
	sexp_operation_completed.emit("get-subsystem-health", true, {
		"ship_name": ship_name,
		"subsystem_name": subsystem_name,
		"health": health
	})
	
	return health

## SEXP Function: model-exists
func _sexp_model_exists(model_path: String) -> bool:
	var model_exists: bool = FileAccess.file_exists(model_path)
	
	if model_exists:
		# Try to load to verify it's a valid model
		var test_model: Mesh = load(model_path) as Mesh
		model_exists = (test_model != null)
	
	sexp_operation_completed.emit("model-exists", true, {
		"model_path": model_path,
		"exists": model_exists
	})
	
	return model_exists

## SEXP Function: play-model-animation
func _sexp_play_model_animation(ship_name: String, animation_name: String) -> bool:
	var space_object: BaseSpaceObject = _find_space_object_by_name(ship_name)
	if not space_object:
		var error_msg: String = "Ship '%s' not found" % ship_name
		sexp_operation_failed.emit("play-model-animation", error_msg)
		return false
	
	# Find animation player in the space object
	var animation_player: AnimationPlayer = space_object.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not animation_player:
		var error_msg: String = "No AnimationPlayer found on ship '%s'" % ship_name
		sexp_operation_failed.emit("play-model-animation", error_msg)
		return false
	
	# Check if animation exists
	if not animation_player.has_animation(animation_name):
		var error_msg: String = "Animation '%s' not found on ship '%s'" % [animation_name, ship_name]
		sexp_operation_failed.emit("play-model-animation", error_msg)
		return false
	
	# Play animation
	animation_player.play(animation_name)
	
	sexp_operation_completed.emit("play-model-animation", true, {
		"ship_name": ship_name,
		"animation_name": animation_name
	})
	
	return true

## Find space object by name (searches through ObjectManager)
func _find_space_object_by_name(object_name: String) -> BaseSpaceObject:
	var object_manager: Node = get_node_or_null("/root/ObjectManager")
	if not object_manager:
		return null
	
	# Search through registered objects
	if object_manager.has_method("find_object_by_name"):
		var found_object: Node = object_manager.find_object_by_name(object_name)
		return found_object as BaseSpaceObject
	
	# Fallback: search scene tree
	var all_objects: Array[Node] = get_tree().get_nodes_in_group("space_objects")
	for obj in all_objects:
		if obj.name == object_name and obj is BaseSpaceObject:
			return obj as BaseSpaceObject
	
	return null

## Get model integration system reference
func _get_model_integration_system() -> ModelIntegrationSystem:
	var system: Node = get_node_or_null("/root/ModelIntegrationSystem")
	if not system:
		# Try to find in scene tree
		system = get_tree().get_first_node_in_group("model_integration_system")
	
	return system as ModelIntegrationSystem

## Get subsystem integration reference
func _get_subsystem_integration() -> ModelSubsystemIntegration:
	var system: Node = get_node_or_null("/root/ModelSubsystemIntegration")
	if not system:
		# Try to find in scene tree
		system = get_tree().get_first_node_in_group("subsystem_integration")
	
	return system as ModelSubsystemIntegration

## Register space object for SEXP access
func register_space_object(space_object: BaseSpaceObject) -> void:
	if not space_object:
		return
	
	# Add to space objects group for SEXP function access
	space_object.add_to_group("space_objects")
	
	# Store reference for faster lookup
	space_object.set_meta("sexp_accessible", true)

## Unregister space object from SEXP access
func unregister_space_object(space_object: BaseSpaceObject) -> void:
	if not space_object:
		return
	
	space_object.remove_from_group("space_objects")
	space_object.remove_meta("sexp_accessible")

## Get available SEXP functions for model operations
func get_available_sexp_functions() -> Dictionary:
	return _sexp_functions.duplicate()

## Enable/disable SEXP integration
func set_sexp_integration_enabled(enabled: bool) -> void:
	if enabled and sexp_manager:
		_register_with_sexp_manager()
	elif not enabled and sexp_manager:
		# Unregister functions
		for function_name in _sexp_functions.keys():
			if sexp_manager.has_method("unregister_function"):
				sexp_manager.unregister_function(function_name)