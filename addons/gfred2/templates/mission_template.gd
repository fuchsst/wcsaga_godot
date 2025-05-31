@tool
class_name MissionTemplate
extends Resource

## Mission template data structure for Template and Pattern Library.
## Represents reusable mission scenarios with configurable parameters.

signal template_modified()

enum TemplateType {
	ESCORT,
	PATROL,
	ASSAULT,
	DEFENSE,
	STEALTH,
	RESCUE,
	CONVOY,
	RECONNAISSANCE,
	TRAINING,
	CUSTOM
}

enum Difficulty {
	EASY,
	MEDIUM,
	HARD,
	VERY_HARD,
	INSANE
}

# Template metadata
@export var template_id: String = ""
@export var template_name: String = ""
@export var template_type: TemplateType = TemplateType.CUSTOM
@export var description: String = ""
@export var author: String = ""
@export var version: String = "1.0.0"
@export var difficulty: Difficulty = Difficulty.MEDIUM
@export var estimated_duration_minutes: int = 15

# Template categories and tags
@export var category: String = "General"
@export var tags: Array[String] = []
@export var faction_requirements: Array[String] = []

# Template parameters for customization
@export var parameters: Dictionary = {}

# Template mission data
@export var template_mission_data: MissionData

# Template validation requirements
@export var required_assets: Array[String] = []
@export var required_sexp_functions: Array[String] = []

# Community features
@export var is_community_template: bool = false
@export var download_url: String = ""
@export var rating: float = 0.0
@export var downloads: int = 0
@export var created_date: String = ""
@export var modified_date: String = ""

func _init() -> void:
	template_id = _generate_unique_id()
	created_date = Time.get_datetime_string_from_system()
	modified_date = created_date

func _generate_unique_id() -> String:
	return "template_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 10000)

## Creates a new mission from this template with optional parameter overrides
func create_mission(parameter_overrides: Dictionary = {}) -> MissionData:
	if not template_mission_data:
		push_error("Template mission data is null")
		return null
	
	var new_mission: MissionData = template_mission_data.duplicate(true)
	
	# Apply template parameters
	var final_parameters: Dictionary = parameters.duplicate()
	final_parameters.merge(parameter_overrides)
	
	# Apply parameter customizations
	_apply_parameters_to_mission(new_mission, final_parameters)
	
	return new_mission

## Applies template parameters to the mission data
func _apply_parameters_to_mission(mission: MissionData, params: Dictionary) -> void:
	# Apply basic mission metadata parameters
	if params.has("mission_title"):
		mission.title = params.mission_title
	if params.has("mission_description"):
		mission.description = params.mission_description
	if params.has("mission_designer"):
		mission.designer = params.mission_designer
	
	# Apply difficulty scaling
	if params.has("difficulty_multiplier"):
		var multiplier: float = params.difficulty_multiplier
		_scale_mission_difficulty(mission, multiplier)
	
	# Apply ship customizations
	if params.has("player_ship_class"):
		_set_player_ship_class(mission, params.player_ship_class)
	
	# Apply numerical parameters
	if params.has("enemy_wing_count"):
		_adjust_enemy_wing_count(mission, params.enemy_wing_count)
	
	# Apply boolean flags
	if params.has("enable_support_ships"):
		mission.disallow_support_ships = not params.enable_support_ships

## Scales mission difficulty by adjusting enemy strength and numbers
func _scale_mission_difficulty(mission: MissionData, multiplier: float) -> void:
	for object in mission.objects.values():
		if object is MissionObject and object.type == MissionObject.Type.SHIP:
			# Scale enemy numbers for higher difficulty
			if object.team != 1 and object.has_method("get_property"): # Non-player team
				var current_waves: int = object.get_property("num_waves", 1)
				object.set_property("num_waves", max(1, int(current_waves * multiplier)))

## Sets the player ship class for the mission
func _set_player_ship_class(mission: MissionData, ship_class: String) -> void:
	for object in mission.objects.values():
		if object is MissionObject and object.type == MissionObject.Type.SHIP:
			if object.team == 1: # Player team
				object.set_property("ship_class", ship_class)
				break

## Adjusts the number of enemy wings in the mission
func _adjust_enemy_wing_count(mission: MissionData, target_count: int) -> void:
	var enemy_wings: Array[MissionObject] = []
	
	# Find all enemy wings
	for object in mission.objects.values():
		if object is MissionObject and object.type == MissionObject.Type.WING and object.team != 1:
			enemy_wings.append(object)
	
	var current_count: int = enemy_wings.size()
	
	if target_count > current_count:
		# Need to add more wings - duplicate existing ones
		var wings_to_add: int = target_count - current_count
		for i in wings_to_add:
			if enemy_wings.size() > 0:
				var template_wing: MissionObject = enemy_wings[i % enemy_wings.size()]
				var new_wing: MissionObject = template_wing.duplicate(true)
				new_wing.id = "wing_" + str(Time.get_unix_time_from_system()) + "_" + str(i)
				new_wing.name = "Enemy Wing " + str(current_count + i + 1)
				mission.add_object(new_wing)
	elif target_count < current_count:
		# Need to remove wings
		var wings_to_remove: int = current_count - target_count
		for i in wings_to_remove:
			if i < enemy_wings.size():
				mission.remove_object(enemy_wings[i])

## Validates template requirements against current asset and SEXP systems
func validate_template() -> Array[String]:
	var errors: Array[String] = []
	
	# Check basic template data
	if template_name.is_empty():
		errors.append("Template name is required")
	if template_id.is_empty():
		errors.append("Template ID is required")
	if not template_mission_data:
		errors.append("Template mission data is required")
		return errors
	
	# Validate mission data
	var mission_errors: Array[String] = template_mission_data.validate()
	if not mission_errors.is_empty():
		errors.append("Template mission validation failed:")
		errors.append_array(mission_errors)
	
	# Check required assets availability
	for asset_path in required_assets:
		if not WCSAssetRegistry.asset_exists(asset_path):
			errors.append("Required asset not found: " + asset_path)
	
	# Check required SEXP functions
	for function_name in required_sexp_functions:
		if not SexpManager.function_exists(function_name):
			errors.append("Required SEXP function not available: " + function_name)
	
	return errors

## Gets available template parameters with their metadata
func get_parameter_definitions() -> Dictionary:
	var param_defs: Dictionary = {}
	
	# Standard parameters for all templates
	param_defs["mission_title"] = {
		"type": "string",
		"default": template_name,
		"description": "Mission title to display"
	}
	param_defs["mission_description"] = {
		"type": "string",
		"default": description,
		"description": "Mission description for briefing"
	}
	param_defs["mission_designer"] = {
		"type": "string",
		"default": "Mission Designer",
		"description": "Mission creator name"
	}
	param_defs["difficulty_multiplier"] = {
		"type": "float",
		"default": 1.0,
		"min": 0.5,
		"max": 3.0,
		"description": "Difficulty scaling factor"
	}
	param_defs["enable_support_ships"] = {
		"type": "bool",
		"default": true,
		"description": "Allow support ship repairs"
	}
	
	# Template-specific parameters
	match template_type:
		TemplateType.ESCORT:
			param_defs["convoy_ship_count"] = {
				"type": "int",
				"default": 3,
				"min": 1,
				"max": 10,
				"description": "Number of ships to escort"
			}
			param_defs["escort_distance"] = {
				"type": "float",
				"default": 1000.0,
				"min": 500.0,
				"max": 5000.0,
				"description": "Escort formation distance"
			}
		
		TemplateType.PATROL:
			param_defs["patrol_waypoint_count"] = {
				"type": "int",
				"default": 5,
				"min": 3,
				"max": 12,
				"description": "Number of patrol waypoints"
			}
			param_defs["patrol_area_size"] = {
				"type": "float",
				"default": 10000.0,
				"min": 5000.0,
				"max": 50000.0,
				"description": "Patrol area radius"
			}
		
		TemplateType.ASSAULT:
			param_defs["target_ship_class"] = {
				"type": "string",
				"default": "Destroyer",
				"description": "Class of ship to assault"
			}
			param_defs["enemy_wing_count"] = {
				"type": "int",
				"default": 3,
				"min": 1,
				"max": 8,
				"description": "Number of defending enemy wings"
			}
		
		TemplateType.DEFENSE:
			param_defs["defense_target"] = {
				"type": "string",
				"default": "Station",
				"description": "Asset to defend"
			}
			param_defs["attack_wave_count"] = {
				"type": "int",
				"default": 4,
				"min": 2,
				"max": 10,
				"description": "Number of attack waves"
			}
	
	return param_defs

## Exports template to community sharing format
func export_template() -> Dictionary:
	return {
		"template_id": template_id,
		"template_name": template_name,
		"template_type": template_type,
		"description": description,
		"author": author,
		"version": version,
		"difficulty": difficulty,
		"category": category,
		"tags": tags,
		"parameters": parameters,
		"required_assets": required_assets,
		"required_sexp_functions": required_sexp_functions,
		"created_date": created_date,
		"mission_data": template_mission_data.save_fs2("") if template_mission_data else ""
	}

## Creates template from community sharing format
static func import_template(template_data: Dictionary) -> MissionTemplate:
	var template: MissionTemplate = MissionTemplate.new()
	
	template.template_id = template_data.get("template_id", "")
	template.template_name = template_data.get("template_name", "")
	template.template_type = template_data.get("template_type", TemplateType.CUSTOM)
	template.description = template_data.get("description", "")
	template.author = template_data.get("author", "")
	template.version = template_data.get("version", "1.0.0")
	template.difficulty = template_data.get("difficulty", Difficulty.MEDIUM)
	template.category = template_data.get("category", "General")
	template.tags = template_data.get("tags", [])
	template.parameters = template_data.get("parameters", {})
	template.required_assets = template_data.get("required_assets", [])
	template.required_sexp_functions = template_data.get("required_sexp_functions", [])
	template.created_date = template_data.get("created_date", "")
	template.is_community_template = true
	
	# Load mission data if available
	var mission_data_string: String = template_data.get("mission_data", "")
	if not mission_data_string.is_empty():
		template.template_mission_data = MissionData.new()
		# TODO: Parse mission data from FS2 format
	
	return template