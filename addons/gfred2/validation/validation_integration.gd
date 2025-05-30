@tool
class_name ValidationIntegration
extends Node

## Integration layer for GFRED2 validation system
## Connects MissionValidationController with editor UI components
## Provides real-time validation feedback and performance optimization

signal validation_system_ready()
signal validation_indicator_update_requested(component: Control, result: ValidationResult)

## Core validation components
var validation_controller: MissionValidationController
var validation_dock: ValidationDock

## UI integration points
var property_inspector: Node  # Object property inspector
var object_hierarchy: Node    # Mission object hierarchy tree
var sexp_editor: Node        # Visual SEXP editor

## Performance optimization
var validation_debounce_timer: Timer
var pending_validations: Array[String] = []
var indicator_cache: Dictionary = {}  # component_path -> ValidationIndicator
var last_validation_hash: int = 0

## Configuration
@export var debounce_delay: float = 0.3  # Seconds to wait before validation
@export var enable_indicator_animation: bool = true
@export var max_cached_indicators: int = 50

func _ready() -> void:
	name = "ValidationIntegration"
	
	# Setup validation debounce timer
	validation_debounce_timer = Timer.new()
	validation_debounce_timer.wait_time = debounce_delay
	validation_debounce_timer.one_shot = true
	validation_debounce_timer.timeout.connect(_process_pending_validations)
	add_child(validation_debounce_timer)
	
	# Initialize validation system
	_initialize_validation_system()

func _initialize_validation_system() -> void:
	"""Initialize the validation system and connect components."""
	
	# Create validation controller
	validation_controller = MissionValidationController.new()
	add_child(validation_controller)
	
	# Connect validation controller signals
	validation_controller.validation_completed.connect(_on_validation_completed)
	validation_controller.validation_progress.connect(_on_validation_progress)
	validation_controller.asset_dependency_error.connect(_on_asset_dependency_error)
	validation_controller.sexp_validation_error.connect(_on_sexp_validation_error)
	
	# Create validation dock
	validation_dock = ValidationDock.new()
	validation_dock.set_validation_controller(validation_controller)
	
	# Connect validation dock signals
	validation_dock.validation_item_selected.connect(_on_validation_item_selected)
	validation_dock.fix_suggestion_applied.connect(_on_fix_suggestion_applied)
	validation_dock.dependency_view_requested.connect(_on_dependency_view_requested)
	
	validation_system_ready.emit()

func set_mission_data(data: MissionData) -> void:
	"""Set mission data for validation.
	Args:
		data: Mission data to validate"""
	
	if validation_controller:
		validation_controller.set_mission_data(data)
		
		# Calculate data hash for change detection
		last_validation_hash = _calculate_mission_hash(data)

func _calculate_mission_hash(data: MissionData) -> int:
	"""Calculate hash of mission data for change detection.
	Args:
		data: Mission data to hash
	Returns:
		Hash value for comparison"""
	
	if not data:
		return 0
	
	var hash_input: String = ""
	
	# Include mission info
	if data.mission_info:
		hash_input += data.mission_info.name + str(data.mission_info.version)
	
	# Include object count and basic properties
	if data.objects:
		hash_input += str(data.objects.size())
		for i in range(min(data.objects.size(), 10)):  # Sample first 10 objects
			var obj: MissionObjectData = data.objects[i]
			if obj:
				hash_input += obj.object_name + obj.ship_class
	
	return hash_input.hash()

func integrate_with_property_inspector(inspector: Node) -> void:
	"""Integrate validation with property inspector.
	Args:
		inspector: Property inspector component"""
	
	property_inspector = inspector
	
	# Connect to property changes for real-time validation
	if inspector.has_signal("property_changed"):
		if not inspector.property_changed.is_connected(_on_property_changed):
			inspector.property_changed.connect(_on_property_changed)

func integrate_with_object_hierarchy(hierarchy: Node) -> void:
	"""Integrate validation with object hierarchy tree.
	Args:
		hierarchy: Object hierarchy component"""
	
	object_hierarchy = hierarchy
	
	# Add validation indicators to hierarchy items
	if hierarchy.has_method("get_tree_items"):
		_add_hierarchy_validation_indicators()

func integrate_with_sexp_editor(editor: Node) -> void:
	"""Integrate validation with SEXP editor.
	Args:
		editor: SEXP editor component"""
	
	sexp_editor = editor
	
	# Connect to SEXP changes for validation
	if editor.has_signal("expression_changed"):
		if not editor.expression_changed.is_connected(_on_sexp_expression_changed):
			editor.expression_changed.connect(_on_sexp_expression_changed)

func _on_property_changed(object_id: String, property: String, old_value: Variant, new_value: Variant) -> void:
	"""Handle property changes for real-time validation.
	Args:
		object_id: ID of object that changed
		property: Property that changed
		old_value: Previous value
		new_value: New value"""
	
	# Queue validation for the specific object
	if not pending_validations.has(object_id):
		pending_validations.append(object_id)
	
	# Start/restart debounce timer
	validation_debounce_timer.start()

func _on_sexp_expression_changed(expression: String, context: String) -> void:
	"""Handle SEXP expression changes.
	Args:
		expression: Changed SEXP expression
		context: Context (event, goal, etc.)"""
	
	# Queue SEXP validation
	var sexp_id: String = "sexp_" + context
	if not pending_validations.has(sexp_id):
		pending_validations.append(sexp_id)
	
	validation_debounce_timer.start()

func _process_pending_validations() -> void:
	"""Process queued validations after debounce period."""
	
	if pending_validations.is_empty():
		return
	
	# Trigger full validation for now
	# TODO: Implement incremental validation for specific objects
	if validation_controller:
		validation_controller.validate_mission()
	
	pending_validations.clear()

func _on_validation_completed(result: MissionValidationController.MissionValidationDetailedResult) -> void:
	"""Handle validation completion and update UI indicators.
	Args:
		result: Validation result"""
	
	# Update property inspector indicators
	if property_inspector:
		_update_property_inspector_indicators(result)
	
	# Update object hierarchy indicators
	if object_hierarchy:
		_update_object_hierarchy_indicators(result)
	
	# Update SEXP editor indicators
	if sexp_editor:
		_update_sexp_editor_indicators(result)
	
	# Update general UI indicators
	_update_general_indicators(result)

func _update_property_inspector_indicators(result: MissionValidationController.MissionValidationDetailedResult) -> void:
	"""Update validation indicators in property inspector.
	Args:
		result: Validation result"""
	
	if not property_inspector or not result:
		return
	
	# Update indicators for each validated object
	for object_id in result.object_results.keys():
		var object_result: ValidationResult = result.object_results[object_id]
		var indicator: ValidationIndicator = _get_or_create_indicator(property_inspector, object_id)
		
		if indicator:
			indicator.update_from_validation_result(object_result)

func _update_object_hierarchy_indicators(result: MissionValidationController.MissionValidationDetailedResult) -> void:
	"""Update validation indicators in object hierarchy.
	Args:
		result: Validation result"""
	
	if not object_hierarchy or not result:
		return
	
	# TODO: Find Tree or ItemList component and update indicators
	# This depends on the specific implementation of object_hierarchy
	
	if object_hierarchy.has_method("get_tree_root"):
		var tree_root: TreeItem = object_hierarchy.get_tree_root()
		_update_tree_item_indicators(tree_root, result)

func _update_tree_item_indicators(item: TreeItem, result: MissionValidationController.MissionValidationDetailedResult) -> void:
	"""Recursively update tree item validation indicators.
	Args:
		item: Tree item to update
		result: Validation result"""
	
	if not item:
		return
	
	# Get object ID from tree item metadata
	var metadata: Variant = item.get_metadata(0)
	if metadata is String:
		var object_id: String = metadata as String
		
		if result.object_results.has(object_id):
			var object_result: ValidationResult = result.object_results[object_id]
			
			# Update tree item icon based on validation result
			if not object_result.is_valid():
				item.set_icon(0, get_theme_icon("StatusError", "EditorIcons"))
			elif object_result.has_warnings():
				item.set_icon(0, get_theme_icon("StatusWarning", "EditorIcons"))
			else:
				item.set_icon(0, get_theme_icon("StatusSuccess", "EditorIcons"))
	
	# Update children recursively
	for child in item.get_children():
		_update_tree_item_indicators(child, result)

func _update_sexp_editor_indicators(result: MissionValidationController.MissionValidationDetailedResult) -> void:
	"""Update validation indicators in SEXP editor.
	Args:
		result: Validation result"""
	
	if not sexp_editor or not result:
		return
	
	# Update SEXP validation indicators
	for sexp_id in result.sexp_results.keys():
		var sexp_result: ValidationResult = result.sexp_results[sexp_id]
		var indicator: ValidationIndicator = _get_or_create_indicator(sexp_editor, sexp_id)
		
		if indicator:
			indicator.update_from_validation_result(sexp_result)

func _update_general_indicators(result: MissionValidationController.MissionValidationDetailedResult) -> void:
	"""Update general validation indicators throughout the UI.
	Args:
		result: Validation result"""
	
	# Emit signal for other components to update their indicators
	validation_indicator_update_requested.emit(get_parent(), result.overall_result)

func _get_or_create_indicator(parent: Node, identifier: String) -> ValidationIndicator:
	"""Get existing or create new validation indicator.
	Args:
		parent: Parent node for the indicator
		identifier: Unique identifier for the indicator
	Returns:
		ValidationIndicator instance"""
	
	var cache_key: String = parent.get_path() + "/" + identifier
	
	# Check cache
	if indicator_cache.has(cache_key):
		var indicator: ValidationIndicator = indicator_cache[cache_key]
		if is_instance_valid(indicator):
			return indicator
		else:
			indicator_cache.erase(cache_key)
	
	# Create new indicator
	var indicator: ValidationIndicator = ValidationIndicator.new()
	indicator.name = "ValidationIndicator_" + identifier
	indicator.indicator_size = Vector2(12, 12)
	indicator.show_tooltip = true
	indicator.animate_transitions = enable_indicator_animation
	
	# Add to parent (position depends on parent type)
	if parent is Control:
		_position_indicator_in_control(parent as Control, indicator, identifier)
	
	# Cache the indicator
	if indicator_cache.size() >= max_cached_indicators:
		_cleanup_indicator_cache()
	
	indicator_cache[cache_key] = indicator
	
	return indicator

func _position_indicator_in_control(parent: Control, indicator: ValidationIndicator, identifier: String) -> void:
	"""Position validation indicator within a control.
	Args:
		parent: Parent control
		indicator: Validation indicator to position
		identifier: Identifier for positioning logic"""
	
	# Add indicator to parent
	parent.add_child(indicator)
	
	# Position in top-right corner by default
	indicator.anchors_preset = Control.PRESET_TOP_RIGHT
	indicator.position = Vector2(-16, 4)
	
	# Specific positioning based on parent type
	if parent is LineEdit:
		indicator.position = Vector2(-20, 2)
	elif parent is SpinBox:
		indicator.position = Vector2(-20, 2)
	elif parent is OptionButton:
		indicator.position = Vector2(-24, 2)

func _cleanup_indicator_cache() -> void:
	"""Clean up invalid indicators from cache."""
	
	var keys_to_remove: Array[String] = []
	
	for cache_key in indicator_cache.keys():
		var indicator: ValidationIndicator = indicator_cache[cache_key]
		if not is_instance_valid(indicator):
			keys_to_remove.append(cache_key)
	
	for key in keys_to_remove:
		indicator_cache.erase(key)

func _add_hierarchy_validation_indicators() -> void:
	"""Add validation indicators to object hierarchy items."""
	
	if not object_hierarchy:
		return
	
	# TODO: Implement based on actual hierarchy structure
	# This would add ValidationIndicator nodes to tree items or list items

func _on_validation_progress(percentage: float, current_check: String) -> void:
	"""Handle validation progress updates.
	Args:
		percentage: Progress percentage
		current_check: Current validation step"""
	
	# Update any progress indicators in the UI
	# TODO: Show progress in status bar or progress dialog

func _on_asset_dependency_error(asset_path: String, error_message: String) -> void:
	"""Handle asset dependency errors.
	Args:
		asset_path: Path to problematic asset
		error_message: Error description"""
	
	push_warning("Asset dependency error: %s - %s" % [asset_path, error_message])
	
	# TODO: Highlight asset in asset browser if available

func _on_sexp_validation_error(expression: String, error_message: String) -> void:
	"""Handle SEXP validation errors.
	Args:
		expression: Problematic SEXP expression
		error_message: Error description"""
	
	push_warning("SEXP validation error: %s" % error_message)
	
	# TODO: Highlight SEXP expression in editor

func _on_validation_item_selected(result: ValidationResult, object_id: String) -> void:
	"""Handle validation item selection from dock.
	Args:
		result: Selected validation result
		object_id: Associated object ID"""
	
	# Navigate to the problematic object/property
	_navigate_to_validation_issue(object_id, result)

func _navigate_to_validation_issue(object_id: String, result: ValidationResult) -> void:
	"""Navigate to a validation issue in the editor.
	Args:
		object_id: Object with the issue
		result: Validation result with details"""
	
	# Select object in hierarchy
	if object_hierarchy and object_hierarchy.has_method("select_object"):
		object_hierarchy.select_object(object_id)
	
	# Show object in property inspector
	if property_inspector and property_inspector.has_method("show_object"):
		property_inspector.show_object(object_id)
	
	# TODO: Scroll to specific property if error is property-specific

func _on_fix_suggestion_applied(object_id: String, property: String, suggested_value: Variant) -> void:
	"""Handle fix suggestion application.
	Args:
		object_id: Object to fix
		property: Property to modify
		suggested_value: Suggested value"""
	
	# TODO: Apply the fix automatically if safe
	# For now, just navigate to the issue
	if validation_controller and validation_controller.current_validation_result:
		var object_result: ValidationResult = validation_controller.current_validation_result.object_results.get(object_id)
		if object_result:
			_navigate_to_validation_issue(object_id, object_result)

func _on_dependency_view_requested(dependency_info: MissionValidationController.DependencyInfo) -> void:
	"""Handle dependency view requests.
	Args:
		dependency_info: Dependency to show"""
	
	# Switch validation dock to dependency view
	if validation_dock:
		validation_dock.show_dependency_graph()
	
	# TODO: Highlight the specific dependency in the graph

## Public API

func get_validation_controller() -> MissionValidationController:
	"""Get the validation controller instance.
	Returns:
		MissionValidationController instance"""
	
	return validation_controller

func get_validation_dock() -> ValidationDock:
	"""Get the validation dock instance.
	Returns:
		ValidationDock instance"""
	
	return validation_dock

func trigger_manual_validation() -> void:
	"""Trigger manual validation immediately."""
	
	if validation_controller:
		validation_controller.validate_mission()

func force_indicator_refresh() -> void:
	"""Force refresh of all validation indicators."""
	
	if validation_controller and validation_controller.current_validation_result:
		_on_validation_completed(validation_controller.current_validation_result)

func set_validation_debounce_delay(delay: float) -> void:
	"""Set the debounce delay for real-time validation.
	Args:
		delay: Delay in seconds"""
	
	debounce_delay = delay
	if validation_debounce_timer:
		validation_debounce_timer.wait_time = delay

func enable_real_time_validation(enabled: bool) -> void:
	"""Enable or disable real-time validation.
	Args:
		enabled: Whether to enable real-time validation"""
	
	if validation_controller:
		validation_controller.set_real_time_validation(enabled)

func clear_validation_cache() -> void:
	"""Clear validation cache to force fresh validation."""
	
	if validation_controller:
		validation_controller.clear_validation_cache()
	
	# Clear indicator cache
	indicator_cache.clear()

func get_validation_statistics() -> Dictionary:
	"""Get validation performance statistics.
	Returns:
		Dictionary with validation statistics"""
	
	if validation_controller:
		return validation_controller.get_validation_statistics()
	else:
		return {}

func is_validation_system_ready() -> bool:
	"""Check if validation system is ready.
	Returns:
		True if validation system is initialized and ready"""
	
	return validation_controller != null and validation_dock != null