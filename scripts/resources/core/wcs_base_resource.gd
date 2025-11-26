# WCSBaseResource - Enhanced Base Resource Class for Wing Commander Saga Data
# Provides comprehensive validation, cross-reference resolution, and Godot editor integration
# All WCS resources inherit from this base class for consistent data management

class_name WCSBaseResource
extends Resource

# === CORE METADATA - Required for all WCS resources ===
@export_group("WCS Provenance", "wcs_")
@export var wcs_source_file: String = ""           # Original TBL filename
@export var wcs_data_version: String = ""         # Data format version (e.g., "1.0.0")
@export var wcs_original_name: String = ""        # Original TBL entry name
@export var wcs_resource_id: String = ""          # Unique resource identifier
@export var wcs_glossary_category: String = ""    # Category for tech database

# === CONVERSION METADATA - Migration tracking ===
@export_group("Conversion Tracking", "conversion_")
@export var conversion_timestamp: int = 0         # Unix timestamp of conversion
@export var conversion_tool_version: String = ""  # Migration tool version
@export var conversion_author: String = ""        # Developer who performed conversion
@export var conversion_notes: Array[String] = [] # Human-readable conversion notes
@export var conversion_metadata: Dictionary = {}  # Additional conversion metadata

# === VALIDATION SYSTEM - Data integrity tracking ===
@export_group("Validation Status", "validation_")
@export var validation_errors: Array[String] = []      # Critical validation errors
@export var validation_warnings: Array[String] = []    # Non-critical warnings
@export var is_valid: bool = true                       # Overall validity flag
@export var last_validation_time: int = 0              # Timestamp of last validation
@export var validation_checksum: String = ""           # Data integrity checksum

# === CROSS-REFERENCE INTEGRITY - Resource linking ===
@export_group("Cross-References", "xref_")
@export var cross_reference_dependencies: Array[String] = [] # Resources this depends on
@export var cross_reference_dependents: Array[String] = []   # Resources depending on this
@export var xref_resolution_status: int = 0 # 0=Unresolved, 1=Partial, 2=Complete

# === RESOURCE CACHING - Performance optimization ===
@export_group("Caching", "cache_")
@export var cache_enabled: bool = true          # Enable resource caching
@export var cache_ttl_seconds: int = 3600       # Time-to-live in seconds
@export var last_cache_update: int = 0          # Last cache refresh timestamp

# === SIGNALS - Godot event system integration ===
signal data_changed()                                           # Emitted when core data changes
signal validation_status_changed(is_valid: bool)                # Emitted when validation status changes
signal cross_reference_resolved(ref_name: String, status: int)  # Emitted when xrefs are updated
signal cache_invalidated()                                      # Emitted when cache is cleared
signal property_validated(property_name: String, is_valid: bool) # Emitted during property validation

func _init():
	conversion_timestamp = Time.get_unix_time_from_system()
	last_validation_time = conversion_timestamp
	_generate_resource_id()

func _generate_resource_id() -> void:
	"""Generate unique resource identifier based on content"""
	if wcs_original_name.is_empty():
		return

	var base_id = wcs_original_name.to_lower().replace(" ", "_").replace("-", "_")
	wcs_resource_id = "wcs_%s_%s" % [get_resource_type(), base_id]

func get_resource_type() -> String:
	"""Override in subclasses to return specific resource type"""
	return "base"

func validate() -> bool:
	"""
	Comprehensive validation of resource data against WCS specifications.
	Override in subclasses for specific validation logic.
	"""
	validation_errors.clear()
	validation_warnings.clear()
	last_validation_time = Time.get_unix_time_from_system()

	# Basic validation: Required metadata
	if wcs_source_file.is_empty():
		_add_validation_error("Missing WCS source file reference")

	if wcs_original_name.is_empty():
		_add_validation_warning("Missing original WCS name - may affect identification")

	if wcs_resource_id.is_empty():
		_generate_resource_id()
		if wcs_resource_id.is_empty():
			_add_validation_error("Unable to generate resource identifier")

	# Validate data integrity
	_validate_checksum_integrity()

	# Validate cross-reference integrity
	if xref_resolution_status == 0 and cross_reference_dependencies.size() > 0:
		_add_validation_warning("Cross-references not yet resolved")

	# Cache validation
	if cache_enabled and cache_ttl_seconds <= 0:
		_add_validation_warning("Cache TTL should be positive when caching is enabled")

	# Update overall validity
	is_valid = validation_errors.size() == 0

	# Emit signals
	validation_status_changed.emit(is_valid)

	return is_valid

func _validate_property(property_name: String, property_value: Variant) -> bool:
	"""
	Validate a specific property value.
	Override in subclasses for property-specific validation.
	"""
	match property_value:
		null:
			_add_validation_error("Property '%s' cannot be null" % property_name)
			return false
		"":
			if property_name.find("required_") != -1:
				_add_validation_error("Required property '%s' cannot be empty" % property_name)
				return false
			type_name(property_value) == "String":
				if property_value.begins_with(" ") or property_value.ends_with(" "):
					_add_validation_warning("Property '%s' has leading/trailing whitespace" % property_name)
				return true  # String validation passed
			type_name(property_value) == "float":
				if property_value != property_value:  # NaN check
					_add_validation_error("Property '%s' cannot be NaN" % property_name)
					return false
				if property_value == INF or property_value == -INF:
					_add_validation_error("Property '%s' cannot be infinite" % property_name)
					return false
				return true  # Float validation passed
		_
			return true  # Default validation passed

func _add_validation_error(error_message: String) -> void:
	"""Add a validation error and mark resource as invalid"""
	validation_errors.append(error_message)
	is_valid = false

func _add_validation_warning(warning_message: String) -> void:
	"""Add a validation warning (doesn't invalidate the resource)"""
	validation_warnings.append(warning_message)

func _validate_checksum_integrity() -> void:
	"""Validate data integrity using checksum"""
	if validation_checksum.is_empty():
		return

	var current_checksum = calculate_checksum()
	if current_checksum != validation_checksum:
		_add_validation_error("Data integrity checksum mismatch - data may be corrupted")

func calculate_checksum() -> String:
	"""Calculate data integrity checksum from resource properties"""
	var data_string = JSON.stringify(to_dictionary(), "", false)
	return data_string.md5_text()

func to_dictionary() -> Dictionary:
	"""Convert resource to dictionary representation"""
	var result = {}

	# Iterate through all properties and add them to dictionary
	var property_list = get_property_list()
	for property_info in property_list:
		var property_name = property_info["name"]
		if property_name.begins_with("__"):
			continue  # Skip internal properties

		var property_value = get(property_name)
		result[property_name] = property_value

	return result

func from_dictionary(data: Dictionary) -> Error:
	"""Load resource from dictionary data"""
	var err = OK

	for key in data.keys():
		if has_method("set_%s" % key):
			# Use setter method if available
			call("set_%s" % key, data[key])
		elif has_method(key):
			# Direct property set
			set(key, data[key])
		else:
			# Property doesn't exist - warning
			_add_validation_warning("Unknown property '%s' ignored during loading" % key)
			err = ERR_UNAVAILABLE

	return err

func resolve_cross_references(available_resources: Array[String]) -> int:
	"""
	Resolve cross-references to other resources.
	Returns number of successfully resolved references.
	"""
	var resolved_count = 0
	var total_count = cross_reference_dependencies.size()

	if total_count == 0:
		xref_resolution_status = 2  # Complete
		return 0

	for ref_path in cross_reference_dependencies:
		if ref_path in available_resources or ResourceLoader.exists(ref_path):
			resolved_count += 1
			cross_reference_resolved.emit(ref_path, 2)
		else:
			cross_reference_resolved.emit(ref_path, 0)

	# Update resolution status
	if resolved_count == total_count:
		xref_resolution_status = 2  # Complete
	elif resolved_count > 0:
		xref_resolution_status = 1  # Partial
	else:
		xref_resolution_status = 0  # Unresolved

	return resolved_count

func add_cross_reference_dependency(resource_path: String) -> void:
	"""Add a cross-reference dependency to another resource"""
	if not cross_reference_dependencies.has(resource_path):
		cross_reference_dependencies.append(resource_path)
		xref_resolution_status = 0  # Mark as needing resolution

func remove_cross_reference_dependency(resource_path: String) -> void:
	"""Remove a cross-reference dependency"""
	var index = cross_reference_dependencies.find(resource_path)
	if index != -1:
		cross_reference_dependencies.remove_at(index)

	# Recalculate resolution status if no dependencies remain
	if cross_reference_dependencies.size() == 0:
		xref_resolution_status = 2

func get_validation_summary() -> Dictionary:
	"""
	Get comprehensive validation summary
	Returns dictionary with detailed validation information
	"""
	return {
		"is_valid": is_valid,
		"error_count": validation_errors.size(),
		"warning_count": validation_warnings.size(),
		"errors": validation_errors.duplicate(),
		"warnings": validation_warnings.duplicate(),
		"last_validation": last_validation_time,
		"checksum_valid": validation_checksum.is_empty() or calculate_checksum() == validation_checksum,
		"xref_status": xref_resolution_status,
		"xref_dependencies": cross_reference_dependencies.size(),
		"resource_type": get_resource_type(),
		"resource_id": wcs_resource_id,
		"source_file": wcs_source_file,
		"original_name": wcs_original_name
	}

func cache_data(data_key: String, data_value: Variant, ttl_override: int = -1) -> void:
	"""Cache computed data for performance optimization"""
	if not cache_enabled:
		return

	var ttl = ttl_override if ttl_override > 0 else cache_ttl_seconds
	var cache_entry = {
		"data": data_value,
		"expires": Time.get_unix_time_from_system() + ttl,
		"key": data_key
	}

	conversion_metadata["cache_%s" % data_key] = cache_entry
	last_cache_update = Time.get_unix_time_from_system()

func get_cached_data(data_key: String) -> Variant:
	"""Retrieve cached data if still valid"""
	if not cache_enabled:
		return null

	var cache_key = "cache_%s" % data_key
	var cache_entry = conversion_metadata.get(cache_key, null)

	if cache_entry == null:
		return null

	var current_time = Time.get_unix_time_from_system()
	if current_time > cache_entry.get("expires", 0):
		# Cache expired - remove it
		conversion_metadata.erase(cache_key)
		return null

	return cache_entry.get("data", null)

func invalidate_cache() -> void:
	"""Clear all cached data"""
	var keys_to_remove = []

	for key in conversion_metadata.keys():
		if key.begins_with("cache_"):
			keys_to_remove.append(key)

	for key in keys_to_remove:
		conversion_metadata.erase(key)

	last_cache_update = Time.get_unix_time_from_system()
	cache_invalidated.emit()

func get_resource_dependencies() -> Array[Dictionary]:
	"""Get detailed dependency information for analysis"""
	var dependencies = []

	for ref_path in cross_reference_dependencies:
		var dep_info = {
			"path": ref_path,
			"exists": ResourceLoader.exists(ref_path),
			"resolved": xref_resolution_status > 0
		}
		dependencies.append(dep_info)

	return dependencies