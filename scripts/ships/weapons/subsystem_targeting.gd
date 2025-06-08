class_name SubsystemTargeting
extends Node

## Subsystem targeting system for direct subsystem selection and navigation
## Enables targeting specific ship subsystems with cycle navigation
## Implementation of SHIP-006 AC4: Subsystem targeting

# Constants
const SubsystemTypes = preload("res://addons/wcs_asset_core/constants/subsystem_types.gd")

# Signals for subsystem targeting events
signal subsystem_selected(target: Node3D, subsystem: Node, subsystem_name: String)
signal subsystem_targeting_disabled()
signal subsystem_cycle_completed(target: Node3D, available_count: int)

# Subsystem targeting state
var current_target_ship: BaseShip = null
var current_subsystem: Node = null
var current_subsystem_name: String = ""
var subsystem_cycle_index: int = -1

# Available subsystems for current target
var available_subsystems: Array[Node] = []
var subsystem_names: Array[String] = []
var subsystem_priorities: Array[int] = []

# Targeting preferences
var prioritize_critical_subsystems: bool = true
var include_destroyed_subsystems: bool = false
var subsystem_type_filter: Array[SubsystemTypes.Type] = []

# Ship reference
var parent_ship: BaseShip

func _init() -> void:
	set_process(false)  # Enable only when needed

## Initialize subsystem targeting
func initialize_subsystem_targeting(ship: BaseShip) -> bool:
	"""Initialize subsystem targeting with ship reference.
	
	Args:
		ship: Parent ship reference
		
	Returns:
		true if initialization successful
	"""
	if not ship:
		push_error("SubsystemTargeting: Cannot initialize without valid ship")
		return false
	
	parent_ship = ship
	return true

## Set target ship for subsystem targeting (SHIP-006 AC4)
func set_target_ship(target_ship: BaseShip) -> bool:
	"""Set target ship for subsystem targeting.
	
	Args:
		target_ship: Ship to target subsystems on (null to disable)
		
	Returns:
		true if target was set successfully
	"""
	# Clear previous targeting
	_clear_subsystem_targeting()
	
	if not target_ship:
		subsystem_targeting_disabled.emit()
		return true
	
	# Validate target ship
	if not target_ship.has_method("get_subsystem_manager") or not target_ship.subsystem_manager:
		return false
	
	current_target_ship = target_ship
	
	# Scan for available subsystems
	_scan_available_subsystems()
	
	# Select first subsystem if available
	if not available_subsystems.is_empty():
		subsystem_cycle_index = 0
		return _select_subsystem_by_index(0)
	
	return true

## Scan for available subsystems on target ship
func _scan_available_subsystems() -> void:
	"""Scan target ship for available subsystems."""
	available_subsystems.clear()
	subsystem_names.clear()
	subsystem_priorities.clear()
	
	if not current_target_ship or not current_target_ship.subsystem_manager:
		return
	
	var subsystem_manager: SubsystemManager = current_target_ship.subsystem_manager
	var all_subsystems: Array = subsystem_manager.get_all_subsystems()
	
	for subsystem in all_subsystems:
		if _is_subsystem_targetable(subsystem):
			available_subsystems.append(subsystem)
			subsystem_names.append(subsystem.name)
			subsystem_priorities.append(_calculate_subsystem_priority(subsystem))
	
	# Sort by priority if enabled
	if prioritize_critical_subsystems:
		_sort_subsystems_by_priority()

## Check if subsystem is targetable
func _is_subsystem_targetable(subsystem: Node) -> bool:
	"""Check if subsystem meets targeting criteria."""
	if not subsystem or not subsystem.has_method("get_status_info"):
		return false
	
	var status_info: Dictionary = subsystem.get_status_info()
	
	# Check if destroyed subsystems should be included
	if not include_destroyed_subsystems and not status_info.get("is_functional", false):
		return false
	
	# Check subsystem type filter
	if not subsystem_type_filter.is_empty():
		var subsystem_type: SubsystemTypes.Type = status_info.get("type", SubsystemTypes.Type.NONE)
		if subsystem_type not in subsystem_type_filter:
			return false
	
	return true

## Calculate subsystem targeting priority
func _calculate_subsystem_priority(subsystem: Node) -> int:
	"""Calculate priority score for subsystem targeting."""
	var priority: int = 0
	
	if not subsystem or not subsystem.has_method("get_status_info"):
		return priority
	
	var status_info: Dictionary = subsystem.get_status_info()
	var subsystem_definition = subsystem.subsystem_definition
	
	# Critical subsystems get highest priority
	if status_info.get("is_critical", false):
		priority += 100
	
	# Subsystem type priority
	var subsystem_type: SubsystemTypes.Type = status_info.get("type", SubsystemTypes.Type.NONE)
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			priority += 80  # Engines high priority (mobility kill)
		SubsystemTypes.Type.WEAPONS:
			priority += 70  # Weapons high priority (combat effectiveness)
		SubsystemTypes.Type.RADAR, SubsystemTypes.Type.SENSORS:
			priority += 60  # Sensors moderate priority (awareness)
		SubsystemTypes.Type.SHIELDS:
			priority += 50  # Shields moderate priority (defense)
		SubsystemTypes.Type.COMMUNICATION:
			priority += 30  # Communications lower priority
		_:
			priority += 10  # Other subsystems lowest priority
	
	# Health-based priority (damaged subsystems easier to destroy)
	var health_percent: float = status_info.get("health_percent", 100.0)
	if health_percent < 50.0:
		priority += 20  # Damaged subsystems get bonus priority
	
	# Turret subsystems get bonus if they're targeting us
	if subsystem_definition and subsystem_definition.is_turret():
		var turret_info: Dictionary = status_info.get("turret_info", {})
		if turret_info.get("has_target", false):
			priority += 25  # Active turrets get priority
	
	return priority

## Sort subsystems by priority
func _sort_subsystems_by_priority() -> void:
	"""Sort available subsystems by targeting priority."""
	# Create indices array for sorting
	var indices: Array[int] = []
	for i in range(available_subsystems.size()):
		indices.append(i)
	
	# Sort indices by priority
	indices.sort_custom(func(a: int, b: int) -> bool: return subsystem_priorities[a] > subsystem_priorities[b])
	
	# Reorder arrays based on sorted indices
	var sorted_subsystems: Array[Node] = []
	var sorted_names: Array[String] = []
	var sorted_priorities: Array[int] = []
	
	for index in indices:
		sorted_subsystems.append(available_subsystems[index])
		sorted_names.append(subsystem_names[index])
		sorted_priorities.append(subsystem_priorities[index])
	
	available_subsystems = sorted_subsystems
	subsystem_names = sorted_names
	subsystem_priorities = sorted_priorities

## Cycle to next subsystem (SHIP-006 AC4)
func cycle_subsystem_next() -> bool:
	"""Cycle to next available subsystem.
	
	Returns:
		true if cycling successful
	"""
	if not current_target_ship or available_subsystems.is_empty():
		return false
	
	subsystem_cycle_index = (subsystem_cycle_index + 1) % available_subsystems.size()
	return _select_subsystem_by_index(subsystem_cycle_index)

## Cycle to previous subsystem (SHIP-006 AC4)
func cycle_subsystem_previous() -> bool:
	"""Cycle to previous available subsystem.
	
	Returns:
		true if cycling successful
	"""
	if not current_target_ship or available_subsystems.is_empty():
		return false
	
	subsystem_cycle_index = (subsystem_cycle_index - 1) % available_subsystems.size()
	if subsystem_cycle_index < 0:
		subsystem_cycle_index = available_subsystems.size() - 1
	
	return _select_subsystem_by_index(subsystem_cycle_index)

## Select subsystem by type (SHIP-006 AC4)
func select_subsystem_by_type(subsystem_type: SubsystemTypes.Type) -> bool:
	"""Select first subsystem of specified type.
	
	Args:
		subsystem_type: Type of subsystem to select
		
	Returns:
		true if subsystem of type was found and selected
	"""
	if not current_target_ship or available_subsystems.is_empty():
		return false
	
	for i in range(available_subsystems.size()):
		var subsystem: Node = available_subsystems[i]
		if subsystem.has_method("get_status_info"):
			var status_info: Dictionary = subsystem.get_status_info()
			if status_info.get("type", SubsystemTypes.Type.NONE) == subsystem_type:
				subsystem_cycle_index = i
				return _select_subsystem_by_index(i)
	
	return false

## Select subsystem by name
func select_subsystem_by_name(subsystem_name: String) -> bool:
	"""Select subsystem by name.
	
	Args:
		subsystem_name: Name of subsystem to select
		
	Returns:
		true if subsystem was found and selected
	"""
	if not current_target_ship or available_subsystems.is_empty():
		return false
	
	for i in range(subsystem_names.size()):
		if subsystem_names[i] == subsystem_name:
			subsystem_cycle_index = i
			return _select_subsystem_by_index(i)
	
	return false

## Select highest priority subsystem
func select_priority_subsystem() -> bool:
	"""Select highest priority available subsystem.
	
	Returns:
		true if priority subsystem was selected
	"""
	if not current_target_ship or available_subsystems.is_empty():
		return false
	
	# Subsystems are already sorted by priority, so select first one
	subsystem_cycle_index = 0
	return _select_subsystem_by_index(0)

## Select subsystem by index
func _select_subsystem_by_index(index: int) -> bool:
	"""Select subsystem by array index."""
	if index < 0 or index >= available_subsystems.size():
		return false
	
	var subsystem: Node = available_subsystems[index]
	var subsystem_name: String = subsystem_names[index]
	
	current_subsystem = subsystem
	current_subsystem_name = subsystem_name
	
	subsystem_selected.emit(current_target_ship, subsystem, subsystem_name)
	return true

## Clear subsystem targeting
func _clear_subsystem_targeting() -> void:
	"""Clear all subsystem targeting state."""
	current_target_ship = null
	current_subsystem = null
	current_subsystem_name = ""
	subsystem_cycle_index = -1
	
	available_subsystems.clear()
	subsystem_names.clear()
	subsystem_priorities.clear()

## Get current subsystem information
func get_current_subsystem_info() -> Dictionary:
	"""Get information about currently targeted subsystem."""
	var info: Dictionary = {
		"has_target_ship": current_target_ship != null,
		"has_subsystem": current_subsystem != null,
		"subsystem_name": current_subsystem_name,
		"subsystem_index": subsystem_cycle_index,
		"available_count": available_subsystems.size()
	}
	
	if current_target_ship:
		info["target_ship_name"] = current_target_ship.name
	
	if current_subsystem and current_subsystem.has_method("get_status_info"):
		var status_info: Dictionary = current_subsystem.get_status_info()
		info["subsystem_health"] = status_info.get("health_percent", 0.0)
		info["subsystem_functional"] = status_info.get("is_functional", false)
		info["subsystem_type"] = status_info.get("type", SubsystemTypes.Type.NONE)
		info["subsystem_critical"] = status_info.get("is_critical", false)
	
	return info

## Get available subsystem names
func get_available_subsystem_names() -> Array[String]:
	"""Get list of available subsystem names for UI display."""
	return subsystem_names.duplicate()

## Get subsystem position for HUD display
func get_subsystem_position() -> Vector3:
	"""Get world position of current subsystem for HUD display."""
	if current_subsystem and current_subsystem.has_method("get_global_position"):
		return current_subsystem.global_position
	elif current_target_ship:
		return current_target_ship.global_position
	
	return Vector3.ZERO

## Set targeting preferences
func set_targeting_preferences(prioritize_critical: bool, include_destroyed: bool) -> void:
	"""Set subsystem targeting preferences.
	
	Args:
		prioritize_critical: Whether to prioritize critical subsystems
		include_destroyed: Whether to include destroyed subsystems in targeting
	"""
	prioritize_critical_subsystems = prioritize_critical
	include_destroyed_subsystems = include_destroyed

## Set subsystem type filter
func set_subsystem_type_filter(types: Array[SubsystemTypes.Type]) -> void:
	"""Set filter for subsystem types to target.
	
	Args:
		types: Array of subsystem types to include (empty = all types)
	"""
	subsystem_type_filter = types

## Check if targeting subsystems
func is_targeting_subsystems() -> bool:
	"""Check if currently targeting subsystems."""
	return current_target_ship != null and current_subsystem != null

## Get subsystem damage effectiveness
func get_damage_effectiveness(weapon_damage: float) -> float:
	"""Calculate damage effectiveness against current subsystem.
	
	Args:
		weapon_damage: Base weapon damage
		
	Returns:
		Effective damage after subsystem modifiers
	"""
	if not current_subsystem or not current_subsystem.has_method("get_status_info"):
		return weapon_damage
	
	var status_info: Dictionary = current_subsystem.get_status_info()
	var subsystem_definition = current_subsystem.subsystem_definition
	
	if subsystem_definition and subsystem_definition.has_method("get_vulnerability_modifier"):
		var vulnerability: float = subsystem_definition.get_vulnerability_modifier()
		return weapon_damage * vulnerability
	
	return weapon_damage

## Refresh subsystem list (call when target ship changes)
func refresh_subsystems() -> void:
	"""Refresh available subsystems for current target."""
	if current_target_ship:
		_scan_available_subsystems()
		
		# Try to maintain current selection if still valid
		if current_subsystem and current_subsystem in available_subsystems:
			subsystem_cycle_index = available_subsystems.find(current_subsystem)
		else:
			# Select first available subsystem
			if not available_subsystems.is_empty():
				subsystem_cycle_index = 0
				_select_subsystem_by_index(0)

## Debug information
func debug_info() -> String:
	"""Get debug information string."""
	var info: String = "SubsystemTargeting: "
	info += "Ship:%s " % (current_target_ship.name if current_target_ship else "None")
	info += "Subsystem:%s " % current_subsystem_name
	info += "Available:%d " % available_subsystems.size()
	return info