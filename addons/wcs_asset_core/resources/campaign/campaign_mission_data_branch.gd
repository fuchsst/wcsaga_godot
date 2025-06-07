class_name CampaignMissionDataBranch
extends Resource

## WCS campaign mission branch data for mission flow control.
## Represents a branching path between missions based on completion conditions.

enum BranchType {
	SUCCESS,   # Branch on mission success
	FAILURE,   # Branch on mission failure
	CONDITION  # Branch on SEXP condition
}

@export var branch_type: BranchType = BranchType.SUCCESS
@export var target_mission_id: String = ""
@export var branch_condition: String = ""  # SEXP condition for conditional branches
@export var description: String = ""

func _init() -> void:
	"""Initialize branch data resource."""
	resource_name = "CampaignMissionDataBranch"

## Validates branch data
func validate_branch() -> Array[String]:
	var errors: Array[String] = []
	
	if target_mission_id.is_empty():
		errors.append("Branch must have a target mission")
	
	if branch_type == BranchType.CONDITION and branch_condition.is_empty():
		errors.append("Conditional branch must have a condition expression")
	
	return errors

## Duplicates branch data
func duplicate_branch() -> CampaignMissionDataBranch:
	var duplicate: CampaignMissionDataBranch = CampaignMissionDataBranch.new()
	duplicate.branch_type = branch_type
	duplicate.target_mission_id = target_mission_id
	duplicate.branch_condition = branch_condition
	duplicate.description = description
	return duplicate