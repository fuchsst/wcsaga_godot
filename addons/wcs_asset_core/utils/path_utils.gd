class_name PathUtils
extends RefCounted

## Path management utilities for the WCS Asset Core addon.
## Provides standardized path operations and conversions.

static func normalize_asset_path(path: String) -> String:
	"""Normalize an asset path for consistent usage.
	Args:
		path: Raw asset path
	Returns:
		Normalized path with forward slashes"""
	
	return path.replace("\\", "/").simplify_path()

static func make_relative_to_assets(path: String) -> String:
	"""Make a path relative to the assets directory.
	Args:
		path: Full or partial path
	Returns:
		Path relative to assets directory"""
	
	var normalized: String = normalize_asset_path(path)
	
	if normalized.begins_with(FolderPaths.BASE_ASSETS_DIR):
		return normalized.substr(FolderPaths.BASE_ASSETS_DIR.length())
	
	return normalized

static func ensure_asset_extension(path: String, asset_type: AssetTypes.Type) -> String:
	"""Ensure a path has the correct extension for its asset type.
	Args:
		path: Asset path
		asset_type: Type of asset
	Returns:
		Path with correct extension"""
	
	var expected_ext: String = FolderPaths.get_file_extension_for_type(asset_type)
	
	if not path.ends_with(expected_ext):
		return path.get_basename() + expected_ext
	
	return path

static func build_full_asset_path(relative_path: String) -> String:
	"""Build full asset path from relative path.
	Args:
		relative_path: Path relative to assets directory
	Returns:
		Full asset path"""
	
	if relative_path.begins_with("res://"):
		return relative_path
	
	return FolderPaths.BASE_ASSETS_DIR.path_join(relative_path)

static func get_asset_category_from_path(path: String) -> String:
	"""Extract asset category from path.
	Args:
		path: Asset file path
	Returns:
		Category name or empty string"""
	
	var normalized: String = normalize_asset_path(path)
	var relative: String = make_relative_to_assets(normalized)
	
	var parts: PackedStringArray = relative.split("/")
	if parts.size() > 0:
		return parts[0]
	
	return ""

static func get_asset_subcategory_from_path(path: String) -> String:
	"""Extract asset subcategory from path.
	Args:
		path: Asset file path
	Returns:
		Subcategory name or empty string"""
	
	var normalized: String = normalize_asset_path(path)
	var relative: String = make_relative_to_assets(normalized)
	
	var parts: PackedStringArray = relative.split("/")
	if parts.size() > 1:
		return parts[1]
	
	return ""
