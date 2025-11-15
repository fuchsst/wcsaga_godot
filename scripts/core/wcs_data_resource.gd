# Base WCS Data Resource
# Abstract base class for all Wing Commander Saga data resources
# Provides common functionality for TBL conversion validation and data integrity

class_name WCSDataResource
extends Resource

# WCS-specific metadata for tracking conversion provenance
@export var wcs_source_file: String = ""        # Original TBL filename
@export var wcs_data_version: String = ""      # Data format version
@export var wcs_original_name: String = ""     # Original TBL entry name
@export var conversion_timestamp: int = 0      # Unix timestamp of conversion
@export var conversion_metadata: Dictionary = {}  # Additional conversion metadata

# Validation and error tracking
@export var validation_errors: Array[String] = []      # Any validation errors found
@export var is_valid: bool = true                       # Overall validity flag
@export var conversion_notes: Array[String] = []       # Human-readable conversion notes

signal data_changed
signal validation_failed(errors: Array[String])
signal validation_warning(warning_value: String)

func _init():
	conversion_timestamp = Time.get_unix_time_from_system()

func validate() -> bool:
	"""
	Validate the resource data against WCS specifications
	Override this method in subclasses for specific validation logic
	"""
	validation_errors.clear()
	is_valid = true

	# Basic validation: required fields
	if wcs_source_file.is_empty():
		_add_validation_error("Missing WCS source file reference")

	if wcs_original_name.is_empty():
		_add_validation_warning("Missing original WCS name")

	# Trigger signal if validation failed
	if not is_valid:
		validation_failed.emit(validation_errors)

	return is_valid

func _add_validation_error(error_message: String) -> void:
	"""Add a validation error and mark resource as invalid"""
	validation_errors.append(error_message)
	is_valid = false

func _add_validation_warning(warning_message: String) -> void:
	"""Add a validation warning (doesn't invalidate the resource)"""
	conversion_notes.append(warning_message)
	validation_warning.emit(warning_message)

func get_validation_summary() -> Dictionary:
	"""
	Get a summary of validation status
	Returns dictionary with error count, warning count, and status message
	"""
	return {
		"is_valid": is_valid,
		"error_count": validation_errors.size(),
		"warning_count": conversion_notes.size(),
		"errors": validation_errors.duplicate(),
		"warnings": conversion_notes.duplicate(),
		"source_file": wcs_source_file,
		"original_name": wcs_original_name
	}

func set_conversion_metadata(key: String, value: Variant) -> void:
	"""Set metadata related to the conversion process"""
	conversion_metadata[key] = value

func get_conversion_metadata(key: String, default_value: Variant = null) -> Variant:
	"""Get conversion metadata by key"""
	return conversion_metadata.get(key, default_value)