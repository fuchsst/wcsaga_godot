# AsteroidData - Asteroid Properties Resource
# Holds configuration data for asteroids, loaded from asteroid.tbl

class_name AsteroidData
extends Resource

# === BASIC PROPERTIES ===
@export_group("Identity")
@export var asteroid_name: String = ""  ## Asteroid type name
@export var resource_identifier: String = ""  ## Unique ID

# === LOD CONFIGURATION ===
@export_group("LOD System")
@export var lod_distances: Array[float] = [1000.0, 2000.0, 5000.0]  ## Distances to switch LODs
# Note: Actual models are child nodes in the scene, not stored here

# === PHYSICS ===
@export_group("Physics")
@export var max_speed: float = 60.0  ## Maximum rotation/drift speed in m/s
@export var hitpoints: float = 100.0  ## Durability

# === EXPLOSION PROPERTIES ===
@export_group("Explosion")
@export var explosion_inner_radius: float = 0.0
@export var explosion_outer_radius: float = 0.0
@export var explosion_damage: float = 0.0
@export var explosion_blast: float = 0.0

# === IMPACT EFFECTS ===
@export_group("Impact Effects")
@export var impact_explosion_effect: String = ""
@export var impact_explosion_radius: float = 20.0


func get_resource_type() -> String:
	return "asteroid_data"


func has_area_damage() -> bool:
	return explosion_damage > 0.0 and explosion_outer_radius > 0.0


func get_size_category() -> String:
	if hitpoints < 30:
		return "small"
	elif hitpoints < 80:
		return "medium"
	else:
		return "large"
