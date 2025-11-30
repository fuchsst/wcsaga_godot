# Base IFF resource class for Wing Commander Saga
# This resource defines the properties of an IFF (Identification Friend or Foe) team

class_name IFFResource
extends Resource

enum IFFFlags {
	SUPPORT_ALLOWED, EXEMPT_FROM_ALL_TEAMS_AT_WAR, ORDERS_HIDDEN, ORDERS_SHOWN, WING_NAME_HIDDEN
}

# Team Identity
@export var iff_name: String = ""
@export var color: Color = Color.WHITE
@export var color_index: int = 0

# Attack Relationships
@export var attacks: Array[String] = []

# Perception Colors (Subjective View)
# Dictionary mapping other IFF names to the color this IFF sees them as
# Key: IFF Name (String), Value: Color
@export var perceptions: Dictionary = {}

# Flags
@export var flags: Array[IFFFlags] = []

# Default Ship Flags
@export_group("Default Ship Flags")
@export var default_ship_flags: Array[String] = []
@export var default_ship_flags2: Array[String] = []
