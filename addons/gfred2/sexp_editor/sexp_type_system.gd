class_name SexpTypeSystem
extends RefCounted

## Type system for SEXP expression validation and connection compatibility.
## Defines data types used in WCS mission scripting and validation rules.

enum SexpDataType {
	UNKNOWN,
	BOOLEAN,
	NUMBER,
	STRING,
	OBJECT,
	SHIP,
	WING,
	WAYPOINT,
	VECTOR,
	ANY
}

## Type compatibility matrix for connection validation
static var type_compatibility: Dictionary = {
	SexpDataType.BOOLEAN: [SexpDataType.BOOLEAN, SexpDataType.ANY],
	SexpDataType.NUMBER: [SexpDataType.NUMBER, SexpDataType.ANY],
	SexpDataType.STRING: [SexpDataType.STRING, SexpDataType.ANY],
	SexpDataType.OBJECT: [SexpDataType.OBJECT, SexpDataType.SHIP, SexpDataType.WING, SexpDataType.WAYPOINT, SexpDataType.ANY],
	SexpDataType.SHIP: [SexpDataType.SHIP, SexpDataType.OBJECT, SexpDataType.ANY],
	SexpDataType.WING: [SexpDataType.WING, SexpDataType.OBJECT, SexpDataType.ANY],
	SexpDataType.WAYPOINT: [SexpDataType.WAYPOINT, SexpDataType.OBJECT, SexpDataType.ANY],
	SexpDataType.VECTOR: [SexpDataType.VECTOR, SexpDataType.ANY],
	SexpDataType.ANY: [SexpDataType.BOOLEAN, SexpDataType.NUMBER, SexpDataType.STRING, SexpDataType.OBJECT, SexpDataType.SHIP, SexpDataType.WING, SexpDataType.WAYPOINT, SexpDataType.VECTOR, SexpDataType.ANY]
}

## Type colors for visual distinction in the editor
static var type_colors: Dictionary = {
	SexpDataType.BOOLEAN: Color.GREEN,
	SexpDataType.NUMBER: Color.BLUE,
	SexpDataType.STRING: Color.YELLOW,
	SexpDataType.OBJECT: Color.RED,
	SexpDataType.SHIP: Color.ORANGE,
	SexpDataType.WING: Color.PURPLE,
	SexpDataType.WAYPOINT: Color.CYAN,
	SexpDataType.VECTOR: Color.MAGENTA,
	SexpDataType.ANY: Color.WHITE,
	SexpDataType.UNKNOWN: Color.GRAY
}

## Type names for UI display
static var type_names: Dictionary = {
	SexpDataType.BOOLEAN: "Boolean",
	SexpDataType.NUMBER: "Number", 
	SexpDataType.STRING: "String",
	SexpDataType.OBJECT: "Object",
	SexpDataType.SHIP: "Ship",
	SexpDataType.WING: "Wing",
	SexpDataType.WAYPOINT: "Waypoint",
	SexpDataType.VECTOR: "Vector",
	SexpDataType.ANY: "Any",
	SexpDataType.UNKNOWN: "Unknown"
}

## Check if two types are compatible for connection
static func are_types_compatible(from_type: SexpDataType, to_type: SexpDataType) -> bool:
	if from_type == SexpDataType.UNKNOWN or to_type == SexpDataType.UNKNOWN:
		return false
	
	var compatible_types: Array = type_compatibility.get(from_type, [])
	return to_type in compatible_types

## Get the color for a data type
static func get_type_color(data_type: SexpDataType) -> Color:
	return type_colors.get(data_type, Color.GRAY)

## Get the display name for a data type
static func get_type_name(data_type: SexpDataType) -> String:
	return type_names.get(data_type, "Unknown")

## Infer type from a value
static func infer_type_from_value(value: Variant) -> SexpDataType:
	if value is bool:
		return SexpDataType.BOOLEAN
	elif value is int or value is float:
		return SexpDataType.NUMBER
	elif value is String:
		return SexpDataType.STRING
	elif value is Vector3:
		return SexpDataType.VECTOR
	else:
		return SexpDataType.UNKNOWN

## Get a more restrictive type when connecting compatible types
static func get_resolved_type(type1: SexpDataType, type2: SexpDataType) -> SexpDataType:
	if type1 == SexpDataType.ANY:
		return type2
	elif type2 == SexpDataType.ANY:
		return type1
	elif are_types_compatible(type1, type2):
		# Return the more specific type
		if type1 == SexpDataType.OBJECT:
			return type2
		elif type2 == SexpDataType.OBJECT:
			return type1
		else:
			return type1
	else:
		return SexpDataType.UNKNOWN