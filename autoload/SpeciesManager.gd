# SpeciesManager - Species Definition Manager
# Autoload singleton for managing species data (thrusters, debris, AWACS, flyby sounds)
# Based on legacy species_defs.cpp functionality

extends Node

## Emitted when species data is loaded or reloaded
signal species_data_loaded

# ==============================================================================
# REGISTRY (typed array as per implementation plan)
# ==============================================================================

## All registered species definitions
@export var species_registry: Array[SpeciesData] = []

# ==============================================================================
# INITIALIZATION
# ==============================================================================


func _ready() -> void:
	print("SpeciesManager: Initializing...")


## Load species definitions from a manifest resource
func load_from_manifest(manifest: SpeciesManifest) -> void:
	if not manifest:
		push_error("SpeciesManager: Cannot load null manifest")
		return

	# Clear existing data
	species_registry.clear()

	# Copy species from manifest
	for species in manifest.species_list:
		if species:
			species_registry.append(species)

	print("SpeciesManager: Loaded %d species from manifest" % species_registry.size())
	species_data_loaded.emit()


## Load species definitions from a resource path
func load_from_path(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("SpeciesManager: Manifest not found at: %s" % path)
		return

	var manifest: SpeciesManifest = ResourceLoader.load(path) as SpeciesManifest
	load_from_manifest(manifest)


# ==============================================================================
# LOOKUP API
# ==============================================================================


## Get species by name
func get_species(species_name: String) -> SpeciesData:
	for species in species_registry:
		if species.species_name == species_name:
			return species
	return null


## Get species by index
func get_species_by_index(index: int) -> SpeciesData:
	if index >= 0 and index < species_registry.size():
		return species_registry[index]
	return null


## Get all registered species names
func get_species_names() -> Array[String]:
	var names: Array[String] = []
	for species in species_registry:
		names.append(species.species_name)
	return names


# ==============================================================================
# SPECIES PROPERTIES API
# ==============================================================================


## Get the default IFF for a species (returns IFFResource via IFFManager)
func get_default_iff(species: SpeciesData) -> IFFResource:
	if not species:
		return null

	# Use IFFManager to look up the IFF by name
	if IFFManager and species.default_iff:
		return IFFManager.get_iff(species.default_iff)
	return null


## Get AWACS multiplier for a species
func get_awacs_multiplier(species: SpeciesData) -> float:
	if not species:
		return 1.0
	return species.awacs_multiplier


## Get thruster animation for a species
func get_thruster_anim(species: SpeciesData, afterburn: bool) -> SpriteFrames:
	if not species:
		return null
	return species.thruster_afterburn if afterburn else species.thruster_normal


## Get secondary thruster animation
func get_thruster_secondary(species: SpeciesData, afterburn: bool) -> SpriteFrames:
	if not species:
		return null
	return species.thruster_secondary_afterburn if afterburn else species.thruster_secondary_normal


## Get tertiary thruster animation
func get_thruster_tertiary(species: SpeciesData, afterburn: bool) -> SpriteFrames:
	if not species:
		return null
	return species.thruster_tertiary_afterburn if afterburn else species.thruster_tertiary_normal


## Get thruster glow texture
func get_glow(species: SpeciesData, afterburn: bool) -> Texture2D:
	if not species:
		return null
	return species.glow_afterburn if afterburn else species.glow_normal


## Get flyby sound for a species
func get_flyby_sound(species: SpeciesData, is_bomber: bool) -> AudioStream:
	if not species:
		return null
	return species.flyby_bomber if is_bomber else species.flyby_fighter


## Get debris texture for a species
func get_debris_texture(species: SpeciesData) -> Texture2D:
	if not species:
		return null
	return species.debris_texture


## Get shield hit animation for a species
func get_shield_anim(species: SpeciesData) -> SpriteFrames:
	if not species:
		return null
	return species.shield_hit_anim
