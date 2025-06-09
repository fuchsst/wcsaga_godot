class_name ShipArmorConfiguration
extends Node

## SHIP-011 AC4: Ship Armor Configuration
## Defines armor thickness, coverage areas, and vulnerable zones for realistic damage distribution
## Implements WCS-authentic ship-specific armor layouts and protection schemes

# EPIC-002 Asset Core Integration
const ArmorTypes = preload("res://addons/wcs_asset_core/constants/armor_types.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

# Signals
signal armor_configuration_loaded(ship_type: String, config_data: Dictionary)
signal armor_zone_hit(zone_name: String, hit_location: Vector3, armor_data: Dictionary)
signal vulnerable_zone_identified(zone_name: String, vulnerability_factor: float)
signal armor_coverage_analyzed(coverage_data: Dictionary)

# Armor configuration data
var ship_armor_configurations: Dictionary = {}
var armor_zones: Dictionary = {}
var coverage_maps: Dictionary = {}
var thickness_maps: Dictionary = {}

# Ship references
var owner_ship: Node = null
var ship_mesh: MeshInstance3D = null
var collision_shape: CollisionShape3D = null

# Configuration
@export var enable_dynamic_armor: bool = true
@export var enable_zone_visualization: bool = false
@export var enable_thickness_mapping: bool = true
@export var debug_armor_logging: bool = false

# Armor layout parameters
@export var default_armor_thickness: float = 1.0
@export var armor_thickness_variation: float = 0.5
@export var vulnerable_zone_threshold: float = 0.3
@export var critical_zone_threshold: float = 0.1

# Performance settings
@export var zone_detection_resolution: float = 0.5  # Meters
@export var thickness_map_resolution: int = 64      # Texture resolution
@export var max_armor_zones: int = 50              # Maximum zones per ship

func _ready() -> void:
	_setup_default_armor_configurations()

## Initialize armor configuration for a ship
func initialize_for_ship(ship: Node) -> void:
	owner_ship = ship
	
	# Find ship mesh and collision components
	ship_mesh = _find_ship_mesh(ship)
	collision_shape = _find_collision_shape(ship)
	
	if not ship_mesh:
		push_warning("ShipArmorConfiguration: No mesh found for ship %s" % ship.name)
		return
	
	# Determine ship type and load appropriate configuration
	var ship_type = _determine_ship_type(ship)
	_load_armor_configuration(ship_type)
	
	# Generate armor zones and thickness maps
	_generate_armor_zones()
	_generate_thickness_maps()
	
	if debug_armor_logging:
		print("ShipArmorConfiguration: Initialized for %s ship %s" % [ship_type, ship.name])

## Get armor data for specific hit location
func get_armor_data_at_location(hit_location: Vector3) -> Dictionary:
	var local_position = _world_to_local_position(hit_location)
	
	# Find the armor zone containing this location
	var zone_data = _find_armor_zone_at_position(local_position)
	if zone_data.is_empty():
		zone_data = _get_default_armor_data()
	
	# Get thickness at this location
	var thickness = _get_armor_thickness_at_position(local_position)
	
	# Calculate armor properties
	var armor_data: Dictionary = {
		"armor_type": zone_data.get("armor_type", ArmorTypes.Class.STANDARD),
		"base_thickness": zone_data.get("base_thickness", default_armor_thickness),
		"actual_thickness": thickness,
		"coverage_factor": zone_data.get("coverage_factor", 1.0),
		"zone_name": zone_data.get("zone_name", "hull"),
		"vulnerability_factor": zone_data.get("vulnerability_factor", 0.5),
		"surface_normal": _calculate_surface_normal(local_position),
		"structural_integrity": zone_data.get("structural_integrity", 1.0),
		"repair_difficulty": zone_data.get("repair_difficulty", 1.0)
	}
	
	# Emit signal for armor zone hit
	armor_zone_hit.emit(armor_data["zone_name"], hit_location, armor_data)
	
	if debug_armor_logging:
		print("ShipArmorConfiguration: Hit %s zone at %.1f thickness" % [
			armor_data["zone_name"], armor_data["actual_thickness"]
		])
	
	return armor_data

## Get all vulnerable zones for tactical targeting
func get_vulnerable_zones() -> Array[Dictionary]:
	var vulnerable_zones: Array[Dictionary] = []
	
	for zone_name in armor_zones.keys():
		var zone_data = armor_zones[zone_name]
		var vulnerability = zone_data.get("vulnerability_factor", 0.5)
		
		if vulnerability >= vulnerable_zone_threshold:
			vulnerable_zones.append({
				"zone_name": zone_name,
				"vulnerability_factor": vulnerability,
				"location": zone_data.get("center_position", Vector3.ZERO),
				"size": zone_data.get("zone_size", 1.0),
				"armor_type": zone_data.get("armor_type", ArmorTypes.Class.STANDARD),
				"thickness": zone_data.get("base_thickness", default_armor_thickness),
				"targeting_priority": _calculate_targeting_priority(zone_data)
			})
			
			vulnerable_zone_identified.emit(zone_name, vulnerability)
	
	# Sort by vulnerability (highest first)
	vulnerable_zones.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["vulnerability_factor"] > b["vulnerability_factor"]
	)
	
	return vulnerable_zones

## Get armor coverage analysis
func get_armor_coverage_analysis() -> Dictionary:
	var total_surface_area = _calculate_total_surface_area()
	var covered_area = 0.0
	var average_thickness = 0.0
	var zone_count = armor_zones.size()
	var vulnerable_area = 0.0
	
	for zone_data in armor_zones.values():
		var zone_area = zone_data.get("surface_area", 1.0)
		var zone_coverage = zone_data.get("coverage_factor", 1.0)
		var zone_thickness = zone_data.get("base_thickness", default_armor_thickness)
		var zone_vulnerability = zone_data.get("vulnerability_factor", 0.5)
		
		covered_area += zone_area * zone_coverage
		average_thickness += zone_thickness * zone_area
		
		if zone_vulnerability >= vulnerable_zone_threshold:
			vulnerable_area += zone_area
	
	if total_surface_area > 0.0:
		average_thickness /= total_surface_area
	
	var coverage_data: Dictionary = {
		"total_surface_area": total_surface_area,
		"covered_area": covered_area,
		"coverage_percentage": (covered_area / max(total_surface_area, 1.0)) * 100.0,
		"average_thickness": average_thickness,
		"armor_zone_count": zone_count,
		"vulnerable_area": vulnerable_area,
		"vulnerability_percentage": (vulnerable_area / max(total_surface_area, 1.0)) * 100.0,
		"armor_mass": _calculate_total_armor_mass(),
		"protection_rating": _calculate_protection_rating()
	}
	
	armor_coverage_analyzed.emit(coverage_data)
	
	return coverage_data

## Setup default armor configurations for different ship types
func _setup_default_armor_configurations() -> void:
	ship_armor_configurations = {
		"fighter": {
			"default_armor_type": ArmorTypes.Class.LIGHT,
			"base_thickness": 0.5,
			"armor_zones": [
				{
					"name": "nose",
					"armor_type": ArmorTypes.Class.LIGHT,
					"thickness": 0.3,
					"vulnerability": 0.7,
					"position": Vector3(0, 0, 2),
					"size": Vector3(1, 1, 1)
				},
				{
					"name": "cockpit",
					"armor_type": ArmorTypes.Class.LIGHT,
					"thickness": 0.2,
					"vulnerability": 0.9,
					"position": Vector3(0, 0.5, 1),
					"size": Vector3(0.8, 0.6, 0.8)
				},
				{
					"name": "engines",
					"armor_type": ArmorTypes.Class.LIGHT,
					"thickness": 0.4,
					"vulnerability": 0.8,
					"position": Vector3(0, 0, -2),
					"size": Vector3(1.2, 0.8, 1.5)
				},
				{
					"name": "wings",
					"armor_type": ArmorTypes.Class.LIGHT,
					"thickness": 0.2,
					"vulnerability": 0.6,
					"position": Vector3(0, 0, 0),
					"size": Vector3(3, 0.3, 2)
				}
			]
		},
		
		"bomber": {
			"default_armor_type": ArmorTypes.Class.STANDARD,
			"base_thickness": 1.0,
			"armor_zones": [
				{
					"name": "nose",
					"armor_type": ArmorTypes.Class.STANDARD,
					"thickness": 0.8,
					"vulnerability": 0.5,
					"position": Vector3(0, 0, 3),
					"size": Vector3(1.5, 1.5, 1.5)
				},
				{
					"name": "cockpit",
					"armor_type": ArmorTypes.Class.STANDARD,
					"thickness": 0.6,
					"vulnerability": 0.7,
					"position": Vector3(0, 1, 2),
					"size": Vector3(1, 0.8, 1)
				},
				{
					"name": "bomb_bay",
					"armor_type": ArmorTypes.Class.LIGHT,
					"thickness": 0.4,
					"vulnerability": 0.9,
					"position": Vector3(0, -0.5, 0),
					"size": Vector3(2, 1, 3)
				},
				{
					"name": "engines",
					"armor_type": ArmorTypes.Class.STANDARD,
					"thickness": 1.2,
					"vulnerability": 0.6,
					"position": Vector3(0, 0, -3),
					"size": Vector3(2, 1, 2)
				}
			]
		},
		
		"capital": {
			"default_armor_type": ArmorTypes.Class.HEAVY,
			"base_thickness": 3.0,
			"armor_zones": [
				{
					"name": "bridge",
					"armor_type": ArmorTypes.Class.HEAVY,
					"thickness": 2.0,
					"vulnerability": 0.8,
					"position": Vector3(0, 5, 10),
					"size": Vector3(3, 2, 4)
				},
				{
					"name": "hull_forward",
					"armor_type": ArmorTypes.Class.HEAVY,
					"thickness": 4.0,
					"vulnerability": 0.3,
					"position": Vector3(0, 0, 15),
					"size": Vector3(8, 6, 10)
				},
				{
					"name": "hull_mid",
					"armor_type": ArmorTypes.Class.HEAVY,
					"thickness": 5.0,
					"vulnerability": 0.2,
					"position": Vector3(0, 0, 0),
					"size": Vector3(10, 8, 15)
				},
				{
					"name": "engine_section",
					"armor_type": ArmorTypes.Class.HEAVY,
					"thickness": 3.5,
					"vulnerability": 0.6,
					"position": Vector3(0, 0, -20),
					"size": Vector3(6, 6, 12)
				},
				{
					"name": "weapon_turrets",
					"armor_type": ArmorTypes.Class.STANDARD,
					"thickness": 2.5,
					"vulnerability": 0.7,
					"position": Vector3(0, 3, 5),
					"size": Vector3(12, 4, 8)
				}
			]
		}
	}

## Determine ship type from ship node
func _determine_ship_type(ship: Node) -> String:
	# Try to get ship type from ship data if available
	if ship.has_method("get_ship_type"):
		return ship.get_ship_type()
	
	# Try to get from object type
	if ship.has_method("get_object_type_enum"):
		var object_type = ship.get_object_type_enum()
		match object_type:
			ObjectTypes.Type.FIGHTER:
				return "fighter"
			ObjectTypes.Type.BOMBER:
				return "bomber"
			ObjectTypes.Type.CAPITAL:
				return "capital"
	
	# Default based on size or name
	var ship_scale = _estimate_ship_scale(ship)
	if ship_scale < 5.0:
		return "fighter"
	elif ship_scale < 15.0:
		return "bomber"
	else:
		return "capital"

## Load armor configuration for ship type
func _load_armor_configuration(ship_type: String) -> void:
	var config = ship_armor_configurations.get(ship_type, ship_armor_configurations["fighter"])
	
	# Clear existing data
	armor_zones.clear()
	
	# Load armor zones from configuration
	var zone_configs = config.get("armor_zones", [])
	for zone_config in zone_configs:
		var zone_name = zone_config["name"]
		armor_zones[zone_name] = {
			"zone_name": zone_name,
			"armor_type": zone_config.get("armor_type", ArmorTypes.Class.STANDARD),
			"base_thickness": zone_config.get("thickness", default_armor_thickness),
			"vulnerability_factor": zone_config.get("vulnerability", 0.5),
			"center_position": zone_config.get("position", Vector3.ZERO),
			"zone_size": zone_config.get("size", Vector3.ONE).length(),
			"bounds": AABB(
				zone_config.get("position", Vector3.ZERO) - zone_config.get("size", Vector3.ONE) * 0.5,
				zone_config.get("size", Vector3.ONE)
			),
			"surface_area": _calculate_zone_surface_area(zone_config.get("size", Vector3.ONE)),
			"coverage_factor": 1.0,
			"structural_integrity": 1.0,
			"repair_difficulty": 1.0
		}
	
	armor_configuration_loaded.emit(ship_type, config)

## Generate armor zones based on ship mesh
func _generate_armor_zones() -> void:
	if not ship_mesh or not ship_mesh.mesh:
		return
	
	# If we already have configured zones, enhance them with mesh data
	if not armor_zones.is_empty():
		_enhance_zones_with_mesh_data()
		return
	
	# Generate zones automatically from mesh geometry
	_auto_generate_zones_from_mesh()

## Generate thickness maps for armor zones
func _generate_thickness_maps() -> void:
	thickness_maps.clear()
	
	for zone_name in armor_zones.keys():
		var zone_data = armor_zones[zone_name]
		thickness_maps[zone_name] = _create_thickness_map(zone_data)

## Find ship mesh component
func _find_ship_mesh(ship: Node) -> MeshInstance3D:
	# Look for MeshInstance3D in ship hierarchy
	var mesh_nodes = _find_mesh_instance_nodes(ship)
	
	# Prefer nodes with "hull" or "mesh" in the name
	for mesh_node in mesh_nodes:
		var node_name = mesh_node.name.to_lower()
		if "hull" in node_name or "mesh" in node_name or "model" in node_name:
			return mesh_node
	
	# Return first MeshInstance3D found
	if not mesh_nodes.is_empty():
		return mesh_nodes[0]
	
	return null

## Find collision shape component
func _find_collision_shape(ship: Node) -> CollisionShape3D:
	var collision_nodes = _find_collision_shape_nodes(ship)
	return collision_nodes[0] if not collision_nodes.is_empty() else null

## Find MeshInstance3D nodes in hierarchy
func _find_mesh_instance_nodes(root: Node) -> Array[MeshInstance3D]:
	var found_nodes: Array[MeshInstance3D] = []
	_search_mesh_recursive(root, found_nodes)
	return found_nodes

## Find CollisionShape3D nodes in hierarchy
func _find_collision_shape_nodes(root: Node) -> Array[CollisionShape3D]:
	var found_nodes: Array[CollisionShape3D] = []
	_search_collision_recursive(root, found_nodes)
	return found_nodes

## Recursive search for MeshInstance3D
func _search_mesh_recursive(node: Node, found_nodes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		found_nodes.append(node as MeshInstance3D)
	
	for child in node.get_children():
		_search_mesh_recursive(child, found_nodes)

## Recursive search for CollisionShape3D
func _search_collision_recursive(node: Node, found_nodes: Array[CollisionShape3D]) -> void:
	if node is CollisionShape3D:
		found_nodes.append(node as CollisionShape3D)
	
	for child in node.get_children():
		_search_collision_recursive(child, found_nodes)

## Convert world position to local ship coordinates
func _world_to_local_position(world_pos: Vector3) -> Vector3:
	if owner_ship:
		return owner_ship.global_transform.inverse() * world_pos
	return world_pos

## Find armor zone containing position
func _find_armor_zone_at_position(local_pos: Vector3) -> Dictionary:
	for zone_data in armor_zones.values():
		var bounds = zone_data.get("bounds", AABB())
		if bounds.has_point(local_pos):
			return zone_data
	
	return {}

## Get armor thickness at specific position
func _get_armor_thickness_at_position(local_pos: Vector3) -> float:
	# Find zone and interpolate thickness
	var zone_data = _find_armor_zone_at_position(local_pos)
	if zone_data.is_empty():
		return default_armor_thickness
	
	var base_thickness = zone_data.get("base_thickness", default_armor_thickness)
	
	# Add variation based on position within zone
	var zone_center = zone_data.get("center_position", Vector3.ZERO)
	var distance_factor = local_pos.distance_to(zone_center) / zone_data.get("zone_size", 1.0)
	var thickness_variation = armor_thickness_variation * (0.5 - distance_factor)
	
	return base_thickness + thickness_variation

## Calculate surface normal at position
func _calculate_surface_normal(local_pos: Vector3) -> Vector3:
	# Simplified normal calculation - would use mesh data in real implementation
	return local_pos.normalized()

## Calculate targeting priority for zone
func _calculate_targeting_priority(zone_data: Dictionary) -> float:
	var vulnerability = zone_data.get("vulnerability_factor", 0.5)
	var thickness = zone_data.get("base_thickness", default_armor_thickness)
	var size = zone_data.get("zone_size", 1.0)
	
	# Higher priority for vulnerable, thin, large targets
	return vulnerability * (2.0 - thickness) * sqrt(size)

## Calculate total surface area
func _calculate_total_surface_area() -> float:
	if not ship_mesh or not ship_mesh.mesh:
		return 100.0  # Default estimate
	
	# Would calculate from mesh in real implementation
	return 100.0

## Calculate zone surface area
func _calculate_zone_surface_area(size: Vector3) -> float:
	# Simplified box surface area calculation
	return 2.0 * (size.x * size.y + size.y * size.z + size.z * size.x)

## Calculate total armor mass
func _calculate_total_armor_mass() -> float:
	var total_mass = 0.0
	
	for zone_data in armor_zones.values():
		var volume = zone_data.get("surface_area", 1.0) * zone_data.get("base_thickness", default_armor_thickness)
		var density = _get_armor_density(zone_data.get("armor_type", ArmorTypes.Class.STANDARD))
		total_mass += volume * density
	
	return total_mass

## Calculate protection rating
func _calculate_protection_rating() -> float:
	var coverage_analysis = get_armor_coverage_analysis()
	var coverage_score = coverage_analysis["coverage_percentage"] / 100.0
	var thickness_score = min(coverage_analysis["average_thickness"] / 2.0, 1.0)
	var vulnerability_penalty = coverage_analysis["vulnerability_percentage"] / 100.0
	
	return clamp((coverage_score + thickness_score) * (1.0 - vulnerability_penalty * 0.5), 0.0, 1.0)

## Get armor density for mass calculation
func _get_armor_density(armor_type: int) -> float:
	match armor_type:
		ArmorTypes.Class.LIGHT:
			return 2.0
		ArmorTypes.Class.STANDARD:
			return 4.0
		ArmorTypes.Class.HEAVY:
			return 8.0
		_:
			return 4.0

## Estimate ship scale for type determination
func _estimate_ship_scale(ship: Node) -> float:
	if ship_mesh and ship_mesh.mesh:
		var aabb = ship_mesh.mesh.get_aabb()
		return max(aabb.size.x, aabb.size.y, aabb.size.z)
	
	return 5.0  # Default fighter scale

## Get default armor data
func _get_default_armor_data() -> Dictionary:
	return {
		"armor_type": ArmorTypes.Class.STANDARD,
		"base_thickness": default_armor_thickness,
		"coverage_factor": 1.0,
		"zone_name": "hull",
		"vulnerability_factor": 0.5,
		"structural_integrity": 1.0,
		"repair_difficulty": 1.0
	}

## Enhance existing zones with mesh data
func _enhance_zones_with_mesh_data() -> void:
	# Implementation would analyze mesh geometry to refine zone boundaries
	pass

## Auto-generate zones from mesh
func _auto_generate_zones_from_mesh() -> void:
	# Implementation would analyze mesh to automatically create armor zones
	# For now, create basic zones
	armor_zones["hull"] = _get_default_armor_data()

## Create thickness map for zone
func _create_thickness_map(zone_data: Dictionary) -> Dictionary:
	return {
		"base_thickness": zone_data.get("base_thickness", default_armor_thickness),
		"variation_map": [],  # Would contain thickness variation data
		"resolution": thickness_map_resolution
	}