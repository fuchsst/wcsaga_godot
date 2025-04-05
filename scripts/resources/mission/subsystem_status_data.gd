# scripts/resources/subsystem_status_data.gd
# Defines initial status overrides for a ship subsystem in a mission.
class_name SubsystemStatusData
extends Resource

@export var subsystem_name: String = "" # Name matching the subsystem in the model (e.g., "turret01", "engine_left")
@export var initial_damage_percent: float = 0.0 # Percentage damage (0-100)

# Weapon overrides (primarily for turrets, potentially pilot weapons if name is "Pilot")
# -1 means no change from ship default. Use WeaponData index.
@export var primary_banks: Array[int] = [-999] # Use SUBSYS_STATUS_NO_CHANGE (-999) as default marker
@export var secondary_banks: Array[int] = [-999]

# Ammo overrides (percentage of capacity, 0-100)
@export var primary_ammo_percent: Array[int] = [100]
@export var secondary_ammo_percent: Array[int] = [100]

# AI Class override for turrets
@export var ai_class_name: String = "" # Name of AIProfile resource, empty means no change

# Cargo override for subsystems that can hold cargo
@export var cargo_name: String = "" # Name of cargo (lookup index later)
