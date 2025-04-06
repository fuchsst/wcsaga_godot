# scripts/resources/game_data/iff_defs_data.gd
# Defines the structure for storing IFF definitions loaded from iff_defs.tbl.
extends Resource
class_name IffDefsData

# --- Global Settings ---
@export var traitor_iff_name: String = "Traitor"
@export var selection_color: Color = Color.WHITE
@export var message_color: Color = Color(0.5, 0.5, 0.5)
@export var tagged_color: Color = Color.YELLOW
@export var dimmed_iff_brightness: int = 4 # Alpha delta (0-255 range likely) - Used to calculate dim color
@export var use_alternate_blip_coloring: bool = false
@export var radar_missile_blip_color: Color = Color(0.5, 0.5, 0.5) # Default grey
@export var radar_navbuoy_blip_color: Color = Color(0.5, 0.5, 0.5)
@export var radar_warping_blip_color: Color = Color(0.5, 0.5, 0.5)
@export var radar_node_blip_color: Color = Color(0.5, 0.5, 0.5)
@export var radar_tagged_blip_color: Color = Color.YELLOW
@export var radar_target_id_flags: int = 0 # Bitmask (RTIF_*)

# --- Individual IFF Definitions ---
# Array of Dictionaries is flexible for parsing and accessing by name later.
# Each dictionary represents one IFF entry.
@export var iff_definitions: Array[Dictionary] = []
# Structure of each dictionary in the array:
# {
#   "name": "Terran",
#   "default_color": Color(0, 0.5, 1.0),
#   "attacks": ["Hostile", "Traitor"], # List of names this IFF attacks
#   "sees_as": { "Hostile": Color(1.0, 0, 0), "Neutral": Color(1.0, 1.0, 0) }, # Dict: TargetName -> Observed Color
#   "flags": 1, # Bitmask (IFFF_*)
#   "default_ship_flags": 0, # Bitmask (P_*)
#   "default_ship_flags2": 0 # Bitmask (P2_*)
# }

# --- Runtime Helper Data (Generated on load by IFFManager or similar) ---
# These are not exported, but can be populated after loading the resource.
var iff_name_to_index: Dictionary = {}
var attack_matrix: Array[int] = [] # Bitmasks, size Num_iffs
var observed_color_matrix: Array[Color] = [] # size Num_iffs * Num_iffs
var iff_colors: Array[Color] = [] # Array of unique Color objects used

# --- Helper Functions (Could be moved to a separate IFFManager script) ---

func _initialize_lookup_tables():
	"""Populates runtime lookup tables after the resource is loaded."""
	iff_name_to_index.clear()
	attack_matrix.clear()
	observed_color_matrix.clear()
	iff_colors.clear()

	var num_iffs = iff_definitions.size()
	if num_iffs == 0:
		printerr("IffDefsData: No IFF definitions loaded to initialize lookup tables.")
		return

	# Populate name->index map and colors array
	var color_map: Dictionary = {} # Track unique colors {Color: index}
	for i in range(num_iffs):
		var iff_name = iff_definitions[i].get("name", "")
		if iff_name:
			iff_name_to_index[iff_name.to_lower()] = i
		var def_color: Color = iff_definitions[i].get("default_color", Color.WHITE)
		if not color_map.has(def_color):
			color_map[def_color] = iff_colors.size()
			iff_colors.append(def_color)
		for target_name in iff_definitions[i].get("sees_as", {}):
			var obs_color: Color = iff_definitions[i]["sees_as"][target_name]
			if not color_map.has(obs_color):
				color_map[obs_color] = iff_colors.size()
				iff_colors.append(obs_color)

	# Populate attack matrix and observed color matrix
	attack_matrix.resize(num_iffs)
	observed_color_matrix.resize(num_iffs * num_iffs) # Flattened 2D array
	observed_color_matrix.fill(Color(0,0,0,0)) # Use transparent black as default/invalid

	for i in range(num_iffs):
		var attacker_dict = iff_definitions[i]
		var attacker_name_lower = attacker_dict.get("name", "").to_lower()
		var attack_mask = 0

		# Build attack mask
		for attackee_name in attacker_dict.get("attacks", []):
			var attackee_idx = iff_name_to_index.get(attackee_name.to_lower(), -1)
			if attackee_idx != -1:
				attack_mask |= (1 << attackee_idx)
		attack_matrix[i] = attack_mask

		# Build observed color matrix
		for j in range(num_iffs):
			var target_dict = iff_definitions[j]
			var target_name = target_dict.get("name", "")
			var observed_color = attacker_dict.get("sees_as", {}).get(target_name, attacker_dict.get("default_color", Color.WHITE))
			observed_color_matrix[i * num_iffs + j] = observed_color


func get_iff_index(iff_name: String) -> int:
	if iff_name_to_index.is_empty() and not iff_definitions.is_empty():
		_initialize_lookup_tables() # Initialize on first use if needed
	return iff_name_to_index.get(iff_name.to_lower(), -1)

func get_num_iffs() -> int:
	return iff_definitions.size()

func get_iff_name(index: int) -> String:
	if index >= 0 and index < iff_definitions.size():
		return iff_definitions[index].get("name", "Unknown")
	return "Invalid"

func get_attack_mask(attacker_iff_index: int) -> int:
	# TODO: Consider MISSION_FLAG_ALL_ATTACK if needed here or in manager
	if attacker_iff_index >= 0 and attacker_iff_index < attack_matrix.size():
		return attack_matrix[attacker_iff_index]
	return 0

func get_observed_color(observer_iff_index: int, target_iff_index: int) -> Color:
	var num_iffs = iff_definitions.size()
	if observer_iff_index >= 0 and observer_iff_index < num_iffs and \
	   target_iff_index >= 0 and target_iff_index < num_iffs:
		var flat_index = observer_iff_index * num_iffs + target_iff_index
		if flat_index < observed_color_matrix.size():
			# Check if the color is valid (not the default transparent black)
			if observed_color_matrix[flat_index].a > 0.1:
				return observed_color_matrix[flat_index]
	# Fallback to target's default color if observer/target index invalid or no specific color set
	if target_iff_index >= 0 and target_iff_index < num_iffs:
		return iff_definitions[target_iff_index].get("default_color", Color.WHITE)
	return Color.WHITE # Absolute fallback

func get_default_color(iff_index: int) -> Color:
	if iff_index >= 0 and iff_index < iff_definitions.size():
		return iff_definitions[iff_index].get("default_color", Color.WHITE)
	return Color.WHITE

func iff_flags_match(iff_index: int, flag_mask: int) -> bool:
	if iff_index >= 0 and iff_index < iff_definitions.size():
		return (iff_definitions[iff_index].get("flags", 0) & flag_mask) != 0
	return false

func get_default_ship_flags(iff_index: int) -> int:
	if iff_index >= 0 and iff_index < iff_definitions.size():
		return iff_definitions[iff_index].get("default_ship_flags", 0)
	return 0

func get_default_ship_flags2(iff_index: int) -> int:
	if iff_index >= 0 and iff_index < iff_definitions.size():
		return iff_definitions[iff_index].get("default_ship_flags2", 0)
	return 0
