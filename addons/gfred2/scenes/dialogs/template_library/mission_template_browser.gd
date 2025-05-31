@tool
class_name MissionTemplateBrowser
extends VBoxContainer

## Mission template browser scene controller for GFRED2 Template Library.
## Provides UI for browsing, filtering, and selecting mission templates.

signal template_selected(template: MissionTemplate)
signal template_use_requested(template: MissionTemplate, parameters: Dictionary)
signal template_customize_requested(template: MissionTemplate)

# Template library manager
var template_manager: TemplateLibraryManager

# UI component references
@onready var category_option: OptionButton = $MainSplitter/LeftPanel/FilterPanel/CategoryFilter/CategoryOption
@onready var type_option: OptionButton = $MainSplitter/LeftPanel/FilterPanel/TypeFilter/TypeOption
@onready var difficulty_option: OptionButton = $MainSplitter/LeftPanel/FilterPanel/DifficultyFilter/DifficultyOption
@onready var search_box: LineEdit = $MainSplitter/LeftPanel/SearchPanel/SearchBox
@onready var tag_container: FlowContainer = $MainSplitter/LeftPanel/TagsPanel/TagContainer
@onready var results_label: Label = $MainSplitter/RightPanel/TemplateListPanel/ListHeader/ResultsLabel
@onready var sort_option: OptionButton = $MainSplitter/RightPanel/TemplateListPanel/ListHeader/SortOption
@onready var template_container: VBoxContainer = $MainSplitter/RightPanel/TemplateListPanel/TemplateList/TemplateContainer
@onready var template_name_label: Label = $MainSplitter/RightPanel/PreviewPanel/PreviewContent/PreviewDetails/TemplateName
@onready var template_description: RichTextLabel = $MainSplitter/RightPanel/PreviewPanel/PreviewContent/PreviewDetails/TemplateDescription
@onready var use_template_button: Button = $MainSplitter/RightPanel/PreviewPanel/PreviewContent/PreviewActions/UseTemplateButton
@onready var customize_button: Button = $MainSplitter/RightPanel/PreviewPanel/PreviewContent/PreviewActions/CustomizeButton
@onready var export_button: Button = $MainSplitter/RightPanel/PreviewPanel/PreviewContent/PreviewActions/ExportButton
@onready var edit_button: Button = $MainSplitter/RightPanel/PreviewPanel/PreviewContent/PreviewActions/EditButton
@onready var delete_button: Button = $MainSplitter/RightPanel/PreviewPanel/PreviewContent/PreviewActions/DeleteButton
@onready var refresh_button: Button = $HeaderPanel/HeaderContent/RefreshButton
@onready var import_button: Button = $HeaderPanel/HeaderContent/ImportButton
@onready var create_button: Button = $HeaderPanel/HeaderContent/CreateButton
@onready var import_dialog: FileDialog = $ImportFileDialog
@onready var export_dialog: FileDialog = $ExportFileDialog

# Current state
var current_templates: Array[MissionTemplate] = []
var selected_template: MissionTemplate = null
var filter_state: Dictionary = {}

# Template item controls for selection management
var template_items: Array[Control] = []

func _ready() -> void:
	name = "MissionTemplateBrowser"
	
	# Initialize template manager
	template_manager = TemplateLibraryManager.new()
	
	# Setup UI
	_setup_filter_options()
	_setup_sort_options()
	_connect_signals()
	
	# Load templates
	refresh_templates()
	
	print("MissionTemplateBrowser: Initialized with %d templates" % template_manager.get_all_mission_templates().size())

## Sets up filter option buttons
func _setup_filter_options() -> void:
	# Category filter
	category_option.add_item("All Categories", -1)
	var categories: PackedStringArray = ["Combat", "Defense", "Reconnaissance", "Training", "General"]
	for i in categories.size():
		category_option.add_item(categories[i], i)
	
	# Type filter
	type_option.add_item("All Types", -1)
	for i in MissionTemplate.TemplateType.size():
		var type_name: String = MissionTemplate.TemplateType.keys()[i]
		type_option.add_item(type_name.replace("_", " ").capitalize(), i)
	
	# Difficulty filter
	difficulty_option.add_item("All Difficulties", -1)
	for i in MissionTemplate.Difficulty.size():
		var diff_name: String = MissionTemplate.Difficulty.keys()[i]
		difficulty_option.add_item(diff_name.replace("_", " ").capitalize(), i)

## Sets up sort option button
func _setup_sort_options() -> void:
	sort_option.add_item("Name (A-Z)", 0)
	sort_option.add_item("Name (Z-A)", 1)
	sort_option.add_item("Type", 2)
	sort_option.add_item("Difficulty", 3)
	sort_option.add_item("Duration", 4)
	sort_option.add_item("Created Date", 5)

## Connects UI signals
func _connect_signals() -> void:
	# Filter signals
	category_option.item_selected.connect(_on_filter_changed)
	type_option.item_selected.connect(_on_filter_changed)
	difficulty_option.item_selected.connect(_on_filter_changed)
	search_box.text_changed.connect(_on_search_changed)
	sort_option.item_selected.connect(_on_sort_changed)
	
	# Action button signals
	refresh_button.pressed.connect(refresh_templates)
	import_button.pressed.connect(_on_import_pressed)
	create_button.pressed.connect(_on_create_pressed)
	use_template_button.pressed.connect(_on_use_template_pressed)
	customize_button.pressed.connect(_on_customize_pressed)
	export_button.pressed.connect(_on_export_pressed)
	edit_button.pressed.connect(_on_edit_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	
	# Dialog signals
	import_dialog.file_selected.connect(_on_import_file_selected)
	export_dialog.file_selected.connect(_on_export_file_selected)

## Refreshes the template list from the library
func refresh_templates() -> void:
	current_templates = template_manager.get_all_mission_templates()
	_apply_filters_and_sort()
	_update_popular_tags()

## Applies current filters and sorting to template list
func _apply_filters_and_sort() -> void:
	var filtered_templates: Array[MissionTemplate] = []
	
	# Apply filters
	for template in current_templates:
		if _template_matches_filters(template):
			filtered_templates.append(template)
	
	# Apply sorting
	_sort_templates(filtered_templates)
	
	# Update UI
	_populate_template_list(filtered_templates)
	results_label.text = "Templates (%d)" % filtered_templates.size()

## Checks if template matches current filters
func _template_matches_filters(template: MissionTemplate) -> bool:
	# Category filter
	var category_id: int = category_option.get_selected_id()
	if category_id >= 0:
		var category_name: String = category_option.get_item_text(category_option.selected)
		if template.category != category_name:
			return false
	
	# Type filter
	var type_id: int = type_option.get_selected_id()
	if type_id >= 0 and template.template_type != type_id:
		return false
	
	# Difficulty filter
	var diff_id: int = difficulty_option.get_selected_id()
	if diff_id >= 0 and template.difficulty != diff_id:
		return false
	
	# Search filter
	var search_text: String = search_box.text.to_lower()
	if not search_text.is_empty():
		var searchable_text: String = (template.template_name + " " + template.description + " " + str(template.tags)).to_lower()
		if not searchable_text.contains(search_text):
			return false
	
	return true

## Sorts templates based on current sort option
func _sort_templates(templates: Array[MissionTemplate]) -> void:
	var sort_id: int = sort_option.selected
	
	match sort_id:
		0: # Name A-Z
			templates.sort_custom(func(a, b): return a.template_name < b.template_name)
		1: # Name Z-A
			templates.sort_custom(func(a, b): return a.template_name > b.template_name)
		2: # Type
			templates.sort_custom(func(a, b): return a.template_type < b.template_type)
		3: # Difficulty
			templates.sort_custom(func(a, b): return a.difficulty < b.difficulty)
		4: # Duration
			templates.sort_custom(func(a, b): return a.estimated_duration_minutes < b.estimated_duration_minutes)
		5: # Created Date
			templates.sort_custom(func(a, b): return a.created_date > b.created_date)

## Populates the template list UI
func _populate_template_list(templates: Array[MissionTemplate]) -> void:
	# Clear existing items
	for item in template_items:
		item.queue_free()
	template_items.clear()
	
	# Create new items
	for template in templates:
		var item: Control = _create_template_item(template)
		template_container.add_child(item)
		template_items.append(item)

## Creates a template list item
func _create_template_item(template: MissionTemplate) -> Control:
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
	
	# Icon placeholder
	var icon: ColorRect = ColorRect.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.color = _get_template_type_color(template.template_type)
	content.add_child(icon)
	
	# Template info
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(info)
	
	# Template name
	var name_label: Label = Label.new()
	name_label.text = template.template_name
	name_label.add_theme_font_size_override("font_size", 14)
	info.add_child(name_label)
	
	# Template details
	var details: HBoxContainer = HBoxContainer.new()
	info.add_child(details)
	
	var type_label: Label = Label.new()
	var type_name: String = MissionTemplate.TemplateType.keys()[template.template_type]
	type_label.text = type_name.replace("_", " ").capitalize()
	type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1))
	details.add_child(type_label)
	
	var separator1: Label = Label.new()
	separator1.text = " • "
	separator1.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 1))
	details.add_child(separator1)
	
	var difficulty_label: Label = Label.new()
	var diff_name: String = MissionTemplate.Difficulty.keys()[template.difficulty]
	difficulty_label.text = diff_name.replace("_", " ").capitalize()
	difficulty_label.add_theme_color_override("font_color", _get_difficulty_color(template.difficulty))
	details.add_child(difficulty_label)
	
	var separator2: Label = Label.new()
	separator2.text = " • "
	separator2.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 1))
	details.add_child(separator2)
	
	var duration_label: Label = Label.new()
	duration_label.text = str(template.estimated_duration_minutes) + " min"
	duration_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1))
	details.add_child(duration_label)
	
	# Template description
	var desc_label: Label = Label.new()
	desc_label.text = template.description
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.clip_contents = true
	info.add_child(desc_label)
	
	# Add click detection
	var button: Button = Button.new()
	button.flat = true
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(_on_template_item_selected.bind(template, item))
	item.add_child(button)
	
	return item

## Gets color for template type
func _get_template_type_color(template_type: MissionTemplate.TemplateType) -> Color:
	match template_type:
		MissionTemplate.TemplateType.ESCORT:
			return Color(0.3, 0.6, 0.3, 1)
		MissionTemplate.TemplateType.PATROL:
			return Color(0.3, 0.3, 0.6, 1)
		MissionTemplate.TemplateType.ASSAULT:
			return Color(0.6, 0.3, 0.3, 1)
		MissionTemplate.TemplateType.DEFENSE:
			return Color(0.6, 0.6, 0.3, 1)
		MissionTemplate.TemplateType.STEALTH:
			return Color(0.4, 0.3, 0.6, 1)
		MissionTemplate.TemplateType.RESCUE:
			return Color(0.3, 0.6, 0.6, 1)
		MissionTemplate.TemplateType.TRAINING:
			return Color(0.5, 0.5, 0.5, 1)
		_:
			return Color(0.4, 0.4, 0.4, 1)

## Gets color for difficulty level
func _get_difficulty_color(difficulty: MissionTemplate.Difficulty) -> Color:
	match difficulty:
		MissionTemplate.Difficulty.EASY:
			return Color(0.3, 0.8, 0.3, 1)
		MissionTemplate.Difficulty.MEDIUM:
			return Color(0.8, 0.8, 0.3, 1)
		MissionTemplate.Difficulty.HARD:
			return Color(0.8, 0.5, 0.3, 1)
		MissionTemplate.Difficulty.VERY_HARD:
			return Color(0.8, 0.3, 0.3, 1)
		MissionTemplate.Difficulty.INSANE:
			return Color(0.6, 0.2, 0.8, 1)
		_:
			return Color(0.6, 0.6, 0.6, 1)

## Updates popular tags display
func _update_popular_tags() -> void:
	# Clear existing tags
	for child in tag_container.get_children():
		child.queue_free()
	
	# Count tag usage
	var tag_counts: Dictionary = {}
	for template in current_templates:
		for tag in template.tags:
			tag_counts[tag] = tag_counts.get(tag, 0) + 1
	
	# Sort by usage count
	var sorted_tags: Array = tag_counts.keys()
	sorted_tags.sort_custom(func(a, b): return tag_counts[a] > tag_counts[b])
	
	# Create tag buttons (limit to top 10)
	for i in min(10, sorted_tags.size()):
		var tag: String = sorted_tags[i]
		var count: int = tag_counts[tag]
		
		var tag_button: Button = Button.new()
		tag_button.text = "%s (%d)" % [tag, count]
		tag_button.flat = true
		tag_button.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1))
		tag_button.pressed.connect(_on_tag_selected.bind(tag))
		tag_container.add_child(tag_button)

## Handles template item selection
func _on_template_item_selected(template: MissionTemplate, item: Control) -> void:
	# Update selection visuals
	_update_selection_visual(item)
	
	# Store selected template
	selected_template = template
	
	# Update preview
	_update_template_preview(template)
	
	# Enable action buttons
	_update_action_buttons(true)
	
	# Emit signal
	template_selected.emit(template)

## Updates selection visual styling
func _update_selection_visual(selected_item: Control) -> void:
	# Reset all items to normal style
	for item in template_items:
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

## Updates template preview panel
func _update_template_preview(template: MissionTemplate) -> void:
	template_name_label.text = template.template_name
	
	var preview_text: String = "[b]Type:[/b] %s\n" % MissionTemplate.TemplateType.keys()[template.template_type].replace("_", " ").capitalize()
	preview_text += "[b]Category:[/b] %s\n" % template.category
	preview_text += "[b]Difficulty:[/b] %s\n" % MissionTemplate.Difficulty.keys()[template.difficulty].replace("_", " ").capitalize()
	preview_text += "[b]Duration:[/b] %d minutes\n" % template.estimated_duration_minutes
	preview_text += "[b]Author:[/b] %s\n\n" % template.author
	preview_text += "[b]Description:[/b]\n%s\n\n" % template.description
	
	if template.tags.size() > 0:
		preview_text += "[b]Tags:[/b] %s\n\n" % ", ".join(template.tags)
	
	if template.parameters.size() > 0:
		preview_text += "[b]Customizable Parameters:[/b]\n"
		for param in template.parameters.keys():
			preview_text += "• %s\n" % param.replace("_", " ").capitalize()
	
	template_description.text = preview_text

## Updates action button states
func _update_action_buttons(enabled: bool) -> void:
	use_template_button.disabled = not enabled
	customize_button.disabled = not enabled
	export_button.disabled = not enabled
	edit_button.disabled = not enabled
	delete_button.disabled = not enabled

## Signal Handlers

func _on_filter_changed(_index: int) -> void:
	_apply_filters_and_sort()

func _on_search_changed(_text: String) -> void:
	_apply_filters_and_sort()

func _on_sort_changed(_index: int) -> void:
	_apply_filters_and_sort()

func _on_tag_selected(tag: String) -> void:
	search_box.text = tag
	_apply_filters_and_sort()

func _on_import_pressed() -> void:
	import_dialog.popup_centered(Vector2i(600, 400))

func _on_create_pressed() -> void:
	# TODO: Open template creation dialog
	print("Create new template - TODO: Implement template creation dialog")

func _on_use_template_pressed() -> void:
	if selected_template:
		template_use_requested.emit(selected_template, {})

func _on_customize_pressed() -> void:
	if selected_template:
		template_customize_requested.emit(selected_template)

func _on_export_pressed() -> void:
	if selected_template:
		export_dialog.current_file = selected_template.template_name + ".json"
		export_dialog.popup_centered(Vector2i(600, 400))

func _on_edit_pressed() -> void:
	# TODO: Open template editor
	print("Edit template - TODO: Implement template editor")

func _on_delete_pressed() -> void:
	if selected_template:
		# TODO: Add confirmation dialog
		template_manager.remove_mission_template(selected_template.template_id)
		refresh_templates()
		selected_template = null
		_update_action_buttons(false)
		template_name_label.text = "Select a template to preview"
		template_description.text = "[i]Template details will appear here[/i]"

func _on_import_file_selected(path: String) -> void:
	var imported_template: MissionTemplate = template_manager.import_template_from_community(path)
	if imported_template:
		print("Successfully imported template: " + imported_template.template_name)
		refresh_templates()
	else:
		print("Failed to import template from: " + path)

func _on_export_file_selected(path: String) -> void:
	if selected_template:
		var result: Error = template_manager.export_template_for_community(selected_template.template_id, path)
		if result == OK:
			print("Successfully exported template to: " + path)
		else:
			print("Failed to export template: " + error_string(result))

## Public API

## Gets the currently selected template
func get_selected_template() -> MissionTemplate:
	return selected_template

## Sets the selected template programmatically
func set_selected_template(template: MissionTemplate) -> void:
	if template and current_templates.has(template):
		# Find and select the template item
		for i in template_items.size():
			var item: Control = template_items[i]
			# Check if this item represents the target template
			# This is a simplified check - in a full implementation you'd store template references
			_on_template_item_selected(template, item)
			break

## Applies a search filter
func apply_search_filter(search_text: String) -> void:
	search_box.text = search_text
	_apply_filters_and_sort()

## Gets template statistics
func get_template_statistics() -> Dictionary:
	return template_manager.get_library_statistics()