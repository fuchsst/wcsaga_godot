class_name ObjectStatusData
extends Resource

## Represents object status entries from the C++ p_object status arrays
## Corresponds to the status_type[], status[], and target[] arrays in p_object struct
##
## Each entry represents a status condition like current orders, target assignments,
## or special states that affect the object's behavior in the mission.

@export var status_type: int = 0    # Corresponds to status_type[i] from C++
@export var status_value: int = 0   # Corresponds to status[i] from C++  
@export var target_name: String = ""  # Corresponds to target[i] from C++ (object name reference)

## Validates the object status data
func validate() -> MissionValidationResult:
	var result := MissionValidationResult.new()
	
	# Validate status type (basic range check)
	if status_type < 0:
		result.add_error("Object status type cannot be negative")
	
	# Note: We don't validate target_name here since it may reference objects
	# that haven't been loaded yet. Cross-reference validation should be done
	# at the mission level.
	
	return result

## Creates a new object status entry
static func create_status(type: int, value: int, target: String = "") -> ObjectStatusData:
	var status := ObjectStatusData.new()
	status.status_type = type
	status.status_value = value
	status.target_name = target
	return status