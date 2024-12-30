@tool
extends EditorPlugin

const MainPanel = preload("res://addons/gfred2/editor_main.tscn")
var main_panel_instance

func _enter_tree():
	# Initialize plugin
	main_panel_instance = MainPanel.instantiate()
	
	# Add the main editor UI to the editor viewport
	get_editor_interface().get_editor_main_screen().add_child(main_panel_instance)
	
	# Hide the panel when plugin starts
	_make_visible(false)

func _exit_tree():
	if main_panel_instance:
		main_panel_instance.queue_free()

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
