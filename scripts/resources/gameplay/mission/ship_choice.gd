extends Resource
class_name ShipChoice

## Represents a ship choice in the ship selection pool
## Maps 4-tuple format: (ship_name, variable, count, count_variable)

@export var ship_name: String = ""
@export var variable_name: String = ""
@export var count: int = 0
@export var count_variable: String = ""
