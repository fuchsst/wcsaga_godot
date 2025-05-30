class_name MissionValidationResult
extends RefCounted

## Validation result class specifically for mission data validation
## Provides error, warning, and info message collection without requiring file paths

var _errors: Array[String] = []
var _warnings: Array[String] = []
var _info_messages: Array[String] = []

## Adds an error message to the validation result
func add_error(message: String) -> void:
	_errors.append(message)

## Adds a warning message to the validation result
func add_warning(message: String) -> void:
	_warnings.append(message)

## Adds an informational message to the validation result
func add_info(message: String) -> void:
	_info_messages.append(message)

## Returns true if validation passed (no errors)
func is_valid() -> bool:
	return _errors.is_empty()

## Returns true if there are any warnings
func has_warnings() -> bool:
	return not _warnings.is_empty()

## Returns true if there are any messages at all
func has_messages() -> bool:
	return not (_errors.is_empty() and _warnings.is_empty() and _info_messages.is_empty())

## Gets all error messages
func get_errors() -> Array[String]:
	return _errors.duplicate()

## Gets all warning messages
func get_warnings() -> Array[String]:
	return _warnings.duplicate()

## Gets all info messages
func get_info_messages() -> Array[String]:
	return _info_messages.duplicate()

## Gets all errors (for compatibility with ValidationResult interface)
func get_all_errors() -> Array[String]:
	return _errors.duplicate()

## Gets all messages combined
func get_all_messages() -> Array[String]:
	var all_messages: Array[String] = []
	all_messages.append_array(_errors)
	all_messages.append_array(_warnings)
	all_messages.append_array(_info_messages)
	return all_messages

## Merges another validation result into this one
func merge(other: MissionValidationResult) -> void:
	if not other:
		return
	
	_errors.append_array(other.get_errors())
	_warnings.append_array(other.get_warnings())
	_info_messages.append_array(other.get_info_messages())

## Gets a summary string of the validation result
func get_summary() -> String:
	var parts: Array[String] = []
	
	if _errors.size() > 0:
		parts.append("%d errors" % _errors.size())
	
	if _warnings.size() > 0:
		parts.append("%d warnings" % _warnings.size())
	
	if _info_messages.size() > 0:
		parts.append("%d info" % _info_messages.size())
	
	if parts.is_empty():
		return "No issues"
	
	return ", ".join(parts)

## Clears all messages
func clear() -> void:
	_errors.clear()
	_warnings.clear()
	_info_messages.clear()

## Gets error count
func get_error_count() -> int:
	return _errors.size()

## Gets warning count
func get_warning_count() -> int:
	return _warnings.size()

## Gets info message count
func get_info_count() -> int:
	return _info_messages.size()

## Gets total message count
func get_total_count() -> int:
	return _errors.size() + _warnings.size() + _info_messages.size()

## Formats all messages for display
func format_for_display() -> String:
	var output := ""
	
	if _errors.size() > 0:
		output += "ERRORS:\n"
		for error in _errors:
			output += "  • " + error + "\n"
		output += "\n"
	
	if _warnings.size() > 0:
		output += "WARNINGS:\n"
		for warning in _warnings:
			output += "  • " + warning + "\n"
		output += "\n"
	
	if _info_messages.size() > 0:
		output += "INFO:\n"
		for info in _info_messages:
			output += "  • " + info + "\n"
	
	return output.strip_edges()

## Static factory methods

## Creates a validation result with a single error
static func with_error(message: String) -> MissionValidationResult:
	var result := MissionValidationResult.new()
	result.add_error(message)
	return result

## Creates a validation result with a single warning
static func with_warning(message: String) -> MissionValidationResult:
	var result := MissionValidationResult.new()
	result.add_warning(message)
	return result

## Creates a valid (empty) validation result
static func valid() -> MissionValidationResult:
	return MissionValidationResult.new()