class_name DamageVisualizationManager
extends Node

## Damage visualization system displaying hull damage states, shield effect indicators, and subsystem damage feedback
## Handles WCS-authentic visual damage representation with real-time feedback (SHIP-009 AC4)

# EPIC-002 Asset Core Integration
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")

# Damage visualization signals (SHIP-009 AC4)
signal damage_effect_spawned(effect_type: String, location: Vector3)
signal hull_visualization_updated(damage_percentage: float, visible_damage: bool)
signal shield_effect_triggered(quadrant: int, impact_strength: float)
signal critical_effect_activated(effect_type: String, severity: float)

# Ship integration
var ship: BaseShip
var ship_model: Node3D
var damage_manager: Node

# Hull damage visualization (SHIP-009 AC4)
var hull_damage_states: Dictionary = {}
var damage_decals: Array[Node3D] = []
var hull_material_overrides: Dictionary = {}
var damage_texture_variants: Array[String] = []

# Shield visualization
var shield_effect_nodes: Array[Node3D] = []
var shield_impact_effects: Dictionary = {}
var shield_quadrant_indicators: Array[Node3D] = []

# Critical damage effects
var critical_effect_spawners: Dictionary = {}
var fire_effects: Array[Node3D] = []
var smoke_effects: Array[Node3D] = []
var spark_effects: Array[Node3D] = []
var explosion_effects: Array[Node3D] = []

# Damage level thresholds for visual states
var damage_level_thresholds: Array[float] = [90.0, 75.0, 50.0, 25.0, 10.0]
var current_damage_level: int = 0

# Performance settings
var max_active_effects: int = 20
var effect_cleanup_interval: float = 5.0
var last_cleanup_time: float = 0.0

func _ready() -> void:
	name = "DamageVisualizationManager"
	_load_damage_resources()

func _physics_process(delta: float) -> void:
	# Update visual effects
	_update_damage_effects(delta)
	
	# Cleanup old effects periodically
	_cleanup_effects(delta)

## Initialize damage visualization system for specific ship (SHIP-009 AC4)
func initialize_visualization_system(parent_ship: BaseShip) -> bool:
	"""Initialize damage visualization system for specific ship.
	
	Args:
		parent_ship: Ship to visualize damage for
		
	Returns:
		true if initialization successful
	"""
	if not parent_ship:
		push_error("DamageVisualizationManager: Cannot initialize with null ship")
		return false
	
	ship = parent_ship
	ship_model = ship.get_node_or_null("ShipModel")
	damage_manager = ship.get_node_or_null("DamageManager")
	
	# Setup hull damage visualization
	_setup_hull_damage_visualization()
	
	# Setup shield effect visualization
	_setup_shield_visualization()
	
	# Setup critical effect spawners
	_setup_critical_effect_spawners()
	
	# Connect to damage system signals
	_connect_damage_signals()
	
	return true

## Load damage visualization resources
func _load_damage_resources() -> void:
	"""Load textures, materials, and prefabs for damage visualization."""
	# Load damage texture variants
	damage_texture_variants = [
		"res://assets/effects/damage/hull_damage_light.png",
		"res://assets/effects/damage/hull_damage_medium.png", 
		"res://assets/effects/damage/hull_damage_heavy.png",
		"res://assets/effects/damage/hull_damage_critical.png",
		"res://assets/effects/damage/hull_damage_destroyed.png"
	]
	
	# Note: These would be actual texture resources in a real implementation
	# For now, we'll create procedural damage materials

## Setup hull damage visualization (SHIP-009 AC4)
func _setup_hull_damage_visualization() -> void:
	"""Setup hull damage visualization system."""
	if not ship_model:
		return
	
	# Create damage state tracking for different hull sections
	hull_damage_states = {
		"front": {"damage": 0.0, "visible": false, "decals": []},
		"rear": {"damage": 0.0, "visible": false, "decals": []},
		"left": {"damage": 0.0, "visible": false, "decals": []},
		"right": {"damage": 0.0, "visible": false, "decals": []},
		"top": {"damage": 0.0, "visible": false, "decals": []},
		"bottom": {"damage": 0.0, "visible": false, "decals": []}
	}
	
	# Prepare hull material overrides
	_prepare_hull_materials()

## Setup shield effect visualization
func _setup_shield_visualization() -> void:
	"""Setup shield impact and quadrant visualization."""
	# Create shield quadrant indicators (4 quadrants)
	for i in range(4):
		var indicator: Node3D = _create_shield_quadrant_indicator(i)
		shield_quadrant_indicators.append(indicator)
		ship.add_child(indicator)
	
	# Initialize shield impact effect pools
	shield_impact_effects = {
		"energy": [],
		"kinetic": [],
		"explosive": []
	}

## Setup critical damage effect spawners
func _setup_critical_effect_spawners() -> void:
	"""Setup critical damage effect spawning points."""
	if not ship_model:
		return
	
	# Create effect spawner points at critical locations
	critical_effect_spawners = {
		"bridge": {"position": Vector3(0, 2, 8), "effects": []},
		"engine": {"position": Vector3(0, 0, -8), "effects": []},
		"reactor": {"position": Vector3(0, -1, 0), "effects": []},
		"weapons": {"position": Vector3(0, 1, 4), "effects": []}
	}

## Connect to damage system signals for visual feedback
func _connect_damage_signals() -> void:
	"""Connect to damage system signals for real-time visual updates."""
	if damage_manager:
		damage_manager.hull_damage_applied.connect(_on_hull_damage_applied)
		damage_manager.critical_damage_triggered.connect(_on_critical_damage_triggered)
		damage_manager.hull_strength_changed.connect(_on_hull_strength_changed)
	
	# Connect to shield manager if available
	var shield_manager: Node = ship.get_node_or_null("ShieldQuadrantManager")
	if shield_manager:
		shield_manager.quadrant_damage_absorbed.connect(_on_shield_damage_absorbed)
		shield_manager.quadrant_depleted.connect(_on_shield_quadrant_depleted)
		shield_manager.quadrant_restored.connect(_on_shield_quadrant_restored)

# ============================================================================
# HULL DAMAGE VISUALIZATION (SHIP-009 AC4)
# ============================================================================

## Update hull damage visualization based on damage state (SHIP-009 AC4)
func update_hull_damage_visualization(hull_integrity_percentage: float, hit_location: Vector3) -> void:
	"""Update hull damage visualization based on current damage state.
	
	Args:
		hull_integrity_percentage: Current hull integrity (0-100)
		hit_location: Local coordinates where damage occurred
	"""
	# Determine new damage level
	var new_damage_level: int = _calculate_damage_level(hull_integrity_percentage)
	
	# Update damage level if changed
	if new_damage_level != current_damage_level:
		current_damage_level = new_damage_level
		_update_hull_damage_materials(hull_integrity_percentage)
	
	# Add damage decal at hit location
	_add_damage_decal(hit_location, hull_integrity_percentage)
	
	# Update hull section damage
	_update_hull_section_damage(hit_location, hull_integrity_percentage)
	
	# Emit visualization update signal
	hull_visualization_updated.emit(100.0 - hull_integrity_percentage, new_damage_level > 1)

## Calculate damage level from hull integrity percentage
func _calculate_damage_level(hull_integrity_percentage: float) -> int:
	"""Calculate damage level index from hull integrity percentage."""
	for i in range(damage_level_thresholds.size()):
		if hull_integrity_percentage >= damage_level_thresholds[i]:
			return i
	return damage_level_thresholds.size()  # Maximum damage level

## Update hull damage materials based on damage level
func _update_hull_damage_materials(hull_integrity_percentage: float) -> void:
	"""Update hull materials to show progressive damage."""
	if not ship_model:
		return
	
	# Get all mesh instances in ship model
	var mesh_instances: Array[MeshInstance3D] = _get_mesh_instances(ship_model)
	
	for mesh_instance in mesh_instances:
		_apply_damage_material(mesh_instance, hull_integrity_percentage)

## Get all MeshInstance3D nodes in ship model
func _get_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	"""Recursively get all MeshInstance3D nodes in ship model."""
	var mesh_instances: Array[MeshInstance3D] = []
	
	if node is MeshInstance3D:
		mesh_instances.append(node as MeshInstance3D)
	
	for child in node.get_children():
		mesh_instances.append_array(_get_mesh_instances(child))
	
	return mesh_instances

## Apply damage material to mesh instance
func _apply_damage_material(mesh_instance: MeshInstance3D, hull_integrity_percentage: float) -> void:
	"""Apply damage material overlay to mesh instance."""
	if not mesh_instance.material_override:
		mesh_instance.material_override = mesh_instance.get_surface_override_material(0)
	
	var material: Material = mesh_instance.material_override
	if not material is StandardMaterial3D:
		return
	
	var std_material: StandardMaterial3D = material as StandardMaterial3D
	
	# Modify material based on damage level
	var damage_factor: float = (100.0 - hull_integrity_percentage) / 100.0
	
	# Darken and add burn marks
	var base_color: Color = std_material.albedo_color
	var damage_color: Color = base_color.lerp(Color(0.3, 0.2, 0.1), damage_factor * 0.7)
	std_material.albedo_color = damage_color
	
	# Add roughness for damaged look
	std_material.roughness = min(1.0, std_material.roughness + damage_factor * 0.4)
	
	# Reduce metallic for battle damage
	std_material.metallic = max(0.0, std_material.metallic - damage_factor * 0.3)

## Add damage decal at hit location (SHIP-009 AC4)
func _add_damage_decal(hit_location: Vector3, hull_integrity_percentage: float) -> void:
	"""Add damage decal at specific hit location."""
	# Limit number of decals for performance
	if damage_decals.size() >= 50:
		var oldest_decal: Node3D = damage_decals[0]
		damage_decals.remove_at(0)
		oldest_decal.queue_free()
	
	# Create damage decal
	var decal: Node3D = _create_damage_decal(hit_location, hull_integrity_percentage)
	if decal:
		ship.add_child(decal)
		damage_decals.append(decal)

## Create damage decal at location
func _create_damage_decal(location: Vector3, hull_integrity: float) -> Node3D:
	"""Create damage decal visual effect at location."""
	# Create decal using Decal node (Godot 4.x)
	var decal: Decal = Decal.new()
	decal.position = location
	
	# Set decal properties based on damage severity
	var damage_factor: float = (100.0 - hull_integrity) / 100.0
	decal.size = Vector3(0.5 + damage_factor, 0.5 + damage_factor, 0.1)
	
	# Create simple damage texture (procedural)
	var damage_texture: ImageTexture = _create_damage_texture(damage_factor)
	if damage_texture:
		decal.texture_albedo = damage_texture
	
	# Set random rotation for variety
	decal.rotation_degrees = Vector3(0, randf() * 360.0, 0)
	
	return decal

## Create procedural damage texture
func _create_damage_texture(damage_factor: float) -> ImageTexture:
	"""Create procedural damage texture based on damage severity."""
	var image: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	
	# Create burn mark pattern
	for x in range(64):
		for y in range(64):
			var center_dist: float = Vector2(x - 32, y - 32).length() / 32.0
			var burn_intensity: float = max(0.0, 1.0 - center_dist) * damage_factor
			
			var color: Color = Color(
				0.2 + burn_intensity * 0.3,  # Red
				0.1 + burn_intensity * 0.1,  # Green  
				0.05,                         # Blue
				burn_intensity                # Alpha
			)
			image.set_pixel(x, y, color)
	
	var texture: ImageTexture = ImageTexture.new()
	texture.set_image(image)
	return texture

## Update hull section damage tracking
func _update_hull_section_damage(hit_location: Vector3, hull_integrity: float) -> void:
	"""Update damage tracking for specific hull sections."""
	var section: String = _determine_hull_section(hit_location)
	
	if hull_damage_states.has(section):
		var section_data: Dictionary = hull_damage_states[section]
		section_data.damage = max(section_data.damage, 100.0 - hull_integrity)
		
		# Update section visibility
		if section_data.damage > 25.0 and not section_data.visible:
			section_data.visible = true
			_make_section_damage_visible(section)

## Determine hull section from hit location
func _determine_hull_section(hit_location: Vector3) -> String:
	"""Determine which hull section was hit based on location."""
	var abs_x: float = abs(hit_location.x)
	var abs_y: float = abs(hit_location.y) 
	var abs_z: float = abs(hit_location.z)
	
	# Find dominant axis
	if abs_z >= abs_x and abs_z >= abs_y:
		return "front" if hit_location.z > 0 else "rear"
	elif abs_y >= abs_x:
		return "top" if hit_location.y > 0 else "bottom"
	else:
		return "right" if hit_location.x > 0 else "left"

## Make hull section damage visible
func _make_section_damage_visible(section: String) -> void:
	"""Make damage visible for specific hull section."""
	# This would add section-specific damage effects
	# For now, just mark as visible
	pass

## Prepare hull materials for damage visualization
func _prepare_hull_materials() -> void:
	"""Prepare hull materials for damage modification."""
	# This would prepare material variants for different damage levels
	pass

# ============================================================================
# SHIELD EFFECT VISUALIZATION (SHIP-009 AC4)
# ============================================================================

## Trigger shield impact effect (SHIP-009 AC4)
func trigger_shield_impact_effect(quadrant: int, impact_location: Vector3, damage_amount: float, damage_type: int) -> void:
	"""Trigger shield impact visual effect.
	
	Args:
		quadrant: Shield quadrant index (0-3)
		impact_location: World position of impact
		damage_amount: Amount of damage for effect intensity
		damage_type: Type of damage for effect style
	"""
	# Create shield impact effect
	var effect: Node3D = _create_shield_impact_effect(impact_location, damage_amount, damage_type)
	if effect:
		ship.add_child(effect)
		
		# Schedule effect cleanup
		var timer: Timer = Timer.new()
		timer.wait_time = 2.0
		timer.one_shot = true
		timer.timeout.connect(func(): effect.queue_free())
		effect.add_child(timer)
		timer.start()
	
	# Update shield quadrant indicator
	_update_shield_quadrant_indicator(quadrant, damage_amount)
	
	# Emit shield effect signal
	shield_effect_triggered.emit(quadrant, damage_amount)

## Create shield impact effect
func _create_shield_impact_effect(location: Vector3, damage_amount: float, damage_type: int) -> Node3D:
	"""Create visual effect for shield impact."""
	var effect_node: Node3D = Node3D.new()
	effect_node.position = location
	
	# Create effect based on damage type
	var particles: GPUParticles3D = GPUParticles3D.new()
	effect_node.add_child(particles)
	
	# Configure particles based on damage type
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	
	match damage_type:
		DamageTypes.Type.ENERGY:
			material.emission = Color.CYAN * 2.0
			material.scale_min = 0.1
			material.scale_max = 0.3
		DamageTypes.Type.KINETIC:
			material.emission = Color.ORANGE * 1.5
			material.scale_min = 0.05
			material.scale_max = 0.2
		DamageTypes.Type.EXPLOSIVE:
			material.emission = Color.RED * 2.5
			material.scale_min = 0.2
			material.scale_max = 0.5
		_:
			material.emission = Color.WHITE * 1.0
	
	particles.process_material = material
	particles.emitting = true
	particles.amount = int(damage_amount * 2.0)
	
	return effect_node

## Update shield quadrant indicator
func _update_shield_quadrant_indicator(quadrant: int, impact_strength: float) -> void:
	"""Update shield quadrant indicator with impact feedback."""
	if quadrant < 0 or quadrant >= shield_quadrant_indicators.size():
		return
	
	var indicator: Node3D = shield_quadrant_indicators[quadrant]
	
	# Flash indicator based on impact strength
	var flash_intensity: float = min(1.0, impact_strength / 20.0)
	_flash_indicator(indicator, flash_intensity)

## Flash shield indicator
func _flash_indicator(indicator: Node3D, intensity: float) -> void:
	"""Flash shield quadrant indicator."""
	# This would animate the indicator with a flash effect
	# For now, just a placeholder implementation
	pass

## Create shield quadrant indicator
func _create_shield_quadrant_indicator(quadrant: int) -> Node3D:
	"""Create visual indicator for shield quadrant."""
	var indicator: Node3D = Node3D.new()
	indicator.name = "ShieldQuadrant_%d" % quadrant
	
	# Position indicator based on quadrant
	match quadrant:
		0:  # Front
			indicator.position = Vector3(0, 0, 6)
		1:  # Rear
			indicator.position = Vector3(0, 0, -6)
		2:  # Left
			indicator.position = Vector3(-4, 0, 0)
		3:  # Right
			indicator.position = Vector3(4, 0, 0)
	
	# Create simple visual representation
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = 0.1
	mesh_instance.mesh = sphere_mesh
	
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color.CYAN
	material.emission_enabled = true
	material.emission = Color.CYAN * 0.5
	mesh_instance.material_override = material
	
	indicator.add_child(mesh_instance)
	indicator.visible = false  # Hidden by default
	
	return indicator

# ============================================================================
# CRITICAL DAMAGE EFFECTS (SHIP-009 AC4)
# ============================================================================

## Trigger critical damage effects (SHIP-009 AC5)
func trigger_critical_damage_effects() -> void:
	"""Trigger visual effects for critical damage state."""
	# Spawn fire effects
	_spawn_fire_effects()
	
	# Spawn smoke effects 
	_spawn_smoke_effects()
	
	# Spawn electrical spark effects
	_spawn_spark_effects()
	
	# Update hull glow for critical damage
	_update_critical_damage_glow()

## Spawn fire effects at critical locations
func _spawn_fire_effects() -> void:
	"""Spawn fire effects at damaged locations."""
	for location_name in critical_effect_spawners.keys():
		var spawner: Dictionary = critical_effect_spawners[location_name]
		var fire_effect: Node3D = _create_fire_effect(spawner.position)
		
		if fire_effect:
			ship.add_child(fire_effect)
			fire_effects.append(fire_effect)
			spawner.effects.append(fire_effect)

## Spawn smoke effects
func _spawn_smoke_effects() -> void:
	"""Spawn smoke effects from damaged areas."""
	for i in range(3):  # Multiple smoke sources
		var smoke_location: Vector3 = Vector3(randf_range(-3, 3), randf_range(-1, 2), randf_range(-3, 3))
		var smoke_effect: Node3D = _create_smoke_effect(smoke_location)
		
		if smoke_effect:
			ship.add_child(smoke_effect)
			smoke_effects.append(smoke_effect)

## Spawn electrical spark effects
func _spawn_spark_effects() -> void:
	"""Spawn electrical spark effects from damaged systems."""
	for i in range(5):  # Multiple spark sources
		var spark_location: Vector3 = Vector3(randf_range(-2, 2), randf_range(-1, 1), randf_range(-2, 2))
		var spark_effect: Node3D = _create_spark_effect(spark_location)
		
		if spark_effect:
			ship.add_child(spark_effect)
			spark_effects.append(spark_effect)

## Create fire effect
func _create_fire_effect(location: Vector3) -> Node3D:
	"""Create fire effect at location."""
	var fire_node: Node3D = Node3D.new()
	fire_node.position = location
	
	var particles: GPUParticles3D = GPUParticles3D.new()
	fire_node.add_child(particles)
	
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission = Color.ORANGE * 2.0
	material.direction = Vector3(0, 1, 0)
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 4.0
	material.gravity = Vector3(0, -1, 0)
	material.scale_min = 0.2
	material.scale_max = 0.5
	
	particles.process_material = material
	particles.amount = 50
	particles.emitting = true
	
	return fire_node

## Create smoke effect
func _create_smoke_effect(location: Vector3) -> Node3D:
	"""Create smoke effect at location."""
	var smoke_node: Node3D = Node3D.new()
	smoke_node.position = location
	
	var particles: GPUParticles3D = GPUParticles3D.new()
	smoke_node.add_child(particles)
	
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission = Color.GRAY
	material.direction = Vector3(0, 1, 0)
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 2.0
	material.scale_min = 0.3
	material.scale_max = 0.8
	
	particles.process_material = material
	particles.amount = 30
	particles.emitting = true
	
	return smoke_node

## Create spark effect
func _create_spark_effect(location: Vector3) -> Node3D:
	"""Create electrical spark effect at location."""
	var spark_node: Node3D = Node3D.new()
	spark_node.position = location
	
	var particles: GPUParticles3D = GPUParticles3D.new()
	spark_node.add_child(particles)
	
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission = Color.YELLOW * 3.0
	material.direction = Vector3(0, 0, 0)
	material.initial_velocity_min = 0.5
	material.initial_velocity_max = 1.5
	material.scale_min = 0.02
	material.scale_max = 0.05
	
	particles.process_material = material
	particles.amount = 20
	particles.emitting = true
	
	return spark_node

## Update critical damage glow effect
func _update_critical_damage_glow() -> void:
	"""Update hull glow effect for critical damage."""
	if not ship_model:
		return
	
	# Add red glow to hull materials
	var mesh_instances: Array[MeshInstance3D] = _get_mesh_instances(ship_model)
	
	for mesh_instance in mesh_instances:
		if mesh_instance.material_override is StandardMaterial3D:
			var material: StandardMaterial3D = mesh_instance.material_override as StandardMaterial3D
			material.emission_enabled = true
			material.emission = Color.RED * 0.3

# ============================================================================
# EFFECT MANAGEMENT AND CLEANUP
# ============================================================================

## Update damage effects each frame
func _update_damage_effects(delta: float) -> void:
	"""Update ongoing damage effects."""
	# Update fire effects
	for fire_effect in fire_effects:
		if fire_effect and is_instance_valid(fire_effect):
			_update_fire_effect(fire_effect, delta)
	
	# Update smoke effects
	for smoke_effect in smoke_effects:
		if smoke_effect and is_instance_valid(smoke_effect):
			_update_smoke_effect(smoke_effect, delta)

## Update fire effect animation
func _update_fire_effect(fire_effect: Node3D, delta: float) -> void:
	"""Update fire effect animation."""
	# Flicker fire effect intensity
	var particles: GPUParticles3D = fire_effect.get_child(0) as GPUParticles3D
	if particles:
		var flicker: float = 0.8 + sin(Time.get_ticks_msec() * 0.01) * 0.2
		particles.amount = int(50.0 * flicker)

## Update smoke effect animation
func _update_smoke_effect(smoke_effect: Node3D, delta: float) -> void:
	"""Update smoke effect animation."""
	# Gradually reduce smoke over time
	var particles: GPUParticles3D = smoke_effect.get_child(0) as GPUParticles3D
	if particles:
		particles.amount = max(5, particles.amount - int(delta * 2.0))

## Cleanup old effects periodically
func _cleanup_effects(delta: float) -> void:
	"""Cleanup old visual effects for performance."""
	last_cleanup_time += delta
	
	if last_cleanup_time >= effect_cleanup_interval:
		last_cleanup_time = 0.0
		
		# Clean up invalid effects
		_cleanup_effect_array(fire_effects)
		_cleanup_effect_array(smoke_effects)
		_cleanup_effect_array(spark_effects)
		_cleanup_effect_array(explosion_effects)
		_cleanup_effect_array(damage_decals)

## Cleanup effect array
func _cleanup_effect_array(effect_array: Array) -> void:
	"""Remove invalid effects from array."""
	for i in range(effect_array.size() - 1, -1, -1):
		var effect = effect_array[i]
		if not effect or not is_instance_valid(effect):
			effect_array.remove_at(i)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

## Handle hull damage applied signal
func _on_hull_damage_applied(damage_amount: float, hit_location: Vector3, damage_type: int) -> void:
	"""Handle hull damage applied for visual feedback."""
	# Calculate hull integrity percentage
	var hull_integrity: float = (ship.current_hull_strength / ship.max_hull_strength) * 100.0
	
	# Update hull damage visualization
	update_hull_damage_visualization(hull_integrity, hit_location)
	
	# Spawn damage effect at impact location
	var damage_effect: Node3D = _create_hull_damage_effect(hit_location, damage_amount, damage_type)
	if damage_effect:
		ship.add_child(damage_effect)

## Handle critical damage triggered signal
func _on_critical_damage_triggered(event_type: String, affected_subsystems: Array[String]) -> void:
	"""Handle critical damage triggered for visual effects."""
	# Spawn critical damage effects
	trigger_critical_damage_effects()
	
	# Emit critical effect signal
	critical_effect_activated.emit(event_type, 2.0)

## Handle hull strength changed signal
func _on_hull_strength_changed(current_hull: float, max_hull: float, hull_percentage: float) -> void:
	"""Handle hull strength changes for progressive damage visualization."""
	# Update overall damage visualization
	update_hull_damage_visualization(hull_percentage, Vector3.ZERO)

## Handle shield damage absorbed signal
func _on_shield_damage_absorbed(quadrant_index: int, damage_amount: float) -> void:
	"""Handle shield damage absorbed for visual feedback."""
	# Calculate impact location for quadrant
	var impact_location: Vector3 = _get_quadrant_impact_location(quadrant_index)
	
	# Trigger shield impact effect
	trigger_shield_impact_effect(quadrant_index, impact_location, damage_amount, DamageTypes.Type.ENERGY)

## Handle shield quadrant depleted signal
func _on_shield_quadrant_depleted(quadrant_index: int, quadrant_name: String) -> void:
	"""Handle shield quadrant depletion."""
	# Hide shield quadrant indicator
	if quadrant_index < shield_quadrant_indicators.size():
		shield_quadrant_indicators[quadrant_index].visible = false

## Handle shield quadrant restored signal
func _on_shield_quadrant_restored(quadrant_index: int, quadrant_name: String) -> void:
	"""Handle shield quadrant restoration."""
	# Show shield quadrant indicator
	if quadrant_index < shield_quadrant_indicators.size():
		shield_quadrant_indicators[quadrant_index].visible = true

## Get impact location for shield quadrant
func _get_quadrant_impact_location(quadrant_index: int) -> Vector3:
	"""Get world position for shield quadrant impact."""
	if quadrant_index < shield_quadrant_indicators.size():
		var indicator: Node3D = shield_quadrant_indicators[quadrant_index]
		return ship.global_transform * indicator.position
	
	return ship.global_position

## Create hull damage effect
func _create_hull_damage_effect(location: Vector3, damage_amount: float, damage_type: int) -> Node3D:
	"""Create visual effect for hull damage impact."""
	var effect_node: Node3D = Node3D.new()
	effect_node.position = location
	
	# Create sparks or debris based on damage type
	var particles: GPUParticles3D = GPUParticles3D.new()
	effect_node.add_child(particles)
	
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission = Color.YELLOW
	material.direction = Vector3(0, 1, 0)
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 3.0
	material.scale_min = 0.02
	material.scale_max = 0.1
	
	particles.process_material = material
	particles.amount = int(damage_amount)
	particles.emitting = true
	
	# Auto-cleanup after 3 seconds
	var timer: Timer = Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(func(): effect_node.queue_free())
	effect_node.add_child(timer)
	timer.start()
	
	return effect_node

# ============================================================================
# DEBUG AND INFORMATION
# ============================================================================

## Get visualization status information
func get_visualization_status() -> Dictionary:
	"""Get comprehensive visualization status for debugging."""
	return {
		"current_damage_level": current_damage_level,
		"active_fire_effects": fire_effects.size(),
		"active_smoke_effects": smoke_effects.size(),
		"active_spark_effects": spark_effects.size(),
		"damage_decals": damage_decals.size(),
		"hull_damage_states": hull_damage_states,
		"shield_indicators_visible": shield_quadrant_indicators.size()
	}

## Get debug information string
func debug_info() -> String:
	"""Get debug information string."""
	return "[Visualization Level:%d Fire:%d Smoke:%d Decals:%d]" % [
		current_damage_level,
		fire_effects.size(),
		smoke_effects.size(), 
		damage_decals.size()
	]