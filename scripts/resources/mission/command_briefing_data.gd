# scripts/resources/mission/command_briefing_data.gd
# Defines the data structure for a command briefing (one per team).
extends Resource
class_name CommandBriefingData

# Array of CommandBriefingStageData resources
@export var stages: Array[Resource] = [] # CommandBriefingStageData
