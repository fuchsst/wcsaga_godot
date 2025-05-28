class_name WCSTypes
extends RefCounted

## Type definitions and enums matching WCS C++ types with proper GDScript equivalents.
## Provides type conversion functions and validation for C++ to GDScript data translation.
## All type definitions use static typing and are properly documented.

# ========================================
# Game Mode Enumeration
# ========================================

enum GameMode {
	NONE = 0,
	HUD_CONFIG = 1,
	MENU = 2,
	GAME = 4,
	BRIEFING = 8,
	DEBRIEF = 16,
	CUTSCENE = 32,
	IN_MISSION = 64,
	STANDALONE_SERVER = 128,
	MULTIPLAYER = 256
}

# ========================================
# Viewer Mode Enumeration
# ========================================

enum ViewerMode {
	CHASE = 0,
	EXTERNAL = 1,
	COCKPIT = 2,
	TOPDOWN = 3,
	FREECAMERA = 4,
	WARP_CHASE = 5,
	PADLOCK_VIEW = 6,
	OTHER_SHIP = 7
}

# ========================================
# Detail Level Enumeration  
# ========================================

enum DetailLevel {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2,
	ULTRA = 3,
	CUSTOM = -1
}

# ========================================
# IFF (Identification Friend/Foe) Enumeration
# ========================================

enum IFF {
	UNKNOWN = -1,
	FRIENDLY = 0,
	HOSTILE = 1,
	NEUTRAL = 2,
	UNKNOWN_HOSTILE = 3,
	TRAITOR = 4
}

# ========================================
# Object Type Enumeration
# ========================================

enum ObjectType {
	NONE = 0,
	SHIP = 1,
	WEAPON = 2,
	DEBRIS = 3,
	ASTEROID = 4,
	WAYPOINT = 5,
	FIREBALL = 6,
	BEAM = 7,
	SHOCKWAVE = 8,
	JUMP_NODE = 9,
	GHOST = 10
}

# ========================================
# Cutscene Bar Flags
# ========================================

enum CutsceneBarFlags {
	NONE = 0,
	FADEIN = 1,
	FADEOUT = 2
}

# ========================================
# Fade Type Enumeration
# ========================================

enum FadeType {
	NONE = 0,
	IN = 1,
	OUT = 2
}

# ========================================
# WCS Vector3D Data Structure
# ========================================

class WCSVector3D:
	var x: float
	var y: float  
	var z: float
	
	func _init(x_val: float = 0.0, y_val: float = 0.0, z_val: float = 0.0) -> void:
		x = x_val
		y = y_val
		z = z_val
	
	## Converts to Godot Vector3
	func to_vector3() -> Vector3:
		return Vector3(x, y, z)
	
	## Creates from Godot Vector3
	static func from_vector3(vec: Vector3) -> WCSVector3D:
		return WCSVector3D.new(vec.x, vec.y, vec.z)
	
	## Creates from WCS C++ array format [x, y, z]
	static func from_array(arr: Array) -> WCSVector3D:
		if arr.size() < 3:
			push_error("WCSVector3D: Array must have at least 3 elements")
			return WCSVector3D.new()
		return WCSVector3D.new(arr[0], arr[1], arr[2])

# ========================================
# WCS Vector2D Data Structure
# ========================================

class WCSVector2D:
	var x: float
	var y: float
	
	func _init(x_val: float = 0.0, y_val: float = 0.0) -> void:
		x = x_val
		y = y_val
	
	## Converts to Godot Vector2
	func to_vector2() -> Vector2:
		return Vector2(x, y)
	
	## Creates from Godot Vector2
	static func from_vector2(vec: Vector2) -> WCSVector2D:
		return WCSVector2D.new(vec.x, vec.y)

# ========================================
# WCS Angles Data Structure
# ========================================

class WCSAngles:
	var pitch: float  # p
	var bank: float   # b  
	var heading: float # h
	
	func _init(pitch_val: float = 0.0, bank_val: float = 0.0, heading_val: float = 0.0) -> void:
		pitch = pitch_val
		bank = bank_val
		heading = heading_val
	
	## Converts to Godot Vector3 (pitch, yaw, roll in radians)
	func to_vector3_radians() -> Vector3:
		return Vector3(
			WCSConstants.angle_to_radians(pitch),
			WCSConstants.angle_to_radians(heading), 
			WCSConstants.angle_to_radians(bank)
		)

# ========================================
# WCS Matrix Data Structure  
# ========================================

class WCSMatrix:
	var right_vector: WCSVector3D   # rvec
	var up_vector: WCSVector3D      # uvec  
	var forward_vector: WCSVector3D # fvec
	
	func _init() -> void:
		right_vector = WCSVector3D.new(1.0, 0.0, 0.0)
		up_vector = WCSVector3D.new(0.0, 1.0, 0.0)
		forward_vector = WCSVector3D.new(0.0, 0.0, 1.0)
	
	## Converts to Godot Basis
	func to_basis() -> Basis:
		return Basis(
			right_vector.to_vector3(),
			up_vector.to_vector3(),
			forward_vector.to_vector3()
		)
	
	## Creates from Godot Basis
	static func from_basis(basis: Basis) -> WCSMatrix:
		var matrix: WCSMatrix = WCSMatrix.new()
		matrix.right_vector = WCSVector3D.from_vector3(basis.x)
		matrix.up_vector = WCSVector3D.from_vector3(basis.y)
		matrix.forward_vector = WCSVector3D.from_vector3(basis.z)
		return matrix

# ========================================
# WCS UV Coordinate Pair
# ========================================

class WCSUVPair:
	var u: float
	var v: float
	
	func _init(u_val: float = 0.0, v_val: float = 0.0) -> void:
		u = u_val
		v = v_val
	
	## Converts to Godot Vector2
	func to_vector2() -> Vector2:
		return Vector2(u, v)

# ========================================
# Type Conversion Functions
# ========================================

## Converts WCS fixed-point integer to float
static func fix_to_float(fix_value: int) -> float:
	return float(fix_value) / 65536.0

## Converts float to WCS fixed-point integer
static func float_to_fix(float_value: float) -> int:
	return int(float_value * 65536.0)

## Converts WCS ubyte color (0-255) to Godot color component (0.0-1.0)
static func ubyte_to_color_component(ubyte_value: int) -> float:
	return clampf(float(ubyte_value) / 255.0, 0.0, 1.0)

## Converts Godot color component (0.0-1.0) to WCS ubyte (0-255)
static func color_component_to_ubyte(component: float) -> int:
	return int(clampf(component * 255.0, 0.0, 255.0))

## Converts WCS vertex color to Godot Color
static func vertex_color_to_godot(r: int, g: int, b: int, a: int) -> Color:
	return Color(
		ubyte_to_color_component(r),
		ubyte_to_color_component(g), 
		ubyte_to_color_component(b),
		ubyte_to_color_component(a)
	)

## Converts Godot Color to WCS vertex color components
static func godot_color_to_vertex(color: Color) -> Dictionary:
	return {
		"r": color_component_to_ubyte(color.r),
		"g": color_component_to_ubyte(color.g),
		"b": color_component_to_ubyte(color.b),
		"a": color_component_to_ubyte(color.a)
	}

# ========================================
# Validation Functions
# ========================================

## Validates that a GameMode value is within valid range
static func validate_game_mode(mode: int) -> bool:
	return mode >= 0 and mode <= 512  # Max valid GameMode value

## Validates that a ViewerMode value is within valid range
static func validate_viewer_mode(mode: int) -> bool:
	return mode >= ViewerMode.CHASE and mode <= ViewerMode.OTHER_SHIP

## Validates that an IFF value is within valid range
static func validate_iff(iff: int) -> bool:
	return iff >= IFF.UNKNOWN and iff <= IFF.TRAITOR

## Validates that an ObjectType value is within valid range
static func validate_object_type(obj_type: int) -> bool:
	return obj_type >= ObjectType.NONE and obj_type <= ObjectType.GHOST

# ========================================
# String Conversion Functions
# ========================================

## Converts GameMode enum to readable string
static func game_mode_to_string(mode: GameMode) -> String:
	match mode:
		GameMode.NONE: return "None"
		GameMode.HUD_CONFIG: return "HUD Config"
		GameMode.MENU: return "Menu"
		GameMode.GAME: return "Game"
		GameMode.BRIEFING: return "Briefing"
		GameMode.DEBRIEF: return "Debrief"
		GameMode.CUTSCENE: return "Cutscene"
		GameMode.IN_MISSION: return "In Mission"
		GameMode.STANDALONE_SERVER: return "Standalone Server"
		GameMode.MULTIPLAYER: return "Multiplayer"
		_: return "Unknown"

## Converts ViewerMode enum to readable string
static func viewer_mode_to_string(mode: ViewerMode) -> String:
	match mode:
		ViewerMode.CHASE: return "Chase"
		ViewerMode.EXTERNAL: return "External"
		ViewerMode.COCKPIT: return "Cockpit"
		ViewerMode.TOPDOWN: return "Top Down"
		ViewerMode.FREECAMERA: return "Free Camera"
		ViewerMode.WARP_CHASE: return "Warp Chase"
		ViewerMode.PADLOCK_VIEW: return "Padlock View"
		ViewerMode.OTHER_SHIP: return "Other Ship"
		_: return "Unknown"

## Converts IFF enum to readable string
static func iff_to_string(iff_val: IFF) -> String:
	match iff_val:
		IFF.UNKNOWN: return "Unknown"
		IFF.FRIENDLY: return "Friendly"
		IFF.HOSTILE: return "Hostile"
		IFF.NEUTRAL: return "Neutral"
		IFF.UNKNOWN_HOSTILE: return "Unknown Hostile"
		IFF.TRAITOR: return "Traitor"
		_: return "Invalid"