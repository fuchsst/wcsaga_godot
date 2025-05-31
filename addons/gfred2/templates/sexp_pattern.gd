@tool
class_name SexpPattern
extends Resource

## SEXP pattern library entry for common scripting solutions.
## Provides reusable SEXP expressions (addons/sexp) with parameters and validation.

signal pattern_modified()

enum PatternCategory {
	TRIGGER,
	ACTION,
	CONDITION,
	OBJECTIVE,
	AI_BEHAVIOR,
	EVENT_SEQUENCE,
	VARIABLE_MANAGEMENT,
	SHIP_CONTROL,
	MISSION_FLOW,
	CUSTOM
}

enum ComplexityLevel {
	BASIC,
	INTERMEDIATE,
	ADVANCED,
	EXPERT
}

# Pattern metadata
@export var pattern_id: String = ""
@export var pattern_name: String = ""
@export var category: PatternCategory = PatternCategory.CUSTOM
@export var description: String = ""
@export var usage_notes: String = ""
@export var author: String = ""
@export var version: String = "1.0.0"
@export var complexity: ComplexityLevel = ComplexityLevel.BASIC

# Pattern content
@export var sexp_expression: String = ""
@export var parameter_placeholders: Dictionary = {}
@export var example_usage: String = ""

# Pattern requirements
@export var required_functions: Array[String] = []
@export var required_variables: Array[String] = []
@export var required_ship_types: Array[String] = []

# Community features
@export var tags: Array[String] = []
@export var is_community_pattern: bool = false
@export var rating: float = 0.0
@export var usage_count: int = 0
@export var created_date: String = ""

func _init() -> void:
	pattern_id = _generate_unique_id()
	created_date = Time.get_datetime_string_from_system()

func _generate_unique_id() -> String:
	return "pattern_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 10000)

## Applies pattern with parameter substitution
func apply_pattern(parameters: Dictionary = {}) -> String:
	var result: String = sexp_expression
	
	# Substitute parameters in the expression
	for placeholder in parameter_placeholders.keys():
		var param_name: String = placeholder
		var default_value: String = parameter_placeholders[placeholder].get("default", "")
		var actual_value: String = parameters.get(param_name, default_value)
		
		# Replace placeholder in expression
		result = result.replace("{" + param_name + "}", actual_value)
	
	return result

## Validates pattern requirements against current systems
func validate_pattern() -> Array[String]:
	var errors: Array[String] = []
	
	# Check basic pattern data
	if pattern_name.is_empty():
		errors.append("Pattern name is required")
	if sexp_expression.is_empty():
		errors.append("SEXP expression is required")
	
	# Validate SEXP syntax
	var syntax_valid: bool = SexpManager.validate_syntax(sexp_expression)
	if not syntax_valid:
		var syntax_errors: Array[String] = SexpManager.get_validation_errors(sexp_expression)
		errors.append("SEXP syntax validation failed:")
		errors.append_array(syntax_errors)
	
	# Check required functions
	for function_name in required_functions:
		if not SexpManager.function_exists(function_name):
			errors.append("Required function not available: " + function_name)
	
	# Check parameter placeholders are valid
	for placeholder in parameter_placeholders.keys():
		if not sexp_expression.contains("{" + placeholder + "}"):
			errors.append("Parameter placeholder '" + placeholder + "' not found in expression")
	
	return errors

## Gets parameter definitions for UI generation
func get_parameter_definitions() -> Dictionary:
	var param_defs: Dictionary = {}
	
	for param_name in parameter_placeholders.keys():
		var param_info: Dictionary = parameter_placeholders[param_name]
		param_defs[param_name] = {
			"type": param_info.get("type", "string"),
			"default": param_info.get("default", ""),
			"description": param_info.get("description", ""),
			"options": param_info.get("options", []),
			"min": param_info.get("min", 0),
			"max": param_info.get("max", 100)
		}
	
	return param_defs

## Creates pattern with validation and examples for common scenarios
static func create_escort_trigger_pattern() -> SexpPattern:
	var pattern: SexpPattern = SexpPattern.new()
	pattern.pattern_name = "Escort Ship Destroyed Trigger"
	pattern.category = PatternCategory.TRIGGER
	pattern.description = "Triggers when an escort target is destroyed"
	pattern.complexity = ComplexityLevel.BASIC
	
	pattern.sexp_expression = "(is-destroyed-delay 0 \"{escort_ship}\")"
	pattern.parameter_placeholders = {
		"escort_ship": {
			"type": "string",
			"default": "Convoy 1",
			"description": "Name of the ship being escorted"
		}
	}
	pattern.example_usage = "Use in mission events to trigger failure condition when escort target dies"
	pattern.required_functions = ["is-destroyed-delay"]
	pattern.tags = ["escort", "trigger", "ship-death"]
	
	return pattern

static func create_patrol_waypoint_pattern() -> SexpPattern:
	var pattern: SexpPattern = SexpPattern.new()
	pattern.pattern_name = "Patrol Waypoint Sequence"
	pattern.category = PatternCategory.AI_BEHAVIOR
	pattern.description = "Makes a ship patrol through waypoints in sequence"
	pattern.complexity = ComplexityLevel.INTERMEDIATE
	
	pattern.sexp_expression = "(and (waypoints-done \"{patrol_ship}\" \"{waypoint_path}\") (ai-dock \"{patrol_ship}\" \"{patrol_ship}\" \"{dock_type}\"))"
	pattern.parameter_placeholders = {
		"patrol_ship": {
			"type": "string",
			"default": "Patrol 1",
			"description": "Name of the patrolling ship"
		},
		"waypoint_path": {
			"type": "string", 
			"default": "Patrol Path 1",
			"description": "Name of the waypoint path to follow"
		},
		"dock_type": {
			"type": "string",
			"default": "dock",
			"description": "Type of docking behavior"
		}
	}
	pattern.required_functions = ["waypoints-done", "ai-dock"]
	pattern.tags = ["patrol", "waypoints", "ai"]
	
	return pattern

static func create_objective_complete_pattern() -> SexpPattern:
	var pattern: SexpPattern = SexpPattern.new()
	pattern.pattern_name = "Primary Objective Complete"
	pattern.category = PatternCategory.OBJECTIVE
	pattern.description = "Completes a primary mission objective"
	pattern.complexity = ComplexityLevel.BASIC
	
	pattern.sexp_expression = "(change-iff \"{target_ship}\" \"{new_team}\")"
	pattern.parameter_placeholders = {
		"target_ship": {
			"type": "string",
			"default": "Target 1",
			"description": "Ship to change allegiance"
		},
		"new_team": {
			"type": "string",
			"default": "friendly",
			"options": ["friendly", "hostile", "neutral", "unknown"],
			"description": "New team allegiance"
		}
	}
	pattern.required_functions = ["change-iff"]
	pattern.tags = ["objective", "team", "allegiance"]
	
	return pattern

static func create_difficulty_scaling_pattern() -> SexpPattern:
	var pattern: SexpPattern = SexpPattern.new()
	pattern.pattern_name = "Difficulty-Based Enemy Spawning"
	pattern.category = PatternCategory.MISSION_FLOW
	pattern.description = "Spawns different numbers of enemies based on difficulty"
	pattern.complexity = ComplexityLevel.ADVANCED
	
	pattern.sexp_expression = "(when (= (get-difficulty-level) {difficulty_level}) (ship-create \"{enemy_wing}\"))"
	pattern.parameter_placeholders = {
		"difficulty_level": {
			"type": "int",
			"default": 2,
			"min": 1,
			"max": 5,
			"description": "Difficulty level (1=Very Easy, 5=Insane)"
		},
		"enemy_wing": {
			"type": "string",
			"default": "Enemy Wing 1",
			"description": "Wing to spawn at this difficulty"
		}
	}
	pattern.required_functions = ["get-difficulty-level", "ship-create"]
	pattern.tags = ["difficulty", "spawning", "adaptive"]
	
	return pattern

static func create_timer_event_pattern() -> SexpPattern:
	var pattern: SexpPattern = SexpPattern.new()
	pattern.pattern_name = "Timed Mission Event"
	pattern.category = PatternCategory.EVENT_SEQUENCE
	pattern.description = "Triggers an event after a specified time delay"
	pattern.complexity = ComplexityLevel.BASIC
	
	pattern.sexp_expression = "(when (> (mission-time) {delay_seconds}) (send-message \"{sender}\" \"{message}\" \"{priority}\" \"{builtin}\"))"
	pattern.parameter_placeholders = {
		"delay_seconds": {
			"type": "int",
			"default": 30,
			"min": 1,
			"max": 600,
			"description": "Delay in seconds before event triggers"
		},
		"sender": {
			"type": "string",
			"default": "Command",
			"description": "Message sender name"
		},
		"message": {
			"type": "string",
			"default": "Timed event triggered",
			"description": "Message text to display"
		},
		"priority": {
			"type": "string",
			"default": "normal",
			"options": ["low", "normal", "high"],
			"description": "Message priority level"
		},
		"builtin": {
			"type": "string",
			"default": "none",
			"description": "Built-in message type"
		}
	}
	pattern.required_functions = ["mission-time", "send-message"]
	pattern.tags = ["timer", "message", "event"]
	
	return pattern

## Exports pattern for community sharing
func export_pattern() -> Dictionary:
	return {
		"pattern_id": pattern_id,
		"pattern_name": pattern_name,
		"category": category,
		"description": description,
		"usage_notes": usage_notes,
		"author": author,
		"version": version,
		"complexity": complexity,
		"sexp_expression": sexp_expression,
		"parameter_placeholders": parameter_placeholders,
		"example_usage": example_usage,
		"required_functions": required_functions,
		"required_variables": required_variables,
		"required_ship_types": required_ship_types,
		"tags": tags,
		"created_date": created_date
	}

## Imports pattern from community sharing format
static func import_pattern(pattern_data: Dictionary) -> SexpPattern:
	var pattern: SexpPattern = SexpPattern.new()
	
	pattern.pattern_id = pattern_data.get("pattern_id", "")
	pattern.pattern_name = pattern_data.get("pattern_name", "")
	pattern.category = pattern_data.get("category", PatternCategory.CUSTOM)
	pattern.description = pattern_data.get("description", "")
	pattern.usage_notes = pattern_data.get("usage_notes", "")
	pattern.author = pattern_data.get("author", "")
	pattern.version = pattern_data.get("version", "1.0.0")
	pattern.complexity = pattern_data.get("complexity", ComplexityLevel.BASIC)
	pattern.sexp_expression = pattern_data.get("sexp_expression", "")
	pattern.parameter_placeholders = pattern_data.get("parameter_placeholders", {})
	pattern.example_usage = pattern_data.get("example_usage", "")
	pattern.required_functions = pattern_data.get("required_functions", [])
	pattern.required_variables = pattern_data.get("required_variables", [])
	pattern.required_ship_types = pattern_data.get("required_ship_types", [])
	pattern.tags = pattern_data.get("tags", [])
	pattern.created_date = pattern_data.get("created_date", "")
	pattern.is_community_pattern = true
	
	return pattern