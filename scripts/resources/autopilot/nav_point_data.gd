# scripts/resources/autopilot/nav_point_data.gd
extends Resource
class_name NavPointData

## Defines a navigation point for the autopilot system.
## Corresponds to the NavPoint struct in C++.

# --- Exports ---
@export var nav_name: String = ""  # Internal name used for identification (e.g., "Alpha 1", "Waypoint Path:Node 1")
@export var display_name: String = "" # Name shown in the HUD/UI (can be localized)

enum TargetType { SHIP, WAYPOINT_PATH }
@export var target_type: TargetType = TargetType.WAYPOINT_PATH

@export var target_identifier: String = "" # Ship name or Waypoint path name
@export var waypoint_node_index: int = 0 # Index within the waypoint path (0-based for Godot)

# Flags corresponding to NP_* defines
@export_flags("Hidden", "NoAccess", "Visited") var flags: int = 0

const FLAG_HIDDEN = 1 << 0 # NP_HIDDEN (0x0004 in C++, shifted for clarity)
const FLAG_NO_ACCESS = 1 << 1 # NP_NOACCESS (0x0008 in C++, shifted for clarity)
const FLAG_VISITED = 1 << 2 # NP_VISITED (0x0100 in C++, shifted for clarity)

# --- Methods ---

func get_target_position() -> Vector3:
	# TODO: Implement logic to find the actual world position
	# based on target_type, target_identifier, and waypoint_node_index.
	# This will likely involve querying ObjectManager or a WaypointManager.
	printerr("NavPointData.get_target_position() not yet implemented for '", nav_name, "'")
	return Vector3.ZERO

func is_hidden() -> bool:
	return (flags & FLAG_HIDDEN) != 0

func is_no_access() -> bool:
	return (flags & FLAG_NO_ACCESS) != 0

func is_visited() -> bool:
	return (flags & FLAG_VISITED) != 0

func set_visited(visited: bool):
	if visited:
		flags |= FLAG_VISITED
	else:
		flags &= ~FLAG_VISITED

func can_select() -> bool:
	# Corresponds to !(NP_HIDDEN | NP_NOACCESS) check
	return not is_hidden() and not is_no_access()

func get_type_string() -> String:
	match target_type:
		TargetType.SHIP: return "Ship"
		TargetType.WAYPOINT_PATH: return "Waypoint"
	return "Unknown"
