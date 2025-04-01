# scripts/resources/waypoint_list_data.gd
# Holds a named list of waypoint positions.
class_name WaypointListData
extends Resource

@export var name: String = "" # Name of this waypoint list (e.g., "Alpha Path", "Waypoint List 1")
@export var waypoints: Array[Vector3] = [] # Array of Vector3 positions
