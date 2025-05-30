@tool
class_name GFRED2DockManager
extends RefCounted

## Dock management system for GFRED2 that provides dockable panels with layout persistence.
## Integrates with Godot's editor dock system while maintaining custom layout state.

signal dock_added(dock_name: String, dock_control: Control)
signal dock_removed(dock_name: String)
signal layout_changed()

# Editor interface reference
var editor_interface: EditorInterface
var theme_manager: GFRED2ThemeManager

# Dock registry
var registered_docks: Dictionary = {}
var active_docks: Dictionary = {}
var dock_configurations: Dictionary = {}

# Layout persistence
var layout_config_path: String = "user://gfred2_dock_layout.cfg"
var default_layout: Dictionary = {}

# Available dock slots
enum DockSlot {
	LEFT_UL,
	LEFT_BL,
	LEFT_UR,
	LEFT_BR,
	RIGHT_UL,
	RIGHT_BL,
	RIGHT_UR,
	RIGHT_BR
}

# Dock configuration structure
class DockConfiguration:
	var name: String
	var display_name: String
	var default_slot: DockSlot
	var control_scene: PackedScene
	var is_enabled: bool = true
	var is_visible: bool = true
	var size_hint: Vector2 = Vector2(300, 400)
	var min_size: Vector2 = Vector2(200, 200)
	
	func _init(dock_name: String, scene: PackedScene, slot: DockSlot = DockSlot.LEFT_UL) -> void:
		name = dock_name
		display_name = dock_name.capitalize()
		control_scene = scene
		default_slot = slot

func _init(editor_interface_ref: EditorInterface, theme_manager_ref: GFRED2ThemeManager) -> void:
	editor_interface = editor_interface_ref
	theme_manager = theme_manager_ref
	_setup_default_layout()

func register_dock(dock_name: String, scene_or_script_path: String, display_name: String = "", default_slot: DockSlot = DockSlot.LEFT_UL) -> bool:
	"""Register a dock for use in the editor."""
	if registered_docks.has(dock_name):
		push_warning("Dock '%s' is already registered" % dock_name)
		return false
	
	# Load the scene or create from script
	var scene: PackedScene = null
	
	if scene_or_script_path.ends_with(".tscn"):
		scene = load(scene_or_script_path)
	elif scene_or_script_path.ends_with(".gd"):
		# Create scene from script using factory
		scene = _create_scene_from_script(dock_name, scene_or_script_path)
	
	if not scene:
		push_error("Failed to load dock scene: %s" % scene_or_script_path)
		return false
	
	# Create configuration
	var config = DockConfiguration.new(dock_name, scene, default_slot)
	config.display_name = display_name if not display_name.is_empty() else dock_name.capitalize()
	
	registered_docks[dock_name] = config
	dock_configurations[dock_name] = {
		"enabled": true,
		"visible": true,
		"slot": default_slot,
		"size": config.size_hint
	}
	
	return true

func add_dock(dock_name: String, force_slot: DockSlot = DockSlot.LEFT_UL) -> bool:
	"""Add a registered dock to the editor."""
	if not registered_docks.has(dock_name):
		push_error("Dock '%s' is not registered" % dock_name)
		return false
	
	if active_docks.has(dock_name):
		push_warning("Dock '%s' is already active" % dock_name)
		return true
	
	var config: DockConfiguration = registered_docks[dock_name]
	var dock_control: Control = config.control_scene.instantiate()
	
	if not dock_control:
		push_error("Failed to instantiate dock scene for '%s'" % dock_name)
		return false
	
	# Apply theming
	if theme_manager:
		theme_manager.apply_theme_to_control(dock_control)
	
	# Configure dock control
	dock_control.name = dock_name
	dock_control.set_meta("dock_name", dock_name)
	
	# Add to editor
	var slot: DockSlot = force_slot if force_slot != DockSlot.LEFT_UL else config.default_slot
	var godot_slot: EditorPlugin.DockSlot = _convert_to_godot_slot(slot)
	
	if editor_interface:
		editor_interface.get_editor_main_screen().add_child(dock_control)
		# Note: EditorInterface dock functionality varies, so we'll manage docking ourselves
	
	# Store active dock
	active_docks[dock_name] = {
		"control": dock_control,
		"slot": slot,
		"configuration": config
	}
	
	# Update configuration
	dock_configurations[dock_name]["slot"] = slot
	dock_configurations[dock_name]["visible"] = true
	
	dock_added.emit(dock_name, dock_control)
	layout_changed.emit()
	
	return true

func remove_dock(dock_name: String) -> bool:
	"""Remove an active dock from the editor."""
	if not active_docks.has(dock_name):
		push_warning("Dock '%s' is not active" % dock_name)
		return false
	
	var dock_data: Dictionary = active_docks[dock_name]
	var dock_control: Control = dock_data["control"]
	
	# Remove from editor
	if dock_control and dock_control.get_parent():
		dock_control.get_parent().remove_child(dock_control)
		dock_control.queue_free()
	
	# Update state
	active_docks.erase(dock_name)
	dock_configurations[dock_name]["visible"] = false
	
	dock_removed.emit(dock_name)
	layout_changed.emit()
	
	return true

func is_dock_active(dock_name: String) -> bool:
	"""Check if a dock is currently active."""
	return active_docks.has(dock_name)

func get_dock_control(dock_name: String) -> Control:
	"""Get the control instance for an active dock."""
	if not active_docks.has(dock_name):
		return null
	return active_docks[dock_name]["control"]

func move_dock(dock_name: String, new_slot: DockSlot) -> bool:
	"""Move a dock to a different slot."""
	if not active_docks.has(dock_name):
		push_warning("Dock '%s' is not active" % dock_name)
		return false
	
	var dock_data: Dictionary = active_docks[dock_name]
	dock_data["slot"] = new_slot
	dock_configurations[dock_name]["slot"] = new_slot
	
	# TODO: Implement actual dock moving in editor
	# This would require custom dock container implementation
	
	layout_changed.emit()
	return true

func toggle_dock_visibility(dock_name: String) -> bool:
	"""Toggle the visibility of a dock."""
	if not registered_docks.has(dock_name):
		return false
	
	if active_docks.has(dock_name):
		return remove_dock(dock_name)
	else:
		return add_dock(dock_name)

func get_available_docks() -> Array[String]:
	"""Get list of all registered dock names."""
	return registered_docks.keys()

func get_active_docks() -> Array[String]:
	"""Get list of currently active dock names."""
	return active_docks.keys()

func save_layout() -> void:
	"""Save the current dock layout to persistent storage."""
	var config = ConfigFile.new()
	
	# Save dock configurations
	for dock_name in dock_configurations:
		var dock_config: Dictionary = dock_configurations[dock_name]
		config.set_value("docks", dock_name + "_enabled", dock_config.get("enabled", true))
		config.set_value("docks", dock_name + "_visible", dock_config.get("visible", false))
		config.set_value("docks", dock_name + "_slot", dock_config.get("slot", DockSlot.LEFT_UL))
		
		if active_docks.has(dock_name):
			var dock_control: Control = active_docks[dock_name]["control"]
			if dock_control:
				config.set_value("docks", dock_name + "_size", dock_control.size)
	
	# Save global layout settings
	config.set_value("layout", "version", "1.0")
	config.set_value("layout", "timestamp", Time.get_ticks_msec())
	
	var save_result: Error = config.save(layout_config_path)
	if save_result != OK:
		push_warning("Failed to save dock layout: %s" % save_result)

func load_layout() -> void:
	"""Load dock layout from persistent storage."""
	var config = ConfigFile.new()
	var load_result: Error = config.load(layout_config_path)
	
	if load_result != OK:
		print("No saved dock layout found, using defaults")
		_apply_default_layout()
		return
	
	# Load dock configurations
	for dock_name in registered_docks:
		var enabled: bool = config.get_value("docks", dock_name + "_enabled", true)
		var visible: bool = config.get_value("docks", dock_name + "_visible", false)
		var slot: DockSlot = config.get_value("docks", dock_name + "_slot", DockSlot.LEFT_UL)
		var size: Vector2 = config.get_value("docks", dock_name + "_size", Vector2(300, 400))
		
		dock_configurations[dock_name] = {
			"enabled": enabled,
			"visible": visible,
			"slot": slot,
			"size": size
		}
		
		# Apply layout
		if enabled and visible:
			add_dock(dock_name, slot)

func reset_layout() -> void:
	"""Reset dock layout to defaults."""
	# Remove all active docks
	for dock_name in active_docks.keys():
		remove_dock(dock_name)
	
	# Reset configurations
	for dock_name in registered_docks:
		var config: DockConfiguration = registered_docks[dock_name]
		dock_configurations[dock_name] = {
			"enabled": true,
			"visible": false,
			"slot": config.default_slot,
			"size": config.size_hint
		}
	
	# Apply default layout
	_apply_default_layout()

func get_layout_preset_names() -> Array[String]:
	"""Get available layout preset names."""
	return ["Default", "Debug", "Compact", "Widescreen"]

func apply_layout_preset(preset_name: String) -> bool:
	"""Apply a predefined layout preset."""
	match preset_name.to_lower():
		"default":
			_apply_default_layout()
		"debug":
			_apply_debug_layout()
		"compact":
			_apply_compact_layout()
		"widescreen":
			_apply_widescreen_layout()
		_:
			return false
	
	return true

func _setup_default_layout() -> void:
	"""Setup default dock layout configuration."""
	default_layout = {
		"object_inspector": {"slot": DockSlot.RIGHT_UL, "visible": true},
		"asset_browser": {"slot": DockSlot.LEFT_UL, "visible": true},
		"sexp_editor": {"slot": DockSlot.LEFT_BL, "visible": false},
		"validation_panel": {"slot": DockSlot.RIGHT_BL, "visible": false}
	}

func _apply_default_layout() -> void:
	"""Apply the default layout."""
	for dock_name in default_layout:
		if registered_docks.has(dock_name):
			var layout_config: Dictionary = default_layout[dock_name]
			if layout_config.get("visible", false):
				add_dock(dock_name, layout_config.get("slot", DockSlot.LEFT_UL))

func _apply_debug_layout() -> void:
	"""Apply debug-focused layout."""
	# Remove all docks first
	for dock_name in active_docks.keys():
		remove_dock(dock_name)
	
	# Add debug-relevant docks
	if registered_docks.has("validation_panel"):
		add_dock("validation_panel", DockSlot.RIGHT_UL)
	if registered_docks.has("sexp_editor"):
		add_dock("sexp_editor", DockSlot.LEFT_BL)
	if registered_docks.has("object_inspector"):
		add_dock("object_inspector", DockSlot.RIGHT_BL)

func _apply_compact_layout() -> void:
	"""Apply compact layout for smaller screens."""
	# Remove all docks first
	for dock_name in active_docks.keys():
		remove_dock(dock_name)
	
	# Add only essential docks
	if registered_docks.has("object_inspector"):
		add_dock("object_inspector", DockSlot.RIGHT_UL)

func _apply_widescreen_layout() -> void:
	"""Apply widescreen layout."""
	# Remove all docks first
	for dock_name in active_docks.keys():
		remove_dock(dock_name)
	
	# Utilize side panels efficiently
	if registered_docks.has("asset_browser"):
		add_dock("asset_browser", DockSlot.LEFT_UL)
	if registered_docks.has("sexp_editor"):
		add_dock("sexp_editor", DockSlot.LEFT_BL)
	if registered_docks.has("object_inspector"):
		add_dock("object_inspector", DockSlot.RIGHT_UL)
	if registered_docks.has("validation_panel"):
		add_dock("validation_panel", DockSlot.RIGHT_BL)

func _convert_to_godot_slot(slot: DockSlot) -> EditorPlugin.DockSlot:
	"""Convert our dock slot enum to Godot's dock slot enum."""
	match slot:
		DockSlot.LEFT_UL:
			return EditorPlugin.DOCK_SLOT_LEFT_UL
		DockSlot.LEFT_BL:
			return EditorPlugin.DOCK_SLOT_LEFT_BL
		DockSlot.LEFT_UR:
			return EditorPlugin.DOCK_SLOT_LEFT_UR
		DockSlot.LEFT_BR:
			return EditorPlugin.DOCK_SLOT_LEFT_BR
		DockSlot.RIGHT_UL:
			return EditorPlugin.DOCK_SLOT_RIGHT_UL
		DockSlot.RIGHT_BL:
			return EditorPlugin.DOCK_SLOT_RIGHT_BL
		DockSlot.RIGHT_UR:
			return EditorPlugin.DOCK_SLOT_RIGHT_UR
		DockSlot.RIGHT_BR:
			return EditorPlugin.DOCK_SLOT_RIGHT_BR
	
	return EditorPlugin.DOCK_SLOT_LEFT_UL

func get_dock_title_for_slot(slot: DockSlot) -> String:
	"""Get a human-readable title for a dock slot."""
	match slot:
		DockSlot.LEFT_UL:
			return "Left Upper"
		DockSlot.LEFT_BL:
			return "Left Lower"
		DockSlot.LEFT_UR:
			return "Left Upper Right"
		DockSlot.LEFT_BR:
			return "Left Lower Right"
		DockSlot.RIGHT_UL:
			return "Right Upper"
		DockSlot.RIGHT_BL:
			return "Right Lower"
		DockSlot.RIGHT_UR:
			return "Right Upper Right"
		DockSlot.RIGHT_BR:
			return "Right Lower Right"
	
	return "Unknown"

func _create_scene_from_script(dock_name: String, script_path: String) -> PackedScene:
	"""Create a PackedScene from a dock script using the factory."""
	match dock_name:
		"object_inspector":
			var dock_script = load(script_path)
			var scene = PackedScene.new()
			var dock_instance = dock_script.new()
			scene.pack(dock_instance)
			return scene
		"asset_browser":
			var dock_script = load(script_path)
			var scene = PackedScene.new()
			var dock_instance = dock_script.new()
			scene.pack(dock_instance)
			return scene
		"sexp_editor":
			# Create placeholder
			var scene = PackedScene.new()
			var dock_instance = Control.new()
			dock_instance.name = "SexpEditorDock"
			var label = Label.new()
			label.text = "SEXP Editor\n(Coming in next tasks)"
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			dock_instance.add_child(label)
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			scene.pack(dock_instance)
			return scene
		"validation_panel":
			# Create placeholder
			var scene = PackedScene.new()
			var dock_instance = Control.new()
			dock_instance.name = "ValidationDock"
			var label = Label.new()
			label.text = "Validation Panel\n(Coming in next tasks)"
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			dock_instance.add_child(label)
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			scene.pack(dock_instance)
			return scene
		_:
			return null