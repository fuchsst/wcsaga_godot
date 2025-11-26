# Base IFF resource class for Wing Commander Saga
# This resource defines the properties of an IFF (Identification Friend or Foe) team

class_name IFFResource
extends Resource

# Team name
@export var name: String = ""

# Color used for HUD/radar display
@export var display_color: Color = Color(1, 1, 1, 1)

# List of team names this IFF attacks
@export var attacks: Array[String] = []

# Dictionary mapping other IFF names to how this IFF perceives them
# Key: IFF name, Value: Color as perceived
@export var perceptions: Dictionary = {}

# Special behavior flags
@export var flags: Array[String] = []

# Default ship flags
@export var default_ship_flags: Array[String] = []

# Additional ship flags
@export var default_ship_flags2: Array[String] = []
