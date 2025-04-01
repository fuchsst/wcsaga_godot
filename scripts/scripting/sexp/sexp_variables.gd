# sexp_variables.gd
# Autoload Singleton responsible for managing SEXP variables (@variable_name).
# Handles storage, retrieval, type checking, and persistence.
extends Node

# Import constants for variable types/flags
const SexpConstants = preload("res://scripts/scripting/sexp/sexp_constants.gd")

# --- Variable Storage ---
# We need separate dictionaries for different persistence levels.
# Structure: { "variable_name": { "type": SexpVariableType, "value": Variant } }

# Variables local to the current mission (cleared on mission end)
var _mission_variables: Dictionary = {}

# Variables persistent across a campaign (loaded/saved with campaign state)
# TODO: Implement loading/saving mechanism, potentially via CampaignManager/PlayerData
var _campaign_variables: Dictionary = {}

# Variables persistent for the player profile (loaded/saved with player profile)
# TODO: Implement loading/saving mechanism, potentially via PlayerData
var _player_variables: Dictionary = {}


# --- Public API ---

## Clears all mission-local variables. Called at the start/end of a mission.
func clear_mission_variables() -> void:
	_mission_variables.clear()
	print("SEXP Mission Variables Cleared")


## Clears all campaign variables. Called when starting/ending a campaign.
func clear_campaign_variables() -> void:
	_campaign_variables.clear()
	print("SEXP Campaign Variables Cleared")


## Clears all player variables. Called when changing player profiles.
func clear_player_variables() -> void:
	_player_variables.clear()
	print("SEXP Player Variables Cleared")


## Sets the value of a SEXP variable.
## Determines persistence based on flags in the type.
func set_variable(var_name: String, value: Variant, type_flags: int) -> void:
	if not var_name.begins_with("@"):
		push_error("Invalid SEXP variable name (must start with @): %s" % var_name)
		return

	var actual_name: String = var_name.substr(1) # Remove the leading '@'
	var var_type: int
	var storage_dict: Dictionary

	# Determine type based on value
	if value is String:
		var_type = SexpConstants.SEXP_VARIABLE_STRING
	elif value is int or value is float:
		var_type = SexpConstants.SEXP_VARIABLE_NUMBER
		value = float(value) # Store numbers consistently as float
	else:
		push_error("Unsupported SEXP variable type for '%s': %s" % [actual_name, typeof(value)])
		return

	# Determine storage based on persistence flags
	if type_flags & SexpConstants.SEXP_VARIABLE_PLAYER_PERSISTENT:
		storage_dict = _player_variables
		#print("Setting player persistent var: %s = %s" % [actual_name, str(value)])
	elif type_flags & SexpConstants.SEXP_VARIABLE_CAMPAIGN_PERSISTENT:
		storage_dict = _campaign_variables
		#print("Setting campaign persistent var: %s = %s" % [actual_name, str(value)])
	else:
		storage_dict = _mission_variables
		#print("Setting mission var: %s = %s" % [actual_name, str(value)])

	# Store the variable data
	storage_dict[actual_name] = {
		"type": var_type,
		"value": value,
		"persistence_flags": type_flags & (SexpConstants.SEXP_VARIABLE_PLAYER_PERSISTENT | SexpConstants.SEXP_VARIABLE_CAMPAIGN_PERSISTENT)
	}


## Gets the value of a SEXP variable.
## Checks persistence levels in order: mission -> campaign -> player.
## Returns null if the variable is not found.
func get_variable(var_name: String) -> Variant:
	if not var_name.begins_with("@"):
		push_error("Invalid SEXP variable name (must start with @): %s" % var_name)
		return null

	var actual_name: String = var_name.substr(1)

	if _mission_variables.has(actual_name):
		return _mission_variables[actual_name]["value"]
	elif _campaign_variables.has(actual_name):
		return _campaign_variables[actual_name]["value"]
	elif _player_variables.has(actual_name):
		return _player_variables[actual_name]["value"]
	else:
		# Variable not found - original FS2 might return 0 or "" depending on context?
		# Returning null seems safer for now to indicate it wasn't found.
		# The SexpEvaluator might need to handle this null case appropriately.
		# print("SEXP Variable not found: %s" % actual_name)
		return null


## Gets the type flags of a SEXP variable (Number/String + Persistence).
## Returns -1 if not found.
func get_variable_type_flags(var_name: String) -> int:
	if not var_name.begins_with("@"):
		return -1

	var actual_name: String = var_name.substr(1)
	var data: Dictionary

	if _mission_variables.has(actual_name):
		data = _mission_variables[actual_name]
	elif _campaign_variables.has(actual_name):
		data = _campaign_variables[actual_name]
	elif _player_variables.has(actual_name):
		data = _player_variables[actual_name]
	else:
		return -1 # Not found

	return data["type"] | data["persistence_flags"]


## Checks if a variable exists (in any persistence level).
func has_variable(var_name: String) -> bool:
	if not var_name.begins_with("@"):
		return false
	var actual_name: String = var_name.substr(1)
	return _mission_variables.has(actual_name) or \
		   _campaign_variables.has(actual_name) or \
		   _player_variables.has(actual_name)


# --- TODO: Persistence ---
# Add functions to save/load campaign and player variables
# These would likely interact with CampaignManager and PlayerData singletons/resources.

# func save_campaign_variables(save_data: Dictionary) -> void:
#	save_data["sexp_campaign_vars"] = _campaign_variables

# func load_campaign_variables(save_data: Dictionary) -> void:
#	if save_data.has("sexp_campaign_vars"):
#		_campaign_variables = save_data["sexp_campaign_vars"]
#	else:
#		_campaign_variables.clear()

# func save_player_variables(save_data: Dictionary) -> void:
#	save_data["sexp_player_vars"] = _player_variables

# func load_player_variables(save_data: Dictionary) -> void:
#	if save_data.has("sexp_player_vars"):
#		_player_variables = save_data["sexp_player_vars"]
#	else:
#		_player_variables.clear()
