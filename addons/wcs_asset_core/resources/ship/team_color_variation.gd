class_name TeamColorVariation
extends Resource

## Team color variation for ship templates
## Defines team-specific visual variations

@export var team_name: String = ""
@export var primary_color: Color = Color.WHITE
@export var secondary_color: Color = Color.WHITE
@export var texture_override: String = ""
@export var material_properties: Dictionary = {}

## Validate the team color variation
func is_valid() -> bool:
	if team_name.is_empty():
		return false
	return true