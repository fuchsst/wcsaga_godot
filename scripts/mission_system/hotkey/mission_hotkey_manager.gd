# scripts/mission_system/hotkey/mission_hotkey_manager.gd
# Manages mission hotkey assignments (F5-F12).
# Corresponds to missionhotkey.cpp logic.
# This might be integrated into PlayerData/CampaignSaveData later.
class_name MissionHotkeyManager
extends Node

# --- Constants ---
const MAX_KEYED_TARGETS = 8 # F5 to F12

# --- State ---
# Dictionary mapping hotkey index (0-7) to an array of target signatures
var hotkey_assignments: Dictionary = {} # { 0: [sig1, sig2], 1: [sig3], ... }

# Temporary storage for restoring keys after mission load (if needed)
var saved_hotkeys: Dictionary = {} # Stores assignments before applying mission defaults

func _ready() -> void:
	print("MissionHotkeyManager initialized.")
	clear_all_hotkeys()

# --- Public API ---

# Clears all hotkey assignments for a specific set (0-7)
func clear_hotkey_set(set_index: int) -> void:
	if set_index >= 0 and set_index < MAX_KEYED_TARGETS:
		hotkey_assignments[set_index] = []
		# TODO: Update HUD if necessary


# Clears all hotkey assignments entirely
func clear_all_hotkeys() -> void:
	for i in range(MAX_KEYED_TARGETS):
		hotkey_assignments[i] = []
	# TODO: Update HUD


# Adds or removes a target object from a hotkey set
func assign_remove_hotkey(set_index: int, target_node: Node3D) -> void:
	if not is_instance_valid(target_node) or not target_node is BaseObject:
		printerr("MissionHotkeyManager: Invalid target node provided.")
		return
	if set_index < 0 or set_index >= MAX_KEYED_TARGETS:
		printerr("MissionHotkeyManager: Invalid hotkey set index: ", set_index)
		return

	var target_script = target_node as BaseObject
	var target_signature = target_script.get_signature()

	var current_set: Array = hotkey_assignments[set_index]

	if target_signature in current_set:
		# Target is already in the set, remove it
		current_set.erase(target_signature)
		print("MissionHotkeyManager: Removed target %s (Sig: %d) from hotkey F%d" % [target_node.name, target_signature, set_index + 5])
	else:
		# Target is not in the set, add it
		current_set.append(target_signature)
		print("MissionHotkeyManager: Added target %s (Sig: %d) to hotkey F%d" % [target_node.name, target_signature, set_index + 5])

	# TODO: Update HUD


# Applies default hotkeys defined in the mission file
func apply_mission_defaults(mission_data: MissionData) -> void:
	print("MissionHotkeyManager: Applying mission default hotkeys.")
	# Save current user assignments before clearing (optional, depends on desired behavior)
	# _save_current_assignments()

	clear_all_hotkeys()

	# Apply ship defaults
	for ship_data in mission_data.ships:
		if ship_data.hotkey >= 0 and ship_data.hotkey < MAX_KEYED_TARGETS:
			# Need to find the actual spawned ship node later to add it
			# For now, maybe store pending assignments?
			# Or, this should be called *after* initial ships are spawned.
			var ship_node = ObjectManager.get_object_by_signature(ship_data.net_signature) # Example lookup
			if is_instance_valid(ship_node):
				assign_remove_hotkey(ship_data.hotkey, ship_node)
			else:
				printerr("MissionHotkeyManager: Could not find spawned ship %s to apply default hotkey." % ship_data.name)


	# Apply wing defaults
	for wing_data in mission_data.wings:
		if wing_data.hotkey >= 0 and wing_data.hotkey < MAX_KEYED_TARGETS:
			# Need to find all spawned ships belonging to this wing
			# This also likely needs to happen after spawning.
			# Example:
			# var wing_nodes = ObjectManager.get_ships_in_wing(wing_data.name) # Assuming method exists
			# for ship_node in wing_nodes:
			#	 assign_remove_hotkey(wing_data.hotkey, ship_node)
			pass

	# TODO: Restore saved user assignments if implementing save/restore logic


# Gets the list of target signatures assigned to a hotkey set
func get_targets_for_set(set_index: int) -> Array[int]:
	if set_index >= 0 and set_index < MAX_KEYED_TARGETS:
		# Return a copy to prevent external modification
		return hotkey_assignments[set_index].duplicate()
	return []


# Checks if a specific target is assigned to any hotkey
func get_hotkey_flags_for_target(target_signature: int) -> int:
	var flags = 0
	for i in range(MAX_KEYED_TARGETS):
		if target_signature in hotkey_assignments[i]:
			flags |= (1 << i)
	return flags


# --- Save/Load Logic (Potentially moved to CampaignManager/PlayerData) ---

func get_save_data() -> Dictionary:
	# Return data suitable for saving (e.g., in CampaignSaveData)
	return hotkey_assignments.duplicate(true) # Deep copy


func load_save_data(data: Dictionary) -> void:
	# Load assignments from saved data
	clear_all_hotkeys()
	for i in range(MAX_KEYED_TARGETS):
		if data.has(i) and data[i] is Array:
			# Validate signatures? Ensure they are integers.
			var valid_sigs: Array[int] = []
			for sig in data[i]:
				if typeof(sig) == TYPE_INT:
					valid_sigs.append(sig)
			hotkey_assignments[i] = valid_sigs
		else:
			hotkey_assignments[i] = [] # Ensure array exists even if key missing/invalid


# --- Internal Helpers ---

# func _save_current_assignments(): ...
# func _restore_saved_assignments(): ...
