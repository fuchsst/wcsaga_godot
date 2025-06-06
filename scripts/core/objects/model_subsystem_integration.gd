class_name ModelSubsystemIntegration
extends Node

## Model subsystem integration for BaseSpaceObject damage states and visual effects
## Integrates POF model subsystems converted by EPIC-003 with Godot visual effects
## Provides subsystem damage visualization and animation integration (AC7)

# EPIC-002 Asset Core Integration
const ModelMetadata = preload("res://addons/wcs_asset_core/resources/object/model_metadata.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

# Subsystem Integration Signals (AC7)
signal subsystem_created(space_object: BaseSpaceObject, subsystem_name: String, subsystem_node: Node3D)
signal subsystem_damage_applied(space_object: BaseSpaceObject, subsystem_name: String, damage_percentage: float)
signal subsystem_destroyed(space_object: BaseSpaceObject, subsystem_name: String)
signal subsystem_repaired(space_object: BaseSpaceObject, subsystem_name: String)

# WCS Subsystem Types (from original C++ model.h)
enum SubsystemType {
	NONE = 0,
	ENGINE = 1,
	TURRET = 2,
	RADAR = 3,
	NAVIGATION = 4,
	COMMUNICATION = 5,
	WEAPONS = 6,
	SENSORS = 7,
	SOLAR = 8,
	GAS_COLLECT = 9,
	ACTIVATION = 10,
	UNKNOWN = 11
}

# Damage state visual effects configuration
var _damage_effects_config: Dictionary = {
	"light_damage": {
		"health_threshold": 0.75,
		"color_tint": Color(0.9, 0.85, 0.85, 0.95),
		"particle_density": 0.2
	},
	"moderate_damage": {
		"health_threshold": 0.5,
		"color_tint": Color(0.8, 0.7, 0.7, 0.9),
		"particle_density": 0.5
	},
	"heavy_damage": {
		"health_threshold": 0.25,
		"color_tint": Color(0.6, 0.4, 0.4, 0.8),
		"particle_density": 1.0
	},
	"critical_damage": {
		"health_threshold": 0.1,
		"color_tint": Color(0.4, 0.2, 0.2, 0.6),
		"particle_density": 2.0
	}
}

# EPIC-008 Graphics integration
var graphics_engine: Node = null

func _ready() -> void:
	name = "ModelSubsystemIntegration"
	_initialize_graphics_integration()

## Initialize EPIC-008 Graphics integration
func _initialize_graphics_integration() -> void:
	graphics_engine = get_node_or_null("/root/GraphicsRenderingEngine")
	if graphics_engine:
		print("ModelSubsystemIntegration: Integrated with EPIC-008 Graphics Rendering Engine")

## Create subsystem nodes from POF model metadata (AC7)
func create_subsystems_from_metadata(space_object: BaseSpaceObject, metadata: ModelMetadata) -> bool:
	if not space_object or not metadata:
		return false
	
	# Create subsystem container node
	var subsystems_container: Node3D = Node3D.new()
	subsystems_container.name = "Subsystems"
	space_object.add_child(subsystems_container)
	
	# Create weapon subsystems from gun/missile banks
	_create_weapon_subsystems(space_object, metadata, subsystems_container)
	
	# Create engine subsystems from thruster banks
	_create_engine_subsystems(space_object, metadata, subsystems_container)
	
	# Create docking subsystems from docking points
	_create_docking_subsystems(space_object, metadata, subsystems_container)
	
	# Create generic subsystems based on model structure
	_create_generic_subsystems(space_object, metadata, subsystems_container)
	
	return true

## Create weapon subsystems from weapon banks
func _create_weapon_subsystems(space_object: BaseSpaceObject, metadata: ModelMetadata, container: Node3D) -> void:
	# Create primary weapon subsystems from gun banks
	for i in range(metadata.gun_banks.size()):
		var gun_bank: ModelMetadata.WeaponBank = metadata.gun_banks[i]
		var weapon_subsystem: Node3D = _create_subsystem_node("WeaponsPrimary_%d" % i, SubsystemType.WEAPONS)
		
		# Position subsystem at average of weapon bank points
		if gun_bank.points.size() > 0:
			var avg_position: Vector3 = Vector3.ZERO
			for point in gun_bank.points:
				avg_position += point.position
			avg_position /= gun_bank.points.size()
			weapon_subsystem.position = avg_position
		
		container.add_child(weapon_subsystem)
		subsystem_created.emit(space_object, weapon_subsystem.name, weapon_subsystem)
	
	# Create secondary weapon subsystems from missile banks
	for i in range(metadata.missile_banks.size()):
		var missile_bank: ModelMetadata.WeaponBank = metadata.missile_banks[i]
		var weapon_subsystem: Node3D = _create_subsystem_node("WeaponsSecondary_%d" % i, SubsystemType.WEAPONS)
		
		if missile_bank.points.size() > 0:
			var avg_position: Vector3 = Vector3.ZERO
			for point in missile_bank.points:
				avg_position += point.position
			avg_position /= missile_bank.points.size()
			weapon_subsystem.position = avg_position
		
		container.add_child(weapon_subsystem)
		subsystem_created.emit(space_object, weapon_subsystem.name, weapon_subsystem)

## Create engine subsystems from thruster banks
func _create_engine_subsystems(space_object: BaseSpaceObject, metadata: ModelMetadata, container: Node3D) -> void:
	for i in range(metadata.thruster_banks.size()):
		var thruster_bank: ModelMetadata.ThrusterBank = metadata.thruster_banks[i]
		var engine_subsystem: Node3D = _create_subsystem_node("Engine_%d" % i, SubsystemType.ENGINE)
		
		# Position engine subsystem at average of thruster points
		if thruster_bank.points.size() > 0:
			var avg_position: Vector3 = Vector3.ZERO
			for point in thruster_bank.points:
				avg_position += point.position
			avg_position /= thruster_bank.points.size()
			engine_subsystem.position = avg_position
			
			# Create thruster effect nodes for visual effects
			_create_thruster_effects(engine_subsystem, thruster_bank)
		
		container.add_child(engine_subsystem)
		subsystem_created.emit(space_object, engine_subsystem.name, engine_subsystem)

## Create docking subsystems from docking points
func _create_docking_subsystems(space_object: BaseSpaceObject, metadata: ModelMetadata, container: Node3D) -> void:
	for i in range(metadata.docking_points.size()):
		var dock_point: ModelMetadata.DockPoint = metadata.docking_points[i]
		var dock_subsystem: Node3D = _create_subsystem_node("Docking_%s" % dock_point.name, SubsystemType.ACTIVATION)
		
		if dock_point.points.size() > 0:
			dock_subsystem.position = dock_point.points[0].position
		
		container.add_child(dock_subsystem)
		subsystem_created.emit(space_object, dock_subsystem.name, dock_subsystem)

## Create generic subsystems for essential ship systems
func _create_generic_subsystems(space_object: BaseSpaceObject, metadata: ModelMetadata, container: Node3D) -> void:
	# Create radar subsystem near the center of the ship
	var radar_subsystem: Node3D = _create_subsystem_node("Radar", SubsystemType.RADAR)
	radar_subsystem.position = Vector3.ZERO  # Center of ship
	container.add_child(radar_subsystem)
	subsystem_created.emit(space_object, radar_subsystem.name, radar_subsystem)
	
	# Create navigation subsystem
	var nav_subsystem: Node3D = _create_subsystem_node("Navigation", SubsystemType.NAVIGATION)
	nav_subsystem.position = Vector3(0, 1, 0)  # Slightly above center
	container.add_child(nav_subsystem)
	subsystem_created.emit(space_object, nav_subsystem.name, nav_subsystem)
	
	# Create communication subsystem
	var comm_subsystem: Node3D = _create_subsystem_node("Communication", SubsystemType.COMMUNICATION)
	comm_subsystem.position = Vector3(0, 2, 0)  # Higher up for antenna placement
	container.add_child(comm_subsystem)
	subsystem_created.emit(space_object, comm_subsystem.name, comm_subsystem)

## Create base subsystem node with damage tracking
func _create_subsystem_node(subsystem_name: String, subsystem_type: SubsystemType) -> Node3D:
	var subsystem: Node3D = Node3D.new()
	subsystem.name = subsystem_name
	
	# Store subsystem metadata
	subsystem.set_meta("subsystem_type", subsystem_type)
	subsystem.set_meta("max_health", 100.0)
	subsystem.set_meta("current_health", 100.0)
	subsystem.set_meta("damage_state", "intact")
	
	# Add mesh instance for visual representation (placeholder)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "SubsystemMesh"
	
	# Create simple box mesh as subsystem representation
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3(0.5, 0.5, 0.5)
	mesh_instance.mesh = box_mesh
	
	subsystem.add_child(mesh_instance)
	
	return subsystem

## Create thruster visual effects for engine subsystem
func _create_thruster_effects(engine_subsystem: Node3D, thruster_bank: ModelMetadata.ThrusterBank) -> void:
	for i in range(thruster_bank.points.size()):
		var point: ModelMetadata.PointDefinition = thruster_bank.points[i]
		
		# Create thruster effect particle system
		var thruster_particles: GPUParticles3D = GPUParticles3D.new()
		thruster_particles.name = "ThrusterEffect_%d" % i
		thruster_particles.position = point.position - engine_subsystem.position
		thruster_particles.look_at(thruster_particles.position - point.normal, Vector3.UP)
		
		# Configure particle system for thruster effects
		thruster_particles.emitting = false  # Will be controlled by engine system
		thruster_particles.amount = 100
		thruster_particles.lifetime = 2.0
		
		engine_subsystem.add_child(thruster_particles)

## Apply damage state to specific subsystem (AC7)
func apply_subsystem_damage(space_object: BaseSpaceObject, subsystem_name: String, damage_amount: float) -> bool:
	var subsystem: Node3D = _find_subsystem(space_object, subsystem_name)
	if not subsystem:
		push_warning("ModelSubsystemIntegration: Subsystem '%s' not found on %s" % [subsystem_name, space_object.name])
		return false
	
	# Update subsystem health
	var current_health: float = subsystem.get_meta("current_health", 100.0)
	var max_health: float = subsystem.get_meta("max_health", 100.0)
	
	current_health = max(0.0, current_health - damage_amount)
	subsystem.set_meta("current_health", current_health)
	
	# Calculate damage percentage
	var damage_percentage: float = 1.0 - (current_health / max_health)
	
	# Apply visual damage effects
	_update_subsystem_visual_state(subsystem, damage_percentage)
	
	# Check for subsystem destruction
	if current_health <= 0.0:
		_destroy_subsystem(space_object, subsystem, subsystem_name)
	else:
		subsystem_damage_applied.emit(space_object, subsystem_name, damage_percentage)
	
	return true

## Update subsystem visual state based on damage percentage
func _update_subsystem_visual_state(subsystem: Node3D, damage_percentage: float) -> void:
	var mesh_instance: MeshInstance3D = subsystem.find_child("SubsystemMesh", false, false) as MeshInstance3D
	if not mesh_instance:
		return
	
	# Determine damage state and apply visual effects
	var damage_state: String = "intact"
	var effect_config: Dictionary = {}
	
	if damage_percentage >= 0.9:
		damage_state = "critical_damage"
		effect_config = _damage_effects_config["critical_damage"]
	elif damage_percentage >= 0.75:
		damage_state = "heavy_damage"
		effect_config = _damage_effects_config["heavy_damage"]
	elif damage_percentage >= 0.5:
		damage_state = "moderate_damage"
		effect_config = _damage_effects_config["moderate_damage"]
	elif damage_percentage >= 0.25:
		damage_state = "light_damage"
		effect_config = _damage_effects_config["light_damage"]
	
	subsystem.set_meta("damage_state", damage_state)
	
	# Apply visual effects
	if effect_config.size() > 0:
		mesh_instance.modulate = effect_config.get("color_tint", Color.WHITE)
		_update_damage_particles(subsystem, effect_config.get("particle_density", 0.0))
	else:
		mesh_instance.modulate = Color.WHITE
		_clear_damage_particles(subsystem)

## Update damage particle effects
func _update_damage_particles(subsystem: Node3D, particle_density: float) -> void:
	var damage_particles: GPUParticles3D = subsystem.find_child("DamageParticles", false, false) as GPUParticles3D
	
	if particle_density > 0.0:
		if not damage_particles:
			# Create damage particle system
			damage_particles = GPUParticles3D.new()
			damage_particles.name = "DamageParticles"
			damage_particles.emitting = true
			subsystem.add_child(damage_particles)
		
		# Configure particle density
		damage_particles.amount = int(50 * particle_density)
		damage_particles.emitting = true
	else:
		_clear_damage_particles(subsystem)

## Clear damage particle effects
func _clear_damage_particles(subsystem: Node3D) -> void:
	var damage_particles: Node = subsystem.find_child("DamageParticles", false, false)
	if damage_particles:
		damage_particles.queue_free()

## Destroy subsystem with visual effects
func _destroy_subsystem(space_object: BaseSpaceObject, subsystem: Node3D, subsystem_name: String) -> void:
	# Create destruction effect
	var destruction_particles: GPUParticles3D = GPUParticles3D.new()
	destruction_particles.name = "DestructionEffect"
	destruction_particles.position = subsystem.global_position
	destruction_particles.emitting = true
	destruction_particles.amount = 200
	destruction_particles.lifetime = 5.0
	
	# Add to parent for temporary effect
	space_object.add_child(destruction_particles)
	
	# Auto-remove after effect duration
	var timer: Timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	timer.timeout.connect(destruction_particles.queue_free)
	destruction_particles.add_child(timer)
	timer.start()
	
	# Hide/disable subsystem
	subsystem.visible = false
	subsystem.set_meta("destroyed", true)
	
	subsystem_destroyed.emit(space_object, subsystem_name)

## Repair subsystem to full health
func repair_subsystem(space_object: BaseSpaceObject, subsystem_name: String) -> bool:
	var subsystem: Node3D = _find_subsystem(space_object, subsystem_name)
	if not subsystem:
		return false
	
	# Restore subsystem health
	var max_health: float = subsystem.get_meta("max_health", 100.0)
	subsystem.set_meta("current_health", max_health)
	subsystem.set_meta("damage_state", "intact")
	subsystem.set_meta("destroyed", false)
	
	# Restore visual state
	subsystem.visible = true
	_update_subsystem_visual_state(subsystem, 0.0)
	
	subsystem_repaired.emit(space_object, subsystem_name)
	return true

## Get subsystem health percentage
func get_subsystem_health(space_object: BaseSpaceObject, subsystem_name: String) -> float:
	var subsystem: Node3D = _find_subsystem(space_object, subsystem_name)
	if not subsystem:
		return 0.0
	
	var current_health: float = subsystem.get_meta("current_health", 100.0)
	var max_health: float = subsystem.get_meta("max_health", 100.0)
	
	return current_health / max_health

## Find subsystem by name in space object
func _find_subsystem(space_object: BaseSpaceObject, subsystem_name: String) -> Node3D:
	var subsystems_container: Node = space_object.find_child("Subsystems", false, false)
	if not subsystems_container:
		return null
	
	return subsystems_container.find_child(subsystem_name, false, false) as Node3D

## Get all subsystems for space object
func get_all_subsystems(space_object: BaseSpaceObject) -> Array[Node3D]:
	var subsystems: Array[Node3D] = []
	var subsystems_container: Node = space_object.find_child("Subsystems", false, false)
	
	if subsystems_container:
		for child in subsystems_container.get_children():
			if child is Node3D:
				subsystems.append(child as Node3D)
	
	return subsystems

## Get subsystem statistics for debugging
func get_subsystem_stats(space_object: BaseSpaceObject) -> Dictionary:
	var stats: Dictionary = {
		"total_subsystems": 0,
		"intact_subsystems": 0,
		"damaged_subsystems": 0,
		"destroyed_subsystems": 0,
		"average_health": 0.0
	}
	
	var subsystems: Array[Node3D] = get_all_subsystems(space_object)
	stats["total_subsystems"] = subsystems.size()
	
	var total_health: float = 0.0
	
	for subsystem in subsystems:
		var current_health: float = subsystem.get_meta("current_health", 100.0)
		var max_health: float = subsystem.get_meta("max_health", 100.0)
		var health_percentage: float = current_health / max_health
		
		total_health += health_percentage
		
		if subsystem.get_meta("destroyed", false):
			stats["destroyed_subsystems"] += 1
		elif health_percentage < 1.0:
			stats["damaged_subsystems"] += 1
		else:
			stats["intact_subsystems"] += 1
	
	if subsystems.size() > 0:
		stats["average_health"] = total_health / subsystems.size()
	
	return stats