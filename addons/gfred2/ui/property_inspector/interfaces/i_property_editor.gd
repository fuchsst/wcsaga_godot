class_name IPropertyEditor
extends RefCounted

## Interface for all property editors to ensure consistent testable API.
## Every property editor must implement this interface for gdUnit4 testing compatibility.

signal value_changed(new_value: Variant)
signal validation_error(error_message: String)
signal performance_metrics_updated(metrics: Dictionary)

## Setup the editor with property information.
func setup_editor(prop_name: String, label_text: String, value: Variant, options: Dictionary) -> void:
	assert(false, "setup_editor must be implemented by concrete property editor")

## Get the current property value.
func get_value() -> Variant:
	assert(false, "get_value must be implemented by concrete property editor")
	return null

## Set the property value without triggering signals.
func set_value(value: Variant) -> void:
	assert(false, "set_value must be implemented by concrete property editor")

## Get the property name for identification.
func get_property_name() -> String:
	assert(false, "get_property_name must be implemented by concrete property editor")
	return ""

## Get validation state information.
func get_validation_state() -> Dictionary:
	assert(false, "get_validation_state must be implemented by concrete property editor")
	return {}

## Set validation state and visual feedback.
func set_validation_state(is_valid: bool, error_message: String = "") -> void:
	assert(false, "set_validation_state must be implemented by concrete property editor")

## Check if editor has validation errors.
func has_validation_error() -> bool:
	assert(false, "has_validation_error must be implemented by concrete property editor")
	return false

## Get performance metrics for testing.
func get_performance_metrics() -> Dictionary:
	assert(false, "get_performance_metrics must be implemented by concrete property editor")
	return {}

## Reset performance metrics.
func reset_performance_metrics() -> void:
	assert(false, "reset_performance_metrics must be implemented by concrete property editor")

## Validate if this editor can handle the given property type.
func can_handle_property_type(property_type: String) -> bool:
	assert(false, "can_handle_property_type must be implemented by concrete property editor")
	return false