# Ship data resource for Godot
# This resource represents a ship definition converted from the WCS ships.tbl file

class_name ShipData
extends Resource

# Basic ship information
@export var name: String = ""
@export var short_name: String = ""
@export var species: String = ""
@export var ship_type: String = ""  # Light Fighter, Medium Fighter, Heavy Fighter, Bomber, Corvette, Destroyer, Carrier, etc.
@export var description: String = ""
@export var tech_description: String = ""
@export var manufacturer: String = ""

# Visual properties
@export var pof_file: String = ""
@export var pof_target_lod: int = 0

# Performance characteristics
@export var max_velocity: float = 0.0
@export var maneuverability: Vector3 = Vector3.ZERO  # Pitch, Yaw, Roll in degrees per second
@export var density: float = 1.0
@export var damp: float = 0.0
@export var rotdamp: float = 0.0

# Combat characteristics
@export var shields: float = 0.0
@export var shield_color: Color = Color(1, 1, 1, 1)
@export var armor_fore: float = 0.0
@export var armor_aft: float = 0.0
@export var armor_right: float = 0.0
@export var armor_left: float = 0.0
@export var hitpoints: float = 0.0

# Power and regeneration
@export var power_output: float = 0.0
@export var shield_regen_rate: float = 0.0
@export var weapon_regen_rate: float = 0.0

# Weapon capabilities
@export var gun_mounts: Dictionary = {}  # Weapon type -> count
@export var missile_banks: Array = []  # Array of missile bank capacities

# Allowed weapons
@export var allowed_primary_banks: Array = []
@export var allowed_secondary_banks: Array = []
@export var default_primary_banks: Array = []
@export var default_secondary_banks: Array = []

# Dimensions
@export var length: float = 0.0

# AI properties
@export var ai_class: String = "Captain"

# Flags
@export var is_fighter: bool = false
@export var is_player_ship: bool = false
@export var is_bomber: bool = false
@export var is_capital: bool = false
@export var in_tech_database: bool = false

# Subsystems
class Subsystem:
    var name: String
    var alt_name: String
    var damage: float
    var position: Vector3
    
    func _init(subsystem_name: String, subsystem_damage: float, subsystem_position: Vector3):
        name = subsystem_name
        damage = subsystem_damage
        position = subsystem_position

@export var subsystems: Array[Subsystem] = []

# Explosion properties
@export var expl_inner_radius: float = 0.0
@export var expl_outer_radius: float = 0.0
@export var expl_damage: float = 0.0
@export var expl_blast: float = 0.0
@export var expl_propagates: bool = false