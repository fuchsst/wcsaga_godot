# scripts/core_systems/species_manager.gd
# Singleton (Autoload) responsible for loading and managing SpeciesInfo resources.
class_name SpeciesManager
extends Node

# Dictionary to store loaded SpeciesInfo resources, keyed by species name (lowercase)
var species_data: Dictionary = {}

# Default species info if lookup fails
var default_species: SpeciesInfo = null

func _ready():
	load_species_data("res://resources/game_data/species/") # Adjust path as needed
	# Set a default fallback (e.g., Terran)
	if species_data.has("terran"):
		default_species = species_data["terran"]
	elif not species_data.is_empty():
		# Fallback to the first loaded species if Terran isn't found
		default_species = species_data.values()[0]
	else:
		# Create a very basic default if nothing loaded
		printerr("SpeciesManager: No species data loaded, creating basic default.")
		default_species = SpeciesInfo.new()
		default_species.species_name = "Default"
		default_species.default_iff_name = "Hostile" # Safer default?
		default_species.awacs_multiplier = 1.0

	print("SpeciesManager initialized. Loaded %d species." % species_data.size())

func load_species_data(directory_path: String):
	species_data.clear()
	var dir = DirAccess.open(directory_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var species_res = load(directory_path.path_join(file_name)) as SpeciesInfo
				if species_res:
					var key = species_res.species_name.to_lower()
					if species_data.has(key):
						printerr("SpeciesManager: Duplicate species name found: %s" % species_res.species_name)
					else:
						species_data[key] = species_res
						#print("Loaded Species: ", species_res.species_name)
				else:
					printerr("SpeciesManager: Failed to load SpeciesInfo resource: %s" % file_name)
			file_name = dir.get_next()
		dir.list_dir_end() # Close the directory handle
	else:
		printerr("SpeciesManager: Could not open species directory: %s" % directory_path)

# Get SpeciesInfo by name (case-insensitive)
func get_species_info_by_name(species_name: String) -> SpeciesInfo:
	if species_name.is_empty():
		return default_species
	var key = species_name.to_lower()
	return species_data.get(key, default_species)

# Get SpeciesInfo by index (assuming indices correspond to load order or a defined enum)
# Note: The original game likely used indices. We need a mapping if using indices.
# For now, provide a placeholder or rely on name lookup.
func get_species_info_by_index(index: int) -> SpeciesInfo:
	# TODO: Implement index-based lookup if required. Needs a defined order.
	# This might involve storing species in an Array as well, or mapping indices.
	if index >= 0 and index < species_data.size():
		# WARNING: Dictionary order is not guaranteed! This is unreliable.
		# A better approach is needed if index lookup is critical.
		return species_data.values()[index]
	printerr("SpeciesManager: Index lookup (%d) is unreliable or out of bounds." % index)
	return default_species

# Get the index for a species name (reverse lookup)
func get_species_index(species_name: String) -> int:
	# TODO: Implement index lookup if required.
	var key = species_name.to_lower()
	var index = 0
	for name in species_data.keys():
		if name == key:
			return index
		index += 1
	return -1 # Not found
