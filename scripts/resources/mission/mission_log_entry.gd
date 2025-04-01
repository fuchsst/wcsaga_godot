# scripts/resources/mission_log_entry.gd
# Defines the structure for a mission log entry.
# Corresponds to C++ 'log_entry' struct.
class_name MissionLogEntry
extends Resource

@export var type: int = 0 # Enum: LOG_SHIP_DESTROYED, etc.
@export var flags: int = 0 # Bitmask: MLF_ESSENTIAL, MLF_OBSOLETE, MLF_HIDDEN
@export var timestamp: float = 0.0 # Mission time when the event occurred
@export var primary_name: String = "" # Name of the primary object involved
@export var secondary_name: String = "" # Name of the secondary object (if any)
@export var primary_display_name: String = "" # Display name (potentially callsign/class)
@export var secondary_display_name: String = "" # Display name (potentially callsign/class)
@export var index: int = -1 # Context-specific index (e.g., goal index, subsys index)
@export var primary_team: int = -1 # IFF team of the primary object
@export var secondary_team: int = -1 # IFF team of the secondary object
