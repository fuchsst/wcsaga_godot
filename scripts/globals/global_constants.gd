# scripts/globals/global_constants.gd
# Defines global constants and enums used throughout the game.
class_name GlobalConstants
extends RefCounted # Use RefCounted as it primarily holds constants/enums

# --- Object Types (Mirroring OBJ_*) ---
enum ObjectType {
	NONE = 0,
	SHIP = 1,
	WEAPON = 2,
	FIREBALL = 3, # Explosions
	START = 4, # Player start marker
	WAYPOINT = 5,
	ASTEROID = 6,
	DEBRIS = 7,
	SHOCKWAVE = 8,
	JUMP_NODE = 9,
	GHOST = 10, # Used internally?
	OBSERVER = 11, # Debug/Spectator
	BEAM = 12, # Beam weapons might be distinct
	UNKNOWN = 13 # Fallback
	# TODO: Add others as needed
}

# --- Object Flags (Mirroring OF_*) ---
# Define common object flags here if needed globally
const OF_PLAYER_SHIP = 1 << 0
const OF_PROTECTED = 1 << 1 # Example mapping
const OF_COLLIDES = 1 << 2 # Example mapping
const OF_TARGETABLE = 1 << 3 # Example mapping
const OF_INVULNERABLE = 1 << 4 # Example mapping
const OF_HIDDEN_FROM_SENSORS = 1 << 5 # Example mapping
# TODO: Add other OF_* flags as needed

# --- Ranks (Mirroring RANK_*) ---
enum Rank {
	ENSIGN = 0,
	LT_JUNIOR = 1,
	LT = 2,
	LT_CMDR = 3,
	CMDR = 4,
	CAPTAIN = 5,
	COMMODORE = 6,
	REAR_ADMIRAL = 7,
	VICE_ADMIRAL = 8,
	ADMIRAL = 9
	# MAX_FREESPACE2_RANK = ADMIRAL
}
const NUM_RANKS = 10

# --- Medals ---
# Placeholder - Actual medal IDs/indices might be loaded from resources
const MAX_MEDALS = 19 # From medals.cpp
# enum MedalID { ... }

# --- Ship Classes ---
# Placeholder - Actual ship class indices loaded from resources
const MAX_SHIP_CLASSES = 130 # From globals.h (MAX_SHIP_CLASSES_MULTI)

# --- Game States (Mirroring GS_STATE_*) ---
enum GameState {
	NONE = 0, # Not a valid state
	MAIN_MENU = 1,
	GAME_PLAY = 2,
	GAME_PAUSED = 3,
	QUIT_GAME = 4,
	OPTIONS_MENU = 5,
	BARRACKS_MENU = 6,
	TECH_MENU = 7,
	TRAINING_MENU = 8,
	LOAD_MISSION_MENU = 9,
	BRIEFING = 10,
	SHIP_SELECT = 11,
	DEBUG_PAUSED = 12,
	HUD_CONFIG = 13,
	MULTI_JOIN_GAME = 14,
	CONTROL_CONFIG = 15,
	WEAPON_SELECT = 16,
	MISSION_LOG_SCROLLBACK = 17,
	DEATH_DIED = 18,
	DEATH_BLEW_UP = 19,
	SIMULATOR_ROOM = 20,
	CREDITS = 21,
	SHOW_GOALS = 22,
	HOTKEY_SCREEN = 23,
	VIEW_MEDALS = 24,
	MULTI_HOST_SETUP = 25,
	MULTI_CLIENT_SETUP = 26,
	DEBRIEF = 27,
	VIEW_CUTSCENES = 28,
	MULTI_STD_WAIT = 29,
	STANDALONE_MAIN = 30,
	MULTI_PAUSED = 31,
	TEAM_SELECT = 32,
	TRAINING_PAUSED = 33,
	INGAME_PRE_JOIN = 34,
	EVENT_DEBUG = 35,
	STANDALONE_POSTGAME = 36,
	INITIAL_PLAYER_SELECT = 37,
	MULTI_MISSION_SYNC = 38,
	MULTI_START_GAME = 39,
	MULTI_HOST_OPTIONS = 40,
	MULTI_DOGFIGHT_DEBRIEF = 41,
	CAMPAIGN_ROOM = 42,
	CMD_BRIEF = 43,
	RED_ALERT = 44,
	END_OF_CAMPAIGN = 45,
	GAMEPLAY_HELP = 46,
	END_DEMO = 47,
	LOOP_BRIEF = 48,
	PXO = 49,
	LAB = 50,
	PXO_HELP = 51,
	START_GAME = 52,
	FICTION_VIEWER = 53
	# NUM_STATES = 54
}

# --- Game Events (Mirroring GS_EVENT_*) ---
enum GameEvent {
	MAIN_MENU = 0,
	START_GAME = 1,
	ENTER_GAME = 2,
	START_GAME_QUICK = 3,
	END_GAME = 4,
	QUIT_GAME = 5,
	PAUSE_GAME = 6,
	PREVIOUS_STATE = 7,
	OPTIONS_MENU = 8,
	BARRACKS_MENU = 9,
	TRAINING_MENU = 10,
	TECH_MENU = 11,
	LOAD_MISSION_MENU = 12,
	SHIP_SELECTION = 13,
	TOGGLE_FULLSCREEN = 14,
	START_BRIEFING = 15,
	DEBUG_PAUSE_GAME = 16,
	HUD_CONFIG = 17,
	MULTI_JOIN_GAME = 18,
	CONTROL_CONFIG = 19,
	EVENT_DEBUG = 20,
	WEAPON_SELECTION = 21,
	MISSION_LOG_SCROLLBACK = 22,
	GAMEPLAY_HELP = 23,
	DEATH_DIED = 24,
	DEATH_BLEW_UP = 25,
	NEW_CAMPAIGN = 26,
	CREDITS = 27,
	SHOW_GOALS = 28,
	HOTKEY_SCREEN = 29,
	VIEW_MEDALS = 30,
	MULTI_HOST_SETUP = 31,
	MULTI_CLIENT_SETUP = 32,
	DEBRIEF = 33,
	GOTO_VIEW_CUTSCENES_SCREEN = 34,
	MULTI_STD_WAIT = 35,
	STANDALONE_MAIN = 36,
	MULTI_PAUSE = 37,
	TEAM_SELECT = 38,
	TRAINING_PAUSE = 39,
	INGAME_PRE_JOIN = 40,
	PLAYER_WARPOUT_START = 41,
	PLAYER_WARPOUT_START_FORCED = 42,
	PLAYER_WARPOUT_STOP = 43,
	PLAYER_WARPOUT_DONE_STAGE1 = 44,
	PLAYER_WARPOUT_DONE_STAGE2 = 45,
	PLAYER_WARPOUT_DONE = 46,
	STANDALONE_POSTGAME = 47,
	INITIAL_PLAYER_SELECT = 48,
	GAME_INIT = 49,
	MULTI_MISSION_SYNC = 50,
	MULTI_START_GAME = 51,
	MULTI_HOST_OPTIONS = 52,
	MULTI_DOGFIGHT_DEBRIEF = 53,
	CAMPAIGN_ROOM = 54,
	CMD_BRIEF = 55,
	TOGGLE_GLIDE = 56,
	RED_ALERT = 57,
	SIMULATOR_ROOM = 58,
	END_CAMPAIGN = 59,
	END_DEMO = 60,
	LOOP_BRIEF = 61,
	CAMPAIGN_CHEAT = 62,
	PXO = 63,
	LAB = 64,
	PXO_HELP = 65,
	FICTION_VIEWER = 66
	# NUM_EVENTS = 67
}

# --- Statistics Types (Placeholder) ---
enum StatType {
	SCORE,
	KILLS_TOTAL,
	# TODO: add others as needed
}

# --- Global Limits (Mirroring MAX_*) ---
# Defined directly where needed or loaded from settings/resources.
# Example: const MAX_SHIPS = 400 (from globals.h) - Use with caution, prefer dynamic limits.

# --- Global Colors (Mirroring Color_*) ---
# Define common colors here or use a Theme resource.
const COLOR_BRIGHT_GREEN = Color(0.31, 0.75, 0.31) # Example
const COLOR_BRIGHT_BLUE = Color(0.5, 0.76, 1.0) # Example
const COLOR_BRIGHT_RED = Color(0.78, 0.0, 0.0) # Example
const COLOR_NORMAL = Color(0.75, 0.75, 0.75) # Example (Color_white)
const COLOR_DEBUG = Color(1.0, 0.5, 0.0) # Example

# --- Ship Flags (ship.h - SF_*) ---
const SF_IGNORE_COUNT = 1 << 0
const SF_REINFORCEMENT = 1 << 1
const SF_ESCORT = 1 << 2
const SF_NO_ARRIVAL_MUSIC = 1 << 3
const SF_NO_ARRIVAL_WARP = 1 << 4
const SF_NO_DEPARTURE_WARP = 1 << 5
const SF_LOCKED = 1 << 6
# Bits 7-11 unused in SF
const SF_WARPED_SUPPORT = 1 << 12
const SF_SCANNABLE = 1 << 13
const SF_HIDDEN_FROM_SENSORS = 1 << 14
const SF_AMMO_COUNT_RECORDED = 1 << 15
const SF_TRIGGER_DOWN = 1 << 16
const SF_WARP_NEVER = 1 << 17
const SF_WARP_BROKEN = 1 << 18
const SF_SECONDARY_DUAL_FIRE = 1 << 19
const SF_PRIMARY_LINKED = 1 << 20
const SF_FROM_PLAYER_WING = 1 << 21
const SF_CARGO_REVEALED = 1 << 22
const SF_DOCK_LEADER = 1 << 23
const SF_ENGINES_ON = 1 << 24
const SF_ARRIVING_STAGE_2 = 1 << 25
const SF_ARRIVING_STAGE_1 = 1 << 26
const SF_DEPART_DOCKBAY = 1 << 27
const SF_DEPART_WARP = 1 << 28
const SF_DISABLED = 1 << 29
const SF_DYING = 1 << 30
const SF_KILL_BEFORE_MISSION = 1 << 31
# Combined flags
const SF_ARRIVING = SF_ARRIVING_STAGE_1 | SF_ARRIVING_STAGE_2
const SF_DEPARTING = SF_DEPART_WARP | SF_DEPART_DOCKBAY
const SF_CANNOT_WARP = SF_WARP_BROKEN | SF_WARP_NEVER | SF_DISABLED

# --- Ship Flags 2 (ship.h - SF2_*) ---
const SF2_PRIMITIVE_SENSORS = 1 << 0
const SF2_FRIENDLY_STEALTH_INVIS = 1 << 1
const SF2_STEALTH = 1 << 2
const SF2_DONT_COLLIDE_INVIS = 1 << 3
const SF2_NO_SUBSPACE_DRIVE = 1 << 4
const SF2_NAVPOINT_CARRY = 1 << 5
const SF2_AFFECTED_BY_GRAVITY = 1 << 6
const SF2_TOGGLE_SUBSYSTEM_SCANNING = 1 << 7
const SF2_NO_BUILTIN_MESSAGES = 1 << 8
const SF2_PRIMARIES_LOCKED = 1 << 9
const SF2_SECONDARIES_LOCKED = 1 << 10
const SF2_GLOWMAPS_DISABLED = 1 << 11
const SF2_NO_DEATH_SCREAM = 1 << 12
const SF2_ALWAYS_DEATH_SCREAM = 1 << 13
const SF2_NAVPOINT_NEEDSLINK = 1 << 14
const SF2_HIDE_SHIP_NAME = 1 << 15
const SF2_AFTERBURNER_LOCKED = 1 << 16
# Bit 17 unused
const SF2_SET_CLASS_DYNAMICALLY = 1 << 18
const SF2_LOCK_ALL_TURRETS_INITIALLY = 1 << 19
const SF2_FORCE_SHIELDS_ON = 1 << 20
const SF2_HIDE_LOG_ENTRIES = 1 << 21
const SF2_NO_ARRIVAL_LOG = 1 << 22
const SF2_NO_DEPARTURE_LOG = 1 << 23
const SF2_IS_HARMLESS = 1 << 24

# --- Physics Flags (object.h - PF_*) ---
const PF_ACCELERATES = 1 << 0
const PF_DEAD_DAMP = 1 << 1 # Apply heavy damping when object is dead
const PF_REDUCED_DAMP = 1 << 2 # Apply reduced damping when object is dying
const PF_SLIDING = 1 << 3 # Ship is sliding sideways
const PF_AFTERBURNER_ON = 1 << 4
const PF_GLIDING = 1 << 5 # Ship is gliding (no engine power)
const PF_USE_VEL = 1 << 6 # Use velocity instead of forward thrust
const PF_WARP_IN = 1 << 7 # Ship is warping in
const PF_WARP_OUT = 1 << 8 # Ship is warping out
const PF_SPECIAL_WARP_IN = 1 << 9 # Special warp effect (Knossos)
const PF_BOOSTER_ON = 1 << 10 # Booster pod active
const PF_AFTERBURNER_WAIT = 1 << 11 # Delay before afterburner can re-engage

# --- Weapon Flags (weapon.h - WIF_*, WIF2_*) ---
const WIF_HOMING_HEAT = 1 << 0
const WIF_HOMING_ASPECT = 1 << 1
const WIF_ELECTRONICS = 1 << 2
const WIF_SPAWN = 1 << 3
const WIF_REMOTE = 1 << 4
const WIF_PUNCTURE = 1 << 5
const WIF_SUPERCAP = 1 << 6
const WIF_CMEASURE = 1 << 7
const WIF_HOMING_JAVELIN = 1 << 8
const WIF_TURNS = 1 << 9
const WIF_SWARM = 1 << 10
const WIF_TRAIL = 1 << 11
const WIF_BIG_ONLY = 1 << 12
const WIF_CHILD = 1 << 13
const WIF_BOMB = 1 << 14
const WIF_HUGE = 1 << 15
const WIF_NO_DUMBFIRE = 1 << 16
const WIF_THRUSTER = 1 << 17
const WIF_IN_TECH_DATABASE = 1 << 18
const WIF_PLAYER_ALLOWED = 1 << 19
const WIF_BOMBER_PLUS = 1 << 20
const WIF_CORKSCREW = 1 << 21
const WIF_PARTICLE_SPEW = 1 << 22
const WIF_EMP = 1 << 23
const WIF_ENERGY_SUCK = 1 << 24
const WIF_FLAK = 1 << 25
const WIF_BEAM = 1 << 26
const WIF_TAG = 1 << 27
const WIF_SHUDDER = 1 << 28
const WIF_MFLASH = 1 << 29
const WIF_LOCKARM = 1 << 30
const WIF_STREAM = 1 << 31
# Combined Weapon Flags
const WIF_HOMING = WIF_HOMING_HEAT | WIF_HOMING_ASPECT | WIF_HOMING_JAVELIN
const WIF_LOCKED_HOMING = WIF_HOMING_ASPECT | WIF_HOMING_JAVELIN
const WIF_HURTS_BIG_SHIPS = WIF_BOMB | WIF_BEAM | WIF_HUGE | WIF_BIG_ONLY

const WIF2_BALLISTIC = 1 << 0
const WIF2_PIERCE_SHIELDS = 1 << 1
const WIF2_DEFAULT_IN_TECH_DATABASE = 1 << 2
const WIF2_LOCAL_SSM = 1 << 3
const WIF2_TAGGED_ONLY = 1 << 4
const WIF2_CYCLE = 1 << 5
const WIF2_SMALL_ONLY = 1 << 6
const WIF2_SAME_TURRET_COOLDOWN = 1 << 7
const WIF2_MR_NO_LIGHTING = 1 << 8
const WIF2_TRANSPARENT = 1 << 9
const WIF2_TRAINING = 1 << 10
const WIF2_SMART_SPAWN = 1 << 11
const WIF2_INHERIT_PARENT_TARGET = 1 << 12
const WIF2_NO_EMP_KILL = 1 << 13
const WIF2_VARIABLE_LEAD_HOMING = 1 << 14
const WIF2_UNTARGETED_HEAT_SEEKER = 1 << 15
const WIF2_HARD_TARGET_BOMB = 1 << 16
const WIF2_NON_SUBSYS_HOMING = 1 << 17
const WIF2_NO_LIFE_LOST_IF_MISSED = 1 << 18
const WIF2_CUSTOM_SEEKER_STR = 1 << 19
const WIF2_CAN_BE_TARGETED = 1 << 20
const WIF2_SHOWN_ON_RADAR = 1 << 21
const WIF2_SHOW_FRIENDLY = 1 << 22
const WIF2_CAPITAL_PLUS = 1 << 23

# --- Weapon Subtypes (weapon.h - WP_*) ---
enum WeaponSubtype {
	UNUSED = -1,
	LASER = 0,
	MISSILE = 1,
	BEAM = 2
}

# --- Weapon Render Types (weapon.h - WRT_*) ---
enum WeaponRenderType {
	NONE = -1,
	LASER = 1,
	POF = 2
}

# --- Subsystem Types (model.h - SUBSYSTEM_*) ---
enum SubsystemType {
	ENGINE = 0,
	TURRET = 1,
	RADAR = 2,
	NAVIGATION = 3,
	COMMUNICATION = 4,
	WEAPONS = 5,
	SENSORS = 6,
	SOLAR = 7,
	GAS_COLLECT = 8,
	ACTIVATION = 9,
	UNKNOWN = 10,
	# MAX = 11 # Use count instead
}
const SUBSYSTEM_MAX = 11

# --- Subsystem Status Flags (ship.h - SSF_*, SSSF_*) ---
const SSF_CARGO_REVEALED = 1 << 0
const SSF_UNTARGETABLE = 1 << 1
const SSF_NO_SS_TARGETING = 1 << 2
const SSF_HAS_FIRED = 1 << 3

const SSSF_ALIVE = 1 << 0
const SSSF_DEAD = 1 << 1
const SSSF_ROTATE = 1 << 2
const SSSF_TURRET_ROTATION = 1 << 3

# --- Model Subsystem Flags (model.h - MSS_FLAG_*) ---
const MSS_FLAG_ROTATES = 1 << 0
const MSS_FLAG_TURRET = 1 << 1
const MSS_FLAG_AWACS = 1 << 2
const MSS_FLAG_AI_REPAIR = 1 << 3
const MSS_FLAG_CARRY_NO_DAMAGE = 1 << 4
const MSS_FLAG_CARRY_SHOCKWAVE = 1 << 5
const MSS_FLAG_LOCKABLE = 1 << 6
const MSS_FLAG_ROTATES_LIMITED = 1 << 7
const MSS_FLAG_TURRET_ALT_MATH = 1 << 8

# --- Shield Quadrants ---
const SHIELD_QUADRANT_FRONT = 0
const SHIELD_QUADRANT_RIGHT = 1
const SHIELD_QUADRANT_REAR = 2
const SHIELD_QUADRANT_LEFT = 3
const MAX_SHIELD_SECTIONS = 4

# --- EMP Constants ---
const EMP_INTENSITY_MAX = 500.0
const EMP_TIME_MAX = 30.0
const EMP_DEFAULT_INTENSITY = 300.0
const EMP_DEFAULT_TIME = 10.0

# --- Energy Suck Constants ---
const ESUCK_DEFAULT_WEAPON_REDUCE = 10.0
const ESUCK_DEFAULT_AFTERBURNER_REDUCE = 10.0

# --- Countermeasure Constants ---
const MAX_CMEASURE_TRACK_DIST = 100.0 # Example, adjust based on FS2 value

# --- Beam Constants ---
const BEAM_FAR_LENGTH = 30000.0

# --- Resource Paths (Adjust if structure changes) ---
const WEAPON_DATA_PATH = "res://resources/weapons/"
const SHIP_DATA_PATH = "res://resources/ships/"
const ARMOR_DATA_PATH = "res://resources/armor/"
# Add paths for other resources as needed

# --- Global Lists (Loaded at runtime, e.g., in GameManager or specific managers) ---
# These store the *names* (or base filenames) of the resources.
# The helper functions will construct the full path and load them.
var weapon_list: Array[String] = [] # Array of weapon names (e.g., "LaserLight", "HeatSeeker")
var ship_list: Array[String] = []   # Array of ship names (e.g., "Hercules", "Orion")
var armor_list: Array[String] = []  # Array of armor type names (e.g., "Fighter Hull", "CapShip Plating")
var species_list: Array[SpeciesInfo] = [] # Array of loaded SpeciesInfo resources
var damage_type_list: Array[String] = [] # Array of damage type names

# --- Resource Caches ---
# Dictionaries to cache loaded resources to avoid reloading frequently
var _weapon_cache: Dictionary = {}
var _ship_cache: Dictionary = {}
var _armor_cache: Dictionary = {}

# --- Initialization Function (Called by GameManager or similar) ---
static func load_resource_lists():
	# TODO: Implement loading logic. This should parse relevant tables (ships.tbl, weapons.tbl, etc.)
	# or read pre-converted index files/resources to populate the *_list arrays.
	# Example (Conceptual):
	# weapon_list = _parse_table_get_names("weapons.tbl")
	# ship_list = _parse_table_get_names("ships.tbl")
	# armor_list = _parse_table_get_names("armor.tbl") # Assuming an armor table exists
	# species_list = _load_all_species_resources("res://resources/game_data/species/")
	# damage_type_list = _load_damage_types() # From armor.tbl or dedicated file?

	# Clear caches when lists are reloaded
	_weapon_cache.clear()
	_ship_cache.clear()
	_armor_cache.clear()
	print("GlobalConstants: Resource lists loaded (Placeholder).")


# --- Helper Functions ---
# Get WeaponData by index, handling loading and caching
static func get_weapon_data(index: int) -> WeaponData:
	if index < 0 or index >= weapon_list.size():
		printerr("Invalid weapon index requested: ", index)
		return null

	# Check cache first
	if _weapon_cache.has(index):
		return _weapon_cache[index]

	# Load resource
	var weapon_name = weapon_list[index]
	var path = WEAPON_DATA_PATH + weapon_name + ".tres" # Assuming .tres extension
	var res = load(path)
	if res is WeaponData:
		_weapon_cache[index] = res # Cache loaded resource
		return res
	else:
		printerr("Failed to load WeaponData at path: ", path)
		return null

# Get ShipData by index, handling loading and caching
static func get_ship_data(index: int) -> ShipData:
	if index < 0 or index >= ship_list.size():
		printerr("Invalid ship index requested: ", index)
		return null

	if _ship_cache.has(index):
		return _ship_cache[index]

	var ship_name = ship_list[index]
	var path = SHIP_DATA_PATH + ship_name + ".tres"
	var res = load(path)
	if res is ShipData:
		_ship_cache[index] = res
		return res
	else:
		printerr("Failed to load ShipData at path: ", path)
		return null

# Get ArmorData by index, handling loading and caching
static func get_armor_data(index: int) -> ArmorData:
	if index < 0 or index >= armor_list.size():
		printerr("Invalid armor index requested: ", index)
		return null

	if _armor_cache.has(index):
		return _armor_cache[index]

	var armor_name = armor_list[index]
	var path = ARMOR_DATA_PATH + armor_name + ".tres"
	var res = load(path)
	if res is ArmorData:
		_armor_cache[index] = res
		return res
	else:
		printerr("Failed to load ArmorData at path: ", path)
		return null

# TODO: Add helper functions for species, damage types if needed.
# TODO: Add other global constants as identified during implementation.
