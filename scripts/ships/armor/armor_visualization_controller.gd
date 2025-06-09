class_name ArmorVisualizationController
extends Node

## SHIP-011 AC7: Armor Visualization Controller
## Manages visual representation of armor status, damage, and weak points for tactical display
## Implements WCS-authentic armor visualization with real-time status updates

# EPIC-002 Asset Core Integration
const ArmorTypes = preload("res://addons/wcs_asset_core/constants/armor_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")

# Signals
signal armor_visualization_updated(zone_name: String, visual_data: Dictionary)
signal weak_point_highlighted(weak_point_name: String, highlight_data: Dictionary)
signal armor_status_changed(overall_status: Dictionary)
signal critical_zone_visualized(zone_name: String, critical_level: float)

# Visualization data
var armor_visual_data: Dictionary = {}
var weak_point_overlays: Dictionary = {}
var zone_indicators: Dictionary = {}
var damage_heat_maps: Dictionary = {}

# Ship references
var owner_ship: Node = null
var ship_mesh: MeshInstance3D = null
var armor_configuration: ShipArmorConfiguration = null
var armor_degradation: ArmorDegradationTracker = null
var critical_hit_detector: CriticalHitDetector = null

# Visual components
var armor_overlay_material: ShaderMaterial = null
var weak_point_markers: Array[Node3D] = []
var damage_indicators: Array[Node3D] = []
var zone_boundaries: Array[Node3D] = []

# Configuration
@export var enable_real_time_updates: bool = true
@export var enable_weak_point_visualization: bool = true
@export var enable_damage_heat_maps: bool = true
@export var enable_zone_boundaries: bool = false
@export var debug_visualization_logging: bool = false

# Visual parameters
@export var armor_health_colors: Array[Color] = [
	Color.RED,       # 0-25% health - critical
	Color.ORANGE,    # 25-50% health - damaged
	Color.YELLOW,    # 50-75% health - worn
	Color.GREEN      # 75-100% health - good
]

@export var weak_point_highlight_color: Color = Color.CYAN
@export var critical_zone_color: Color = Color.MAGENTA
@export var zone_boundary_color: Color = Color.WHITE
@export var damage_heat_alpha: float = 0.7

# Update parameters
@export var visualization_update_frequency: float = 0.5  # Update every 0.5 seconds
@export var weak_point_pulse_frequency: float = 2.0     # Pulse every 2 seconds
@export var damage_fade_time: float = 5.0               # Damage indicators fade over 5 seconds

# Internal state
var visualization_timer: float = 0.0
var weak_point_pulse_timer: float = 0.0
var damage_indicator_pool: Array[Node3D] = []

func _ready() -> void:
	_setup_visualization_system()

## Initialize armor visualization for a ship
func initialize_for_ship(ship: Node) -> void:
	owner_ship = ship
	
	# Find required components
	ship_mesh = _find_ship_mesh(ship)
	armor_configuration = ship.get_node_or_null("ShipArmorConfiguration")
	armor_degradation = ship.get_node_or_null("ArmorDegradationTracker")
	critical_hit_detector = ship.get_node_or_null("CriticalHitDetector")
	
	if not ship_mesh:
		push_warning("ArmorVisualizationController: No ship mesh found for visualization")
		return
	
	# Setup visual components
	_setup_armor_overlay_material()
	_setup_weak_point_markers()
	_setup_damage_indicator_pool()
	
	# Connect to armor system signals
	_connect_armor_system_signals()
	
	# Initial visualization update
	_update_all_visualizations()
	
	if debug_visualization_logging:
		print("ArmorVisualizationController: Initialized for ship %s" % ship.name)

## Update armor zone visualization
func update_armor_zone_visualization(zone_name: String) -> void:
	if not armor_configuration or not armor_degradation:
		return
	
	# Get current armor status
	var degradation_status = armor_degradation.get_degradation_status(zone_name)
	if degradation_status.is_empty():
		return
	
	# Calculate visualization data
	var visual_data = _calculate_armor_visual_data(zone_name, degradation_status)
	
	# Update armor overlay material
	_update_armor_overlay(zone_name, visual_data)
	
	# Update zone indicators
	_update_zone_indicators(zone_name, visual_data)
	
	# Store visualization data
	armor_visual_data[zone_name] = visual_data
	
	# Emit signal
	armor_visualization_updated.emit(zone_name, visual_data)
	
	if debug_visualization_logging:
		print("ArmorVisualizationController: Updated %s visualization (%.1f%% integrity)" % [
			zone_name, visual_data["structural_integrity"] * 100
		])

## Highlight weak points for tactical targeting
func highlight_weak_points(show_weak_points: bool = true) -> void:
	if not enable_weak_point_visualization or not critical_hit_detector:
		return
	
	if show_weak_points:
		var weak_points = critical_hit_detector.get_weak_points_analysis()
		
		for weak_point_analysis in weak_points:
			var weak_point_name = weak_point_analysis["weak_point_name"]
			_create_weak_point_highlight(weak_point_name, weak_point_analysis)
			
			weak_point_highlighted.emit(weak_point_name, weak_point_analysis)
	else:
		_clear_weak_point_highlights()

## Visualize damage at specific location
func visualize_damage_at_location(hit_location: Vector3, damage_amount: float, damage_type: int) -> void:
	if not enable_damage_heat_maps:
		return
	
	# Create damage indicator
	var damage_indicator = _create_damage_indicator(hit_location, damage_amount, damage_type)
	if damage_indicator:
		damage_indicators.append(damage_indicator)
		
		# Schedule indicator removal
		var fade_tween = create_tween()
		fade_tween.tween_method(_fade_damage_indicator, 1.0, 0.0, damage_fade_time)
		fade_tween.tween_callback(_remove_damage_indicator.bind(damage_indicator))

## Update critical zone visualization
func update_critical_zone_visualization(zone_name: String, critical_level: float) -> void:
	if critical_level >= 0.7:  # 70% critical threshold
		_create_critical_zone_overlay(zone_name, critical_level)
		critical_zone_visualized.emit(zone_name, critical_level)
	else:
		_remove_critical_zone_overlay(zone_name)

## Get comprehensive armor visualization status
func get_armor_visualization_status() -> Dictionary:
	var total_zones = armor_visual_data.size()
	var critical_zones = 0
	var damaged_zones = 0
	var average_integrity = 0.0
	
	for zone_data in armor_visual_data.values():
		var integrity = zone_data.get("structural_integrity", 1.0)
		average_integrity += integrity
		
		if integrity < 0.3:
			critical_zones += 1
		elif integrity < 0.7:
			damaged_zones += 1
	
	if total_zones > 0:
		average_integrity /= total_zones
	
	var status: Dictionary = {
		"total_zones": total_zones,
		"critical_zones": critical_zones,
		"damaged_zones": damaged_zones,
		"healthy_zones": total_zones - critical_zones - damaged_zones,
		"average_integrity": average_integrity,
		"overall_condition": _get_overall_condition_rating(average_integrity),
		"weak_points_visible": not weak_point_overlays.is_empty(),
		"damage_indicators_active": damage_indicators.size(),
		"critical_zones_highlighted": _count_critical_zone_overlays()
	}
	
	armor_status_changed.emit(status)
	return status

## Setup visualization system
func _setup_visualization_system() -> void:
	armor_visual_data.clear()
	weak_point_overlays.clear()
	zone_indicators.clear()
	damage_heat_maps.clear()
	
	weak_point_markers.clear()
	damage_indicators.clear()
	zone_boundaries.clear()

## Find ship mesh for visualization
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

## Find MeshInstance3D nodes in hierarchy
func _find_mesh_instance_nodes(root: Node) -> Array[MeshInstance3D]:
	var found_nodes: Array[MeshInstance3D] = []
	_search_mesh_recursive(root, found_nodes)
	return found_nodes

## Recursive search for MeshInstance3D
func _search_mesh_recursive(node: Node, found_nodes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		found_nodes.append(node as MeshInstance3D)
	
	for child in node.get_children():
		_search_mesh_recursive(child, found_nodes)

## Setup armor overlay material
func _setup_armor_overlay_material() -> void:
	if not ship_mesh:
		return
	
	# Create shader material for armor overlay
	armor_overlay_material = ShaderMaterial.new()
	
	# Set up basic parameters (would use actual shader in real implementation)
	armor_overlay_material.set_shader_parameter("armor_health_colors", armor_health_colors)
	armor_overlay_material.set_shader_parameter("weak_point_highlight_color", weak_point_highlight_color)
	armor_overlay_material.set_shader_parameter("damage_heat_alpha", damage_heat_alpha)

## Setup weak point markers
func _setup_weak_point_markers() -> void:
	# Create marker pool for weak point visualization
	for i in range(20):  # Pool of 20 markers
		var marker = _create_weak_point_marker()
		marker.visible = false
		if owner_ship:
			owner_ship.add_child(marker)
		weak_point_markers.append(marker)

## Setup damage indicator pool
func _setup_damage_indicator_pool() -> void:
	# Create pool of damage indicators
	for i in range(50):  # Pool of 50 indicators
		var indicator = _create_damage_indicator_node()
		indicator.visible = false
		if owner_ship:
			owner_ship.add_child(indicator)
		damage_indicator_pool.append(indicator)

## Connect to armor system signals
func _connect_armor_system_signals() -> void:
	if armor_degradation:
		armor_degradation.armor_degraded.connect(_on_armor_degraded)
		armor_degradation.structural_integrity_compromised.connect(_on_structural_integrity_compromised)
		armor_degradation.degradation_threshold_exceeded.connect(_on_degradation_threshold_exceeded)
	
	if critical_hit_detector:
		critical_hit_detector.critical_hit_detected.connect(_on_critical_hit_detected)
		critical_hit_detector.weak_point_identified.connect(_on_weak_point_identified)

## Calculate armor visual data
func _calculate_armor_visual_data(zone_name: String, degradation_status: Dictionary) -> Dictionary:
	var integrity = degradation_status.get("structural_integrity", 1.0)
	var degradation = degradation_status.get("total_degradation", 0.0)
	var fatigue = degradation_status.get("fatigue_level", 0.0)
	
	return {
		"zone_name": zone_name,
		"structural_integrity": integrity,
		"degradation_level": degradation,
		"fatigue_level": fatigue,
		"health_color": _get_health_color(integrity),
		"damage_heat_intensity": _calculate_damage_heat_intensity(degradation, fatigue),
		"critical_level": _calculate_critical_level(integrity, degradation),
		"visual_priority": _calculate_visual_priority(integrity, degradation, fatigue)
	}

## Update armor overlay
func _update_armor_overlay(zone_name: String, visual_data: Dictionary) -> void:
	if not armor_overlay_material:
		return
	
	# Update shader parameters for zone
	var zone_prefix = "zone_" + zone_name + "_"
	armor_overlay_material.set_shader_parameter(zone_prefix + "integrity", visual_data["structural_integrity"])
	armor_overlay_material.set_shader_parameter(zone_prefix + "color", visual_data["health_color"])
	armor_overlay_material.set_shader_parameter(zone_prefix + "heat_intensity", visual_data["damage_heat_intensity"])

## Update zone indicators
func _update_zone_indicators(zone_name: String, visual_data: Dictionary) -> void:
	# Create or update zone indicator
	if not zone_indicators.has(zone_name):
		zone_indicators[zone_name] = _create_zone_indicator(zone_name)
	
	var indicator = zone_indicators[zone_name]
	if indicator:
		_update_zone_indicator_appearance(indicator, visual_data)

## Create weak point highlight
func _create_weak_point_highlight(weak_point_name: String, weak_point_data: Dictionary) -> void:
	var marker = _get_available_weak_point_marker()
	if not marker:
		return
	
	# Position marker at weak point location
	var location = weak_point_data.get("location", Vector3.ZERO)
	marker.global_position = owner_ship.global_transform * location
	
	# Configure marker appearance
	_configure_weak_point_marker(marker, weak_point_data)
	
	marker.visible = true
	weak_point_overlays[weak_point_name] = marker

## Clear weak point highlights
func _clear_weak_point_highlights() -> void:
	for marker in weak_point_overlays.values():
		marker.visible = false
	weak_point_overlays.clear()

## Create damage indicator
func _create_damage_indicator(hit_location: Vector3, damage_amount: float, damage_type: int) -> Node3D:
	var indicator = _get_available_damage_indicator()
	if not indicator:
		return null
	
	# Position indicator at hit location
	indicator.global_position = hit_location
	
	# Configure indicator appearance
	_configure_damage_indicator(indicator, damage_amount, damage_type)
	
	indicator.visible = true
	return indicator

## Create critical zone overlay
func _create_critical_zone_overlay(zone_name: String, critical_level: float) -> void:
	# Implementation would create visual overlay for critical zones
	pass

## Remove critical zone overlay
func _remove_critical_zone_overlay(zone_name: String) -> void:
	# Implementation would remove critical zone overlay
	pass

## Get health color based on integrity
func _get_health_color(integrity: float) -> Color:
	if integrity >= 0.75:
		return armor_health_colors[3]  # Green - good
	elif integrity >= 0.5:
		return armor_health_colors[2]  # Yellow - worn
	elif integrity >= 0.25:
		return armor_health_colors[1]  # Orange - damaged
	else:
		return armor_health_colors[0]  # Red - critical

## Calculate damage heat intensity
func _calculate_damage_heat_intensity(degradation: float, fatigue: float) -> float:
	return min(degradation + (fatigue * 0.5), 1.0)

## Calculate critical level
func _calculate_critical_level(integrity: float, degradation: float) -> float:
	return max(1.0 - integrity, degradation)

## Calculate visual priority
func _calculate_visual_priority(integrity: float, degradation: float, fatigue: float) -> float:
	# Higher priority for more damaged zones
	return (1.0 - integrity) + degradation + (fatigue * 0.3)

## Get overall condition rating
func _get_overall_condition_rating(average_integrity: float) -> String:
	if average_integrity >= 0.8:
		return "Excellent"
	elif average_integrity >= 0.6:
		return "Good"
	elif average_integrity >= 0.4:
		return "Fair"
	elif average_integrity >= 0.2:
		return "Poor"
	else:
		return "Critical"

## Count critical zone overlays
func _count_critical_zone_overlays() -> int:
	# Implementation would count active critical zone overlays
	return 0

## Update all visualizations
func _update_all_visualizations() -> void:
	if not armor_configuration:
		return
	
	var armor_zones = armor_configuration.armor_zones
	for zone_name in armor_zones.keys():
		update_armor_zone_visualization(zone_name)

## Create weak point marker
func _create_weak_point_marker() -> Node3D:
	var marker = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.2
	marker.mesh = sphere_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = weak_point_highlight_color
	material.emission_enabled = true
	material.emission = weak_point_highlight_color * 0.5
	marker.material_override = material
	
	return marker

## Create damage indicator node
func _create_damage_indicator_node() -> Node3D:
	var indicator = MeshInstance3D.new()
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.5, 0.5)
	indicator.mesh = quad_mesh
	
	var material = StandardMaterial3D.new()
	material.flags_transparent = true
	material.albedo_color = Color.RED
	material.albedo_color.a = damage_heat_alpha
	indicator.material_override = material
	
	return indicator

## Create zone indicator
func _create_zone_indicator(zone_name: String) -> Node3D:
	if not enable_zone_boundaries:
		return null
	
	var indicator = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1, 1, 1)
	indicator.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	material.flags_transparent = true
	material.flags_unshaded = true
	material.albedo_color = zone_boundary_color
	material.albedo_color.a = 0.3
	indicator.material_override = material
	
	if owner_ship:
		owner_ship.add_child(indicator)
	
	return indicator

## Get available weak point marker
func _get_available_weak_point_marker() -> Node3D:
	for marker in weak_point_markers:
		if not marker.visible:
			return marker
	return null

## Get available damage indicator
func _get_available_damage_indicator() -> Node3D:
	for indicator in damage_indicator_pool:
		if not indicator.visible:
			return indicator
	return null

## Configure weak point marker
func _configure_weak_point_marker(marker: Node3D, weak_point_data: Dictionary) -> void:
	var vulnerability = weak_point_data.get("vulnerability_factor", 1.0)
	var priority = weak_point_data.get("targeting_priority", 0.5)
	
	# Scale marker based on vulnerability
	var scale_factor = 0.5 + (vulnerability * 0.5)
	marker.scale = Vector3.ONE * scale_factor
	
	# Adjust color intensity based on priority
	var material = marker.material_override as StandardMaterial3D
	if material:
		var intensity = 0.5 + (priority * 0.5)
		material.emission = weak_point_highlight_color * intensity

## Configure damage indicator
func _configure_damage_indicator(indicator: Node3D, damage_amount: float, damage_type: int) -> void:
	# Scale based on damage amount
	var scale_factor = 0.3 + min(damage_amount / 100.0, 1.0) * 0.7
	indicator.scale = Vector3.ONE * scale_factor
	
	# Color based on damage type
	var damage_color = DamageTypes.get_damage_type_color(damage_type)
	var material = indicator.material_override as StandardMaterial3D
	if material:
		material.albedo_color = damage_color
		material.albedo_color.a = damage_heat_alpha

## Update zone indicator appearance
func _update_zone_indicator_appearance(indicator: Node3D, visual_data: Dictionary) -> void:
	var material = indicator.material_override as StandardMaterial3D
	if material:
		material.albedo_color = visual_data["health_color"]
		material.albedo_color.a = 0.3 + (visual_data["visual_priority"] * 0.2)

## Fade damage indicator
func _fade_damage_indicator(alpha: float) -> void:
	# Implementation would fade damage indicators
	pass

## Remove damage indicator
func _remove_damage_indicator(indicator: Node3D) -> void:
	indicator.visible = false
	damage_indicators.erase(indicator)

## Signal handlers
func _on_armor_degraded(zone_name: String, degradation_level: float) -> void:
	update_armor_zone_visualization(zone_name)

func _on_structural_integrity_compromised(zone_name: String, integrity_level: float) -> void:
	update_critical_zone_visualization(zone_name, 1.0 - integrity_level)

func _on_degradation_threshold_exceeded(zone_name: String, threshold_type: String) -> void:
	if threshold_type == "structural_failure":
		update_critical_zone_visualization(zone_name, 1.0)

func _on_critical_hit_detected(hit_data: Dictionary, critical_multiplier: float) -> void:
	var hit_location = hit_data.get("hit_location", Vector3.ZERO)
	visualize_damage_at_location(hit_location, 100.0 * critical_multiplier, DamageTypes.Type.KINETIC)

func _on_weak_point_identified(weak_point_data: Dictionary) -> void:
	var weak_point_name = weak_point_data.get("weak_point_name", "unknown")
	_create_weak_point_highlight(weak_point_name, weak_point_data)

## Process frame updates
func _process(delta: float) -> void:
	if not enable_real_time_updates:
		return
	
	visualization_timer += delta
	weak_point_pulse_timer += delta
	
	# Update visualizations periodically
	if visualization_timer >= visualization_update_frequency:
		visualization_timer = 0.0
		_update_all_visualizations()
	
	# Pulse weak point markers
	if weak_point_pulse_timer >= weak_point_pulse_frequency:
		weak_point_pulse_timer = 0.0
		_pulse_weak_point_markers()

## Pulse weak point markers for attention
func _pulse_weak_point_markers() -> void:
	for marker in weak_point_overlays.values():
		if marker and marker.visible:
			var tween = create_tween()
			tween.tween_property(marker, "scale", marker.scale * 1.3, 0.3)
			tween.tween_property(marker, "scale", marker.scale, 0.3)