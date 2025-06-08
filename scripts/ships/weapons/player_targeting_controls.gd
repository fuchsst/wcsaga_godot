class_name PlayerTargetingControls
extends Node

## Player targeting controls with HUD integration and input handling
## Provides player interface for target selection, lock-on, and subsystem cycling
## Implementation of SHIP-006 AC7: Player targeting controls

# Constants
const TeamTypes = preload("res://addons/wcs_asset_core/constants/team_types.gd")

# Input action names (these should match project input map)
const INPUT_TARGET_NEXT: String = "target_next"
const INPUT_TARGET_PREVIOUS: String = "target_previous"
const INPUT_TARGET_CLOSEST: String = "target_closest"
const INPUT_TARGET_HOSTILE: String = "target_hostile"
const INPUT_TARGET_FRIENDLY: String = "target_friendly"
const INPUT_SUBSYSTEM_NEXT: String = "subsystem_next"
const INPUT_SUBSYSTEM_PREVIOUS: String = "subsystem_previous"
const INPUT_SUBSYSTEM_DISABLE: String = "subsystem_disable"

# Hotkey target assignments (F5-F12 typically)
const HOTKEY_BASE: String = "target_hotkey_"  # target_hotkey_1, target_hotkey_2, etc.

# Signals for HUD integration
signal target_selection_changed(new_target: Node3D, old_target: Node3D)
signal subsystem_selection_changed(subsystem: Node, subsystem_name: String)
signal target_lock_strength_changed(strength: float, max_strength: float)
signal aspect_lock_achieved(target: Node3D, lock_time: float)
signal aspect_lock_lost(target: Node3D)
signal hotkey_assignment_changed(hotkey: int, target: Node3D)
signal targeting_mode_changed(mode: String)

# Player ship reference
var player_ship: BaseShip

# Targeting system components
var target_manager: TargetManager
var aspect_lock_controller: AspectLockController
var subsystem_targeting: SubsystemTargeting
var range_validator: RangeValidator

# HUD integration
var hud_system: Node = null
var crosshair_node: Node2D = null
var target_brackets: Array[Node2D] = []

# Input handling state
var input_enabled: bool = true
var mouse_targeting_enabled: bool = true
var keyboard_targeting_enabled: bool = true

# Targeting mode state
var current_targeting_mode: String = "normal"  # normal, subsystem, formation
var target_filter_mode: TeamTypes.Team = TeamTypes.Team.HOSTILE

# Visual feedback settings
var show_target_info: bool = true
var show_lead_indicator: bool = true
var show_subsystem_highlights: bool = true
var auto_center_target: bool = false

# Audio feedback
var lock_tone_enabled: bool = true
var target_change_sound_enabled: bool = true

func _init() -> void:
	set_process_input(true)

func _ready() -> void:
	# Connect to aspect lock controller for audio feedback
	if aspect_lock_controller:
		aspect_lock_controller.lock_tone_start.connect(_on_lock_tone_start)
		aspect_lock_controller.lock_tone_stop.connect(_on_lock_tone_stop)

## Initialize player targeting controls
func initialize_player_targeting(ship: BaseShip, hud: Node = null) -> bool:
	"""Initialize player targeting controls with ship and HUD references.
	
	Args:
		ship: Player ship reference
		hud: HUD system for visual feedback
		
	Returns:
		true if initialization successful
	"""
	if not ship:
		push_error("PlayerTargetingControls: Cannot initialize without valid ship")
		return false
	
	player_ship = ship
	hud_system = hud
	
	# Get targeting system components from ship
	_find_targeting_components()
	
	# Connect to targeting system signals
	_connect_targeting_signals()
	
	# Initialize HUD integration
	_initialize_hud_integration()
	
	return true

## Find targeting system components from ship
func _find_targeting_components() -> void:
	"""Find targeting system components in ship hierarchy."""
	if not player_ship:
		return
	
	# Look for targeting components in weapon manager
	if player_ship.weapon_manager:
		var weapon_manager: WeaponManager = player_ship.weapon_manager
		
		# Find targeting system
		for child in weapon_manager.get_children():
			if child is TargetManager:
				target_manager = child
			elif child is AspectLockController:
				aspect_lock_controller = child
			elif child is SubsystemTargeting:
				subsystem_targeting = child
			elif child is RangeValidator:
				range_validator = child
	
	# Create missing components if needed
	if not target_manager:
		target_manager = TargetManager.new()
		player_ship.add_child(target_manager)
		target_manager.initialize_target_manager(player_ship)
	
	if not aspect_lock_controller:
		aspect_lock_controller = AspectLockController.new()
		player_ship.add_child(aspect_lock_controller)
		aspect_lock_controller.initialize_aspect_lock_controller(player_ship)
	
	if not subsystem_targeting:
		subsystem_targeting = SubsystemTargeting.new()
		player_ship.add_child(subsystem_targeting)
		subsystem_targeting.initialize_subsystem_targeting(player_ship)
	
	if not range_validator:
		range_validator = RangeValidator.new()
		player_ship.add_child(range_validator)
		range_validator.initialize_range_validator(player_ship)

## Connect to targeting system signals
func _connect_targeting_signals() -> void:
	"""Connect to targeting system signals for HUD updates."""
	if target_manager:
		target_manager.target_acquired.connect(_on_target_acquired)
		target_manager.target_lost.connect(_on_target_lost)
		target_manager.target_changed.connect(_on_target_changed)
		target_manager.hotkey_target_assigned.connect(_on_hotkey_target_assigned)
	
	if aspect_lock_controller:
		aspect_lock_controller.aspect_lock_acquired.connect(_on_aspect_lock_acquired)
		aspect_lock_controller.aspect_lock_lost.connect(_on_aspect_lock_lost)
		aspect_lock_controller.aspect_lock_progress_changed.connect(_on_aspect_lock_progress_changed)
	
	if subsystem_targeting:
		subsystem_targeting.subsystem_selected.connect(_on_subsystem_selected)
		subsystem_targeting.subsystem_targeting_disabled.connect(_on_subsystem_targeting_disabled)

## Initialize HUD integration
func _initialize_hud_integration() -> void:
	"""Initialize HUD components for targeting display."""
	if not hud_system:
		return
	
	# This would integrate with actual HUD system
	# For now, we'll create placeholder connections

## Handle input events for targeting (SHIP-006 AC7)
func _input(event: InputEvent) -> void:
	"""Handle player input for targeting controls."""
	if not input_enabled or not player_ship:
		return
	
	# Handle keyboard targeting
	if keyboard_targeting_enabled:
		_handle_keyboard_input(event)
	
	# Handle mouse targeting
	if mouse_targeting_enabled and event is InputEventMouse:
		_handle_mouse_input(event)

## Handle keyboard input for targeting
func _handle_keyboard_input(event: InputEvent) -> void:
	"""Handle keyboard input for targeting controls."""
	if not event.is_pressed():
		return
	
	# Target cycling
	if event.is_action_pressed(INPUT_TARGET_NEXT):
		cycle_target_next()
	elif event.is_action_pressed(INPUT_TARGET_PREVIOUS):
		cycle_target_previous()
	
	# Target selection by type
	elif event.is_action_pressed(INPUT_TARGET_CLOSEST):
		select_closest_target()
	elif event.is_action_pressed(INPUT_TARGET_HOSTILE):
		cycle_hostile_targets()
	elif event.is_action_pressed(INPUT_TARGET_FRIENDLY):
		cycle_friendly_targets()
	
	# Subsystem targeting
	elif event.is_action_pressed(INPUT_SUBSYSTEM_NEXT):
		cycle_subsystem_next()
	elif event.is_action_pressed(INPUT_SUBSYSTEM_PREVIOUS):
		cycle_subsystem_previous()
	elif event.is_action_pressed(INPUT_SUBSYSTEM_DISABLE):
		disable_subsystem_targeting()
	
	# Hotkey assignments (F5-F12)
	for i in range(1, 13):  # F1-F12
		var hotkey_action: String = HOTKEY_BASE + str(i)
		if event.is_action_pressed(hotkey_action):
			_handle_hotkey_input(i, event)
			break

## Handle mouse input for targeting
func _handle_mouse_input(event: InputEventMouse) -> void:
	"""Handle mouse input for targeting controls."""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Mouse click targeting
			_handle_mouse_click_targeting(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Context menu or subsystem cycling
			if subsystem_targeting.is_targeting_subsystems():
				cycle_subsystem_next()
			else:
				_show_targeting_context_menu(event.position)

## Handle hotkey input (SHIP-006 AC7)
func _handle_hotkey_input(hotkey: int, event: InputEvent) -> void:
	"""Handle hotkey assignment and recall."""
	if event.is_action_pressed("assign_modifier"):  # Shift key typically
		# Assign current target to hotkey
		assign_target_to_hotkey(hotkey)
	else:
		# Recall target from hotkey
		recall_target_from_hotkey(hotkey)

## Target cycling methods (SHIP-006 AC7)
func cycle_target_next() -> bool:
	"""Cycle to next available target."""
	if not target_manager:
		return false
	
	var success: bool = target_manager.cycle_target_next()
	if success:
		_play_target_change_sound()
		_update_hud_target_display()
	
	return success

func cycle_target_previous() -> bool:
	"""Cycle to previous available target."""
	if not target_manager:
		return false
	
	var success: bool = target_manager.cycle_target_previous()
	if success:
		_play_target_change_sound()
		_update_hud_target_display()
	
	return success

func select_closest_target() -> bool:
	"""Select closest available target."""
	if not target_manager:
		return false
	
	var closest_target: Node3D = target_manager.get_closest_target()
	if closest_target:
		var success: bool = target_manager.set_target(closest_target)
		if success:
			_play_target_change_sound()
			_update_hud_target_display()
		return success
	
	return false

func cycle_hostile_targets() -> bool:
	"""Cycle through hostile targets only."""
	if not target_manager:
		return false
	
	var success: bool = target_manager.cycle_target_by_team(TeamTypes.Team.HOSTILE)
	if success:
		_play_target_change_sound()
		_update_hud_target_display()
	
	return success

func cycle_friendly_targets() -> bool:
	"""Cycle through friendly targets only."""
	if not target_manager:
		return false
	
	var success: bool = target_manager.cycle_target_by_team(TeamTypes.Team.FRIENDLY)
	if success:
		_play_target_change_sound()
		_update_hud_target_display()
	
	return success

## Subsystem targeting methods (SHIP-006 AC7)
func cycle_subsystem_next() -> bool:
	"""Cycle to next subsystem on current target."""
	if not subsystem_targeting or not target_manager.current_target:
		return false
	
	# Set target ship if not already set
	if subsystem_targeting.current_target_ship != target_manager.current_target:
		subsystem_targeting.set_target_ship(target_manager.current_target as BaseShip)
	
	var success: bool = subsystem_targeting.cycle_subsystem_next()
	if success:
		_play_target_change_sound()
		_update_hud_subsystem_display()
	
	return success

func cycle_subsystem_previous() -> bool:
	"""Cycle to previous subsystem on current target."""
	if not subsystem_targeting or not target_manager.current_target:
		return false
	
	# Set target ship if not already set
	if subsystem_targeting.current_target_ship != target_manager.current_target:
		subsystem_targeting.set_target_ship(target_manager.current_target as BaseShip)
	
	var success: bool = subsystem_targeting.cycle_subsystem_previous()
	if success:
		_play_target_change_sound()
		_update_hud_subsystem_display()
	
	return success

func disable_subsystem_targeting() -> void:
	"""Disable subsystem targeting mode."""
	if subsystem_targeting:
		subsystem_targeting.set_target_ship(null)
		_update_hud_subsystem_display()

## Hotkey target management (SHIP-006 AC7)
func assign_target_to_hotkey(hotkey: int) -> bool:
	"""Assign current target to hotkey slot."""
	if not target_manager:
		return false
	
	var success: bool = target_manager.assign_hotkey_target(hotkey)
	if success:
		_play_assignment_sound()
		hotkey_assignment_changed.emit(hotkey, target_manager.current_target)
	
	return success

func recall_target_from_hotkey(hotkey: int) -> bool:
	"""Recall target from hotkey slot."""
	if not target_manager:
		return false
	
	var success: bool = target_manager.recall_hotkey_target(hotkey)
	if success:
		_play_target_change_sound()
		_update_hud_target_display()
	
	return success

## Mouse click targeting
func _handle_mouse_click_targeting(screen_position: Vector2) -> void:
	"""Handle mouse click targeting on screen."""
	if not player_ship or not player_ship.get_viewport():
		return
	
	var camera: Camera3D = player_ship.get_viewport().get_camera_3d()
	if not camera:
		return
	
	# Cast ray from camera through mouse position
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	
	var space_state := player_ship.physics_body.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + ray_direction * 10000.0,  # 10km max range
		(1 << CollisionLayers.Layer.SHIPS) | (1 << CollisionLayers.Layer.ASTEROIDS)
	)
	
	var result := space_state.intersect_ray(query)
	if not result.is_empty():
		var hit_object := result["collider"] as Node3D
		var target_object := _find_targetable_object(hit_object)
		
		if target_object and target_manager:
			target_manager.set_target(target_object)
			_play_target_change_sound()
			_update_hud_target_display()

## Find targetable object from hit collider
func _find_targetable_object(hit_object: Node3D) -> Node3D:
	"""Find targetable object from physics hit."""
	if not hit_object:
		return null
	
	# Check if hit object is a ship
	var current_node: Node = hit_object
	while current_node:
		if current_node is BaseShip:
			return current_node as Node3D
		current_node = current_node.get_parent()
	
	# Check for other targetable objects
	if hit_object.has_method("get_target_info"):
		return hit_object
	
	return null

## Show targeting context menu
func _show_targeting_context_menu(screen_position: Vector2) -> void:
	"""Show targeting context menu at screen position."""
	# This would integrate with UI system for context menus
	pass

## Set targeting mode
func set_targeting_mode(mode: String) -> void:
	"""Set targeting mode (normal, subsystem, formation)."""
	if current_targeting_mode == mode:
		return
	
	current_targeting_mode = mode
	targeting_mode_changed.emit(mode)
	
	# Configure targeting systems based on mode
	match mode:
		"normal":
			disable_subsystem_targeting()
		"subsystem":
			if target_manager.current_target and target_manager.current_target is BaseShip:
				subsystem_targeting.set_target_ship(target_manager.current_target)
		"formation":
			# Formation targeting would be handled by AI system
			pass

## Get current targeting status
func get_targeting_status() -> Dictionary:
	"""Get comprehensive targeting status for HUD display."""
	var status: Dictionary = {
		"has_target": false,
		"target_name": "",
		"target_distance": 0.0,
		"has_subsystem": false,
		"subsystem_name": "",
		"lock_strength": 0.0,
		"has_aspect_lock": false,
		"targeting_mode": current_targeting_mode,
		"available_targets": 0,
		"hotkey_assignments": {}
	}
	
	# Target manager status
	if target_manager:
		var target_info: Dictionary = target_manager.get_target_info()
		status["has_target"] = target_info["has_target"]
		status["target_name"] = target_info["target_name"]
		status["target_distance"] = target_info["target_distance"]
		status["available_targets"] = target_info["available_targets_count"]
		status["hotkey_assignments"] = target_info["hotkey_targets"]
	
	# Subsystem targeting status
	if subsystem_targeting:
		var subsystem_info: Dictionary = subsystem_targeting.get_current_subsystem_info()
		status["has_subsystem"] = subsystem_info["has_subsystem"]
		status["subsystem_name"] = subsystem_info["subsystem_name"]
	
	# Aspect lock status
	if aspect_lock_controller:
		var lock_status: Dictionary = aspect_lock_controller.get_lock_status()
		status["lock_strength"] = lock_status["lock_progress"]
		status["has_aspect_lock"] = lock_status["has_aspect_lock"]
	
	return status

## HUD update methods
func _update_hud_target_display() -> void:
	"""Update HUD target display."""
	if not hud_system:
		return
	
	var status: Dictionary = get_targeting_status()
	
	# Update target brackets and information
	if hud_system.has_method("update_target_display"):
		hud_system.update_target_display(status)
	
	# Update lead indicator
	if show_lead_indicator and target_manager and target_manager.current_target:
		_update_lead_indicator()

func _update_hud_subsystem_display() -> void:
	"""Update HUD subsystem display."""
	if not hud_system:
		return
	
	var status: Dictionary = get_targeting_status()
	
	# Update subsystem highlighting
	if hud_system.has_method("update_subsystem_display"):
		hud_system.update_subsystem_display(status)

func _update_lead_indicator() -> void:
	"""Update lead indicator position."""
	if not player_ship.weapon_manager or not target_manager.current_target:
		return
	
	# Get firing solution from weapon manager
	var weapon_status: Dictionary = player_ship.weapon_manager.get_weapon_status()
	# Lead indicator update would be handled by HUD system

## Audio feedback methods
func _play_target_change_sound() -> void:
	"""Play target change sound effect."""
	if target_change_sound_enabled:
		# This would integrate with audio system
		pass

func _play_assignment_sound() -> void:
	"""Play hotkey assignment sound effect."""
	# This would integrate with audio system
	pass

func _on_lock_tone_start(target: Node3D) -> void:
	"""Handle lock tone start."""
	if lock_tone_enabled:
		# This would integrate with audio system for lock tone
		pass

func _on_lock_tone_stop() -> void:
	"""Handle lock tone stop."""
	if lock_tone_enabled:
		# This would integrate with audio system to stop lock tone
		pass

## Signal handlers for targeting events
func _on_target_acquired(target: Node3D, target_subsystem: Node) -> void:
	"""Handle target acquisition."""
	target_selection_changed.emit(target, null)
	_update_hud_target_display()

func _on_target_lost() -> void:
	"""Handle target loss."""
	target_selection_changed.emit(null, target_manager.current_target if target_manager else null)
	_update_hud_target_display()

func _on_target_changed(old_target: Node3D, new_target: Node3D) -> void:
	"""Handle target change."""
	target_selection_changed.emit(new_target, old_target)
	
	# Update aspect lock controller with new target
	if aspect_lock_controller:
		aspect_lock_controller.set_target(new_target)
	
	_update_hud_target_display()

func _on_hotkey_target_assigned(hotkey: int, target: Node3D) -> void:
	"""Handle hotkey target assignment."""
	hotkey_assignment_changed.emit(hotkey, target)

func _on_aspect_lock_acquired(target: Node3D, lock_time: float) -> void:
	"""Handle aspect lock achievement."""
	aspect_lock_achieved.emit(target, lock_time)

func _on_aspect_lock_lost(target: Node3D) -> void:
	"""Handle aspect lock loss."""
	aspect_lock_lost.emit(target)

func _on_aspect_lock_progress_changed(target: Node3D, progress: float) -> void:
	"""Handle aspect lock progress updates."""
	target_lock_strength_changed.emit(progress, 1.0)

func _on_subsystem_selected(target: Node3D, subsystem: Node, subsystem_name: String) -> void:
	"""Handle subsystem selection."""
	subsystem_selection_changed.emit(subsystem, subsystem_name)
	_update_hud_subsystem_display()

func _on_subsystem_targeting_disabled() -> void:
	"""Handle subsystem targeting disable."""
	subsystem_selection_changed.emit(null, "")
	_update_hud_subsystem_display()

## Configuration methods
func set_input_enabled(enabled: bool) -> void:
	"""Enable or disable input handling."""
	input_enabled = enabled

func set_mouse_targeting_enabled(enabled: bool) -> void:
	"""Enable or disable mouse targeting."""
	mouse_targeting_enabled = enabled

func set_keyboard_targeting_enabled(enabled: bool) -> void:
	"""Enable or disable keyboard targeting."""
	keyboard_targeting_enabled = enabled

func set_visual_feedback_settings(target_info: bool, lead_indicator: bool, subsystem_highlights: bool) -> void:
	"""Configure visual feedback settings."""
	show_target_info = target_info
	show_lead_indicator = lead_indicator
	show_subsystem_highlights = subsystem_highlights

func set_audio_feedback_settings(lock_tone: bool, target_change: bool) -> void:
	"""Configure audio feedback settings."""
	lock_tone_enabled = lock_tone
	target_change_sound_enabled = target_change

## Debug information
func debug_info() -> String:
	"""Get debug information string."""
	var info: String = "PlayerTargeting: "
	info += "Mode:%s " % current_targeting_mode
	info += "Input:%s " % ("On" if input_enabled else "Off")
	if target_manager:
		info += "Target:%s " % (target_manager.current_target.name if target_manager.current_target else "None")
	return info