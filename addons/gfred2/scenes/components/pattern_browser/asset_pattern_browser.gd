@tool
class_name AssetPatternBrowser
extends VBoxContainer

## Asset pattern browser component for GFRED2 Template Library.
## Provides UI for browsing, filtering, and inserting asset patterns.

signal pattern_selected(pattern: AssetPattern)
signal pattern_insert_requested(pattern: AssetPattern, parameters: Dictionary)
signal pattern_preview_requested(pattern: AssetPattern, parameters: Dictionary)
signal pattern_validated(pattern: AssetPattern, is_valid: bool, errors: Array[String])

# Pattern library manager
var template_manager: TemplateLibraryManager

# UI component references
@onready var type_filter: OptionButton = $HeaderPanel/HeaderContent/TypeFilter
@onready var role_filter: OptionButton = $HeaderPanel/HeaderContent/RoleFilter
@onready var faction_filter: OptionButton = $HeaderPanel/HeaderContent/FactionFilter
@onready var refresh_button: Button = $HeaderPanel/HeaderContent/RefreshButton
@onready var search_box: LineEdit = $MainSplitter/LeftPanel/SearchPanel/SearchBox
@onready var pattern_container: VBoxContainer = $MainSplitter/LeftPanel/PatternList/PatternContainer
@onready var pattern_name_label: Label = $MainSplitter/RightPanel/PreviewPanel/PatternDetails/PatternName
@onready var pattern_info: RichTextLabel = $MainSplitter/RightPanel/PreviewPanel/PatternDetails/PatternInfo
@onready var loadout_details: RichTextLabel = $MainSplitter/RightPanel/PreviewPanel/LoadoutPanel/LoadoutDetails
@onready var parameter_container: VBoxContainer = $MainSplitter/RightPanel/ParameterPanel/ParameterScroll/ParameterContainer
@onready var validate_button: Button = $MainSplitter/RightPanel/ActionPanel/ValidateButton
@onready var insert_button: Button = $MainSplitter/RightPanel/ActionPanel/InsertButton
@onready var preview_button: Button = $MainSplitter/RightPanel/ActionPanel/PreviewButton

# Current state
var current_patterns: Array[AssetPattern] = []
var selected_pattern: AssetPattern = null
var parameter_controls: Dictionary = {}
var current_parameters: Dictionary = {}
var pattern_items: Array[Control] = []

func _ready() -> void:
	name = "AssetPatternBrowser"
	
	# Initialize template manager
	template_manager = TemplateLibraryManager.new()
	
	# Setup UI
	_setup_filter_options()
	_connect_signals()
	
	# Load patterns
	refresh_patterns()
	
	print("AssetPatternBrowser: Initialized with %d patterns" % template_manager.get_all_asset_patterns().size())

## Sets up filter option buttons
func _setup_filter_options() -> void:
	# Type filter
	type_filter.add_item("All Types", -1)
	for i in AssetPattern.PatternType.size():
		var type_name: String = AssetPattern.PatternType.keys()[i]
		type_filter.add_item(type_name.replace("_", " ").capitalize(), i)
	
	# Role filter
	role_filter.add_item("All Roles", -1)
	for i in AssetPattern.TacticalRole.size():
		var role_name: String = AssetPattern.TacticalRole.keys()[i]
		role_filter.add_item(role_name.replace("_", " ").capitalize(), i)
	
	# Faction filter
	faction_filter.add_item("All Factions", -1)
	for i in AssetPattern.Faction.size():
		var faction_name: String = AssetPattern.Faction.keys()[i]
		faction_filter.add_item(faction_name.capitalize(), i)

## Connects UI signals
func _connect_signals() -> void:
	# Filter signals
	type_filter.item_selected.connect(_on_filter_changed)
	role_filter.item_selected.connect(_on_filter_changed)
	faction_filter.item_selected.connect(_on_filter_changed)
	search_box.text_changed.connect(_on_search_changed)
	
	# Action button signals
	refresh_button.pressed.connect(refresh_patterns)
	validate_button.pressed.connect(_on_validate_pressed)
	insert_button.pressed.connect(_on_insert_pressed)
	preview_button.pressed.connect(_on_preview_pressed)

## Refreshes the pattern list from the library
func refresh_patterns() -> void:
	current_patterns = template_manager.get_all_asset_patterns()
	_apply_filters()

## Applies current filters to pattern list
func _apply_filters() -> void:
	var filtered_patterns: Array[AssetPattern] = []
	
	# Apply filters
	for pattern in current_patterns:
		if _pattern_matches_filters(pattern):
			filtered_patterns.append(pattern)
	
	# Sort patterns by name
	filtered_patterns.sort_custom(func(a, b): return a.pattern_name < b.pattern_name)
	
	# Update UI
	_populate_pattern_list(filtered_patterns)

## Checks if pattern matches current filters
func _pattern_matches_filters(pattern: AssetPattern) -> bool:
	# Type filter
	var type_id: int = type_filter.get_selected_id()
	if type_id >= 0 and pattern.pattern_type != type_id:
		return false
	
	# Role filter
	var role_id: int = role_filter.get_selected_id()
	if role_id >= 0 and pattern.tactical_role != role_id:
		return false
	
	# Faction filter
	var faction_id: int = faction_filter.get_selected_id()
	if faction_id >= 0 and pattern.faction != faction_id:
		return false
	
	# Search filter
	var search_text: String = search_box.text.to_lower()
	if not search_text.is_empty():
		var searchable_text: String = (
			pattern.pattern_name + " " + 
			pattern.description + " " + 
			pattern.ship_class + " " + 
			str(pattern.primary_weapons) + " " + 
			str(pattern.secondary_weapons) + " " + 
			str(pattern.tags)
		).to_lower()
		if not searchable_text.contains(search_text):
			return false
	
	return true

## Populates the pattern list UI
func _populate_pattern_list(patterns: Array[AssetPattern]) -> void:
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
func _create_pattern_item(pattern: AssetPattern) -> Control:
	var item: PanelContainer = PanelContainer.new()
	item.custom_minimum_size = Vector2(0, 80)
	
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
	var content: HBoxContainer = HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 8)
	item.add_child(content)
	
	# Icon placeholder (colored by type)
	var icon: ColorRect = ColorRect.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.color = _get_pattern_type_color(pattern.pattern_type)
	content.add_child(icon)
	
	# Pattern info
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(info)
	
	# Pattern name and ship class
	var name_label: Label = Label.new()
	name_label.text = pattern.pattern_name
	if not pattern.ship_class.is_empty():
		name_label.text += " (" + pattern.ship_class + ")"
	name_label.add_theme_font_size_override("font_size", 12)
	info.add_child(name_label)
	
	# Pattern details
	var details: HBoxContainer = HBoxContainer.new()
	info.add_child(details)
	
	var type_label: Label = Label.new()
	var type_name: String = AssetPattern.PatternType.keys()[pattern.pattern_type]
	type_label.text = type_name.replace("_", " ").capitalize()
	type_label.add_theme_color_override("font_color", _get_pattern_type_color(pattern.pattern_type))
	type_label.add_theme_font_size_override("font_size", 10)
	details.add_child(type_label)
	
	var separator1: Label = Label.new()
	separator1.text = " • "
	separator1.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 1))
	separator1.add_theme_font_size_override("font_size", 10)
	details.add_child(separator1)
	
	var role_label: Label = Label.new()
	var role_name: String = AssetPattern.TacticalRole.keys()[pattern.tactical_role]
	role_label.text = role_name.replace("_", " ").capitalize()
	role_label.add_theme_color_override("font_color", _get_tactical_role_color(pattern.tactical_role))
	role_label.add_theme_font_size_override("font_size", 10)
	details.add_child(role_label)
	
	var separator2: Label = Label.new()
	separator2.text = " • "
	separator2.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 1))
	separator2.add_theme_font_size_override("font_size", 10)
	details.add_child(separator2)
	
	var faction_label: Label = Label.new()
	var faction_name: String = AssetPattern.Faction.keys()[pattern.faction]
	faction_label.text = faction_name.capitalize()
	faction_label.add_theme_color_override("font_color", _get_faction_color(pattern.faction))
	faction_label.add_theme_font_size_override("font_size", 10)
	details.add_child(faction_label)
	
	# Pattern description
	var desc_label: Label = Label.new()
	desc_label.text = pattern.description
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.clip_contents = true
	info.add_child(desc_label)
	
	# Add click detection
	var button: Button = Button.new()
	button.flat = true
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(_on_pattern_item_selected.bind(pattern, item))
	item.add_child(button)
	
	return item

## Gets color for pattern type
func _get_pattern_type_color(pattern_type: AssetPattern.PatternType) -> Color:
	match pattern_type:
		AssetPattern.PatternType.SHIP_LOADOUT:
			return Color(0.3, 0.6, 0.3, 1)
		AssetPattern.PatternType.WING_FORMATION:
			return Color(0.3, 0.3, 0.6, 1)
		AssetPattern.PatternType.WEAPON_CONFIG:
			return Color(0.6, 0.3, 0.3, 1)
		AssetPattern.PatternType.FLEET_COMPOSITION:
			return Color(0.6, 0.6, 0.3, 1)
		AssetPattern.PatternType.SQUADRON_SETUP:
			return Color(0.4, 0.3, 0.6, 1)
		AssetPattern.PatternType.TACTICAL_GROUP:
			return Color(0.3, 0.6, 0.6, 1)
		AssetPattern.PatternType.DEFENSE_GRID:
			return Color(0.6, 0.4, 0.3, 1)
		AssetPattern.PatternType.SUPPORT_PACKAGE:
			return Color(0.5, 0.5, 0.5, 1)
		_:
			return Color(0.4, 0.4, 0.4, 1)

## Gets color for tactical role
func _get_tactical_role_color(role: AssetPattern.TacticalRole) -> Color:
	match role:
		AssetPattern.TacticalRole.FIGHTER:
			return Color(0.3, 0.8, 0.3, 1)
		AssetPattern.TacticalRole.BOMBER:
			return Color(0.8, 0.3, 0.3, 1)
		AssetPattern.TacticalRole.INTERCEPTOR:
			return Color(0.3, 0.3, 0.8, 1)
		AssetPattern.TacticalRole.ASSAULT:
			return Color(0.8, 0.8, 0.3, 1)
		AssetPattern.TacticalRole.SUPPORT:
			return Color(0.8, 0.3, 0.8, 1)
		AssetPattern.TacticalRole.RECONNAISSANCE:
			return Color(0.3, 0.8, 0.8, 1)
		AssetPattern.TacticalRole.ESCORT:
			return Color(0.6, 0.4, 0.8, 1)
		AssetPattern.TacticalRole.HEAVY_ASSAULT:
			return Color(0.8, 0.6, 0.3, 1)
		AssetPattern.TacticalRole.POINT_DEFENSE:
			return Color(0.4, 0.6, 0.8, 1)
		AssetPattern.TacticalRole.CAPITAL_SHIP:
			return Color(0.8, 0.8, 0.8, 1)
		_:
			return Color(0.6, 0.6, 0.6, 1)

## Gets color for faction
func _get_faction_color(faction: AssetPattern.Faction) -> Color:
	match faction:
		AssetPattern.Faction.TERRAN:
			return Color(0.3, 0.6, 1.0, 1)
		AssetPattern.Faction.VASUDAN:
			return Color(0.8, 0.6, 0.2, 1)
		AssetPattern.Faction.SHIVAN:
			return Color(0.8, 0.2, 0.2, 1)
		AssetPattern.Faction.PIRATE:
			return Color(0.6, 0.3, 0.6, 1)
		AssetPattern.Faction.CIVILIAN:
			return Color(0.5, 0.8, 0.5, 1)
		AssetPattern.Faction.UNKNOWN:
			return Color(0.6, 0.6, 0.6, 1)
		_:
			return Color(0.4, 0.4, 0.4, 1)

## Handles pattern item selection
func _on_pattern_item_selected(pattern: AssetPattern, item: Control) -> void:
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
func _update_pattern_preview(pattern: AssetPattern) -> void:
	pattern_name_label.text = pattern.pattern_name
	
	var info_text: String = "[b]Type:[/b] %s\n" % AssetPattern.PatternType.keys()[pattern.pattern_type].replace("_", " ").capitalize()
	info_text += "[b]Role:[/b] %s\n" % AssetPattern.TacticalRole.keys()[pattern.tactical_role].replace("_", " ").capitalize()
	info_text += "[b]Faction:[/b] %s\n" % AssetPattern.Faction.keys()[pattern.faction].capitalize()
	info_text += "[b]Author:[/b] %s\n\n" % pattern.author
	info_text += "[b]Description:[/b]\n%s\n\n" % pattern.description
	
	if not pattern.usage_notes.is_empty():
		info_text += "[b]Usage Notes:[/b]\n%s\n\n" % pattern.usage_notes
	
	if pattern.pattern_type == AssetPattern.PatternType.WING_FORMATION:
		info_text += "[b]Wing Size:[/b] %d ships\n" % pattern.wing_size
		info_text += "[b]Formation:[/b] %s\n" % pattern.formation_type.capitalize()
	
	if not pattern.ai_behavior.is_empty():
		info_text += "[b]AI Behavior:[/b] %s\n" % pattern.ai_behavior.replace("_", " ").capitalize()
	
	if pattern.tags.size() > 0:
		info_text += "\n[b]Tags:[/b] %s\n" % ", ".join(pattern.tags)
	
	pattern_info.text = info_text
	
	# Update loadout details
	_update_loadout_preview(pattern)
	
	# Initialize default parameters
	current_parameters.clear()
	current_parameters["ship_name"] = pattern.pattern_name + " Ship"
	current_parameters["team"] = 1

## Updates weapon loadout preview
func _update_loadout_preview(pattern: AssetPattern) -> void:
	var loadout_text: String = ""
	
	if not pattern.ship_class.is_empty():
		loadout_text += "[b]Ship Class:[/b] %s\n\n" % pattern.ship_class
	
	if pattern.primary_weapons.size() > 0:
		loadout_text += "[b]Primary Weapons:[/b]\n"
		for weapon in pattern.primary_weapons:
			loadout_text += "• %s\n" % weapon
		loadout_text += "\n"
	
	if pattern.secondary_weapons.size() > 0:
		loadout_text += "[b]Secondary Weapons:[/b]\n"
		for weapon in pattern.secondary_weapons:
			loadout_text += "• %s\n" % weapon
		loadout_text += "\n"
	
	if pattern.weapon_loadout.size() > 0:
		loadout_text += "[b]Weapon Banks:[/b]\n"
		for bank in pattern.weapon_loadout.keys():
			loadout_text += "• %s: %s\n" % [bank.capitalize(), pattern.weapon_loadout[bank]]
		loadout_text += "\n"
	
	if pattern.difficulty_modifier != 1.0:
		var difficulty_text: String
		if pattern.difficulty_modifier < 1.0:
			difficulty_text = "[color=green]Easier (%.1fx)[/color]" % pattern.difficulty_modifier
		else:
			difficulty_text = "[color=red]Harder (%.1fx)[/color]" % pattern.difficulty_modifier
		loadout_text += "[b]Difficulty Modifier:[/b] %s\n" % difficulty_text
	
	if loadout_text.is_empty():
		loadout_text = "[i]No loadout configuration specified[/i]"
	
	loadout_details.text = loadout_text

## Creates parameter control UI
func _create_parameter_controls(pattern: AssetPattern) -> void:
	# Clear existing controls
	for child in parameter_container.get_children():
		child.queue_free()
	parameter_controls.clear()
	
	# Basic placement parameters
	_add_parameter_control("Ship Name", "string", current_parameters.get("ship_name", pattern.pattern_name + " Ship"))
	_add_parameter_control("Team", "int", current_parameters.get("team", 1), {"min": 1, "max": 10})
	_add_parameter_control("Position X", "float", 0.0, {"min": -50000.0, "max": 50000.0})
	_add_parameter_control("Position Y", "float", 0.0, {"min": -50000.0, "max": 50000.0})
	_add_parameter_control("Position Z", "float", 0.0, {"min": -50000.0, "max": 50000.0})
	
	# Pattern-specific parameters
	match pattern.pattern_type:
		AssetPattern.PatternType.WING_FORMATION:
			_add_parameter_control("Wing Size", "int", pattern.wing_size, {"min": 1, "max": 12})
			_add_parameter_control("Formation", "string", pattern.formation_type, {"options": ["standard", "diamond", "vic", "finger-four", "wall"]})
		
		AssetPattern.PatternType.FLEET_COMPOSITION:
			_add_parameter_control("Fleet Scale", "float", 1.0, {"min": 0.5, "max": 3.0})
		
		AssetPattern.PatternType.DEFENSE_GRID:
			_add_parameter_control("Grid Size", "float", 5000.0, {"min": 1000.0, "max": 20000.0})
			_add_parameter_control("Gun Count", "int", 4, {"min": 2, "max": 12})

## Adds a parameter control to the UI
func _add_parameter_control(param_name: String, param_type: String, default_value, options: Dictionary = {}) -> void:
	var group: VBoxContainer = VBoxContainer.new()
	group.add_theme_constant_override("separation", 2)
	
	# Parameter label
	var label: Label = Label.new()
	label.text = param_name
	label.add_theme_font_size_override("font_size", 10)
	group.add_child(label)
	
	# Parameter control
	var control: Control = _create_parameter_control(param_name, param_type, default_value, options)
	if control:
		group.add_child(control)
		parameter_controls[param_name] = control
	
	parameter_container.add_child(group)

## Creates appropriate control for parameter type
func _create_parameter_control(param_name: String, param_type: String, default_value, options: Dictionary) -> Control:
	match param_type:
		"string":
			if options.has("options"):
				var option_button: OptionButton = OptionButton.new()
				var choices: Array = options.options
				for i in choices.size():
					option_button.add_item(str(choices[i]))
					if str(choices[i]) == str(default_value):
						option_button.selected = i
				option_button.item_selected.connect(_on_parameter_changed.bind(param_name))
				return option_button
			else:
				var line_edit: LineEdit = LineEdit.new()
				line_edit.text = str(default_value)
				line_edit.text_changed.connect(_on_parameter_changed.bind(param_name))
				return line_edit
		
		"int":
			var spin_box: SpinBox = SpinBox.new()
			spin_box.value = int(default_value) if default_value is int else 0
			spin_box.min_value = options.get("min", 0)
			spin_box.max_value = options.get("max", 100)
			spin_box.step = 1
			spin_box.value_changed.connect(_on_parameter_changed.bind(param_name))
			return spin_box
		
		"float":
			var spin_box: SpinBox = SpinBox.new()
			spin_box.value = float(default_value) if (default_value is float or default_value is int) else 0.0
			spin_box.min_value = options.get("min", 0.0)
			spin_box.max_value = options.get("max", 100.0)
			spin_box.step = 0.1
			spin_box.value_changed.connect(_on_parameter_changed.bind(param_name))
			return spin_box
		
		_:
			var line_edit: LineEdit = LineEdit.new()
			line_edit.text = str(default_value)
			line_edit.text_changed.connect(_on_parameter_changed.bind(param_name))
			return line_edit

## Updates action button states
func _update_action_buttons(enabled: bool) -> void:
	validate_button.disabled = not enabled
	insert_button.disabled = not enabled
	preview_button.disabled = not enabled

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
	elif control is OptionButton:
		new_value = control.get_item_text(control.selected)
	else:
		new_value = value
	
	# Update parameter
	current_parameters[param_name] = new_value

func _on_validate_pressed() -> void:
	if not selected_pattern:
		return
	
	var validation_errors: Array[String] = selected_pattern.validate_pattern()
	var is_valid: bool = validation_errors.is_empty()
	
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
		# Prepare insertion parameters
		var insertion_params: Dictionary = current_parameters.duplicate()
		
		# Convert position parameters to Vector3
		if current_parameters.has("Position X") and current_parameters.has("Position Y") and current_parameters.has("Position Z"):
			insertion_params["position"] = Vector3(
				current_parameters.get("Position X", 0.0),
				current_parameters.get("Position Y", 0.0),
				current_parameters.get("Position Z", 0.0)
			)
		
		pattern_insert_requested.emit(selected_pattern, insertion_params)

func _on_preview_pressed() -> void:
	if selected_pattern:
		var preview_params: Dictionary = current_parameters.duplicate()
		
		# Convert position parameters to Vector3
		if current_parameters.has("Position X") and current_parameters.has("Position Y") and current_parameters.has("Position Z"):
			preview_params["position"] = Vector3(
				current_parameters.get("Position X", 0.0),
				current_parameters.get("Position Y", 0.0),
				current_parameters.get("Position Z", 0.0)
			)
		
		pattern_preview_requested.emit(selected_pattern, preview_params)

## Public API

## Gets the currently selected pattern
func get_selected_pattern() -> AssetPattern:
	return selected_pattern

## Gets current parameter values
func get_current_parameters() -> Dictionary:
	return current_parameters.duplicate()

## Sets parameter values programmatically
func set_parameters(parameters: Dictionary) -> void:
	current_parameters.merge(parameters)
	
	# Update UI controls
	for param_name in parameters.keys():
		var control: Control = parameter_controls.get(param_name)
		if control:
			var value = parameters[param_name]
			if control is LineEdit:
				control.text = str(value)
			elif control is SpinBox:
				control.value = float(value) if (value is float or value is int) else 0.0
			elif control is OptionButton:
				for i in control.get_item_count():
					if control.get_item_text(i) == str(value):
						control.selected = i
						break