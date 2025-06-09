class_name ExplosionSystem
extends Node

## SHIP-012 AC2: Explosion System
## Creates realistic detonations with particle effects, shockwaves, and environmental interaction
## Implements WCS-authentic explosion mechanics with scalable blast effects

# EPIC-002 Asset Core Integration
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const WeaponTypes = preload("res://addons/wcs_asset_core/constants/weapon_types.gd")

# Signals
signal explosion_created(explosion_data: Dictionary, explosion_instance: Node3D)
signal explosion_shockwave_impact(affected_object: Node, shockwave_data: Dictionary)
signal explosion_chain_reaction(original_explosion: Dictionary, triggered_explosion: Dictionary)
signal explosion_environmental_effect(explosion_location: Vector3, effect_type: String, effect_data: Dictionary)

# Explosion configuration
var explosion_templates: Dictionary = {}
var active_explosions: Array[Node3D] = []
var explosion_effect_pool: Dictionary = {}
var chain_reaction_tracker: Dictionary = {}

# Environmental interaction
var affected_objects: Array[Node] = []
var shockwave_propagation_data: Dictionary = {}
var environmental_effects: Array[Node3D] = []

# Configuration
@export var enable_shockwave_physics: bool = true
@export var enable_chain_reactions: bool = true
@export var enable_environmental_effects: bool = true
@export var enable_debris_generation: bool = true
@export var debug_explosion_logging: bool = false

# Performance settings
@export var max_simultaneous_explosions: int = 20
@export var shockwave_detection_radius: float = 200.0
@export var chain_reaction_probability: float = 0.3
@export var debris_particle_count: int = 50

# Explosion scale categories
@export var small_explosion_scale: float = 1.0      # Fighter weapons
@export var medium_explosion_scale: float = 3.0     # Bomber weapons  
@export var large_explosion_scale: float = 8.0      # Capital ship weapons
@export var massive_explosion_scale: float = 20.0   # Ship destruction

# Physics parameters
@export var shockwave_speed: float = 300.0          # m/s
@export var blast_pressure_falloff: float = 2.0     # Inverse square falloff
@export var debris_velocity_range: Vector2 = Vector2(10.0, 50.0)
@export var heat_expansion_factor: float = 1.5

# Visual parameters
@export var fireball_duration: float = 3.0
@export var shockwave_duration: float = 1.0
@export var debris_lifetime: float = 8.0
@export var flash_intensity: float = 2.0

func _ready() -> void:
	_setup_explosion_system()
	_initialize_explosion_templates()
	_setup_explosion_pools()

## Create explosion with specified parameters
func create_explosion(explosion_data: Dictionary) -> Node3D:
	var location = explosion_data.get("location", Vector3.ZERO)
	var explosion_type = explosion_data.get("explosion_type", "small")
	var damage_amount = explosion_data.get("damage_amount", 100.0)
	var blast_radius = explosion_data.get("blast_radius", 10.0)
	var explosion_source = explosion_data.get("source", "weapon")
	var cause_chain_reactions = explosion_data.get("chain_reactions", enable_chain_reactions)
	
	# Performance check
	if active_explosions.size() >= max_simultaneous_explosions:
		if debug_explosion_logging:
			print("ExplosionSystem: Explosion limit reached, skipping new explosion")
		return null
	
	# Get explosion template
	var template = explosion_templates.get(explosion_type, explosion_templates["small"])
	
	# Create explosion instance
	var explosion_instance = _create_explosion_instance(template, explosion_data)
	if not explosion_instance:
		return null
	
	# Position explosion
	explosion_instance.global_position = location
	add_child(explosion_instance)
	active_explosions.append(explosion_instance)
	
	# Configure explosion effects
	_configure_explosion_effects(explosion_instance, explosion_data, template)
	
	# Generate shockwave if enabled
	if enable_shockwave_physics:
		_generate_explosion_shockwave(location, blast_radius, damage_amount)
	
	# Check for chain reactions
	if cause_chain_reactions:
		_check_chain_reactions(location, blast_radius, explosion_data)
	
	# Environmental effects
	if enable_environmental_effects:
		_generate_environmental_effects(location, explosion_type, explosion_data)
	
	# Schedule cleanup
	var cleanup_timer = create_tween()
	cleanup_timer.tween_delay(fireball_duration + shockwave_duration)
	cleanup_timer.tween_callback(_cleanup_explosion.bind(explosion_instance))
	
	# Emit signal
	explosion_created.emit(explosion_data, explosion_instance)
	
	if debug_explosion_logging:
		print("ExplosionSystem: Created %s explosion at %s with radius %.1f" % [
			explosion_type, location, blast_radius
		])
	
	return explosion_instance

## Create small explosion (fighter weapons, small ordinance)
func create_small_explosion(location: Vector3, damage: float = 50.0) -> Node3D:
	return create_explosion({
		"location": location,
		"explosion_type": "small",
		"damage_amount": damage,
		"blast_radius": 5.0 * small_explosion_scale,
		"source": "fighter_weapon"
	})

## Create medium explosion (bomber weapons, ship systems)
func create_medium_explosion(location: Vector3, damage: float = 150.0) -> Node3D:
	return create_explosion({
		"location": location,
		"explosion_type": "medium", 
		"damage_amount": damage,
		"blast_radius": 12.0 * medium_explosion_scale,
		"source": "bomber_weapon"
	})

## Create large explosion (capital weapons, major systems)
func create_large_explosion(location: Vector3, damage: float = 500.0) -> Node3D:
	return create_explosion({
		"location": location,
		"explosion_type": "large",
		"damage_amount": damage,
		"blast_radius": 25.0 * large_explosion_scale,
		"source": "capital_weapon"
	})

## Create massive explosion (ship destruction, reactor explosion)
func create_massive_explosion(location: Vector3, damage: float = 1000.0) -> Node3D:
	return create_explosion({
		"location": location,
		"explosion_type": "massive",
		"damage_amount": damage,
		"blast_radius": 50.0 * massive_explosion_scale,
		"source": "ship_destruction",
		"chain_reactions": true
	})

## Create EMP explosion with special electromagnetic effects
func create_emp_explosion(location: Vector3, emp_radius: float = 30.0) -> Node3D:
	return create_explosion({
		"location": location,
		"explosion_type": "emp",
		"damage_amount": 0.0,  # No physical damage
		"blast_radius": emp_radius,
		"source": "emp_weapon",
		"electromagnetic": true,
		"chain_reactions": false
	})

## Setup explosion system
func _setup_explosion_system() -> void:
	active_explosions.clear()
	explosion_effect_pool.clear()
	chain_reaction_tracker.clear()
	affected_objects.clear()
	shockwave_propagation_data.clear()
	environmental_effects.clear()

## Initialize explosion templates
func _initialize_explosion_templates() -> void:
	explosion_templates = {
		"small": {
			"fireball_scale": small_explosion_scale,
			"particle_count": 30,
			"shockwave_strength": 1.0,
			"light_intensity": 1.0,
			"debris_count": 20,
			"audio_volume": 0.7
		},
		"medium": {
			"fireball_scale": medium_explosion_scale,
			"particle_count": 80,
			"shockwave_strength": 2.5,
			"light_intensity": 2.0,
			"debris_count": 50,
			"audio_volume": 1.0
		},
		"large": {
			"fireball_scale": large_explosion_scale,
			"particle_count": 150,
			"shockwave_strength": 5.0,
			"light_intensity": 4.0,
			"debris_count": 100,
			"audio_volume": 1.5
		},
		"massive": {
			"fireball_scale": massive_explosion_scale,
			"particle_count": 300,
			"shockwave_strength": 10.0,
			"light_intensity": 8.0,
			"debris_count": 200,
			"audio_volume": 2.0
		},
		"emp": {
			"fireball_scale": medium_explosion_scale * 0.5,
			"particle_count": 100,
			"shockwave_strength": 1.0,
			"light_intensity": 0.5,
			"debris_count": 0,
			"audio_volume": 0.8,
			"electromagnetic": true
		}
	}

## Setup explosion effect pools
func _setup_explosion_pools() -> void:
	var pool_types = ["small", "medium", "large", "massive", "emp"]
	
	for pool_type in pool_types:
		explosion_effect_pool[pool_type] = []
		
		# Pre-populate pools
		for i in range(5):  # 5 instances per type
			var explosion_node = _create_explosion_node(pool_type)
			explosion_node.visible = false
			explosion_effect_pool[pool_type].append(explosion_node)

## Create explosion instance from template
func _create_explosion_instance(template: Dictionary, explosion_data: Dictionary) -> Node3D:
	var explosion_type = explosion_data.get("explosion_type", "small")
	
	# Try to get from pool
	var pool = explosion_effect_pool.get(explosion_type, [])
	if not pool.is_empty():
		var instance = pool.pop_back()
		instance.visible = true
		return instance
	
	# Create new instance
	return _create_explosion_node(explosion_type)

## Create explosion node for specific type
func _create_explosion_node(explosion_type: String) -> Node3D:
	var explosion_node = Node3D.new()
	explosion_node.name = explosion_type + "_explosion"
	
	# Fireball particle system
	var fireball = GPUParticles3D.new()
	fireball.name = "Fireball"
	fireball.emitting = false
	explosion_node.add_child(fireball)
	
	# Shockwave particle system
	var shockwave = GPUParticles3D.new()
	shockwave.name = "Shockwave"
	shockwave.emitting = false
	explosion_node.add_child(shockwave)
	
	# Debris particle system
	var debris = GPUParticles3D.new()
	debris.name = "Debris"
	debris.emitting = false
	explosion_node.add_child(debris)
	
	# Flash light
	var flash_light = OmniLight3D.new()
	flash_light.name = "Flash"
	flash_light.light_energy = 0.0
	flash_light.light_color = Color.ORANGE_RED
	explosion_node.add_child(flash_light)
	
	# Audio player
	var audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "ExplosionAudio"
	explosion_node.add_child(audio_player)
	
	# Special effects for EMP
	if explosion_type == "emp":
		var emp_field = GPUParticles3D.new()
		emp_field.name = "EMPField"
		emp_field.emitting = false
		explosion_node.add_child(emp_field)
	
	return explosion_node

## Configure explosion effects based on template and data
func _configure_explosion_effects(explosion: Node3D, explosion_data: Dictionary, template: Dictionary) -> void:
	var damage_amount = explosion_data.get("damage_amount", 100.0)
	var blast_radius = explosion_data.get("blast_radius", 10.0)
	
	# Configure fireball
	var fireball = explosion.get_node_or_null("Fireball")
	if fireball and fireball is GPUParticles3D:
		fireball.emitting = true
		fireball.amount = template.get("particle_count", 50)
		fireball.lifetime = fireball_duration
		explosion.scale = Vector3.ONE * template.get("fireball_scale", 1.0)
	
	# Configure shockwave
	var shockwave = explosion.get_node_or_null("Shockwave")
	if shockwave and shockwave is GPUParticles3D:
		shockwave.emitting = true
		shockwave.amount = template.get("particle_count", 50) / 2
		shockwave.lifetime = shockwave_duration
	
	# Configure debris
	if enable_debris_generation:
		var debris = explosion.get_node_or_null("Debris")
		if debris and debris is GPUParticles3D:
			debris.emitting = true
			debris.amount = template.get("debris_count", 30)
			debris.lifetime = debris_lifetime
	
	# Configure flash light
	var flash_light = explosion.get_node_or_null("Flash")
	if flash_light and flash_light is OmniLight3D:
		flash_light.light_energy = template.get("light_intensity", 1.0) * flash_intensity
		flash_light.omni_range = blast_radius * 2.0
		
		# Animate flash
		var flash_tween = create_tween()
		flash_tween.tween_property(flash_light, "light_energy", 0.0, 0.3)
	
	# Configure audio
	var audio_player = explosion.get_node_or_null("ExplosionAudio")
	if audio_player and audio_player is AudioStreamPlayer3D:
		audio_player.volume_db = linear_to_db(template.get("audio_volume", 1.0))
		audio_player.max_distance = blast_radius * 10.0
	
	# Special EMP effects
	if explosion_data.get("electromagnetic", false):
		_configure_emp_effects(explosion, blast_radius)

## Configure EMP-specific effects
func _configure_emp_effects(explosion: Node3D, emp_radius: float) -> void:
	var emp_field = explosion.get_node_or_null("EMPField")
	if emp_field and emp_field is GPUParticles3D:
		emp_field.emitting = true
		emp_field.amount = 50
		emp_field.lifetime = 2.0
	
	# EMP blue-white light
	var flash_light = explosion.get_node_or_null("Flash")
	if flash_light and flash_light is OmniLight3D:
		flash_light.light_color = Color.CYAN
		flash_light.omni_range = emp_radius

## Generate explosion shockwave
func _generate_explosion_shockwave(location: Vector3, blast_radius: float, damage_amount: float) -> void:
	# Find objects within shockwave range
	var detection_radius = min(blast_radius * 3.0, shockwave_detection_radius)
	var nearby_objects = _find_objects_in_radius(location, detection_radius)
	
	for obj in nearby_objects:
		if obj and is_instance_valid(obj):
			_apply_shockwave_to_object(obj, location, blast_radius, damage_amount)

## Find objects within specified radius
func _find_objects_in_radius(center: Vector3, radius: float) -> Array[Node]:
	var found_objects: Array[Node] = []
	
	# Use physics space query to find objects
	var space_state = get_viewport().get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	# Create sphere collision shape
	var sphere = SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform.origin = center
	
	var results = space_state.intersect_shape(query)
	for result in results:
		var collider = result.get("collider")
		if collider and collider not in found_objects:
			found_objects.append(collider)
	
	return found_objects

## Apply shockwave effects to object
func _apply_shockwave_to_object(object: Node, explosion_center: Vector3, blast_radius: float, damage_amount: float) -> void:
	var object_position = Vector3.ZERO
	
	# Get object position
	if object.has_method("get_global_position"):
		object_position = object.get_global_position()
	elif object is Node3D:
		object_position = (object as Node3D).global_position
	else:
		return
	
	var distance = object_position.distance_to(explosion_center)
	if distance > blast_radius * 3.0:
		return
	
	# Calculate shockwave intensity
	var intensity = 1.0 - pow(distance / (blast_radius * 3.0), blast_pressure_falloff)
	intensity = clamp(intensity, 0.0, 1.0)
	
	# Create shockwave data
	var shockwave_data: Dictionary = {
		"explosion_center": explosion_center,
		"object_position": object_position,
		"distance": distance,
		"intensity": intensity,
		"blast_radius": blast_radius,
		"damage_amount": damage_amount * intensity,
		"shockwave_force": intensity * 500.0  # Base force
	}
	
	# Apply physics force if object has RigidBody3D
	if object is RigidBody3D:
		var direction = (object_position - explosion_center).normalized()
		var force = direction * shockwave_data["shockwave_force"]
		(object as RigidBody3D).apply_central_impulse(force)
	
	# Apply damage if object has damage system
	if object.has_method("take_damage"):
		object.take_damage(shockwave_data["damage_amount"])
	
	# Emit shockwave impact signal
	explosion_shockwave_impact.emit(object, shockwave_data)

## Check for chain reactions
func _check_chain_reactions(explosion_center: Vector3, blast_radius: float, original_explosion: Dictionary) -> void:
	if not enable_chain_reactions:
		return
	
	# Find potential chain reaction targets
	var chain_candidates = _find_chain_reaction_candidates(explosion_center, blast_radius * 2.0)
	
	for candidate in chain_candidates:
		if randf() < chain_reaction_probability:
			_trigger_chain_reaction(candidate, original_explosion)

## Find chain reaction candidates
func _find_chain_reaction_candidates(center: Vector3, search_radius: float) -> Array[Node]:
	var candidates: Array[Node] = []
	
	# Look for objects with explosive potential
	var nearby_objects = _find_objects_in_radius(center, search_radius)
	
	for obj in nearby_objects:
		if _can_cause_chain_reaction(obj):
			candidates.append(obj)
	
	return candidates

## Check if object can cause chain reaction
func _can_cause_chain_reaction(object: Node) -> bool:
	# Check for explosive materials, weapons, fuel, etc.
	if object.has_method("has_explosive_potential"):
		return object.has_explosive_potential()
	
	# Check object name for explosive indicators
	var obj_name = object.name.to_lower()
	return ("weapon" in obj_name or "fuel" in obj_name or "reactor" in obj_name or "missile" in obj_name)

## Trigger chain reaction explosion
func _trigger_chain_reaction(target: Node, original_explosion: Dictionary) -> void:
	var target_position = Vector3.ZERO
	
	if target.has_method("get_global_position"):
		target_position = target.get_global_position()
	elif target is Node3D:
		target_position = (target as Node3D).global_position
	
	# Create secondary explosion
	var chain_explosion_data = {
		"location": target_position,
		"explosion_type": "medium",  # Secondary explosions are typically medium
		"damage_amount": original_explosion.get("damage_amount", 100.0) * 0.7,
		"blast_radius": original_explosion.get("blast_radius", 10.0) * 0.8,
		"source": "chain_reaction",
		"chain_reactions": false  # Prevent infinite chains
	}
	
	# Slight delay for realism
	var chain_timer = create_tween()
	chain_timer.tween_delay(randf_range(0.1, 0.5))
	chain_timer.tween_callback(create_explosion.bind(chain_explosion_data))
	
	# Emit chain reaction signal
	explosion_chain_reaction.emit(original_explosion, chain_explosion_data)

## Generate environmental effects
func _generate_environmental_effects(location: Vector3, explosion_type: String, explosion_data: Dictionary) -> void:
	# Space debris generation
	if enable_debris_generation:
		_generate_space_debris(location, explosion_type)
	
	# Energy discharges
	_generate_energy_discharges(location, explosion_data)
	
	# Heat distortion effects
	_generate_heat_effects(location, explosion_data)

## Generate space debris
func _generate_space_debris(location: Vector3, explosion_type: String) -> void:
	var debris_count = 10
	match explosion_type:
		"small":
			debris_count = 5
		"medium":
			debris_count = 15
		"large":
			debris_count = 30
		"massive":
			debris_count = 50
	
	for i in range(debris_count):
		var debris_node = _create_debris_piece()
		debris_node.global_position = location + Vector3(
			randf_range(-2, 2),
			randf_range(-2, 2), 
			randf_range(-2, 2)
		)
		
		add_child(debris_node)
		environmental_effects.append(debris_node)
		
		# Schedule debris cleanup
		var debris_timer = create_tween()
		debris_timer.tween_delay(debris_lifetime)
		debris_timer.tween_callback(debris_node.queue_free)

## Create debris piece
func _create_debris_piece() -> RigidBody3D:
	var debris = RigidBody3D.new()
	debris.name = "SpaceDebris"
	
	# Collision shape
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.5, 0.5, 0.5)
	collision.shape = box_shape
	debris.add_child(collision)
	
	# Mesh
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.5, 0.5, 0.5)
	mesh_instance.mesh = box_mesh
	debris.add_child(mesh_instance)
	
	# Apply random velocity
	var velocity = Vector3(
		randf_range(-1, 1),
		randf_range(-1, 1),
		randf_range(-1, 1)
	).normalized() * randf_range(debris_velocity_range.x, debris_velocity_range.y)
	
	debris.linear_velocity = velocity
	debris.angular_velocity = Vector3(
		randf_range(-5, 5),
		randf_range(-5, 5),
		randf_range(-5, 5)
	)
	
	return debris

## Generate energy discharges
func _generate_energy_discharges(location: Vector3, explosion_data: Dictionary) -> void:
	# Create energy discharge effect
	var discharge_effect = Node3D.new()
	discharge_effect.name = "EnergyDischarge"
	discharge_effect.global_position = location
	
	var discharge_particles = GPUParticles3D.new()
	discharge_particles.emitting = true
	discharge_particles.amount = 20
	discharge_particles.lifetime = 1.5
	discharge_effect.add_child(discharge_particles)
	
	add_child(discharge_effect)
	environmental_effects.append(discharge_effect)
	
	# Cleanup
	var discharge_timer = create_tween()
	discharge_timer.tween_delay(2.0)
	discharge_timer.tween_callback(discharge_effect.queue_free)

## Generate heat effects
func _generate_heat_effects(location: Vector3, explosion_data: Dictionary) -> void:
	# Create heat distortion effect
	var heat_effect = Node3D.new()
	heat_effect.name = "HeatDistortion"
	heat_effect.global_position = location
	
	# Scale based on explosion size
	var blast_radius = explosion_data.get("blast_radius", 10.0)
	heat_effect.scale = Vector3.ONE * (blast_radius / 10.0) * heat_expansion_factor
	
	add_child(heat_effect)
	environmental_effects.append(heat_effect)
	
	# Heat effect duration
	var heat_timer = create_tween()
	heat_timer.tween_delay(3.0)
	heat_timer.tween_callback(heat_effect.queue_free)
	
	# Emit environmental effect signal
	explosion_environmental_effect.emit(location, "heat_distortion", {
		"radius": blast_radius * heat_expansion_factor,
		"duration": 3.0
	})

## Cleanup explosion and return to pool
func _cleanup_explosion(explosion: Node3D) -> void:
	if not explosion or not is_instance_valid(explosion):
		return
	
	# Remove from active explosions
	active_explosions.erase(explosion)
	
	# Stop all particle systems
	for child in explosion.get_children():
		if child is GPUParticles3D:
			child.emitting = false
		elif child is OmniLight3D:
			child.light_energy = 0.0
		elif child is AudioStreamPlayer3D:
			child.stop()
	
	# Return to pool or remove
	var explosion_type = _get_explosion_type_from_name(explosion.name)
	var pool = explosion_effect_pool.get(explosion_type, [])
	
	if pool.size() < 10:  # Pool size limit
		explosion.visible = false
		if explosion.get_parent():
			explosion.get_parent().remove_child(explosion)
		pool.append(explosion)
	else:
		explosion.queue_free()

## Get explosion type from name
func _get_explosion_type_from_name(explosion_name: String) -> String:
	var lower_name = explosion_name.to_lower()
	for explosion_type in explosion_templates.keys():
		if explosion_type in lower_name:
			return explosion_type
	return "small"

## Get system performance status
func get_explosion_system_status() -> Dictionary:
	return {
		"active_explosions": active_explosions.size(),
		"environmental_effects": environmental_effects.size(),
		"chain_reactions_enabled": enable_chain_reactions,
		"performance_optimal": active_explosions.size() < max_simultaneous_explosions * 0.8
	}