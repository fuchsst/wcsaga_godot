@tool
class_name AssetCorePlugin
extends EditorPlugin

## WCS Asset Core Plugin
## Main plugin class for the WCS Asset Core addon.
## Manages addon lifecycle, autoload registration, and custom type registration.

const PLUGIN_NAME: String = "WCS Asset Core"
const PLUGIN_VERSION: String = "1.0.0"

# Plugin lifecycle
func _enter_tree() -> void:
	_initialize_asset_system()
	_register_custom_types()
	_setup_autoloads()
	
	print("WCS Asset Core: Plugin activated v%s" % PLUGIN_VERSION)

func _exit_tree() -> void:
	_cleanup_asset_system()
	_unregister_custom_types()
	_remove_autoloads()
	
	print("WCS Asset Core: Plugin deactivated")

## Asset system initialization
func _initialize_asset_system() -> void:
	"""Initialize the asset management system components."""
	
	# The actual initialization will be handled by autoloads
	# This is just the plugin framework setup
	pass

## Custom type registration for editor
func _register_custom_types() -> void:
	"""Register custom asset types in the Godot editor."""
	
	# Base asset type
	add_custom_type(
		"BaseAssetData", 
		"Resource", 
		preload("structures/base_asset_data.gd"), 
		preload("icons/asset_icon.svg")
	)
	
	# Ship asset type
	add_custom_type(
		"ShipData", 
		"BaseAssetData",
		preload("structures/ship_data.gd"),
		preload("icons/ship_icon.svg")
	)
	
	# Weapon asset type
	add_custom_type(
		"WeaponData", 
		"BaseAssetData",
		preload("structures/weapon_data.gd"),
		preload("icons/weapon_icon.svg")
	)
	
	# Armor asset type
	add_custom_type(
		"ArmorData", 
		"BaseAssetData",
		preload("structures/armor_data.gd"),
		preload("icons/armor_icon.svg")
	)

func _unregister_custom_types() -> void:
	"""Unregister custom asset types from the editor."""
	
	remove_custom_type("BaseAssetData")
	remove_custom_type("ShipData")
	remove_custom_type("WeaponData")
	remove_custom_type("ArmorData")

## Autoload management
func _setup_autoloads() -> void:
	"""Register autoload singletons for asset management."""
	
	# Register AssetLoader as singleton for global access
	add_autoload_singleton("WCSAssetLoader", "loaders/asset_loader.gd")
	
	# Register RegistryManager as singleton for asset discovery
	add_autoload_singleton("WCSAssetRegistry", "loaders/registry_manager.gd")
	
	# Register ValidationManager as singleton for asset validation
	add_autoload_singleton("WCSAssetValidator", "loaders/validation_manager.gd")

func _remove_autoloads() -> void:
	"""Remove autoload singletons when plugin is disabled."""
	
	remove_autoload_singleton("WCSAssetLoader")
	remove_autoload_singleton("WCSAssetRegistry")
	remove_autoload_singleton("WCSAssetValidator")

## Cleanup
func _cleanup_asset_system() -> void:
	"""Clean up asset system when plugin is disabled."""
	
	# Cleanup will be handled by the autoloads themselves
	pass

## Plugin information
func get_plugin_name() -> String:
	return PLUGIN_NAME

func has_main_screen() -> bool:
	return false

func get_plugin_icon() -> Texture2D:
	return preload("icons/asset_icon.svg")
