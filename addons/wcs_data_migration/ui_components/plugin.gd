@tool
extends EditorPlugin

## WCS Data Migration & Conversion Tools Plugin
## EPIC-003 Implementation - Complete asset conversion pipeline with unified wizard interface

const ConversionWizardMain = preload("res://addons/wcs_data_migration/ui_components/conversion_wizard_main.tscn")

var main_screen: Control

func _enter_tree() -> void:
	# Add main screen wizard
	main_screen = ConversionWizardMain.instantiate()
	get_editor_interface().get_editor_main_screen().add_child(main_screen)
	main_screen.visible = false
	
	print("WCS Asset Mapper activated")

func _exit_tree() -> void:
	# Remove main screen
	if main_screen and is_instance_valid(main_screen):
		get_editor_interface().get_editor_main_screen().remove_child(main_screen)
		main_screen.free()
	
	print("WCS Asset Mapper deactivated")

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if main_screen:
		main_screen.visible = visible

func _get_plugin_name() -> String:
	return "WCS Asset Mapper"

func _get_plugin_icon() -> Texture2D:
	# Use built-in Godot icon for now
	return get_editor_interface().get_base_control().get_theme_icon("ImportCheck", "EditorIcons")
