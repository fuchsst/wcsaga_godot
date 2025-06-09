class_name DamageVisualizationController
extends Node

## SHIP-012 AC3: Damage Visualization Controller  
## Shows progressive hull damage, subsystem failures, and armor degradation with real-time updates
## Implements WCS-authentic damage state visualization with performance optimization

# EPIC-002 Asset Core Integration
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const ArmorTypes = preload("res://addons/wcs_asset_core/constants/armor_types.gd")

# Signals
signal damage_visualization_updated(zone_name: String, damage_level: float)
signal subsystem_failure_visualized(subsystem_name: String, failure_type: String)
signal hull_breach_detected(breach_location: Vector3, breach_severity: float)
signal emergency_lighting_activated(activation_level: float)

# Ship references
var owner_ship: Node = null
var ship_mesh: MeshInstance3D = null
var damage_system: Node = null
var subsystem_manager: Node = null
var armor_system: Node = null

# Damage visualization data
var damage_zones: Dictionary = {}
var subsystem_indicators: Dictionary = {}
var hull_breach_effects: Array[Node3D] = []
var damage_textures: Dictionary = {}
var emergency_lighting: Array[Light3D] = []

# Visual effect pools
var spark_effect_pool: Array[Node3D] = []
var smoke_effect_pool: Array[Node3D] = []
var fire_effect_pool: Array[Node3D] = []
var breach_effect_pool: Array[Node3D] = []

# Configuration
@export var enable_progressive_damage: bool = true
@export var enable_subsystem_indicators: bool = true
@export var enable_hull_breach_effects: bool = true
@export var enable_emergency_lighting: bool = true
@export var debug_damage_visualization: bool = false

# Visual parameters
@export var damage_texture_resolution: int = 512
@export var subsystem_indicator_size: float = 0.5
@export var hull_breach_particle_count: int = 30
@export var emergency_light_intensity: float = 1.5

# Performance settings
@export var max_simultaneous_effects: int = 50
@export var effect_culling_distance: float = 200.0
@export var update_frequency: float = 0.5
@export var lod_distance_thresholds: Array[float] = [50.0, 100.0, 200.0]

# Damage state thresholds
@export var light_damage_threshold: float = 0.75   # 75% health
@export var moderate_damage_threshold: float = 0.5 # 50% health  
@export var heavy_damage_threshold: float = 0.25   # 25% health
@export var critical_damage_threshold: float = 0.1 # 10% health

# Update timing
var update_timer: float = 0.0
var current_camera_distance: float = 0.0

func _ready() -> void:
	_setup_damage_visualization_system()
	_initialize_effect_pools()

## Initialize damage visualization for a ship
func initialize_for_ship(ship: Node) -> void:
	owner_ship = ship
	
	# Find required components
	ship_mesh = _find_ship_mesh(ship)
	damage_system = ship.get_node_or_null("DamageManager")
	subsystem_manager = ship.get_node_or_null("SubsystemManager")
	armor_system = ship.get_node_or_null("ArmorDegradationTracker")
	
	if not ship_mesh:
		push_warning("DamageVisualizationController: No ship mesh found for %s" % ship.name)
		return
	
	# Setup damage zones based on ship structure
	_setup_damage_zones()
	
	# Initialize subsystem indicators
	if enable_subsystem_indicators:
		_setup_subsystem_indicators()
	
	# Setup emergency lighting
	if enable_emergency_lighting:
		_setup_emergency_lighting()
	
	# Connect to damage system signals
	_connect_damage_system_signals()
	
	if debug_damage_visualization:
		print("DamageVisualizationController: Initialized for ship %s" % ship.name)

## Update damage visualization for specific zone
func update_zone_damage_visualization(zone_name: String, damage_level: float) -> void:
	if not damage_zones.has(zone_name):
		_create_damage_zone(zone_name)
	
	var zone_data = damage_zones[zone_name]
	var previous_level = zone_data.get("damage_level", 0.0)
	zone_data["damage_level"] = damage_level
	
	# Determine damage state
	var damage_state = _get_damage_state(damage_level)
	zone_data["damage_state"] = damage_state
	
	# Update visual effects based on damage progression
	if damage_level > previous_level:
		_apply_progressive_damage_effects(zone_name, damage_level, previous_level)
	
	# Update zone visual representation
	_update_zone_visual_effects(zone_name, zone_data)
	
	# Check for hull breach
	if damage_level >= critical_damage_threshold and previous_level < critical_damage_threshold:
		_create_hull_breach_effect(zone_name, zone_data)
	
	damage_visualization_updated.emit(zone_name, damage_level)
	
	if debug_damage_visualization:
		print("DamageVisualizationController: Updated %s damage to %.1f%% (%s)" % [
			zone_name, (1.0 - damage_level) * 100, damage_state
		])

## Visualize subsystem failure
func visualize_subsystem_failure(subsystem_name: String, failure_type: String, severity: float) -> void:
	if not enable_subsystem_indicators:
		return
	
	# Get or create subsystem indicator
	var indicator = _get_subsystem_indicator(subsystem_name)
	if not indicator:
		return
	
	# Configure indicator based on failure type
	_configure_subsystem_failure_indicator(indicator, failure_type, severity)
	
	# Add failure effects
	match failure_type:
		"power_failure":
			_add_power_failure_effects(indicator, severity)
		"structural_damage":
			_add_structural_damage_effects(indicator, severity)
		"thermal_overload":
			_add_thermal_overload_effects(indicator, severity)
		"electrical_short":
			_add_electrical_short_effects(indicator, severity)
	
	subsystem_failure_visualized.emit(subsystem_name, failure_type)

## Update hull integrity visualization
func update_hull_integrity_visualization(overall_integrity: float) -> void:
	if not ship_mesh:
		return
	
	# Update overall hull material properties
	_update_hull_material(overall_integrity)
	
	# Update emergency lighting based on hull integrity
	if enable_emergency_lighting:
		_update_emergency_lighting(overall_integrity)
	
	# Check for critical hull state
	if overall_integrity <= critical_damage_threshold:
		_activate_critical_hull_state()

## Create hull breach effect at location
func create_hull_breach_effect(breach_location: Vector3, breach_severity: float) -> void:
	if not enable_hull_breach_effects:
		return
	
	var breach_effect = _get_breach_effect_from_pool()
	if not breach_effect:
		breach_effect = _create_breach_effect()
	
	# Position and configure breach effect
	breach_effect.global_position = breach_location
	_configure_breach_effect(breach_effect, breach_severity)
	
	# Add to ship
	if owner_ship:
		owner_ship.add_child(breach_effect)
	hull_breach_effects.append(breach_effect)
	
	hull_breach_detected.emit(breach_location, breach_severity)
	
	if debug_damage_visualization:
		print("DamageVisualizationController: Created hull breach at %s (severity: %.1f)" % [
			breach_location, breach_severity
		])

## Setup damage visualization system
func _setup_damage_visualization_system() -> void:
	damage_zones.clear()
	subsystem_indicators.clear()
	hull_breach_effects.clear()
	damage_textures.clear()
	emergency_lighting.clear()
	
	# Initialize update timer
	update_timer = 0.0

## Initialize effect pools for performance
func _initialize_effect_pools() -> void:
	# Spark effect pool
	for i in range(20):
		var spark_effect = _create_spark_effect()
		spark_effect.visible = false
		spark_effect_pool.append(spark_effect)
	
	# Smoke effect pool
	for i in range(15):
		var smoke_effect = _create_smoke_effect()
		smoke_effect.visible = false
		smoke_effect_pool.append(smoke_effect)
	
	# Fire effect pool
	for i in range(10):
		var fire_effect = _create_fire_effect()
		fire_effect.visible = false
		fire_effect_pool.append(fire_effect)
	
	# Hull breach effect pool
	for i in range(5):
		var breach_effect = _create_breach_effect()
		breach_effect.visible = false
		breach_effect_pool.append(breach_effect)

## Setup damage zones based on ship structure
func _setup_damage_zones() -> void:
	if not ship_mesh:
		return
	
	# Create basic damage zones
	var zone_names = ["hull_front", "hull_mid", "hull_rear", "wings", "engines"]
	
	for zone_name in zone_names:
		_create_damage_zone(zone_name)

## Create damage zone
func _create_damage_zone(zone_name: String) -> void:
	damage_zones[zone_name] = {
		"zone_name": zone_name,
		"damage_level": 0.0,
		"damage_state": "pristine",
		"visual_effects": [],
		"last_update": 0.0,
		"position": _estimate_zone_position(zone_name),
		"size": _estimate_zone_size(zone_name)
	}

## Setup subsystem indicators
func _setup_subsystem_indicators() -> void:
	if not subsystem_manager:
		return
	
	# Get subsystems from manager
	var subsystems = subsystem_manager.get_subsystems() if subsystem_manager.has_method("get_subsystems") else {}
	
	for subsystem_name in subsystems.keys():
		_create_subsystem_indicator(subsystem_name)

## Create subsystem indicator
func _create_subsystem_indicator(subsystem_name: String) -> void:
	var indicator = Node3D.new()
	indicator.name = subsystem_name + "_indicator"
	
	# Indicator mesh
	var mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = subsystem_indicator_size * 0.5
	mesh_instance.mesh = sphere_mesh
	
	# Indicator material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.GREEN  # Default healthy state
	material.emission_enabled = true
	material.emission = Color.GREEN * 0.3
	mesh_instance.material_override = material
	
	indicator.add_child(mesh_instance)
	
	# Position indicator
	indicator.global_position = _estimate_subsystem_position(subsystem_name)
	
	subsystem_indicators[subsystem_name] = indicator
	
	if owner_ship:
		owner_ship.add_child(indicator)

## Setup emergency lighting
func _setup_emergency_lighting() -> void:
	if not owner_ship:
		return
	
	# Create emergency lights at strategic locations
	var light_positions = [
		Vector3(0, 1, 2),   # Front
		Vector3(-2, 0, 0),  # Port
		Vector3(2, 0, 0),   # Starboard
		Vector3(0, 1, -2)   # Rear
	]
	
	for pos in light_positions:
		var emergency_light = OmniLight3D.new()
		emergency_light.name = "EmergencyLight"
		emergency_light.light_color = Color.RED
		emergency_light.light_energy = 0.0
		emergency_light.omni_range = 10.0
		emergency_light.global_position = pos
		
		emergency_lighting.append(emergency_light)
		owner_ship.add_child(emergency_light)

## Connect to damage system signals
func _connect_damage_system_signals() -> void:
	if damage_system:
		if damage_system.has_signal("hull_damaged"):
			damage_system.hull_damaged.connect(_on_hull_damaged)
		if damage_system.has_signal("subsystem_damaged"):
			damage_system.subsystem_damaged.connect(_on_subsystem_damaged)
		if damage_system.has_signal("critical_damage_detected"):
			damage_system.critical_damage_detected.connect(_on_critical_damage_detected)
	
	if subsystem_manager:
		if subsystem_manager.has_signal("subsystem_failed"):
			subsystem_manager.subsystem_failed.connect(_on_subsystem_failed)
		if subsystem_manager.has_signal("subsystem_destroyed"):
			subsystem_manager.subsystem_destroyed.connect(_on_subsystem_destroyed)

## Find ship mesh component
func _find_ship_mesh(ship: Node) -> MeshInstance3D:
	# Search for MeshInstance3D in ship hierarchy
	for child in ship.get_children():
		if child is MeshInstance3D:
			return child
		
		# Search recursively
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

## Get damage state from damage level
func _get_damage_state(damage_level: float) -> String:
	var health = 1.0 - damage_level
	
	if health >= light_damage_threshold:
		return "pristine"
	elif health >= moderate_damage_threshold:
		return "light_damage"
	elif health >= heavy_damage_threshold:
		return "moderate_damage"
	elif health >= critical_damage_threshold:
		return "heavy_damage"
	else:
		return "critical_damage"

## Apply progressive damage effects
func _apply_progressive_damage_effects(zone_name: String, current_level: float, previous_level: float) -> void:
	var current_state = _get_damage_state(current_level)
	var previous_state = _get_damage_state(previous_level)
	
	if current_state != previous_state:
		_transition_damage_state(zone_name, previous_state, current_state)

## Transition between damage states
func _transition_damage_state(zone_name: String, from_state: String, to_state: String) -> void:
	var zone_data = damage_zones[zone_name]
	var zone_position = zone_data.get("position", Vector3.ZERO)
	
	match to_state:
		"light_damage":
			_add_light_damage_effects(zone_name, zone_position)
		"moderate_damage":
			_add_moderate_damage_effects(zone_name, zone_position)
		"heavy_damage":
			_add_heavy_damage_effects(zone_name, zone_position)
		"critical_damage":
			_add_critical_damage_effects(zone_name, zone_position)

## Add light damage effects
func _add_light_damage_effects(zone_name: String, position: Vector3) -> void:
	# Occasional sparks
	var spark_effect = _get_spark_effect_from_pool()
	if spark_effect:
		spark_effect.global_position = position
		spark_effect.visible = true
		_configure_light_spark_effect(spark_effect)

## Add moderate damage effects  
func _add_moderate_damage_effects(zone_name: String, position: Vector3) -> void:
	# More frequent sparks + light smoke
	var spark_effect = _get_spark_effect_from_pool()
	if spark_effect:
		spark_effect.global_position = position
		spark_effect.visible = true
		_configure_moderate_spark_effect(spark_effect)
	
	var smoke_effect = _get_smoke_effect_from_pool()
	if smoke_effect:
		smoke_effect.global_position = position
		smoke_effect.visible = true
		_configure_light_smoke_effect(smoke_effect)

## Add heavy damage effects
func _add_heavy_damage_effects(zone_name: String, position: Vector3) -> void:
	# Heavy sparks + smoke + occasional fire
	var spark_effect = _get_spark_effect_from_pool()
	if spark_effect:
		spark_effect.global_position = position
		spark_effect.visible = true
		_configure_heavy_spark_effect(spark_effect)
	
	var smoke_effect = _get_smoke_effect_from_pool()
	if smoke_effect:
		smoke_effect.global_position = position
		smoke_effect.visible = true
		_configure_heavy_smoke_effect(smoke_effect)
	
	if randf() < 0.5:  # 50% chance of fire
		var fire_effect = _get_fire_effect_from_pool()
		if fire_effect:
			fire_effect.global_position = position
			fire_effect.visible = true
			_configure_fire_effect(fire_effect)

## Add critical damage effects
func _add_critical_damage_effects(zone_name: String, position: Vector3) -> void:
	# All effects + emergency lighting
	_add_heavy_damage_effects(zone_name, position)
	
	# Additional critical effects
	_create_hull_breach_effect(zone_name, damage_zones[zone_name])
	
	# Activate emergency lighting
	if enable_emergency_lighting:
		_activate_emergency_lighting()

## Update zone visual effects
func _update_zone_visual_effects(zone_name: String, zone_data: Dictionary) -> void:
	# Update material properties based on damage
	_update_zone_material(zone_name, zone_data)
	
	# Update any active effects
	_update_zone_active_effects(zone_name, zone_data)

## Update zone material
func _update_zone_material(zone_name: String, zone_data: Dictionary) -> void:
	if not ship_mesh:
		return
	
	var damage_level = zone_data.get("damage_level", 0.0)
	var material = ship_mesh.material_override
	
	if not material:
		material = StandardMaterial3D.new()
		ship_mesh.material_override = material
	
	# Darken material based on damage
	var damage_factor = damage_level
	var base_color = Color.WHITE
	var damaged_color = base_color.lerp(Color.GRAY, damage_factor)
	
	if material is StandardMaterial3D:
		(material as StandardMaterial3D).albedo_color = damaged_color

## Update hull material
func _update_hull_material(integrity: float) -> void:
	if not ship_mesh:
		return
	
	var material = ship_mesh.material_override
	if not material:
		material = StandardMaterial3D.new()
		ship_mesh.material_override = material
	
	if material is StandardMaterial3D:
		var std_material = material as StandardMaterial3D
		
		# Adjust material properties based on integrity
		var damage_factor = 1.0 - integrity
		std_material.metallic = 0.5 + (damage_factor * 0.3)
		std_material.roughness = 0.3 + (damage_factor * 0.5)

## Update emergency lighting
func _update_emergency_lighting(hull_integrity: float) -> void:
	var activation_level = 1.0 - hull_integrity
	
	for light in emergency_lighting:
		if light and light is OmniLight3D:
			(light as OmniLight3D).light_energy = activation_level * emergency_light_intensity

## Activate emergency lighting
func _activate_emergency_lighting() -> void:
	for light in emergency_lighting:
		if light and light is OmniLight3D:
			(light as OmniLight3D).light_energy = emergency_light_intensity
	
	emergency_lighting_activated.emit(1.0)

## Create hull breach effect
func _create_hull_breach_effect(zone_name: String, zone_data: Dictionary) -> void:
	var position = zone_data.get("position", Vector3.ZERO)
	var damage_level = zone_data.get("damage_level", 0.0)
	
	create_hull_breach_effect(position, damage_level)

## Get subsystem indicator
func _get_subsystem_indicator(subsystem_name: String) -> Node3D:
	return subsystem_indicators.get(subsystem_name)

## Configure subsystem failure indicator
func _configure_subsystem_failure_indicator(indicator: Node3D, failure_type: String, severity: float) -> void:
	var mesh_instance = indicator.get_child(0) as MeshInstance3D
	if not mesh_instance:
		return
	
	var material = mesh_instance.material_override as StandardMaterial3D
	if not material:
		return
	
	# Set color based on failure type
	match failure_type:
		"power_failure":
			material.albedo_color = Color.YELLOW
			material.emission = Color.YELLOW * 0.5
		"structural_damage":
			material.albedo_color = Color.RED
			material.emission = Color.RED * 0.5
		"thermal_overload":
			material.albedo_color = Color.ORANGE
			material.emission = Color.ORANGE * 0.5
		"electrical_short":
			material.albedo_color = Color.CYAN
			material.emission = Color.CYAN * 0.5
		_:
			material.albedo_color = Color.RED
			material.emission = Color.RED * 0.5
	
	# Scale based on severity
	indicator.scale = Vector3.ONE * (1.0 + severity * 0.5)

## Effect creation and configuration methods
func _create_spark_effect() -> Node3D:
	var spark_node = Node3D.new()
	spark_node.name = "SparkEffect"
	
	var particles = GPUParticles3D.new()
	particles.emitting = false
	particles.amount = 20
	particles.lifetime = 1.0
	spark_node.add_child(particles)
	
	return spark_node

func _create_smoke_effect() -> Node3D:
	var smoke_node = Node3D.new()
	smoke_node.name = "SmokeEffect"
	
	var particles = GPUParticles3D.new()
	particles.emitting = false
	particles.amount = 30
	particles.lifetime = 3.0
	smoke_node.add_child(particles)
	
	return smoke_node

func _create_fire_effect() -> Node3D:
	var fire_node = Node3D.new()
	fire_node.name = "FireEffect"
	
	var particles = GPUParticles3D.new()
	particles.emitting = false
	particles.amount = 40
	particles.lifetime = 2.0
	fire_node.add_child(particles)
	
	return fire_node

func _create_breach_effect() -> Node3D:
	var breach_node = Node3D.new()
	breach_node.name = "BreachEffect"
	
	var particles = GPUParticles3D.new()
	particles.emitting = false
	particles.amount = hull_breach_particle_count
	particles.lifetime = 5.0
	breach_node.add_child(particles)
	
	return breach_node

## Effect pool getters
func _get_spark_effect_from_pool() -> Node3D:
	for effect in spark_effect_pool:
		if not effect.visible:
			return effect
	return null

func _get_smoke_effect_from_pool() -> Node3D:
	for effect in smoke_effect_pool:
		if not effect.visible:
			return effect
	return null

func _get_fire_effect_from_pool() -> Node3D:
	for effect in fire_effect_pool:
		if not effect.visible:
			return effect
	return null

func _get_breach_effect_from_pool() -> Node3D:
	for effect in breach_effect_pool:
		if not effect.visible:
			return effect
	return null

## Effect configuration methods
func _configure_light_spark_effect(effect: Node3D) -> void:
	var particles = effect.get_child(0) as GPUParticles3D
	if particles:
		particles.amount = 10
		particles.emitting = true

func _configure_moderate_spark_effect(effect: Node3D) -> void:
	var particles = effect.get_child(0) as GPUParticles3D
	if particles:
		particles.amount = 20
		particles.emitting = true

func _configure_heavy_spark_effect(effect: Node3D) -> void:
	var particles = effect.get_child(0) as GPUParticles3D
	if particles:
		particles.amount = 30
		particles.emitting = true

func _configure_light_smoke_effect(effect: Node3D) -> void:
	var particles = effect.get_child(0) as GPUParticles3D
	if particles:
		particles.amount = 15
		particles.emitting = true

func _configure_heavy_smoke_effect(effect: Node3D) -> void:
	var particles = effect.get_child(0) as GPUParticles3D
	if particles:
		particles.amount = 40
		particles.emitting = true

func _configure_fire_effect(effect: Node3D) -> void:
	var particles = effect.get_child(0) as GPUParticles3D
	if particles:
		particles.amount = 35
		particles.emitting = true

func _configure_breach_effect(effect: Node3D, severity: float) -> void:
	var particles = effect.get_child(0) as GPUParticles3D
	if particles:
		particles.amount = int(hull_breach_particle_count * severity)
		particles.emitting = true

## Estimate zone positions and sizes
func _estimate_zone_position(zone_name: String) -> Vector3:
	match zone_name:
		"hull_front":
			return Vector3(0, 0, 2)
		"hull_mid":
			return Vector3(0, 0, 0)
		"hull_rear":
			return Vector3(0, 0, -2)
		"wings":
			return Vector3(0, 0, 0)
		"engines":
			return Vector3(0, 0, -3)
		_:
			return Vector3.ZERO

func _estimate_zone_size(zone_name: String) -> Vector3:
	match zone_name:
		"hull_front":
			return Vector3(2, 2, 2)
		"hull_mid":
			return Vector3(3, 2, 3)
		"hull_rear":
			return Vector3(2, 2, 2)
		"wings":
			return Vector3(6, 1, 3)
		"engines":
			return Vector3(2, 2, 2)
		_:
			return Vector3.ONE

func _estimate_subsystem_position(subsystem_name: String) -> Vector3:
	match subsystem_name.to_lower():
		"engine":
			return Vector3(0, 0, -2)
		"weapons":
			return Vector3(0, 0, 1)
		"shields":
			return Vector3(0, 1, 0)
		"sensors":
			return Vector3(0, 1, 1)
		_:
			return Vector3.ZERO

## Update zone active effects
func _update_zone_active_effects(zone_name: String, zone_data: Dictionary) -> void:
	# Update any ongoing effects for this zone
	var effects = zone_data.get("visual_effects", [])
	for effect in effects:
		if effect and is_instance_valid(effect):
			# Update effect based on current damage state
			pass

## Add subsystem failure effects  
func _add_power_failure_effects(indicator: Node3D, severity: float) -> void:
	# Power failure - flickering light effect
	pass

func _add_structural_damage_effects(indicator: Node3D, severity: float) -> void:
	# Structural damage - debris and sparks
	pass

func _add_thermal_overload_effects(indicator: Node3D, severity: float) -> void:
	# Thermal overload - heat distortion and smoke
	pass

func _add_electrical_short_effects(indicator: Node3D, severity: float) -> void:
	# Electrical short - electrical arcs and sparks
	pass

## Activate critical hull state
func _activate_critical_hull_state() -> void:
	# Activate all emergency systems
	_activate_emergency_lighting()
	
	# Add critical hull effects
	for zone_data in damage_zones.values():
		if zone_data.get("damage_level", 0.0) > heavy_damage_threshold:
			_add_critical_damage_effects(zone_data["zone_name"], zone_data["position"])

## Signal handlers
func _on_hull_damaged(zone_name: String, damage_amount: float, total_damage: float) -> void:
	update_zone_damage_visualization(zone_name, total_damage)

func _on_subsystem_damaged(subsystem_name: String, damage_amount: float, health_percentage: float) -> void:
	if health_percentage < 0.5:  # 50% health threshold
		visualize_subsystem_failure(subsystem_name, "structural_damage", 1.0 - health_percentage)

func _on_critical_damage_detected(damage_data: Dictionary) -> void:
	var location = damage_data.get("location", Vector3.ZERO)
	var severity = damage_data.get("severity", 1.0)
	create_hull_breach_effect(location, severity)

func _on_subsystem_failed(subsystem_name: String, failure_type: String) -> void:
	visualize_subsystem_failure(subsystem_name, failure_type, 1.0)

func _on_subsystem_destroyed(subsystem_name: String) -> void:
	visualize_subsystem_failure(subsystem_name, "destroyed", 1.0)

## Process frame updates
func _process(delta: float) -> void:
	update_timer += delta
	
	if update_timer >= update_frequency:
		update_timer = 0.0
		_update_damage_visualizations()

## Update damage visualizations
func _update_damage_visualizations() -> void:
	if not enable_progressive_damage:
		return
	
	# Update active damage effects
	_update_active_damage_effects()
	
	# Cull distant effects for performance
	_cull_distant_effects()

## Update active damage effects
func _update_active_damage_effects() -> void:
	# Update any time-based damage effects
	pass

## Cull distant effects for performance
func _cull_distant_effects() -> void:
	# Remove effects that are too far from camera
	pass