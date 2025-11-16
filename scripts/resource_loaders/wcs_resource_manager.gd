# WCSResourceManager - Simplified Resource Management System
# Basic resource loading and registration without complex caching or optimization

@tool
class_name WCSResourceManager
extends Node

# Basic configuration
@export var resources_base_path: String = "res://data/converted/"
@export var enable_auto_load: bool = true

# Simple resource registries
var species_registry: Dictionary = {}
var ship_registry: Dictionary = {}
var weapon_registry: Dictionary = {}
var environmental_registry: Dictionary = {}
var effect_registry: Dictionary = {}
var audio_registry: Dictionary = {}

# Simple resource tracking
var loaded_resources: Dictionary = {}
var resource_files: Dictionary = {}

signal resource_loaded(resource_type: String, resource_id: String, resource: Resource)
signal resource_unloaded(resource_type: String, resource_id: String)

func _ready():
	print("Initializing WCS Resource Manager (simplified)...")
	initialize_resource_system()
	print("WCS Resource Manager ready")

func initialize_resource_system():
	"""Initialize basic resource system"""
	if enable_auto_load:
		load_all_resources()

func load_all_resources() -> void:
	"""Load all WCS resources"""
	print("Loading WCS resources...")
	
	load_species_resources()
	load_ship_resources()
	load_weapon_resources()
	load_environmental_resources()
	load_effect_resources()
	load_audio_resources()
	
	print("Resource loading complete")

func load_species_resources() -> void:
	"""Load species resources"""
	var species_paths = [
		"terran_species.tres",
		"kilrathi_species.tres"
	]
	
	for species_file in species_paths:
		var resource_path = get_species_path(species_file)
		if ResourceLoader.exists(resource_path):
			_load_single_species(resource_path, species_file.get_basename())

func _load_single_species(resource_path: String, species_id: String) -> void:
	var resource = load(resource_path)
	if resource:
		species_registry[species_id] = resource
		loaded_resources["species:" + species_id] = resource
		resource_loaded.emit("species", species_id, resource)

func load_ship_resources() -> void:
	"""Load ship resources"""
	var ship_classes = [
		"F-86C_Hellcat_V",
		"F-27B_Arrow", 
		"F-66A_Thunderbolt_VII",
		"F-44A_Rapier_II"
	]
	
	for ship_class in ship_classes:
		var resource_path = get_ship_path(ship_class + ".tres")
		if ResourceLoader.exists(resource_path):
			_load_single_ship(resource_path, ship_class)

func _load_single_ship(resource_path: String, ship_class: String) -> void:
	var resource = load(resource_path)
	if resource:
		ship_registry[ship_class] = resource
		loaded_resources["ship:" + ship_class] = resource
		resource_loaded.emit("ship", ship_class, resource)

func load_weapon_resources() -> void:
	"""Load weapon resources"""
	var weapon_classes = [
		"Ion",
		"Neutron", 
		"Laser",
		"Particle",
		"Mass_Driver"
	]
	
	for weapon_class in weapon_classes:
		var resource_path = get_weapon_path(weapon_class + ".tres")
		if ResourceLoader.exists(resource_path):
			_load_single_weapon(resource_path, weapon_class)

func _load_single_weapon(resource_path: String, weapon_class: String) -> void:
	var resource = load(resource_path)
	if resource:
		weapon_registry[weapon_class] = resource
		loaded_resources["weapon:" + weapon_class] = resource
		resource_loaded.emit("weapon", weapon_class, resource)

func load_environmental_resources() -> void:
	"""Load environmental resources"""
	var env_files = [
		"alpha_belt.tres",
		"kilrah_debris.tres",
		"tigers_claw_nebula.tres"
	]
	
	for env_file in env_files:
		var resource_path = get_environment_path(env_file)
		if ResourceLoader.exists(resource_path):
			var env_id = env_file.get_basename()
			_load_single_environment(resource_path, env_id)

func _load_single_environment(resource_path: String, env_id: String) -> void:
	var resource = load(resource_path)
	if resource:
		environmental_registry[env_id] = resource
		loaded_resources["environment:" + env_id] = resource
		resource_loaded.emit("environment", env_id, resource)

func load_effect_resources() -> void:
	"""Load effect resources"""
	var effect_files = [
		"muzzle_flash.tres",
		"explosion.tres",
		"shield_impact.tres"
	]
	
	for effect_file in effect_files:
		var resource_path = "res://effects/" + effect_file
		if ResourceLoader.exists(resource_path):
			var effect_id = effect_file.get_basename()
			_load_single_effect(resource_path, effect_id)

func _load_single_effect(resource_path: String, effect_id: String) -> void:
	var resource = load(resource_path)
	if resource:
		effect_registry[effect_id] = resource
		loaded_resources["effect:" + effect_id] = resource
		resource_loaded.emit("effect", effect_id, resource)

func load_audio_resources() -> void:
	"""Load audio resources"""
	var audio_files = [
		"ion_fire.ogg",
		"engine_idle.ogg",
		"alert_general.ogg"
	]
	
	for audio_file in audio_files:
		var resource_path = "res://audio/" + audio_file
		if ResourceLoader.exists(resource_path):
			var audio_id = audio_file.get_basename()
			_load_single_audio(resource_path, audio_id)

func _load_single_audio(resource_path: String, audio_id: String) -> void:
	var resource = load(resource_path)
	if resource:
		audio_registry[audio_id] = resource
		loaded_resources["audio:" + audio_id] = resource
		resource_loaded.emit("audio", audio_id, resource)

# ================== RESOURCE ACCESS API ==================

func get_species(species_id: String) -> Resource:
	"""Get species resource by ID"""
	return species_registry.get(species_id, null)

func get_ship(ship_class: String) -> Resource:
	"""Get ship resource by class"""
	return ship_registry.get(ship_class, null)

func get_weapon(weapon_class: String) -> Resource:
	"""Get weapon resource by class"""
	return weapon_registry.get(weapon_class, null)

func get_environment(env_id: String) -> Resource:
	"""Get environmental resource by ID"""
	return environmental_registry.get(env_id, null)

func get_effect(effect_id: String) -> Resource:
	"""Get effect resource by ID"""
	return effect_registry.get(effect_id, null)

func get_audio(audio_id: String) -> Resource:
	"""Get audio resource by ID"""
	return audio_registry.get(audio_id, null)

func get_loaded_resource(resource_key: String) -> Resource:
	"""Get any loaded resource by key (format: type:id)"""
	return loaded_resources.get(resource_key, null)

# ================== RESOURCE MANAGEMENT ==================

func register_resource(resource_id: String, resource_type: String, resource: Resource) -> void:
	"""Register a resource manually"""
	loaded_resources[resource_type + ":" + resource_id] = resource
	
	match resource_type:
		"species":
			species_registry[resource_id] = resource
		"ship":
			ship_registry[resource_id] = resource
		"weapon":
			weapon_registry[resource_id] = resource
		"environment":
			environmental_registry[resource_id] = resource
		"effect":
			effect_registry[resource_id] = resource
		"audio":
			audio_registry[resource_id] = resource

func unload_resource(resource_key: String) -> bool:
	"""Unload a resource"""
	if not loaded_resources.has(resource_key):
		return false
	
	var resource_type = resource_key.split(":")[0]
	var resource_id = resource_key.split(":")[1]
	
	# Remove from registries
	match resource_type:
		"species":
			species_registry.erase(resource_id)
		"ship":
			ship_registry.erase(resource_id)
		"weapon":
			weapon_registry.erase(resource_id)
		"environment":
			environmental_registry.erase(resource_id)
		"effect":
			effect_registry.erase(resource_id)
		"audio":
			audio_registry.erase(resource_id)
	
	loaded_resources.erase(resource_key)
	resource_unloaded.emit(resource_type, resource_id)
	return true

func is_resource_loaded(resource_key: String) -> bool:
	"""Check if a resource is loaded"""
	return loaded_resources.has(resource_key)

# ================== STATISTICS ==================

func get_resource_count() -> int:
	"""Get total number of loaded resources"""
	return loaded_resources.size()

func get_registry_counts() -> Dictionary:
	"""Get count of resources in each registry"""
	return {
		"species": species_registry.size(),
		"ships": ship_registry.size(),
		"weapons": weapon_registry.size(),
		"environments": environmental_registry.size(),
		"effects": effect_registry.size(),
		"audio": audio_registry.size(),
		"total": get_resource_count()
	}

func get_loaded_resource_keys() -> Array:
	"""Get all loaded resource keys"""
	return loaded_resources.keys()

# ================== PATH HELPERS ==================

func get_species_path(species_file: String) -> String:
	"""Get species resource path"""
	return resources_base_path + "species/" + species_file

func get_ship_path(ship_file: String) -> String:
	"""Get ship resource path"""
	return resources_base_path + "ships/" + ship_file

func get_weapon_path(weapon_file: String) -> String:
	"""Get weapon resource path"""
	return resources_base_path + "weapons/" + weapon_file

func get_environment_path(env_file: String) -> String:
	"""Get environment resource path"""
	return resources_base_path + "environment/" + env_file