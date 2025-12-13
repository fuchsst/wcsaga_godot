# NavPoint Resource - Navigation Point Definition
# Part of the autopilot system for mission navigation
# Integrates with MissionManifest and WaypointList

class_name NavPoint
extends Resource

## Navigation point type
enum NavType {
	WAYPOINT = 0, ## Bound to a waypoint position in a WaypointList
	SHIP = 1, ## Bound to a ship's current position
}

## Navigation point flags (bitfield for efficiency, use helpers below)
enum NavFlag {
	NONE = 0,
	HIDDEN = 1, ## Not visible on nav map
	NO_ACCESS = 2, ## Cannot be selected by player
	VISITED = 4, ## Player has been within 1000m of this point
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

## Display name for this nav point
@export var nav_name: String = ""

## Type of nav point (waypoint or ship)
@export var nav_type: NavType = NavType.WAYPOINT

## Flags controlling visibility and access
@export var flags: int = NavFlag.NONE

## Target name (waypoint path name or ship name)
@export var target_name: String = ""

## Waypoint index within the path (only for NavType.WAYPOINT)
@export var waypoint_index: int = 0

# ==============================================================================
# FLAG HELPERS
# ==============================================================================


## Check if this nav point is hidden
func is_hidden() -> bool:
	return (flags & NavFlag.HIDDEN) != 0


## Check if this nav point is accessible
func is_accessible() -> bool:
	return (flags & NavFlag.NO_ACCESS) == 0


## Check if this nav point has been visited
func is_visited() -> bool:
	return (flags & NavFlag.VISITED) != 0


## Check if this nav point is selectable
func is_selectable() -> bool:
	return is_accessible() and not is_hidden()


## Set hidden flag
func set_hidden(hidden: bool) -> void:
	if hidden:
		flags |= NavFlag.HIDDEN
	else:
		flags &= ~NavFlag.HIDDEN


## Set no access flag
func set_no_access(no_access: bool) -> void:
	if no_access:
		flags |= NavFlag.NO_ACCESS
	else:
		flags &= ~NavFlag.NO_ACCESS


## Set visited flag
func set_visited(visited: bool) -> void:
	if visited:
		flags |= NavFlag.VISITED
	else:
		flags &= ~NavFlag.VISITED


# ==============================================================================
# POSITION HELPERS
# ==============================================================================


## Get the world position of this nav point
## Requires reference to mission objects to resolve ship positions
func get_position(mission_manager: Node = null) -> Vector3:
	if nav_type == NavType.SHIP:
		return _get_ship_position(mission_manager)
	return _get_waypoint_position(mission_manager)


func _get_ship_position(mission_manager: Node) -> Vector3:
	if not mission_manager:
		mission_manager = Engine.get_singleton("MissionManager")
	if not mission_manager:
		push_warning("NavPoint: No MissionManager to resolve ship position")
		return Vector3.ZERO

	# Find ship by name
	if mission_manager.has_method("get_ship_by_name"):
		var ship: Node3D = mission_manager.get_ship_by_name(target_name)
		if ship:
			return ship.global_position

	push_warning("NavPoint: Ship '%s' not found" % target_name)
	return Vector3.ZERO


func _get_waypoint_position(mission_manager: Node) -> Vector3:
	if not mission_manager:
		mission_manager = Engine.get_singleton("MissionManager")
	if not mission_manager:
		push_warning("NavPoint: No MissionManager to resolve waypoint")
		return Vector3.ZERO

	# Find waypoint path by name
	if mission_manager.has_method("get_waypoint_position"):
		return mission_manager.get_waypoint_position(target_name, waypoint_index)

	push_warning("NavPoint: Waypoint '%s:%d' not found" % [target_name, waypoint_index])
	return Vector3.ZERO


## Get internal name for debugging
func get_internal_name() -> String:
	if nav_type == NavType.WAYPOINT:
		return "%s:%d" % [target_name, waypoint_index]
	return target_name
