class_name WeaponImpactEffectManager
extends Node

## SHIP-012 AC1: Weapon Impact Effect Manager
## Manages visual effects for weapon impacts with material-specific responses and particle systems
## Implements WCS-authentic impact visualization with weapon type differentiation

# EPIC-002 Asset Core Integration
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const WeaponTypes = preload("res://addons/wcs_asset_core/constants/weapon_types.gd")
const ArmorTypes = preload("res://addons/wcs_asset_core/constants/armor_types.gd")

# Signals
signal impact_effect_created(impact_data: Dictionary, effect_instance: Node3D)
signal impact_effect_completed(impact_data: Dictionary, effect_duration: float)
signal material_response_triggered(material_type: int, weapon_type: int, response_data: Dictionary)
signal performance_warning(effect_count: int, performance_impact: float)

# Impact effect resources
var impact_effect_scenes: Dictionary = {}
var particle_systems: Dictionary = {}
var impact_audio_streams: Dictionary = {}
var material_response_data: Dictionary = {}

# Effect management
var active_impact_effects: Array[Node3D] = []
var impact_effect_pool: Dictionary = {}
var effect_performance_tracker: Dictionary = {}

# Configuration
@export var enable_material_responses: bool = true
@export var enable_particle_effects: bool = true
@export var enable_impact_audio: bool = true
@export var enable_performance_optimization: bool = true
@export var debug_impact_logging: bool = false

# Performance settings
@export var max_simultaneous_impacts: int = 50
@export var effect_culling_distance: float = 500.0
@export var particle_count_scale: float = 1.0
@export var audio_falloff_distance: float = 200.0

# Visual parameters
@export var impact_effect_duration: float = 2.0
@export var particle_lifetime_modifier: float = 1.0
@export var spark_intensity_multiplier: float = 1.0
@export var energy_discharge_brightness: float = 1.0

# Material response configurations
var material_spark_factors: Dictionary = {
	ArmorTypes.Class.LIGHT: 0.8,
	ArmorTypes.Class.STANDARD: 1.0,
	ArmorTypes.Class.HEAVY: 1.5,
	ArmorTypes.Class.ENERGY: 0.3,
	ArmorTypes.Class.COMPOSITE: 1.2
}

var weapon_impact_intensities: Dictionary = {
	WeaponTypes.Type.PRIMARY_LASER: 0.7,
	WeaponTypes.Type.PRIMARY_MASS_DRIVER: 1.2,
	WeaponTypes.Type.SECONDARY_MISSILE: 1.5,
	WeaponTypes.Type.BEAM_WEAPON: 0.9
}

func _ready() -> void:
	_setup_impact_effect_system()
	_load_material_response_data()
	_initialize_effect_pools()

## Create weapon impact effect at specified location
func create_weapon_impact_effect(impact_data: Dictionary) -> Node3D:
	var hit_location = impact_data.get("hit_location", Vector3.ZERO)
	var weapon_type = impact_data.get("weapon_type", WeaponTypes.Type.PRIMARY_LASER)
	var damage_type = impact_data.get("damage_type", DamageTypes.Type.ENERGY)
	var material_type = impact_data.get("material_type", ArmorTypes.Class.STANDARD)
	var damage_amount = impact_data.get("damage_amount", 50.0)
	var impact_velocity = impact_data.get("impact_velocity", Vector3.ZERO)
	var surface_normal = impact_data.get("surface_normal", Vector3.UP)
	
	# Check performance limits
	if active_impact_effects.size() >= max_simultaneous_impacts:
		if enable_performance_optimization:
			_cull_distant_effects(hit_location)
		else:
			performance_warning.emit(active_impact_effects.size(), 1.0)
			return null
	
	# Get or create impact effect
	var effect_instance = _get_impact_effect_instance(weapon_type, damage_type)
	if not effect_instance:
		return null
	
	# Position and orient effect
	effect_instance.global_position = hit_location
	_orient_effect_to_surface(effect_instance, surface_normal, impact_velocity)
	
	# Configure effect based on impact parameters
	_configure_impact_effect(effect_instance, impact_data)
	
	# Add material-specific response
	if enable_material_responses:
		_add_material_response_effects(effect_instance, material_type, weapon_type, damage_amount)
	
	# Add to scene and track
	add_child(effect_instance)
	active_impact_effects.append(effect_instance)
	
	# Schedule cleanup
	var cleanup_timer = create_tween()
	cleanup_timer.tween_delay(impact_effect_duration)
	cleanup_timer.tween_callback(_cleanup_impact_effect.bind(effect_instance))
	
	# Emit signals
	impact_effect_created.emit(impact_data, effect_instance)
	
	if debug_impact_logging:
		print("WeaponImpactEffectManager: Created %s impact effect at %s" % [
			DamageTypes.get_damage_type_name(damage_type), hit_location
		])
	
	return effect_instance

## Create energy weapon impact with beam characteristics
func create_energy_impact_effect(impact_data: Dictionary) -> Node3D:
	var enhanced_data = impact_data.duplicate()
	enhanced_data["damage_type"] = DamageTypes.Type.ENERGY
	enhanced_data["energy_discharge"] = true
	enhanced_data["heat_effect"] = true
	
	var effect = create_weapon_impact_effect(enhanced_data)
	if effect:
		_add_energy_discharge_effects(effect, impact_data.get("damage_amount", 50.0))
	
	return effect

## Create kinetic weapon impact with projectile characteristics
func create_kinetic_impact_effect(impact_data: Dictionary) -> Node3D:
	var enhanced_data = impact_data.duplicate()
	enhanced_data["damage_type"] = DamageTypes.Type.KINETIC
	enhanced_data["debris_generation"] = true
	enhanced_data["spark_shower"] = true
	
	var effect = create_weapon_impact_effect(enhanced_data)
	if effect:
		_add_kinetic_impact_effects(effect, impact_data.get("impact_velocity", Vector3.ZERO))
	
	return effect

## Create explosive weapon impact with blast characteristics
func create_explosive_impact_effect(impact_data: Dictionary) -> Node3D:
	var enhanced_data = impact_data.duplicate()
	enhanced_data["damage_type"] = DamageTypes.Type.EXPLOSIVE
	enhanced_data["blast_wave"] = true
	enhanced_data["fire_effect"] = true
	
	var effect = create_weapon_impact_effect(enhanced_data)
	if effect:
		_add_explosive_blast_effects(effect, impact_data.get("damage_amount", 100.0))
	
	return effect

## Get material response factor for weapon-material combination
func get_material_response_factor(material_type: int, weapon_type: int) -> float:
	var material_factor = material_spark_factors.get(material_type, 1.0)
	var weapon_intensity = weapon_impact_intensities.get(weapon_type, 1.0)
	
	# Special interactions
	var interaction_modifier = 1.0
	if material_type == ArmorTypes.Class.ENERGY and weapon_type == WeaponTypes.Type.PRIMARY_LASER:
		interaction_modifier = 0.5  # Energy armor resists energy weapons
	elif material_type == ArmorTypes.Class.HEAVY and weapon_type == WeaponTypes.Type.PRIMARY_MASS_DRIVER:
		interaction_modifier = 1.3  # Kinetic weapons effective against heavy armor
	
	return material_factor * weapon_intensity * interaction_modifier

## Setup impact effect system
func _setup_impact_effect_system() -> void:
	active_impact_effects.clear()
	impact_effect_pool.clear()
	effect_performance_tracker.clear()
	
	# Initialize effect tracking
	effect_performance_tracker = {
		"total_effects_created": 0,
		"active_effects": 0,
		"peak_effects": 0,
		"performance_warnings": 0
	}

## Load material response data
func _load_material_response_data() -> void:
	material_response_data = {
		ArmorTypes.Class.LIGHT: {
			"spark_multiplier": 0.8,
			"debris_size": 0.5,
			"audio_pitch": 1.2,
			"heat_dissipation": 1.5
		},
		ArmorTypes.Class.STANDARD: {
			"spark_multiplier": 1.0,
			"debris_size": 1.0,
			"audio_pitch": 1.0,
			"heat_dissipation": 1.0
		},
		ArmorTypes.Class.HEAVY: {
			"spark_multiplier": 1.5,
			"debris_size": 1.5,
			"audio_pitch": 0.8,
			"heat_dissipation": 0.7
		},
		ArmorTypes.Class.ENERGY: {
			"spark_multiplier": 0.3,
			"debris_size": 0.2,
			"audio_pitch": 1.5,
			"heat_dissipation": 2.0
		},
		ArmorTypes.Class.COMPOSITE: {
			"spark_multiplier": 1.2,
			"debris_size": 0.8,
			"audio_pitch": 1.1,
			"heat_dissipation": 1.3
		}
	}

## Initialize effect pools for performance
func _initialize_effect_pools() -> void:
	# Create pools for common effect types
	var pool_types = [
		"energy_impact",
		"kinetic_impact", 
		"explosive_impact",
		"spark_system",
		"debris_system"
	]
	
	for pool_type in pool_types:
		impact_effect_pool[pool_type] = []
		
		# Pre-populate with effect instances
		for i in range(10):  # Pool size of 10 per type
			var effect_instance = _create_effect_instance(pool_type)
			if effect_instance:
				effect_instance.visible = false
				impact_effect_pool[pool_type].append(effect_instance)

## Get impact effect instance from pool or create new
func _get_impact_effect_instance(weapon_type: int, damage_type: int) -> Node3D:
	var effect_type = _determine_effect_type(weapon_type, damage_type)
	
	# Try to get from pool first
	var pool = impact_effect_pool.get(effect_type, [])
	if not pool.is_empty():
		var effect = pool.pop_back()
		effect.visible = true
		return effect
	
	# Create new instance if pool is empty
	return _create_effect_instance(effect_type)

## Determine effect type from weapon and damage type
func _determine_effect_type(weapon_type: int, damage_type: int) -> String:
	match damage_type:
		DamageTypes.Type.ENERGY:
			return "energy_impact"
		DamageTypes.Type.KINETIC:
			return "kinetic_impact"
		DamageTypes.Type.EXPLOSIVE:
			return "explosive_impact"
		DamageTypes.Type.PLASMA:
			return "energy_impact"  # Similar to energy
		DamageTypes.Type.BEAM:
			return "energy_impact"  # Beam weapons use energy effects
		_:
			return "kinetic_impact"  # Default

## Create effect instance for specific type
func _create_effect_instance(effect_type: String) -> Node3D:
	var effect_node = Node3D.new()
	effect_node.name = effect_type + "_effect"
	
	match effect_type:
		"energy_impact":
			_setup_energy_impact_effect(effect_node)
		"kinetic_impact":
			_setup_kinetic_impact_effect(effect_node)
		"explosive_impact":
			_setup_explosive_impact_effect(effect_node)
		"spark_system":
			_setup_spark_system_effect(effect_node)
		"debris_system":
			_setup_debris_system_effect(effect_node)
	
	return effect_node

## Setup energy impact effect
func _setup_energy_impact_effect(effect_node: Node3D) -> void:
	# Main energy discharge particle system
	var energy_particles = GPUParticles3D.new()
	energy_particles.name = "EnergyDischarge"
	energy_particles.emitting = false
	effect_node.add_child(energy_particles)
	
	# Energy flash light
	var flash_light = OmniLight3D.new()
	flash_light.name = "EnergyFlash"
	flash_light.light_energy = 0.0
	flash_light.light_color = Color.CYAN
	flash_light.omni_range = 10.0
	effect_node.add_child(flash_light)
	
	# Heat distortion effect placeholder
	var heat_effect = MeshInstance3D.new()
	heat_effect.name = "HeatDistortion"
	heat_effect.visible = false
	effect_node.add_child(heat_effect)

## Setup kinetic impact effect
func _setup_kinetic_impact_effect(effect_node: Node3D) -> void:
	# Spark shower particle system
	var spark_particles = GPUParticles3D.new()
	spark_particles.name = "SparkShower"
	spark_particles.emitting = false
	effect_node.add_child(spark_particles)
	
	# Debris particle system
	var debris_particles = GPUParticles3D.new()
	debris_particles.name = "MetalDebris"
	debris_particles.emitting = false
	effect_node.add_child(debris_particles)
	
	# Impact flash
	var impact_flash = OmniLight3D.new()
	impact_flash.name = "ImpactFlash"
	impact_flash.light_energy = 0.0
	impact_flash.light_color = Color.ORANGE
	impact_flash.omni_range = 5.0
	effect_node.add_child(impact_flash)

## Setup explosive impact effect
func _setup_explosive_impact_effect(effect_node: Node3D) -> void:
	# Explosion fireball
	var fireball_particles = GPUParticles3D.new()
	fireball_particles.name = "Fireball"
	fireball_particles.emitting = false
	effect_node.add_child(fireball_particles)
	
	# Shockwave ring
	var shockwave_particles = GPUParticles3D.new()
	shockwave_particles.name = "Shockwave"
	shockwave_particles.emitting = false
	effect_node.add_child(shockwave_particles)
	
	# Explosion light
	var explosion_light = OmniLight3D.new()
	explosion_light.name = "ExplosionLight"
	explosion_light.light_energy = 0.0
	explosion_light.light_color = Color.ORANGE_RED
	explosion_light.omni_range = 20.0
	effect_node.add_child(explosion_light)

## Setup spark system effect
func _setup_spark_system_effect(effect_node: Node3D) -> void:
	var spark_system = GPUParticles3D.new()
	spark_system.name = "SparkSystem"
	spark_system.emitting = false
	effect_node.add_child(spark_system)

## Setup debris system effect
func _setup_debris_system_effect(effect_node: Node3D) -> void:
	var debris_system = GPUParticles3D.new()
	debris_system.name = "DebrisSystem"
	debris_system.emitting = false
	effect_node.add_child(debris_system)

## Orient effect to surface normal and impact direction
func _orient_effect_to_surface(effect: Node3D, surface_normal: Vector3, impact_velocity: Vector3) -> void:
	# Point effect toward surface normal
	if surface_normal.length() > 0:
		effect.look_at(effect.global_position + surface_normal, Vector3.UP)
	
	# Add slight random rotation for variation
	effect.rotate_z(randf_range(-PI/6, PI/6))

## Configure impact effect based on parameters
func _configure_impact_effect(effect: Node3D, impact_data: Dictionary) -> void:
	var damage_amount = impact_data.get("damage_amount", 50.0)
	var weapon_type = impact_data.get("weapon_type", WeaponTypes.Type.PRIMARY_LASER)
	var damage_type = impact_data.get("damage_type", DamageTypes.Type.ENERGY)
	
	# Scale effect intensity based on damage
	var intensity_scale = clamp(damage_amount / 100.0, 0.3, 2.0)
	
	# Configure particle systems
	for child in effect.get_children():
		if child is GPUParticles3D:
			_configure_particle_system(child, damage_type, intensity_scale)
		elif child is OmniLight3D:
			_configure_light_effect(child, damage_type, intensity_scale)

## Configure particle system parameters
func _configure_particle_system(particles: GPUParticles3D, damage_type: int, intensity: float) -> void:
	particles.emitting = true
	particles.amount = int(50 * intensity * particle_count_scale)
	
	# Set particle color based on damage type
	var particle_color = DamageTypes.get_damage_type_color(damage_type)
	
	# Configure based on particle system name
	match particles.name:
		"EnergyDischarge":
			particles.lifetime = 1.0 * particle_lifetime_modifier
		"SparkShower":
			particles.lifetime = 0.8 * particle_lifetime_modifier
		"MetalDebris":
			particles.lifetime = 1.5 * particle_lifetime_modifier
		"Fireball":
			particles.lifetime = 2.0 * particle_lifetime_modifier
		"Shockwave":
			particles.lifetime = 0.5 * particle_lifetime_modifier

## Configure light effect parameters
func _configure_light_effect(light: OmniLight3D, damage_type: int, intensity: float) -> void:
	light.light_energy = intensity * energy_discharge_brightness
	light.light_color = DamageTypes.get_damage_type_color(damage_type)
	
	# Animate light fade
	var light_tween = create_tween()
	light_tween.tween_property(light, "light_energy", 0.0, 0.5)

## Add material-specific response effects
func _add_material_response_effects(effect: Node3D, material_type: int, weapon_type: int, damage_amount: float) -> void:
	var response_data = material_response_data.get(material_type, {})
	var response_factor = get_material_response_factor(material_type, weapon_type)
	
	# Add material-specific spark effects
	var spark_multiplier = response_data.get("spark_multiplier", 1.0)
	if spark_multiplier > 0.3:
		_add_material_spark_effects(effect, spark_multiplier * response_factor)
	
	# Add debris generation
	var debris_size = response_data.get("debris_size", 1.0)
	if debris_size > 0.1:
		_add_material_debris_effects(effect, debris_size * response_factor)
	
	# Emit material response signal
	material_response_triggered.emit(material_type, weapon_type, {
		"response_factor": response_factor,
		"spark_multiplier": spark_multiplier,
		"debris_size": debris_size
	})

## Add energy discharge effects
func _add_energy_discharge_effects(effect: Node3D, damage_amount: float) -> void:
	var energy_discharge = effect.get_node_or_null("EnergyDischarge")
	if energy_discharge and energy_discharge is GPUParticles3D:
		energy_discharge.amount = int(30 * clamp(damage_amount / 50.0, 0.5, 2.0))
		energy_discharge.emitting = true

## Add kinetic impact effects
func _add_kinetic_impact_effects(effect: Node3D, impact_velocity: Vector3) -> void:
	var velocity_magnitude = impact_velocity.length()
	var intensity = clamp(velocity_magnitude / 100.0, 0.5, 2.0)
	
	# Enhanced sparks for high-velocity impacts
	var spark_shower = effect.get_node_or_null("SparkShower")
	if spark_shower and spark_shower is GPUParticles3D:
		spark_shower.amount = int(40 * intensity * spark_intensity_multiplier)
		spark_shower.emitting = true

## Add explosive blast effects
func _add_explosive_blast_effects(effect: Node3D, damage_amount: float) -> void:
	var blast_intensity = clamp(damage_amount / 100.0, 0.5, 3.0)
	
	# Scale explosion effects
	var fireball = effect.get_node_or_null("Fireball")
	if fireball and fireball is GPUParticles3D:
		fireball.amount = int(60 * blast_intensity)
		fireball.emitting = true
	
	var shockwave = effect.get_node_or_null("Shockwave")
	if shockwave and shockwave is GPUParticles3D:
		shockwave.amount = int(20 * blast_intensity)
		shockwave.emitting = true

## Add material-specific spark effects
func _add_material_spark_effects(effect: Node3D, spark_multiplier: float) -> void:
	# Create additional spark system if needed
	var spark_effect = _get_impact_effect_instance(0, DamageTypes.Type.KINETIC)
	if spark_effect:
		spark_effect.scale = Vector3.ONE * spark_multiplier
		effect.add_child(spark_effect)

## Add material-specific debris effects
func _add_material_debris_effects(effect: Node3D, debris_size: float) -> void:
	# Create debris system
	var debris_effect = _get_impact_effect_instance(0, DamageTypes.Type.KINETIC)
	if debris_effect:
		debris_effect.scale = Vector3.ONE * debris_size
		effect.add_child(debris_effect)

## Cull distant effects for performance
func _cull_distant_effects(reference_position: Vector3) -> void:
	var effects_to_remove: Array[Node3D] = []
	
	for effect in active_impact_effects:
		if effect and is_instance_valid(effect):
			var distance = effect.global_position.distance_to(reference_position)
			if distance > effect_culling_distance:
				effects_to_remove.append(effect)
	
	# Remove distant effects
	for effect in effects_to_remove:
		_cleanup_impact_effect(effect)

## Cleanup impact effect and return to pool
func _cleanup_impact_effect(effect: Node3D) -> void:
	if not effect or not is_instance_valid(effect):
		return
	
	# Remove from active effects
	active_impact_effects.erase(effect)
	
	# Stop all particle systems
	for child in effect.get_children():
		if child is GPUParticles3D:
			child.emitting = false
		elif child is OmniLight3D:
			child.light_energy = 0.0
	
	# Return to pool or remove
	var effect_type = _get_effect_type_from_name(effect.name)
	var pool = impact_effect_pool.get(effect_type, [])
	
	if pool.size() < 20:  # Pool size limit
		effect.visible = false
		if effect.get_parent():
			effect.get_parent().remove_child(effect)
		pool.append(effect)
	else:
		effect.queue_free()
	
	# Update performance tracking
	effect_performance_tracker["active_effects"] = active_impact_effects.size()

## Get effect type from effect name
func _get_effect_type_from_name(effect_name: String) -> String:
	if "energy" in effect_name.to_lower():
		return "energy_impact"
	elif "kinetic" in effect_name.to_lower():
		return "kinetic_impact"
	elif "explosive" in effect_name.to_lower():
		return "explosive_impact"
	else:
		return "kinetic_impact"

## Get current performance status
func get_impact_effect_performance_status() -> Dictionary:
	effect_performance_tracker["active_effects"] = active_impact_effects.size()
	effect_performance_tracker["peak_effects"] = max(
		effect_performance_tracker.get("peak_effects", 0),
		active_impact_effects.size()
	)
	
	return effect_performance_tracker.duplicate()

## Process frame updates
func _process(_delta: float) -> void:
	# Performance monitoring
	if active_impact_effects.size() > max_simultaneous_impacts * 0.8:
		performance_warning.emit(active_impact_effects.size(), 0.8)