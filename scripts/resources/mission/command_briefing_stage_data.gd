# scripts/resources/mission/command_briefing_stage_data.gd
# Defines the data structure for a single stage within a command briefing.
extends Resource
class_name CommandBriefingStageData

# Corresponds to FS2 $Stage Text:
@export_multiline var text: String = ""

# Corresponds to FS2 $Ani Filename:
@export var ani_filename: String = ""

# Corresponds to FS2 +Wave Filename: (Optional)
@export var wave_filename: String = ""
