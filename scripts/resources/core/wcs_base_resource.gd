class_name WCSBaseResource
extends Resource

signal validation_status_changed(is_valid: bool)

var is_valid: bool = true
var validation_errors: Array[String] = []
var validation_warnings: Array[String] = []
var cross_reference_dependencies: Array[String] = []


func validate() -> bool:
	validation_errors.clear()
	validation_warnings.clear()
	cross_reference_dependencies.clear()
	return true


func _add_validation_error(msg: String) -> void:
	validation_errors.append(msg)
	is_valid = false


func _add_validation_warning(msg: String) -> void:
	validation_warnings.append(msg)


func add_cross_reference_dependency(path: String) -> void:
	if not path in cross_reference_dependencies:
		cross_reference_dependencies.append(path)
