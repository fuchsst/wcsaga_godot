# scripts/globals/global_constants.gd
# Defines global constants and enums used throughout the game.
# Also provides helper functions for looking up resource indices by name.
# This is an autoload singleton - no class_name needed
extends Node

# --- Preload Resource Definitions (Needed for lookups) ---
# Preload resource *scripts* to access their class definitions if needed,
# but actual resource loading happens in _ready() or load_resource_lists()
const ShipData = preload("res://scripts/resources/ship_weapon/ship_data.gd")
const WeaponData = preload("res://scripts/resources/ship_weapon/weapon_data.gd")
const PersonaData = preload("res://scripts/resources/mission/persona_data.gd")
const SpeciesInfo = preload("res://scripts/resources/game_data/species_info.gd")
const ArmorData = preload("res://scripts/resources/ship_weapon/armor_data.gd")
# const IffDefsData = preload("res://resources/game_data/iff_defs.tres") # TODO: create when resource exists

# --- Object Types (Mirroring OBJ_*) ---
enum ObjectType {
	NONE = 0, SHIP = 1, WEAPON = 2, FIREBALL = 3, START = 4, WAYPOINT = 5,
	ASTEROID = 6, DEBRIS = 7, GHOST = 8, POINT = 9, SHOCKWAVE = 10, WING = 11,
	GHOST_SAVE = 12, OBSERVER = 13, JUMP_NODE = 14, BEAM = 15,
	UNKNOWN = 16 # Fallback
}

# --- Object Flags (Mirroring OF_*) ---
const OF_RENDERS					= (1<<0)
const OF_COLLIDES					= (1<<1)
const OF_PHYSICS					= (1<<2)
const OF_SHOULD_BE_DEAD			    = (1<<3)
const OF_INVULNERABLE				= (1<<4)
const OF_PROTECTED					= (1<<5)  # ship is protected
const OF_PLAYER_SHIP				= (1<<6)  # is this the player?
const OF_NO_SHIELDS					= (1<<7)  # Ship has no shields
const OF_JUST_UPDATED				= (1<<8)  # Network flag used to indicate that we just got an update for this object
const OF_COULD_BE_PLAYER			= (1<<9)  # This ship is potentially a player ship.
const OF_WAS_RENDERED				= (1<<10) # Set if object rendered last frame
const OF_NOT_IN_COLL				= (1<<11) # This object is not in the collision pair list
const OF_BEAM_PROTECTED			    = (1<<12) # Ship is protected against beam weapons
const OF_SPECIAL_WARPIN			    = (1<<13) # Ship is using special warp in effect (Knossos device)
const OF_DOCKED_ALREADY_HANDLED	    = (1<<14) # Internal flag used when moving docked objects
const OF_TARGETABLE_AS_BOMB		    = (1<<15) # Is this object targetable as a bomb?
# const OF_MARKED					= (1<<17) # Internal use
# const OF_TEMP_MARKED				= (1<<18) # Internal use
# const OF_REFERENCED				= (1<<19) # Internal use
const OF_HIDDEN					    = (1<<20) # Should this object be hidden?

# --- Ship Flags (ship.h - SF_*) ---
const SF_IGNORE_COUNT				= (1<<0)	# this ship should not count towards goals
const SF_REINFORCEMENT				= (1<<1)	# this ship is a reinforcement
const SF_ESCORT						= (1<<2)	# this ship is an escort ship
const SF_NO_ARRIVAL_MUSIC			= (1<<3)	# Don't play arrival music when this ship arrives
const SF_NO_ARRIVAL_WARP			= (1<<4)	# Ship does not create warp effect upon arrival
const SF_NO_DEPARTURE_WARP			= (1<<5)	# Ship does not create warp effect upon departure
const SF_LOCKED						= (1<<6)	# Ship cannot be targeted by player
# Bits 7-11 unused in SF
const SF_WARPED_SUPPORT				= (1<<12)	# support ship has successfully warped out
const SF_SCANNABLE					= (1<<13)	# ship is scannable
const SF_HIDDEN_FROM_SENSORS		= (1<<14)	# Ship is hidden from sensors - like stealth, but maybe not targeted? Check usage.
const SF_AMMO_COUNT_RECORDED		= (1<<15)	# Has the initial ammo count been recorded?
const SF_TRIGGER_DOWN				= (1<<16)	# Is the trigger down?
const SF_WARP_NEVER					= (1<<17)	# Ship can never warp out
const SF_WARP_BROKEN				= (1<<18)	# Ship warp drive is broken
const SF_SECONDARY_DUAL_FIRE		= (1<<19)	# Ship can fire secondaries from two banks simultaneously
const SF_PRIMARY_LINKED				= (1<<20)	# Primary weapons are linked
const SF_FROM_PLAYER_WING			= (1<<21)	# Ship is in a wing that the player starts in
const SF_CARGO_REVEALED				= (1<<22)	# Cargo has been revealed
const SF_DOCK_LEADER				= (1<<23)	# Leader of a docking group (internal parse flag)
const SF_ENGINES_ON					= (1<<24)	# Ship engines are on
const SF_ARRIVING_STAGE_2			= (1<<25)	# Ship is arriving via warp (stage 2)
const SF_ARRIVING_STAGE_1			= (1<<26)	# Ship is arriving via warp (stage 1)
const SF_DEPART_DOCKBAY				= (1<<27)	# Ship is departing via docking bay
const SF_DEPART_WARP				= (1<<28)	# Ship is departing via warp
const SF_DISABLED					= (1<<29)	# Ship is disabled
const SF_DYING						= (1<<30)	# Ship is dying
const SF_KILL_BEFORE_MISSION		= (1<<31)	# Ship should be destroyed before mission starts (FRED flag)
# Combined flags
const SF_ARRIVING					= SF_ARRIVING_STAGE_1 | SF_ARRIVING_STAGE_2
const SF_DEPARTING					= SF_DEPART_WARP | SF_DEPART_DOCKBAY
const SF_CANNOT_WARP				= SF_WARP_BROKEN | SF_WARP_NEVER | SF_DISABLED

# --- Ship Flags 2 (ship.h - SF2_*) ---
const SF2_PRIMITIVE_SENSORS			= (1<<0)	# Ship has primitive sensors (can't target bombs, etc.)
const SF2_FRIENDLY_STEALTH_INVIS	= (1<<1)	# Ship is invisible to friendly sensors when stealth
const SF2_STEALTH					= (1<<2)	# Ship is stealthy
const SF2_DONT_COLLIDE_INVIS		= (1<<3)	# Ship does not collide when invisible
const SF2_NO_SUBSPACE_DRIVE			= (1<<4)	# Ship has no subspace drive
const SF2_NAVPOINT_CARRY			= (1<<5)	# Ship carries navpoint status
const SF2_AFFECTED_BY_GRAVITY		= (1<<6)	# Ship is affected by gravity wells
const SF2_TOGGLE_SUBSYSTEM_SCANNING	= (1<<7)	# Subsystem scanning state can be toggled
const SF2_NO_BUILTIN_MESSAGES		= (1<<8)	# Ship does not send built-in messages
const SF2_PRIMARIES_LOCKED			= (1<<9)	# Primary weapons are locked
const SF2_SECONDARIES_LOCKED		= (1<<10)	# Secondary weapons are locked
const SF2_GLOWMAPS_DISABLED			= (1<<11)	# Glow maps are disabled for this ship
const SF2_NO_DEATH_SCREAM			= (1<<12)	# Ship does not play death scream
const SF2_ALWAYS_DEATH_SCREAM		= (1<<13)	# Ship always plays death scream (even if not small ship)
const SF2_NAVPOINT_NEEDSLINK		= (1<<14)	# Navpoint needs linking (FRED flag)
const SF2_HIDE_SHIP_NAME			= (1<<15)	# Hide ship name on HUD (FRED flag)
const SF2_AFTERBURNER_LOCKED		= (1<<16)	# Afterburner is locked
# Bit 17 unused
const SF2_SET_CLASS_DYNAMICALLY		= (1<<18)	# Ship class can be changed dynamically (multiplayer loadout)
const SF2_LOCK_ALL_TURRETS_INITIALLY = (1<<19)	# All turrets start locked
const SF2_FORCE_SHIELDS_ON			= (1<<20)	# Force shields on even if ship class has none
const SF2_HIDE_LOG_ENTRIES			= (1<<21)	# Hide log entries related to this ship
const SF2_NO_ARRIVAL_LOG			= (1<<22)	# Don't log arrival
const SF2_NO_DEPARTURE_LOG			= (1<<23)	# Don't log departure
const SF2_IS_HARMLESS				= (1<<24)	# Ship is harmless (won't attack)

# --- Physics Flags (object.h - PF_*) ---
const PF_ACCELERATES				= (1<<0)	# Means object is accelerating this frame
const PF_DEAD_DAMP					= (1<<1)	# Apply heavy damping when object is dead
const PF_REDUCED_DAMP				= (1<<2)	# Apply reduced damping when object is dying
const PF_SLIDING					= (1<<3)	# Ship is sliding sideways
const PF_AFTERBURNER_ON				= (1<<4)	# Ship has afterburner engaged
const PF_GLIDING					= (1<<5)	# Ship is gliding (no engine power)
const PF_USE_VEL					= (1<<6)	# Use velocity instead of forward thrust (docking/warp)
const PF_WARP_IN					= (1<<7)	# Ship is warping in
const PF_WARP_OUT					= (1<<8)	# Ship is warping out
const PF_SPECIAL_WARP_IN			= (1<<9)	# Special warp effect (Knossos device)
const PF_BOOSTER_ON					= (1<<10)	# Booster pod active
const PF_AFTERBURNER_WAIT			= (1<<11)	# Delay before afterburner can re-engage

# --- Weapon Flags (weapon.h - WIF_*) ---
const WIF_HOMING_HEAT				= (1<<0)	# heat seeking homing
const WIF_HOMING_ASPECT				= (1<<1)	# aspect seeking homing
const WIF_ELECTRONICS				= (1<<2)	# weapon has electronic effect (like emp)
const WIF_SPAWN						= (1<<3)	# weapon spawns something (like swarm)
const WIF_REMOTE					= (1<<4)	# weapon is remote detonated
const WIF_PUNCTURE					= (1<<5)	# weapon punctures shields
const WIF_SUPERCAP					= (1<<6)	# weapon damages supercaps to some degree
const WIF_CMEASURE					= (1<<7)	# weapon is a countermeasure
const WIF_HOMING_JAVELIN			= (1<<8)	# javelin style heat seeker
const WIF_TURNS						= (1<<9)	# weapon turns
const WIF_SWARM						= (1<<10)	# weapon is a swarmer
const WIF_TRAIL						= (1<<11)	# weapon leaves a trail
const WIF_BIG_ONLY					= (1<<12)	# weapon only collides with big ships
const WIF_CHILD						= (1<<13)	# weapon is a child object (spawned)
const WIF_BOMB						= (1<<14)	# weapon is a bomb
const WIF_HUGE						= (1<<15)	# weapon is huge (does lots of damage)
const WIF_NO_DUMBFIRE				= (1<<16)	# weapon cannot be dumbfired
const WIF_THRUSTER					= (1<<17)	# weapon has thruster effects
const WIF_IN_TECH_DATABASE			= (1<<18)	# weapon is viewable in tech database
const WIF_PLAYER_ALLOWED			= (1<<19)	# weapon is allowed for player loadout
const WIF_BOMBER_PLUS				= (1<<20)	# weapon is allowed for bombers and ships that can carry bombs
const WIF_CORKSCREW					= (1<<21)	# weapon uses corkscrew movement
const WIF_PARTICLE_SPEW				= (1<<22)	# weapon spews particles
const WIF_EMP						= (1<<23)	# weapon is EMP
const WIF_ENERGY_SUCK				= (1<<24)	# weapon sucks energy
const WIF_FLAK						= (1<<25)	# weapon is flak
const WIF_BEAM						= (1<<26)	# weapon is a beam
const WIF_TAG						= (1<<27)	# weapon TAGs its target
const WIF_SHUDDER					= (1<<28)	# weapon causes screen shudder on impact
const WIF_MFLASH					= (1<<29)	# weapon has muzzle flash
const WIF_LOCKARM					= (1<<30)	# weapon requires lock to arm
const WIF_STREAM					= (1<<31)	# weapon is a stream (like flak)
# Combined Weapon Flags
const WIF_HOMING					= WIF_HOMING_HEAT | WIF_HOMING_ASPECT | WIF_HOMING_JAVELIN
const WIF_LOCKED_HOMING				= WIF_HOMING_ASPECT | WIF_HOMING_JAVELIN
const WIF_HURTS_BIG_SHIPS			= WIF_BOMB | WIF_BEAM | WIF_HUGE | WIF_BIG_ONLY

# --- Weapon Flags 2 (weapon.h - WIF2_*) ---
const WIF2_BALLISTIC				= (1<<0)	# weapon is ballistic (affected by gravity)
const WIF2_PIERCE_SHIELDS			= (1<<1)	# weapon pierces shields
const WIF2_DEFAULT_IN_TECH_DATABASE	= (1<<2)	# weapon is viewable by default in tech database
const WIF2_LOCAL_SSM				= (1<<3)	# weapon is a local secondary swarm missile
const WIF2_TAGGED_ONLY				= (1<<4)	# weapon only hits tagged targets
const WIF2_CYCLE					= (1<<5)	# weapon cycles through banks when firing
const WIF2_SMALL_ONLY				= (1<<6)	# weapon only collides with small ships
const WIF2_SAME_TURRET_COOLDOWN		= (1<<7)	# turret cooldown applies to all guns on turret
const WIF2_MR_NO_LIGHTING			= (1<<8)	# weapon model should not be lit
const WIF2_TRANSPARENT				= (1<<9)	# weapon model is transparent
const WIF2_TRAINING					= (1<<10)	# weapon is used in training missions
const WIF2_SMART_SPAWN				= (1<<11)	# smart spawn (swarm missiles)
const WIF2_INHERIT_PARENT_TARGET	= (1<<12)	# inherit target from parent weapon
const WIF2_NO_EMP_KILL				= (1<<13)	# EMP effect does not kill weapon
const WIF2_VARIABLE_LEAD_HOMING		= (1<<14)	# homing uses variable lead time
const WIF2_UNTARGETED_HEAT_SEEKER	= (1<<15)	# heat seeker that doesn't require lock
const WIF2_HARD_TARGET_BOMB			= (1<<16)	# bomb that requires hard lock
const WIF2_NON_SUBSYS_HOMING		= (1<<17)	# homing missile that doesn't target subsystems
const WIF2_NO_LIFE_LOST_IF_MISSED	= (1<<18)	# lifetime not reduced if missile misses
const WIF2_CUSTOM_SEEKER_STR		= (1<<19)	# uses custom seeker strength
const WIF2_CAN_BE_TARGETED			= (1<<20)	# weapon can be targeted
const WIF2_SHOWN_ON_RADAR			= (1<<21)	# weapon appears on radar
const WIF2_SHOW_FRIENDLY			= (1<<22)	# friendly weapons appear on radar
const WIF2_CAPITAL_PLUS				= (1<<23)	# weapon allowed on capital ships and larger

# --- Wing Flags (ship.h - WF_*) ---
const WF_IGNORE_COUNT				= (1<<0)	# ignore this wing for counting purposes
const WF_REINFORCEMENT				= (1<<1)	# this wing is a reinforcement
const WF_NO_ARRIVAL_MUSIC			= (1<<2)	# don't play arrival music for this wing
const WF_NO_ARRIVAL_MESSAGE			= (1<<3)	# don't display arrival message for this wing
const WF_NO_ARRIVAL_WARP			= (1<<4)	# ships in wing do not warp in
const WF_NO_DEPARTURE_WARP			= (1<<5)	# ships in wing do not warp out
const WF_NO_DYNAMIC					= (1<<6)	# ships in wing do not have dynamic goals assigned
const WF_NAV_CARRY					= (1<<7)	# wing carries navpoint status
const WF_EXPANDED					= (1<<8)	# wing is expanded in ship select (runtime flag)
const WF_NEVER_EXISTED				= (1<<9)	# wing never existed (e.g., mothership destroyed before arrival)
const WF_WING_GONE					= (1<<10)	# wing has departed or been destroyed
const WF_WING_DEPARTING				= (1<<11)	# wing is currently departing
const WF_RESET_REINFORCEMENT		= (1<<12)	# wing is a reinforcement that needs resetting
const WF_NO_ARRIVAL_LOG				= (1<<13)	# don't log arrival
const WF_NO_DEPARTURE_LOG			= (1<<14)	# don't log departure

# --- Parse Object Flags (missionparse.h - P_*) ---
const P_SF_CARGO_KNOWN				= (1<<0)
const P_SF_IGNORE_COUNT				= (1<<1)
const P_OF_PROTECTED				= (1<<2)
const P_SF_REINFORCEMENT			= (1<<3)
const P_OF_NO_SHIELDS				= (1<<4)
const P_SF_ESCORT					= (1<<5)
const P_OF_PLAYER_START				= (1<<6)
const P_SF_NO_ARRIVAL_MUSIC			= (1<<7)
const P_SF_NO_ARRIVAL_WARP			= (1<<8)
const P_SF_NO_DEPARTURE_WARP		= (1<<9)
const P_SF_LOCKED					= (1<<10)
const P_OF_INVULNERABLE				= (1<<11)
const P_SF_HIDDEN_FROM_SENSORS		= (1<<12)
const P_SF_SCANNABLE				= (1<<13)
const P_AIF_KAMIKAZE				= (1<<14)
const P_AIF_NO_DYNAMIC				= (1<<15)
const P_SF_RED_ALERT_STORE_STATUS	= (1<<16)
const P_OF_BEAM_PROTECTED			= (1<<17)
const P_SF_GUARDIAN					= (1<<18)
const P_KNOSSOS_WARP_IN				= (1<<19)
const P_SF_VAPORIZE					= (1<<20)
const P_SF2_STEALTH					= (1<<21)
const P_SF2_FRIENDLY_STEALTH_INVIS	= (1<<22)
const P_SF2_DONT_COLLIDE_INVIS		= (1<<23)
# Bits 24, 25 unused
const P_SF_USE_UNIQUE_ORDERS		= (1<<26)
const P_SF_DOCK_LEADER				= (1<<27)
const P_SF_CANNOT_ARRIVE			= (1<<28) # Internal flag
const P_SF_WARP_BROKEN				= (1<<29)
const P_SF_WARP_NEVER				= (1<<30)
const P_SF_PLAYER_START_VALID		= (1<<31) # Internal flag

# --- Parse Object Flags 2 (missionparse.h - P2_*) ---
const P2_SF2_PRIMITIVE_SENSORS			= (1<<0)
const P2_SF2_NO_SUBSPACE_DRIVE			= (1<<1)
const P2_SF2_NAV_CARRY_STATUS			= (1<<2)
const P2_SF2_AFFECTED_BY_GRAVITY		= (1<<3)
const P2_SF2_TOGGLE_SUBSYSTEM_SCANNING	= (1<<4)
const P2_OF_TARGETABLE_AS_BOMB			= (1<<5)
const P2_SF2_NO_BUILTIN_MESSAGES		= (1<<6)
const P2_SF2_PRIMARIES_LOCKED			= (1<<7)
const P2_SF2_SECONDARIES_LOCKED			= (1<<8)
const P2_SF2_NO_DEATH_SCREAM			= (1<<9)
const P2_SF2_ALWAYS_DEATH_SCREAM		= (1<<10)
const P2_SF2_NAV_NEEDSLINK				= (1<<11)
const P2_SF2_HIDE_SHIP_NAME				= (1<<12)
const P2_SF2_SET_CLASS_DYNAMICALLY		= (1<<13)
const P2_SF2_LOCK_ALL_TURRETS_INITIALLY	= (1<<14)
const P2_SF2_AFTERBURNER_LOCKED			= (1<<15)
const P2_OF_FORCE_SHIELDS_ON			= (1<<16)
const P2_SF2_HIDE_LOG_ENTRIES			= (1<<17)
const P2_SF2_NO_ARRIVAL_LOG				= (1<<18)
const P2_SF2_NO_DEPARTURE_LOG			= (1<<19)
const P2_SF2_IS_HARMLESS				= (1<<20)
# Bit 31 reserved for internal use (P2_ALREADY_HANDLED)

# --- Briefing Icon Flags (missionbriefcommon.h - BI_*) ---
const BI_HIGHLIGHT					= (1<<0)
const BI_SHOWHIGHLIGHT				= (1<<1) # Runtime flag
const BI_FADEIN						= (1<<2) # Runtime flag
const BI_MIRROR_ICON				= (1<<3)

# --- Mission Goal Flags (missiongoals.h - MGF_*) ---
const MGF_NO_MUSIC					= (1<<0)

# --- Mission Event Flags (missiongoals.h - MEF_*) ---
const MEF_CURRENT					= (1<<0) # Runtime flag
const MEF_DIRECTIVE_SPECIAL			= (1<<1) # Runtime flag
const MEF_DIRECTIVE_TEMP_TRUE		= (1<<2) # Runtime flag
const MEF_USING_TRIGGER_COUNT		= (1<<3) # Set if trigger count > 1

# --- Persona Flags (missionmessage.h - PERSONA_FLAG_*) ---
const PERSONA_FLAG_WINGMAN			= (1<<0)
const PERSONA_FLAG_SUPPORT			= (1<<1)
const PERSONA_FLAG_LARGE			= (1<<2)
const PERSONA_FLAG_COMMAND			= (1<<3)
# const PERSONA_FLAG_VASUDAN		= (1<<30) # Not needed? Species index used instead.
# const PERSONA_FLAG_USED			= (1<<31) # Runtime flag

# --- Ranks (Mirroring RANK_*) ---
enum Rank {
	ENSIGN = 0, LT_JUNIOR = 1, LT = 2, LT_CMDR = 3, CMDR = 4, CAPTAIN = 5,
	COMMODORE = 6, REAR_ADMIRAL = 7, VICE_ADMIRAL = 8, ADMIRAL = 9
}
const NUM_RANKS = 10

# --- Medals ---
const MAX_MEDALS = 19 # From medals.cpp

# --- Ship Classes ---
const MAX_SHIP_CLASSES = 130 # From globals.h (MAX_SHIP_CLASSES_MULTI)

# --- Game States (Mirroring GS_STATE_*) ---
enum GameState {
	NONE = 0, MAIN_MENU = 1, GAME_PLAY = 2, GAME_PAUSED = 3, QUIT_GAME = 4,
	OPTIONS_MENU = 5, BARRACKS_MENU = 6, TECH_MENU = 7, TRAINING_MENU = 8,
	LOAD_MISSION_MENU = 9, BRIEFING = 10, SHIP_SELECT = 11, DEBUG_PAUSED = 12,
	HUD_CONFIG = 13, MULTI_JOIN_GAME = 14, CONTROL_CONFIG = 15, WEAPON_SELECT = 16,
	MISSION_LOG_SCROLLBACK = 17, DEATH_DIED = 18, DEATH_BLEW_UP = 19, SIMULATOR_ROOM = 20,
	CREDITS = 21, SHOW_GOALS = 22, HOTKEY_SCREEN = 23, VIEW_MEDALS = 24,
	MULTI_HOST_SETUP = 25, MULTI_CLIENT_SETUP = 26, DEBRIEF = 27, VIEW_CUTSCENES = 28,
	MULTI_STD_WAIT = 29, STANDALONE_MAIN = 30, MULTI_PAUSED = 31, TEAM_SELECT = 32,
	TRAINING_PAUSED = 33, INGAME_PRE_JOIN = 34, EVENT_DEBUG = 35, STANDALONE_POSTGAME = 36,
	INITIAL_PLAYER_SELECT = 37, MULTI_MISSION_SYNC = 38, MULTI_START_GAME = 39,
	MULTI_HOST_OPTIONS = 40, MULTI_DOGFIGHT_DEBRIEF = 41, CAMPAIGN_ROOM = 42,
	CMD_BRIEF = 43, RED_ALERT = 44, END_OF_CAMPAIGN = 45, GAMEPLAY_HELP = 46,
	END_DEMO = 47, LOOP_BRIEF = 48, PXO = 49, LAB = 50, PXO_HELP = 51,
	START_GAME = 52, FICTION_VIEWER = 53
}

# --- Game Events (Mirroring GS_EVENT_*) ---
enum GameEvent {
	MAIN_MENU = 0, START_GAME = 1, ENTER_GAME = 2, START_GAME_QUICK = 3, END_GAME = 4,
	QUIT_GAME = 5, PAUSE_GAME = 6, PREVIOUS_STATE = 7, OPTIONS_MENU = 8, BARRACKS_MENU = 9,
	TRAINING_MENU = 10, TECH_MENU = 11, LOAD_MISSION_MENU = 12, SHIP_SELECTION = 13,
	TOGGLE_FULLSCREEN = 14, START_BRIEFING = 15, DEBUG_PAUSE_GAME = 16, HUD_CONFIG = 17,
	MULTI_JOIN_GAME = 18, CONTROL_CONFIG = 19, EVENT_DEBUG = 20, WEAPON_SELECTION = 21,
	MISSION_LOG_SCROLLBACK = 22, GAMEPLAY_HELP = 23, DEATH_DIED = 24, DEATH_BLEW_UP = 25,
	NEW_CAMPAIGN = 26, CREDITS = 27, SHOW_GOALS = 28, HOTKEY_SCREEN = 29, VIEW_MEDALS = 30,
	MULTI_HOST_SETUP = 31, MULTI_CLIENT_SETUP = 32, DEBRIEF = 33, GOTO_VIEW_CUTSCENES_SCREEN = 34,
	MULTI_STD_WAIT = 35, STANDALONE_MAIN = 36, MULTI_PAUSE = 37, TEAM_SELECT = 38,
	TRAINING_PAUSE = 39, INGAME_PRE_JOIN = 40, PLAYER_WARPOUT_START = 41,
	PLAYER_WARPOUT_START_FORCED = 42, PLAYER_WARPOUT_STOP = 43, PLAYER_WARPOUT_DONE_STAGE1 = 44,
	PLAYER_WARPOUT_DONE_STAGE2 = 45, PLAYER_WARPOUT_DONE = 46, STANDALONE_POSTGAME = 47,
	INITIAL_PLAYER_SELECT = 48, GAME_INIT = 49, MULTI_MISSION_SYNC = 50, MULTI_START_GAME = 51,
	MULTI_HOST_OPTIONS = 52, MULTI_DOGFIGHT_DEBRIEF = 53, CAMPAIGN_ROOM = 54, CMD_BRIEF = 55,
	TOGGLE_GLIDE = 56, RED_ALERT = 57, SIMULATOR_ROOM = 58, END_CAMPAIGN = 59, END_DEMO = 60,
	LOOP_BRIEF = 61, CAMPAIGN_CHEAT = 62, PXO = 63, LAB = 64, PXO_HELP = 65, FICTION_VIEWER = 66
}

# --- Hook Condition Types (Mirroring CHC_*) ---
enum HookConditionType {
	NONE = -1, MISSION = 0, SHIP = 1, SHIPCLASS = 2, SHIPTYPE = 3, STATE = 4,
	CAMPAIGN = 5, WEAPONCLASS = 6, OBJECTTYPE = 7, KEYPRESS = 8, VERSION = 9,
	APPLICATION = 10
}

# --- Hook Action Types (Mirroring CHA_*) ---
enum HookActionType {
	NONE = -1, WARPOUT = 0, WARPIN = 1, DEATH = 2, ONFRAME = 3, COLLIDESHIP = 4,
	COLLIDEWEAPON = 5, COLLIDEDEBRIS = 6, COLLIDEASTEROID = 7, HUDDRAW = 8,
	OBJECTRENDER = 9, SPLASHSCREEN = 10, GAMEINIT = 11, MISSIONSTART = 12,
	MISSIONEND = 13, MOUSEMOVED = 14, MOUSEPRESSED = 15, MOUSERELEASED = 16,
	KEYPRESSED = 17, KEYRELEASED = 18, ONSTATESTART = 19, ONSTATEEND = 20
}

# --- Flag Definitions (Mirroring C++) ---
# IFFF Flags
const IFFF_SUPPORT_ALLOWED = (1 << 0)
const IFFF_EXEMPT_FROM_ALL_TEAMS_AT_WAR = (1 << 1)
const IFFF_ORDERS_HIDDEN = (1 << 2)
const IFFF_ORDERS_SHOWN = (1 << 3)
const IFFF_WING_NAME_HIDDEN = (1 << 4)

# --- Statistics Types (Placeholder) ---
enum StatType { SCORE, KILLS_TOTAL }

# --- Global Colors (Mirroring Color_*) ---
const COLOR_BRIGHT_GREEN = Color(0.31, 0.75, 0.31)
const COLOR_BRIGHT_BLUE = Color(0.5, 0.76, 1.0)
const COLOR_BRIGHT_RED = Color(0.78, 0.0, 0.0)
const COLOR_NORMAL = Color(0.75, 0.75, 0.75) # Example (Color_white)
const COLOR_DEBUG = Color(1.0, 0.5, 0.0) # Example

# --- Resource Paths (Adjust if structure changes) ---
const WEAPON_DATA_PATH = "res://resources/weapons/"
const SHIP_DATA_PATH = "res://resources/ships/"
const ARMOR_DATA_PATH = "res://resources/armor/"
const PERSONA_DATA_PATH = "res://resources/messages/personas/"
const IFF_DEFS_PATH = "res://resources/game_data/iff_defs.tres"
const SPECIES_DATA_PATH = "res://resources/game_data/species/"
# Add paths for other resources as needed

# --- Global Lists (Loaded at runtime) ---
# These store the loaded resources or names for lookup.
var weapon_list: Array[WeaponData] = [] # Store loaded resources directly
var ship_list: Array[ShipData] = []   # Store loaded resources directly
var armor_list: Array[String] = []  # Array of armor type names
var species_list: Array[SpeciesInfo] = [] # Array of loaded SpeciesInfo resources
var damage_type_list: Array[String] = [] # Array of damage type names
var persona_list: Array[PersonaData] = [] # Store loaded resources directly
var iff_list: Array[String] = [] # Array of IFF names
var cargo_list: Array[String] = [] # Array of cargo names

# --- Lookup Dictionaries (Populated by load_resource_lists) ---
var _ship_name_to_index: Dictionary = {}
var _weapon_name_to_index: Dictionary = {}
var _armor_name_to_index: Dictionary = {}
var _persona_name_to_index: Dictionary = {}
var _iff_name_to_index: Dictionary = {}
var _species_name_to_index: Dictionary = {}
var _cargo_name_to_index: Dictionary = {}

# --- Initialization Function (Called automatically for Autoloads) ---
func _ready():
	load_resource_lists()

func load_resource_lists():
	print("GlobalConstants: Loading resource lists...")
	# Clear existing lists and caches
	weapon_list.clear()
	ship_list.clear()
	armor_list.clear()
	species_list.clear()
	damage_type_list.clear()
	iff_list.clear()
	persona_list.clear()
	_ship_name_to_index.clear()
	_weapon_name_to_index.clear()
	_armor_name_to_index.clear()
	_persona_name_to_index.clear()
	_iff_name_to_index.clear()
	_species_name_to_index.clear()
	_cargo_name_to_index.clear()

	# --- Load Ship Data ---
	print("Loading ship list...")
	var ship_dir = DirAccess.open(SHIP_DATA_PATH)
	if ship_dir:
		ship_dir.list_dir_begin()
		var file_name = ship_dir.get_next()
		while file_name != "":
			if not ship_dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = load(SHIP_DATA_PATH.path_join(file_name))
				if res is ShipData:
					ship_list.append(res) # Store the loaded resource
				else:
					printerr("Failed to load ShipData resource: " + file_name)
			file_name = ship_dir.get_next()
		ship_dir.list_dir_end()
		# Sort by name for consistent index mapping
		ship_list.sort_custom(func(a, b): return a.ship_name < b.ship_name)
		# Populate lookup dictionary
		for i in range(ship_list.size()):
			_ship_name_to_index[ship_list[i].ship_name.to_lower()] = i
		print("Loaded " + str(ship_list.size()) + " ships.")
	else:
		printerr("Could not open ship resource directory: " + SHIP_DATA_PATH)

	# --- Load Weapon Data ---
	print("Loading weapon list...")
	var weapon_dir = DirAccess.open(WEAPON_DATA_PATH)
	if weapon_dir:
		weapon_dir.list_dir_begin()
		var file_name = weapon_dir.get_next()
		while file_name != "":
			if not weapon_dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = load(WEAPON_DATA_PATH.path_join(file_name))
				if res is WeaponData:
					weapon_list.append(res) # Store the loaded resource
				else:
					printerr("Failed to load WeaponData resource: " + file_name)
			file_name = weapon_dir.get_next()
		weapon_dir.list_dir_end()
		# Sort by name for consistent index mapping
		weapon_list.sort_custom(func(a, b): return a.weapon_name < b.weapon_name)
		# Populate lookup dictionary
		for i in range(weapon_list.size()):
			_weapon_name_to_index[weapon_list[i].weapon_name.to_lower()] = i
		print("Loaded " + str(weapon_list.size()) + " weapons.")
	else:
		printerr("Could not open weapon resource directory: " + WEAPON_DATA_PATH)

	# --- Load Armor Names ---
	print("Loading armor list...")
	var armor_dir = DirAccess.open(ARMOR_DATA_PATH)
	if armor_dir:
		armor_dir.list_dir_begin()
		var file_name = armor_dir.get_next()
		while file_name != "":
			if not armor_dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = load(ARMOR_DATA_PATH.path_join(file_name))
				# Assuming ArmorData resource script exists and has a 'armor_name' property
				if res is ArmorData and res.has("armor_name"):
					armor_list.append(res.armor_name)
				else:
					printerr("Failed to load or get name from armor resource: " + file_name)
			file_name = armor_dir.get_next()
		armor_dir.list_dir_end()
		armor_list.sort()
		# Populate lookup dictionary
		for i in range(armor_list.size()):
			_armor_name_to_index[armor_list[i].to_lower()] = i
		print("Loaded " + str(armor_list.size()) + " armor names.")
	else:
		printerr("Could not open armor resource directory: " + ARMOR_DATA_PATH)

	# --- Load IFF Names ---
	print("Loading IFF list...")
	var iff_res = load(IFF_DEFS_PATH)
	# Assuming IffDefsData resource script exists and has 'iff_names' property
	if iff_res and iff_res.has("iff_names"):
		iff_list = iff_res.iff_names.duplicate() # Assign the loaded names
		# Populate lookup dictionary
		for i in range(iff_list.size()):
			_iff_name_to_index[iff_list[i].to_lower()] = i
		print("Loaded " + str(iff_list.size()) + " IFF names from " + IFF_DEFS_PATH + ".")
	else:
		printerr("Failed to load or parse IFF definitions from: " + IFF_DEFS_PATH + ". Using defaults.")
		# Fallback defaults if loading fails
		iff_list = ["Terran", "Hostile", "Neutral", "Unknown", "Traitor"]
		for i in range(iff_list.size()):
			_iff_name_to_index[iff_list[i].to_lower()] = i

	# --- Load Species Info ---
	print("Loading species list...")
	var species_dir = DirAccess.open(SPECIES_DATA_PATH)
	if species_dir:
		species_dir.list_dir_begin()
		var file_name = species_dir.get_next()
		while file_name != "":
			if not species_dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = load(SPECIES_DATA_PATH.path_join(file_name))
				if res is SpeciesInfo:
					species_list.append(res)
				else:
					printerr("Failed to load SpeciesInfo resource: " + file_name)
			file_name = species_dir.get_next()
		species_dir.list_dir_end()
		# Sort by name? Or rely on file order? Let's sort.
		species_list.sort_custom(func(a, b): return a.species_name < b.species_name)
		# Populate lookup dictionary
		for i in range(species_list.size()):
			_species_name_to_index[species_list[i].species_name.to_lower()] = i
		print("Loaded " + str(species_list.size()) + " species.")
	else:
		printerr("Could not open species resource directory: " + SPECIES_DATA_PATH)

	# --- Load Damage Types ---
	# TODO: Implement loading damage types (maybe from armor types?)
	print("Loading damage types... (TODO)")

	# --- Load Personas ---
	print("Loading persona list...")
	var persona_dir = DirAccess.open(PERSONA_DATA_PATH)
	if persona_dir:
		persona_dir.list_dir_begin()
		var file_name = persona_dir.get_next()
		while file_name != "":
			if not persona_dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = load(PERSONA_DATA_PATH.path_join(file_name))
				if res is PersonaData:
					persona_list.append(res)
				else:
					printerr("Failed to load PersonaData resource: " + file_name)
			file_name = persona_dir.get_next()
		persona_dir.list_dir_end()
		# Sort by name for consistent index mapping? Or rely on load order? Let's sort.
		persona_list.sort_custom(func(a, b): return a.name < b.name)
		# Populate lookup dictionary
		for i in range(persona_list.size()):
			_persona_name_to_index[persona_list[i].name.to_lower()] = i
		print("Loaded " + str(persona_list.size()) + " personas.")
	else:
		printerr("Could not open persona resource directory: " + PERSONA_DATA_PATH)

	# --- Load Cargo Names (Placeholder - needs actual loading from tables.tbl or similar) ---
	print("Loading cargo list... (Placeholder)")
	cargo_list = ["Nothing", "Explosives", "Food", "Medical Supplies", "Parts"] # Example
	for i in range(cargo_list.size()):
		_cargo_name_to_index[cargo_list[i].to_lower()] = i

	print("GlobalConstants: Resource lists loaded.")


# --- Helper Functions ---
	# Get WeaponData by index (list is preloaded)
func get_weapon_data(index: int) -> WeaponData:
	if index < 0 or index >= weapon_list.size():
		printerr("Invalid weapon index requested: ", index)
		return null
	return weapon_list[index]

# Get ShipData by index (list is preloaded)
func get_ship_data(index: int) -> ShipData:
	if index < 0 or index >= ship_list.size():
		printerr("Invalid ship index requested: ", index)
		return null
	return ship_list[index]

# Get ArmorData by index (list is preloaded)
func get_armor_data(index: int) -> Resource: # Return generic Resource
	if index < 0 or index >= armor_list.size():
		printerr("Invalid armor index requested: ", index)
		return null

	# Armor data isn't cached directly, lookup name and load
	var armor_name = armor_list[index]
	# Construct path based on name (assuming lowercase with underscores)
	var file_name = armor_name.to_lower().replace(" ", "_") + ".tres"
	var path = ARMOR_DATA_PATH.path_join(file_name)
	var res = load(path)
	# Check if it's a valid Resource, not specifically ArmorData yet
	if res is Resource:
		return res
	else:
		printerr("Failed to load ArmorData at path: ", path)
		return null

# Get PersonaData by index (list is preloaded)
func get_persona_data(index: int) -> PersonaData:
	if index < 0 or index >= persona_list.size():
		printerr("Invalid persona index requested: ", index)
		return null
	return persona_list[index]

# Helper to find persona index by name (case-insensitive)
func lookup_persona_index(persona_name: String) -> int:
	if persona_name.is_empty():
		return -1
	var lower_name = persona_name.to_lower()
	if _persona_name_to_index.has(lower_name):
		return _persona_name_to_index[lower_name]
	printerr("Persona name not found: '" + persona_name + "'")
	return -1

# Helper to find ship index by name (case-insensitive)
func lookup_ship_index(ship_name: String) -> int:
	if ship_name.is_empty():
		return -1
	var lower_name = ship_name.to_lower()
	if _ship_name_to_index.has(lower_name):
		return _ship_name_to_index[lower_name]
	printerr("Ship name not found: '" + ship_name + "'")
	return -1

# Helper to find weapon index by name (case-insensitive)
func lookup_weapon_index(weapon_name: String) -> int:
	if weapon_name.is_empty():
		return -1
	var lower_name = weapon_name.to_lower()
	if _weapon_name_to_index.has(lower_name):
		return _weapon_name_to_index[lower_name]
	printerr("Weapon name not found: '" + weapon_name + "'")
	return -1

# Helper to find armor index by name (case-insensitive)
func lookup_armor_index(armor_name: String) -> int:
	if armor_name.is_empty():
		return -1
	var lower_name = armor_name.to_lower()
	if _armor_name_to_index.has(lower_name):
		return _armor_name_to_index[lower_name]
	printerr("Armor name not found: '" + armor_name + "'")
	return -1

# Helper to find IFF index by name (case-insensitive)
func lookup_iff_index(iff_name: String) -> int:
	if iff_name.is_empty():
		return -1
	var lower_name = iff_name.to_lower()
	if _iff_name_to_index.has(lower_name):
		return _iff_name_to_index[lower_name]
	printerr("IFF name not found: '" + iff_name + "'")
	return -1 # Or default to a specific IFF?

# Helper to find Species index by name (case-insensitive)
func lookup_species_index(species_name: String) -> int:
	if species_name.is_empty():
		return -1
	var lower_name = species_name.to_lower()
	if _species_name_to_index.has(lower_name):
		return _species_name_to_index[lower_name]
	printerr("Species name not found: '" + species_name + "'")
	return -1 # Or default to Terran (0)?

# --- Goal Types (missiongoals.h - PRIMARY_GOAL, etc.) ---
enum GoalType {
	PRIMARY = 0,
	SECONDARY = 1,
	BONUS = 2,
	INVALID = 1 << 16 # Flag combined with type
}
const GOAL_FLAG_INVALID = GoalType.INVALID # Alias for parser

# --- Physics Layers (Example Setup - Adjust based on project needs) ---
# Layer 1: Ships
# Layer 2: Weapons (Projectiles)
# Layer 3: Asteroids
# Layer 4: Debris
# Layer 5: Jump Nodes
# Layer 6: Beams (Special case, might need separate handling)
# Layer 7: Shockwaves (Area effects)
# ... Reserve others ...
# Layer 10: Environment (Static geometry?)
const COLLISION_LAYER_SHIP = 1 << 0       # 1
const COLLISION_LAYER_WEAPON = 1 << 1     # 2
const COLLISION_LAYER_ASTEROID = 1 << 2   # 4
const COLLISION_LAYER_DEBRIS = 1 << 3     # 8
const COLLISION_LAYER_JUMP_NODE = 1 << 4  # 16
const COLLISION_LAYER_BEAM = 1 << 5       # 32
const COLLISION_LAYER_SHOCKWAVE = 1 << 6  # 64
const COLLISION_LAYER_ENVIRONMENT = 1 << 9 # 512

# --- Collision Masks (What each layer collides WITH) ---
# Ships collide with Ships, Weapons, Asteroids, Debris, Environment
const COLLISION_MASK_SHIP = COLLISION_LAYER_SHIP | COLLISION_LAYER_WEAPON | COLLISION_LAYER_ASTEROID | COLLISION_LAYER_DEBRIS | COLLISION_LAYER_ENVIRONMENT
# Weapons collide with Ships, Asteroids, Debris, Environment (Potentially other weapons? e.g., flak vs missile)
const COLLISION_MASK_WEAPON = COLLISION_LAYER_SHIP | COLLISION_LAYER_ASTEROID | COLLISION_LAYER_DEBRIS | COLLISION_LAYER_ENVIRONMENT # | COLLISION_LAYER_WEAPON
# Asteroids collide with Ships, Weapons, Asteroids, Debris, Environment
const COLLISION_MASK_ASTEROID = COLLISION_LAYER_SHIP | COLLISION_LAYER_WEAPON | COLLISION_LAYER_ASTEROID | COLLISION_LAYER_DEBRIS | COLLISION_LAYER_ENVIRONMENT
# Debris collides with Ships, Weapons, Asteroids, Debris, Environment
const COLLISION_MASK_DEBRIS = COLLISION_LAYER_SHIP | COLLISION_LAYER_WEAPON | COLLISION_LAYER_ASTEROID | COLLISION_LAYER_DEBRIS | COLLISION_LAYER_ENVIRONMENT
# Jump Nodes likely only need to detect Ships entering (using Area3D, mask = SHIP)
const COLLISION_MASK_JUMP_NODE_AREA = COLLISION_LAYER_SHIP
# Beams collide with Ships, Asteroids, Debris (handled by RayCast mask)
const COLLISION_MASK_BEAM = COLLISION_LAYER_SHIP | COLLISION_LAYER_ASTEROID | COLLISION_LAYER_DEBRIS
# Shockwaves affect Ships, Asteroids, Debris, Weapons (handled by query mask)
const COLLISION_MASK_SHOCKWAVE = COLLISION_LAYER_SHIP | COLLISION_LAYER_ASTEROID | COLLISION_LAYER_DEBRIS | COLLISION_LAYER_WEAPON

# --- Goal Type Lookup ---
const _goal_type_map: Dictionary = {
	"primary": GoalType.PRIMARY,
	"secondary": GoalType.SECONDARY,
	"bonus": GoalType.BONUS,
}

func lookup_goal_type(type_name: String) -> int:
	var lower_name = type_name.to_lower()
	if _goal_type_map.has(lower_name):
		return _goal_type_map[lower_name]
	printerr("Unknown goal type name: '" + type_name + "'. Defaulting to PRIMARY.")
	return GoalType.PRIMARY

# --- Cargo Lookup ---
func lookup_cargo_index(cargo_name: String) -> int:
	if cargo_name.is_empty() or cargo_name.to_lower() == "nothing":
		return -1 # Assuming -1 means no cargo
	var lower_name = cargo_name.to_lower()
	if _cargo_name_to_index.has(lower_name):
		return _cargo_name_to_index[lower_name]
	# If not found, maybe add it dynamically? Or require it to be pre-defined?
	# For now, let's add dynamically and warn.
	printerr("Cargo name '" + cargo_name + "' not preloaded. Adding dynamically.")
	var new_index = cargo_list.size()
	cargo_list.append(cargo_name)
	_cargo_name_to_index[lower_name] = new_index
	return new_index

# --- Arrival/Departure Location Lookup ---
const _arrival_location_map: Dictionary = {
	"Hyperspace": 0, "Near Ship": 1, "In front of ship": 2, "Docking Bay": 3,
}
const _departure_location_map: Dictionary = {
	"Hyperspace": 0, "Docking Bay": 1,
}

func lookup_arrival_location(loc_name: String) -> int:
	if _arrival_location_map.has(loc_name):
		return _arrival_location_map[loc_name]
	printerr("Unknown Arrival Location: '" + loc_name + "'. Defaulting to Hyperspace.")
	return 0

func lookup_departure_location(loc_name: String) -> int:
	if _departure_location_map.has(loc_name):
		return _departure_location_map[loc_name]
	printerr("Unknown Departure Location: '" + loc_name + "'. Defaulting to Hyperspace.")
	return 0


# TODO: Add helper functions for damage types if needed.
# TODO: Add other global constants as identified during implementation.
