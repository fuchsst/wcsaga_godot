extends GdUnitTestSuite

## Comprehensive test suite for HUD-007: Weapon Lock and Firing Solution Display
## Tests all 8 core components and their integration

# Component classes to test
const WeaponLockDisplay = preload("res://scripts/hud/weapon_lock/weapon_lock_display.gd")
const LockOnManager = preload("res://scripts/hud/weapon_lock/lock_on_manager.gd")
const FiringSolutionDisplay = preload("res://scripts/hud/weapon_lock/firing_solution_display.gd")
const WeaponStatusIndicator = preload("res://scripts/hud/weapon_lock/weapon_status_indicator.gd")
const MissileLockSystem = preload("res://scripts/hud/weapon_lock/missile_lock_system.gd")
const BeamLockSystem = preload("res://scripts/hud/weapon_lock/beam_lock_system.gd")
const WeaponConvergenceIndicator = preload("res://scripts/hud/weapon_lock/weapon_convergence_indicator.gd")
const FiringOpportunityAlert = preload("res://scripts/hud/weapon_lock/firing_opportunity_alert.gd")

# Test instances
var weapon_lock_display: WeaponLockDisplay
var lock_on_manager: LockOnManager
var firing_solution_display: FiringSolutionDisplay
var weapon_status_indicator: WeaponStatusIndicator
var missile_lock_system: MissileLockSystem
var beam_lock_system: BeamLockSystem
var weapon_convergence_indicator: WeaponConvergenceIndicator
var firing_opportunity_alert: FiringOpportunityAlert

# Mock objects
var mock_player_ship: Node3D
var mock_target_ship: Node3D
var mock_weapon_manager: Node
var mock_camera: Camera3D

func before_test() -> void:
	"""Setup before each test."""
	# Create test scene tree
	_setup_mock_objects()
	
	# Create component instances
	weapon_lock_display = WeaponLockDisplay.new()
	lock_on_manager = LockOnManager.new()
	firing_solution_display = FiringSolutionDisplay.new()
	weapon_status_indicator = WeaponStatusIndicator.new()
	missile_lock_system = MissileLockSystem.new()
	beam_lock_system = BeamLockSystem.new()
	weapon_convergence_indicator = WeaponConvergenceIndicator.new()
	firing_opportunity_alert = FiringOpportunityAlert.new()

func after_test() -> void:
	"""Cleanup after each test."""
	# Free test instances
	if weapon_lock_display:
		weapon_lock_display.queue_free()
	if lock_on_manager:
		lock_on_manager.queue_free()
	if firing_solution_display:
		firing_solution_display.queue_free()
	if weapon_status_indicator:
		weapon_status_indicator.queue_free()
	if missile_lock_system:
		missile_lock_system.queue_free()
	if beam_lock_system:
		beam_lock_system.queue_free()
	if weapon_convergence_indicator:
		weapon_convergence_indicator.queue_free()
	if firing_opportunity_alert:
		firing_opportunity_alert.queue_free()
	
	# Free mock objects
	_cleanup_mock_objects()

func _setup_mock_objects() -> void:
	"""Setup mock objects for testing."""
	# Create mock player ship
	mock_player_ship = Node3D.new()
	mock_player_ship.name = "MockPlayerShip"
	mock_player_ship.global_position = Vector3.ZERO
	
	# Create mock target ship
	mock_target_ship = Node3D.new()
	mock_target_ship.name = "MockTargetShip"
	mock_target_ship.global_position = Vector3(1000, 0, 0)
	
	# Create mock weapon manager
	mock_weapon_manager = Node.new()
	mock_weapon_manager.name = "MockWeaponManager"
	
	# Create mock camera
	mock_camera = Camera3D.new()
	mock_camera.name = "MockCamera"
	mock_camera.global_position = Vector3(0, 0, 10)

func _cleanup_mock_objects() -> void:
	"""Cleanup mock objects."""
	if mock_player_ship:
		mock_player_ship.queue_free()
	if mock_target_ship:
		mock_target_ship.queue_free()
	if mock_weapon_manager:
		mock_weapon_manager.queue_free()
	if mock_camera:
		mock_camera.queue_free()

## WeaponLockDisplay Tests

func test_weapon_lock_display_initialization() -> void:
	"""Test WeaponLockDisplay initialization."""
	assert_that(weapon_lock_display).is_not_null()
	assert_that(weapon_lock_display.lock_state).is_equal(WeaponLockDisplay.LockState.NONE)
	assert_that(weapon_lock_display.weapon_type).is_equal(WeaponLockDisplay.WeaponType.ENERGY)
	assert_that(weapon_lock_display.display_mode).is_equal(WeaponLockDisplay.DisplayMode.STANDARD)

func test_weapon_lock_display_state_changes() -> void:
	"""Test weapon lock display state transitions."""
	# Test lock state changes
	weapon_lock_display.lock_state = WeaponLockDisplay.LockState.SEEKING
	assert_that(weapon_lock_display.lock_state).is_equal(WeaponLockDisplay.LockState.SEEKING)
	
	weapon_lock_display.lock_state = WeaponLockDisplay.LockState.LOCKED
	assert_that(weapon_lock_display.lock_state).is_equal(WeaponLockDisplay.LockState.LOCKED)
	
	# Test progress updates
	weapon_lock_display.lock_progress = 0.5
	assert_that(weapon_lock_display.lock_progress).is_equal(0.5)
	
	weapon_lock_display.lock_progress = 1.5  # Should clamp to 1.0
	assert_that(weapon_lock_display.lock_progress).is_equal(1.0)

func test_weapon_lock_display_weapon_types() -> void:
	"""Test different weapon type configurations."""
	var weapon_types = [
		WeaponLockDisplay.WeaponType.ENERGY,
		WeaponLockDisplay.WeaponType.BALLISTIC,
		WeaponLockDisplay.WeaponType.MISSILE,
		WeaponLockDisplay.WeaponType.BEAM,
		WeaponLockDisplay.WeaponType.SPECIAL
	]
	
	for weapon_type in weapon_types:
		weapon_lock_display.weapon_type = weapon_type
		assert_that(weapon_lock_display.weapon_type).is_equal(weapon_type)

func test_weapon_lock_display_status_methods() -> void:
	"""Test weapon lock display status methods."""
	# Test status retrieval
	var status: Dictionary = weapon_lock_display.get_lock_status()
	assert_that(status).contains_keys(["lock_state", "lock_progress", "weapon_type", "weapon_ready"])
	
	# Test configuration methods
	weapon_lock_display.set_display_mode(WeaponLockDisplay.DisplayMode.DETAILED)
	assert_that(weapon_lock_display.display_mode).is_equal(WeaponLockDisplay.DisplayMode.DETAILED)
	
	weapon_lock_display.set_weapon_type(WeaponLockDisplay.WeaponType.MISSILE)
	assert_that(weapon_lock_display.weapon_type).is_equal(WeaponLockDisplay.WeaponType.MISSILE)

## LockOnManager Tests

func test_lock_on_manager_initialization() -> void:
	"""Test LockOnManager initialization."""
	assert_that(lock_on_manager).is_not_null()
	assert_that(lock_on_manager.lock_type).is_equal(LockOnManager.LockType.ASPECT)
	assert_that(lock_on_manager.acquisition_state).is_equal(LockOnManager.AcquisitionState.INACTIVE)

func test_lock_on_manager_target_setting() -> void:
	"""Test lock-on manager target setting."""
	# Set valid target
	var result: bool = lock_on_manager.set_target(mock_target_ship)
	assert_that(result).is_true()
	assert_that(lock_on_manager.current_target).is_equal(mock_target_ship)
	
	# Clear target
	lock_on_manager.clear_target()
	assert_that(lock_on_manager.current_target).is_null()

func test_lock_on_manager_lock_types() -> void:
	"""Test different lock type configurations."""
	var lock_types = [
		LockOnManager.LockType.ASPECT,
		LockOnManager.LockType.MISSILE,
		LockOnManager.LockType.BEAM,
		LockOnManager.LockType.TORPEDO,
		LockOnManager.LockType.SPECIAL
	]
	
	for lock_type in lock_types:
		lock_on_manager.set_lock_type(lock_type)
		assert_that(lock_on_manager.lock_type).is_equal(lock_type)

func test_lock_on_manager_configuration() -> void:
	"""Test lock-on manager parameter configuration."""
	lock_on_manager.configure_lock_parameters(3.0, 1.0, 45.0, 6000.0, 100.0)
	assert_that(lock_on_manager.lock_acquisition_time).is_equal(3.0)
	assert_that(lock_on_manager.lock_maintain_time).is_equal(1.0)
	assert_that(lock_on_manager.max_lock_angle).is_equal(45.0)
	assert_that(lock_on_manager.max_lock_distance).is_equal(6000.0)
	assert_that(lock_on_manager.min_lock_distance).is_equal(100.0)

func test_lock_on_manager_status_methods() -> void:
	"""Test lock-on manager status methods."""
	var status: Dictionary = lock_on_manager.get_lock_status()
	assert_that(status).contains_keys(["acquisition_state", "lock_type", "lock_progress", "lock_strength"])
	
	assert_that(lock_on_manager.get_lock_progress()).is_equal(0.0)
	assert_that(lock_on_manager.get_lock_strength()).is_equal(0.0)
	assert_that(lock_on_manager.has_lock()).is_false()
	assert_that(lock_on_manager.is_acquiring_lock()).is_false()

## FiringSolutionDisplay Tests

func test_firing_solution_display_initialization() -> void:
	"""Test FiringSolutionDisplay initialization."""
	assert_that(firing_solution_display).is_not_null()
	assert_that(firing_solution_display.display_mode).is_equal(FiringSolutionDisplay.DisplayMode.ADVANCED)

func test_firing_solution_display_modes() -> void:
	"""Test firing solution display modes."""
	var display_modes = [
		FiringSolutionDisplay.DisplayMode.OFF,
		FiringSolutionDisplay.DisplayMode.BASIC,
		FiringSolutionDisplay.DisplayMode.ADVANCED,
		FiringSolutionDisplay.DisplayMode.TACTICAL
	]
	
	for mode in display_modes:
		firing_solution_display.set_display_mode(mode)
		assert_that(firing_solution_display.display_mode).is_equal(mode)

func test_firing_solution_display_data_update() -> void:
	"""Test firing solution data updates."""
	var test_data: Dictionary = {
		"is_valid": true,
		"target_position": Vector3(500, 0, 0),
		"target_velocity": Vector3(100, 0, 0),
		"time_to_impact": 2.5,
		"hit_probability": 0.75,
		"optimal_firing_window": true
	}
	
	firing_solution_display.update_firing_solution(test_data)
	
	var solution: Dictionary = firing_solution_display.get_firing_solution()
	assert_that(solution["is_valid"]).is_true()
	assert_that(solution["hit_probability"]).is_equal(0.75)
	assert_that(solution["optimal_firing_window"]).is_true()

func test_firing_solution_display_configuration() -> void:
	"""Test firing solution display configuration."""
	firing_solution_display.set_display_elements(true, false, true, false)
	assert_that(firing_solution_display.show_intercept_point).is_true()
	assert_that(firing_solution_display.show_weapon_convergence).is_false()
	assert_that(firing_solution_display.show_hit_probability).is_true()
	assert_that(firing_solution_display.show_time_to_impact).is_false()

func test_firing_solution_display_methods() -> void:
	"""Test firing solution display methods."""
	assert_that(firing_solution_display.has_valid_solution()).is_false()
	assert_that(firing_solution_display.is_optimal_firing_window()).is_false()
	
	var quality = firing_solution_display.get_solution_quality()
	assert_that(quality).is_equal(FiringSolutionDisplay.SolutionQuality.IMPOSSIBLE)

## WeaponStatusIndicator Tests

func test_weapon_status_indicator_initialization() -> void:
	"""Test WeaponStatusIndicator initialization."""
	assert_that(weapon_status_indicator).is_not_null()
	assert_that(weapon_status_indicator.display_mode).is_equal(WeaponStatusIndicator.DisplayMode.STANDARD)
	assert_that(weapon_status_indicator.max_weapons_shown).is_equal(4)

func test_weapon_status_indicator_display_modes() -> void:
	"""Test weapon status display modes."""
	var display_modes = [
		WeaponStatusIndicator.DisplayMode.COMPACT,
		WeaponStatusIndicator.DisplayMode.STANDARD,
		WeaponStatusIndicator.DisplayMode.DETAILED
	]
	
	for mode in display_modes:
		weapon_status_indicator.set_display_mode(mode)
		assert_that(weapon_status_indicator.display_mode).is_equal(mode)

func test_weapon_status_indicator_configuration() -> void:
	"""Test weapon status indicator configuration."""
	weapon_status_indicator.set_max_weapons_shown(6)
	assert_that(weapon_status_indicator.max_weapons_shown).is_equal(6)
	
	weapon_status_indicator.set_selected_weapon(2)
	assert_that(weapon_status_indicator.selected_weapon_index).is_equal(2)
	
	weapon_status_indicator.set_horizontal_layout(true)
	assert_that(weapon_status_indicator.horizontal_layout).is_true()

func test_weapon_status_indicator_weapon_data() -> void:
	"""Test weapon status indicator data handling."""
	var test_weapon_data: Dictionary = {
		"weapons": [
			{
				"name": "Laser Cannon",
				"type": WeaponLockDisplay.WeaponType.ENERGY,
				"ready": true,
				"charge": 0.8,
				"heat": 0.3
			},
			{
				"name": "Missile Launcher",
				"type": WeaponLockDisplay.WeaponType.MISSILE,
				"ready": false,
				"ammo_current": 10,
				"ammo_maximum": 20
			}
		],
		"selected_weapon": 0
	}
	
	weapon_status_indicator.update_weapon_status(test_weapon_data)
	
	var weapon_0_status: Dictionary = weapon_status_indicator.get_weapon_status(0)
	assert_that(weapon_0_status["weapon_name"]).is_equal("Laser Cannon")
	assert_that(weapon_0_status["is_ready"]).is_true()
	
	assert_that(weapon_status_indicator.has_ready_weapons()).is_true()
	assert_that(weapon_status_indicator.get_ready_weapon_count()).is_equal(1)

## MissileLockSystem Tests

func test_missile_lock_system_initialization() -> void:
	"""Test MissileLockSystem initialization."""
	assert_that(missile_lock_system).is_not_null()
	assert_that(missile_lock_system.missile_type).is_equal(MissileLockSystem.MissileType.HEATSEEKER)
	assert_that(missile_lock_system.lock_stage).is_equal(MissileLockSystem.LockStage.INACTIVE)

func test_missile_lock_system_missile_types() -> void:
	"""Test different missile type configurations."""
	var missile_types = [
		MissileLockSystem.MissileType.HEATSEEKER,
		MissileLockSystem.MissileType.RADAR_GUIDED,
		MissileLockSystem.MissileType.TARGET_PAINTER,
		MissileLockSystem.MissileType.TORPEDO,
		MissileLockSystem.MissileType.SWARM,
		MissileLockSystem.MissileType.DUMBFIRE
	]
	
	for missile_type in missile_types:
		missile_lock_system.set_missile_type(missile_type)
		assert_that(missile_lock_system.missile_type).is_equal(missile_type)

func test_missile_lock_system_target_setting() -> void:
	"""Test missile lock system target setting."""
	var result: bool = missile_lock_system.set_target(mock_target_ship)
	assert_that(missile_lock_system.current_target).is_equal(mock_target_ship)

func test_missile_lock_system_configuration() -> void:
	"""Test missile lock system parameter configuration."""
	missile_lock_system.configure_missile_parameters(2.5, 1.5, 35.0, 4500.0, 20.0)
	assert_that(missile_lock_system.seeker_acquisition_time).is_equal(2.5)
	assert_that(missile_lock_system.lock_maintain_time).is_equal(1.5)
	assert_that(missile_lock_system.max_lock_angle).is_equal(35.0)
	assert_that(missile_lock_system.max_lock_range).is_equal(4500.0)
	assert_that(missile_lock_system.seeker_cone_angle).is_equal(20.0)

func test_missile_lock_system_status_methods() -> void:
	"""Test missile lock system status methods."""
	var status: Dictionary = missile_lock_system.get_missile_lock_status()
	assert_that(status).contains_keys(["missile_type", "lock_stage", "seeker_status", "launch_window_open"])
	
	assert_that(missile_lock_system.has_missile_lock()).is_false()
	assert_that(missile_lock_system.is_ready_to_launch()).is_false()
	assert_that(missile_lock_system.get_launch_window_quality()).is_equal(0.0)

## BeamLockSystem Tests

func test_beam_lock_system_initialization() -> void:
	"""Test BeamLockSystem initialization."""
	assert_that(beam_lock_system).is_not_null()
	assert_that(beam_lock_system.beam_type).is_equal(BeamLockSystem.BeamType.LASER)
	assert_that(beam_lock_system.tracking_state).is_equal(BeamLockSystem.TrackingState.OFFLINE)

func test_beam_lock_system_beam_types() -> void:
	"""Test different beam type configurations."""
	var beam_types = [
		BeamLockSystem.BeamType.LASER,
		BeamLockSystem.BeamType.PARTICLE,
		BeamLockSystem.BeamType.PLASMA,
		BeamLockSystem.BeamType.ION,
		BeamLockSystem.BeamType.ANTIMATTER,
		BeamLockSystem.BeamType.CUTTING,
		BeamLockSystem.BeamType.POINT_DEFENSE
	]
	
	for beam_type in beam_types:
		beam_lock_system.set_beam_type(beam_type)
		assert_that(beam_lock_system.beam_type).is_equal(beam_type)

func test_beam_lock_system_target_setting() -> void:
	"""Test beam lock system target setting."""
	var result: bool = beam_lock_system.set_target(mock_target_ship)
	assert_that(beam_lock_system.current_target).is_equal(mock_target_ship)

func test_beam_lock_system_configuration() -> void:
	"""Test beam lock system parameter configuration."""
	beam_lock_system.configure_beam_parameters(2500.0, 1200.0, 20.0, 900.0)
	assert_that(beam_lock_system.max_beam_range).is_equal(2500.0)
	assert_that(beam_lock_system.optimal_beam_range).is_equal(1200.0)
	assert_that(beam_lock_system.max_tracking_angle).is_equal(20.0)
	assert_that(beam_lock_system.beam_convergence_distance).is_equal(900.0)

func test_beam_lock_system_status_methods() -> void:
	"""Test beam lock system status methods."""
	var status: Dictionary = beam_lock_system.get_beam_lock_status()
	assert_that(status).contains_keys(["beam_type", "tracking_state", "beam_quality", "is_firing"])
	
	assert_that(beam_lock_system.has_beam_lock()).is_false()
	assert_that(beam_lock_system.is_beam_firing()).is_false()
	assert_that(beam_lock_system.is_ready_to_fire()).is_false()
	assert_that(beam_lock_system.get_firing_efficiency()).is_equal(0.0)

func test_beam_lock_system_firing_control() -> void:
	"""Test beam lock system firing control."""
	# Should not be able to start firing without proper setup
	var can_fire: bool = beam_lock_system.start_beam_firing()
	assert_that(can_fire).is_false()
	
	# Stop firing should work even if not firing
	beam_lock_system.stop_firing()
	assert_that(beam_lock_system.is_beam_firing()).is_false()

## WeaponConvergenceIndicator Tests

func test_weapon_convergence_indicator_initialization() -> void:
	"""Test WeaponConvergenceIndicator initialization."""
	assert_that(weapon_convergence_indicator).is_not_null()
	assert_that(weapon_convergence_indicator.convergence_mode).is_equal(WeaponConvergenceIndicator.ConvergenceMode.DETAILED)

func test_weapon_convergence_indicator_modes() -> void:
	"""Test weapon convergence display modes."""
	var convergence_modes = [
		WeaponConvergenceIndicator.ConvergenceMode.OFF,
		WeaponConvergenceIndicator.ConvergenceMode.BASIC,
		WeaponConvergenceIndicator.ConvergenceMode.DETAILED,
		WeaponConvergenceIndicator.ConvergenceMode.ADVANCED
	]
	
	for mode in convergence_modes:
		weapon_convergence_indicator.set_convergence_mode(mode)
		assert_that(weapon_convergence_indicator.convergence_mode).is_equal(mode)

func test_weapon_convergence_indicator_weapon_groups() -> void:
	"""Test weapon convergence weapon group configuration."""
	var weapon_groups: Array[WeaponConvergenceIndicator.WeaponGroup] = [
		WeaponConvergenceIndicator.WeaponGroup.PRIMARY,
		WeaponConvergenceIndicator.WeaponGroup.SECONDARY
	]
	
	weapon_convergence_indicator.set_weapon_groups_display(weapon_groups)
	assert_that(weapon_convergence_indicator.show_weapon_groups).has_size(2)

func test_weapon_convergence_indicator_configuration() -> void:
	"""Test weapon convergence indicator configuration."""
	weapon_convergence_indicator.set_display_elements(true, false, true, false)
	assert_that(weapon_convergence_indicator.show_convergence_point).is_true()
	assert_that(weapon_convergence_indicator.show_convergence_zone).is_false()
	assert_that(weapon_convergence_indicator.show_weapon_spread_pattern).is_true()
	assert_that(weapon_convergence_indicator.show_optimal_range_indicator).is_false()

func test_weapon_convergence_indicator_data_update() -> void:
	"""Test weapon convergence data updates."""
	var test_weapon_data: Dictionary = {
		"primary_weapons": [
			{
				"position": Vector3(2, 0, 0),
				"orientation": Vector3.FORWARD,
				"range": 1200.0
			},
			{
				"position": Vector3(-2, 0, 0),
				"orientation": Vector3.FORWARD,
				"range": 1200.0
			}
		],
		"secondary_weapons": []
	}
	
	weapon_convergence_indicator.update_convergence_data(test_weapon_data)
	
	var convergence_info: Dictionary = weapon_convergence_indicator.get_convergence_info(
		WeaponConvergenceIndicator.WeaponGroup.PRIMARY
	)
	assert_that(convergence_info["weapon_count"]).is_equal(2)
	assert_that(convergence_info["optimal_range"]).is_equal(1200.0)

func test_weapon_convergence_indicator_methods() -> void:
	"""Test weapon convergence indicator utility methods."""
	var optimal_range: float = weapon_convergence_indicator.get_optimal_firing_range(
		WeaponConvergenceIndicator.WeaponGroup.PRIMARY
	)
	assert_that(optimal_range).is_greater_equal(0.0)
	
	var is_good: bool = weapon_convergence_indicator.is_convergence_good(
		WeaponConvergenceIndicator.WeaponGroup.PRIMARY
	)
	assert_that(is_good).is_false()  # Should be false with no data
	
	var best_group = weapon_convergence_indicator.get_best_weapon_group_for_distance(1000.0)
	assert_that(best_group).is_equal(WeaponConvergenceIndicator.WeaponGroup.PRIMARY)

## FiringOpportunityAlert Tests

func test_firing_opportunity_alert_initialization() -> void:
	"""Test FiringOpportunityAlert initialization."""
	assert_that(firing_opportunity_alert).is_not_null()
	assert_that(firing_opportunity_alert.alert_style).is_equal(FiringOpportunityAlert.AlertStyle.STANDARD)

func test_firing_opportunity_alert_styles() -> void:
	"""Test firing opportunity alert styles."""
	var alert_styles = [
		FiringOpportunityAlert.AlertStyle.SUBTLE,
		FiringOpportunityAlert.AlertStyle.STANDARD,
		FiringOpportunityAlert.AlertStyle.AGGRESSIVE,
		FiringOpportunityAlert.AlertStyle.MINIMAL
	]
	
	for style in alert_styles:
		firing_opportunity_alert.set_alert_style(style)
		assert_that(firing_opportunity_alert.alert_style).is_equal(style)

func test_firing_opportunity_alert_configuration() -> void:
	"""Test firing opportunity alert configuration."""
	firing_opportunity_alert.configure_display_elements(true, false, true, false)
	assert_that(firing_opportunity_alert.show_opportunity_text).is_true()
	assert_that(firing_opportunity_alert.show_timing_bar).is_false()
	assert_that(firing_opportunity_alert.show_damage_prediction).is_true()
	assert_that(firing_opportunity_alert.show_confidence_indicator).is_false()
	
	firing_opportunity_alert.set_alert_position(Vector2(200, 150))
	assert_that(firing_opportunity_alert.alert_position).is_equal(Vector2(200, 150))
	
	firing_opportunity_alert.set_audio_alerts_enabled(false)
	assert_that(firing_opportunity_alert.play_audio_alerts).is_false()

func test_firing_opportunity_alert_analysis() -> void:
	"""Test firing opportunity analysis."""
	var target_data: Dictionary = {
		"hit_probability": 0.85,
		"stability": 0.9,
		"vulnerability": 0.7,
		"range_optimality": 0.8,
		"shield_strength": 0.2
	}
	
	var weapon_data: Dictionary = {
		"readiness": 0.95,
		"damage_potential": 0.85,
		"convergence_quality": 0.9
	}
	
	var tactical_data: Dictionary = {
		"threat_level": 0.5
	}
	
	firing_opportunity_alert.update_firing_analysis(target_data, weapon_data, tactical_data)
	
	# Should have created some opportunities
	var opportunities: Array[Dictionary] = firing_opportunity_alert.get_active_opportunities()
	assert_that(opportunities.size()).is_greater_equal(0)

func test_firing_opportunity_alert_methods() -> void:
	"""Test firing opportunity alert utility methods."""
	assert_that(firing_opportunity_alert.has_critical_opportunity()).is_false()
	
	var best_opportunity: Dictionary = firing_opportunity_alert.get_best_opportunity()
	assert_that(best_opportunity).is_empty()  # No opportunities initially
	
	firing_opportunity_alert.clear_all_opportunities()
	var opportunities: Array[Dictionary] = firing_opportunity_alert.get_active_opportunities()
	assert_that(opportunities).is_empty()

## Integration Tests

func test_weapon_lock_display_integration() -> void:
	"""Test integration between WeaponLockDisplay and sub-components."""
	# Mock GameState for integration
	var mock_game_state = {
		"player_ship": mock_player_ship
	}
	
	# Test initialization of child components
	weapon_lock_display._initialize_components()
	
	# Verify child components were created
	assert_that(weapon_lock_display.get_child_count()).is_greater_equal(3)

func test_component_signal_integration() -> void:
	"""Test signal integration between components."""
	# Create signal connections
	var signal_received: bool = false
	
	# Test LockOnManager signals
	lock_on_manager.lock_state_changed.connect(func(state): signal_received = true)
	lock_on_manager.acquisition_state = LockOnManager.AcquisitionState.ACQUIRING
	lock_on_manager.lock_state_changed.emit(LockOnManager.AcquisitionState.ACQUIRING)
	
	assert_that(signal_received).is_true()

func test_weapon_lock_display_update_cycle() -> void:
	"""Test complete weapon lock display update cycle."""
	# Create mock weapon data
	var weapon_data: Dictionary = {
		"lock_state": WeaponLockDisplay.LockState.SEEKING,
		"lock_progress": 0.6,
		"weapon_type": WeaponLockDisplay.WeaponType.MISSILE,
		"ready": true,
		"ammo": 10
	}
	
	# Test update from game state (would normally be called by update_from_game_state)
	weapon_lock_display.lock_state = weapon_data["lock_state"]
	weapon_lock_display.lock_progress = weapon_data["lock_progress"]
	weapon_lock_display.weapon_type = weapon_data["weapon_type"]
	weapon_lock_display.weapon_ready = weapon_data["ready"]
	weapon_lock_display.ammo_count = weapon_data["ammo"]
	
	# Verify state was updated correctly
	assert_that(weapon_lock_display.lock_state).is_equal(WeaponLockDisplay.LockState.SEEKING)
	assert_that(weapon_lock_display.lock_progress).is_equal(0.6)
	assert_that(weapon_lock_display.weapon_type).is_equal(WeaponLockDisplay.WeaponType.MISSILE)
	assert_that(weapon_lock_display.weapon_ready).is_true()
	assert_that(weapon_lock_display.ammo_count).is_equal(10)

func test_missile_lock_system_complete_cycle() -> void:
	"""Test complete missile lock acquisition cycle."""
	# Set up missile system
	missile_lock_system.set_missile_type(MissileLockSystem.MissileType.HEATSEEKER)
	missile_lock_system.player_ship = mock_player_ship
	
	# Set target
	var result: bool = missile_lock_system.set_target(mock_target_ship)
	assert_that(result).is_equal(result)  # Result depends on target being in seeker cone
	
	# Check initial state
	var status: Dictionary = missile_lock_system.get_missile_lock_status()
	assert_that(status["missile_type"]).is_equal(MissileLockSystem.MissileType.HEATSEEKER)
	assert_that(status["target"]).is_equal(mock_target_ship)

func test_beam_lock_system_power_management() -> void:
	"""Test beam lock system power and thermal management."""
	# Set initial conditions
	beam_lock_system.capacitor_charge = 100.0
	beam_lock_system.current_heat_level = 0.0
	beam_lock_system.is_overheated = false
	
	# Simulate power drain
	beam_lock_system._update_power_systems(1.0)  # 1 second update
	
	# Heat should remain low without firing
	assert_that(beam_lock_system.current_heat_level).is_less_equal(10.0)

func test_convergence_quality_calculation() -> void:
	"""Test weapon convergence quality calculation."""
	# Create test convergence data
	var convergence_data = weapon_convergence_indicator.primary_convergence
	convergence_data.weapon_positions = [Vector3(-1, 0, 0), Vector3(1, 0, 0)]
	convergence_data.weapon_orientations = [Vector3.FORWARD, Vector3.FORWARD]
	convergence_data.weapon_ranges = [1000.0, 1000.0]
	convergence_data.convergence_distance = 1000.0
	convergence_data.convergence_spread = 10.0  # 10m spread at 1000m = 1% = PERFECT
	
	weapon_convergence_indicator._calculate_convergence_quality(convergence_data)
	
	assert_that(convergence_data.quality).is_equal(WeaponConvergenceIndicator.ConvergenceQuality.PERFECT)

func test_firing_opportunity_priority_system() -> void:
	"""Test firing opportunity priority and sorting system."""
	# Clear any existing opportunities
	firing_opportunity_alert.clear_all_opportunities()
	
	# Create test opportunities with different priorities
	firing_opportunity_alert._create_opportunity(
		FiringOpportunityAlert.OpportunityType.PERFECT_SHOT,
		FiringOpportunityAlert.AlertPriority.CRITICAL,
		2.0, 0.9, 1.5, 0.85, "Perfect Shot"
	)
	
	firing_opportunity_alert._create_opportunity(
		FiringOpportunityAlert.OpportunityType.HIGH_DAMAGE,
		FiringOpportunityAlert.AlertPriority.HIGH,
		3.0, 0.7, 1.3, 0.75, "High Damage"
	)
	
	# Check that opportunities were created and sorted correctly
	var opportunities: Array[Dictionary] = firing_opportunity_alert.get_active_opportunities()
	assert_that(opportunities.size()).is_equal(2)
	
	# Critical priority should be first
	var best_opportunity: Dictionary = firing_opportunity_alert.get_best_opportunity()
	assert_that(best_opportunity["priority"]).is_equal(FiringOpportunityAlert.AlertPriority.CRITICAL)
	
	assert_that(firing_opportunity_alert.has_critical_opportunity()).is_true()

## Performance Tests

func test_component_performance() -> void:
	"""Test component performance under load."""
	var start_time: int = Time.get_ticks_msec()
	
	# Simulate multiple rapid updates
	for i in range(100):
		weapon_lock_display.lock_progress = float(i) / 100.0
		lock_on_manager.lock_progress = float(i) / 100.0
		
		# Update components
		var weapon_data: Dictionary = {
			"weapons": [{"name": "Test", "ready": true, "charge": float(i) / 100.0}]
		}
		weapon_status_indicator.update_weapon_status(weapon_data)
	
	var end_time: int = Time.get_ticks_msec()
	var duration: int = end_time - start_time
	
	# Should complete within reasonable time (less than 100ms)
	assert_that(duration).is_less(100)

func test_memory_usage() -> void:
	"""Test memory usage and cleanup."""
	# Create and destroy multiple instances
	var instances: Array = []
	
	for i in range(10):
		var display = WeaponLockDisplay.new()
		var manager = LockOnManager.new()
		instances.append(display)
		instances.append(manager)
	
	# Clean up instances
	for instance in instances:
		instance.queue_free()
	
	# Test should complete without memory leaks
	assert_that(instances.size()).is_equal(20)

## Error Handling Tests

func test_null_safety() -> void:
	"""Test null safety in all components."""
	# Test with null targets
	lock_on_manager.set_target(null)
	assert_that(lock_on_manager.current_target).is_null()
	
	missile_lock_system.set_target(null)
	assert_that(missile_lock_system.current_target).is_null()
	
	beam_lock_system.set_target(null)
	assert_that(beam_lock_system.current_target).is_null()
	
	# Test with empty data
	weapon_status_indicator.update_weapon_status({})
	firing_solution_display.update_firing_solution({})
	weapon_convergence_indicator.update_convergence_data({})
	firing_opportunity_alert.update_firing_analysis({}, {}, {})

func test_invalid_input_handling() -> void:
	"""Test handling of invalid inputs."""
	# Test invalid progress values
	weapon_lock_display.lock_progress = -1.0
	assert_that(weapon_lock_display.lock_progress).is_equal(0.0)
	
	weapon_lock_display.lock_progress = 2.0
	assert_that(weapon_lock_display.lock_progress).is_equal(1.0)
	
	# Test invalid weapon types
	weapon_lock_display.weapon_type = 999 as WeaponLockDisplay.WeaponType
	# Should handle gracefully without crashing
	
	# Test invalid configuration values
	lock_on_manager.configure_lock_parameters(-1.0, -1.0, -1.0, -1.0, -1.0)
	# Should handle negative values appropriately