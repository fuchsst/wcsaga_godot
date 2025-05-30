@tool
class_name GFRED2DockSceneFactory
extends RefCounted

## Factory for creating dock scenes from GDScript classes.
## Allows dock manager to work with script-only docks without requiring .tscn files.

static func create_object_inspector_scene() -> PackedScene:
	"""Create a PackedScene for the object inspector dock."""
	var scene = PackedScene.new()
	var dock_script = preload("res://addons/gfred2/ui/docks/object_inspector_dock.gd")
	
	var dock_instance = dock_script.new()
	scene.pack(dock_instance)
	
	return scene

static func create_asset_browser_scene() -> PackedScene:
	"""Create a PackedScene for the asset browser dock."""
	var scene = PackedScene.new()
	var dock_script = preload("res://addons/gfred2/ui/docks/asset_browser_dock.gd")
	
	var dock_instance = dock_script.new()
	scene.pack(dock_instance)
	
	return scene

static func create_sexp_editor_scene() -> PackedScene:
	"""Create a PackedScene for the SEXP editor dock."""
	var scene = PackedScene.new()
	
	# Create a placeholder dock for now
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

static func create_validation_dock_scene() -> PackedScene:
	"""Create a PackedScene for the validation dock."""
	var scene = PackedScene.new()
	
	# Create a placeholder dock for now
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