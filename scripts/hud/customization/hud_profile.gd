class_name HUDProfile
extends Resource

## EPIC-012 HUD-016: HUD Profile Data Structure
## Stores complete HUD configuration profile including element configurations,
## global settings, and visibility rules for comprehensive customization

# Profile metadata
var profile_name: String
var profile_description: String
var creation_date: String
var last_modified: String
var profile_version: String = "1.0.0"

# Element configurations
var element_configurations: Dictionary = {}  # element_id -> ElementConfiguration
var global_settings: GlobalHUDSettings
var visibility_rules: Array[VisibilityRule] = []

# Profile settings and metadata
var author: String = ""
var tags: Array[String] = []
var is_default: bool = false
var is_readonly: bool = false

func _init():
	# Initialize with default global settings if not provided
	if not global_settings:
		global_settings = GlobalHUDSettings.new()

## Add element configuration to profile
func add_element_configuration(element_id: String, config: ElementConfiguration) -> void:
	element_configurations[element_id] = config

## Remove element configuration from profile
func remove_element_configuration(element_id: String) -> void:
	element_configurations.erase(element_id)

## Get element configuration
func get_element_configuration(element_id: String) -> ElementConfiguration:
	return element_configurations.get(element_id)

## Check if element has configuration
func has_element_configuration(element_id: String) -> bool:
	return element_configurations.has(element_id)

## Get all configured element IDs
func get_configured_elements() -> Array[String]:
	var ids: Array[String] = []
	for id in element_configurations.keys():
		ids.append(id)
	return ids

## Add visibility rule
func add_visibility_rule(rule: VisibilityRule) -> void:
	visibility_rules.append(rule)

## Remove visibility rule
func remove_visibility_rule(rule_index: int) -> void:
	if rule_index >= 0 and rule_index < visibility_rules.size():
		visibility_rules.remove_at(rule_index)

## Create a duplicate of this profile
func duplicate_profile(new_name: String = "") -> HUDProfile:
	var new_profile = HUDProfile.new()
	
	# Copy metadata
	new_profile.profile_name = new_name if not new_name.is_empty() else profile_name + "_copy"
	new_profile.profile_description = profile_description
	new_profile.creation_date = Time.get_datetime_string_from_system()
	new_profile.last_modified = new_profile.creation_date
	new_profile.profile_version = profile_version
	new_profile.author = author
	new_profile.tags = tags.duplicate()
	new_profile.is_default = false
	new_profile.is_readonly = false
	
	# Copy global settings
	new_profile.global_settings = global_settings.duplicate() if global_settings else GlobalHUDSettings.new()
	
	# Copy element configurations
	for element_id in element_configurations:
		var config = element_configurations[element_id]
		new_profile.element_configurations[element_id] = config.duplicate() if config else null
	
	# Copy visibility rules
	for rule in visibility_rules:
		new_profile.visibility_rules.append(rule.duplicate() if rule else null)
	
	return new_profile

## Validate profile data integrity
func validate_profile() -> Dictionary:
	var result = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	# Check required fields
	if profile_name.is_empty():
		result.errors.append("Profile name cannot be empty")
		result.is_valid = false
	
	if not global_settings:
		result.errors.append("Global settings are required")
		result.is_valid = false
	
	# Validate element configurations
	for element_id in element_configurations:
		var config = element_configurations[element_id]
		if not config:
			result.warnings.append("Null configuration for element: " + element_id)
			continue
		
		var config_validation = config.validate_configuration()
		if not config_validation.is_valid:
			result.errors.append("Invalid configuration for element %s: %s" % [element_id, str(config_validation.errors)])
			result.is_valid = false
	
	# Validate visibility rules
	for i in range(visibility_rules.size()):
		var rule = visibility_rules[i]
		if not rule:
			result.warnings.append("Null visibility rule at index: " + str(i))
			continue
		
		var rule_validation = rule.validate_rule()
		if not rule_validation.is_valid:
			result.errors.append("Invalid visibility rule at index %d: %s" % [i, str(rule_validation.errors)])
			result.is_valid = false
	
	return result

## Get profile summary for display
func get_profile_summary() -> Dictionary:
	return {
		"name": profile_name,
		"description": profile_description,
		"author": author,
		"creation_date": creation_date,
		"last_modified": last_modified,
		"version": profile_version,
		"element_count": element_configurations.size(),
		"visibility_rules_count": visibility_rules.size(),
		"tags": tags,
		"is_default": is_default,
		"is_readonly": is_readonly
	}