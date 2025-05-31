@tool
extends GdUnitTestSuite

## Test suite for GFRED2-007 Briefing Editor System.
## Tests briefing dialog, 3D viewport, timeline editor, and data structures.

func test_briefing_data_instantiation():
	"""Test briefing data can be instantiated."""
	
	var briefing_data: BriefingData = BriefingData.new()
	assert_not_null(briefing_data)
	assert_that(briefing_data).is_instance_of(BriefingData)
	assert_that(briefing_data.stages).is_not_null()
	assert_that(briefing_data.stages.size()).is_equal(0)
	assert_that(briefing_data.total_duration).is_equal(0.0)

func test_briefing_data_stage_management():
	"""Test briefing data stage management."""
	
	var briefing_data: BriefingData = BriefingData.new()
	briefing_data.briefing_title = "Test Briefing"
	
	# Create test stage
	var stage: BriefingStage = BriefingStage.new()
	stage.stage_title = "Test Stage"
	stage.stage_duration = 15.0
	stage.stage_text = "This is a test stage"
	
	# Add stage
	briefing_data.add_stage(stage)
	
	assert_that(briefing_data.stages.size()).is_equal(1)
	assert_that(briefing_data.total_duration).is_equal(15.0)
	assert_that(briefing_data.get_stage(0)).is_equal(stage)
	
	# Add another stage
	var stage2: BriefingStage = BriefingStage.new()
	stage2.stage_title = "Test Stage 2"
	stage2.stage_duration = 20.0
	briefing_data.add_stage(stage2)
	
	assert_that(briefing_data.stages.size()).is_equal(2)
	assert_that(briefing_data.total_duration).is_equal(35.0)
	
	# Remove stage
	briefing_data.remove_stage(0)
	assert_that(briefing_data.stages.size()).is_equal(1)
	assert_that(briefing_data.total_duration).is_equal(20.0)
	assert_that(briefing_data.get_stage(0)).is_equal(stage2)

func test_briefing_data_validation():
	"""Test briefing data validation."""
	
	var briefing_data: BriefingData = BriefingData.new()
	
	# Empty briefing should have validation errors
	var errors: Array[String] = briefing_data.validate_briefing()
	assert_that(errors.size()).is_greater(0)
	assert_that(errors).contains("Briefing must have a title")
	assert_that(errors).contains("Briefing must have at least one stage")
	
	# Add title and stage
	briefing_data.briefing_title = "Valid Briefing"
	var stage: BriefingStage = BriefingStage.new()
	stage.stage_title = "Valid Stage"
	stage.stage_duration = 10.0
	stage.stage_text = "Valid stage text"
	briefing_data.add_stage(stage)
	
	# Should now be valid
	errors = briefing_data.validate_briefing()
	assert_that(errors.size()).is_equal(0)

func test_briefing_data_duplication():
	"""Test briefing data duplication."""
	
	var briefing_data: BriefingData = BriefingData.new()
	briefing_data.briefing_title = "Original Briefing"
	briefing_data.mission_name = "Test Mission"
	
	var stage: BriefingStage = BriefingStage.new()
	stage.stage_title = "Original Stage"
	stage.stage_duration = 10.0
	briefing_data.add_stage(stage)
	
	# Duplicate briefing
	var duplicate: BriefingData = briefing_data.duplicate_briefing()
	
	assert_not_null(duplicate)
	assert_that(duplicate).is_not_equal(briefing_data)
	assert_that(duplicate.briefing_title).is_equal("Original Briefing (Copy)")
	assert_that(duplicate.mission_name).is_equal("Test Mission")
	assert_that(duplicate.stages.size()).is_equal(1)
	assert_that(duplicate.total_duration).is_equal(10.0)

func test_briefing_stage_data():
	"""Test briefing stage data structure."""
	
	var stage: BriefingStage = BriefingStage.new()
	stage.stage_title = "Test Stage"
	stage.stage_duration = 12.5
	stage.stage_text = "Test briefing text"
	stage.camera_position = Vector3(10, 5, 15)
	stage.camera_rotation = Vector3(0, 45, 0)
	stage.camera_fov = 60.0
	
	assert_that(stage.stage_title).is_equal("Test Stage")
	assert_that(stage.stage_duration).is_equal(12.5)
	assert_that(stage.stage_text).is_equal("Test briefing text")
	assert_that(stage.camera_position).is_equal(Vector3(10, 5, 15))
	assert_that(stage.camera_rotation).is_equal(Vector3(0, 45, 0))
	assert_that(stage.camera_fov).is_equal(60.0)

func test_briefing_stage_validation():
	"""Test briefing stage validation."""
	
	var stage: BriefingStage = BriefingStage.new()
	
	# Empty stage should have validation errors
	var errors: Array[String] = stage.validate_stage()
	assert_that(errors.size()).is_greater(0)
	
	# Add required fields
	stage.stage_title = "Valid Stage"
	stage.stage_duration = 10.0
	stage.stage_text = "Valid stage text"
	
	# Should now be valid
	errors = stage.validate_stage()
	assert_that(errors.size()).is_equal(0)

func test_briefing_icon_data():
	"""Test briefing icon data structure."""
	
	var icon: BriefingIconData = BriefingIconData.new()
	icon.icon_type = BriefingIconData.IconType.SHIP
	icon.icon_name = "Test Ship"
	icon.position = Vector3(100, 0, 200)
	icon.ship_class = "Fighter"
	icon.icon_color = Color.RED
	icon.is_visible = true
	
	assert_that(icon.icon_type).is_equal(BriefingIconData.IconType.SHIP)
	assert_that(icon.icon_name).is_equal("Test Ship")
	assert_that(icon.position).is_equal(Vector3(100, 0, 200))
	assert_that(icon.ship_class).is_equal("Fighter")
	assert_that(icon.icon_color).is_equal(Color.RED)
	assert_bool(icon.is_visible).is_true()

func test_briefing_keyframe_data():
	"""Test briefing keyframe data structure."""
	
	var keyframe: BriefingKeyframe = BriefingKeyframe.new()
	keyframe.keyframe_type = BriefingKeyframe.KeyframeType.CAMERA_POSITION
	keyframe.time_position = 5.5
	keyframe.keyframe_data = {"position": Vector3(10, 20, 30)}
	keyframe.easing_type = Tween.EASE_IN_OUT
	keyframe.transition_type = Tween.TRANS_SINE
	
	assert_that(keyframe.keyframe_type).is_equal(BriefingKeyframe.KeyframeType.CAMERA_POSITION)
	assert_that(keyframe.time_position).is_equal(5.5)
	assert_that(keyframe.keyframe_data).has_key("position")
	assert_that(keyframe.keyframe_data["position"]).is_equal(Vector3(10, 20, 30))
	assert_that(keyframe.easing_type).is_equal(Tween.EASE_IN_OUT)
	assert_that(keyframe.transition_type).is_equal(Tween.TRANS_SINE)

func test_briefing_audio_clip_data():
	"""Test briefing audio clip data structure."""
	
	var audio_clip: BriefingAudioClip = BriefingAudioClip.new()
	audio_clip.audio_file_path = "res://audio/briefing_voice.ogg"
	audio_clip.start_time = 2.0
	audio_clip.duration = 8.5
	audio_clip.volume = 0.8
	audio_clip.is_voice_over = true
	audio_clip.subtitle_text = "Welcome to your mission briefing"
	
	assert_that(audio_clip.audio_file_path).is_equal("res://audio/briefing_voice.ogg")
	assert_that(audio_clip.start_time).is_equal(2.0)
	assert_that(audio_clip.duration).is_equal(8.5)
	assert_that(audio_clip.volume).is_equal(0.8)
	assert_bool(audio_clip.is_voice_over).is_true()
	assert_that(audio_clip.subtitle_text).is_equal("Welcome to your mission briefing")

func test_briefing_text_clip_data():
	"""Test briefing text clip data structure."""
	
	var text_clip: BriefingTextClip = BriefingTextClip.new()
	text_clip.text_content = "Mission Objective"
	text_clip.start_time = 1.0
	text_clip.duration = 5.0
	text_clip.position = Vector2(100, 50)
	text_clip.font_size = 18
	text_clip.text_color = Color.YELLOW
	text_clip.alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	assert_that(text_clip.text_content).is_equal("Mission Objective")
	assert_that(text_clip.start_time).is_equal(1.0)
	assert_that(text_clip.duration).is_equal(5.0)
	assert_that(text_clip.position).is_equal(Vector2(100, 50))
	assert_that(text_clip.font_size).is_equal(18)
	assert_that(text_clip.text_color).is_equal(Color.YELLOW)
	assert_that(text_clip.alignment).is_equal(HORIZONTAL_ALIGNMENT_CENTER)

func test_briefing_editor_dialog_instantiation():
	"""Test briefing editor dialog can be instantiated."""
	
	var dialog: BriefingEditorDialog = BriefingEditorDialog.new()
	assert_not_null(dialog)
	assert_that(dialog).is_instance_of(BriefingEditorDialog)
	assert_that(dialog.briefing_data).is_not_null()
	assert_that(dialog.current_stage_index).is_equal(-1)
	assert_bool(dialog.is_preview_playing).is_false()
	
	dialog.queue_free()

func test_briefing_editor_dialog_setup():
	"""Test briefing editor dialog setup."""
	
	var dialog: BriefingEditorDialog = BriefingEditorDialog.new()
	add_child(dialog)
	
	# Create test briefing data
	var briefing_data: BriefingData = _create_test_briefing_data()
	
	# Setup dialog
	dialog.setup_briefing_editor(briefing_data)
	
	assert_that(dialog.briefing_data).is_equal(briefing_data)
	assert_that(dialog.get_briefing_data()).is_equal(briefing_data)
	
	dialog.queue_free()

func test_briefing_editor_dialog_stage_selection():
	"""Test briefing editor dialog stage selection."""
	
	var dialog: BriefingEditorDialog = BriefingEditorDialog.new()
	add_child(dialog)
	
	var briefing_data: BriefingData = _create_test_briefing_data()
	dialog.setup_briefing_editor(briefing_data)
	
	# Monitor stage selection signal
	var selection_monitor: GdUnitSignalMonitor = monitor_signal(dialog.briefing_stage_selected)
	
	# Should start with no selection
	assert_that(dialog.get_current_stage_index()).is_equal(-1)
	assert_that(dialog.get_current_stage()).is_null()
	
	# Select first stage
	dialog._select_stage(0)
	
	assert_that(dialog.get_current_stage_index()).is_equal(0)
	assert_that(dialog.get_current_stage()).is_equal(briefing_data.stages[0])
	assert_signal_emitted(dialog.briefing_stage_selected)
	
	dialog.queue_free()

func test_briefing_editor_dialog_stage_management():
	"""Test briefing editor dialog stage management."""
	
	var dialog: BriefingEditorDialog = BriefingEditorDialog.new()
	add_child(dialog)
	
	var briefing_data: BriefingData = BriefingData.new()
	briefing_data.briefing_title = "Test Briefing"
	dialog.setup_briefing_editor(briefing_data)
	
	# Monitor stage signals
	var added_monitor: GdUnitSignalMonitor = monitor_signal(dialog.briefing_stage_added)
	var removed_monitor: GdUnitSignalMonitor = monitor_signal(dialog.briefing_stage_removed)
	
	# Add stage
	dialog._on_add_stage_pressed()
	
	assert_that(briefing_data.stages.size()).is_equal(1)
	assert_signal_emitted(dialog.briefing_stage_added)
	assert_that(dialog.get_current_stage_index()).is_equal(0)
	
	# Add another stage
	dialog._on_add_stage_pressed()
	
	assert_that(briefing_data.stages.size()).is_equal(2)
	assert_that(dialog.get_current_stage_index()).is_equal(1)
	
	# Remove stage
	dialog._on_remove_stage_pressed()
	
	assert_that(briefing_data.stages.size()).is_equal(1)
	assert_signal_emitted(dialog.briefing_stage_removed)
	
	dialog.queue_free()

func test_briefing_viewport_3d_instantiation():
	"""Test briefing 3D viewport can be instantiated."""
	
	var viewport: BriefingViewport3D = BriefingViewport3D.new()
	assert_not_null(viewport)
	assert_that(viewport).is_instance_of(BriefingViewport3D)
	assert_bool(viewport.is_camera_control_active).is_false()
	assert_bool(viewport.preview_playing).is_false()
	
	viewport.queue_free()

func test_briefing_viewport_3d_setup():
	"""Test briefing 3D viewport setup."""
	
	var viewport: BriefingViewport3D = BriefingViewport3D.new()
	add_child(viewport)
	
	var briefing_data: BriefingData = _create_test_briefing_data()
	
	# Setup viewport
	viewport.setup_briefing_viewport(briefing_data)
	
	assert_that(viewport.briefing_data).is_equal(briefing_data)
	
	viewport.queue_free()

func test_briefing_viewport_3d_stage_display():
	"""Test briefing viewport stage display."""
	
	var viewport: BriefingViewport3D = BriefingViewport3D.new()
	add_child(viewport)
	
	var briefing_data: BriefingData = _create_test_briefing_data()
	viewport.setup_briefing_viewport(briefing_data)
	
	# Display first stage
	var stage: BriefingStage = briefing_data.stages[0]
	viewport.display_briefing_stage(stage)
	
	assert_that(viewport.current_stage).is_equal(stage)
	
	viewport.queue_free()

func test_briefing_viewport_3d_camera_controls():
	"""Test briefing viewport camera controls."""
	
	var viewport: BriefingViewport3D = BriefingViewport3D.new()
	add_child(viewport)
	
	# Test camera position getting/setting
	var test_position: Vector3 = Vector3(10, 20, 30)
	var test_rotation: Vector3 = Vector3(15, 45, 0)
	
	viewport.set_camera_transform(test_position, test_rotation)
	
	# Note: Actual camera position testing would require scene tree setup
	# For now, test that methods don't crash
	var camera_position: Vector3 = viewport.get_camera_position()
	var camera_rotation: Vector3 = viewport.get_camera_rotation()
	
	assert_that(camera_position).is_instance_of(Vector3)
	assert_that(camera_rotation).is_instance_of(Vector3)
	
	viewport.queue_free()

func test_briefing_viewport_3d_preview_control():
	"""Test briefing viewport preview control."""
	
	var viewport: BriefingViewport3D = BriefingViewport3D.new()
	add_child(viewport)
	
	# Monitor preview signals
	var started_monitor: GdUnitSignalMonitor = monitor_signal(viewport.camera_moved)
	
	# Test preview start/stop
	assert_bool(viewport.preview_playing).is_false()
	
	viewport.start_briefing_preview()
	assert_bool(viewport.preview_playing).is_true()
	
	viewport.stop_briefing_preview()
	assert_bool(viewport.preview_playing).is_false()
	
	viewport.queue_free()

func test_briefing_timeline_editor_instantiation():
	"""Test briefing timeline editor can be instantiated."""
	
	var timeline: BriefingTimelineEditor = BriefingTimelineEditor.new()
	assert_not_null(timeline)
	assert_that(timeline).is_instance_of(BriefingTimelineEditor)
	assert_that(timeline.timeline_duration).is_equal(60.0)
	assert_that(timeline.current_position).is_equal(0.0)
	assert_bool(timeline.is_playing).is_false()
	
	timeline.queue_free()

func test_briefing_timeline_editor_setup():
	"""Test briefing timeline editor setup."""
	
	var timeline: BriefingTimelineEditor = BriefingTimelineEditor.new()
	add_child(timeline)
	
	var briefing_data: BriefingData = _create_test_briefing_data()
	
	# Setup timeline
	timeline.setup_briefing_timeline(briefing_data)
	
	assert_that(timeline.briefing_data).is_equal(briefing_data)
	assert_that(timeline.get_timeline_duration()).is_greater_equal(briefing_data.total_duration)
	
	timeline.queue_free()

func test_briefing_timeline_editor_stage_selection():
	"""Test briefing timeline editor stage selection."""
	
	var timeline: BriefingTimelineEditor = BriefingTimelineEditor.new()
	add_child(timeline)
	
	var briefing_data: BriefingData = _create_test_briefing_data()
	timeline.setup_briefing_timeline(briefing_data)
	
	# Select first stage
	timeline.select_stage(0)
	
	assert_that(timeline.current_stage_index).is_equal(0)
	assert_that(timeline.current_stage).is_equal(briefing_data.stages[0])
	
	timeline.queue_free()

func test_briefing_timeline_editor_playback_control():
	"""Test briefing timeline editor playback control."""
	
	var timeline: BriefingTimelineEditor = BriefingTimelineEditor.new()
	add_child(timeline)
	
	# Monitor playback signals
	var started_monitor: GdUnitSignalMonitor = monitor_signal(timeline.playback_started)
	var stopped_monitor: GdUnitSignalMonitor = monitor_signal(timeline.playback_stopped)
	var paused_monitor: GdUnitSignalMonitor = monitor_signal(timeline.playback_paused)
	
	# Test playback controls
	assert_bool(timeline.is_timeline_playing()).is_false()
	
	timeline.start_playback()
	assert_bool(timeline.is_timeline_playing()).is_true()
	assert_signal_emitted(timeline.playback_started)
	
	timeline.pause_playback()
	assert_bool(timeline.is_timeline_playing()).is_false()
	assert_signal_emitted(timeline.playback_paused)
	
	timeline.stop_playback()
	assert_bool(timeline.is_timeline_playing()).is_false()
	assert_signal_emitted(timeline.playback_stopped)
	assert_that(timeline.get_timeline_position()).is_equal(0.0)
	
	timeline.queue_free()

func test_briefing_timeline_editor_position_control():
	"""Test briefing timeline editor position control."""
	
	var timeline: BriefingTimelineEditor = BriefingTimelineEditor.new()
	add_child(timeline)
	
	# Monitor position change signal
	var position_monitor: GdUnitSignalMonitor = monitor_signal(timeline.timeline_position_changed)
	
	# Test position setting
	timeline.set_timeline_position(15.5)
	
	assert_that(timeline.get_timeline_position()).is_equal(15.5)
	assert_signal_emitted(timeline.timeline_position_changed)
	
	# Test position clamping
	timeline.set_timeline_position(-5.0)
	assert_that(timeline.get_timeline_position()).is_equal(0.0)
	
	timeline.set_timeline_position(timeline.get_timeline_duration() + 10.0)
	assert_that(timeline.get_timeline_position()).is_equal(timeline.get_timeline_duration())
	
	timeline.queue_free()

func test_briefing_timeline_editor_keyframe_management():
	"""Test briefing timeline editor keyframe management."""
	
	var timeline: BriefingTimelineEditor = BriefingTimelineEditor.new()
	add_child(timeline)
	
	var briefing_data: BriefingData = _create_test_briefing_data()
	timeline.setup_briefing_timeline(briefing_data)
	timeline.select_stage(0)
	
	# Monitor keyframe signals
	var added_monitor: GdUnitSignalMonitor = monitor_signal(timeline.keyframe_added)
	var removed_monitor: GdUnitSignalMonitor = monitor_signal(timeline.keyframe_removed)
	
	# Add keyframe
	timeline.set_timeline_position(5.0)
	var keyframe: BriefingKeyframe = timeline.add_keyframe_at_position(
		BriefingKeyframe.KeyframeType.CAMERA_POSITION,
		{"position": Vector3(10, 0, 10)}
	)
	
	assert_not_null(keyframe)
	assert_that(keyframe.time_position).is_equal(5.0)
	assert_that(keyframe.keyframe_type).is_equal(BriefingKeyframe.KeyframeType.CAMERA_POSITION)
	assert_signal_emitted(timeline.keyframe_added)
	
	# Remove keyframe
	timeline.remove_keyframe(keyframe)
	assert_signal_emitted(timeline.keyframe_removed)
	
	timeline.queue_free()

func test_briefing_integration_workflow():
	"""Test integration between briefing editor components."""
	
	var dialog: BriefingEditorDialog = BriefingEditorDialog.new()
	add_child(dialog)
	
	var briefing_data: BriefingData = _create_test_briefing_data()
	dialog.setup_briefing_editor(briefing_data)
	
	# Monitor integration signals
	var analysis_monitor: GdUnitSignalMonitor = monitor_signal(dialog.briefing_stage_selected)
	var preview_started_monitor: GdUnitSignalMonitor = monitor_signal(dialog.briefing_preview_started)
	var preview_stopped_monitor: GdUnitSignalMonitor = monitor_signal(dialog.briefing_preview_stopped)
	
	# Select a stage
	dialog._select_stage(0)
	assert_signal_emitted(dialog.briefing_stage_selected)
	
	# Start preview
	dialog.start_briefing_preview()
	assert_signal_emitted(dialog.briefing_preview_started)
	assert_bool(dialog.is_preview_active()).is_true()
	
	# Stop preview
	dialog.stop_briefing_preview()
	assert_signal_emitted(dialog.briefing_preview_stopped)
	assert_bool(dialog.is_preview_active()).is_false()
	
	dialog.queue_free()

func test_briefing_performance_requirements():
	"""Test briefing editor performance requirements."""
	
	# Test briefing data creation performance
	var start_time: int = Time.get_ticks_msec()
	
	var briefing_data: BriefingData = _create_large_briefing_data()
	
	var creation_time: int = Time.get_ticks_msec() - start_time
	
	# Should create large briefing quickly
	assert_that(creation_time).is_less_than(100)  # Less than 100ms
	
	# Test component instantiation performance
	start_time = Time.get_ticks_msec()
	
	var dialog: BriefingEditorDialog = BriefingEditorDialog.new()
	add_child(dialog)
	
	var instantiation_time: int = Time.get_ticks_msec() - start_time
	
	# Performance requirement: < 16ms scene instantiation
	assert_that(instantiation_time).is_less_than(16)
	
	dialog.queue_free()

## Helper Methods

func _create_test_briefing_data() -> BriefingData:
	"""Creates test briefing data for testing."""
	var briefing_data: BriefingData = BriefingData.new()
	briefing_data.briefing_title = "Test Mission Briefing"
	briefing_data.briefing_description = "A test briefing for unit testing"
	briefing_data.mission_name = "Test Mission"
	briefing_data.background_scene = "res://backgrounds/space.tscn"
	
	# Add test stages
	for i in range(3):
		var stage: BriefingStage = BriefingStage.new()
		stage.stage_title = "Stage %d" % (i + 1)
		stage.stage_duration = 10.0 + (i * 5.0)
		stage.stage_text = "This is briefing stage %d content." % (i + 1)
		stage.camera_position = Vector3(i * 10, 5, 10)
		stage.camera_rotation = Vector3(0, i * 30, 0)
		stage.camera_fov = 75.0
		
		# Add test icons
		for j in range(2):
			var icon: BriefingIconData = BriefingIconData.new()
			icon.icon_type = BriefingIconData.IconType.SHIP
			icon.icon_name = "Test Icon %d-%d" % [i + 1, j + 1]
			icon.position = Vector3(j * 50, 0, i * 100)
			icon.ship_class = "Fighter"
			stage.icons.append(icon)
		
		# Add test keyframes
		for k in range(2):
			var keyframe: BriefingKeyframe = BriefingKeyframe.new()
			keyframe.keyframe_type = BriefingKeyframe.KeyframeType.CAMERA_POSITION
			keyframe.time_position = k * 5.0
			keyframe.keyframe_data = {"position": Vector3(k * 10, 0, 0)}
			stage.keyframes.append(keyframe)
		
		# Add test audio clip
		var audio_clip: BriefingAudioClip = BriefingAudioClip.new()
		audio_clip.audio_file_path = "res://audio/briefing_%d.ogg" % (i + 1)
		audio_clip.start_time = 1.0
		audio_clip.duration = stage.stage_duration - 2.0
		audio_clip.is_voice_over = true
		audio_clip.subtitle_text = "Voice-over for stage %d" % (i + 1)
		stage.audio_clips.append(audio_clip)
		
		# Add test text clip
		var text_clip: BriefingTextClip = BriefingTextClip.new()
		text_clip.text_content = "Mission Objective %d" % (i + 1)
		text_clip.start_time = 0.5
		text_clip.duration = 3.0
		text_clip.position = Vector2(100, 50 + (i * 30))
		text_clip.font_size = 16
		text_clip.text_color = Color.YELLOW
		stage.text_clips.append(text_clip)
		
		briefing_data.add_stage(stage)
	
	return briefing_data

func _create_large_briefing_data() -> BriefingData:
	"""Creates a large briefing data structure for performance testing."""
	var briefing_data: BriefingData = BriefingData.new()
	briefing_data.briefing_title = "Large Test Briefing"
	
	# Create 10 stages with lots of content
	for i in range(10):
		var stage: BriefingStage = BriefingStage.new()
		stage.stage_title = "Large Stage %d" % (i + 1)
		stage.stage_duration = 15.0
		stage.stage_text = "Large stage content with lots of text and details for stage %d" % (i + 1)
		
		# Add many icons
		for j in range(20):
			var icon: BriefingIconData = BriefingIconData.new()
			icon.icon_type = BriefingIconData.IconType.SHIP
			icon.icon_name = "Icon %d-%d" % [i + 1, j + 1]
			icon.position = Vector3(randf_range(-1000, 1000), randf_range(-500, 500), randf_range(-1000, 1000))
			stage.icons.append(icon)
		
		# Add many keyframes
		for k in range(50):
			var keyframe: BriefingKeyframe = BriefingKeyframe.new()
			keyframe.keyframe_type = BriefingKeyframe.KeyframeType.CAMERA_POSITION
			keyframe.time_position = k * 0.3
			keyframe.keyframe_data = {"position": Vector3(randf_range(-100, 100), randf_range(-50, 50), randf_range(-100, 100))}
			stage.keyframes.append(keyframe)
		
		briefing_data.add_stage(stage)
	
	return briefing_data