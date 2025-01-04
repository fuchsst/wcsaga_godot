extends Node
class_name SupportInfo

# Support status
enum Status {
	NONE,           # No support ship assigned
	APPROACHING,    # Support ship en route
	DOCKING,        # Support ship docking
	REPAIRING,      # Repairs in progress
	REARMING,       # Rearming in progress
	DEPARTING,      # Support ship leaving
	ABORTED         # Support operation aborted
}

# Support info
var ship_name: String
var status: Status
var distance: float
var eta: float
var repair_progress: float
var rearm_progress: float
var is_active: bool

func _init(name: String = "") -> void:
	ship_name = name
	status = Status.NONE
	distance = 0.0
	eta = 0.0
	repair_progress = 0.0
	rearm_progress = 0.0
	is_active = false
