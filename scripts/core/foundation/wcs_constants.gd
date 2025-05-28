class_name WCSConstants
extends Resource

## Core constants and global definitions from WCS C++ implementation.
## Contains all global constants from globals.h and pstypes.h with identical values.
## Provides centralized access to WCS constants for all game systems.

# ========================================
# String Length Constants (from parselo.h)
# ========================================

const PATHNAME_LENGTH: int = 192
const NAME_LENGTH: int = 32
const SEXP_LENGTH: int = 128
const DATE_LENGTH: int = 32
const TIME_LENGTH: int = 16
const DATE_TIME_LENGTH: int = 48
const NOTES_LENGTH: int = 1024
const MULTITEXT_LENGTH: int = 4096
const FILESPEC_LENGTH: int = 64
const MESSAGE_LENGTH: int = 512
const TRAINING_MESSAGE_LENGTH: int = 512

# ========================================
# Mission Constants
# ========================================

const MISSION_DESC_LENGTH: int = 1024

# ========================================
# Player Constants
# ========================================

const CALLSIGN_LEN: int = 28
const SHORT_CALLSIGN_PIXEL_W: int = 80
const MAX_PLAYERS: int = 12  # From pstypes.h
const MAX_IFFS: int = 10

# ========================================
# Ship Constants
# ========================================

const MAX_SHIPS: int = 400
const SHIPS_LIMIT: int = 400
const MAX_SHIP_CLASSES: int = 130  # Release version
const MAX_SHIP_CLASSES_MULTI: int = 130  # DO NOT CHANGE - PXO compatibility
const MAX_WINGS: int = 75
const MAX_SHIPS_PER_WING: int = 6
const MAX_STARTING_WINGS: int = 3
const MAX_SQUADRON_WINGS: int = 5

# ========================================
# Team/Combat Constants
# ========================================

const MAX_TVT_TEAMS: int = 2
const MAX_TVT_WINGS_PER_TEAM: int = 1
const MAX_TVT_WINGS: int = MAX_TVT_TEAMS * MAX_TVT_WINGS_PER_TEAM

# ========================================
# Weapon Constants
# ========================================

const MAX_SHIP_PRIMARY_BANKS: int = 3
const MAX_SHIP_SECONDARY_BANKS: int = 6
const MAX_SHIP_WEAPONS: int = MAX_SHIP_PRIMARY_BANKS + MAX_SHIP_SECONDARY_BANKS
const MAX_WEAPONS: int = 700
const MAX_WEAPON_TYPES: int = 200

# ========================================
# Model/Graphics Constants
# ========================================

const MAX_MODEL_TEXTURES: int = 64
const MAX_POLYGON_MODELS: int = 128
const MAX_COMPLETE_ESCORT_LIST: int = 20

# ========================================
# Object System Constants
# ========================================

const MAX_OBJECTS: int = 2000
const MAX_LIGHTS: int = 256

# ========================================
# Medal/Scoring Constants
# ========================================

const MAX_MEDALS: int = 19
const NUM_MEDALS_FS1: int = 16

# ========================================
# File System Constants
# ========================================

const MAX_FILENAME_LEN: int = 32
const MAX_PATH_LEN: int = 260  # Windows MAX_PATH compatible

# ========================================
# Math Constants (from pstypes.h)
# ========================================

const PI: float = 3.141592654
const PI2: float = PI * 2.0  # 2 * PI
const PI_2: float = PI / 2.0  # PI / 2
const RAND_MAX_2: int = 16383  # RAND_MAX / 2 (assuming RAND_MAX = 32767)

## Converts angle from degrees to radians.
static func angle_to_radians(degrees: float) -> float:
	return degrees * PI / 180.0

# ========================================
# Platform Constants
# ========================================

# Directory separator based on platform (handled by Godot automatically)
const DIR_SEPARATOR_STR: String = "/"  # Godot uses forward slash universally

# ========================================
# Debug/Development Constants
# ========================================

const UNINITIALIZED: int = 0x7f8e6d9c  # Value representing uninitialized state

# ========================================
# Detail Level Constants
# ========================================

const MAX_DETAIL_LEVEL: int = 4
const NUM_DEFAULT_DETAIL_LEVELS: int = 4

# ========================================
# Noise Constants (for thruster animations)
# ========================================

const NOISE_NUM_FRAMES: int = 15
const NOISE_VALUES: PackedFloat32Array = [
	0.468225, 0.168765, 0.318945, 0.292866, 0.553357,
	0.468225, 0.180456, 0.418465, 0.489958, 1.000000,
	0.468225, 0.599820, 0.664718, 0.294215, 0.000000
]

# ========================================
# Utility Functions
# ========================================

## Validates that a string represents a valid filename (not empty, "none", or "<none>")
static func is_valid_filename(filename: String) -> bool:
	if filename.length() == 0:
		return false
	var lower_name: String = filename.to_lower()
	return lower_name != "none" and lower_name != "<none>"

## Clamps a value between minimum and maximum bounds.
static func clamp_value(value: float, min_val: float, max_val: float) -> float:
	return clampf(value, min_val, max_val)

## Returns the minimum of two values.
static func min_value(a: float, b: float) -> float:
	return min(a, b)

## Returns the maximum of two values.
static func max_value(a: float, b: float) -> float:
	return max(a, b)

# ========================================
# Validation Functions
# ========================================

## Validates that an integer is within expected WCS bounds for ship count.
static func validate_ship_count(count: int) -> bool:
	return count >= 0 and count <= MAX_SHIPS

## Validates that an integer is within expected WCS bounds for weapon count.
static func validate_weapon_count(count: int) -> bool:
	return count >= 0 and count <= MAX_WEAPONS

## Validates that an integer is within expected WCS bounds for object count.
static func validate_object_count(count: int) -> bool:
	return count >= 0 and count <= MAX_OBJECTS

## Validates that a string is within WCS length limits for pathnames.
static func validate_pathname_length(pathname: String) -> bool:
	return pathname.length() <= PATHNAME_LENGTH

## Validates that a string is within WCS length limits for names.
static func validate_name_length(name: String) -> bool:
	return name.length() <= NAME_LENGTH