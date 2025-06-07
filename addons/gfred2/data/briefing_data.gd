@tool
class_name BriefingData
extends Resource

## Briefing data structure for GFRED2-007 Briefing Editor System.
## Contains all briefing information including stages, animations, and audio.

@export var briefing_title: String = ""
@export var briefing_description: String = ""
@export var mission_name: String = ""
@export var total_duration: float = 0.0
@export var background_scene: String = ""
@export var stages: Array[BriefingStage] = []

signal briefing_data_changed()

func _init() -> void:
	resource_name = "BriefingData"

## Adds a new briefing stage
func add_stage(stage: BriefingStage) -> void:
	stages.append(stage)
	_recalculate_total_duration()
	briefing_data_changed.emit()

## Removes a briefing stage
func remove_stage(stage_index: int) -> void:
	if stage_index >= 0 and stage_index < stages.size():
		stages.remove_at(stage_index)
		_recalculate_total_duration()
		briefing_data_changed.emit()

## Gets a stage by index
func get_stage(stage_index: int) -> BriefingStage:
	if stage_index >= 0 and stage_index < stages.size():
		return stages[stage_index]
	return null

## Recalculates total briefing duration
func _recalculate_total_duration() -> void:
	total_duration = 0.0
	for stage in stages:
		total_duration += stage.stage_duration

## Validates briefing data
func validate_briefing() -> Array[String]:
	var errors: Array[String] = []
	
	if briefing_title.is_empty():
		errors.append("Briefing must have a title")
	
	if stages.is_empty():
		errors.append("Briefing must have at least one stage")
	
	for i in range(stages.size()):
		var stage_errors: Array[String] = stages[i].validate_stage()
		for error in stage_errors:
			errors.append("Stage %d: %s" % [i + 1, error])
	
	return errors

## Duplicates briefing data
func duplicate_briefing() -> BriefingData:
	var duplicate: BriefingData = BriefingData.new()
	duplicate.briefing_title = briefing_title + " (Copy)"
	duplicate.briefing_description = briefing_description
	duplicate.mission_name = mission_name
	duplicate.background_scene = background_scene
	
	for stage in stages:
		duplicate.stages.append(stage.duplicate_stage())
	
	duplicate._recalculate_total_duration()
	return duplicate

class BriefingStage extends Resource:

	## Individual briefing stage data.

	@export var stage_title: String = ""
	@export var stage_duration: float = 10.0
	@export var stage_text: String = ""
	@export var camera_position: Vector3 = Vector3.ZERO
	@export var camera_rotation: Vector3 = Vector3.ZERO
	@export var camera_fov: float = 75.0
	@export var icons: Array[BriefingIconData] = []
	@export var keyframes: Array[BriefingKeyframe] = []
	@export var audio_clips: Array[BriefingAudioClip] = []
	@export var text_clips: Array[BriefingTextClip] = []

	func _init() -> void:
		resource_name = "BriefingStage"

	## Validates stage data
	func validate_stage() -> Array[String]:
		var errors: Array[String] = []
		
		if stage_title.is_empty():
			errors.append("Stage must have a title")
		
		if stage_duration <= 0.0:
			errors.append("Stage duration must be positive")
		
		if stage_text.is_empty():
			errors.append("Stage should have briefing text")
		
		return errors

	## Duplicates stage data
	func duplicate_stage() -> BriefingStage:
		var duplicate: BriefingStage = BriefingStage.new()
		duplicate.stage_title = stage_title
		duplicate.stage_duration = stage_duration
		duplicate.stage_text = stage_text
		duplicate.camera_position = camera_position
		duplicate.camera_rotation = camera_rotation
		duplicate.camera_fov = camera_fov
		
		for icon in icons:
			duplicate.icons.append(icon.duplicate_icon())
		
		for keyframe in keyframes:
			duplicate.keyframes.append(keyframe.duplicate_keyframe())
		
		for audio_clip in audio_clips:
			duplicate.audio_clips.append(audio_clip.duplicate_clip())
		
		for text_clip in text_clips:
			duplicate.text_clips.append(text_clip.duplicate_clip())
		
		return duplicate

# Use BriefingIconData from wcs_asset_core addon instead of duplicating it here

class BriefingKeyframe extends Resource:
## Animation keyframe for briefing timeline.

	enum KeyframeType {
		CAMERA_POSITION,
		CAMERA_ROTATION,
		CAMERA_FOV,
		ICON_POSITION,
		ICON_ROTATION,
		ICON_SCALE,
		ICON_VISIBILITY,
		ICON_COLOR
	}

	@export var keyframe_type: KeyframeType = KeyframeType.CAMERA_POSITION
	@export var time_position: float = 0.0
	@export var keyframe_data: Dictionary = {}
	@export var easing_type: Tween.EaseType = Tween.EASE_IN_OUT
	@export var transition_type: Tween.TransitionType = Tween.TRANS_LINEAR

	func _init() -> void:
		resource_name = "BriefingKeyframe"

	## Duplicates keyframe data
	func duplicate_keyframe() -> BriefingKeyframe:
		var duplicate: BriefingKeyframe = BriefingKeyframe.new()
		duplicate.keyframe_type = keyframe_type
		duplicate.time_position = time_position
		duplicate.keyframe_data = keyframe_data.duplicate()
		duplicate.easing_type = easing_type
		duplicate.transition_type = transition_type
		return duplicate

class BriefingAudioClip extends Resource:
## Audio clip for briefing voice-over and sound effects.

	@export var audio_file_path: String = ""
	@export var start_time: float = 0.0
	@export var duration: float = 0.0
	@export var volume: float = 1.0
	@export var is_voice_over: bool = true
	@export var subtitle_text: String = ""

	func _init() -> void:
		resource_name = "BriefingAudioClip"

	## Duplicates audio clip data
	func duplicate_clip() -> BriefingAudioClip:
		var duplicate: BriefingAudioClip = BriefingAudioClip.new()
		duplicate.audio_file_path = audio_file_path
		duplicate.start_time = start_time
		duplicate.duration = duration
		duplicate.volume = volume
		duplicate.is_voice_over = is_voice_over
		duplicate.subtitle_text = subtitle_text
		return duplicate

class BriefingTextClip extends Resource:
## Text overlay clip for briefing stages .

	@export var text_content: String = ""
	@export var start_time: float = 0.0
	@export var duration: float = 0.0
	@export var position: Vector2 = Vector2.ZERO
	@export var font_size: int = 14
	@export var text_color: Color = Color.WHITE
	@export var background_color: Color = Color.TRANSPARENT
	@export var alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT

	func _init() -> void:
		resource_name = "BriefingTextClip"

	## Duplicates text clip data
	func duplicate_clip() -> BriefingTextClip:
		var duplicate: BriefingTextClip = BriefingTextClip.new()
		duplicate.text_content = text_content
		duplicate.start_time = start_time
		duplicate.duration = duration
		duplicate.position = position
		duplicate.font_size = font_size
		duplicate.text_color = text_color
		duplicate.background_color = background_color
		duplicate.alignment = alignment
		return duplicate
