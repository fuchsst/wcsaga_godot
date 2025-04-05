# scripts/resources/reinforcement_data.gd
# Defines a reinforcement unit.
# Corresponds to the C++ 'reinforcements' struct.
class_name ReinforcementData
extends Resource

enum ReinforcementType { ATTACK_PROTECT = 0, REPAIR_REARM = 1 }

@export var name: String = "" # Name of the ship or wing to reinforce
@export var type: ReinforcementType = ReinforcementType.ATTACK_PROTECT # Type of reinforcement (attack/protect or repair/rearm)
@export var total_uses: int = 1 # How many times this reinforcement can be called
@export var arrival_delay_seconds: int = 0 # Delay before arrival after being called

# --- Messages ---
# Arrays of message names (strings) to be sent
@export var no_messages: Array[String] = [] # Messages sent if reinforcement cannot arrive
@export var yes_messages: Array[String] = [] # Messages sent when reinforcement arrives

# --- Runtime State (Managed by MissionManager) ---
# These are not exported, they are set during gameplay
var current_uses: int = 0 # How many times used so far
var is_available: bool = false # Flag indicating if the reinforcement can be called
