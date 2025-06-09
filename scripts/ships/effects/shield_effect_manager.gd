class_name ShieldEffectManager
extends Node

## SHIP-012 AC4: Shield Effect Manager
## Displays shield impact effects with quadrant-specific hits and energy dispersion visualization
## Implements WCS-authentic shield mechanics with real-time strength indicators

# EPIC-002 Asset Core Integration
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const ShieldTypes = preload("res://addons/wcs_asset_core/constants/shield_types.gd")

# Signals
signal shield_impact_visualized(quadrant: int, impact_data: Dictionary)
signal shield_quadrant_failed(quadrant: int, failure_data: Dictionary)
signal shield_regeneration_visualized(quadrant: int, regeneration_rate: float)
signal shield_overload_detected(quadrant: int, overload_severity: float)

# Ship references
var owner_ship: Node = null
var shield_system: Node = null
var ship_mesh: MeshInstance3D = null
var shield_collision_shape: CollisionShape3D = null

# Shield visual components
var shield_bubble_mesh: MeshInstance3D = null
var shield_material: ShaderMaterial = null
var quadrant_impact_nodes: Array[Node3D] = []
var shield_strength_indicators: Array[Node3D] = []

# Effect pools
var impact_effect_pool: Array[Node3D] = []
var ripple_effect_pool: Array[Node3D] = []
var overload_effect_pool: Array[Node3D] = []

# Shield state tracking
var quadrant_states: Array[Dictionary] = []
var active_impacts: Array[Dictionary] = []
var shield_bubble_visible: bool = false
var shield_flicker_timer: float = 0.0

# Configuration
@export var enable_shield_bubble: bool = true
@export var enable_quadrant_indicators: bool = true
@export var enable_impact_ripples: bool = true
@export var enable_regeneration_effects: bool = true
@export var debug_shield_effects: bool = false

# Visual parameters
@export var shield_bubble_radius: float = 6.0
@export var impact_effect_duration: float = 1.5
@export var ripple_propagation_speed: float = 15.0
@export var shield_opacity: float = 0.3
@export var impact_flash_intensity: float = 2.0

# Performance settings
@export var max_simultaneous_impacts: int = 20
@export var effect_culling_distance: float = 150.0
@export var quadrant_update_frequency: float = 0.1
@export var shield_flicker_frequency: float = 0.05

# Shield quadrant definitions (Front, Rear, Port, Starboard)
const SHIELD_QUADRANTS = {
	FRONT = 0,
	REAR = 1,
	PORT = 2,
	STARBOARD = 3
}

# Quadrant colors for visualization
const QUADRANT_COLORS = [
	Color.CYAN,      # Front - Cyan
	Color.BLUE,      # Rear - Blue  
	Color.GREEN,     # Port - Green
	Color.MAGENTA    # Starboard - Magenta
]

# Update timers
var quadrant_update_timer: float = 0.0

func _ready() -> void:
	_setup_shield_effect_system()
	_initialize_effect_pools()

## Initialize shield effects for a ship
func initialize_for_ship(ship: Node) -> void:
	owner_ship = ship
	
	# Find required components
	ship_mesh = _find_ship_mesh(ship)
	shield_system = ship.get_node_or_null("ShieldQuadrantManager")
	shield_collision_shape = _find_shield_collision_shape(ship)
	
	if not ship_mesh:
		push_warning("ShieldEffectManager: No ship mesh found for %s" % ship.name)
		return
	
	# Setup shield bubble
	if enable_shield_bubble:
		_setup_shield_bubble()
	
	# Initialize quadrant states
	_initialize_quadrant_states()
	
	# Setup quadrant indicators
	if enable_quadrant_indicators:
		_setup_quadrant_indicators()
	
	# Connect to shield system signals
	_connect_shield_system_signals()
	
	if debug_shield_effects:
		print("ShieldEffectManager: Initialized for ship %s" % ship.name)

## Create shield impact effect
func create_shield_impact_effect(impact_data: Dictionary) -> void:
	var hit_location = impact_data.get("hit_location", Vector3.ZERO)
	var damage_amount = impact_data.get("damage_amount", 50.0)
	var damage_type = impact_data.get("damage_type", DamageTypes.Type.ENERGY)
	var weapon_type = impact_data.get("weapon_type", 0)
	
	# Determine which quadrant was hit
	var quadrant = _determine_hit_quadrant(hit_location)
	
	# Check performance limits
	if active_impacts.size() >= max_simultaneous_impacts:
		_cull_oldest_impact_effects()
	
	# Create impact effect
	var impact_effect = _create_impact_effect(hit_location, damage_amount, damage_type, quadrant)
	if not impact_effect:
		return
	
	# Add to active impacts
	active_impacts.append({
		"effect": impact_effect,
		"quadrant": quadrant,
		"start_time": Time.get_ticks_msec() / 1000.0,
		"duration": impact_effect_duration,
		"damage_amount": damage_amount
	})
	
	# Update quadrant state
	_update_quadrant_impact_state(quadrant, damage_amount)
	
	# Create ripple effects if enabled
	if enable_impact_ripples:
		_create_impact_ripple_effect(hit_location, quadrant, damage_amount)
	
	# Update shield bubble visualization
	_update_shield_bubble_impact(hit_location, damage_amount, damage_type)
	
	# Emit signal
	shield_impact_visualized.emit(quadrant, impact_data)
	
	if debug_shield_effects:
		print("ShieldEffectManager: Created impact effect at %s (quadrant: %d, damage: %.1f)" % [
			hit_location, quadrant, damage_amount
		])

## Visualize shield quadrant failure
func visualize_shield_quadrant_failure(quadrant: int, failure_data: Dictionary) -> void:
	if quadrant < 0 or quadrant >= quadrant_states.size():
		return
	
	var quadrant_state = quadrant_states[quadrant]
	quadrant_state["failed"] = true
	quadrant_state["failure_time"] = Time.get_ticks_msec() / 1000.0
	
	# Create failure effect
	_create_quadrant_failure_effect(quadrant, failure_data)
	
	# Update shield bubble
	_update_shield_bubble_failure(quadrant)
	
	# Update quadrant indicator
	_update_quadrant_indicator(quadrant, 0.0, true)
	
	shield_quadrant_failed.emit(quadrant, failure_data)
	
	if debug_shield_effects:
		print("ShieldEffectManager: Quadrant %d failed" % quadrant)

## Visualize shield regeneration
func visualize_shield_regeneration(quadrant: int, strength: float, regeneration_rate: float) -> void:
	if quadrant < 0 or quadrant >= quadrant_states.size():
		return
	
	var quadrant_state = quadrant_states[quadrant]
	quadrant_state["strength"] = strength
	quadrant_state["regenerating"] = regeneration_rate > 0.0
	quadrant_state["failed"] = false
	
	# Create regeneration effect
	if enable_regeneration_effects and regeneration_rate > 0.0:
		_create_regeneration_effect(quadrant, regeneration_rate)
	
	# Update shield bubble
	_update_shield_bubble_regeneration(quadrant, strength)
	
	# Update quadrant indicator
	_update_quadrant_indicator(quadrant, strength, false)
	
	shield_regeneration_visualized.emit(quadrant, regeneration_rate)

## Update shield strength visualization
func update_shield_strength_visualization(quadrant_strengths: Array[float]) -> void:
	for i in range(min(quadrant_strengths.size(), quadrant_states.size())):
		var strength = quadrant_strengths[i]
		quadrant_states[i]["strength"] = strength
		
		# Update visualization elements
		_update_quadrant_indicator(i, strength, false)
		_update_shield_bubble_quadrant(i, strength)

## Create shield overload effect
func create_shield_overload_effect(quadrant: int, overload_severity: float) -> void:
	if quadrant < 0 or quadrant >= quadrant_states.size():
		return
	
	# Get overload effect from pool
	var overload_effect = _get_overload_effect_from_pool()
	if not overload_effect:
		overload_effect = _create_overload_effect()
	
	# Position and configure overload effect
	var quadrant_position = _get_quadrant_center_position(quadrant)
	overload_effect.global_position = quadrant_position
	_configure_overload_effect(overload_effect, overload_severity, quadrant)
	
	# Add to ship
	if owner_ship:
		owner_ship.add_child(overload_effect)
	
	# Schedule cleanup
	var cleanup_timer = create_tween()
	cleanup_timer.tween_delay(2.0)
	cleanup_timer.tween_callback(_cleanup_overload_effect.bind(overload_effect))
	
	shield_overload_detected.emit(quadrant, overload_severity)

## Setup shield effect system
func _setup_shield_effect_system() -> void:
	active_impacts.clear()
	quadrant_impact_nodes.clear()
	shield_strength_indicators.clear()
	
	shield_flicker_timer = 0.0
	quadrant_update_timer = 0.0

## Initialize effect pools
func _initialize_effect_pools() -> void:
	# Impact effect pool
	for i in range(30):
		var impact_effect = _create_impact_effect_node()
		impact_effect.visible = false
		impact_effect_pool.append(impact_effect)
	
	# Ripple effect pool
	for i in range(20):
		var ripple_effect = _create_ripple_effect_node()
		ripple_effect.visible = false
		ripple_effect_pool.append(ripple_effect)
	
	# Overload effect pool
	for i in range(10):
		var overload_effect = _create_overload_effect()
		overload_effect.visible = false
		overload_effect_pool.append(overload_effect)

## Setup shield bubble
func _setup_shield_bubble() -> void:
	if not owner_ship:
		return
	
	# Create shield bubble mesh
	shield_bubble_mesh = MeshInstance3D.new()
	shield_bubble_mesh.name = "ShieldBubble"
	
	# Create sphere mesh for shield
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = shield_bubble_radius
	sphere_mesh.radial_segments = 32
	sphere_mesh.rings = 16
	shield_bubble_mesh.mesh = sphere_mesh
	
	# Create shield material
	_create_shield_material()
	shield_bubble_mesh.material_override = shield_material
	
	# Initially invisible
	shield_bubble_mesh.visible = false
	
	owner_ship.add_child(shield_bubble_mesh)

## Create shield material
func _create_shield_material() -> void:
	shield_material = ShaderMaterial.new()
	
	# For now, use StandardMaterial3D as placeholder
	var std_material = StandardMaterial3D.new()
	std_material.flags_transparent = true
	std_material.flags_unshaded = true
	std_material.albedo_color = Color(0.5, 0.8, 1.0, shield_opacity)
	std_material.emission_enabled = true
	std_material.emission = Color(0.3, 0.6, 0.9)
	
	shield_bubble_mesh.material_override = std_material

## Initialize quadrant states
func _initialize_quadrant_states() -> void:
	quadrant_states.clear()
	
	for i in range(4):  # 4 quadrants
		quadrant_states.append({
			"quadrant": i,
			"strength": 1.0,
			"failed": false,
			"regenerating": false,
			"last_impact_time": 0.0,
			"failure_time": 0.0,
			"impact_count": 0
		})

## Setup quadrant indicators
func _setup_quadrant_indicators() -> void:
	if not owner_ship:
		return
	
	for i in range(4):
		var indicator = _create_quadrant_indicator(i)
		shield_strength_indicators.append(indicator)
		owner_ship.add_child(indicator)

## Create quadrant indicator
func _create_quadrant_indicator(quadrant: int) -> Node3D:
	var indicator = Node3D.new()
	indicator.name = "ShieldQuadrantIndicator_" + str(quadrant)
	
	# Indicator mesh (small sphere)
	var mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.3
	mesh_instance.mesh = sphere_mesh
	
	# Indicator material
	var material = StandardMaterial3D.new()
	material.albedo_color = QUADRANT_COLORS[quadrant]
	material.emission_enabled = true
	material.emission = QUADRANT_COLORS[quadrant] * 0.5
	material.flags_unshaded = true
	mesh_instance.material_override = material
	
	indicator.add_child(mesh_instance)
	
	# Position indicator at quadrant location
	indicator.global_position = _get_quadrant_indicator_position(quadrant)
	
	return indicator

## Connect to shield system signals
func _connect_shield_system_signals() -> void:
	if shield_system:
		if shield_system.has_signal("shield_hit"):
			shield_system.shield_hit.connect(_on_shield_hit)
		if shield_system.has_signal("quadrant_depleted"):
			shield_system.quadrant_depleted.connect(_on_quadrant_depleted)
		if shield_system.has_signal("shield_regenerating"):
			shield_system.shield_regenerating.connect(_on_shield_regenerating)
		if shield_system.has_signal("shield_overload"):
			shield_system.shield_overload.connect(_on_shield_overload)

## Find ship mesh
func _find_ship_mesh(ship: Node) -> MeshInstance3D:
	for child in ship.get_children():
		if child is MeshInstance3D:
			return child
		var found_mesh = _search_mesh_recursive(child)
		if found_mesh:
			return found_mesh
	return null

## Recursive mesh search
func _search_mesh_recursive(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found_mesh = _search_mesh_recursive(child)
		if found_mesh:
			return found_mesh
	return null

## Find shield collision shape
func _find_shield_collision_shape(ship: Node) -> CollisionShape3D:
	for child in ship.get_children():
		if child is CollisionShape3D:
			var shape = child.shape
			if shape is SphereShape3D or shape is CapsuleShape3D:
				return child
	return null

## Determine which quadrant was hit
func _determine_hit_quadrant(hit_location: Vector3) -> int:
	if not owner_ship:
		return 0
	
	# Convert to local coordinates
	var local_hit = owner_ship.global_transform.inverse() * hit_location
	
	# Determine quadrant based on position
	if abs(local_hit.z) > abs(local_hit.x):
		# Front/Rear hit
		return SHIELD_QUADRANTS.FRONT if local_hit.z > 0 else SHIELD_QUADRANTS.REAR
	else:
		# Port/Starboard hit  
		return SHIELD_QUADRANTS.PORT if local_hit.x < 0 else SHIELD_QUADRANTS.STARBOARD

## Create impact effect
func _create_impact_effect(location: Vector3, damage: float, damage_type: int, quadrant: int) -> Node3D:
	var impact_effect = _get_impact_effect_from_pool()
	if not impact_effect:
		impact_effect = _create_impact_effect_node()
	
	# Position and configure effect
	impact_effect.global_position = location
	impact_effect.visible = true
	_configure_impact_effect(impact_effect, damage, damage_type, quadrant)
	
	# Add to ship
	if owner_ship:
		owner_ship.add_child(impact_effect)
	
	return impact_effect

## Create impact effect node
func _create_impact_effect_node() -> Node3D:
	var impact_node = Node3D.new()
	impact_node.name = "ShieldImpactEffect"
	
	# Impact flash particle system
	var flash_particles = GPUParticles3D.new()
	flash_particles.name = "ImpactFlash"
	flash_particles.emitting = false
	flash_particles.amount = 25
	flash_particles.lifetime = 0.5
	impact_node.add_child(flash_particles)
	
	# Energy dispersion particles
	var dispersion_particles = GPUParticles3D.new()
	dispersion_particles.name = "EnergyDispersion"
	dispersion_particles.emitting = false
	dispersion_particles.amount = 40
	dispersion_particles.lifetime = 1.0
	impact_node.add_child(dispersion_particles)
	
	# Impact light
	var impact_light = OmniLight3D.new()
	impact_light.name = "ImpactLight"
	impact_light.light_energy = 0.0
	impact_light.omni_range = 5.0
	impact_node.add_child(impact_light)
	
	return impact_node

## Configure impact effect
func _configure_impact_effect(effect: Node3D, damage: float, damage_type: int, quadrant: int) -> void:
	var quadrant_color = QUADRANT_COLORS[quadrant]
	var damage_color = DamageTypes.get_damage_type_color(damage_type)
	var final_color = quadrant_color.lerp(damage_color, 0.5)
	
	# Configure flash particles
	var flash_particles = effect.get_node_or_null("ImpactFlash")
	if flash_particles and flash_particles is GPUParticles3D:
		flash_particles.emitting = true
		flash_particles.amount = int(25 * clamp(damage / 100.0, 0.5, 2.0))
	
	# Configure dispersion particles
	var dispersion_particles = effect.get_node_or_null("EnergyDispersion")
	if dispersion_particles and dispersion_particles is GPUParticles3D:
		dispersion_particles.emitting = true
		dispersion_particles.amount = int(40 * clamp(damage / 100.0, 0.5, 2.0))
	
	# Configure impact light
	var impact_light = effect.get_node_or_null("ImpactLight")
	if impact_light and impact_light is OmniLight3D:
		impact_light.light_color = final_color
		impact_light.light_energy = impact_flash_intensity * clamp(damage / 100.0, 0.5, 2.0)
		
		# Animate light fade
		var light_tween = create_tween()
		light_tween.tween_property(impact_light, "light_energy", 0.0, 0.3)

## Create ripple effect
func _create_impact_ripple_effect(location: Vector3, quadrant: int, damage: float) -> void:
	var ripple_effect = _get_ripple_effect_from_pool()
	if not ripple_effect:
		ripple_effect = _create_ripple_effect_node()
	
	# Position and configure ripple
	ripple_effect.global_position = location
	ripple_effect.visible = true
	_configure_ripple_effect(ripple_effect, quadrant, damage)
	
	# Add to ship
	if owner_ship:
		owner_ship.add_child(ripple_effect)
	
	# Schedule cleanup
	var cleanup_timer = create_tween()
	cleanup_timer.tween_delay(2.0)
	cleanup_timer.tween_callback(_cleanup_ripple_effect.bind(ripple_effect))

## Create ripple effect node
func _create_ripple_effect_node() -> Node3D:
	var ripple_node = Node3D.new()
	ripple_node.name = "ShieldRippleEffect"
	
	# Ripple mesh (expanding ring)
	var mesh_instance = MeshInstance3D.new()
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = 0.1
	cylinder_mesh.bottom_radius = 0.1
	cylinder_mesh.height = 0.05
	mesh_instance.mesh = cylinder_mesh
	
	# Ripple material
	var material = StandardMaterial3D.new()
	material.flags_transparent = true
	material.flags_unshaded = true
	material.albedo_color = Color(1, 1, 1, 0.5)
	mesh_instance.material_override = material
	
	ripple_node.add_child(mesh_instance)
	
	return ripple_node

## Configure ripple effect
func _configure_ripple_effect(effect: Node3D, quadrant: int, damage: float) -> void:
	var mesh_instance = effect.get_child(0) as MeshInstance3D
	if not mesh_instance:
		return
	
	var material = mesh_instance.material_override as StandardMaterial3D
	if material:
		material.albedo_color = QUADRANT_COLORS[quadrant]
		material.albedo_color.a = 0.7
	
	# Animate ripple expansion
	var expansion_scale = 5.0 * clamp(damage / 100.0, 0.5, 2.0)
	var expand_tween = create_tween()
	expand_tween.parallel().tween_property(effect, "scale", Vector3.ONE * expansion_scale, 1.5)
	expand_tween.parallel().tween_property(material, "albedo_color:a", 0.0, 1.5)

## Update quadrant impact state
func _update_quadrant_impact_state(quadrant: int, damage: float) -> void:
	if quadrant >= 0 and quadrant < quadrant_states.size():
		var state = quadrant_states[quadrant]
		state["last_impact_time"] = Time.get_ticks_msec() / 1000.0
		state["impact_count"] += 1

## Update shield bubble impact
func _update_shield_bubble_impact(location: Vector3, damage: float, damage_type: int) -> void:
	if not enable_shield_bubble or not shield_bubble_mesh:
		return
	
	# Make shield temporarily visible on impact
	shield_bubble_mesh.visible = true
	shield_bubble_visible = true
	
	# Update shield material for impact flash
	var material = shield_bubble_mesh.material_override
	if material and material is StandardMaterial3D:
		var std_material = material as StandardMaterial3D
		var damage_color = DamageTypes.get_damage_type_color(damage_type)
		
		# Flash effect
		std_material.emission = damage_color * 0.8
		
		# Fade back to normal
		var fade_tween = create_tween()
		fade_tween.tween_property(std_material, "emission", Color(0.3, 0.6, 0.9), 0.5)
		fade_tween.tween_callback(_check_hide_shield_bubble)

## Update shield bubble for quadrant failure
func _update_shield_bubble_failure(quadrant: int) -> void:
	if not enable_shield_bubble or not shield_bubble_mesh:
		return
	
	# Create visible gap or darkness in failed quadrant
	_update_shield_bubble_quadrant(quadrant, 0.0)

## Update shield bubble for regeneration
func _update_shield_bubble_regeneration(quadrant: int, strength: float) -> void:
	if not enable_shield_bubble or not shield_bubble_mesh:
		return
	
	# Make shield visible during regeneration
	if strength > 0.0:
		shield_bubble_mesh.visible = true
		shield_bubble_visible = true
	
	_update_shield_bubble_quadrant(quadrant, strength)

## Update shield bubble quadrant
func _update_shield_bubble_quadrant(quadrant: int, strength: float) -> void:
	# This would update shader parameters for specific quadrant
	# For now, update overall bubble opacity based on average strength
	var material = shield_bubble_mesh.material_override
	if material and material is StandardMaterial3D:
		var std_material = material as StandardMaterial3D
		var alpha = shield_opacity * strength
		std_material.albedo_color.a = alpha

## Update quadrant indicator
func _update_quadrant_indicator(quadrant: int, strength: float, failed: bool) -> void:
	if quadrant < 0 or quadrant >= shield_strength_indicators.size():
		return
	
	var indicator = shield_strength_indicators[quadrant]
	if not indicator:
		return
	
	var mesh_instance = indicator.get_child(0) as MeshInstance3D
	if not mesh_instance:
		return
	
	var material = mesh_instance.material_override as StandardMaterial3D
	if not material:
		return
	
	if failed:
		# Dark/red color for failed quadrant
		material.albedo_color = Color.RED
		material.emission = Color.RED * 0.3
		indicator.scale = Vector3.ONE * 0.5
	else:
		# Scale and color based on strength
		var base_color = QUADRANT_COLORS[quadrant]
		material.albedo_color = base_color.lerp(Color.WHITE, strength)
		material.emission = base_color * strength * 0.5
		indicator.scale = Vector3.ONE * (0.5 + strength * 0.5)

## Create quadrant failure effect
func _create_quadrant_failure_effect(quadrant: int, failure_data: Dictionary) -> void:
	var failure_position = _get_quadrant_center_position(quadrant)
	
	# Create failure flash effect
	var failure_effect = Node3D.new()
	failure_effect.name = "QuadrantFailureEffect"
	failure_effect.global_position = failure_position
	
	# Failure particle system
	var particles = GPUParticles3D.new()
	particles.emitting = true
	particles.amount = 50
	particles.lifetime = 2.0
	failure_effect.add_child(particles)
	
	# Failure light
	var light = OmniLight3D.new()
	light.light_color = Color.RED
	light.light_energy = 3.0
	light.omni_range = 15.0
	failure_effect.add_child(light)
	
	if owner_ship:
		owner_ship.add_child(failure_effect)
	
	# Animate light fade
	var fade_tween = create_tween()
	fade_tween.tween_property(light, "light_energy", 0.0, 1.0)
	fade_tween.tween_callback(failure_effect.queue_free)

## Create regeneration effect
func _create_regeneration_effect(quadrant: int, regeneration_rate: float) -> void:
	var regen_position = _get_quadrant_center_position(quadrant)
	
	# Create regeneration glow effect
	var regen_effect = Node3D.new()
	regen_effect.name = "RegenerationEffect"
	regen_effect.global_position = regen_position
	
	# Regeneration particles
	var particles = GPUParticles3D.new()
	particles.emitting = true
	particles.amount = int(20 * regeneration_rate)
	particles.lifetime = 3.0
	regen_effect.add_child(particles)
	
	# Regeneration light
	var light = OmniLight3D.new()
	light.light_color = QUADRANT_COLORS[quadrant]
	light.light_energy = regeneration_rate * 2.0
	light.omni_range = 8.0
	regen_effect.add_child(light)
	
	if owner_ship:
		owner_ship.add_child(regen_effect)
	
	# Remove effect when regeneration slows
	var cleanup_timer = create_tween()
	cleanup_timer.tween_delay(5.0)
	cleanup_timer.tween_callback(regen_effect.queue_free)

## Create overload effect
func _create_overload_effect() -> Node3D:
	var overload_node = Node3D.new()
	overload_node.name = "ShieldOverloadEffect"
	
	# Overload particle system
	var particles = GPUParticles3D.new()
	particles.name = "OverloadParticles"
	particles.emitting = false
	particles.amount = 60
	particles.lifetime = 1.5
	overload_node.add_child(particles)
	
	# Overload light
	var light = OmniLight3D.new()
	light.name = "OverloadLight"
	light.light_color = Color.WHITE
	light.light_energy = 0.0
	light.omni_range = 12.0
	overload_node.add_child(light)
	
	return overload_node

## Configure overload effect
func _configure_overload_effect(effect: Node3D, severity: float, quadrant: int) -> void:
	var particles = effect.get_node_or_null("OverloadParticles")
	if particles and particles is GPUParticles3D:
		particles.amount = int(60 * severity)
		particles.emitting = true
	
	var light = effect.get_node_or_null("OverloadLight")
	if light and light is OmniLight3D:
		light.light_color = QUADRANT_COLORS[quadrant]
		light.light_energy = severity * 4.0
		
		# Animate overload flash
		var flash_tween = create_tween()
		flash_tween.tween_property(light, "light_energy", 0.0, 1.0)

## Get effect from pools
func _get_impact_effect_from_pool() -> Node3D:
	for effect in impact_effect_pool:
		if not effect.visible:
			return effect
	return null

func _get_ripple_effect_from_pool() -> Node3D:
	for effect in ripple_effect_pool:
		if not effect.visible:
			return effect
	return null

func _get_overload_effect_from_pool() -> Node3D:
	for effect in overload_effect_pool:
		if not effect.visible:
			return effect
	return null

## Cleanup effects
func _cleanup_ripple_effect(effect: Node3D) -> void:
	effect.visible = false
	if effect.get_parent():
		effect.get_parent().remove_child(effect)

func _cleanup_overload_effect(effect: Node3D) -> void:
	effect.visible = false
	if effect.get_parent():
		effect.get_parent().remove_child(effect)

## Get quadrant positions
func _get_quadrant_center_position(quadrant: int) -> Vector3:
	if not owner_ship:
		return Vector3.ZERO
	
	var base_pos = owner_ship.global_position
	var offset = Vector3.ZERO
	
	match quadrant:
		SHIELD_QUADRANTS.FRONT:
			offset = Vector3(0, 0, shield_bubble_radius * 0.7)
		SHIELD_QUADRANTS.REAR:
			offset = Vector3(0, 0, -shield_bubble_radius * 0.7)
		SHIELD_QUADRANTS.PORT:
			offset = Vector3(-shield_bubble_radius * 0.7, 0, 0)
		SHIELD_QUADRANTS.STARBOARD:
			offset = Vector3(shield_bubble_radius * 0.7, 0, 0)
	
	return base_pos + offset

func _get_quadrant_indicator_position(quadrant: int) -> Vector3:
	var center = _get_quadrant_center_position(quadrant)
	return center + Vector3(0, 2, 0)  # Slightly above center

## Cull oldest impact effects
func _cull_oldest_impact_effects() -> void:
	if active_impacts.is_empty():
		return
	
	# Remove oldest impact
	var oldest_impact = active_impacts[0]
	var effect = oldest_impact.get("effect")
	if effect and is_instance_valid(effect):
		effect.queue_free()
	
	active_impacts.remove_at(0)

## Check if shield bubble should be hidden
func _check_hide_shield_bubble() -> void:
	# Hide shield if no recent impacts and not regenerating
	var current_time = Time.get_ticks_msec() / 1000.0
	var hide_shield = true
	
	for state in quadrant_states:
		if state["regenerating"] or (current_time - state["last_impact_time"]) < 3.0:
			hide_shield = false
			break
	
	if hide_shield:
		shield_bubble_mesh.visible = false
		shield_bubble_visible = false

## Signal handlers
func _on_shield_hit(hit_data: Dictionary) -> void:
	create_shield_impact_effect(hit_data)

func _on_quadrant_depleted(quadrant: int, depletion_data: Dictionary) -> void:
	visualize_shield_quadrant_failure(quadrant, depletion_data)

func _on_shield_regenerating(quadrant: int, strength: float, regen_rate: float) -> void:
	visualize_shield_regeneration(quadrant, strength, regen_rate)

func _on_shield_overload(quadrant: int, overload_data: Dictionary) -> void:
	var severity = overload_data.get("severity", 1.0)
	create_shield_overload_effect(quadrant, severity)

## Process frame updates
func _process(delta: float) -> void:
	quadrant_update_timer += delta
	shield_flicker_timer += delta
	
	# Update quadrant states
	if quadrant_update_timer >= quadrant_update_frequency:
		quadrant_update_timer = 0.0
		_update_quadrant_states()
	
	# Shield flicker effect for low shields
	if shield_flicker_timer >= shield_flicker_frequency:
		shield_flicker_timer = 0.0
		_update_shield_flicker()
	
	# Cleanup expired impacts
	_cleanup_expired_impacts()

## Update quadrant states
func _update_quadrant_states() -> void:
	# Update each quadrant's visual state
	for i in range(quadrant_states.size()):
		var state = quadrant_states[i]
		_update_quadrant_indicator(i, state["strength"], state["failed"])

## Update shield flicker
func _update_shield_flicker() -> void:
	if not shield_bubble_mesh or not shield_bubble_visible:
		return
	
	# Calculate overall shield health
	var total_strength = 0.0
	for state in quadrant_states:
		total_strength += state["strength"]
	total_strength /= quadrant_states.size()
	
	# Flicker when shields are low
	if total_strength < 0.3:
		var flicker_alpha = shield_opacity * (0.5 + randf() * 0.5)
		var material = shield_bubble_mesh.material_override
		if material and material is StandardMaterial3D:
			(material as StandardMaterial3D).albedo_color.a = flicker_alpha

## Cleanup expired impacts
func _cleanup_expired_impacts() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var expired_impacts: Array[int] = []
	
	for i in range(active_impacts.size()):
		var impact = active_impacts[i]
		var start_time = impact.get("start_time", 0.0)
		var duration = impact.get("duration", impact_effect_duration)
		
		if current_time - start_time > duration:
			expired_impacts.append(i)
	
	# Remove expired impacts (reverse order to maintain indices)
	for i in range(expired_impacts.size() - 1, -1, -1):
		var impact_index = expired_impacts[i]
		var impact = active_impacts[impact_index]
		var effect = impact.get("effect")
		if effect and is_instance_valid(effect):
			effect.queue_free()
		active_impacts.remove_at(impact_index)