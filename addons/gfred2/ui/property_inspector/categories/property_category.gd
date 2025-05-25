class_name PropertyCategory
extends VBoxContainer

## Collapsible property category container for organizing properties in the inspector.
## Provides expand/collapse functionality and search filtering.

signal category_toggled(collapsed: bool)

var category_title: String = ""
var category_description: String = ""
var collapsed: bool = false
var properties_container: VBoxContainer
var header_button: Button
var properties_visible: int = 0  # For search filtering

@onready var header_container: HBoxContainer = $HeaderContainer
@onready var content_container: VBoxContainer = $ContentContainer

func _ready() -> void:
	name = "PropertyCategory"
	_setup_ui()

func _setup_ui() -> void:
	"""Initialize the category UI structure."""
	# Header container
	var header: HBoxContainer = HBoxContainer.new()
	header.name = "HeaderContainer"
	add_child(header)
	
	# Category toggle button
	var toggle_btn: Button = Button.new()
	toggle_btn.name = "ToggleButton"
	toggle_btn.flat = true
	toggle_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle_btn.text_alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(toggle_btn)
	
	# Help button
	var help_btn: Button = Button.new()
	help_btn.name = "HelpButton"
	help_btn.text = "?"
	help_btn.flat = true
	help_btn.custom_minimum_size = Vector2(24, 24)
	help_btn.tooltip_text = "Show category help"
	header.add_child(help_btn)
	
	# Content container
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "ContentContainer"
	add_child(content)
	
	# Properties container
	var props: VBoxContainer = VBoxContainer.new()
	props.name = "PropertiesContainer"
	content.add_child(props)
	
	# Update references
	header_container = header
	header_button = toggle_btn
	content_container = content
	properties_container = props
	
	# Connect signals
	header_button.pressed.connect(_on_header_pressed)
	help_btn.pressed.connect(_on_help_pressed)

func setup_category(title: String, description: String, icon_path: String = "") -> void:
	"""Initialize the category with title, description, and optional icon."""
	category_title = title
	category_description = description
	
	# Update header button
	header_button.text = title
	
	if not icon_path.is_empty() and FileAccess.file_exists(icon_path):
		var icon: Texture2D = load(icon_path)
		header_button.icon = icon
	
	_update_header_appearance()

func add_property_control(control: Control) -> void:
	"""Add a property control to this category."""
	properties_container.add_child(control)
	properties_visible += 1

func remove_property_control(control: Control) -> void:
	"""Remove a property control from this category."""
	if control.get_parent() == properties_container:
		properties_container.remove_child(control)
		properties_visible = max(0, properties_visible - 1)

func set_collapsed(new_collapsed: bool) -> void:
	"""Set the collapsed state of the category."""
	if collapsed != new_collapsed:
		collapsed = new_collapsed
		_update_header_appearance()
		_update_content_visibility()
		category_toggled.emit(collapsed)

func toggle_collapsed() -> void:
	"""Toggle the collapsed state."""
	set_collapsed(not collapsed)

func apply_search_filter(filter_text: String) -> bool:
	"""Apply search filter to properties and return if any are visible."""
	if filter_text.is_empty():
		_show_all_properties()
		return properties_container.get_child_count() > 0
	
	var visible_count: int = 0
	
	for child in properties_container.get_children():
		var should_show: bool = _property_matches_filter(child, filter_text)
		child.visible = should_show
		if should_show:
			visible_count += 1
	
	properties_visible = visible_count
	
	# Auto-expand category if it has matching properties
	if visible_count > 0 and collapsed:
		set_collapsed(false)
	
	return visible_count > 0

func _property_matches_filter(property_control: Control, filter_text: String) -> bool:
	"""Check if a property control matches the search filter."""
	# Check property name/label
	if property_control.has_method("get_property_name"):
		var prop_name: String = property_control.get_property_name().to_lower()
		if prop_name.contains(filter_text):
			return true
	
	# Check control text content
	for child in property_control.get_children():
		if child is Label:
			var label_text: String = child.text.to_lower()
			if label_text.contains(filter_text):
				return true
	
	# Check tooltip text
	if property_control.tooltip_text.to_lower().contains(filter_text):
		return true
	
	return false

func _show_all_properties() -> void:
	"""Show all properties (clear filter)."""
	for child in properties_container.get_children():
		child.visible = true
	
	properties_visible = properties_container.get_child_count()

func _update_header_appearance() -> void:
	"""Update the header button appearance based on state."""
	if collapsed:
		header_button.icon = _get_collapsed_icon()
		header_button.add_theme_color_override("font_color", Color.GRAY)
	else:
		header_button.icon = _get_expanded_icon()
		header_button.remove_theme_color_override("font_color")
	
	# Update text with property count if collapsed
	if collapsed and properties_visible > 0:
		header_button.text = "%s (%d)" % [category_title, properties_visible]
	else:
		header_button.text = category_title

func _update_content_visibility() -> void:
	"""Update the visibility of the content container."""
	content_container.visible = not collapsed

func _get_expanded_icon() -> Texture2D:
	"""Get the icon for expanded state."""
	# Try to load custom icon, fallback to built-in
	var icon_path: String = "res://addons/gfred2/icons/category_expanded.svg"
	if FileAccess.file_exists(icon_path):
		return load(icon_path)
	
	# Use Godot's built-in arrow icon
	return get_theme_icon("arrow", "Tree")

func _get_collapsed_icon() -> Texture2D:
	"""Get the icon for collapsed state."""
	# Try to load custom icon, fallback to built-in
	var icon_path: String = "res://addons/gfred2/icons/category_collapsed.svg"
	if FileAccess.file_exists(icon_path):
		return load(icon_path)
	
	# Use Godot's built-in arrow icon (rotated)
	return get_theme_icon("arrow_right", "Tree")

func _on_header_pressed() -> void:
	"""Handle header button press to toggle category."""
	toggle_collapsed()

func _on_help_pressed() -> void:
	"""Handle help button press to show category help."""
	_show_category_help()

func _show_category_help() -> void:
	"""Show help popup for this category."""
	var help_dialog: AcceptDialog = AcceptDialog.new()
	help_dialog.title = "Help: " + category_title
	help_dialog.size = Vector2i(450, 300)
	
	var scroll: ScrollContainer = ScrollContainer.new()
	help_dialog.add_child(scroll)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	scroll.add_child(vbox)
	
	var desc_label: RichTextLabel = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.text = "[b]" + category_title + "[/b]\n\n" + category_description
	desc_label.fit_content = true
	vbox.add_child(desc_label)
	
	# Add to scene tree temporarily
	get_tree().current_scene.add_child(help_dialog)
	
	# Center and show
	help_dialog.popup_centered(Vector2i(450, 300))
	
	# Remove when closed
	help_dialog.confirmed.connect(help_dialog.queue_free)
	help_dialog.close_requested.connect(help_dialog.queue_free)

func get_property_count() -> int:
	"""Get the total number of properties in this category."""
	return properties_container.get_child_count()

func get_visible_property_count() -> int:
	"""Get the number of currently visible properties."""
	return properties_visible

func has_properties() -> bool:
	"""Check if this category has any properties."""
	return properties_container.get_child_count() > 0

func clear_properties() -> void:
	"""Remove all properties from this category."""
	for child in properties_container.get_children():
		child.queue_free()
	
	properties_visible = 0

# Convenience methods for common category types

func create_transform_category() -> PropertyCategory:
	"""Create a pre-configured transform category."""
	var category: PropertyCategory = PropertyCategory.new()
	category.setup_category(
		"Transform", 
		"Position, rotation, and scale properties for the object in 3D space.",
		"res://addons/gfred2/icons/transform.svg"
	)
	return category

func create_visual_category() -> PropertyCategory:
	"""Create a pre-configured visual category."""
	var category: PropertyCategory = PropertyCategory.new()
	category.setup_category(
		"Visual", 
		"Visual appearance settings including model, textures, and visibility.",
		"res://addons/gfred2/icons/visual.svg"
	)
	return category

func create_behavior_category() -> PropertyCategory:
	"""Create a pre-configured behavior category."""
	var category: PropertyCategory = PropertyCategory.new()
	category.setup_category(
		"Behavior", 
		"AI behavior, orders, and gameplay configuration for this object.",
		"res://addons/gfred2/icons/behavior.svg"
	)
	return category

func create_mission_logic_category() -> PropertyCategory:
	"""Create a pre-configured mission logic category."""
	var category: PropertyCategory = PropertyCategory.new()
	category.setup_category(
		"Mission Logic", 
		"Mission goals, events, and SEXP expressions controlling object behavior.",
		"res://addons/gfred2/icons/mission_logic.svg"
	)
	return category

func create_advanced_category() -> PropertyCategory:
	"""Create a pre-configured advanced category."""
	var category: PropertyCategory = PropertyCategory.new()
	category.setup_category(
		"Advanced", 
		"Advanced properties and debug information for this object.",
		"res://addons/gfred2/icons/advanced.svg"
	)
	category.collapsed = true  # Start collapsed
	return category