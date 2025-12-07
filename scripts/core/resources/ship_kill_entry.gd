class_name ShipKillEntry
extends Resource
## Tracks kills of a specific ship class.

## Ship class identifier (references Ship resource ID)
@export var ship_class_id: String = ""

## Total kills of this ship class
@export var kill_count: int = 0
