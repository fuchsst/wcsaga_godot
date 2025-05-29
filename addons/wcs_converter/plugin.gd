@tool
extends EditorPlugin

## WCS Asset Converter Plugin for Godot Editor
## Provides seamless import capabilities for Wing Commander Saga assets

const VPImportPlugin = preload("res://addons/wcs_converter/import/vp_import_plugin.gd")
const POFImportPlugin = preload("res://addons/wcs_converter/import/pof_import_plugin.gd")
const MissionImportPlugin = preload("res://addons/wcs_converter/import/mission_import_plugin.gd")
const ConversionDock = preload("res://addons/wcs_converter/ui/conversion_dock.gd")

var vp_import_plugin: EditorImportPlugin
var pof_import_plugin: EditorImportPlugin
var mission_import_plugin: EditorImportPlugin
var conversion_dock: Control

func _enter_tree() -> void:
	# Register import plugins
	vp_import_plugin = VPImportPlugin.new()
	pof_import_plugin = POFImportPlugin.new()
	mission_import_plugin = MissionImportPlugin.new()
	
	add_import_plugin(vp_import_plugin)
	add_import_plugin(pof_import_plugin)
	add_import_plugin(mission_import_plugin)
	
	# Add conversion dock
	conversion_dock = ConversionDock.new()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, conversion_dock)
	
	print("WCS Asset Converter plugin activated")

func _exit_tree() -> void:
	# Remove import plugins
	remove_import_plugin(vp_import_plugin)
	remove_import_plugin(pof_import_plugin)
	remove_import_plugin(mission_import_plugin)
	
	# Remove conversion dock
	remove_control_from_docks(conversion_dock)
	
	print("WCS Asset Converter plugin deactivated")

func _has_main_screen() -> bool:
	return false

func _get_plugin_name() -> String:
	return "WCS Converter"