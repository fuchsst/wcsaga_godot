class_name HUDCustomizationManager
extends Node

## EPIC-012 HUD-016: HUD Customization Manager
## Central coordination system for HUD element customization and user preferences
## Provides comprehensive interface customization, profile management, and accessibility features

signal customization_mode_changed(enabled: bool)
signal element_customization_changed(element_id: String, config: ElementConfiguration)
signal profile_loaded(profile_name: String, profile: HUDProfile)
signal profile_saved(profile_name: String, profile: HUDProfile)
signal customization_error(error_message: String)

# Singleton instance for global access
static var instance: HUDCustomizationManager

# Customization system components
var element_positioning_system: ElementPositioningSystem
var visibility_manager: VisibilityManager
var visual_styling_system: VisualStylingSystem
var profile_manager: ProfileManager

# Customization state
var current_profile: HUDProfile
var customization_mode: bool = false
var pending_changes: Dictionary = {}
var undo_stack: Array[CustomizationAction] = []
var redo_stack: Array[CustomizationAction] = []

# Element tracking and management
var customizable_elements: Dictionary = {}  # element_id -> HUDElementBase
var element_constraints: Dictionary = {}
var layout_presets: Array[LayoutPreset] = []

# Configuration settings
@export var max_undo_stack_size: int = 50
@export var auto_save_enabled: bool = true
@export var auto_save_interval: float = 30.0
@export var grid_snap_enabled: bool = true
@export var collision_detection_enabled: bool = true

# Customization interface
var customization_interface: CustomizationInterface
var property_panel: Control
var grid_overlay: Control
var alignment_guides: Array[Control] = []

# Performance monitoring
var performance_monitor: HUDPerformanceMonitor
var customization_start_time: float
var update_timer: Timer

func _init():
	if instance == null:
		instance = self
	name = "HUDCustomizationManager"
	set_process(false)  # Only process when in customization mode

func _ready() -> void:
	_initialize_customization_system()

## Initialize the HUD customization framework
func _initialize_customization_system() -> void:
	print("HUDCustomizationManager: Initializing comprehensive customization framework...")
	
	# Initialize core systems
	_initialize_core_systems()
	
	# Setup default configuration
	_load_default_configuration()
	
	# Initialize UI components
	_initialize_ui_components()
	
	# Setup auto-save timer
	_setup_auto_save()
	
	# Connect to HUD manager
	_connect_to_hud_manager()
	
	print("HUDCustomizationManager: Customization framework initialization complete")

## Initialize core customization systems
func _initialize_core_systems() -> void:
	# Create element positioning system
	element_positioning_system = ElementPositioningSystem.new()
	add_child(element_positioning_system)
	element_positioning_system.element_moved.connect(_on_element_moved)
	element_positioning_system.element_resized.connect(_on_element_resized)
	
	# Create visibility manager
	visibility_manager = VisibilityManager.new()
	add_child(visibility_manager)
	visibility_manager.visibility_changed.connect(_on_element_visibility_changed)
	
	# Create visual styling system
	visual_styling_system = VisualStylingSystem.new()
	add_child(visual_styling_system)
	visual_styling_system.style_changed.connect(_on_element_style_changed)
	
	# Create profile manager
	profile_manager = ProfileManager.new()
	add_child(profile_manager)
	profile_manager.profile_loaded.connect(_on_profile_loaded)
	profile_manager.profile_saved.connect(_on_profile_saved)
	
	print("HUDCustomizationManager: Core systems initialized")

## Initialize UI components for customization interface
func _initialize_ui_components() -> void:
	# Create customization interface
	customization_interface = CustomizationInterface.new()
	add_child(customization_interface)
	customization_interface.visible = false
	
	# Create property panel
	property_panel = Control.new()
	property_panel.name = "PropertyPanel"
	customization_interface.add_child(property_panel)
	
	# Create grid overlay
	grid_overlay = Control.new()
	grid_overlay.name = "GridOverlay"
	grid_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	customization_interface.add_child(grid_overlay)
	
	print("HUDCustomizationManager: UI components initialized")

## Setup auto-save timer
func _setup_auto_save() -> void:
	if auto_save_enabled:
		update_timer = Timer.new()
		update_timer.wait_time = auto_save_interval
		update_timer.timeout.connect(_auto_save_configuration)
		update_timer.autostart = false
		add_child(update_timer)

## Connect to HUD manager for element discovery
func _connect_to_hud_manager() -> void:
	if HUDManager.is_ready():
		var hud_manager = HUDManager.get_instance()
		hud_manager.hud_element_registered.connect(_on_hud_element_registered)
		hud_manager.hud_element_unregistered.connect(_on_hud_element_unregistered)
		
		# Discover existing elements
		_discover_existing_elements()

## Discover existing HUD elements for customization
func _discover_existing_elements() -> void:
	if not HUDManager.is_ready():
		return
	
	var hud_manager = HUDManager.get_instance()
	var elements = hud_manager.get_all_elements()
	
	for element in elements:
		_register_customizable_element(element)

## Register element for customization
func _register_customizable_element(element: HUDElementBase) -> void:
	if not element or element.element_id.is_empty():
		return
	
	customizable_elements[element.element_id] = element
	element_constraints[element.element_id] = _get_element_constraints(element)
	
	print("HUDCustomizationManager: Registered element for customization: " + element.element_id)

## Get element constraints for positioning and sizing
func _get_element_constraints(element: HUDElementBase) -> Dictionary:
	return {
		"min_size": element.get("min_size", Vector2(20, 20)),
		"max_size": element.get("max_size", Vector2(500, 500)),
		"can_rotate": element.get("can_rotate", false),
		"snap_to_edges": element.get("snap_to_edges", true),
		"maintain_aspect_ratio": element.get("maintain_aspect_ratio", false)
	}

## Enter customization mode
func enter_customization_mode() -> void:
	if customization_mode:
		return
	
	customization_mode = true
	customization_start_time = Time.get_unix_time_from_system()
	
	# Show customization interface
	if customization_interface:
		customization_interface.visible = true
	
	# Enable element positioning
	if element_positioning_system:
		element_positioning_system.enable_positioning_mode()
	
	# Show grid overlay
	if grid_overlay and grid_snap_enabled:
		grid_overlay.visible = true
	
	# Start processing for real-time updates
	set_process(true)
	
	# Start auto-save timer
	if update_timer and auto_save_enabled:
		update_timer.start()
	
	customization_mode_changed.emit(true)
	print("HUDCustomizationManager: Entered customization mode")

## Exit customization mode
func exit_customization_mode(save_changes: bool = true) -> void:
	if not customization_mode:
		return
	
	# Save or discard changes
	if save_changes and not pending_changes.is_empty():
		_apply_pending_changes()
		if current_profile:
			profile_manager.save_profile(current_profile)
	else:
		_discard_pending_changes()
	
	customization_mode = false
	
	# Hide customization interface
	if customization_interface:
		customization_interface.visible = false
	
	# Disable element positioning
	if element_positioning_system:
		element_positioning_system.disable_positioning_mode()
	
	# Hide grid overlay
	if grid_overlay:
		grid_overlay.visible = false
	
	# Stop processing
	set_process(false)
	
	# Stop auto-save timer
	if update_timer:
		update_timer.stop()
	
	customization_mode_changed.emit(false)
	print("HUDCustomizationManager: Exited customization mode")

## Apply customization profile
func apply_customization_profile(profile: HUDProfile) -> bool:
	if not profile:
		customization_error.emit("Invalid profile provided")
		return false
	
	# Validate profile
	if not _validate_profile(profile):
		customization_error.emit("Profile validation failed")
		return false
	
	current_profile = profile
	
	# Apply global settings
	_apply_global_settings(profile.global_settings)
	
	# Apply element configurations
	for element_id in profile.element_configurations:
		var config = profile.element_configurations[element_id]
		_apply_element_configuration(element_id, config)
	
	# Apply visibility rules
	_apply_visibility_rules(profile.visibility_rules)
	
	profile_loaded.emit(profile.profile_name, profile)
	print("HUDCustomizationManager: Applied profile: " + profile.profile_name)
	return true

## Apply element configuration
func _apply_element_configuration(element_id: String, config: ElementConfiguration) -> void:
	var element = customizable_elements.get(element_id)
	if not element:
		return
	
	# Apply position and size
	if element_positioning_system:
		element_positioning_system.set_element_position(element, config.position)
		element_positioning_system.set_element_size(element, config.size)
		element_positioning_system.set_element_rotation(element, config.rotation)
		element_positioning_system.set_element_scale(element, config.scale)
	
	# Apply visibility
	if visibility_manager:
		visibility_manager.set_element_visibility(element_id, config.visible)
	
	# Apply styling
	if visual_styling_system and not config.custom_colors.is_empty():
		visual_styling_system.apply_element_colors(element_id, config.custom_colors)
	
	# Apply custom properties
	for property in config.custom_properties:
		if element.has_method("set_" + property):
			element.call("set_" + property, config.custom_properties[property])

## Apply global settings
func _apply_global_settings(settings: GlobalHUDSettings) -> void:
	if not settings:
		return
	
	# Apply master scale
	if HUDManager.is_ready():
		var hud_manager = HUDManager.get_instance()
		# Apply scaling through layout manager if available
		var layout_manager = hud_manager.get_layout_manager()
		if layout_manager:
			layout_manager.set_global_scale(settings.master_scale)
	
	# Apply color scheme
	if visual_styling_system:
		visual_styling_system.apply_color_scheme(settings.color_scheme)
	
	# Apply other global settings
	_apply_information_density(settings.information_density)
	_apply_animation_settings(settings.animation_speed)

## Validate profile integrity
func _validate_profile(profile: HUDProfile) -> bool:
	if not profile:
		return false
	
	# Check required fields
	if profile.profile_name.is_empty():
		return false
	
	# Validate element configurations
	for element_id in profile.element_configurations:
		var config = profile.element_configurations[element_id]
		if not _validate_element_configuration(element_id, config):
			return false
	
	return true

## Validate element configuration
func _validate_element_configuration(element_id: String, config: ElementConfiguration) -> bool:
	if not config:
		return false
	
	# Check if element exists
	if not customizable_elements.has(element_id):
		return false
	
	# Validate constraints
	var constraints = element_constraints.get(element_id, {})
	
	# Check size constraints
	var min_size = constraints.get("min_size", Vector2(1, 1))
	var max_size = constraints.get("max_size", Vector2(9999, 9999))
	
	if config.size.x < min_size.x or config.size.x > max_size.x:
		return false
	if config.size.y < min_size.y or config.size.y > max_size.y:
		return false
	
	# Check scale constraints
	if config.scale <= 0.0 or config.scale > 5.0:
		return false
	
	return true

## Create new customization action for undo/redo
func _create_customization_action(type: String, element_id: String, old_value: Variant, new_value: Variant) -> CustomizationAction:
	var action = CustomizationAction.new()
	action.action_type = type
	action.element_id = element_id
	action.old_value = old_value
	action.new_value = new_value
	action.timestamp = Time.get_unix_time_from_system()
	return action

## Add action to undo stack
func _add_to_undo_stack(action: CustomizationAction) -> void:
	undo_stack.append(action)
	
	# Clear redo stack when new action is added
	redo_stack.clear()
	
	# Limit stack size
	if undo_stack.size() > max_undo_stack_size:
		undo_stack.pop_front()

## Undo last customization action
func undo_last_action() -> bool:
	if undo_stack.is_empty():
		return false
	
	var action = undo_stack.pop_back()
	_apply_customization_action(action, true)  # Apply in reverse
	redo_stack.append(action)
	
	print("HUDCustomizationManager: Undid action: " + action.action_type)
	return true

## Redo last undone action
func redo_last_action() -> bool:
	if redo_stack.is_empty():
		return false
	
	var action = redo_stack.pop_back()
	_apply_customization_action(action, false)  # Apply normally
	undo_stack.append(action)
	
	print("HUDCustomizationManager: Redid action: " + action.action_type)
	return true

## Apply customization action
func _apply_customization_action(action: CustomizationAction, reverse: bool) -> void:
	var element = customizable_elements.get(action.element_id)
	if not element:
		return
	
	var value = action.new_value if not reverse else action.old_value
	
	match action.action_type:
		"position":
			element_positioning_system.set_element_position(element, value)
		"size":
			element_positioning_system.set_element_size(element, value)
		"rotation":
			element_positioning_system.set_element_rotation(element, value)
		"scale":
			element_positioning_system.set_element_scale(element, value)
		"visibility":
			visibility_manager.set_element_visibility(action.element_id, value)
		"color":
			visual_styling_system.apply_element_colors(action.element_id, value)

## Load default configuration
func _load_default_configuration() -> void:
	# Create default profile
	current_profile = HUDProfile.new()
	current_profile.profile_name = "Default"
	current_profile.profile_description = "Default HUD configuration"
	current_profile.creation_date = Time.get_datetime_string_from_system()
	current_profile.last_modified = current_profile.creation_date
	current_profile.profile_version = "1.0.0"
	
	# Set default global settings
	current_profile.global_settings = GlobalHUDSettings.new()
	current_profile.global_settings.master_scale = 1.0
	current_profile.global_settings.color_scheme = "default"
	current_profile.global_settings.information_density = "standard"
	current_profile.global_settings.animation_speed = 1.0
	current_profile.global_settings.transparency_global = 0.9

## Process customization updates
func _process(delta: float) -> void:
	if not customization_mode:
		return
	
	# Update element positioning system
	if element_positioning_system:
		element_positioning_system.update_positioning(delta)
	
	# Update visual feedback
	_update_visual_feedback(delta)

## Update visual feedback during customization
func _update_visual_feedback(delta: float) -> void:
	# Update grid overlay
	if grid_overlay and grid_overlay.visible:
		queue_redraw()
	
	# Update alignment guides
	_update_alignment_guides()

## Update alignment guides
func _update_alignment_guides() -> void:
	# Clear existing guides
	for guide in alignment_guides:
		if is_instance_valid(guide):
			guide.queue_free()
	alignment_guides.clear()
	
	# Create new guides based on active element
	if element_positioning_system:
		var active_element = element_positioning_system.get_active_element()
		if active_element:
			_create_alignment_guides_for_element(active_element)

## Create alignment guides for element
func _create_alignment_guides_for_element(element: HUDElementBase) -> void:
	# Implementation would create visual guides for aligning elements
	pass

## Apply information density setting
func _apply_information_density(density: String) -> void:
	# Apply density to all elements
	for element_id in customizable_elements:
		var element = customizable_elements[element_id]
		if element.has_method("set_information_density"):
			element.set_information_density(density)

## Apply animation settings
func _apply_animation_settings(speed: float) -> void:
	# Apply animation speed to all elements
	for element_id in customizable_elements:
		var element = customizable_elements[element_id]
		if element.has_method("set_animation_speed"):
			element.set_animation_speed(speed)

## Apply visibility rules
func _apply_visibility_rules(rules: Array[VisibilityRule]) -> void:
	if visibility_manager:
		visibility_manager.apply_visibility_rules(rules)

## Apply pending changes
func _apply_pending_changes() -> void:
	for element_id in pending_changes:
		var changes = pending_changes[element_id]
		_apply_element_configuration(element_id, changes)
	pending_changes.clear()

## Discard pending changes
func _discard_pending_changes() -> void:
	pending_changes.clear()

## Auto-save configuration
func _auto_save_configuration() -> void:
	if current_profile and auto_save_enabled:
		current_profile.last_modified = Time.get_datetime_string_from_system()
		profile_manager.save_profile(current_profile)

## Signal handlers

func _on_hud_element_registered(element_id: String, element: HUDElementBase) -> void:
	_register_customizable_element(element)

func _on_hud_element_unregistered(element_id: String) -> void:
	customizable_elements.erase(element_id)
	element_constraints.erase(element_id)

func _on_element_moved(element: HUDElementBase, old_position: Vector2, new_position: Vector2) -> void:
	var action = _create_customization_action("position", element.element_id, old_position, new_position)
	_add_to_undo_stack(action)
	element_customization_changed.emit(element.element_id, _get_current_element_configuration(element))

func _on_element_resized(element: HUDElementBase, old_size: Vector2, new_size: Vector2) -> void:
	var action = _create_customization_action("size", element.element_id, old_size, new_size)
	_add_to_undo_stack(action)
	element_customization_changed.emit(element.element_id, _get_current_element_configuration(element))

func _on_element_visibility_changed(element_id: String, visible: bool) -> void:
	var element = customizable_elements.get(element_id)
	if element:
		element_customization_changed.emit(element_id, _get_current_element_configuration(element))

func _on_element_style_changed(element_id: String, style_data: Dictionary) -> void:
	var element = customizable_elements.get(element_id)
	if element:
		element_customization_changed.emit(element_id, _get_current_element_configuration(element))

func _on_profile_loaded(profile_name: String, profile: HUDProfile) -> void:
	profile_loaded.emit(profile_name, profile)

func _on_profile_saved(profile_name: String, profile: HUDProfile) -> void:
	profile_saved.emit(profile_name, profile)

## Get current element configuration
func _get_current_element_configuration(element: HUDElementBase) -> ElementConfiguration:
	var config = ElementConfiguration.new()
	config.element_id = element.element_id
	config.position = element.position
	config.size = element.size
	config.rotation = element.rotation
	config.scale = element.scale
	config.visible = element.visible
	return config

## Public API

## Get singleton instance
static func get_instance() -> HUDCustomizationManager:
	return instance

## Check if customization system is ready
static func is_ready() -> bool:
	return instance != null

## Get current customization mode
func is_customization_mode() -> bool:
	return customization_mode

## Get current profile
func get_current_profile() -> HUDProfile:
	return current_profile

## Get customizable elements
func get_customizable_elements() -> Dictionary:
	return customizable_elements.duplicate()

## Get element positioning system
func get_element_positioning_system() -> ElementPositioningSystem:
	return element_positioning_system

## Get visibility manager
func get_visibility_manager() -> VisibilityManager:
	return visibility_manager

## Get visual styling system
func get_visual_styling_system() -> VisualStylingSystem:
	return visual_styling_system

## Get profile manager
func get_profile_manager() -> ProfileManager:
	return profile_manager

## Cleanup and shutdown
func _exit_tree() -> void:
	if instance == self:
		instance = null