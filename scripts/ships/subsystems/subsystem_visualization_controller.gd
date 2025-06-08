class_name SubsystemVisualizationController
extends Node

## SHIP-010 AC7: Subsystem Failure Visualization
## Displays system status with clear indicators and damage progression feedback
## Provides WCS-authentic visual feedback for subsystem states and tactical information

# EPIC-002 Asset Core Integration
const SubsystemTypes = preload("res://addons/wcs_asset_core/constants/subsystem_types.gd")

# Signals
signal visualization_updated(subsystem_name: String, visual_state: String)
signal damage_effect_triggered(subsystem_name: String, effect_type: String)
signal status_indicator_changed(subsystem_name: String, indicator_data: Dictionary)
signal hud_update_requested(subsystem_data: Dictionary)

# Visualization components
var subsystem_indicators: Dictionary = {}    # subsystem_name -> visual_indicator_node
var damage_effects: Dictionary = {}          # subsystem_name -> effect_nodes_array
var status_displays: Dictionary = {}         # subsystem_name -> status_display_data
var hud_elements: Dictionary = {}            # hud_element_name -> hud_node

# Ship references
var owner_ship: Node = null
var subsystem_health_manager: SubsystemHealthManager = null
var critical_identifier: CriticalSubsystemIdentifier = null

# Configuration
@export var enable_3d_indicators: bool = true
@export var enable_hud_integration: bool = true
@export var enable_damage_effects: bool = true
@export var enable_status_colors: bool = true
@export var debug_visualization_logging: bool = false

# Visual parameters
@export var indicator_update_frequency: float = 0.5  # Update every 500ms
@export var effect_fade_duration: float = 2.0       # Damage effects fade time
@export var critical_flash_rate: float = 1.0        # Critical systems flash rate
@export var health_bar_width: float = 2.0           # Health bar display width

# Color schemes
var health_colors: Dictionary = {
	"excellent": Color.GREEN,
	"good": Color.YELLOW,
	"damaged": Color.ORANGE,
	"critical": Color.RED,
	"destroyed": Color.DARK_RED
}

var criticality_colors: Dictionary = {
	"vital": Color.MAGENTA,
	"critical": Color.RED,
	"important": Color.YELLOW,
	"non_critical": Color.WHITE
}

# Internal state
var update_timer: float = 0.0
var flash_timer: float = 0.0
var active_effects: Array[Node3D] = []

func _ready() -> void:
	_setup_color_schemes()

## Initialize subsystem visualization controller for a ship
func initialize_for_ship(ship: Node) -> void:
	owner_ship = ship
	
	# Find required components
	subsystem_health_manager = ship.get_node_or_null("SubsystemHealthManager")
	critical_identifier = ship.get_node_or_null("CriticalSubsystemIdentifier")
	
	if not subsystem_health_manager:
		push_error("SubsystemVisualizationController: SubsystemHealthManager not found on ship")
		return
	
	# Connect to component signals
	subsystem_health_manager.subsystem_health_changed.connect(_on_subsystem_health_changed)
	subsystem_health_manager.subsystem_failed.connect(_on_subsystem_failed)
	subsystem_health_manager.subsystem_repaired.connect(_on_subsystem_repaired)
	
	if critical_identifier:
		critical_identifier.critical_threshold_exceeded.connect(_on_critical_threshold_exceeded)
		critical_identifier.ship_critical_state_changed.connect(_on_ship_critical_state_changed)
	
	# Initialize visualization components
	_setup_subsystem_indicators()
	_setup_hud_integration()
	
	if debug_visualization_logging:
		print("SubsystemVisualizationController: Initialized for ship %s" % ship.name)

## Setup 3D visual indicators for all subsystems
func _setup_subsystem_indicators() -> void:
	if not enable_3d_indicators or not subsystem_health_manager:
		return
	
	var subsystem_statuses = subsystem_health_manager.get_all_subsystem_statuses()
	
	for subsystem_name in subsystem_statuses.keys():
		_create_subsystem_indicator(subsystem_name)

## Create 3D visual indicator for a subsystem
func _create_subsystem_indicator(subsystem_name: String) -> bool:
	if subsystem_indicators.has(subsystem_name):
		return true
	
	# Create indicator node structure
	var indicator_root = Node3D.new()
	indicator_root.name = "Indicator_%s" % subsystem_name
	
	# Health bar visualization
	var health_bar = _create_health_bar(subsystem_name)
	indicator_root.add_child(health_bar)
	
	# Status light indicator
	var status_light = _create_status_light(subsystem_name)
	indicator_root.add_child(status_light)
	
	# Critical system indicator
	var critical_indicator = _create_critical_indicator(subsystem_name)
	indicator_root.add_child(critical_indicator)
	
	# Add to ship
	if owner_ship:
		owner_ship.add_child(indicator_root)
	
	# Store reference
	subsystem_indicators[subsystem_name] = {
		"root": indicator_root,
		"health_bar": health_bar,
		"status_light": status_light,
		"critical_indicator": critical_indicator,
		"last_update": 0.0
	}
	
	# Position indicator based on subsystem location
	_position_subsystem_indicator(subsystem_name)
	
	return true

## Create health bar visualization for subsystem
func _create_health_bar(subsystem_name: String) -> Node3D:
	var health_bar_root = Node3D.new()
	health_bar_root.name = "HealthBar"
	
	# Background bar
	var background = MeshInstance3D.new()
	var background_mesh = BoxMesh.new()
	background_mesh.size = Vector3(health_bar_width, 0.2, 0.1)
	background.mesh = background_mesh
	
	var background_material = StandardMaterial3D.new()
	background_material.albedo_color = Color.DARK_GRAY
	background_material.emission = Color.DARK_GRAY * 0.3
	background.material_override = background_material
	
	health_bar_root.add_child(background)
	
	# Foreground bar (health indicator)
	var foreground = MeshInstance3D.new()
	foreground.name = "HealthFill"
	var foreground_mesh = BoxMesh.new()
	foreground_mesh.size = Vector3(health_bar_width, 0.2, 0.1)
	foreground.mesh = foreground_mesh
	
	var foreground_material = StandardMaterial3D.new()
	foreground_material.albedo_color = Color.GREEN
	foreground_material.emission = Color.GREEN * 0.5
	foreground.material_override = foreground_material
	
	health_bar_root.add_child(foreground)
	
	return health_bar_root

## Create status light indicator for subsystem
func _create_status_light(subsystem_name: String) -> Node3D:
	var light_root = Node3D.new()
	light_root.name = "StatusLight"
	
	# Light mesh
	var light_mesh = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.3
	light_mesh.mesh = sphere_mesh
	
	var light_material = StandardMaterial3D.new()
	light_material.albedo_color = Color.GREEN
	light_material.emission = Color.GREEN
	light_material.emission_energy = 1.0
	light_mesh.material_override = light_material
	
	light_root.add_child(light_mesh)
	light_root.position = Vector3(0, 1.0, 0)  # Above health bar
	
	return light_root

## Create critical system indicator
func _create_critical_indicator(subsystem_name: String) -> Node3D:
	var critical_root = Node3D.new()
	critical_root.name = "CriticalIndicator"
	critical_root.visible = false  # Hidden by default
	
	# Critical warning mesh
	var warning_mesh = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.5, 0.5, 0.1)
	warning_mesh.mesh = box_mesh
	
	var warning_material = StandardMaterial3D.new()
	warning_material.albedo_color = Color.RED
	warning_material.emission = Color.RED
	warning_material.emission_energy = 2.0
	warning_mesh.material_override = warning_material
	
	critical_root.add_child(warning_mesh)
	critical_root.position = Vector3(0, 1.5, 0)  # Above status light
	
	return critical_root

## Position subsystem indicator based on subsystem location
func _position_subsystem_indicator(subsystem_name: String) -> void:
	var indicator_data = subsystem_indicators.get(subsystem_name, {})
	if indicator_data.is_empty():
		return
	
	var indicator_root = indicator_data["root"]
	
	# Try to get subsystem location from ship
	var position = Vector3.ZERO
	
	# Check if ship has subsystem location data
	var targeted_damage_system = owner_ship.get_node_or_null("TargetedDamageSystem")
	if targeted_damage_system and targeted_damage_system.has_method("get_subsystem_targeting_info"):
		var targeting_info = targeted_damage_system.get_subsystem_targeting_info(owner_ship, subsystem_name)
		if targeting_info.has("location"):
			position = targeting_info["location"]
	else:
		# Use default positions based on subsystem type
		position = _get_default_subsystem_position(subsystem_name)
	
	indicator_root.position = position + Vector3(0, 2.0, 0)  # Offset above subsystem

## Get default position for subsystem indicator
func _get_default_subsystem_position(subsystem_name: String) -> Vector3:
	var name_lower = subsystem_name.to_lower()
	
	if name_lower.contains("engine"):
		return Vector3(0, 0, -5)  # Behind ship
	elif name_lower.contains("weapon"):
		if name_lower.contains("0") or name_lower.contains("left"):
			return Vector3(-2, 0, 2)  # Left side
		else:
			return Vector3(2, 0, 2)   # Right side
	elif name_lower.contains("radar"):
		return Vector3(0, 2, 0)      # Top of ship
	elif name_lower.contains("navigation"):
		return Vector3(0, 1, -2)     # Center-back
	elif name_lower.contains("communication"):
		return Vector3(0, 3, 0)      # High on ship
	else:
		return Vector3(0, 0, 0)      # Center

## Update visual indicator for subsystem
func update_subsystem_visualization(subsystem_name: String) -> void:
	var indicator_data = subsystem_indicators.get(subsystem_name, {})
	if indicator_data.is_empty():
		return
	
	var health_pct = subsystem_health_manager.get_subsystem_health_percentage(subsystem_name)
	var is_operational = subsystem_health_manager.is_subsystem_operational(subsystem_name)
	var criticality_level = critical_identifier.get_subsystem_criticality(subsystem_name) if critical_identifier else 0
	
	# Update health bar
	_update_health_bar(indicator_data["health_bar"], health_pct)
	
	# Update status light
	_update_status_light(indicator_data["status_light"], health_pct, is_operational)
	
	# Update critical indicator
	_update_critical_indicator(indicator_data["critical_indicator"], health_pct, criticality_level)
	
	# Update HUD if enabled
	if enable_hud_integration:
		_update_hud_element(subsystem_name, health_pct, is_operational, criticality_level)
	
	# Record update
	indicator_data["last_update"] = Time.get_unix_time_from_system()
	
	# Emit update signal
	var visual_state = _get_visual_state(health_pct, is_operational)
	visualization_updated.emit(subsystem_name, visual_state)

## Update health bar visualization
func _update_health_bar(health_bar: Node3D, health_pct: float) -> void:
	var health_fill = health_bar.get_node_or_null("HealthFill")
	if not health_fill:
		return
	
	# Update scale to show health percentage
	var scale_x = max(0.01, health_pct)  # Minimum visible scale
	health_fill.scale.x = scale_x
	health_fill.position.x = (health_bar_width * (scale_x - 1.0)) * 0.5
	
	# Update color based on health
	var health_color = _get_health_color(health_pct)
	var material = health_fill.material_override as StandardMaterial3D
	if material:
		material.albedo_color = health_color
		material.emission = health_color * 0.5

## Update status light visualization
func _update_status_light(status_light: Node3D, health_pct: float, is_operational: bool) -> void:
	var light_mesh = status_light.get_child(0) as MeshInstance3D
	if not light_mesh:
		return
	
	var light_color: Color
	if not is_operational:
		light_color = Color.RED
	elif health_pct >= 0.7:
		light_color = Color.GREEN
	elif health_pct >= 0.3:
		light_color = Color.YELLOW
	else:
		light_color = Color.ORANGE
	
	var material = light_mesh.material_override as StandardMaterial3D
	if material:
		material.albedo_color = light_color
		material.emission = light_color
		material.emission_energy = 1.0 if is_operational else 0.3

## Update critical indicator visualization
func _update_critical_indicator(critical_indicator: Node3D, health_pct: float, criticality_level: int) -> void:
	var show_critical = health_pct <= 0.3 and criticality_level >= 2  # Critical or Vital systems
	critical_indicator.visible = show_critical
	
	if show_critical:
		# Flash effect for critical systems
		var flash_alpha = (sin(flash_timer * critical_flash_rate * 2.0 * PI) + 1.0) * 0.5
		var warning_mesh = critical_indicator.get_child(0) as MeshInstance3D
		if warning_mesh:
			var material = warning_mesh.material_override as StandardMaterial3D
			if material:
				material.emission_energy = 1.0 + flash_alpha * 2.0

## Update HUD element for subsystem
func _update_hud_element(subsystem_name: String, health_pct: float, is_operational: bool, criticality_level: int) -> void:
	var hud_data: Dictionary = {
		"subsystem_name": subsystem_name,
		"health_percentage": health_pct,
		"health_color": _get_health_color(health_pct),
		"is_operational": is_operational,
		"criticality_level": criticality_level,
		"criticality_name": _get_criticality_name(criticality_level),
		"visual_state": _get_visual_state(health_pct, is_operational),
		"update_timestamp": Time.get_unix_time_from_system()
	}
	
	status_displays[subsystem_name] = hud_data
	hud_update_requested.emit(hud_data)

## Trigger damage effect visualization
func trigger_damage_effect(subsystem_name: String, damage_amount: float, damage_type: String = "generic") -> void:
	if not enable_damage_effects:
		return
	
	var indicator_data = subsystem_indicators.get(subsystem_name, {})
	if indicator_data.is_empty():
		return
	
	var indicator_root = indicator_data["root"]
	
	# Create damage effect based on type
	var effect_node = _create_damage_effect(damage_type, damage_amount)
	indicator_root.add_child(effect_node)
	active_effects.append(effect_node)
	
	# Auto-remove effect after fade duration
	var timer = Timer.new()
	timer.wait_time = effect_fade_duration
	timer.one_shot = true
	timer.timeout.connect(func():
		if effect_node and is_instance_valid(effect_node):
			effect_node.queue_free()
		active_effects.erase(effect_node)
		timer.queue_free()
	)
	effect_node.add_child(timer)
	timer.start()
	
	damage_effect_triggered.emit(subsystem_name, damage_type)
	
	if debug_visualization_logging:
		print("SubsystemVisualizationController: Triggered %s damage effect for %s (damage: %.1f)" % [
			damage_type, subsystem_name, damage_amount
		])

## Create damage effect visualization
func _create_damage_effect(damage_type: String, damage_amount: float) -> Node3D:
	var effect_root = Node3D.new()
	effect_root.name = "DamageEffect_%s" % damage_type
	
	# Create particle effect or simple visual
	var effect_mesh = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.5 + (damage_amount * 0.01)  # Scale with damage
	effect_mesh.mesh = sphere_mesh
	
	var effect_material = StandardMaterial3D.new()
	
	match damage_type:
		"explosion":
			effect_material.albedo_color = Color.ORANGE
			effect_material.emission = Color.ORANGE
		"fire":
			effect_material.albedo_color = Color.RED
			effect_material.emission = Color.RED
		"electrical":
			effect_material.albedo_color = Color.CYAN
			effect_material.emission = Color.CYAN
		_:
			effect_material.albedo_color = Color.YELLOW
			effect_material.emission = Color.YELLOW
	
	effect_material.emission_energy = 2.0
	effect_mesh.material_override = effect_material
	
	effect_root.add_child(effect_mesh)
	effect_root.position = Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
	
	return effect_root

## Setup HUD integration
func _setup_hud_integration() -> void:
	if not enable_hud_integration:
		return
	
	# Initialize HUD elements for subsystems
	# This would connect to the ship's HUD system if available
	pass

## Setup color schemes
func _setup_color_schemes() -> void:
	# Colors can be customized here for different visual themes
	pass

## Get health-based color
func _get_health_color(health_pct: float) -> Color:
	if health_pct >= 0.8:
		return health_colors["excellent"]
	elif health_pct >= 0.6:
		return health_colors["good"]
	elif health_pct >= 0.3:
		return health_colors["damaged"]
	elif health_pct > 0.0:
		return health_colors["critical"]
	else:
		return health_colors["destroyed"]

## Get visual state description
func _get_visual_state(health_pct: float, is_operational: bool) -> String:
	if not is_operational:
		return "failed"
	elif health_pct >= 0.8:
		return "excellent"
	elif health_pct >= 0.6:
		return "good"
	elif health_pct >= 0.3:
		return "damaged"
	else:
		return "critical"

## Get criticality name for display
func _get_criticality_name(criticality_level: int) -> String:
	match criticality_level:
		3:
			return "VITAL"
		2:
			return "CRITICAL"
		1:
			return "IMPORTANT"
		0:
			return "NON_CRITICAL"
		_:
			return "UNKNOWN"

## Process frame updates
func _process(delta: float) -> void:
	# Update flash timer for critical indicators
	flash_timer += delta
	
	# Update visualization periodically
	update_timer += delta
	if update_timer >= indicator_update_frequency:
		update_timer = 0.0
		_update_all_visualizations()

## Update all subsystem visualizations
func _update_all_visualizations() -> void:
	if not subsystem_health_manager:
		return
	
	var subsystem_statuses = subsystem_health_manager.get_all_subsystem_statuses()
	
	for subsystem_name in subsystem_statuses.keys():
		update_subsystem_visualization(subsystem_name)

## Handle subsystem health changes
func _on_subsystem_health_changed(subsystem_name: String, old_health: float, new_health: float) -> void:
	# Trigger damage effect if health decreased significantly
	if new_health < old_health:
		var damage_amount = old_health - new_health
		if damage_amount >= 10.0:  # Significant damage
			trigger_damage_effect(subsystem_name, damage_amount, "generic")
	
	# Update visualization immediately for significant changes
	if abs(new_health - old_health) >= 5.0:
		update_subsystem_visualization(subsystem_name)

## Handle subsystem failures
func _on_subsystem_failed(subsystem_name: String, failure_type: String) -> void:
	# Trigger appropriate failure effect
	var effect_type = "explosion" if failure_type == "complete_failure" else "electrical"
	trigger_damage_effect(subsystem_name, 100.0, effect_type)
	
	# Update visualization immediately
	update_subsystem_visualization(subsystem_name)

## Handle subsystem repairs
func _on_subsystem_repaired(subsystem_name: String, repair_amount: float) -> void:
	# Trigger repair effect
	if repair_amount >= 10.0:
		trigger_damage_effect(subsystem_name, repair_amount, "repair")
	
	# Update visualization
	update_subsystem_visualization(subsystem_name)

## Handle critical threshold exceeded
func _on_critical_threshold_exceeded(subsystem_name: String, damage_percentage: float) -> void:
	# Trigger critical warning effect
	trigger_damage_effect(subsystem_name, 50.0, "critical_warning")
	
	if debug_visualization_logging:
		print("SubsystemVisualizationController: Critical threshold visualization for %s" % subsystem_name)

## Handle ship critical state changes
func _on_ship_critical_state_changed(critical_state: String, critical_systems: Array[String]) -> void:
	# Update all critical system visualizations
	for subsystem_name in critical_systems:
		update_subsystem_visualization(subsystem_name)

## Get all current status displays for HUD
func get_all_status_displays() -> Dictionary:
	return status_displays.duplicate()

## Get subsystem visualization data
func get_subsystem_visualization_data(subsystem_name: String) -> Dictionary:
	var indicator_data = subsystem_indicators.get(subsystem_name, {})
	var status_data = status_displays.get(subsystem_name, {})
	
	return {
		"has_indicator": not indicator_data.is_empty(),
		"indicator_position": indicator_data.get("root", Node3D.new()).position if not indicator_data.is_empty() else Vector3.ZERO,
		"last_update": indicator_data.get("last_update", 0.0),
		"status_display": status_data,
		"active_effects": active_effects.size()
	}

## Clear all visualizations
func clear_all_visualizations() -> void:
	# Remove all indicator nodes
	for indicator_data in subsystem_indicators.values():
		var root_node = indicator_data.get("root")
		if root_node and is_instance_valid(root_node):
			root_node.queue_free()
	
	# Clear all active effects
	for effect in active_effects:
		if effect and is_instance_valid(effect):
			effect.queue_free()
	
	# Clear data structures
	subsystem_indicators.clear()
	status_displays.clear()
	active_effects.clear()
	
	if debug_visualization_logging:
		print("SubsystemVisualizationController: All visualizations cleared")