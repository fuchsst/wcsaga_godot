@tool
extends Control
class_name WizardStepBase

## Base class for wizard steps in WCS conversion workflow
## Provides common functionality and interface for all wizard steps

signal step_completed()
signal step_validation_changed(is_valid: bool)
signal status_message(message: String)
signal data_changed(data)

## Step number in the wizard sequence
@export var step_number: int = 1

## Step title displayed to user
@export var step_title: String = ""

## Step description/help text
@export var step_description: String = ""

## Whether this step has been completed successfully
var is_completed: bool = false

## Whether current step state is valid
var is_valid: bool = false

## Wizard data shared between steps
var wizard_data: Dictionary = {}

func _ready() -> void:
	_setup_step()
	_connect_step_signals()
	_validate_step()

## Override in subclasses to set up step-specific UI
func _setup_step() -> void:
	pass

## Override in subclasses to connect step-specific signals
func _connect_step_signals() -> void:
	pass

## Override in subclasses to validate step state
func _validate_step() -> void:
	var was_valid = is_valid
	is_valid = _check_step_validity()
	
	if was_valid != is_valid:
		step_validation_changed.emit(is_valid)

## Override in subclasses to implement validation logic
func _check_step_validity() -> bool:
	return true

## Called when step becomes active
func activate_step() -> void:
	visible = true
	_on_step_activated()

## Called when step becomes inactive
func deactivate_step() -> void:
	visible = false
	_on_step_deactivated()

## Override in subclasses for activation logic
func _on_step_activated() -> void:
	pass

## Override in subclasses for deactivation logic
func _on_step_deactivated() -> void:
	pass

## Mark step as completed
func complete_step() -> void:
	if is_valid:
		is_completed = true
		step_completed.emit()

## Reset step to initial state
func reset_step() -> void:
	is_completed = false
	is_valid = false
	_validate_step()

## Update wizard data (called by wizard controller)
func set_wizard_data(data: Dictionary) -> void:
	wizard_data = data
	_on_wizard_data_updated()

## Override in subclasses to react to wizard data changes
func _on_wizard_data_updated() -> void:
	pass

## Emit status message to wizard controller
func _emit_status(message: String) -> void:
	status_message.emit(message)
