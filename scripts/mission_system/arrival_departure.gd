# scripts/mission_system/arrival_departure.gd
# Node or helper class responsible for managing ship/wing arrival and departure logic.
# Interacts with MissionManager, SpawnManager, and SEXPSystem.
class_name ArrivalDepartureSystem
extends Node # Using Node allows easy use of timers if needed

# --- Dependencies ---
# References to other systems will likely be passed in or accessed via singletons
var mission_manager = null # Reference to MissionManager (likely set externally)
var spawn_manager = null # Reference to SpawnManager (likely set externally)
# Access SEXPSystem via singleton: Engine.get_singleton("SEXPSystem")
# Access ObjectManager via singleton: Engine.get_singleton("ObjectManager")

# --- State ---
# Track arrival/departure status internally if needed, or rely on MissionManager/MissionData state
var arriving_ships: Array = [] # Could store ShipInstanceData references or indices
var departing_ships: Array = [] # Could store active ship node references or signatures

func _ready() -> void:
	print("ArrivalDepartureSystem initialized.")
	# Initialization logic if needed

func set_managers(m_manager, s_manager):
	mission_manager = m_manager
	spawn_manager = s_manager

# Called by MissionManager's _physics_process
func update_arrivals_departures(delta: float) -> void:
	if mission_manager == null or mission_manager.current_mission_data == null:
		return

	_check_arrivals(delta)
	_check_departures(delta)


func _check_arrivals(delta: float) -> void:
	# TODO: Iterate through ships and wings in mission_manager.current_mission_data
	# that haven't arrived yet.

	# For each ship/wing:
	# 1. Check if arrival_cue_sexp is true using SEXPSystem.
	#	 var context = {} # Build context
	#	 var cue_result = SEXPSystem.evaluate_expression(ship_data.arrival_cue_sexp, context)

	# 2. If cue is true, check arrival_delay_seconds.
	#	 - Need to store the timestamp when the cue first became true.
	#	 - If delay has passed:
	#		 - Trigger spawn via spawn_manager.spawn_ship(ship_data) or spawn_manager.spawn_wing(wing_data)
	#		 - Remove from pending arrival list.
	#		 - Handle arrival messages/music (via MissionManager signals?)

	# Handle Reinforcements:
	# - Check ReinforcementData resources in mission_manager.current_mission_data
	# - If reinforcement.is_available is true:
	#	 - Check arrival delay.
	#	 - If delay passed, trigger spawn.
	#	 - Decrement reinforcement uses, potentially set is_available to false.
	#	 - Send arrival messages.
	pass


func _check_departures(delta: float) -> void:
	# TODO: Iterate through *active* ships and wings (get from ObjectManager or MissionManager).

	# For each active ship/wing:
	# 1. Check if already departing.
	# 2. Check departure_cue_sexp using SEXPSystem.
	#	 var context = {} # Build context
	#	 var cue_result = SEXPSystem.evaluate_expression(ship_data.departure_cue_sexp, context) # Or get cue from ShipBase script?

	# 3. If cue is true, check departure_delay_seconds.
	#	 - Need to store timestamp when cue first became true.
	#	 - If delay has passed:
	#		 - Initiate departure sequence:
	#			 - Tell AI to warp out (AIController.set_mode(AIMode.WARP_OUT))
	#			 - Or tell AI to depart to dock bay (AIController.set_mode(AIMode.BAY_DEPART))
	#			 - Mark ship/wing as departing in MissionManager/ObjectManager?
	#		 - Handle departure messages.
	pass

# --- Helper Functions ---

# TODO: Add helper functions for calculating arrival positions, handling docking bay arrivals/departures, etc.
# Example: _calculate_arrival_position(anchor_name, location_enum, distance) -> Vector3
