extends Resource
# Wingman info
class_name Wingman

# Order types
enum OrderType {
	NONE,
	ATTACK,
	DEFEND,
	FORM_UP,
	COVER,
	REARM,
	DISABLE
}

# Wingman status
enum Status {
	ALIVE,
	DAMAGED,
	CRITICAL,
	DEPARTED,
	DESTROYED
}

@export var name: String
@export var callsign: String
@export var status: Status
@export var health: float
@export var shield: float
@export var current_order: OrderType
@export var target_name: String
@export var is_selected: bool
@export var flash_time: float

func _init(n: String = "", c: String = "",
	h: float = 1.0, s: float = 1.0) -> void:
	name = n
	callsign = c
	status = Status.ALIVE
	health = h
	shield = s
	current_order = OrderType.NONE
	target_name = ""
	is_selected = false
	flash_time = 0.0
