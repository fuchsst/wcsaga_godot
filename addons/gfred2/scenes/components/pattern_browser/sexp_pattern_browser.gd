@tool
class_name SexpPatternBrowser
extends VBoxContainer

## SEXP pattern browser component for GFRED2 Template Library.
## Provides UI for browsing, filtering, and inserting SEXP patterns.

signal pattern_selected(pattern: SexpPattern)
signal pattern_insert_requested(pattern: SexpPattern, parameters: Dictionary)
signal pattern_validated(pattern: SexpPattern, is_valid: bool, errors: Array[String])

# Pattern library manager
var template_manager: TemplateLibraryManager

# UI component references
@onready var category_filter: OptionButton = $HeaderPanel/HeaderContent/CategoryFilter
@onready var complexity_filter: OptionButton = $HeaderPanel/HeaderContent/ComplexityFilter
@onready var refresh_button: Button = $HeaderPanel/HeaderContent/RefreshButton
@onready var search_box: LineEdit = $MainSplitter/LeftPanel/SearchPanel/SearchBox
@onready var pattern_container: VBoxContainer = $MainSplitter/LeftPanel/PatternList/PatternContainer
@onready var pattern_name_label: Label = $MainSplitter/RightPanel/PreviewPanel/PatternDetails/PatternName
@onready var pattern_info: RichTextLabel = $MainSplitter/RightPanel/PreviewPanel/PatternDetails/PatternInfo
@onready var expression_editor: TextEdit = $MainSplitter/RightPanel/PreviewPanel/ExpressionPanel/ExpressionEditor
@onready var parameter_container: VBoxContainer = $MainSplitter/RightPanel/ParameterPanel/ParameterScroll/ParameterContainer
@onready var validate_button: Button = $MainSplitter/RightPanel/ActionPanel/ValidateButton
@onready var insert_button: Button = $MainSplitter/RightPanel/ActionPanel/InsertButton
@onready var copy_button: Button = $MainSplitter/RightPanel/ActionPanel/CopyButton

# Current state
var current_patterns: Array[SexpPattern] = []
var selected_pattern: SexpPattern = null
var parameter_controls: Dictionary = {}
var current_parameters: Dictionary = {}
var pattern_items: Array[Control] = []

func _ready() -> void:
	name = "SexpPatternBrowser"
	
	# Initialize template manager
	template_manager = TemplateLibraryManager.new()
	
	# Setup UI
	_setup_filter_options()
	_connect_signals()
	
	# Load patterns
	refresh_patterns()
	
	print("SexpPatternBrowser: Initialized with %d patterns" % template_manager.get_all_sexp_patterns().size())

## Sets up filter option buttons
func _setup_filter_options() -> void:
	# Category filter
	category_filter.add_item("All Categories", -1)
	for i in SexpPattern.PatternCategory.size():
		var category_name: String = SexpPattern.PatternCategory.keys()[i]
		category_filter.add_item(category_name.replace("_", " ").capitalize(), i)
	
	# Complexity filter
	complexity_filter.add_item("All Levels", -1)
	for i in SexpPattern.ComplexityLevel.size():
		var complexity_name: String = SexpPattern.ComplexityLevel.keys()[i]
		complexity_filter.add_item(complexity_name.capitalize(), i)

## Connects UI signals
func _connect_signals() -> void:
	# Filter signals
	category_filter.item_selected.connect(_on_filter_changed)
	complexity_filter.item_selected.connect(_on_filter_changed)
	search_box.text_changed.connect(_on_search_changed)
	
	# Action button signals
	refresh_button.pressed.connect(refresh_patterns)
	validate_button.pressed.connect(_on_validate_pressed)
	insert_button.pressed.connect(_on_insert_pressed)
	copy_button.pressed.connect(_on_copy_pressed)

## Refreshes the pattern list from the library
func refresh_patterns() -> void:
	current_patterns = template_manager.get_all_sexp_patterns()
	_apply_filters()

## Applies current filters to pattern list
func _apply_filters() -> void:
	var filtered_patterns: Array[SexpPattern] = []
	
	# Apply filters
	for pattern in current_patterns:
		if _pattern_matches_filters(pattern):
			filtered_patterns.append(pattern)
	
	# Sort patterns by name
	filtered_patterns.sort_custom(func(a, b): return a.pattern_name < b.pattern_name)
	
	# Update UI
	_populate_pattern_list(filtered_patterns)

## Checks if pattern matches current filters
func _pattern_matches_filters(pattern: SexpPattern) -> bool:
	# Category filter
	var category_id: int = category_filter.get_selected_id()
	if category_id >= 0 and pattern.category != category_id:
		return false
	
	# Complexity filter
	var complexity_id: int = complexity_filter.get_selected_id()
	if complexity_id >= 0 and pattern.complexity != complexity_id:
		return false
	
	# Search filter
	var search_text: String = search_box.text.to_lower()
	if not search_text.is_empty():
		var searchable_text: String = (
			pattern.pattern_name + " " + 
			pattern.description + " " + 
			pattern.sexp_expression + " " + 
			str(pattern.tags) + " " + 
			str(pattern.required_functions)
		).to_lower()
		if not searchable_text.contains(search_text):
			return false
	
	return true

## Populates the pattern list UI
func _populate_pattern_list(patterns: Array[SexpPattern]) -> void:
	# Clear existing items
	for item in pattern_items:
		item.queue_free()
	pattern_items.clear()
	
	# Create new items
	for pattern in patterns:
		var item: Control = _create_pattern_item(pattern)
		pattern_container.add_child(item)
		pattern_items.append(item)

## Creates a pattern list item
func _create_pattern_item(pattern: SexpPattern) -> Control:
	var item: PanelContainer = PanelContainer.new()
	item.custom_minimum_size = Vector2(0, 60)
	
	# Add background style
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.35, 1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	item.add_theme_stylebox_override("panel", style)
	
	# Main content
	var content: VBoxContainer = VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 2)
	item.add_child(content)
	
	# Pattern name
	var name_label: Label = Label.new()
	name_label.text = pattern.pattern_name
	name_label.add_theme_font_size_override("font_size", 12)
	content.add_child(name_label)
	
	# Pattern details
	var details: HBoxContainer = HBoxContainer.new()
	content.add_child(details)
	
	var category_label: Label = Label.new()
	var category_name: String = SexpPattern.PatternCategory.keys()[pattern.category]
	category_label.text = category_name.replace("_", " ").capitalize()
	category_label.add_theme_color_override("font_color", _get_category_color(pattern.category))
	category_label.add_theme_font_size_override("font_size", 10)
	details.add_child(category_label)
	
	var separator: Label = Label.new()
	separator.text = " • "
	separator.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 1))
	separator.add_theme_font_size_override("font_size", 10)
	details.add_child(separator)
	
	var complexity_label: Label = Label.new()
	var complexity_name: String = SexpPattern.ComplexityLevel.keys()[pattern.complexity]
	complexity_label.text = complexity_name.capitalize()
	complexity_label.add_theme_color_override("font_color", _get_complexity_color(pattern.complexity))
	complexity_label.add_theme_font_size_override("font_size", 10)
	details.add_child(complexity_label)
	
	# Short description
	var desc_label: Label = Label.new()
	desc_label.text = pattern.description
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.clip_contents = true
	content.add_child(desc_label)
	
	# Add click detection
	var button: Button = Button.new()
	button.flat = true
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(_on_pattern_item_selected.bind(pattern, item))
	item.add_child(button)
	
	return item

## Gets color for pattern category
func _get_category_color(category: SexpPattern.PatternCategory) -> Color:
	match category:
		SexpPattern.PatternCategory.TRIGGER:
			return Color(0.8, 0.3, 0.3, 1)
		SexpPattern.PatternCategory.ACTION:
			return Color(0.3, 0.8, 0.3, 1)
		SexpPattern.PatternCategory.CONDITION:
			return Color(0.3, 0.3, 0.8, 1)
		SexpPattern.PatternCategory.OBJECTIVE:
			return Color(0.8, 0.8, 0.3, 1)
		SexpPattern.PatternCategory.AI_BEHAVIOR:
			return Color(0.8, 0.3, 0.8, 1)
		SexpPattern.PatternCategory.EVENT_SEQUENCE:
			return Color(0.3, 0.8, 0.8, 1)
		SexpPattern.PatternCategory.VARIABLE_MANAGEMENT:
			return Color(0.6, 0.4, 0.8, 1)
		SexpPattern.PatternCategory.SHIP_CONTROL:
			return Color(0.8, 0.6, 0.3, 1)
		SexpPattern.PatternCategory.MISSION_FLOW:
			return Color(0.4, 0.6, 0.8, 1)
		_:
			return Color(0.6, 0.6, 0.6, 1)

## Gets color for complexity level
func _get_complexity_color(complexity: SexpPattern.ComplexityLevel) -> Color:
	match complexity:
		SexpPattern.ComplexityLevel.BASIC:
			return Color(0.3, 0.8, 0.3, 1)
		SexpPattern.ComplexityLevel.INTERMEDIATE:
			return Color(0.8, 0.8, 0.3, 1)
		SexpPattern.ComplexityLevel.ADVANCED:
			return Color(0.8, 0.5, 0.3, 1)
		SexpPattern.ComplexityLevel.EXPERT:
			return Color(0.8, 0.3, 0.3, 1)
		_:
			return Color(0.6, 0.6, 0.6, 1)

## Handles pattern item selection
func _on_pattern_item_selected(pattern: SexpPattern, item: Control) -> void:
	# Update selection visuals
	_update_selection_visual(item)
	
	# Store selected pattern
	selected_pattern = pattern
	
	# Update preview and parameters
	_update_pattern_preview(pattern)
	_create_parameter_controls(pattern)
	
	# Enable action buttons
	_update_action_buttons(true)
	
	# Emit signal
	pattern_selected.emit(pattern)

## Updates selection visual styling
func _update_selection_visual(selected_item: Control) -> void:
	# Reset all items to normal style
	for item in pattern_items:
		if item.has_method("add_theme_stylebox_override"):
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = Color(0.15, 0.15, 0.2, 1)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.border_color = Color(0.3, 0.3, 0.35, 1)
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_right = 4
			style.corner_radius_bottom_left = 4
			item.add_theme_stylebox_override("panel", style)
	
	# Highlight selected item
	if selected_item.has_method("add_theme_stylebox_override"):
		var selected_style: StyleBoxFlat = StyleBoxFlat.new()
		selected_style.bg_color = Color(0.25, 0.35, 0.45, 1)
		selected_style.border_width_left = 2
		selected_style.border_width_top = 2
		selected_style.border_width_right = 2
		selected_style.border_width_bottom = 2
		selected_style.border_color = Color(0.4, 0.6, 0.8, 1)
		selected_style.corner_radius_top_left = 4
		selected_style.corner_radius_top_right = 4
		selected_style.corner_radius_bottom_right = 4
		selected_style.corner_radius_bottom_left = 4
		selected_item.add_theme_stylebox_override("panel", selected_style)

## Updates pattern preview panel
func _update_pattern_preview(pattern: SexpPattern) -> void:
	pattern_name_label.text = pattern.pattern_name
	
	var info_text: String = "[b]Category:[/b] %s\n" % SexpPattern.PatternCategory.keys()[pattern.category].replace("_", " ").capitalize()
	info_text += "[b]Complexity:[/b] %s\n" % SexpPattern.ComplexityLevel.keys()[pattern.complexity].capitalize()
	info_text += "[b]Author:[/b] %s\n\n" % pattern.author
	info_text += "[b]Description:[/b]\n%s\n\n" % pattern.description
	
	if not pattern.usage_notes.is_empty():
		info_text += "[b]Usage Notes:[/b]\n%s\n\n" % pattern.usage_notes
	
	if pattern.required_functions.size() > 0:
		info_text += "[b]Required Functions:[/b]\n%s\n\n" % ", ".join(pattern.required_functions)
	
	if pattern.tags.size() > 0:
		info_text += "[b]Tags:[/b] %s\n\n" % ", ".join(pattern.tags)
	
	if not pattern.example_usage.is_empty():
		info_text += "[b]Example Usage:[/b]\n[i]%s[/i]\n" % pattern.example_usage
	
	pattern_info.text = info_text
	expression_editor.text = pattern.sexp_expression
	
	# Update current parameters with defaults
	current_parameters.clear()
	for param_name in pattern.parameter_placeholders.keys():
		var param_info: Dictionary = pattern.parameter_placeholders[param_name]
		current_parameters[param_name] = param_info.get("default", "")
	
	_update_expression_preview()

## Creates parameter control UI
func _create_parameter_controls(pattern: SexpPattern) -> void:
	# Clear existing controls
	for child in parameter_container.get_children():
		child.queue_free()
	parameter_controls.clear()
	
	# Create controls for each parameter
	var param_defs: Dictionary = pattern.get_parameter_definitions()
	for param_name in param_defs.keys():
		var param_def: Dictionary = param_defs[param_name]
		var control_group: VBoxContainer = _create_parameter_group(param_name, param_def)
		parameter_container.add_child(control_group)

## Creates a parameter control group
func _create_parameter_group(param_name: String, param_def: Dictionary) -> VBoxContainer:
	var group: VBoxContainer = VBoxContainer.new()
	group.add_theme_constant_override("separation", 2)
	
	# Parameter label
	var label: Label = Label.new()
	label.text = param_name.replace("_", " ").capitalize()
	if param_def.has("description"):
		label.tooltip_text = param_def.description
	label.add_theme_font_size_override("font_size", 10)
	group.add_child(label)
	
	# Parameter control
	var param_type: String = param_def.get("type", "string")
	var control: Control = _create_parameter_control(param_name, param_type, param_def)
	if control:
		group.add_child(control)
		parameter_controls[param_name] = control
	
	return group

## Creates appropriate control for parameter type
func _create_parameter_control(param_name: String, param_type: String, param_def: Dictionary) -> Control:
	var current_value = current_parameters.get(param_name, param_def.get("default"))
	
	match param_type:
		"string":
			if param_def.has("options"):
				var option_button: OptionButton = OptionButton.new()
				var options: Array = param_def.options
				for i in options.size():
					option_button.add_item(str(options[i]))
					if str(options[i]) == str(current_value):
						option_button.selected = i
				option_button.item_selected.connect(_on_parameter_changed.bind(param_name))
				return option_button
			else:
				var line_edit: LineEdit = LineEdit.new()
				line_edit.text = str(current_value)
				line_edit.text_changed.connect(_on_parameter_changed.bind(param_name))
				return line_edit
		
		"int":
			var spin_box: SpinBox = SpinBox.new()
			spin_box.value = int(current_value) if current_value is int else 0
			spin_box.min_value = param_def.get("min", 0)
			spin_box.max_value = param_def.get("max", 100)
			spin_box.step = 1
			spin_box.value_changed.connect(_on_parameter_changed.bind(param_name))
			return spin_box
		
		"float":
			var spin_box: SpinBox = SpinBox.new()
			spin_box.value = float(current_value) if (current_value is float or current_value is int) else 0.0
			spin_box.min_value = param_def.get("min", 0.0)
			spin_box.max_value = param_def.get("max", 100.0)
			spin_box.step = 0.1
			spin_box.value_changed.connect(_on_parameter_changed.bind(param_name))
			return spin_box
		
		"bool":
			var check_box: CheckBox = CheckBox.new()
			check_box.button_pressed = bool(current_value) if current_value is bool else false
			check_box.text = "Enabled"
			check_box.toggled.connect(_on_parameter_changed.bind(param_name))
			return check_box
		
		_:
			var line_edit: LineEdit = LineEdit.new()
			line_edit.text = str(current_value)
			line_edit.text_changed.connect(_on_parameter_changed.bind(param_name))
			return line_edit

## Updates expression preview with current parameters
func _update_expression_preview() -> void:
	if not selected_pattern:
		return
	
	var preview_expression: String = selected_pattern.apply_pattern(current_parameters)
	expression_editor.text = preview_expression

## Updates action button states
func _update_action_buttons(enabled: bool) -> void:
	validate_button.disabled = not enabled
	insert_button.disabled = not enabled
	copy_button.disabled = not enabled

## Signal Handlers

func _on_filter_changed(_index: int) -> void:
	_apply_filters()

func _on_search_changed(_text: String) -> void:
	_apply_filters()

func _on_parameter_changed(param_name: String, value = null) -> void:
	var control: Control = parameter_controls.get(param_name)
	if not control:
		return
	
	# Get value from control
	var new_value
	if control is LineEdit:
		new_value = control.text
	elif control is SpinBox:
		new_value = control.value
	elif control is CheckBox:
		new_value = control.button_pressed
	elif control is OptionButton:
		new_value = control.get_item_text(control.selected)
	else:
		new_value = value
	
	# Update parameter
	current_parameters[param_name] = new_value
	
	# Update preview
	_update_expression_preview()

func _on_validate_pressed() -> void:
	if not selected_pattern:
		return
	
	var validation_errors: Array[String] = selected_pattern.validate_pattern()
	var is_valid: bool = validation_errors.is_empty()
	
	if is_valid:
		# Also validate the applied expression
		var applied_expression: String = selected_pattern.apply_pattern(current_parameters)
		var syntax_valid: bool = SexpManager.validate_syntax(applied_expression)
		if not syntax_valid:
			validation_errors = SexpManager.get_validation_errors(applied_expression)
			is_valid = false
	
	# Update UI with validation results
	if is_valid:
		pattern_info.text += "\n[color=green][b]✓ Pattern validation passed![/b][/color]"
	else:
		pattern_info.text += "\n[color=red][b]✗ Validation errors:[/b][/color]\n"
		for error in validation_errors:
			pattern_info.text += "• %s\n" % error
	
	# Emit validation signal
	pattern_validated.emit(selected_pattern, is_valid, validation_errors)

func _on_insert_pressed() -> void:
	if selected_pattern:
		pattern_insert_requested.emit(selected_pattern, current_parameters)

func _on_copy_pressed() -> void:
	if selected_pattern:
		var applied_expression: String = selected_pattern.apply_pattern(current_parameters)
		DisplayServer.clipboard_set(applied_expression)
		
		# Show confirmation
		pattern_info.text += "\n[color=green][b]✓ Expression copied to clipboard![/b][/color]"

## Public API

## Gets the currently selected pattern
func get_selected_pattern() -> SexpPattern:
	return selected_pattern

## Gets current parameter values
func get_current_parameters() -> Dictionary:
	return current_parameters.duplicate()

## Sets parameter values programmatically
func set_parameters(parameters: Dictionary) -> void:
	current_parameters.merge(parameters)
	if selected_pattern:
		_update_expression_preview()
		# Update UI controls
		for param_name in parameters.keys():
			var control: Control = parameter_controls.get(param_name)
			if control:
				var value = parameters[param_name]
				if control is LineEdit:
					control.text = str(value)
				elif control is SpinBox:
					control.value = float(value) if (value is float or value is int) else 0.0
				elif control is CheckBox:
					control.button_pressed = bool(value) if value is bool else false
				elif control is OptionButton:
					for i in control.get_item_count():
						if control.get_item_text(i) == str(value):
							control.selected = i
							break

## Applies pattern with current parameters
func apply_current_pattern() -> String:
	if selected_pattern:
		return selected_pattern.apply_pattern(current_parameters)
	return ""