# scripts/globals/iff_manager.gd
# Autoload Singleton for managing IFF (Identification Friend or Foe) data and logic.
# Corresponds to parts of iff_defs.cpp functionality.
class_name IFFManager
extends Node

# Path to the converted IFF definitions resource
const IFF_DEFS_RESOURCE_PATH = "res://resources/game_data/iff_defs.tres"

# Preload the resource definition script
const IffDefsData = preload("res://scripts/resources/game_data/iff_defs_data.gd")

# Holds the loaded IffDefsData resource instance
var _iff_data: IffDefsData = null

func _ready():
	name = "IFFManager" # Ensure singleton name
	_load_iff_data()

func _load_iff_data():
	"""Loads the IffDefsData resource and initializes its lookup tables."""
	if ResourceLoader.exists(IFF_DEFS_RESOURCE_PATH):
		_iff_data = load(IFF_DEFS_RESOURCE_PATH)
		if _iff_data is IffDefsData:
			# Ensure internal lookup tables are ready
			if _iff_data.has_method("_initialize_lookup_tables"):
				_iff_data._initialize_lookup_tables()
				print(f"IFFManager: Loaded and initialized IFF data with {_iff_data.get_num_iffs()} IFF definitions.")
			else:
				printerr("IFFManager: Loaded IffDefsData resource is missing _initialize_lookup_tables() method!")
				_iff_data = null # Treat as failed load
		else:
			printerr(f"IFFManager: Failed to load! Resource is not an IffDefsData: {IFF_DEFS_RESOURCE_PATH}")
			_iff_data = null
	else:
		printerr(f"IFFManager: Failed to load IFF definitions resource, file not found: {IFF_DEFS_RESOURCE_PATH}")

# --- Core IFF Logic ---

func iff_can_attack(attacker_team_index: int, target_team_index: int) -> bool:
	"""Checks if the attacker team can attack the target team based on loaded IFF data."""
	if _iff_data == null:
		printerr("IFFManager: IFF data not loaded, cannot perform attack check.")
		return true # Fail safe: allow attack if data is missing? Or false? Let's default to true for now.

	if attacker_team_index < 0 or target_team_index < 0:
		# Invalid team index, likely means neutral or unassigned object.
		# Original game might have specific rules, but generally allow attacking unknowns.
		return true

	if attacker_team_index >= _iff_data.get_num_iffs() or target_team_index >= _iff_data.get_num_iffs():
		printerr(f"IFFManager: Invalid team index provided ({attacker_team_index} or {target_team_index}) for attack check. Max is {_iff_data.get_num_iffs() - 1}.")
		return true # Fail safe

	# TODO: Consider MISSION_FLAG_ALL_ATTACK if needed here or in manager
	# if MissionManager.get_mission_flag(GlobalConstants.MISSION_FLAG_ALL_ATTACK):
	#	 return true

	var attack_mask = _iff_data.get_attack_mask(attacker_team_index)
	var target_bit = (1 << target_team_index)

	return (attack_mask & target_bit) != 0

# --- Helper Functions (Delegating to IffDefsData) ---

func get_iff_index(iff_name: String) -> int:
	"""Gets the numerical index for a given IFF name (case-insensitive). Returns -1 if not found."""
	if _iff_data:
		return _iff_data.get_iff_index(iff_name)
	return -1

func get_num_iffs() -> int:
	"""Returns the total number of loaded IFF definitions."""
	if _iff_data:
		return _iff_data.get_num_iffs()
	return 0

func get_iff_name(index: int) -> String:
	"""Gets the IFF name for a given index. Returns 'Invalid' or 'Unknown' if index is out of bounds."""
	if _iff_data:
		return _iff_data.get_iff_name(index)
	return "Invalid"

func get_observed_color(observer_iff_index: int, target_iff_index: int) -> Color:
	"""Gets the color the observer team sees the target team as."""
	if _iff_data:
		return _iff_data.get_observed_color(observer_iff_index, target_iff_index)
	return Color.WHITE # Default fallback

func get_default_color(iff_index: int) -> Color:
	"""Gets the default color for a given IFF team index."""
	if _iff_data:
		return _iff_data.get_default_color(iff_index)
	return Color.WHITE

func iff_flags_match(iff_index: int, flag_mask: int) -> bool:
	"""Checks if the IFF definition at the given index has the specified flags set."""
	if _iff_data:
		return _iff_data.iff_flags_match(iff_index, flag_mask)
	return false

func get_default_ship_flags(iff_index: int) -> int:
	"""Gets the default ship flags associated with an IFF team."""
	if _iff_data:
		return _iff_data.get_default_ship_flags(iff_index)
	return 0

func get_default_ship_flags2(iff_index: int) -> int:
	"""Gets the default ship flags2 associated with an IFF team."""
	if _iff_data:
		return _iff_data.get_default_ship_flags2(iff_index)
	return 0

func get_traitor_iff_index() -> int:
	"""Gets the index of the traitor IFF."""
	if _iff_data:
		return get_iff_index(_iff_data.traitor_iff_name)
	return -1
