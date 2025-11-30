# IFF Manager autoload for Wing Commander Saga
# Handles IFF relationship matrix storage and provides lookup functionality

class_name IFFManager
extends Node

const IFFResource = preload("res://scripts/resources/iff_defs/iff_resource.gd")

# Dictionary to store loaded IFF resources
# Key: IFF name, Value: IFFResource
var iff_database: Dictionary = {}


# Called when the node enters the scene tree for the first time
func _ready() -> void:
	load_iff_database()


# Load all IFF resources from the data directory
func load_iff_database() -> void:
	var iff_directory = "res://assets/data/iff/"
	var dir = DirAccess.open(iff_directory)

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if file_name.ends_with(".tres"):
				var iff_resource = load(iff_directory + file_name)
				if iff_resource and iff_resource is IFFResource:
					var iff_name = iff_resource.name
					iff_database[iff_name] = iff_resource
			file_name = dir.get_next()
		dir.list_dir_end()


# Get an IFF resource by name
func get_iff(iff_name: String) -> IFFResource:
	return iff_database.get(iff_name, null)


# Check if one IFF attacks another
func does_iff_attack(attacker_iff: String, target_iff: String) -> bool:
	var iff_resource = get_iff(attacker_iff)
	if iff_resource:
		return target_iff in iff_resource.attacks
	return false


# Get how one IFF perceives another
func get_iff_perception(viewer_iff: String, target_iff: String) -> Color:
	var iff_resource = get_iff(viewer_iff)
	if iff_resource and iff_resource.perceptions.has(target_iff):
		return iff_resource.perceptions[target_iff]
	# Return the target's default color if no special perception
	var target_resource = get_iff(target_iff)
	if target_resource:
		return target_resource.display_color
	return Color(1, 1, 1, 1)  # Default to white


# Get the display color for an IFF
func get_iff_color(iff_name: String) -> Color:
	var iff_resource = get_iff(iff_name)
	if iff_resource:
		return iff_resource.display_color
	return Color(1, 1, 1, 1)  # Default to white
