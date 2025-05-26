class_name AssetData
extends Resource

## Base class for all WCS asset data.
## Provides common interface and functionality for ships, weapons, and other assets.

@export var asset_id: String = ""
@export var asset_name: String = ""
@export var asset_type: String = ""
@export var description: String = ""
@export var is_available: bool = true
@export var file_path: String = ""

func _init() -> void:
	asset_id = ""
	asset_name = ""
	asset_type = ""
	description = ""
	is_available = true
	file_path = ""

## Get the display name for this asset
func get_display_name() -> String:
	return asset_name if not asset_name.is_empty() else asset_id

## Get the description for this asset
func get_description() -> String:
	return description

## Get the asset type string
func get_asset_type() -> String:
	return asset_type

## Check if this asset is available for use
func is_asset_available() -> bool:
	return is_available

## Validate that this asset has all required data
func validate() -> Dictionary:
	var result: Dictionary = {"is_valid": true, "errors": []}
	
	if asset_id.is_empty():
		result.is_valid = false
		result.errors.append("Asset ID cannot be empty")
	
	if asset_name.is_empty():
		result.is_valid = false
		result.errors.append("Asset name cannot be empty")
	
	if asset_type.is_empty():
		result.is_valid = false
		result.errors.append("Asset type cannot be empty")
	
	return result