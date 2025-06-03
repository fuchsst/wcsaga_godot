class_name BaseAssetData
extends Resource

## Base class for all WCS asset data structures.
## Provides common properties and interface for asset management, validation, and metadata handling.
## All specific asset types (ShipData, WeaponData, etc.) inherit from this base class.

# Asset identification
@export var asset_name: String = ""
@export var asset_id: String = ""
@export var description: String = ""
@export var file_path: String = ""
@export var asset_type: int = -1  # AssetTypes.Type enum value

# Metadata and organization
@export var metadata: Dictionary = {}
@export var tags: Array[String] = []
@export var category: String = ""
@export var subcategory: String = ""

# Version and source tracking
@export var asset_version: String = "1.0.0"
@export var source_file: String = ""  # Original WCS file this was converted from
@export var conversion_notes: String = ""

# Validation state
var _validation_cache: Dictionary = {}
var _last_validation_time: int = 0
var _is_validation_dirty: bool = true

## Abstract interface - must be implemented by subclasses
func _init() -> void:
	pass

func is_valid() -> bool:
	"""Check if the asset data is valid.
	Subclasses should override this to provide specific validation logic.
	Returns true if the asset passes all validation checks."""
	
	var errors: Array[String] = get_validation_errors()
	return errors.is_empty()

func get_validation_errors() -> Array[String]:
	"""Get list of validation errors for this asset.
	Subclasses should override this to provide specific validation.
	Returns array of error messages, empty if no errors."""
	
	var errors: Array[String] = []
	
	# Base validation - required fields
	if asset_name.is_empty():
		errors.append("Asset name is required")
	
	if asset_id.is_empty():
		errors.append("Asset ID is required")
	
	if asset_type < 0:
		errors.append("Valid asset type is required")
	
	return errors

func get_asset_type() -> int:
	"""Get the asset type enum value.
	Returns the AssetTypes.Type enum value for this asset."""
	
	return asset_type

func get_asset_type_name() -> String:
	"""Get the human-readable asset type name.
	Returns string representation of the asset type."""
	
	# This will use AssetTypes once implemented
	match asset_type:
		0:
			return "Ship"
		1:
			return "Weapon"
		2:
			return "Armor"
		_:
			return "Unknown"

## Metadata management

func set_metadata(key: String, value: Variant) -> void:
	"""Set a metadata value for this asset.
	Args:
		key: Metadata key name
		value: Metadata value (any Variant type)"""
	
	metadata[key] = value
	_mark_validation_dirty()

func get_metadata(key: String, default_value: Variant = null) -> Variant:
	"""Get a metadata value for this asset.
	Args:
		key: Metadata key name
		default_value: Value to return if key not found
	Returns:
		Metadata value or default_value if not found"""
	
	return metadata.get(key, default_value)

func has_metadata(key: String) -> bool:
	"""Check if a metadata key exists.
	Args:
		key: Metadata key name
	Returns:
		true if key exists in metadata"""
	
	return metadata.has(key)

func clear_metadata() -> void:
	"""Clear all metadata for this asset."""
	
	metadata.clear()
	_mark_validation_dirty()

## Tag management

func add_tag(tag: String) -> void:
	"""Add a tag to this asset.
	Args:
		tag: Tag string to add"""
	
	if not tags.has(tag):
		tags.append(tag)
		_mark_validation_dirty()

func remove_tag(tag: String) -> void:
	"""Remove a tag from this asset.
	Args:
		tag: Tag string to remove"""
	
	tags.erase(tag)
	_mark_validation_dirty()

func has_tag(tag: String) -> bool:
	"""Check if this asset has a specific tag.
	Args:
		tag: Tag string to check
	Returns:
		true if asset has the tag"""
	
	return tags.has(tag)

func get_tags() -> Array[String]:
	"""Get all tags for this asset.
	Returns:
		Array of tag strings"""
	
	return tags.duplicate()

## Utility functions

func get_display_name() -> String:
	"""Get the display name for this asset.
	Uses asset_name if available, otherwise asset_id.
	Returns:
		Human-readable name for display"""
	
	if not asset_name.is_empty():
		return asset_name
	elif not asset_id.is_empty():
		return asset_id
	else:
		return "Unnamed Asset"

func get_full_identifier() -> String:
	"""Get the full identifier for this asset.
	Combines asset type, category, and ID for unique identification.
	Returns:
		Full asset identifier string"""
	
	var parts: Array[String] = []
	
	parts.append(get_asset_type_name())
	
	if not category.is_empty():
		parts.append(category)
	
	if not subcategory.is_empty():
		parts.append(subcategory)
	
	parts.append(asset_id)
	
	return ":".join(parts)

func matches_search(query: String) -> bool:
	"""Check if this asset matches a search query.
	Searches in name, ID, description, and tags.
	Args:
		query: Search query string (case-insensitive)
	Returns:
		true if asset matches the query"""
	
	var search_query: String = query.to_lower()
	
	# Search in basic fields
	if asset_name.to_lower().contains(search_query):
		return true
	
	if asset_id.to_lower().contains(search_query):
		return true
	
	if description.to_lower().contains(search_query):
		return true
	
	if category.to_lower().contains(search_query):
		return true
	
	if subcategory.to_lower().contains(search_query):
		return true
	
	# Search in tags
	for tag in tags:
		if tag.to_lower().contains(search_query):
			return true
	
	return false

func get_memory_size() -> int:
	"""Estimate the memory size of this asset in bytes.
	Used for cache management and performance monitoring.
	Subclasses should override for accurate size estimation.
	Returns:
		Estimated memory size in bytes"""
	
	# Base estimation - strings and basic data
	var size: int = 0
	
	size += asset_name.length() + asset_id.length() + description.length()
	size += file_path.length() + category.length() + subcategory.length()
	size += asset_version.length() + source_file.length() + conversion_notes.length()
	
	# Estimate metadata size (rough approximation)
	for key in metadata.keys():
		size += str(key).length() + str(metadata[key]).length()
	
	# Estimate tags size
	for tag in tags:
		size += tag.length()
	
	# Add overhead for data structures
	size += 1024  # Base object overhead
	
	return size

## Serialization support

func to_dictionary() -> Dictionary:
	"""Convert asset to dictionary for serialization.
	Returns:
		Dictionary representation of the asset"""
	
	return {
		"asset_name": asset_name,
		"asset_id": asset_id,
		"description": description,
		"file_path": file_path,
		"asset_type": asset_type,
		"metadata": metadata,
		"tags": tags,
		"category": category,
		"subcategory": subcategory,
		"asset_version": asset_version,
		"source_file": source_file,
		"conversion_notes": conversion_notes
	}

func from_dictionary(data: Dictionary) -> void:
	"""Load asset from dictionary representation.
	Args:
		data: Dictionary containing asset data"""
	
	asset_name = data.get("asset_name", "")
	asset_id = data.get("asset_id", "")
	description = data.get("description", "")
	file_path = data.get("file_path", "")
	asset_type = data.get("asset_type", -1)
	metadata = data.get("metadata", {})
	tags = data.get("tags", [])
	category = data.get("category", "")
	subcategory = data.get("subcategory", "")
	asset_version = data.get("asset_version", "1.0.0")
	source_file = data.get("source_file", "")
	conversion_notes = data.get("conversion_notes", "")
	
	_mark_validation_dirty()

## Internal validation cache management

func _mark_validation_dirty() -> void:
	"""Mark validation cache as dirty to force re-validation."""
	
	_is_validation_dirty = true
	_validation_cache.clear()

func _get_cached_validation() -> Dictionary:
	"""Get cached validation results if still valid.
	Returns:
		Cached validation dictionary or empty if invalid"""
	
	if _is_validation_dirty:
		return {}
	
	var current_time: int = Time.get_ticks_msec()
	var cache_timeout: int = 5000  # 5 second cache timeout
	
	if current_time - _last_validation_time > cache_timeout:
		_validation_cache.clear()
		return {}
	
	return _validation_cache

func _set_validation_cache(errors: Array[String]) -> void:
	"""Cache validation results.
	Args:
		errors: Array of validation error messages"""
	
	_validation_cache = {
		"errors": errors,
		"is_valid": errors.is_empty()
	}
	_last_validation_time = Time.get_ticks_msec()
	_is_validation_dirty = false

## Debug and development support

func _to_string() -> String:
	"""String representation for debugging.
	Returns:
		Debug string representation"""
	
	return "BaseAssetData(id=%s, name=%s, type=%s)" % [asset_id, asset_name, get_asset_type_name()]
