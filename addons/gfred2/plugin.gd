@tool
extends EditorPlugin

const MainPanel = preload("res://addons/gfred2/editor_main.tscn")
const ThemeManager = preload("res://addons/gfred2/ui/theme_manager.gd")
const DockManager = preload("res://addons/gfred2/ui/dock_manager.gd")
const ShortcutManager = preload("res://addons/gfred2/ui/shortcut_manager.gd")
const ValidationIntegration = preload("res://addons/gfred2/validation/validation_integration.gd")

var main_panel_instance
var theme_manager: GFRED2ThemeManager
var dock_manager: GFRED2DockManager
var shortcut_manager: GFRED2ShortcutManager
var validation_integration: ValidationIntegration

func _enter_tree():
	# Initialize theme manager first
	theme_manager = ThemeManager.new(get_editor_interface())
	theme_manager.load_theme_preferences()
	
	# Initialize shortcut manager
	shortcut_manager = ShortcutManager.new()
	
	# Initialize validation integration
	validation_integration = ValidationIntegration.new()
	add_child(validation_integration)
	
	# Initialize dock manager
	dock_manager = DockManager.new(get_editor_interface(), theme_manager)
	_register_docks()
	dock_manager.load_layout()
	
	# Initialize plugin
	main_panel_instance = MainPanel.instantiate()
	
	# Apply managers to main panel
	if main_panel_instance.has_method("set_theme_manager"):
		main_panel_instance.set_theme_manager(theme_manager)
	if main_panel_instance.has_method("set_dock_manager"):
		main_panel_instance.set_dock_manager(dock_manager)
	if main_panel_instance.has_method("set_shortcut_manager"):
		main_panel_instance.set_shortcut_manager(shortcut_manager)
	if main_panel_instance.has_method("set_validation_integration"):
		main_panel_instance.set_validation_integration(validation_integration)
	
	# Add the main editor UI to the editor viewport
	get_editor_interface().get_editor_main_screen().add_child(main_panel_instance)
	
	# Hide the panel when plugin starts
	_make_visible(false)

func _exit_tree():
	if shortcut_manager:
		shortcut_manager.save_shortcuts()
	if dock_manager:
		dock_manager.save_layout()
	if theme_manager:
		theme_manager.save_theme_preferences()
	if main_panel_instance:
		main_panel_instance.queue_free()

func _register_docks() -> void:
	"""Register all available docks with the dock manager."""
	# Note: Using placeholder scene paths - these would need to be created as .tscn files
	dock_manager.register_dock("object_inspector", "res://addons/gfred2/ui/docks/object_inspector_dock.gd", "Object Inspector", GFRED2DockManager.DockSlot.RIGHT_UL)
	dock_manager.register_dock("asset_browser", "res://addons/gfred2/ui/docks/asset_browser_dock.gd", "Asset Browser", GFRED2DockManager.DockSlot.LEFT_UL)
	dock_manager.register_dock("sexp_editor", "res://addons/gfred2/ui/docks/sexp_editor_dock.gd", "SEXP Editor", GFRED2DockManager.DockSlot.LEFT_BL)
	dock_manager.register_dock("validation_panel", "res://addons/gfred2/ui/docks/validation_dock.gd", "Validation", GFRED2DockManager.DockSlot.RIGHT_BL)
	
	# Integrate validation dock with validation system
	if validation_integration and validation_integration.is_validation_system_ready():
		var validation_dock: ValidationDock = validation_integration.get_validation_dock()
		if validation_dock:
			dock_manager.add_dock_instance("validation_panel", validation_dock)

func _has_main_screen():
	return true

func _make_visible(visible):
	if main_panel_instance:
		main_panel_instance.visible = visible

func _get_plugin_name():
	return "Mission Editor"

func _get_plugin_icon():
	# Return editor icon from Godot's built-in icons
	return get_editor_interface().get_base_control().get_theme_icon("Node3D", "EditorIcons")
