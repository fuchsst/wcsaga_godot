class_name DamagePersistenceManager
extends Node

## Damage persistence system managing save/load operations for all damage system components
## Handles WCS-authentic damage state persistence with comprehensive serialization (SHIP-009 AC6)

# EPIC-002 Asset Core Integration
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const SaveGameTypes = preload("res://addons/wcs_asset_core/constants/save_game_types.gd")

# Damage persistence signals (SHIP-009 AC6)
signal damage_state_saved(save_data: Dictionary)
signal damage_state_loaded(save_data: Dictionary, success: bool)
signal persistence_error(error_message: String, component_name: String)

# Ship integration
var ship: BaseShip
var damage_manager: Node
var shield_manager: Node
var critical_system: Node
var visualization_manager: Node
var collision_system: Node
var armor_calculator: Node

# Save/load configuration
var auto_save_enabled: bool = true
var save_compression_enabled: bool = true
var backup_count: int = 3  # Number of backup saves to keep
var save_validation_enabled: bool = true

# Persistence metadata
var save_version: String = "1.0"
var last_save_time: float = 0.0
var last_load_time: float = 0.0
var save_integrity_hash: String = ""

func _ready() -> void:
	name = "DamagePersistenceManager"

## Initialize damage persistence system for specific ship (SHIP-009 AC6)
func initialize_persistence_system(parent_ship: BaseShip) -> bool:
	"""Initialize damage persistence system for specific ship.
	
	Args:
		parent_ship: Ship to manage damage persistence for
		
	Returns:
		true if initialization successful
	"""
	if not parent_ship:
		push_error("DamagePersistenceManager: Cannot initialize with null ship")
		return false
	
	ship = parent_ship
	
	# Get all damage system components
	damage_manager = ship.get_node_or_null("DamageManager")
	shield_manager = ship.get_node_or_null("ShieldQuadrantManager")
	critical_system = ship.get_node_or_null("CriticalDamageSystem")
	visualization_manager = ship.get_node_or_null("DamageVisualizationManager")
	collision_system = ship.get_node_or_null("CollisionDamageSystem")
	armor_calculator = ship.get_node_or_null("ArmorResistanceCalculator")
	
	# Connect to ship destruction for final save
	ship.ship_destroyed.connect(_on_ship_destroyed)
	
	return true

# ============================================================================
# COMPREHENSIVE SAVE SYSTEM (SHIP-009 AC6)
# ============================================================================

## Save complete damage system state (SHIP-009 AC6)
func save_damage_state() -> Dictionary:
	"""Save complete damage system state to dictionary.
	
	Returns:
		Complete damage state data dictionary
	"""
	var save_data: Dictionary = {
		"metadata": _create_save_metadata(),
		"ship_info": _get_ship_info(),
		"damage_manager": {},
		"shield_manager": {},
		"critical_system": {},
		"visualization_manager": {},
		"collision_system": {},
		"armor_calculator": {}
	}
	
	# Save damage manager state
	if damage_manager and damage_manager.has_method("get_damage_save_data"):
		save_data.damage_manager = damage_manager.get_damage_save_data()
	
	# Save shield manager state
	if shield_manager and shield_manager.has_method("get_shield_save_data"):
		save_data.shield_manager = shield_manager.get_shield_save_data()
	
	# Save critical damage system state
	if critical_system and critical_system.has_method("get_critical_save_data"):
		save_data.critical_system = critical_system.get_critical_save_data()
	
	# Save visualization state (optional)
	if visualization_manager and visualization_manager.has_method("get_visualization_save_data"):
		save_data.visualization_manager = visualization_manager.get_visualization_save_data()
	else:
		save_data.visualization_manager = _get_basic_visualization_state()
	
	# Save collision system state
	if collision_system and collision_system.has_method("get_collision_save_data"):
		save_data.collision_system = collision_system.get_collision_save_data()
	
	# Save armor calculator state (usually configuration only)
	if armor_calculator and armor_calculator.has_method("get_armor_save_data"):
		save_data.armor_calculator = armor_calculator.get_armor_save_data()
	else:
		save_data.armor_calculator = _get_basic_armor_state()
	
	# Calculate and store integrity hash
	save_data.metadata.integrity_hash = _calculate_save_hash(save_data)
	save_integrity_hash = save_data.metadata.integrity_hash
	
	# Update save time
	last_save_time = Time.get_ticks_msec() * 0.001
	save_data.metadata.save_timestamp = last_save_time
	
	# Emit save signal
	damage_state_saved.emit(save_data)
	
	return save_data

## Load complete damage system state (SHIP-009 AC6)
func load_damage_state(save_data: Dictionary) -> bool:
	"""Load complete damage system state from dictionary.
	
	Args:
		save_data: Complete damage state data dictionary
		
	Returns:
		true if loading was successful
	"""
	if not save_data:
		_emit_persistence_error("Save data is null or empty", "DamagePersistenceManager")
		return false
	
	# Validate save data
	if not _validate_save_data(save_data):
		_emit_persistence_error("Save data validation failed", "DamagePersistenceManager")
		return false
	
	var load_success: bool = true
	var error_components: Array[String] = []
	
	# Load damage manager state
	if save_data.has("damage_manager") and damage_manager:
		if damage_manager.has_method("load_damage_save_data"):
			if not damage_manager.load_damage_save_data(save_data.damage_manager):
				load_success = false
				error_components.append("DamageManager")
	
	# Load shield manager state
	if save_data.has("shield_manager") and shield_manager:
		if shield_manager.has_method("load_shield_save_data"):
			if not shield_manager.load_shield_save_data(save_data.shield_manager):
				load_success = false
				error_components.append("ShieldQuadrantManager")
	
	# Load critical damage system state
	if save_data.has("critical_system") and critical_system:
		if critical_system.has_method("load_critical_save_data"):
			if not critical_system.load_critical_save_data(save_data.critical_system):
				load_success = false
				error_components.append("CriticalDamageSystem")
	
	# Load visualization state (optional, non-critical)
	if save_data.has("visualization_manager") and visualization_manager:
		if visualization_manager.has_method("load_visualization_save_data"):
			visualization_manager.load_visualization_save_data(save_data.visualization_manager)
	
	# Load collision system state
	if save_data.has("collision_system") and collision_system:
		if collision_system.has_method("load_collision_save_data"):
			if not collision_system.load_collision_save_data(save_data.collision_system):
				load_success = false
				error_components.append("CollisionDamageSystem")
	
	# Load armor calculator state
	if save_data.has("armor_calculator") and armor_calculator:
		if armor_calculator.has_method("load_armor_save_data"):
			if not armor_calculator.load_armor_save_data(save_data.armor_calculator):
				load_success = false
				error_components.append("ArmorResistanceCalculator")
	
	# Update load time
	last_load_time = Time.get_ticks_msec() * 0.001
	
	# Emit load signal with results
	damage_state_loaded.emit(save_data, load_success)
	
	# Report errors if any
	if not load_success:
		var error_message: String = "Failed to load components: " + ", ".join(error_components)
		_emit_persistence_error(error_message, "DamagePersistenceManager")
	
	return load_success

## Create save metadata for damage state
func _create_save_metadata() -> Dictionary:
	"""Create metadata for damage state save."""
	return {
		"save_version": save_version,
		"godot_version": Engine.get_version_info(),
		"save_timestamp": Time.get_ticks_msec() * 0.001,
		"ship_instance_id": ship.get_instance_id() if ship else 0,
		"components_present": _get_components_present(),
		"compression_enabled": save_compression_enabled,
		"integrity_hash": ""  # Will be calculated later
	}

## Get basic ship information for save context
func _get_ship_info() -> Dictionary:
	"""Get basic ship information for save context."""
	if not ship:
		return {}
	
	return {
		"ship_name": ship.name,
		"ship_class_name": ship.ship_class.class_name if ship.ship_class else "",
		"ship_type": ship.ship_class.ship_type if ship.ship_class else 0,
		"max_hull_strength": ship.max_hull_strength,
		"max_shield_strength": ship.max_shield_strength,
		"current_hull_strength": ship.current_hull_strength,
		"current_shield_strength": ship.current_shield_strength,
		"ship_position": ship.global_position,
		"ship_rotation": ship.global_rotation
	}

## Get list of damage components present
func _get_components_present() -> Array[String]:
	"""Get list of damage system components that are present."""
	var components: Array[String] = []
	
	if damage_manager:
		components.append("DamageManager")
	if shield_manager:
		components.append("ShieldQuadrantManager")
	if critical_system:
		components.append("CriticalDamageSystem")
	if visualization_manager:
		components.append("DamageVisualizationManager")
	if collision_system:
		components.append("CollisionDamageSystem")
	if armor_calculator:
		components.append("ArmorResistanceCalculator")
	
	return components

## Get basic visualization state when full save unavailable
func _get_basic_visualization_state() -> Dictionary:
	"""Get basic visualization state when full visualization save is unavailable."""
	if not visualization_manager:
		return {}
	
	return {
		"current_damage_level": visualization_manager.current_damage_level if visualization_manager.has_method("get_current_damage_level") else 0,
		"fire_effects_count": visualization_manager.fire_effects.size() if visualization_manager.has("fire_effects") else 0,
		"smoke_effects_count": visualization_manager.smoke_effects.size() if visualization_manager.has("smoke_effects") else 0
	}

## Get basic armor state when full save unavailable
func _get_basic_armor_state() -> Dictionary:
	"""Get basic armor state when full armor save is unavailable."""
	if not armor_calculator:
		return {}
	
	return {
		"penetration_tracking_count": armor_calculator.penetration_tracking.size() if armor_calculator.has("penetration_tracking") else 0
	}

# ============================================================================
# SAVE DATA VALIDATION (SHIP-009 AC6)
# ============================================================================

## Validate save data integrity and structure
func _validate_save_data(save_data: Dictionary) -> bool:
	"""Validate save data integrity and structure."""
	if not save_validation_enabled:
		return true
	
	# Check basic structure
	if not save_data.has("metadata"):
		return false
	
	var metadata: Dictionary = save_data.metadata
	
	# Check version compatibility
	if not _is_version_compatible(metadata.get("save_version", "")):
		return false
	
	# Verify integrity hash if present
	if metadata.has("integrity_hash") and metadata.integrity_hash != "":
		var stored_hash: String = metadata.integrity_hash
		metadata.integrity_hash = ""  # Temporarily remove for calculation
		var calculated_hash: String = _calculate_save_hash(save_data)
		metadata.integrity_hash = stored_hash  # Restore
		
		if stored_hash != calculated_hash:
			return false
	
	# Check required components
	var required_components: Array[String] = ["damage_manager", "shield_manager"]
	for component in required_components:
		if not save_data.has(component):
			return false
	
	return true

## Check if save version is compatible
func _is_version_compatible(save_version_string: String) -> bool:
	"""Check if save version is compatible with current version."""
	if save_version_string == "":
		return false
	
	# Parse version numbers
	var save_parts: PackedStringArray = save_version_string.split(".")
	var current_parts: PackedStringArray = save_version.split(".")
	
	if save_parts.size() != current_parts.size():
		return false
	
	# Check major version compatibility
	if save_parts[0] != current_parts[0]:
		return false
	
	# Minor version differences are usually compatible
	return true

## Calculate hash for save data integrity
func _calculate_save_hash(save_data: Dictionary) -> String:
	"""Calculate hash for save data integrity verification."""
	# Convert save data to JSON string
	var json_string: String = JSON.stringify(save_data)
	
	# Create a simple hash (in real implementation, use proper cryptographic hash)
	var hash: int = 0
	for i in range(json_string.length()):
		hash = ((hash << 5) - hash + json_string.unicode_at(i)) & 0xFFFFFFFF
	
	return str(hash)

# ============================================================================
# FILE-BASED PERSISTENCE (SHIP-009 AC6)
# ============================================================================

## Save damage state to file
func save_damage_state_to_file(file_path: String) -> bool:
	"""Save damage state to file with optional compression and backup.
	
	Args:
		file_path: Path to save file
		
	Returns:
		true if save was successful
	"""
	var save_data: Dictionary = save_damage_state()
	
	# Create backup if file exists
	if FileAccess.file_exists(file_path) and backup_count > 0:
		_create_backup_files(file_path)
	
	# Save to file
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		_emit_persistence_error("Could not open file for writing: " + file_path, "FileSystem")
		return false
	
	var json_string: String = JSON.stringify(save_data)
	
	# Apply compression if enabled
	if save_compression_enabled:
		var compressed_data: PackedByteArray = json_string.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
		file.store_var(compressed_data)
	else:
		file.store_string(json_string)
	
	file.close()
	return true

## Load damage state from file
func load_damage_state_from_file(file_path: String) -> bool:
	"""Load damage state from file with decompression support.
	
	Args:
		file_path: Path to save file
		
	Returns:
		true if load was successful
	"""
	if not FileAccess.file_exists(file_path):
		_emit_persistence_error("Save file does not exist: " + file_path, "FileSystem")
		return false
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		_emit_persistence_error("Could not open file for reading: " + file_path, "FileSystem")
		return false
	
	var json_string: String = ""
	
	# Check if file contains compressed data
	if save_compression_enabled:
		var compressed_data: PackedByteArray = file.get_var()
		var decompressed_data: PackedByteArray = compressed_data.decompress(0, FileAccess.COMPRESSION_GZIP)
		json_string = decompressed_data.get_string_from_utf8()
	else:
		json_string = file.get_as_text()
	
	file.close()
	
	# Parse JSON
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	
	if parse_result != OK:
		_emit_persistence_error("JSON parse error: " + str(parse_result), "JSONParser")
		return false
	
	var save_data: Dictionary = json.data
	return load_damage_state(save_data)

## Create backup files
func _create_backup_files(original_file_path: String) -> void:
	"""Create backup files by rotating existing saves."""
	# Rotate backup files
	for i in range(backup_count - 1, 0, -1):
		var current_backup: String = original_file_path + ".backup" + str(i)
		var next_backup: String = original_file_path + ".backup" + str(i + 1)
		
		if FileAccess.file_exists(current_backup):
			if i == backup_count - 1:
				# Delete oldest backup
				DirAccess.remove_absolute(current_backup)
			else:
				# Move to next backup number
				DirAccess.rename_absolute(current_backup, next_backup)
	
	# Create new backup from current file
	var backup_path: String = original_file_path + ".backup1"
	DirAccess.copy_absolute(original_file_path, backup_path)

# ============================================================================
# AUTO-SAVE SYSTEM (SHIP-009 AC6)
# ============================================================================

## Process auto-save if enabled
func _process_auto_save() -> void:
	"""Process automatic saving based on ship condition changes."""
	if not auto_save_enabled or not ship:
		return
	
	# Auto-save triggers
	var should_auto_save: bool = false
	
	# Save when ship takes significant damage
	var hull_percentage: float = (ship.current_hull_strength / ship.max_hull_strength) * 100.0
	if hull_percentage < 50.0:  # Below 50% hull
		should_auto_save = true
	
	# Save when critical events are active
	if critical_system and critical_system.has_method("get_critical_status"):
		var critical_status: Dictionary = critical_system.get_critical_status()
		if critical_status.get("active_critical_events", []).size() > 0:
			should_auto_save = true
	
	# Save periodically (every 30 seconds)
	var current_time: float = Time.get_ticks_msec() * 0.001
	if current_time - last_save_time > 30.0:
		should_auto_save = true
	
	if should_auto_save:
		var auto_save_path: String = "user://damage_auto_save_" + ship.name + ".json"
		save_damage_state_to_file(auto_save_path)

# ============================================================================
# MIGRATION AND COMPATIBILITY (SHIP-009 AC6)
# ============================================================================

## Migrate save data from older version
func migrate_save_data(save_data: Dictionary, from_version: String) -> Dictionary:
	"""Migrate save data from older version to current version.
	
	Args:
		save_data: Original save data
		from_version: Version to migrate from
		
	Returns:
		Migrated save data
	"""
	var migrated_data: Dictionary = save_data.duplicate(true)
	
	# Example migration logic
	if from_version == "0.9":
		# Add new fields that weren't present in 0.9
		if not migrated_data.has("collision_system"):
			migrated_data.collision_system = {}
		
		# Update metadata
		migrated_data.metadata.save_version = save_version
		migrated_data.metadata.migrated_from = from_version
	
	return migrated_data

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

## Handle ship destruction for final save
func _on_ship_destroyed(destroyed_ship: BaseShip) -> void:
	"""Handle ship destruction event with final damage state save."""
	if destroyed_ship == ship and auto_save_enabled:
		# Save final damage state for historical/statistical purposes
		var final_save_path: String = "user://damage_final_state_" + ship.name + "_" + str(Time.get_ticks_msec()) + ".json"
		save_damage_state_to_file(final_save_path)

## Emit persistence error signal
func _emit_persistence_error(error_message: String, component_name: String) -> void:
	"""Emit persistence error signal with details."""
	push_error("DamagePersistenceManager (" + component_name + "): " + error_message)
	persistence_error.emit(error_message, component_name)

# ============================================================================
# CONFIGURATION AND CONTROL
# ============================================================================

## Enable or disable auto-save
func set_auto_save_enabled(enabled: bool) -> void:
	"""Enable or disable automatic damage state saving."""
	auto_save_enabled = enabled

## Set number of backup files to keep
func set_backup_count(count: int) -> void:
	"""Set number of backup files to keep."""
	backup_count = max(0, count)

## Enable or disable save compression
func set_compression_enabled(enabled: bool) -> void:
	"""Enable or disable save file compression."""
	save_compression_enabled = enabled

## Enable or disable save validation
func set_validation_enabled(enabled: bool) -> void:
	"""Enable or disable save data validation."""
	save_validation_enabled = enabled

# ============================================================================
# DEBUG AND INFORMATION
# ============================================================================

## Get persistence system status
func get_persistence_status() -> Dictionary:
	"""Get comprehensive persistence system status for debugging."""
	var components_status: Dictionary = {}
	
	for component_name in _get_components_present():
		var component: Node = get(component_name.to_lower().replace("damage", "").replace("manager", "_manager"))
		components_status[component_name] = {
			"present": component != null,
			"has_save_method": component.has_method("get_" + component_name.to_lower() + "_save_data") if component else false,
			"has_load_method": component.has_method("load_" + component_name.to_lower() + "_save_data") if component else false
		}
	
	return {
		"auto_save_enabled": auto_save_enabled,
		"compression_enabled": save_compression_enabled,
		"validation_enabled": save_validation_enabled,
		"backup_count": backup_count,
		"save_version": save_version,
		"last_save_time": last_save_time,
		"last_load_time": last_load_time,
		"components_status": components_status
	}

## Get debug information string
func debug_info() -> String:
	"""Get debug information string."""
	var components_count: int = _get_components_present().size()
	var time_since_save: float = (Time.get_ticks_msec() * 0.001) - last_save_time
	
	return "[Persistence Components:%d AutoSave:%s LastSave:%.1fs]" % [
		components_count,
		"Y" if auto_save_enabled else "N",
		time_since_save
	]