# scripts/mission_system/log/mission_log_manager.gd
# Singleton (Autoload) responsible for managing the mission event log.
# Corresponds to missionlog.cpp logic.
class_name MissionLogManager
extends Node

# --- Dependencies ---
const MissionLogEntry = preload("res://scripts/resources/mission/mission_log_entry.gd")
# Access GameManager via singleton: Engine.get_singleton("GameManager")

# --- Constants ---
const MAX_LOG_ENTRIES = 700 # Maximum number of entries to store
const LOG_CULL_MARK = int(MAX_LOG_ENTRIES * 0.95) # Start culling around 95% capacity
const LOG_CULL_DOORDIE_MARK = int(MAX_LOG_ENTRIES * 0.99) # More aggressive culling mark
const LOG_LAST_DITCH_CULL_NUM = int(MAX_LOG_ENTRIES * 0.20) # Number to cull in emergency

# --- State ---
var log_entries: Array[MissionLogEntry] = []

func _ready() -> void:
	print("MissionLogManager initialized.")

# --- Public API ---

func clear_log() -> void:
	log_entries.clear()
	print("MissionLogManager: Log cleared.")

# Adds a new entry to the log. Called by various game systems.
func add_entry(type: int, primary_name: String, secondary_name: String = "", index: int = -1) -> void:
	# TODO: Handle multiplayer master/client logic if needed (only master adds?)

	# Cull log if approaching limit
	if log_entries.size() >= LOG_CULL_MARK:
		_cull_obsolete_entries()
		# Aggressive culling if still too full
		if log_entries.size() >= LOG_CULL_DOORDIE_MARK:
			_cull_aggressively()

	if log_entries.size() >= MAX_LOG_ENTRIES:
		printerr("MissionLogManager: Log full, cannot add new entry!")
		return

	var entry = MissionLogEntry.new()
	entry.type = type
	entry.timestamp = GameManager.get_mission_time() if Engine.has_singleton("GameManager") else 0.0
	entry.primary_name = primary_name if primary_name else ""
	entry.secondary_name = secondary_name if secondary_name else ""
	entry.index = index
	entry.flags = 0 # Set flags based on type/context below

	# --- Determine Display Names and Teams ---
	# This requires looking up ship/wing data based on names
	var primary_node = _find_object_node(entry.primary_name)
	var secondary_node = _find_object_node(entry.secondary_name)

	if primary_node and primary_node is ShipBase:
		entry.primary_team = primary_node.get_team()
		entry.primary_display_name = primary_node.get_display_name() # Assuming ShipBase has this
		if primary_node.has_flag(GlobalConstants.SF2_HIDE_LOG_ENTRIES): # Assuming flags defined
			entry.flags |= GlobalConstants.MLF_HIDDEN
	elif primary_node: # Could be a wing name? Need wing lookup logic
		# TODO: Handle wing name lookup and display name generation
		entry.primary_display_name = entry.primary_name # Fallback
	else:
		entry.primary_display_name = entry.primary_name # Fallback

	if secondary_node and secondary_node is ShipBase:
		entry.secondary_team = secondary_node.get_team()
		entry.secondary_display_name = secondary_node.get_display_name()
		if secondary_node.has_flag(GlobalConstants.SF2_HIDE_LOG_ENTRIES):
			entry.flags |= GlobalConstants.MLF_SECONDARY_HIDDEN
	elif secondary_node:
		# TODO: Handle wing name lookup
		entry.secondary_display_name = entry.secondary_name
	else:
		entry.secondary_display_name = entry.secondary_name

	# --- Set Flags based on Type ---
	match type:
		GlobalConstants.LOG_SHIP_DESTROYED, \
		GlobalConstants.LOG_WING_DESTROYED, \
		GlobalConstants.LOG_GOAL_SATISFIED, \
		GlobalConstants.LOG_GOAL_FAILED:
			entry.flags |= GlobalConstants.MLF_ESSENTIAL # Mark as essential

		GlobalConstants.LOG_SHIP_ARRIVED:
			if primary_node and primary_node is ShipBase and primary_node.has_flag(GlobalConstants.SF2_NO_ARRIVAL_LOG):
				entry.flags |= GlobalConstants.MLF_HIDDEN
		GlobalConstants.LOG_SHIP_DEPARTED:
			if primary_node and primary_node is ShipBase and primary_node.has_flag(GlobalConstants.SF2_NO_DEPARTURE_LOG):
				entry.flags |= GlobalConstants.MLF_HIDDEN
		GlobalConstants.LOG_WING_ARRIVED:
			# TODO: Check wing flags WF_NO_ARRIVAL_LOG
			pass
		GlobalConstants.LOG_WING_DEPARTED:
			# TODO: Check wing flags WF_NO_DEPARTURE_LOG
			pass
		GlobalConstants.LOG_SHIP_SUBSYS_DESTROYED:
			# Hide if it's a small ship subsystem? Check SIF_SMALL_SHIP
			if primary_node and primary_node is ShipBase:
				var ship_data = primary_node.ship_data
				if ship_data and ship_data.flags & GlobalConstants.SIF_SMALL_SHIP: # Assuming flags defined
					entry.flags |= GlobalConstants.MLF_HIDDEN
		# Add other type-specific flag logic...

	# TODO: Mark related older entries as obsolete (e.g., subsystem destroyed when ship destroyed)
	_mark_related_obsolete(type, entry.primary_name)

	log_entries.append(entry)

	# TODO: Handle multiplayer log synchronization (send packet if master)


# Retrieves all log entries (e.g., for display)
func get_all_entries() -> Array[MissionLogEntry]:
	return log_entries


# Finds the timestamp of the nth occurrence of a specific log event.
func get_entry_time(type: int, primary_name: String, secondary_name: String = "", occurrence: int = 1) -> float:
	var count = 0
	for entry in log_entries:
		if entry.type == type and \
		   entry.primary_name == primary_name and \
		   (secondary_name.is_empty() or entry.secondary_name == secondary_name):
			count += 1
			if count == occurrence:
				entry.flags |= GlobalConstants.MLF_ESSENTIAL # Mark as essential if queried
				return entry.timestamp
	return -1.0 # Not found


# Counts occurrences of a specific log event.
func get_entry_count(type: int, primary_name: String, secondary_name: String = "") -> int:
	var count = 0
	for entry in log_entries:
		if entry.type == type and \
		   entry.primary_name == primary_name and \
		   (secondary_name.is_empty() or entry.secondary_name == secondary_name):
			count += 1
	return count


# --- Internal Logic ---

func _find_object_node(object_name: String) -> Node:
	if object_name.is_empty():
		return null
	# TODO: Implement robust lookup - check ObjectManager for ships, maybe check Wing data?
	if Engine.has_singleton("ObjectManager"):
		return ObjectManager.find_ship_by_name(object_name) # Assuming method exists
	return null


func _mark_related_obsolete(new_entry_type: int, primary_name: String) -> void:
	# Example: If a ship is destroyed, mark its previous subsystem destroyed entries as obsolete
	if new_entry_type == GlobalConstants.LOG_SHIP_DESTROYED:
		for entry in log_entries:
			if entry.primary_name == primary_name:
				match entry.type:
					GlobalConstants.LOG_SHIP_SUBSYS_DESTROYED, \
					GlobalConstants.LOG_SHIP_DISABLED, \
					GlobalConstants.LOG_SHIP_DISARMED:
						entry.flags |= GlobalConstants.MLF_OBSOLETE


func _cull_obsolete_entries() -> void:
	var entries_to_keep: Array[MissionLogEntry] = []
	for entry in log_entries:
		if not (entry.flags & GlobalConstants.MLF_OBSOLETE):
			entries_to_keep.append(entry)
	var removed_count = log_entries.size() - entries_to_keep.size()
	if removed_count > 0:
		log_entries = entries_to_keep
		print("MissionLogManager: Culled %d obsolete log entries." % removed_count)


func _cull_aggressively() -> void:
	# Mark the first N non-essential entries as obsolete
	var marked_count = 0
	for i in range(log_entries.size()):
		if not (log_entries[i].flags & GlobalConstants.MLF_ESSENTIAL):
			log_entries[i].flags |= GlobalConstants.MLF_OBSOLETE
			marked_count += 1
			if marked_count >= LOG_LAST_DITCH_CULL_NUM:
				break
	print("MissionLogManager: Aggressively marked %d entries for culling." % marked_count)
	_cull_obsolete_entries()
