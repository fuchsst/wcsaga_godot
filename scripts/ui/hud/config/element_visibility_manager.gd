class_name HUDElementVisibilityManager
extends RefCounted

## EPIC-012 HUD-004: Element Visibility Management
## Manages individual HUD element visibility with real-time updates and group operations

signal element_visibility_changed(element_id: String, visible: bool)
signal visibility_group_changed(group_name: String, visible: bool)
signal visibility_flags_updated(new_flags: int)

# Current visibility state
var current_visibility_flags: int = 0
var element_visibility_overrides: Dictionary = {}
var visibility_groups: Dictionary = {}

# Element visibility mappings (element_id -> flag bit)
var element_flag_mapping: Dictionary = {}

# Visibility group definitions
var default_visibility_groups: Dictionary = {}

func initialize() -> void:
	_setup_element_mappings()
	_setup_visibility_groups()
	_load_default_visibility()
	print("HUDElementVisibilityManager: Initialized with %d elements" % element_flag_mapping.size())

## Setup element to flag bit mappings
func _setup_element_mappings() -> void:
	element_flag_mapping = {
		# Core HUD elements
		"speed": HUDConfig.GAUGE_SPEED,
		"weapons": HUDConfig.GAUGE_WEAPONS,
		"objectives": HUDConfig.GAUGE_OBJECTIVES,
		"target_box": HUDConfig.GAUGE_TARGET_BOX,
		"target_shield": HUDConfig.GAUGE_TARGET_SHIELD,
		"player_shield": HUDConfig.GAUGE_PLAYER_SHIELD,
		"afterburner": HUDConfig.GAUGE_AFTERBURNER,
		"weapon_energy": HUDConfig.GAUGE_WEAPON_ENERGY,
		"auto_speed": HUDConfig.GAUGE_AUTO_SPEED,
		"auto_target": HUDConfig.GAUGE_AUTO_TARGET,
		"cmeasure": HUDConfig.GAUGE_CMEASURE,
		"talking_head": HUDConfig.GAUGE_TALKING_HEAD,
		"damage": HUDConfig.GAUGE_DAMAGE,
		"message_lines": HUDConfig.GAUGE_MESSAGE_LINES,
		"radar": HUDConfig.GAUGE_RADAR,
		"escort": HUDConfig.GAUGE_ESCORT,
		"directives": HUDConfig.GAUGE_DIRECTIVES,
		"threat": HUDConfig.GAUGE_THREAT,
		"lead": HUDConfig.GAUGE_LEAD,
		"lock": HUDConfig.GAUGE_LOCK,
		"lead_sight": HUDConfig.GAUGE_LEAD_SIGHT,
		"orientation_tee": HUDConfig.GAUGE_ORIENTATION_TEE,
		"squadmsg": HUDConfig.GAUGE_SQUADMSG,
		"lag": HUDConfig.GAUGE_LAG,
		"mini_target_box": HUDConfig.GAUGE_MINI_TARGET_BOX,
		"offscreen": HUDConfig.GAUGE_OFFSCREEN,
		"brackets": HUDConfig.GAUGE_BRACKETS,
		"weapon_linking": HUDConfig.GAUGE_WEAPON_LINKING,
		"throttle": HUDConfig.GAUGE_THROTTLE,
		"radar_integrity": HUDConfig.GAUGE_RADAR_INTEGRITY,
		"countermeasures": HUDConfig.GAUGE_COUNTERMEASURES,
		"wingman_status": HUDConfig.GAUGE_WINGMAN_STATUS,
		"kill_gauge": HUDConfig.GAUGE_KILL_GAUGE,
		"text_warnings": HUDConfig.GAUGE_TEXT_WARNINGS,
		"center_reticle": HUDConfig.GAUGE_CENTER_RETICLE,
		"navigation": HUDConfig.GAUGE_NAVIGATION,
		"mission_time": HUDConfig.GAUGE_MISSION_TIME,
		"flight_path": HUDConfig.GAUGE_FLIGHT_PATH,
		"warhead_count": HUDConfig.GAUGE_WARHEAD_COUNT,
		"support_view": HUDConfig.GAUGE_SUPPORT_VIEW
	}

## Setup visibility groups for batch operations
func _setup_visibility_groups() -> void:
	default_visibility_groups = {
		"essential": {
			"name": "Essential HUD",
			"description": "Core elements needed for basic gameplay",
			"elements": ["speed", "target_box", "player_shield", "weapons", "radar"]
		},
		"combat": {
			"name": "Combat Elements",
			"description": "Elements focused on combat situations",
			"elements": ["target_box", "target_shield", "weapons", "weapon_energy", "cmeasure", "damage", "threat", "lead", "lock", "brackets"]
		},
		"navigation": {
			"name": "Navigation Elements", 
			"description": "Elements for navigation and exploration",
			"elements": ["speed", "auto_speed", "auto_target", "objectives", "radar", "escort", "directives", "orientation_tee", "navigation"]
		},
		"communication": {
			"name": "Communication Elements",
			"description": "Message and communication displays",
			"elements": ["talking_head", "message_lines", "squadmsg", "directives"]
		},
		"targeting": {
			"name": "Targeting Systems",
			"description": "All targeting and lock-on related elements",
			"elements": ["target_box", "target_shield", "lead", "lock", "lead_sight", "brackets", "center_reticle"]
		},
		"status": {
			"name": "Ship Status",
			"description": "Player ship status and damage indicators",
			"elements": ["player_shield", "afterburner", "weapon_energy", "damage", "throttle", "radar_integrity"]
		},
		"tactical": {
			"name": "Tactical Displays",
			"description": "Advanced tactical information",
			"elements": ["threat", "escort", "wingman_status", "offscreen", "mini_target_box", "kill_gauge"]
		},
		"advanced": {
			"name": "Advanced Features",
			"description": "Advanced and optional HUD elements",
			"elements": ["lag", "weapon_linking", "text_warnings", "mission_time", "flight_path", "warhead_count", "support_view"]
		}
	}
	
	# Copy to working groups
	visibility_groups = default_visibility_groups.duplicate(true)

## Load default visibility settings
func _load_default_visibility() -> void:
	current_visibility_flags = HUDConfig.DEFAULT_FLAGS
	element_visibility_overrides.clear()

## Set element visibility
func set_element_visibility(element_id: String, visible: bool) -> void:
	if not element_flag_mapping.has(element_id):
		print("HUDElementVisibilityManager: Warning - Unknown element: %s" % element_id)
		return
	
	var flag_bit = element_flag_mapping[element_id]
	var was_visible = (current_visibility_flags & flag_bit) != 0
	
	if visible:
		current_visibility_flags |= flag_bit
	else:
		current_visibility_flags &= ~flag_bit
	
	# Store override if different from default
	var default_visible = (HUDConfig.DEFAULT_FLAGS & flag_bit) != 0
	if visible != default_visible:
		element_visibility_overrides[element_id] = visible
	else:
		element_visibility_overrides.erase(element_id)
	
	# Emit signal if visibility actually changed
	if visible != was_visible:
		element_visibility_changed.emit(element_id, visible)
		visibility_flags_updated.emit(current_visibility_flags)
		print("HUDElementVisibilityManager: Element '%s' visibility: %s" % [element_id, str(visible)])

## Get element visibility
func is_element_visible(element_id: String) -> bool:
	if not element_flag_mapping.has(element_id):
		return false
	
	var flag_bit = element_flag_mapping[element_id]
	return (current_visibility_flags & flag_bit) != 0

## Apply visibility flags
func apply_visibility_flags(flags: int) -> void:
	var old_flags = current_visibility_flags
	current_visibility_flags = flags
	
	# Clear overrides and rebuild them
	element_visibility_overrides.clear()
	
	# Check each element for overrides
	for element_id in element_flag_mapping:
		var flag_bit = element_flag_mapping[element_id]
		var current_visible = (flags & flag_bit) != 0
		var default_visible = (HUDConfig.DEFAULT_FLAGS & flag_bit) != 0
		
		if current_visible != default_visible:
			element_visibility_overrides[element_id] = current_visible
		
		# Emit change signal if visibility changed
		var was_visible = (old_flags & flag_bit) != 0
		if current_visible != was_visible:
			element_visibility_changed.emit(element_id, current_visible)
	
	visibility_flags_updated.emit(current_visibility_flags)
	print("HUDElementVisibilityManager: Applied visibility flags: 0x%08X" % flags)

## Get current visibility flags
func get_current_visibility_flags() -> int:
	return current_visibility_flags

## Set visibility group
func set_visibility_group(group_name: String, visible: bool) -> void:
	if not visibility_groups.has(group_name):
		print("HUDElementVisibilityManager: Error - Unknown visibility group: %s" % group_name)
		return
	
	var group_data = visibility_groups[group_name]
	var elements = group_data.get("elements", [])
	
	for element_id in elements:
		set_element_visibility(element_id, visible)
	
	visibility_group_changed.emit(group_name, visible)
	print("HUDElementVisibilityManager: Group '%s' visibility: %s (%d elements)" % [group_name, str(visible), elements.size()])

## Check if all elements in group are visible
func is_visibility_group_visible(group_name: String) -> bool:
	if not visibility_groups.has(group_name):
		return false
	
	var group_data = visibility_groups[group_name]
	var elements = group_data.get("elements", [])
	
	for element_id in elements:
		if not is_element_visible(element_id):
			return false
	
	return true

## Check if any elements in group are visible
func is_visibility_group_partially_visible(group_name: String) -> bool:
	if not visibility_groups.has(group_name):
		return false
	
	var group_data = visibility_groups[group_name]
	var elements = group_data.get("elements", [])
	
	for element_id in elements:
		if is_element_visible(element_id):
			return true
	
	return false

## Get visibility group state
func get_visibility_group_state(group_name: String) -> Dictionary:
	if not visibility_groups.has(group_name):
		return {}
	
	var group_data = visibility_groups[group_name]
	var elements = group_data.get("elements", [])
	var visible_count = 0
	var element_states = {}
	
	for element_id in elements:
		var visible = is_element_visible(element_id)
		element_states[element_id] = visible
		if visible:
			visible_count += 1
	
	return {
		"group_name": group_name,
		"visible_count": visible_count,
		"total_count": elements.size(),
		"fully_visible": visible_count == elements.size(),
		"partially_visible": visible_count > 0,
		"element_states": element_states
	}

## Get all element visibility states
func get_all_element_states() -> Dictionary:
	var states = {}
	
	for element_id in element_flag_mapping:
		states[element_id] = is_element_visible(element_id)
	
	return states

## Get visible element count
func get_visible_element_count() -> int:
	var count = 0
	
	for element_id in element_flag_mapping:
		if is_element_visible(element_id):
			count += 1
	
	return count

## Get total element count
func get_total_element_count() -> int:
	return element_flag_mapping.size()

## Reset to default visibility
func reset_to_defaults() -> void:
	apply_visibility_flags(HUDConfig.DEFAULT_FLAGS)
	print("HUDElementVisibilityManager: Reset to default visibility")

## Enable only essential elements
func enable_minimal_mode() -> void:
	set_visibility_group("essential", true)
	
	# Disable all non-essential elements
	for element_id in element_flag_mapping:
		if not _is_element_in_group(element_id, "essential"):
			set_element_visibility(element_id, false)
	
	print("HUDElementVisibilityManager: Enabled minimal mode")

## Enable observer mode (minimal for spectating)
func enable_observer_mode() -> void:
	# Start with all off
	apply_visibility_flags(0)
	
	# Enable specific observer elements
	var observer_elements = ["target_box", "target_shield", "objectives", "message_lines", "radar", "escort"]
	for element_id in observer_elements:
		set_element_visibility(element_id, true)
	
	print("HUDElementVisibilityManager: Enabled observer mode")

## Enable combat mode (combat focused elements)
func enable_combat_mode() -> void:
	# Enable essential and combat groups
	set_visibility_group("essential", true)
	set_visibility_group("combat", true)
	set_visibility_group("targeting", true)
	
	# Disable non-combat elements
	var non_combat_elements = ["talking_head", "squadmsg", "directives", "navigation", "mission_time"]
	for element_id in non_combat_elements:
		set_element_visibility(element_id, false)
	
	print("HUDElementVisibilityManager: Enabled combat mode")

## Check if element is in group
func _is_element_in_group(element_id: String, group_name: String) -> bool:
	if not visibility_groups.has(group_name):
		return false
	
	var group_data = visibility_groups[group_name]
	var elements = group_data.get("elements", [])
	return elements.has(element_id)

## Get elements by visibility
func get_visible_elements() -> Array[String]:
	var visible_elements: Array[String] = []
	
	for element_id in element_flag_mapping:
		if is_element_visible(element_id):
			visible_elements.append(element_id)
	
	return visible_elements

## Get elements by visibility
func get_hidden_elements() -> Array[String]:
	var hidden_elements: Array[String] = []
	
	for element_id in element_flag_mapping:
		if not is_element_visible(element_id):
			hidden_elements.append(element_id)
	
	return hidden_elements

## Get element information
func get_element_info(element_id: String) -> Dictionary:
	if not element_flag_mapping.has(element_id):
		return {}
	
	var flag_bit = element_flag_mapping[element_id]
	var is_visible = is_element_visible(element_id)
	var is_default = (HUDConfig.DEFAULT_FLAGS & flag_bit) != 0
	var is_overridden = element_visibility_overrides.has(element_id)
	
	# Find which groups contain this element
	var groups: Array[String] = []
	for group_name in visibility_groups:
		if _is_element_in_group(element_id, group_name):
			groups.append(group_name)
	
	return {
		"element_id": element_id,
		"visible": is_visible,
		"default_visible": is_default,
		"overridden": is_overridden,
		"flag_bit": flag_bit,
		"groups": groups
	}

## Get visibility groups info
func get_visibility_groups() -> Dictionary:
	return visibility_groups.duplicate(true)

## Get available element IDs
func get_available_elements() -> Array[String]:
	var elements: Array[String] = []
	for element_id in element_flag_mapping.keys():
		elements.append(element_id)
	return elements

## Create custom visibility group
func create_custom_group(group_name: String, elements: Array[String], description: String = "") -> bool:
	if group_name.is_empty():
		print("HUDElementVisibilityManager: Error - Empty group name")
		return false
	
	# Validate elements exist
	for element_id in elements:
		if not element_flag_mapping.has(element_id):
			print("HUDElementVisibilityManager: Error - Unknown element in group: %s" % element_id)
			return false
	
	visibility_groups[group_name] = {
		"name": group_name.capitalize(),
		"description": description if not description.is_empty() else "Custom visibility group",
		"elements": elements,
		"custom": true
	}
	
	print("HUDElementVisibilityManager: Created custom group '%s' with %d elements" % [group_name, elements.size()])
	return true

## Remove custom visibility group
func remove_custom_group(group_name: String) -> bool:
	if not visibility_groups.has(group_name):
		print("HUDElementVisibilityManager: Error - Group not found: %s" % group_name)
		return false
	
	var group_data = visibility_groups[group_name]
	if not group_data.get("custom", false):
		print("HUDElementVisibilityManager: Error - Cannot remove system group: %s" % group_name)
		return false
	
	visibility_groups.erase(group_name)
	print("HUDElementVisibilityManager: Removed custom group: %s" % group_name)
	return true

## Toggle element visibility
func toggle_element_visibility(element_id: String) -> bool:
	var current_state = is_element_visible(element_id)
	set_element_visibility(element_id, not current_state)
	return not current_state

## Toggle group visibility
func toggle_group_visibility(group_name: String) -> bool:
	var current_state = is_visibility_group_visible(group_name)
	set_visibility_group(group_name, not current_state)
	return not current_state

## Get visibility summary
func get_visibility_summary() -> Dictionary:
	var visible_count = get_visible_element_count()
	var total_count = get_total_element_count()
	var override_count = element_visibility_overrides.size()
	
	var group_states = {}
	for group_name in visibility_groups:
		group_states[group_name] = get_visibility_group_state(group_name)
	
	return {
		"visible_elements": visible_count,
		"total_elements": total_count,
		"visibility_percentage": (float(visible_count) / float(total_count)) * 100.0,
		"overrides_count": override_count,
		"current_flags": current_visibility_flags,
		"default_flags": HUDConfig.DEFAULT_FLAGS,
		"group_states": group_states
	}

## Apply preset visibility profile
func apply_preset_profile(profile_name: String) -> bool:
	match profile_name:
		"default":
			reset_to_defaults()
		"minimal":
			enable_minimal_mode()
		"observer":
			enable_observer_mode()
		"combat":
			enable_combat_mode()
		_:
			print("HUDElementVisibilityManager: Error - Unknown preset profile: %s" % profile_name)
			return false
	
	return true

## Export visibility configuration
func export_visibility_config() -> Dictionary:
	return {
		"visibility_flags": current_visibility_flags,
		"element_overrides": element_visibility_overrides.duplicate(),
		"custom_groups": _get_custom_groups()
	}

## Import visibility configuration
func import_visibility_config(config: Dictionary) -> bool:
	if not config.has("visibility_flags"):
		print("HUDElementVisibilityManager: Error - Invalid config format")
		return false
	
	# Apply visibility flags
	apply_visibility_flags(config.visibility_flags)
	
	# Apply element overrides
	if config.has("element_overrides"):
		element_visibility_overrides = config.element_overrides.duplicate()
	
	# Apply custom groups
	if config.has("custom_groups"):
		var custom_groups = config.custom_groups
		for group_name in custom_groups:
			var group_data = custom_groups[group_name]
			if group_data.has("elements"):
				create_custom_group(group_name, group_data.elements, group_data.get("description", ""))
	
	print("HUDElementVisibilityManager: Imported visibility configuration")
	return true

## Get custom groups only
func _get_custom_groups() -> Dictionary:
	var custom_groups = {}
	
	for group_name in visibility_groups:
		var group_data = visibility_groups[group_name]
		if group_data.get("custom", false):
			custom_groups[group_name] = group_data
	
	return custom_groups