class_name TargetingReticle
extends HUDElementBase

## HUD-006: Core Targeting Reticle System
## Provides dynamic targeting reticles, lead indicators, and weapon convergence display
## for accurate combat targeting and firing solutions

signal reticle_target_changed(old_target: Node, new_target: Node)
signal reticle_weapon_changed(weapon_group: Array[Node])
signal lead_solution_updated(lead_point: Vector3, accuracy: float)
signal convergence_point_changed(convergence_point: Vector3, effective_range: float)
signal firing_solution_ready(optimal_shot: bool, time_window: float)

# Core components
var reticle_renderer: ReticleRenderer
var lead_calculator: LeadCalculator
var convergence_display: ConvergenceDisplay
var firing_solution_calculator: FiringSolutionCalculator

# Target and weapon data
var current_target: Node = null
var active_weapons: Array[Node] = []
var primary_weapon: Node = null
var reticle_config: Dictionary = {}

# Visual state
var reticle_position: Vector2 = Vector2.ZERO
var lead_position: Vector2 = Vector2.ZERO
var convergence_position: Vector2 = Vector2.ZERO
var reticle_visible: bool = false

# Update configuration  
var targeting_update_frequency: float = 60.0  # High frequency for targeting accuracy
var projection_mode: String = "perspective"
var target_prediction_time: float = 2.0  # Seconds to predict ahead

# Target data (need to be class members)
var target_position: Vector3 = Vector3.ZERO
var target_velocity: Vector3 = Vector3.ZERO  
var target_distance: float = 0.0

# HUD integration
var hud_data_provider: Node = null

# Performance settings
var max_lead_distance: float = 5000.0  # Maximum lead calculation distance
var min_target_size: float = 5.0  # Minimum target size for reticle display
var convergence_range_limit: float = 10000.0  # Maximum convergence calculation range

# Ballistics cache
var ballistics_cache: Dictionary = {}
var cache_expiry_time: float = 1.0
var last_cache_update: float = 0.0

func _ready() -> void:
	super._ready()
	_initialize_reticle_system()
	print("TargetingReticle: Targeting reticle system initialized")

func _initialize_reticle_system() -> void:
	# Create core components
	reticle_renderer = ReticleRenderer.new()
	lead_calculator = LeadCalculator.new()
	convergence_display = ConvergenceDisplay.new()
	firing_solution_calculator = FiringSolutionCalculator.new()
	
	# Add renderer as child for visual display
	add_child(reticle_renderer)
	add_child(convergence_display)
	
	# Configure default reticle settings
	reticle_config = {
		"reticle_size": 32.0,
		"lead_marker_size": 16.0,
		"convergence_marker_size": 24.0,
		"reticle_colors": {
			"ready": Color.GREEN,
			"charging": Color.YELLOW,
			"out_of_range": Color.RED,
			"no_target": Color.GRAY,
			"lead_indicator": Color.CYAN,
			"convergence": Color.MAGENTA
		},
		"weapon_types": {
			"energy": "energy_reticle",
			"ballistic": "ballistic_reticle", 
			"missile": "missile_reticle",
			"beam": "beam_reticle"
		}
	}
	
	# Connect to HUD data provider
	_connect_to_data_provider()

func _connect_to_data_provider() -> void:
	# Try to find HUD data provider
	hud_data_provider = get_node_or_null("/root/HUDDataProvider")
	if not hud_data_provider:
		# Try alternative path
		var hud_manager = get_node_or_null("/root/HUDManager")
		if hud_manager:
			hud_data_provider = hud_manager.get_node_or_null("HUDDataProvider")
	
	# Connect to targeting data updates
	if hud_data_provider:
		if hud_data_provider.has_signal("targeting_data_updated"):
			hud_data_provider.targeting_data_updated.connect(_on_targeting_data_updated)
		if hud_data_provider.has_signal("weapon_data_updated"):
			hud_data_provider.weapon_data_updated.connect(_on_weapon_data_updated)

## Set current target for reticle display
func set_target(target: Node) -> void:
	if current_target == target:
		return
	
	var old_target = current_target
	current_target = target
	
	# Update target in child components
	if lead_calculator:
		lead_calculator.set_target(target)
	if firing_solution_calculator:
		firing_solution_calculator.set_target(target)
	
	# Update reticle visibility and position
	_update_reticle_visibility()
	_calculate_reticle_position()
	
	reticle_target_changed.emit(old_target, current_target)
	print("TargetingReticle: Target changed to %s" % (target.name if target else "None"))

## Set active weapons for reticle display
func set_active_weapons(weapons: Array[Node]) -> void:
	active_weapons = weapons.duplicate()
	
	# Set primary weapon (first in array or highest priority)
	primary_weapon = _determine_primary_weapon(weapons)
	
	# Update weapon data in components
	if firing_solution_calculator:
		firing_solution_calculator.set_weapons(weapons)
	if convergence_display:
		convergence_display.set_weapons(weapons)
	
	# Clear ballistics cache for new weapons
	_clear_ballistics_cache()
	
	reticle_weapon_changed.emit(active_weapons)
	print("TargetingReticle: Active weapons updated - %d weapons" % weapons.size())

func _determine_primary_weapon(weapons: Array[Node]) -> Node:
	if weapons.is_empty():
		return null
	
	# For now, use first weapon. In full implementation, would prioritize by:
	# - Weapon type priority (missiles > energy > ballistic)
	# - Current ammo/charge status
	# - Optimal range for current target
	return weapons[0]

## Update reticle system
func update_element() -> void:
	if not current_target or not is_visible_in_tree():
		reticle_visible = false
		_hide_all_reticles()
		return
	
	# Update target data and calculations
	_update_target_data()
	_calculate_reticle_position()
	_calculate_lead_indicator()
	_calculate_convergence_point()
	_calculate_firing_solution()
	
	# Update visual display
	_update_reticle_display()

func _update_target_data() -> void:
	if not current_target:
		return
	
	# Get target data from data provider or direct queries
	var target_data = {}
	if hud_data_provider:
		target_data = hud_data_provider.get_target_data(current_target)
	else:
		# Fallback to direct target queries
		target_data = _get_direct_target_data(current_target)
	
	# Store for use in calculations
	target_position = target_data.get("position", Vector3.ZERO)
	target_velocity = target_data.get("velocity", Vector3.ZERO)
	target_distance = target_data.get("distance", 0.0)

func _get_direct_target_data(target: Node) -> Dictionary:
	# Direct target data extraction for when data provider is unavailable
	var data = {}
	
	if target.has_method("get_global_position"):
		data["position"] = target.get_global_position()
	elif target.has_method("get_position"):
		data["position"] = target.get_position()
	else:
		data["position"] = Vector3.ZERO
	
	# Get velocity if available
	if target.has_method("get_velocity"):
		data["velocity"] = target.get_velocity()
	elif target.has_property("velocity"):
		data["velocity"] = target.velocity
	else:
		data["velocity"] = Vector3.ZERO
	
	# Calculate distance
	var player_pos = _get_player_position()
	data["distance"] = player_pos.distance_to(data["position"])
	
	return data

func _get_player_position() -> Vector3:
	# Get player position for distance calculations
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_global_position"):
		return player.get_global_position()
	return Vector3.ZERO

## Calculate main reticle position
func _calculate_reticle_position() -> void:
	if not current_target:
		reticle_visible = false
		return
	
	# Get 3D target position
	var target_3d_pos = target_position
	if target_3d_pos == Vector3.ZERO:
		reticle_visible = false
		return
	
	# Project to screen coordinates
	var camera = get_viewport().get_camera_3d()
	if not camera:
		reticle_visible = false
		return
	
	# Convert 3D position to 2D screen position
	var screen_pos = camera.unproject_position(target_3d_pos)
	
	# Check if target is visible (in front of camera and within screen bounds)
	var is_behind = camera.is_position_behind(target_3d_pos)
	var viewport_size = get_viewport().get_visible_rect().size
	var is_on_screen = (screen_pos.x >= 0 and screen_pos.x <= viewport_size.x and
	                   screen_pos.y >= 0 and screen_pos.y <= viewport_size.y)
	
	reticle_visible = not is_behind and is_on_screen and target_distance <= max_lead_distance
	reticle_position = screen_pos

## Calculate lead indicator position
func _calculate_lead_indicator() -> void:
	if not current_target or not primary_weapon or not reticle_visible:
		return
	
	# Get weapon ballistics data
	var ballistics = _get_weapon_ballistics(primary_weapon)
	if ballistics.is_empty():
		return
	
	# Calculate lead point using lead calculator
	var target_motion = LeadCalculator.TargetMotion.new()
	target_motion.position = target_position
	target_motion.velocity = target_velocity
	target_motion.acceleration = Vector3.ZERO  # Would get from target if available
	target_motion.angular_velocity = Vector3.ZERO  # Would get from target if available
	
	var weapon_ballistics = LeadCalculator.WeaponBallistics.new()
	weapon_ballistics.projectile_speed = ballistics.get("projectile_speed", 1000.0)
	weapon_ballistics.gravity_effect = ballistics.get("gravity_effect", 0.0)
	weapon_ballistics.drag_coefficient = ballistics.get("drag_coefficient", 0.0)
	weapon_ballistics.time_to_target = target_distance / weapon_ballistics.projectile_speed
	
	# Calculate 3D lead point
	var lead_point_3d = lead_calculator.calculate_lead_point(target_motion, weapon_ballistics)
	
	# Project lead point to screen coordinates
	var camera = get_viewport().get_camera_3d()
	if camera and lead_point_3d != Vector3.ZERO:
		lead_position = camera.unproject_position(lead_point_3d)
		
		# Calculate accuracy/confidence
		var lead_accuracy = _calculate_lead_accuracy(target_motion, weapon_ballistics)
		lead_solution_updated.emit(lead_point_3d, lead_accuracy)

func _calculate_lead_accuracy(target_motion: LeadCalculator.TargetMotion, ballistics: LeadCalculator.WeaponBallistics) -> float:
	# Calculate confidence in lead solution based on:
	# - Target velocity consistency
	# - Distance to target
	# - Weapon accuracy characteristics
	var base_accuracy = 1.0
	
	# Reduce accuracy for fast-moving targets
	var target_speed = target_motion.velocity.length()
	if target_speed > 100.0:  # Fast target
		base_accuracy *= max(0.3, 1.0 - (target_speed - 100.0) / 500.0)
	
	# Reduce accuracy for long-range targets
	if target_distance > 1000.0:
		base_accuracy *= max(0.2, 1.0 - (target_distance - 1000.0) / 4000.0)
	
	# Weapon-specific accuracy factors
	var weapon_accuracy = 1.0
	if primary_weapon and primary_weapon.has_method("get_accuracy"):
		weapon_accuracy = primary_weapon.get_accuracy()
	
	return clamp(base_accuracy * weapon_accuracy, 0.0, 1.0)

## Calculate weapon convergence point
func _calculate_convergence_point() -> void:
	if active_weapons.is_empty() or not reticle_visible:
		return
	
	# Calculate optimal convergence point for all active weapons
	var optimal_range = _calculate_optimal_engagement_range()
	var convergence_point_3d = target_position + (target_velocity * 0.1)  # Slight prediction
	
	# Adjust convergence for optimal range
	var player_pos = _get_player_position()
	var to_target = (target_position - player_pos).normalized()
	var convergence_3d = player_pos + (to_target * optimal_range)
	
	# Project to screen coordinates
	var camera = get_viewport().get_camera_3d()
	if camera:
		convergence_position = camera.unproject_position(convergence_3d)
		convergence_point_changed.emit(convergence_3d, optimal_range)

func _calculate_optimal_engagement_range() -> float:
	if active_weapons.is_empty():
		return 500.0  # Default range
	
	var total_range = 0.0
	var weapon_count = 0
	
	for weapon in active_weapons:
		var weapon_range = _get_weapon_effective_range(weapon)
		if weapon_range > 0:
			total_range += weapon_range
			weapon_count += 1
	
	return total_range / max(1, weapon_count) if weapon_count > 0 else 500.0

func _get_weapon_effective_range(weapon: Node) -> float:
	# Get weapon effective range from weapon data
	if weapon.has_method("get_effective_range"):
		return weapon.get_effective_range()
	elif weapon.has_property("effective_range"):
		return weapon.effective_range
	else:
		return 800.0  # Default range

## Calculate firing solution
func _calculate_firing_solution() -> void:
	if not current_target or not primary_weapon or not reticle_visible:
		return
	
	# Use firing solution calculator to determine optimal shot
	var solution = firing_solution_calculator.calculate_firing_solution(
		current_target, primary_weapon, _get_player_position()
	)
	
	if solution:
		var optimal_shot = solution.get("optimal", false)
		var time_window = solution.get("time_window", 0.0)
		firing_solution_ready.emit(optimal_shot, time_window)

## Update visual reticle display
func _update_reticle_display() -> void:
	if not reticle_renderer:
		return
	
	# Update main reticle
	if reticle_visible:
		var weapon_type = _get_weapon_type(primary_weapon)
		var weapon_status = _get_weapon_status(primary_weapon)
		reticle_renderer.render_central_reticle(reticle_position, weapon_type, weapon_status)
		
		# Update lead indicator
		if lead_position != Vector2.ZERO:
			var lead_confidence = 0.8  # Would calculate based on accuracy
			reticle_renderer.render_lead_indicator(lead_position, lead_confidence)
		
		# Update convergence display
		if convergence_position != Vector2.ZERO:
			var effective_range = _calculate_optimal_engagement_range()
			reticle_renderer.render_convergence_display(convergence_position, effective_range)
	else:
		reticle_renderer.hide_all_reticles()

func _get_weapon_type(weapon: Node) -> String:
	if not weapon:
		return "energy"  # Default
	
	# Get weapon type from weapon data
	if weapon.has_method("get_weapon_type"):
		return weapon.get_weapon_type()
	elif weapon.has_property("weapon_type"):
		return weapon.weapon_type
	else:
		return "energy"  # Default type

func _get_weapon_status(weapon: Node) -> String:
	if not weapon:
		return "no_target"
	
	# Check weapon readiness status
	if weapon.has_method("is_ready_to_fire"):
		if weapon.is_ready_to_fire():
			if target_distance <= _get_weapon_effective_range(weapon):
				return "ready"
			else:
				return "out_of_range"
		else:
			return "charging"
	else:
		return "ready"  # Default to ready

## Get weapon ballistics data
func _get_weapon_ballistics(weapon: Node) -> Dictionary:
	if not weapon:
		return {}
	
	# Check cache first
	var weapon_id = weapon.get_instance_id()
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if ballistics_cache.has(weapon_id):
		var cached = ballistics_cache[weapon_id]
		if current_time - cached["timestamp"] < cache_expiry_time:
			return cached["data"]
	
	# Get fresh ballistics data
	var ballistics = {}
	if weapon.has_method("get_ballistics_data"):
		ballistics = weapon.get_ballistics_data()
	else:
		# Default ballistics for testing
		ballistics = {
			"projectile_speed": 1000.0,
			"gravity_effect": 0.0,
			"drag_coefficient": 0.0,
			"damage": 100.0,
			"range": 2000.0
		}
	
	# Cache the data
	ballistics_cache[weapon_id] = {
		"data": ballistics,
		"timestamp": current_time
	}
	
	return ballistics

func _clear_ballistics_cache() -> void:
	ballistics_cache.clear()
	last_cache_update = Time.get_ticks_msec() / 1000.0

## Update reticle visibility
func _update_reticle_visibility() -> void:
	if not current_target:
		reticle_visible = false
		return
	
	# Check target validity and visibility
	var target_valid = current_target != null and is_instance_valid(current_target)
	var target_in_range = target_distance <= max_lead_distance
	var target_size_adequate = true  # Would check actual target size in full implementation
	
	reticle_visible = target_valid and target_in_range and target_size_adequate

func _hide_all_reticles() -> void:
	if reticle_renderer:
		reticle_renderer.hide_all_reticles()

## Signal handlers
func _on_targeting_data_updated(data: Dictionary) -> void:
	# Update from data provider
	if data.has("current_target"):
		set_target(data["current_target"])
	
	if data.has("target_position"):
		target_position = data["target_position"]
	
	if data.has("target_velocity"):
		target_velocity = data["target_velocity"]
	
	if data.has("target_distance"):
		target_distance = data["target_distance"]

func _on_weapon_data_updated(data: Dictionary) -> void:
	# Update weapon data
	if data.has("active_weapons"):
		set_active_weapons(data["active_weapons"])
	
	# Clear cache when weapon data changes
	_clear_ballistics_cache()

## Configuration
func configure_reticle(config: Dictionary) -> void:
	# Update reticle configuration
	for key in config.keys():
		reticle_config[key] = config[key]
	
	# Apply configuration to components
	if reticle_renderer:
		reticle_renderer.apply_configuration(reticle_config)

## Get reticle status information
func get_reticle_status() -> Dictionary:
	return {
		"reticle_visible": reticle_visible,
		"current_target": current_target.name if current_target else "None",
		"active_weapons": active_weapons.size(),
		"primary_weapon": primary_weapon.name if primary_weapon else "None",
		"reticle_position": reticle_position,
		"lead_position": lead_position,
		"convergence_position": convergence_position,
		"target_distance": target_distance,
		"ballistics_cache_size": ballistics_cache.size()
	}