@tool
extends EditorPlugin

## GFRED2 Mission Editor Plugin for Godot Engine.
## Provides scene-based mission editing with WCS Asset Core integration.

# Scene-based resource loading
const MainPanel = preload("res://addons/gfred2/editor_main.tscn")
const MainEditorDock = preload("res://addons/gfred2/scenes/docks/main_editor_dock.tscn")
const AssetBrowserDock = preload("res://addons/gfred2/scenes/docks/asset_browser_dock.tscn")
const SexpEditorDock = preload("res://addons/gfred2/scenes/docks/sexp_editor_dock.tscn")
const ObjectInspectorDock = preload("res://addons/gfred2/scenes/docks/object_inspector_dock.tscn")
const ValidationDock = preload("res://addons/gfred2/scenes/docks/validation_dock.tscn")
const SceneDialogManager = preload("res://addons/gfred2/scenes/managers/scene_dialog_manager.tscn")

# Manager script loading
const ThemeManager = preload("res://addons/gfred2/ui/theme_manager.gd")
const ShortcutManager = preload("res://addons/gfred2/ui/shortcut_manager.gd")
const ValidationIntegration = preload("res://addons/gfred2/validation/validation_integration.gd")

# Plugin instances
var main_panel_instance: Control
var scene_dialog_manager: SceneDialogManagerController
var theme_manager: GFRED2ThemeManager
var shortcut_manager: GFRED2ShortcutManager
var validation_integration: ValidationIntegration

# Dock instances
var dock_instances: Dictionary = {}

func _enter_tree():
	print("GFRED2: Initializing mission editor plugin...")
	
	# Initialize core managers
	_initialize_managers()
	
	# Initialize dialog manager
	_initialize_dialog_manager()
	
	# Initialize main panel
	_initialize_main_panel()
	
	# Register docks
	_register_docks()
	
	# Hide panel initially
	_make_visible(false)
	
	print("GFRED2: Mission editor plugin initialization completed")

func _exit_tree():
	print("GFRED2: Cleaning up mission editor plugin...")
	
	# Save manager settings
	if shortcut_manager:
		shortcut_manager.save_shortcuts()
	if theme_manager:
		theme_manager.save_theme_preferences()
	
	# Clean up dock instances
	_cleanup_dock_instances()
	
	# Clean up main panel
	if main_panel_instance:
		main_panel_instance.queue_free()
		main_panel_instance = null
	
	# Clean up dialog manager
	if scene_dialog_manager:
		scene_dialog_manager.close_all_dialogs()
		scene_dialog_manager.queue_free()
		scene_dialog_manager = null

func _initialize_managers() -> void:
	# Initialize theme manager
	theme_manager = ThemeManager.new()
	if theme_manager.has_method("initialize_with_editor_interface"):
		theme_manager.initialize_with_editor_interface(get_editor_interface())
	theme_manager.load_theme_preferences()
	
	# Initialize shortcut manager
	shortcut_manager = ShortcutManager.new()
	
	# Initialize validation integration
	validation_integration = ValidationIntegration.new()
	add_child(validation_integration)

func _initialize_dialog_manager() -> void:
	# Instantiate dialog manager
	scene_dialog_manager = SceneDialogManager.instantiate() as SceneDialogManagerController
	if scene_dialog_manager:
		add_child(scene_dialog_manager)
		print("GFRED2: Dialog manager initialized")
	else:
		push_error("GFRED2: Failed to instantiate dialog manager")

func _initialize_main_panel() -> void:
	# Instantiate main panel scene
	main_panel_instance = MainPanel.instantiate()
	
	if not main_panel_instance:
		push_error("GFRED2: Failed to instantiate main panel scene")
		return
	
	# Connect managers to main panel
	if main_panel_instance.has_method("set_theme_manager"):
		main_panel_instance.set_theme_manager(theme_manager)
	
	if main_panel_instance.has_method("set_shortcut_manager"):
		main_panel_instance.set_shortcut_manager(shortcut_manager)
	
	if main_panel_instance.has_method("set_validation_integration"):
		main_panel_instance.set_validation_integration(validation_integration)
	
	if main_panel_instance.has_method("set_dialog_manager"):
		main_panel_instance.set_dialog_manager(scene_dialog_manager)
	
	# Add to editor
	get_editor_interface().get_editor_main_screen().add_child(main_panel_instance)
	print("GFRED2: Main panel scene initialized and added to editor")

func _register_docks() -> void:
	"""Register all docks with the Godot editor."""
	print("GFRED2: Registering docks...")
	
	# Create and register main editor dock
	var main_editor_dock: MainEditorDockController = MainEditorDock.instantiate() as MainEditorDockController
	if main_editor_dock:
		dock_instances["main_editor"] = main_editor_dock
		add_control_to_dock(DOCK_SLOT_LEFT_UL, main_editor_dock)
		print("GFRED2: Main editor dock registered")
	
	# Create and register asset browser dock
	var asset_browser_dock: AssetBrowserDockController = AssetBrowserDock.instantiate() as AssetBrowserDockController
	if asset_browser_dock:
		dock_instances["asset_browser"] = asset_browser_dock
		add_control_to_dock(DOCK_SLOT_LEFT_UR, asset_browser_dock)
		print("GFRED2: Asset browser dock registered")
	
	# Create and register SEXP editor dock
	var sexp_editor_dock: SexpEditorDockController = SexpEditorDock.instantiate() as SexpEditorDockController
	if sexp_editor_dock:
		dock_instances["sexp_editor"] = sexp_editor_dock
		add_control_to_dock(DOCK_SLOT_LEFT_BL, sexp_editor_dock)
		print("GFRED2: SEXP editor dock registered")
	
	# Create and register object inspector dock
	var object_inspector_dock: ObjectInspectorDockController = ObjectInspectorDock.instantiate() as ObjectInspectorDockController
	if object_inspector_dock:
		dock_instances["object_inspector"] = object_inspector_dock
		add_control_to_dock(DOCK_SLOT_RIGHT_UL, object_inspector_dock)
		print("GFRED2: Object inspector dock registered")
	
	# Create and register validation dock (if available)
	if ValidationDock:
		var validation_dock_instance = ValidationDock.instantiate()
		if validation_dock_instance:
			dock_instances["validation"] = validation_dock_instance
			add_control_to_dock(DOCK_SLOT_RIGHT_BL, validation_dock_instance)
			print("GFRED2: Validation dock registered")
	
	# Connect dock signals for inter-dock communication
	_connect_dock_signals()

func _connect_dock_signals() -> void:
	"""Connect signals between docks for coordinated functionality."""
	var main_dock: MainEditorDockController = dock_instances.get("main_editor") as MainEditorDockController
	var asset_dock: AssetBrowserDockController = dock_instances.get("asset_browser") as AssetBrowserDockController
	var sexp_dock: SexpEditorDockController = dock_instances.get("sexp_editor") as SexpEditorDockController
	var inspector_dock: ObjectInspectorDockController = dock_instances.get("object_inspector") as ObjectInspectorDockController
	
	if main_dock and inspector_dock:
		# Connect object selection between main editor and inspector
		main_dock.object_selected.connect(inspector_dock.inspect_object)
		inspector_dock.property_changed.connect(_on_object_property_changed)
		print("GFRED2: Connected main editor and object inspector")
	
	if asset_dock and main_dock:
		# Connect asset selection for adding to mission
		asset_dock.asset_double_clicked.connect(_on_asset_add_to_mission)
		print("GFRED2: Connected asset browser to main editor")
	
	if sexp_dock and main_dock:
		# Connect SEXP editor for mission event editing
		sexp_dock.expression_changed.connect(_on_sexp_expression_changed)
		print("GFRED2: Connected SEXP editor to main editor")

func _cleanup_dock_instances() -> void:
	"""Clean up all dock instances."""
	for dock_name in dock_instances:
		var dock_instance: Control = dock_instances[dock_name]
		if dock_instance:
			remove_control_from_docks(dock_instance)
			dock_instance.queue_free()
	
	dock_instances.clear()
	print("GFRED2: All dock instances cleaned up")

## Signal handlers for inter-dock communication

func _on_object_property_changed(object_data: MissionObjectData, property_name: String, new_value: Variant) -> void:
	# Handle property changes from object inspector
	print("GFRED2: Object property changed: %s.%s = %s" % [object_data.name if object_data else "null", property_name, new_value])

func _on_asset_add_to_mission(asset_path: String, asset_data: Resource) -> void:
	# Handle adding assets to mission from asset browser
	var main_dock: MainEditorDockController = dock_instances.get("main_editor") as MainEditorDockController
	if main_dock and main_dock.has_method("add_asset_to_mission"):
		main_dock.add_asset_to_mission(asset_path, asset_data)
	
	print("GFRED2: Adding asset to mission: %s" % asset_path)

func _on_sexp_expression_changed(sexp_code: String) -> void:
	# Handle SEXP expression changes
	print("GFRED2: SEXP expression changed: %s" % sexp_code)

## Plugin interface implementation

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if main_panel_instance:
		main_panel_instance.visible = visible

func _get_plugin_name() -> String:
	return "GFRED2 Mission Editor"

func _get_plugin_icon() -> Texture2D:
	# Return mission editor icon
	return get_editor_interface().get_base_control().get_theme_icon("Node3D", "EditorIcons")

## Public API for accessing scene-based components

func get_scene_dialog_manager() -> SceneDialogManagerController:
	return scene_dialog_manager

func get_dock_instance(dock_name: String) -> Control:
	return dock_instances.get(dock_name)

func get_main_editor_dock() -> MainEditorDockController:
	return dock_instances.get("main_editor") as MainEditorDockController

func get_asset_browser_dock() -> AssetBrowserDockController:
	return dock_instances.get("asset_browser") as AssetBrowserDockController

func get_sexp_editor_dock() -> SexpEditorDockController:
	return dock_instances.get("sexp_editor") as SexpEditorDockController

func get_object_inspector_dock() -> ObjectInspectorDockController:
	return dock_instances.get("object_inspector") as ObjectInspectorDockController

## Mission management integration

func load_mission(mission_path: String) -> void:
	# Load mission into all relevant docks
	print("GFRED2: Loading mission: %s" % mission_path)
	
	# TODO: Implement mission loading logic
	# This would use WCS Asset Core to load mission data
	# and distribute it to relevant dock instances

func save_mission(mission_path: String) -> void:
	# Save mission from all relevant docks
	print("GFRED2: Saving mission: %s" % mission_path)
	
	# TODO: Implement mission saving logic
	# This would collect data from all docks and save using WCS Asset Core