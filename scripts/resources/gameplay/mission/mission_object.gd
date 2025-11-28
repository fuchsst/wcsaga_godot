extends Resource
class_name MissionObject

## Mission object/ship instance configuration

# Basic Identity
@export var object_name: String = ""
@export var ship_class: String = ""
@export var team_name: String = ""

# Transform
@export var position: Vector3 = Vector3.ZERO
@export var orientation: Basis = Basis.IDENTITY
@export var velocity: Vector3 = Vector3.ZERO

# Object State
@export var flags: Array[String] = []
@export var flags2: Array[String] = []
@export var ai_behavior: String = ""
@export var status: String = ""
@export var cargo: String = ""

# Initial Condition
@export var initial_hull: float = 100.0
@export var initial_shields: float = 100.0
@export var initial_velocity: float = 0.0

# Arrival
@export var arrival_location: String = ""
@export var arrival_distance: float = 0.0
@export var arrival_anchor: String = ""
@export var arrival_delay: float = 0.0
@export var arrival_cue: String = ""

# Departure
@export var departure_location: String = ""
@export var departure_anchor: String = ""
@export var departure_delay: float = 0.0
@export var departure_cue: String = ""

# Orders and AI
@export var orders: String = ""
@export var determination: String = ""

# Multiplayer/Identification
@export var callsign: String = ""
@export var alt_name: String = ""
@export var net_type: String = ""
@export var respawn: String = ""

# Alternative ship classes
@export var alt_classes: Array[String] = []

# Subsystems
@export var subsystems: Array[ObjectSubsystem] = []
