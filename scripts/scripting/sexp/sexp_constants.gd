# sexp_constants.gd
# Defines constants related to the S-Expression (SEXP) system,
# mirroring values from the original C++ code (parse/sexp.h).

# --- SEXP Node Types ---
const SEXP_NOT_USED: int = 0
const SEXP_LIST: int = 1
const SEXP_ATOM: int = 2

# --- SEXP Atom Subtypes ---
const SEXP_ATOM_LIST: int = 0       # Should not happen? Check original logic.
const SEXP_ATOM_OPERATOR: int = 1
const SEXP_ATOM_NUMBER: int = 2
const SEXP_ATOM_STRING: int = 3

# --- SEXP Evaluation Results ---
const SEXP_TRUE: int = 1
const SEXP_FALSE: int = 0
const SEXP_KNOWN_FALSE: int = -2147483647
const SEXP_KNOWN_TRUE: int = -2147483646
const SEXP_UNKNOWN: int = -2147483645
const SEXP_NAN: int = -2147483644
const SEXP_NAN_FOREVER: int = -2147483643
const SEXP_CANT_EVAL: int = -2147483642
const SEXP_NUM_EVAL: int = -2147483641 # Indicates a numerical result rather than boolean

# --- SEXP Variable Flags ---
const SEXP_VARIABLE_NUMBER: int = (1 << 4)
const SEXP_VARIABLE_STRING: int = (1 << 5)
const SEXP_VARIABLE_UNKNOWN: int = (1 << 6) # Should not be used?
const SEXP_VARIABLE_NOT_USED: int = (1 << 7) # Indicates slot is free
const SEXP_VARIABLE_BLOCK: int = (1 << 0) # Special block variable? Check usage.
const SEXP_VARIABLE_PLAYER_PERSISTENT: int = (1 << 3)
const SEXP_VARIABLE_CAMPAIGN_PERSISTENT: int = (1 << 29)
const SEXP_VARIABLE_NETWORK: int = (1 << 28) # Multiplayer related
const SEXP_VARIABLE_SET: int = (0x0100) # Flag indicating variable is set/used
const SEXP_VARIABLE_MODIFIED: int = (0x0200) # Flag indicating variable was modified

# --- SEXP Operator Flags/Categories ---
# Note: Using hex for easier comparison with C++ defines
const OP_INSERT_FLAG: int = 0x8000
const OP_REPLACE_FLAG: int = 0x4000
const OP_NONCAMPAIGN_FLAG: int = 0x2000
const OP_CAMPAIGN_ONLY_FLAG: int = 0x1000
const FIRST_OP: int = 0x0400
const OP_CATEGORY_MASK: int = 0x0f00

const OP_CATEGORY_OBJECTIVE: int = 0x0400
const OP_CATEGORY_TIME: int = 0x0500
const OP_CATEGORY_LOGICAL: int = 0x0600
const OP_CATEGORY_ARITHMETIC: int = 0x0700
const OP_CATEGORY_STATUS: int = 0x0800
const OP_CATEGORY_CHANGE: int = 0x0900
const OP_CATEGORY_CONDITIONAL: int = 0x0a00
const OP_CATEGORY_AI: int = 0x0b00
const OP_CATEGORY_TRAINING: int = 0x0c00
const OP_CATEGORY_UNLISTED: int = 0x0d00 # Operators not shown in FRED
const OP_CATEGORY_NAVPOINTS: int = 0x0e00
const OP_CATEGORY_GOAL_EVENT: int = 0x0f00

# --- SEXP Operators (Core Set - Expand as needed) ---
# Arithmetic
const OP_PLUS: int = (0x0000 | OP_CATEGORY_ARITHMETIC)
const OP_MINUS: int = (0x0001 | OP_CATEGORY_ARITHMETIC)
const OP_MOD: int = (0x0002 | OP_CATEGORY_ARITHMETIC)
const OP_MUL: int = (0x0003 | OP_CATEGORY_ARITHMETIC)
const OP_DIV: int = (0x0004 | OP_CATEGORY_ARITHMETIC)
const OP_RAND: int = (0x0005 | OP_CATEGORY_ARITHMETIC)
const OP_ABS: int = (0x0006 | OP_CATEGORY_ARITHMETIC)
const OP_MIN: int = (0x0007 | OP_CATEGORY_ARITHMETIC)
const OP_MAX: int = (0x0008 | OP_CATEGORY_ARITHMETIC)
const OP_AVG: int = (0x0009 | OP_CATEGORY_ARITHMETIC)
const OP_RAND_MULTIPLE: int = (0x000a | OP_CATEGORY_ARITHMETIC)

# Logical
const OP_TRUE: int = (0x0000 | OP_CATEGORY_LOGICAL)
const OP_FALSE: int = (0x0001 | OP_CATEGORY_LOGICAL)
const OP_AND: int = (0x0002 | OP_CATEGORY_LOGICAL)
const OP_AND_IN_SEQUENCE: int = (0x0003 | OP_CATEGORY_LOGICAL)
const OP_OR: int = (0x0004 | OP_CATEGORY_LOGICAL)
const OP_EQUALS: int = (0x0005 | OP_CATEGORY_LOGICAL)
const OP_GREATER_THAN: int = (0x0006 | OP_CATEGORY_LOGICAL)
const OP_LESS_THAN: int = (0x0007 | OP_CATEGORY_LOGICAL)
const OP_HAS_TIME_ELAPSED: int = (0x0008 | OP_CATEGORY_LOGICAL | OP_NONCAMPAIGN_FLAG)
const OP_NOT: int = (0x0009 | OP_CATEGORY_LOGICAL)
const OP_STRING_EQUALS: int = (0x000a | OP_CATEGORY_LOGICAL)
const OP_STRING_GREATER_THAN: int = (0x000b | OP_CATEGORY_LOGICAL)
const OP_STRING_LESS_THAN: int = (0x000c | OP_CATEGORY_LOGICAL)

# Status
const OP_IS_DESTROYED_DELAY: int = (0x0000 | OP_CATEGORY_OBJECTIVE | OP_NONCAMPAIGN_FLAG)
const OP_IS_SUBSYSTEM_DESTROYED_DELAY: int = (0x0001 | OP_CATEGORY_OBJECTIVE | OP_NONCAMPAIGN_FLAG)
const OP_DISTANCE: int = (0x0004 | OP_CATEGORY_STATUS | OP_NONCAMPAIGN_FLAG)
const OP_MISSION_TIME: int = (0x0006 | OP_CATEGORY_TIME | OP_NONCAMPAIGN_FLAG)
const OP_HITS_LEFT: int = (0x0001 | OP_CATEGORY_STATUS | OP_NONCAMPAIGN_FLAG)
const OP_HITS_LEFT_SUBSYSTEM: int = (0x0002 | OP_CATEGORY_STATUS | OP_NONCAMPAIGN_FLAG)

# Change
const OP_SEND_MESSAGE: int = (0x0005 | OP_CATEGORY_CHANGE | OP_NONCAMPAIGN_FLAG)
const OP_ADD_GOAL: int = (0x0008 | OP_CATEGORY_CHANGE | OP_NONCAMPAIGN_FLAG)
const OP_MODIFY_VARIABLE: int = (0X0024 | OP_CATEGORY_CHANGE | OP_NONCAMPAIGN_FLAG)
const OP_END_MISSION: int = (0x0041 | OP_CATEGORY_CHANGE | OP_NONCAMPAIGN_FLAG)

# Conditional
const OP_WHEN: int = (0x0000 | OP_CATEGORY_CONDITIONAL)
const OP_EVERY_TIME: int = (0x0002 | OP_CATEGORY_CONDITIONAL)

# AI
const OP_AI_CHASE: int = (0x0000 | OP_CATEGORY_AI | OP_NONCAMPAIGN_FLAG)
const OP_AI_WAYPOINTS: int = (0x0004 | OP_CATEGORY_AI | OP_NONCAMPAIGN_FLAG)

# Unlisted (Internal/Parsing related)
const OP_IS_DESTROYED: int = (0x0002 | OP_CATEGORY_UNLISTED)
const OP_IS_SUBSYSTEM_DESTROYED: int = (0x0003 | OP_CATEGORY_UNLISTED)

# --- SEXP Argument Types (OPF_*) ---
# Used for syntax checking and potentially by the evaluator/parser
const OPF_NONE: int = 1
const OPF_NULL: int = 2 # Placeholder/unused?
const OPF_BOOL: int = 3
const OPF_NUMBER: int = 4
const OPF_SHIP: int = 5
const OPF_WING: int = 6
const OPF_SUBSYSTEM: int = 7
const OPF_POINT: int = 8 # Vector3
const OPF_IFF: int = 9
const OPF_AI_GOAL: int = 10
const OPF_DOCKER_POINT: int = 11
const OPF_DOCKEE_POINT: int = 12
const OPF_MESSAGE: int = 13
const OPF_WHO_FROM: int = 14 # Message source
const OPF_PRIORITY: int = 15
const OPF_WAYPOINT_PATH: int = 16
const OPF_POSITIVE: int = 17 # Positive number
const OPF_MISSION_NAME: int = 18
const OPF_SHIP_POINT: int = 19 # Ship or Point
const OPF_GOAL_NAME: int = 20
const OPF_SHIP_WING: int = 21 # Ship or Wing
const OPF_SHIP_WING_POINT: int = 22 # Ship, Wing or Point
const OPF_SHIP_TYPE: int = 23
const OPF_KEYPRESS: int = 24
const OPF_EVENT_NAME: int = 25
const OPF_AI_ORDER: int = 26 # Specific AI order constant
const OPF_SKILL_LEVEL: int = 27
const OPF_MEDAL_NAME: int = 28
const OPF_WEAPON_NAME: int = 29
const OPF_SHIP_CLASS_NAME: int = 30
const OPF_HUD_GAUGE_NAME: int = 31
const OPF_HUGE_WEAPON: int = 32 # Weapon allowed on big ships
const OPF_SHIP_NOT_PLAYER: int = 33
const OPF_JUMP_NODE_NAME: int = 34
const OPF_VARIABLE_NAME: int = 35
const OPF_AMBIGUOUS: int = 36 # Can be multiple types (string or number?)
const OPF_AWACS_SUBSYSTEM: int = 37
const OPF_CARGO: int = 38
const OPF_AI_CLASS: int = 39
const OPF_SUPPORT_SHIP_CLASS: int = 40
const OPF_ARRIVAL_LOCATION: int = 41
const OPF_ARRIVAL_ANCHOR_ALL: int = 42
const OPF_DEPARTURE_LOCATION: int = 43
const OPF_SHIP_WITH_BAY: int = 44
const OPF_SOUNDTRACK_NAME: int = 45
const OPF_INTEL_NAME: int = 46
const OPF_STRING: int = 47
const OPF_ROTATING_SUBSYSTEM: int = 48
const OPF_NAV_POINT: int = 49
const OPF_SSM_CLASS: int = 50 # Self-propelled secondary missile class?
const OPF_FLEXIBLE_ARGUMENT: int = 51 # Used by when/every-time?
const OPF_ANYTHING: int = 52 # Any atom type
const OPF_SKYBOX_MODEL_NAME: int = 53
const OPF_SHIP_OR_NONE: int = 54
const OPF_BACKGROUND_BITMAP: int = 55
const OPF_SUN_BITMAP: int = 56
const OPF_NEBULA_STORM_TYPE: int = 57
const OPF_NEBULA_POOF: int = 58 # Nebula poof effect name?
const OPF_TURRET_TARGET_ORDER: int = 59
const OPF_SUBSYSTEM_OR_NONE: int = 60
const OPF_PERSONA: int = 61
const OPF_SUBSYS_OR_GENERIC: int = 62 # Subsystem name or generic type like "Engine"
const OPF_SHIP_WING_POINT_OR_NONE: int = 63
const OPF_ORDER_RECIPIENT: int = 64 # Ship, Wing, or special like "all fighters"
const OPF_SHIP_WING_TEAM: int = 65 # Ship, Wing, or Team name
const OPF_SUBSYSTEM_TYPE: int = 66 # Generic subsystem type (Engine, Turret, etc.)
const OPF_POST_EFFECT: int = 67
const OPF_TARGET_PRIORITIES: int = 68
const OPF_ARMOR_TYPES: int = 69
const OPF_HUD_ELEMENT: int = 71

# --- SEXP Return Types (OPR_*) ---
# Used for syntax checking
const OPR_NUMBER: int = 1
const OPR_BOOL: int = 2
const OPR_NULL: int = 3 # Returns nothing/no value
const OPR_AI_GOAL: int = 4 # Returns an AI goal constant
const OPR_POSITIVE: int = 5 # Returns a positive number
const OPR_STRING: int = 6
const OPR_AMBIGUOUS: int = 7 # Can return multiple types?
const OPR_FLEXIBLE_ARGUMENT: int = 8 # Used by when/every-time?

# --- SEXP Syntax Check Results ---
const SEXP_CHECK_OK: int = 0 # Not defined in C++, using 0 for success
const SEXP_CHECK_NONOP_ARGS: int = -1
const SEXP_CHECK_OP_EXPECTED: int = -2
const SEXP_CHECK_UNKNOWN_OP: int = -3
const SEXP_CHECK_TYPE_MISMATCH: int = -4
const SEXP_CHECK_BAD_ARG_COUNT: int = -5
const SEXP_CHECK_UNKNOWN_TYPE: int = -6
# ... (add other SEXP_CHECK_* constants as needed) ...
