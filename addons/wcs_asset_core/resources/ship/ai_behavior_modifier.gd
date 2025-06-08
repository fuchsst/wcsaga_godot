class_name AIBehaviorModifier
extends Resource

## AI behavior modifier for ship templates
## Modifies AI behavior and decision-making patterns

@export var behavior_name: String = ""
@export var modifier_value: float = 1.0
@export var priority_adjustment: int = 0
@export var conditions: Array[String] = []

## Validate the AI behavior modifier
func is_valid() -> bool:
	if behavior_name.is_empty():
		return false
	return true

## Apply modifier to ship class
func apply_to_ship_class(ship_class: ShipClass) -> void:
	# This would modify AI behavior flags or properties
	# Implementation depends on AI system integration
	pass