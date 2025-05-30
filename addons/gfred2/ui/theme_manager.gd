@tool
class_name GFRED2ThemeManager
extends RefCounted

## Theme manager for GFRED2 that provides consistent Godot editor theming.
## Handles theme application, custom theme support, and editor integration.

signal theme_changed(new_theme: Theme)
signal high_contrast_changed(enabled: bool)

# Editor interface reference
var editor_interface: EditorInterface
var current_theme: Theme
var custom_themes: Dictionary = {}
var high_contrast_enabled: bool = false

# Theme constants
const THEME_COLORS = {
	"panel_bg": "dark_color_2",
	"button_normal": "dark_color_1", 
	"button_hover": "accent_color",
	"button_pressed": "accent_color",
	"text_normal": "font_color",
	"text_disabled": "font_color_disabled",
	"selection": "selection_color",
	"border": "contrast_color_1"
}

const HIGH_CONTRAST_COLORS = {
	"panel_bg": Color.BLACK,
	"button_normal": Color(0.2, 0.2, 0.2),
	"button_hover": Color.YELLOW,
	"button_pressed": Color.WHITE,
	"text_normal": Color.WHITE,
	"text_disabled": Color.GRAY,
	"selection": Color.CYAN,
	"border": Color.WHITE
}

func _init(editor_interface_ref: EditorInterface) -> void:
	editor_interface = editor_interface_ref
	current_theme = _create_gfred2_theme()

func get_current_theme() -> Theme:
	"""Get the current theme with applied customizations."""
	return current_theme

func apply_theme_to_control(control: Control) -> void:
	"""Apply the current theme to a control and its children."""
	if not control or not current_theme:
		return
	
	control.theme = current_theme
	
	# Recursively apply to children
	for child in control.get_children():
		if child is Control:
			apply_theme_to_control(child)

func create_themed_button(text: String, icon: Texture2D = null) -> Button:
	"""Create a button with proper theme and accessibility."""
	var button: Button = Button.new()
	button.text = text
	button.theme = current_theme
	
	if icon:
		button.icon = icon
	
	# Accessibility attributes
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = text
	
	return button

func create_themed_label(text: String, variant: String = "normal") -> Label:
	"""Create a label with proper theme styling."""
	var label: Label = Label.new()
	label.text = text
	label.theme = current_theme
	
	match variant:
		"heading":
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", _get_theme_color("accent_color"))
		"subheading":
			label.add_theme_font_size_override("font_size", 14)
		"caption":
			label.add_theme_font_size_override("font_size", 11)
			label.add_theme_color_override("font_color", _get_theme_color("font_color_disabled"))
		_:
			# Normal styling from theme
			pass
	
	return label

func create_themed_panel(panel_type: String = "normal") -> Panel:
	"""Create a panel with proper background styling."""
	var panel: Panel = Panel.new()
	panel.theme = current_theme
	
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	
	match panel_type:
		"dock":
			style_box.bg_color = _get_theme_color("dark_color_2")
			style_box.border_width_left = 1
			style_box.border_width_right = 1
			style_box.border_color = _get_theme_color("contrast_color_1")
		"dialog":
			style_box.bg_color = _get_theme_color("dark_color_1")
			style_box.corner_radius_top_left = 4
			style_box.corner_radius_top_right = 4
			style_box.corner_radius_bottom_left = 4
			style_box.corner_radius_bottom_right = 4
		"toolbar":
			style_box.bg_color = _get_theme_color("dark_color_2")
			style_box.border_width_bottom = 1
			style_box.border_color = _get_theme_color("contrast_color_1")
		_:
			style_box.bg_color = _get_theme_color("dark_color_2")
	
	panel.add_theme_stylebox_override("panel", style_box)
	return panel

func create_themed_line_edit(placeholder: String = "") -> LineEdit:
	"""Create a line edit with proper theme and accessibility."""
	var line_edit: LineEdit = LineEdit.new()
	line_edit.placeholder_text = placeholder
	line_edit.theme = current_theme
	line_edit.focus_mode = Control.FOCUS_ALL
	
	return line_edit

func create_themed_option_button() -> OptionButton:
	"""Create an option button with proper theme and accessibility."""
	var option_button: OptionButton = OptionButton.new()
	option_button.theme = current_theme
	option_button.focus_mode = Control.FOCUS_ALL
	
	return option_button

func create_themed_tree() -> Tree:
	"""Create a tree control with proper theme."""
	var tree: Tree = Tree.new()
	tree.theme = current_theme
	tree.focus_mode = Control.FOCUS_ALL
	tree.hide_root = true
	
	# Configure for accessibility
	tree.allow_rmb_select = true
	tree.select_mode = Tree.SELECT_SINGLE
	
	return tree

func enable_high_contrast_mode(enabled: bool) -> void:
	"""Enable or disable high contrast mode for accessibility."""
	if high_contrast_enabled == enabled:
		return
	
	high_contrast_enabled = enabled
	current_theme = _create_gfred2_theme()
	high_contrast_changed.emit(enabled)
	theme_changed.emit(current_theme)

func is_high_contrast_enabled() -> bool:
	"""Check if high contrast mode is enabled."""
	return high_contrast_enabled

func register_custom_theme(name: String, theme: Theme) -> void:
	"""Register a custom theme for user selection."""
	custom_themes[name] = theme

func get_available_themes() -> Array[String]:
	"""Get list of available theme names."""
	var themes: Array[String] = ["Default", "High Contrast"]
	themes.append_array(custom_themes.keys())
	return themes

func apply_custom_theme(theme_name: String) -> bool:
	"""Apply a custom theme by name."""
	if theme_name == "Default":
		high_contrast_enabled = false
		current_theme = _create_gfred2_theme()
		theme_changed.emit(current_theme)
		return true
	elif theme_name == "High Contrast":
		enable_high_contrast_mode(true)
		return true
	elif custom_themes.has(theme_name):
		current_theme = custom_themes[theme_name]
		high_contrast_enabled = false
		theme_changed.emit(current_theme)
		return true
	
	return false

func get_editor_icon(icon_name: String) -> Texture2D:
	"""Get an icon from Godot's editor icon set."""
	if not editor_interface:
		return null
	
	var base_control: Control = editor_interface.get_base_control()
	return base_control.get_theme_icon(icon_name, "EditorIcons")

func _create_gfred2_theme() -> Theme:
	"""Create the main GFRED2 theme based on Godot editor theme."""
	var theme: Theme = Theme.new()
	
	if not editor_interface:
		return theme
	
	var editor_theme: Theme = editor_interface.get_base_control().theme
	if not editor_theme:
		return theme
	
	# Copy base editor theme
	theme = editor_theme.duplicate()
	
	# Apply high contrast overrides if enabled
	if high_contrast_enabled:
		_apply_high_contrast_theme(theme)
	
	# Customize for GFRED2 specific needs
	_customize_gfred2_theme(theme)
	
	return theme

func _apply_high_contrast_theme(theme: Theme) -> void:
	"""Apply high contrast color overrides."""
	for control_type in ["Button", "Label", "LineEdit", "Panel", "Tree", "OptionButton"]:
		for color_name in HIGH_CONTRAST_COLORS:
			var color: Color = HIGH_CONTRAST_COLORS[color_name]
			
			match color_name:
				"panel_bg":
					if control_type in ["Panel", "Tree"]:
						var style_box: StyleBoxFlat = StyleBoxFlat.new()
						style_box.bg_color = color
						theme.set_stylebox("panel", control_type, style_box)
				"text_normal":
					if control_type in ["Button", "Label", "LineEdit", "Tree", "OptionButton"]:
						theme.set_color("font_color", control_type, color)
				"text_disabled":
					if control_type in ["Button", "Label", "LineEdit", "Tree", "OptionButton"]:
						theme.set_color("font_color_disabled", control_type, color)
				"selection":
					if control_type in ["Tree", "LineEdit"]:
						theme.set_color("selection_color", control_type, color)

func _customize_gfred2_theme(theme: Theme) -> void:
	"""Apply GFRED2-specific theme customizations."""
	# Mission editor specific styles
	var mission_panel_style: StyleBoxFlat = StyleBoxFlat.new()
	mission_panel_style.bg_color = _get_theme_color("dark_color_2")
	mission_panel_style.border_width_left = 2
	mission_panel_style.border_color = _get_theme_color("accent_color")
	theme.set_stylebox("mission_panel", "Panel", mission_panel_style)
	
	# Property editor styles
	var property_bg_style: StyleBoxFlat = StyleBoxFlat.new()
	property_bg_style.bg_color = _get_theme_color("dark_color_1")
	property_bg_style.corner_radius_top_left = 2
	property_bg_style.corner_radius_top_right = 2
	property_bg_style.corner_radius_bottom_left = 2
	property_bg_style.corner_radius_bottom_right = 2
	theme.set_stylebox("property_bg", "Panel", property_bg_style)
	
	# SEXP editor specific styles
	var sexp_node_style: StyleBoxFlat = StyleBoxFlat.new()
	sexp_node_style.bg_color = _get_theme_color("dark_color_3")
	sexp_node_style.border_width_left = 1
	sexp_node_style.border_width_right = 1
	sexp_node_style.border_width_top = 1
	sexp_node_style.border_width_bottom = 1
	sexp_node_style.border_color = _get_theme_color("contrast_color_2")
	sexp_node_style.corner_radius_top_left = 4
	sexp_node_style.corner_radius_top_right = 4
	sexp_node_style.corner_radius_bottom_left = 4
	sexp_node_style.corner_radius_bottom_right = 4
	theme.set_stylebox("sexp_node", "Panel", sexp_node_style)

func _get_theme_color(color_name: String) -> Color:
	"""Get a color from the current editor theme."""
	if high_contrast_enabled and HIGH_CONTRAST_COLORS.has(color_name):
		return HIGH_CONTRAST_COLORS[color_name]
	
	if not editor_interface:
		return Color.WHITE
	
	var base_control: Control = editor_interface.get_base_control()
	return base_control.get_theme_color(color_name, "Editor")

func save_theme_preferences() -> void:
	"""Save theme preferences using ConfigurationManager."""
	if not ConfigurationManager:
		return
	
	ConfigurationManager.set_user_preference("gfred2_high_contrast", high_contrast_enabled)
	ConfigurationManager.set_user_preference("gfred2_custom_theme", "")  # Could store custom theme name

func load_theme_preferences() -> void:
	"""Load theme preferences from ConfigurationManager."""
	if not ConfigurationManager:
		return
	
	var high_contrast: bool = ConfigurationManager.get_user_preference("gfred2_high_contrast", false)
	enable_high_contrast_mode(high_contrast)