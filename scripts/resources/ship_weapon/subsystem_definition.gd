# scripts/resources/subsystem_definition.gd
extends Resource
class_name SubsystemDefinition
	@export var subobj_name: String = ""
	@export var type: int = 0 # SUBSYSTEM_* enum
	@export var max_hits: float = 100.0
	@export var radius: float = 1.0
	@export var pnt: Vector3 = Vector3.ZERO # Offset from ship center
	@export var turret_fov: float = 0.0 # Radians
	@export var turret_turn_rate: float = 1.0 # Radians/sec
	@export var turret_norm: Vector3 = Vector3.FORWARD
	@export var turret_gun_sobj: int = -1 # Index to gun submodel if separate
	@export var turret_num_firing_points: int = 1
	@export var turret_firing_point: Array[Vector3] = [] # Offsets from pnt
	@export var turret_primary_banks: Array[int] = [] # Indices of primary banks this turret uses
	@export var turret_secondary_banks: Array[int] = [] # Indices of secondary banks this turret uses
	@export var awacs_radius: float = 0.0
	@export var awacs_intensity: float = 0.0
	@export var armor_type_idx: int = -1
	@export var crewspot: String = "" # model_subsystem.crewspot (if MSS_FLAG_CREWPOINT is set)
	@export var flags: int = 0 # MSS_FLAG_*
	@export var alive_snd: int = -1
	@export var dead_snd: int = -1
	@export var rotation_snd: int = -1
	@export var turret_base_rotation_snd: int = -1
	@export var turret_gun_rotation_snd: int = -1
	@export var subsys_cargo_name: String = "" # Index/Name of cargo
	@export var path_name: String = "" # AI path name associated with subsystem
	@export var alt_dmg_sub_name: String = "" # Alternative name for damage messages
	# ... other static subsystem properties from model_subsystem
