extends Resource
class_name WeaponryPoolItem

## Represents a weapon available in the weaponry pool
## Maps 4-tuple format: (weapon_name, variable, count, count_variable)

@export var weapon_name: String = ""
@export var variable_name: String = ""
@export var count: int = 0
@export var count_variable: String = ""
