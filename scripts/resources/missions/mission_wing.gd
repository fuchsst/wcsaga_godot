extends Resource
class_name MissionWing

## Wing formation configuration

@export var wing_name: String = ""
@export var special_ship: String = ""  # Special ship class for this wing
@export var waves: int = 1  # Number of waves
@export var wave_threshold: int = 0  # Wave arrival threshold
@export var arrival_location: String = ""
@export var arrival_cue: String = ""  # SEXP arrival condition
@export var departure_cue: String = ""  # SEXP departure condition
@export var flags: String = ""  # Wing flags
# Legacy fields kept for compatibility
@export var ship_class: String = ""
@export var count: int = 0
@export var wave_delay_min: int = 0
@export var wave_delay_max: int = 0
