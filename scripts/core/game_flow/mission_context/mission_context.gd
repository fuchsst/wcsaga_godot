class_name MissionContext
extends Resource

## Mission Context Data Structure
## Maintains comprehensive mission state throughout the mission lifecycle,
## leveraging existing MissionData and campaign systems for complete integration

const MissionData = preload("res://addons/wcs_asset_core/resources/mission/mission_data.gd")
const ShipData = preload("res://addons/wcs_asset_core/resources/ship/ship_data.gd")
const CampaignState = preload("res://addons/wcs_asset_core/resources/save_system/campaign_state.gd")

enum Phase {
	BRIEFING,
	SHIP_SELECTION,
	LOADING,
	IN_MISSION,
	COMPLETED,
	DEBRIEFING
}

## Core mission identification
@export var mission_id: String = ""
@export var mission_data: MissionData = null
@export var campaign_state: CampaignState = null
@export var current_phase: Phase = Phase.BRIEFING

## Mission timing
@export var start_time: int = 0
@export var end_time: int = 0
@export var duration: float = 0.0

## Mission-specific state
@export var selected_ship: ShipData = null
@export var selected_loadout: Dictionary = {}
@export var mission_variables: Dictionary = {}
@export var briefing_acknowledged: bool = false
@export var objectives_read: bool = false

## Mission result data (set during completion)
@export var mission_result: Dictionary = {}
@export var performance_metrics: Dictionary = {}

## Resource loading state
@export var loaded_resources: Array[String] = []
@export var resource_loading_progress: float = 0.0

func _init() -> void:
	start_time = Time.get_unix_time_from_system()

## Mission context validation
func is_valid() -> bool:
	return mission_id.length() > 0 and mission_data != null and campaign_state != null

## Phase progression validation
func can_advance_to_phase(target_phase: Phase) -> bool:
	match target_phase:
		Phase.SHIP_SELECTION:
			return current_phase == Phase.BRIEFING and briefing_acknowledged
		Phase.LOADING:
			return current_phase == Phase.SHIP_SELECTION and selected_ship != null
		Phase.IN_MISSION:
			return current_phase == Phase.LOADING and resource_loading_progress >= 1.0
		Phase.COMPLETED:
			return current_phase == Phase.IN_MISSION
		Phase.DEBRIEFING:
			return current_phase == Phase.COMPLETED and not mission_result.is_empty()
		_:
			return false

## Mission data accessors using existing mission system
func get_mission_objectives() -> Array:
	if not mission_data:
		return []
	
	var objectives: Array = []
	for goal_resource in mission_data.goals:
		objectives.append(goal_resource)
	return objectives

func get_available_ships() -> Array[ShipData]:
	if not mission_data:
		return []
	
	# Get ships available for player selection from mission data
	var available_ships: Array[ShipData] = []
	
	# Find player start ships in mission
	for player_start in mission_data.player_starts:
		if player_start.has_method("get_available_ship_classes"):
			var ship_classes = player_start.get_available_ship_classes()
			for ship_class in ship_classes:
				var ship_data = WCSAssetLoader.load_asset("ships/" + ship_class + ".tres")
				if ship_data and ship_data is ShipData:
					available_ships.append(ship_data)
	
	# If no specific ships found, allow all fighter-class ships
	if available_ships.is_empty():
		available_ships = _get_default_player_ships()
	
	return available_ships

func get_mission_briefing() -> Resource:
	if not mission_data or mission_data.briefings.is_empty():
		return null
	
	# Return the first briefing (team 0 briefing)
	return mission_data.briefings[0]

## Mission variable management using campaign state integration
func set_mission_variable(variable_name: String, value: Variant) -> void:
	mission_variables[variable_name] = value
	
	# Also set in campaign state for SEXP integration
	if campaign_state:
		campaign_state.set_variable(variable_name, value, false)  # false = mission-only

func get_mission_variable(variable_name: String, default_value: Variant = null) -> Variant:
	# Check mission context first, then campaign state
	if mission_variables.has(variable_name):
		return mission_variables[variable_name]
	elif campaign_state:
		return campaign_state.get_variable(variable_name, default_value)
	else:
		return default_value

## Ship selection management
func select_ship(ship: ShipData) -> bool:
	if not ship or not _is_ship_available_for_mission(ship):
		return false
	
	selected_ship = ship
	
	# Initialize default loadout for selected ship
	_initialize_default_loadout()
	
	return true

func select_loadout(loadout_data: Dictionary) -> bool:
	if not selected_ship:
		push_error("Cannot select loadout without a selected ship")
		return false
	
	# Validate loadout compatibility with selected ship
	if not _validate_loadout_compatibility(loadout_data):
		return false
	
	selected_loadout = loadout_data
	return true

## Mission completion handling
func complete_mission(result_data: Dictionary) -> void:
	end_time = Time.get_unix_time_from_system()
	duration = float(end_time - start_time)
	mission_result = result_data
	current_phase = Phase.COMPLETED
	
	# Update campaign state with mission completion
	if campaign_state and mission_data:
		var mission_index = _get_mission_index_in_campaign()
		if mission_index >= 0:
			campaign_state.complete_mission(mission_index, result_data)

## Get formatted mission summary
func get_mission_summary() -> Dictionary:
	return {
		"mission_id": mission_id,
		"mission_name": mission_data.mission_title if mission_data else "Unknown",
		"current_phase": _get_phase_name(current_phase),
		"duration": duration,
		"selected_ship": selected_ship.display_name if selected_ship else "None",
		"briefing_read": briefing_acknowledged,
		"objectives_count": get_mission_objectives().size(),
		"is_valid": is_valid()
	}

## Resource management
func add_loaded_resource(resource_path: String) -> void:
	if resource_path not in loaded_resources:
		loaded_resources.append(resource_path)

func get_required_resources() -> Array[String]:
	var resources: Array[String] = []
	
	if mission_data:
		# Mission file itself
		resources.append("missions/" + mission_id + ".tres")
		
		# Ship resources
		if selected_ship:
			resources.append(selected_ship.resource_path)
		
		# Briefing resources
		var briefing = get_mission_briefing()
		if briefing and briefing.has_method("get_required_resources"):
			resources.append_array(briefing.get_required_resources())
	
	return resources

## Private helper methods
func _is_ship_available_for_mission(ship: ShipData) -> bool:
	if not ship:
		return false
	
	# Check ship class restrictions from mission data
	# For now, allow all fighter-class ships
	return ship.ship_class == "fighter" or ship.ship_class == "interceptor"

func _get_default_player_ships() -> Array[ShipData]:
	# Return default set of player ships if mission doesn't specify
	var default_ships: Array[ShipData] = []
	var ship_classes = ["ulysses", "hercules", "loki", "ares"]
	
	for ship_class in ship_classes:
		var ship_data = WCSAssetLoader.load_asset("ships/" + ship_class + ".tres")
		if ship_data and ship_data is ShipData:
			default_ships.append(ship_data)
	
	return default_ships

func _initialize_default_loadout() -> void:
	if not selected_ship:
		return
	
	# Initialize with ship's default loadout
	selected_loadout = {
		"primary_weapons": selected_ship.default_primary_weapons.duplicate(),
		"secondary_weapons": selected_ship.default_secondary_weapons.duplicate(),
		"afterburner": true,
		"countermeasures": selected_ship.cmeasure_max
	}

func _validate_loadout_compatibility(loadout_data: Dictionary) -> bool:
	if not selected_ship:
		return false
	
	# Basic validation - check if weapons can be mounted on ship
	# More detailed validation would check weapon bank compatibility
	return true

func _get_mission_index_in_campaign() -> int:
	if not campaign_state or not mission_data:
		return -1
	
	# Find mission index in campaign by mission filename
	# This would need to be coordinated with campaign progression system
	return 0  # Placeholder

func _get_phase_name(phase: Phase) -> String:
	match phase:
		Phase.BRIEFING:
			return "Briefing"
		Phase.SHIP_SELECTION:
			return "Ship Selection"
		Phase.LOADING:
			return "Loading"
		Phase.IN_MISSION:
			return "In Mission"
		Phase.COMPLETED:
			return "Completed"
		Phase.DEBRIEFING:
			return "Debriefing"
		_:
			return "Unknown"