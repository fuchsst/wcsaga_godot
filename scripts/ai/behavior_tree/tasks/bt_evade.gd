@tool
class_name BTEvade
extends BTAction

## Behavior Tree Action: Evade 
## Performs evasive maneuvers

@export var evade_time: float = 2.0
@export var intensity: float = 1.0

var _timer: float = 0.0
var _evade_dir: Vector3 = Vector3.ZERO

func _enter() -> void:
	_timer = evade_time
	# Pick random direction (local)
	_evade_dir = Vector3(
		randf_range(-1, 1),
		randf_range(-1, 1),
		0
	).normalized()

func _tick(delta: float) -> Status:
	var ship: ShipEntity = agent as ShipEntity
	if not ship: return FAILURE
	
	_timer -= delta
	if _timer <= 0:
		return SUCCESS
		
	# Apply evade input
	# Roll + Pitch/Yaw
	ship.set_control_input(
		_evade_dir.y * intensity, # Pitch
		_evade_dir.x * intensity, # Yaw
		1.0, # Roll constantly
		1.0 # Full throttle
	)
	
	# Maybe Strafe?
	ship.set_control_input(
		_evade_dir.y, _evade_dir.x, 1.0, 1.0,
		signf(_evade_dir.x), # Slide X
		signf(_evade_dir.y) # Slide Y
	)
	
	return RUNNING
