class_name VisibilityManager
extends RefCounted

## EPIC-012 HUD-016: Visibility Management System
## Manages individual element visibility controls and information density management

signal visibility_changed(element_id: String, visible: bool)
signal density_level_changed(level: String)
signal visibility_rule_triggered(rule: VisibilityRule, elements: Array[String])

# Visibility state management
var element_visibility: Dictionary = {}  # element_id -> bool
var element_groups: Dictionary = {}  # group_name -> Array[String]
var visibility_rules: Array[VisibilityRule] = []
var conditional_visibility: Dictionary = {}  # element_id -> VisibilityRule

# Information density management
var current_density_level: String = "standard"
var density_configurations: Dictionary = {}
var density_presets: Dictionary = {}

# Quick preset system
var visibility_presets: Dictionary = {}  # preset_name -> Dictionary
var active_preset: String = ""

# Rule evaluation context
var evaluation_context: Dictionary = {}
var context_providers: Dictionary = {}  # context_type -> Node
var rule_evaluation_enabled: bool = true

# Performance optimization
var update_frequency: float = 10.0  # Hz
var last_update_time: float = 0.0
var dirty_rules: Array[VisibilityRule] = []
var batch_updates: bool = true

func _init():
	_initialize_default_presets()
	_initialize_density_configurations()

## Initialize visibility manager
func initialize_visibility_manager() -> void:
	_setup_context_providers()
	_load_visibility_rules()
	print("VisibilityManager: Initialized with %d elements and %d rules" % [element_visibility.size(), visibility_rules.size()])

## Register HUD element for visibility management
func register_element(element_id: String, element: HUDElementBase, initial_visible: bool = true) -> void:
	element_visibility[element_id] = initial_visible
	
	# Apply current density level visibility
	var density_config = density_configurations.get(current_density_level, {})
	if density_config.has(element_id):
		element_visibility[element_id] = density_config[element_id]
	
	# Apply element to appropriate groups
	_assign_element_to_groups(element_id, element)
	
	print("VisibilityManager: Registered element '%s' with visibility %s" % [element_id, str(initial_visible)])

## Unregister HUD element
func unregister_element(element_id: String) -> void:
	element_visibility.erase(element_id)
	conditional_visibility.erase(element_id)
	
	# Remove from groups
	for group_name in element_groups:
		var group = element_groups[group_name]
		var index = group.find(element_id)
		if index >= 0:
			group.remove_at(index)
	
	print("VisibilityManager: Unregistered element '%s'" % element_id)

## Set element visibility
func set_element_visibility(element_id: String, visible: bool, reason: String = "") -> void:
	if not element_visibility.has(element_id):
		push_warning("VisibilityManager: Unknown element '%s'" % element_id)
		return
	
	var old_visible = element_visibility[element_id]
	if old_visible == visible:
		return
	
	element_visibility[element_id] = visible
	visibility_changed.emit(element_id, visible)
	
	print("VisibilityManager: Element '%s' visibility changed to %s (%s)" % [element_id, str(visible), reason])

## Get element visibility
func get_element_visibility(element_id: String) -> bool:
	return element_visibility.get(element_id, false)

## Set group visibility
func set_group_visibility(group_name: String, visible: bool, reason: String = "") -> void:
	var group = element_groups.get(group_name, [])
	if group.is_empty():
		push_warning("VisibilityManager: Unknown group '%s'" % group_name)
		return
	
	for element_id in group:
		set_element_visibility(element_id, visible, "group:%s" % group_name)
	
	print("VisibilityManager: Group '%s' visibility changed to %s (%s)" % [group_name, str(visible), reason])

## Set information density level
func set_information_density(level: String) -> void:
	if not density_configurations.has(level):
		push_error("VisibilityManager: Unknown density level '%s'" % level)
		return
	
	var old_level = current_density_level
	current_density_level = level
	
	# Apply density configuration
	var density_config = density_configurations[level]
	for element_id in density_config:
		set_element_visibility(element_id, density_config[element_id], "density:%s" % level)
	
	density_level_changed.emit(level)
	print("VisibilityManager: Information density changed from '%s' to '%s'" % [old_level, level])

## Get current information density level
func get_information_density() -> String:
	return current_density_level

## Apply visibility preset
func apply_visibility_preset(preset_name: String) -> void:
	var preset = visibility_presets.get(preset_name)
	if not preset:
		push_error("VisibilityManager: Unknown visibility preset '%s'" % preset_name)
		return
	
	active_preset = preset_name
	
	for element_id in preset:
		set_element_visibility(element_id, preset[element_id], "preset:%s" % preset_name)
	
	print("VisibilityManager: Applied visibility preset '%s'" % preset_name)

## Create custom visibility preset
func create_visibility_preset(preset_name: String, description: String = "") -> void:
	var preset = element_visibility.duplicate()
	visibility_presets[preset_name] = preset
	
	print("VisibilityManager: Created visibility preset '%s' with %d elements" % [preset_name, preset.size()])

## Delete visibility preset
func delete_visibility_preset(preset_name: String) -> bool:
	if not visibility_presets.has(preset_name):
		return false
	
	visibility_presets.erase(preset_name)
	if active_preset == preset_name:
		active_preset = ""
	
	print("VisibilityManager: Deleted visibility preset '%s'" % preset_name)
	return true

## Add visibility rule
func add_visibility_rule(rule: VisibilityRule) -> void:
	if not rule:
		push_error("VisibilityManager: Cannot add null visibility rule")
		return
	
	visibility_rules.append(rule)
	
	# Assign conditional visibility for targeted elements
	for element_id in rule.target_elements:
		conditional_visibility[element_id] = rule
	
	print("VisibilityManager: Added visibility rule '%s' targeting %d elements" % [rule.rule_name, rule.target_elements.size()])

## Remove visibility rule
func remove_visibility_rule(rule: VisibilityRule) -> bool:
	var index = visibility_rules.find(rule)
	if index < 0:
		return false
	
	visibility_rules.remove_at(index)
	
	# Remove conditional visibility assignments
	for element_id in rule.target_elements:
		if conditional_visibility.get(element_id) == rule:
			conditional_visibility.erase(element_id)
	
	print("VisibilityManager: Removed visibility rule '%s'" % rule.rule_name)
	return true

## Update visibility rules based on current context
func update_visibility_rules(context: Dictionary = {}) -> void:
	if not rule_evaluation_enabled:
		return
	
	# Update evaluation context
	evaluation_context.merge(context, true)
	
	# Collect context from providers
	for context_type in context_providers:
		var provider = context_providers[context_type]
		if is_instance_valid(provider) and provider.has_method("get_context_data"):
			var provider_context = provider.get_context_data()
			evaluation_context[context_type] = provider_context
	
	# Evaluate rules by priority (higher priority first)
	var sorted_rules = visibility_rules.duplicate()
	sorted_rules.sort_custom(func(a, b): return a.rule_priority > b.rule_priority)
	
	var triggered_rules: Array[VisibilityRule] = []
	
	for rule in sorted_rules:
		if not rule.is_active:
			continue
		
		var rule_result = rule.evaluate_condition(evaluation_context)
		if rule_result and rule.last_evaluation != rule_result:
			# Rule triggered
			var elements_dict = {}
			for element_id in rule.target_elements:
				if element_visibility.has(element_id):
					elements_dict[element_id] = true  # Placeholder for element reference
			
			if rule.apply_rule(elements_dict, evaluation_context):
				triggered_rules.append(rule)
				
				# Apply rule effects directly
				for element_id in rule.target_elements:
					if element_visibility.has(element_id):
						var action_value = rule.action_value if rule.action_type == "visibility" else true
						set_element_visibility(element_id, action_value, "rule:%s" % rule.rule_name)
	
	# Emit signal for triggered rules
	if not triggered_rules.is_empty():
		for rule in triggered_rules:
			visibility_rule_triggered.emit(rule, rule.target_elements)

## Create element group
func create_element_group(group_name: String, element_ids: Array[String], description: String = "") -> void:
	element_groups[group_name] = element_ids.duplicate()
	print("VisibilityManager: Created element group '%s' with %d elements" % [group_name, element_ids.size()])

## Add element to group
func add_element_to_group(group_name: String, element_id: String) -> void:
	if not element_groups.has(group_name):
		element_groups[group_name] = []
	
	var group = element_groups[group_name]
	if not group.has(element_id):
		group.append(element_id)
		print("VisibilityManager: Added element '%s' to group '%s'" % [element_id, group_name])

## Remove element from group
func remove_element_from_group(group_name: String, element_id: String) -> void:
	var group = element_groups.get(group_name, [])
	var index = group.find(element_id)
	if index >= 0:
		group.remove_at(index)
		print("VisibilityManager: Removed element '%s' from group '%s'" % [element_id, group_name])

## Get elements in group
func get_group_elements(group_name: String) -> Array[String]:
	return element_groups.get(group_name, [])

## Register context provider
func register_context_provider(context_type: String, provider: Node) -> void:
	context_providers[context_type] = provider
	print("VisibilityManager: Registered context provider for '%s'" % context_type)

## Unregister context provider
func unregister_context_provider(context_type: String) -> void:
	context_providers.erase(context_type)
	print("VisibilityManager: Unregistered context provider for '%s'" % context_type)

## Update visibility system (called periodically)
func update_visibility(delta: float) -> void:
	var current_time = Time.get_unix_time_from_system()
	
	# Limit update frequency for performance
	if current_time - last_update_time < 1.0 / update_frequency:
		return
	
	last_update_time = current_time
	
	# Update visibility rules if context providers exist
	if not context_providers.is_empty():
		update_visibility_rules()

## Enable/disable rule evaluation
func set_rule_evaluation_enabled(enabled: bool) -> void:
	rule_evaluation_enabled = enabled
	print("VisibilityManager: Rule evaluation %s" % ("enabled" if enabled else "disabled"))

## Get visibility statistics
func get_visibility_statistics() -> Dictionary:
	var visible_count = 0
	var hidden_count = 0
	
	for element_id in element_visibility:
		if element_visibility[element_id]:
			visible_count += 1
		else:
			hidden_count += 1
	
	return {
		"total_elements": element_visibility.size(),
		"visible_elements": visible_count,
		"hidden_elements": hidden_count,
		"active_rules": visibility_rules.size(),
		"element_groups": element_groups.size(),
		"current_density": current_density_level,
		"active_preset": active_preset
	}

## Export visibility configuration
func export_visibility_configuration() -> Dictionary:
	return {
		"element_visibility": element_visibility.duplicate(),
		"element_groups": element_groups.duplicate(),
		"current_density_level": current_density_level,
		"visibility_presets": visibility_presets.duplicate(),
		"active_preset": active_preset,
		"update_frequency": update_frequency
	}

## Import visibility configuration
func import_visibility_configuration(config: Dictionary) -> bool:
	if config.has("element_visibility"):
		element_visibility = config.element_visibility.duplicate()
	
	if config.has("element_groups"):
		element_groups = config.element_groups.duplicate()
	
	if config.has("current_density_level"):
		current_density_level = config.current_density_level
	
	if config.has("visibility_presets"):
		visibility_presets = config.visibility_presets.duplicate()
	
	if config.has("active_preset"):
		active_preset = config.active_preset
	
	if config.has("update_frequency"):
		update_frequency = config.update_frequency
	
	print("VisibilityManager: Successfully imported visibility configuration")
	return true

## Initialize default visibility presets
func _initialize_default_presets() -> void:
	# Minimal preset - only critical information
	visibility_presets["minimal"] = {
		"shield_display": true,
		"hull_display": true,
		"speed_display": true,
		"weapon_energy": true,
		"target_info": true,
		"threat_warning": true
	}
	
	# Standard preset - normal gameplay
	visibility_presets["standard"] = {
		"shield_display": true,
		"hull_display": true,
		"speed_display": true,
		"weapon_energy": true,
		"target_info": true,
		"threat_warning": true,
		"subsystem_status": true,
		"radar_display": true,
		"communication_panel": false,
		"detailed_targeting": false
	}
	
	# Detailed preset - maximum information
	visibility_presets["detailed"] = {
		"shield_display": true,
		"hull_display": true,
		"speed_display": true,
		"weapon_energy": true,
		"target_info": true,
		"threat_warning": true,
		"subsystem_status": true,
		"radar_display": true,
		"communication_panel": true,
		"detailed_targeting": true,
		"performance_monitor": true,
		"debug_overlay": false
	}
	
	# Combat preset - optimized for combat scenarios
	visibility_presets["combat"] = {
		"shield_display": true,
		"hull_display": true,
		"weapon_energy": true,
		"target_info": true,
		"threat_warning": true,
		"targeting_reticle": true,
		"weapon_lock": true,
		"detailed_targeting": true,
		"communication_panel": false,
		"navigation_display": false
	}

## Initialize information density configurations
func _initialize_density_configurations() -> void:
	# Minimal density - essential information only
	density_configurations["minimal"] = {
		"shield_display": true,
		"hull_display": true,
		"speed_display": false,
		"weapon_energy": true,
		"target_info": true,
		"threat_warning": true,
		"subsystem_status": false,
		"radar_display": false,
		"communication_panel": false,
		"detailed_targeting": false,
		"navigation_display": false,
		"performance_monitor": false
	}
	
	# Standard density - normal information level
	density_configurations["standard"] = {
		"shield_display": true,
		"hull_display": true,
		"speed_display": true,
		"weapon_energy": true,
		"target_info": true,
		"threat_warning": true,
		"subsystem_status": true,
		"radar_display": true,
		"communication_panel": false,
		"detailed_targeting": false,
		"navigation_display": true,
		"performance_monitor": false
	}
	
	# Detailed density - comprehensive information
	density_configurations["detailed"] = {
		"shield_display": true,
		"hull_display": true,
		"speed_display": true,
		"weapon_energy": true,
		"target_info": true,
		"threat_warning": true,
		"subsystem_status": true,
		"radar_display": true,
		"communication_panel": true,
		"detailed_targeting": true,
		"navigation_display": true,
		"performance_monitor": false
	}
	
	# Comprehensive density - all information visible
	density_configurations["comprehensive"] = {
		"shield_display": true,
		"hull_display": true,
		"speed_display": true,
		"weapon_energy": true,
		"target_info": true,
		"threat_warning": true,
		"subsystem_status": true,
		"radar_display": true,
		"communication_panel": true,
		"detailed_targeting": true,
		"navigation_display": true,
		"performance_monitor": true,
		"debug_overlay": true
	}

## Setup context providers for rule evaluation
func _setup_context_providers() -> void:
	# Context providers would be registered by the main HUD system
	# This is a placeholder for the initialization process
	pass

## Load default visibility rules
func _load_visibility_rules() -> void:
	# Create some default visibility rules
	
	# Combat visibility rule
	var combat_rule = VisibilityRule.create_combat_state_rule(
		"combat_hud_enhancement",
		true,
		["targeting_reticle", "weapon_lock", "threat_warning", "detailed_targeting"],
		true
	)
	combat_rule.rule_priority = 100
	add_visibility_rule(combat_rule)
	
	# Mission phase rules
	var briefing_rule = VisibilityRule.create_mission_phase_rule(
		"briefing_mode",
		"briefing",
		["communication_panel", "navigation_display"],
		true
	)
	briefing_rule.rule_priority = 90
	add_visibility_rule(briefing_rule)
	
	# Ship system rules
	var weapons_offline_rule = VisibilityRule.create_ship_system_rule(
		"weapons_offline",
		"weapons",
		false,
		["weapon_energy", "targeting_reticle", "weapon_lock"],
		false
	)
	weapons_offline_rule.rule_priority = 80
	add_visibility_rule(weapons_offline_rule)

## Assign element to appropriate groups based on type and characteristics
func _assign_element_to_groups(element_id: String, element: HUDElementBase) -> void:
	# Critical group - essential elements always visible
	if element_id in ["shield_display", "hull_display", "threat_warning"]:
		add_element_to_group("critical", element_id)
	
	# Combat group - combat-related elements
	if element_id in ["weapon_energy", "targeting_reticle", "weapon_lock", "detailed_targeting"]:
		add_element_to_group("combat", element_id)
	
	# Navigation group - navigation and movement elements
	if element_id in ["speed_display", "navigation_display", "radar_display"]:
		add_element_to_group("navigation", element_id)
	
	# Information group - detailed information displays
	if element_id in ["subsystem_status", "target_info", "communication_panel"]:
		add_element_to_group("information", element_id)
	
	# Debug group - development and debugging elements
	if element_id in ["performance_monitor", "debug_overlay"]:
		add_element_to_group("debug", element_id)