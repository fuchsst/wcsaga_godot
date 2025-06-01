class_name AudioOptionsDataManager
extends Node

## Audio options data management for WCS-Godot conversion.
## Handles audio settings storage, device detection, and real-time audio testing.
## Provides audio bus management and accessibility features.

signal settings_loaded(audio_settings: AudioSettingsData)
signal settings_saved(audio_settings: AudioSettingsData)
signal device_detected(device_info: Dictionary)
signal audio_test_started(sample_name: String)
signal audio_test_completed(sample_name: String)
signal volume_changed(bus_name: String, volume: float)

# Current state
var current_settings: AudioSettingsData = null
var available_devices: Array[Dictionary] = []
var audio_test_players: Dictionary = {}

# Configuration
@export var enable_device_detection: bool = true
@export var enable_real_time_audio_testing: bool = true
@export var enable_accessibility_features: bool = true
@export var enable_audio_monitoring: bool = false

# Audio bus names (matching Godot's audio system)
const BUS_MASTER: String = \"Master\"
const BUS_MUSIC: String = \"Music\"
const BUS_EFFECTS: String = \"Effects\"
const BUS_VOICE: String = \"Voice\"
const BUS_AMBIENT: String = \"Ambient\"
const BUS_UI: String = \"UI\"

# Sample audio files for testing
const TEST_SAMPLES: Dictionary = {
	\"music\": \"res://assets/audio/test/music_sample.ogg\",
	\"effects\": \"res://assets/audio/test/laser_sample.ogg\",
	\"voice\": \"res://assets/audio/test/voice_sample.ogg\",
	\"ambient\": \"res://assets/audio/test/ambient_sample.ogg\",
	\"ui\": \"res://assets/audio/test/ui_sample.ogg\"
}

func _ready() -> void:
	\"\"\"Initialize audio options data manager.\"\"\"
	name = \"AudioOptionsDataManager\"
	_setup_audio_buses()
	
	if enable_device_detection:
		_detect_audio_devices()

func _setup_audio_buses() -> void:
	\"\"\"Setup audio bus configuration.\"\"\"
	# Ensure required audio buses exist
	var required_buses: Array[String] = [BUS_MUSIC, BUS_EFFECTS, BUS_VOICE, BUS_AMBIENT, BUS_UI]
	
	for bus_name in required_buses:
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index == -1:
			# Create bus if it doesn't exist
			AudioServer.add_bus()
			var new_bus_index: int = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(new_bus_index, bus_name)
			# Set master as parent
			AudioServer.set_bus_send(new_bus_index, BUS_MASTER)

func _detect_audio_devices() -> void:
	\"\"\"Detect available audio devices.\"\"\"
	available_devices.clear()
	
	# Get available audio drivers
	var drivers: PackedStringArray = AudioServer.get_device_list()
	
	for i in range(drivers.size()):
		var device_info: Dictionary = {
			\"name\": drivers[i],
			\"index\": i,
			\"is_default\": i == 0,
			\"sample_rate\": AudioServer.get_mix_rate(),
			\"channels\": 2  # Default to stereo
		}
		available_devices.append(device_info)
	
	if not available_devices.is_empty():
		device_detected.emit(available_devices[0])

# ============================================================================
# PUBLIC API
# ============================================================================

func load_audio_settings() -> AudioSettingsData:
	\"\"\"Load audio settings from ConfigurationManager.\"\"\"
	var config_data: Dictionary = ConfigurationManager.get_configuration(\"audio_options\", {})
	current_settings = AudioSettingsData.new()
	
	if not config_data.is_empty():
		current_settings.from_dictionary(config_data)
	else:
		current_settings = _create_default_settings()
	
	_apply_audio_settings_to_engine(current_settings)
	settings_loaded.emit(current_settings)
	return current_settings

func save_audio_settings(settings: AudioSettingsData) -> bool:
	\"\"\"Save audio settings to ConfigurationManager.\"\"\"
	if not settings or not settings.is_valid():
		push_error(\"Cannot save invalid audio settings\")
		return false
	
	var config_data: Dictionary = settings.to_dictionary()
	var success: bool = ConfigurationManager.set_configuration(\"audio_options\", config_data)
	
	if success:
		current_settings = settings.clone()
		_apply_audio_settings_to_engine(current_settings)
		settings_saved.emit(current_settings)
	
	return success

func apply_preset_configuration(preset_name: String) -> AudioSettingsData:
	\"\"\"Apply predefined audio configuration preset.\"\"\"
	var preset_settings: AudioSettingsData = AudioSettingsData.new()
	
	match preset_name.to_lower():
		\"low\":
			preset_settings.apply_quality_preset(AudioSettingsData.AudioQualityPreset.LOW)
		\"medium\":
			preset_settings.apply_quality_preset(AudioSettingsData.AudioQualityPreset.MEDIUM)
		\"high\":
			preset_settings.apply_quality_preset(AudioSettingsData.AudioQualityPreset.HIGH)
		\"ultra\":
			preset_settings.apply_quality_preset(AudioSettingsData.AudioQualityPreset.ULTRA)
		\"custom\":
			if current_settings:
				preset_settings = current_settings.clone()
			else:
				preset_settings = _create_default_settings()
		_:
			push_warning(\"Unknown audio preset: \" + preset_name + \", using medium\")
			preset_settings.apply_quality_preset(AudioSettingsData.AudioQualityPreset.MEDIUM)
	
	current_settings = preset_settings
	return preset_settings

func get_available_presets() -> Array[String]:
	\"\"\"Get list of available audio presets.\"\"\"
	return [\"low\", \"medium\", \"high\", \"ultra\", \"custom\"]

func get_recommended_preset() -> String:
	\"\"\"Get recommended preset based on system capabilities.\"\"\"
	# Analyze system capabilities for audio recommendation
	var system_memory: int = OS.get_static_memory_usage_by_type()[0]  # Get memory usage
	var cpu_count: int = OS.get_processor_count()
	
	if system_memory > 8000000000 and cpu_count >= 8:  # 8GB+ RAM, 8+ cores
		return \"ultra\"
	elif system_memory > 4000000000 and cpu_count >= 4:  # 4GB+ RAM, 4+ cores
		return \"high\"
	elif system_memory > 2000000000:  # 2GB+ RAM
		return \"medium\"
	else:
		return \"low\"

func validate_settings(settings: AudioSettingsData) -> Array[String]:
	\"\"\"Validate audio settings and return any errors.\"\"\"
	var errors: Array[String] = []
	
	if not settings:
		errors.append(\"Audio settings data is null\")
		return errors
	
	if not settings.is_valid():
		errors.append(\"Audio settings data failed validation\")
	
	# Check if requested sample rate is supported
	var current_rate: float = AudioServer.get_mix_rate()
	if settings.sample_rate != int(current_rate):
		errors.append(\"Sample rate \" + str(settings.sample_rate) + \" may not be supported (current: \" + str(current_rate) + \")\")
	
	# Check audio device availability
	if settings.audio_device != \"Default\" and not _is_device_available(settings.audio_device):
		errors.append(\"Audio device '\" + settings.audio_device + \"' is not available\")
	
	# Validate volume levels
	var volume_levels: Dictionary = settings.get_volume_levels()
	for bus_name in volume_levels:
		var volume: float = volume_levels[bus_name]
		if volume < 0.0 or volume > 1.0:
			errors.append(\"Volume for \" + bus_name + \" is out of range (0.0-1.0): \" + str(volume))
	
	return errors

func test_audio_sample(category: String) -> void:
	\"\"\"Play test audio sample for specified category.\"\"\"
	if not enable_real_time_audio_testing:
		return
	
	if not TEST_SAMPLES.has(category):
		push_error(\"No test sample available for category: \" + category)
		return
	
	var sample_path: String = TEST_SAMPLES[category]
	if not ResourceLoader.exists(sample_path):
		push_warning(\"Test sample file not found: \" + sample_path)
		return
	
	# Stop previous test if running
	stop_audio_test(category)
	
	# Create and setup audio player
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = load(sample_path)
	player.bus = _get_bus_for_category(category)
	
	# Connect completion signal
	player.finished.connect(_on_audio_test_completed.bind(category))
	
	# Add to scene and play
	add_child(player)
	audio_test_players[category] = player
	player.play()
	
	audio_test_started.emit(category)

func stop_audio_test(category: String) -> void:
	\"\"\"Stop audio test for specified category.\"\"\"
	if audio_test_players.has(category):
		var player: AudioStreamPlayer = audio_test_players[category]
		if player:
			player.stop()
			player.queue_free()
		audio_test_players.erase(category)

func stop_all_audio_tests() -> void:
	\"\"\"Stop all running audio tests.\"\"\"
	for category in audio_test_players.keys():
		stop_audio_test(category)

func get_available_devices() -> Array[Dictionary]:
	\"\"\"Get list of available audio devices.\"\"\"
	return available_devices.duplicate()

func set_device(device_name: String) -> bool:
	\"\"\"Set active audio device.\"\"\"
	if device_name == \"Default\":
		return true
	
	for device in available_devices:
		if device.name == device_name:
			# TODO: Implement device switching when Godot supports it
			push_warning(\"Audio device switching not fully supported in Godot 4.x\")
			return true
	
	return false

func get_current_device_info() -> Dictionary:
	\"\"\"Get information about currently active audio device.\"\"\"
	return {
		\"name\": \"Default\",
		\"sample_rate\": AudioServer.get_mix_rate(),
		\"channels\": 2,
		\"buffer_size\": 1024,
		\"latency\": AudioServer.get_output_latency()
	}

func get_audio_performance_metrics() -> Dictionary:
	\"\"\"Get current audio performance metrics.\"\"\"
	return {
		\"sample_rate\": AudioServer.get_mix_rate(),
		\"output_latency\": AudioServer.get_output_latency(),
		\"cpu_usage\": AudioServer.get_speaker_mode(),
		\"memory_usage\": _estimate_audio_memory_usage(),
		\"active_voices\": _count_active_audio_players(),
		\"bus_count\": AudioServer.get_bus_count()
	}

# ============================================================================
# HELPER METHODS
# ============================================================================

func _create_default_settings() -> AudioSettingsData:
	\"\"\"Create default audio settings.\"\"\"
	var default_settings: AudioSettingsData = AudioSettingsData.new()
	default_settings.reset_to_defaults()
	return default_settings

func _apply_audio_settings_to_engine(settings: AudioSettingsData) -> void:
	\"\"\"Apply audio settings to Godot audio system.\"\"\"
	if not settings:
		return
	
	# Apply volume levels to audio buses
	var volume_levels: Dictionary = settings.get_volume_levels()
	for bus_name in volume_levels:
		var volume: float = volume_levels[bus_name]
		_set_bus_volume(bus_name, volume)
	
	# Apply device settings (limited support in Godot 4.x)
	if settings.audio_device != \"Default\":
		set_device(settings.audio_device)

func _set_bus_volume(bus_name: String, volume: float) -> void:
	\"\"\"Set volume for specific audio bus.\"\"\"
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		var db_volume: float = linear_to_db(volume) if volume > 0.0 else -80.0
		AudioServer.set_bus_volume_db(bus_index, db_volume)
		volume_changed.emit(bus_name, volume)

func _get_bus_for_category(category: String) -> String:
	\"\"\"Get audio bus name for test category.\"\"\"
	match category:
		\"music\":
			return BUS_MUSIC
		\"effects\":
			return BUS_EFFECTS
		\"voice\":
			return BUS_VOICE
		\"ambient\":
			return BUS_AMBIENT
		\"ui\":
			return BUS_UI
		_:
			return BUS_MASTER

func _is_device_available(device_name: String) -> bool:
	\"\"\"Check if audio device is available.\"\"\"
	for device in available_devices:
		if device.name == device_name:
			return true
	return false

func _estimate_audio_memory_usage() -> float:
	\"\"\"Estimate current audio memory usage in MB.\"\"\"
	var base_usage: float = 10.0  # Base audio system memory
	
	# Add memory for active audio streams
	var active_players: int = _count_active_audio_players()
	base_usage += active_players * 2.0  # Rough estimate per player
	
	# Add memory for current settings
	if current_settings:
		base_usage += current_settings.get_estimated_memory_usage()
	
	return base_usage

func _count_active_audio_players() -> int:
	\"\"\"Count active audio players in the scene tree.\"\"\"
	var count: int = 0
	var scene_tree: SceneTree = get_tree()
	if scene_tree:
		var root: Node = scene_tree.root
		count += _count_audio_players_recursive(root)
	return count

func _count_audio_players_recursive(node: Node) -> int:
	\"\"\"Recursively count audio players.\"\"\"
	var count: int = 0
	
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		var player = node as AudioStreamPlayer
		if player and player.playing:
			count += 1
	
	for child in node.get_children():
		count += _count_audio_players_recursive(child)
	
	return count

func _on_audio_test_completed(category: String) -> void:
	\"\"\"Handle audio test completion.\"\"\"
	if audio_test_players.has(category):
		var player: AudioStreamPlayer = audio_test_players[category]
		if player:
			player.queue_free()
		audio_test_players.erase(category)
	
	audio_test_completed.emit(category)

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_audio_options_data_manager() -> AudioOptionsDataManager:
	\"\"\"Create a new audio options data manager instance.\"\"\"
	var manager: AudioOptionsDataManager = AudioOptionsDataManager.new()
	return manager