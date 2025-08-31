# Weapon data resource for Godot
# This resource represents a weapon definition converted from the WCS weapons.tbl file

class_name WeaponData
extends Resource

# Basic weapon information
@export var name: String = ""
@export var short_name: String = ""
@export var description: String = ""
@export var tech_title: String = ""
@export var tech_description: String = ""

# Visual properties
@export var model_file: String = ""
@export var laser_bitmap: String = ""
@export var laser_glow: String = ""
@export var laser_color: Color = Color(1, 1, 1, 1)
@export var laser_length: float = 0.0
@export var laser_head_radius: float = 0.0
@export var laser_tail_radius: float = 0.0

# Physical properties
@export var mass: float = 0.0
@export var velocity: float = 0.0
@export var fire_wait: float = 0.0  # Time between shots
@export var damage: float = 0.0
@export var lifetime: float = 0.0

# Damage factors against different target types
@export var armor_factor: float = 1.0
@export var shield_factor: float = 1.0
@export var subsystem_factor: float = 1.0

# Energy and cargo
@export var energy_consumed: float = 0.0
@export var cargo_size: float = 0.0

# Homing properties
@export var homing: bool = false
@export var homing_type: String = ""  # JAVELIN, ASPECT, HEAT
@export var turn_time: float = 0.0
@export var min_lock_time: float = 0.0

# Audio
@export var launch_sound: int = -1
@export var impact_sound: int = -1

# Visual effects
@export var impact_explosion: String = ""
@export var impact_explosion_radius: float = 0.0
@export var icon: String = ""
@export var anim: String = ""

# Flags
@export var player_allowed: bool = false
@export var in_tech_database: bool = false
@export var is_bomb: bool = false
@export var is_huge: bool = false

# Weapon type classification
enum WeaponType {
    PRIMARY,
    SECONDARY,
    BEAM,
    COUNTERMEASURE
}

@export var weapon_type: WeaponType = WeaponType.PRIMARY

# Special properties for different weapon types
@export var swarm_count: int = 1
@export var burst_count: int = 1
@export var burst_delay: float = 0.0