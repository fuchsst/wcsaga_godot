class_name AudioSettingsData
extends BaseAssetData

## Audio configuration settings data for WCS-Godot conversion.
## Comprehensive audio settings including volume levels, spatial audio, and accessibility options.

# Audio volume settings (0.0 to 1.0)
@export var master_volume: float = 1.0
@export var music_volume: float = 0.8
@export var effects_volume: float = 0.9
@export var voice_volume: float = 1.0
@export var ambient_volume: float = 0.7
@export var ui_volume: float = 0.8

# Audio quality settings
@export var sample_rate: int = 44100  # 22050, 44100, 48000, 96000
@export var bit_depth: int = 16  # 16, 24, 32
@export var audio_channels: int = 2  # 1=mono, 2=stereo, 6=5.1, 8=7.1

# Spatial audio settings
@export var enable_3d_audio: bool = true
@export var doppler_effect: bool = true
@export var reverb_enabled: bool = true
@export var audio_occlusion: bool = true
@export var distance_attenuation: float = 1.0

# Voice and communication settings
@export var voice_enabled: bool = true
@export var briefing_voice_enabled: bool = true
@export var subtitles_enabled: bool = false
@export var subtitle_size: int = 1  # 0=small, 1=medium, 2=large
@export var subtitle_background: bool = true

# Audio device settings
@export var audio_device: String = \"Default\"
@export var buffer_size: int = 1024  # 512, 1024, 2048, 4096
@export var enable_audio_monitoring: bool = false

# Accessibility settings
@export var audio_cues_enabled: bool = false
@export var visual_audio_indicators: bool = false
@export var hearing_impaired_mode: bool = false
@export var audio_ducking: bool = false  # Lower other sounds during voice

# Advanced audio settings
@export var dynamic_range_compression: bool = false
@export var audio_normalization: bool = true
@export var crossfade_duration: float = 0.5
@export var audio_fade_out_time: float = 2.0

enum AudioQualityPreset {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2,
	ULTRA = 3,
	CUSTOM = 4
}

enum SampleRateOption {
	RATE_22050 = 22050,
	RATE_44100 = 44100,
	RATE_48000 = 48000,
	RATE_96000 = 96000
}

enum BitDepthOption {
	DEPTH_16 = 16,
	DEPTH_24 = 24,
	DEPTH_32 = 32
}

enum ChannelConfiguration {
	MONO = 1,
	STEREO = 2,
	SURROUND_5_1 = 6,
	SURROUND_7_1 = 8
}

func _init() -> void:
	super._init()
	data_type = \"AudioSettingsData\"

func is_valid() -> bool:
	\"\"\"Validate audio settings data integrity.\"\"\"
	if not super.is_valid():
		return false
	
	# Validate volume ranges
	if master_volume < 0.0 or master_volume > 1.0:
		return false
	if music_volume < 0.0 or music_volume > 1.0:
		return false
	if effects_volume < 0.0 or effects_volume > 1.0:
		return false
	if voice_volume < 0.0 or voice_volume > 1.0:
		return false
	if ambient_volume < 0.0 or ambient_volume > 1.0:
		return false
	if ui_volume < 0.0 or ui_volume > 1.0:
		return false
	
	# Validate sample rate
	if sample_rate not in [22050, 44100, 48000, 96000]:
		return false
	
	# Validate bit depth
	if bit_depth not in [16, 24, 32]:
		return false
	
	# Validate channel configuration
	if audio_channels not in [1, 2, 6, 8]:
		return false
	
	# Validate subtitle size
	if subtitle_size < 0 or subtitle_size > 2:
		return false
	
	# Validate buffer size (power of 2)
	if buffer_size < 256 or buffer_size > 8192 or (buffer_size & (buffer_size - 1)) != 0:
		return false
	
	# Validate distance attenuation
	if distance_attenuation < 0.1 or distance_attenuation > 5.0:
		return false
	
	# Validate crossfade duration
	if crossfade_duration < 0.0 or crossfade_duration > 10.0:
		return false
	
	# Validate fade out time
	if audio_fade_out_time < 0.0 or audio_fade_out_time > 10.0:
		return false
	
	return true

func clone() -> AudioSettingsData:
	\"\"\"Create a deep copy of audio settings.\"\"\"
	var cloned_data: AudioSettingsData = AudioSettingsData.new()
	
	# Copy base properties
	cloned_data.asset_id = asset_id
	cloned_data.display_name = display_name
	cloned_data.description = description
	cloned_data.tags = tags.duplicate()
	cloned_data.metadata = metadata.duplicate(true)
	
	# Copy audio volume settings
	cloned_data.master_volume = master_volume
	cloned_data.music_volume = music_volume
	cloned_data.effects_volume = effects_volume
	cloned_data.voice_volume = voice_volume
	cloned_data.ambient_volume = ambient_volume
	cloned_data.ui_volume = ui_volume
	
	# Copy audio quality settings
	cloned_data.sample_rate = sample_rate
	cloned_data.bit_depth = bit_depth
	cloned_data.audio_channels = audio_channels
	
	# Copy spatial audio settings
	cloned_data.enable_3d_audio = enable_3d_audio
	cloned_data.doppler_effect = doppler_effect
	cloned_data.reverb_enabled = reverb_enabled
	cloned_data.audio_occlusion = audio_occlusion
	cloned_data.distance_attenuation = distance_attenuation
	
	# Copy voice and communication settings
	cloned_data.voice_enabled = voice_enabled
	cloned_data.briefing_voice_enabled = briefing_voice_enabled
	cloned_data.subtitles_enabled = subtitles_enabled
	cloned_data.subtitle_size = subtitle_size
	cloned_data.subtitle_background = subtitle_background
	
	# Copy audio device settings
	cloned_data.audio_device = audio_device
	cloned_data.buffer_size = buffer_size
	cloned_data.enable_audio_monitoring = enable_audio_monitoring
	
	# Copy accessibility settings
	cloned_data.audio_cues_enabled = audio_cues_enabled
	cloned_data.visual_audio_indicators = visual_audio_indicators
	cloned_data.hearing_impaired_mode = hearing_impaired_mode
	cloned_data.audio_ducking = audio_ducking
	
	# Copy advanced audio settings
	cloned_data.dynamic_range_compression = dynamic_range_compression
	cloned_data.audio_normalization = audio_normalization
	cloned_data.crossfade_duration = crossfade_duration
	cloned_data.audio_fade_out_time = audio_fade_out_time
	
	return cloned_data

func get_volume_levels() -> Dictionary:
	\"\"\"Get all volume levels as a dictionary.\"\"\"
	return {
		\"master\": master_volume,
		\"music\": music_volume,
		\"effects\": effects_volume,
		\"voice\": voice_volume,
		\"ambient\": ambient_volume,
		\"ui\": ui_volume
	}

func set_volume_levels(volumes: Dictionary) -> void:
	\"\"\"Set volume levels from dictionary.\"\"\"
	if volumes.has(\"master\"):
		master_volume = clamp(volumes.master, 0.0, 1.0)
	if volumes.has(\"music\"):
		music_volume = clamp(volumes.music, 0.0, 1.0)
	if volumes.has(\"effects\"):
		effects_volume = clamp(volumes.effects, 0.0, 1.0)
	if volumes.has(\"voice\"):
		voice_volume = clamp(volumes.voice, 0.0, 1.0)
	if volumes.has(\"ambient\"):
		ambient_volume = clamp(volumes.ambient, 0.0, 1.0)
	if volumes.has(\"ui\"):
		ui_volume = clamp(volumes.ui, 0.0, 1.0)

func get_quality_preset_name(preset: AudioQualityPreset) -> String:
	\"\"\"Get human-readable name for audio quality preset.\"\"\"
	match preset:
		AudioQualityPreset.LOW:
			return \"Low Quality\"
		AudioQualityPreset.MEDIUM:
			return \"Medium Quality\"
		AudioQualityPreset.HIGH:
			return \"High Quality\"
		AudioQualityPreset.ULTRA:
			return \"Ultra Quality\"
		AudioQualityPreset.CUSTOM:
			return \"Custom\"
		_:
			return \"Unknown\"

func get_sample_rate_name(rate: int) -> String:
	\"\"\"Get human-readable name for sample rate.\"\"\"
	match rate:
		22050:
			return \"22.05 kHz\"
		44100:
			return \"44.1 kHz (CD Quality)\"
		48000:
			return \"48 kHz (Studio)\"
		96000:
			return \"96 kHz (High-Res)\"
		_:
			return str(rate) + \" Hz\"

func get_bit_depth_name(depth: int) -> String:
	\"\"\"Get human-readable name for bit depth.\"\"\"
	match depth:
		16:
			return \"16-bit (CD Quality)\"
		24:
			return \"24-bit (Studio)\"
		32:
			return \"32-bit (High-Res)\"
		_:
			return str(depth) + \"-bit\"

func get_channel_configuration_name(channels: int) -> String:
	\"\"\"Get human-readable name for channel configuration.\"\"\"
	match channels:
		1:
			return \"Mono\"
		2:
			return \"Stereo\"
		6:
			return \"5.1 Surround\"
		8:
			return \"7.1 Surround\"
		_:
			return str(channels) + \" Channels\"

func get_subtitle_size_name(size: int) -> String:
	\"\"\"Get human-readable name for subtitle size.\"\"\"
	match size:
		0:
			return \"Small\"
		1:
			return \"Medium\"
		2:
			return \"Large\"
		_:
			return \"Unknown\"

func apply_quality_preset(preset: AudioQualityPreset) -> void:
	\"\"\"Apply predefined quality preset to audio settings.\"\"\"
	match preset:
		AudioQualityPreset.LOW:
			sample_rate = 22050
			bit_depth = 16
			audio_channels = 2
			enable_3d_audio = false
			doppler_effect = false
			reverb_enabled = false
			audio_occlusion = false
			dynamic_range_compression = true
			
		AudioQualityPreset.MEDIUM:
			sample_rate = 44100
			bit_depth = 16
			audio_channels = 2
			enable_3d_audio = true
			doppler_effect = false
			reverb_enabled = true
			audio_occlusion = false
			dynamic_range_compression = false
			
		AudioQualityPreset.HIGH:
			sample_rate = 48000
			bit_depth = 24
			audio_channels = 2
			enable_3d_audio = true
			doppler_effect = true
			reverb_enabled = true
			audio_occlusion = true
			dynamic_range_compression = false
			
		AudioQualityPreset.ULTRA:
			sample_rate = 96000
			bit_depth = 32
			audio_channels = 6  # 5.1 surround
			enable_3d_audio = true
			doppler_effect = true
			reverb_enabled = true
			audio_occlusion = true
			dynamic_range_compression = false

func get_estimated_memory_usage() -> float:
	\"\"\"Estimate memory usage in MB based on current settings.\"\"\"
	var base_usage: float = 10.0  # Base memory for audio system
	
	# Sample rate impact
	var rate_multiplier: float = sample_rate / 44100.0
	base_usage *= rate_multiplier
	
	# Bit depth impact
	var depth_multiplier: float = bit_depth / 16.0
	base_usage *= depth_multiplier
	
	# Channel configuration impact
	var channel_multiplier: float = audio_channels / 2.0
	base_usage *= channel_multiplier
	
	# 3D audio features
	if enable_3d_audio:
		base_usage += 5.0
	if reverb_enabled:
		base_usage += 3.0
	if audio_occlusion:
		base_usage += 2.0
	
	return base_usage

func get_estimated_cpu_impact() -> String:
	\"\"\"Get estimated CPU impact description.\"\"\"
	var impact_score: int = 0
	
	# Sample rate impact
	if sample_rate >= 96000:
		impact_score += 3
	elif sample_rate >= 48000:
		impact_score += 2
	elif sample_rate >= 44100:
		impact_score += 1
	
	# Bit depth impact
	if bit_depth >= 32:
		impact_score += 2
	elif bit_depth >= 24:
		impact_score += 1
	
	# Channel configuration impact
	if audio_channels >= 8:
		impact_score += 3
	elif audio_channels >= 6:
		impact_score += 2
	elif audio_channels > 2:
		impact_score += 1
	
	# 3D audio features
	if enable_3d_audio:
		impact_score += 2
	if doppler_effect:
		impact_score += 1
	if reverb_enabled:
		impact_score += 2
	if audio_occlusion:
		impact_score += 2
	if dynamic_range_compression:
		impact_score += 1
	
	# Categorize impact
	if impact_score <= 3:
		return \"Low\"
	elif impact_score <= 8:
		return \"Medium\"
	elif impact_score <= 15:
		return \"High\"
	else:
		return \"Very High\"

func reset_to_defaults() -> void:
	\"\"\"Reset all audio settings to default values.\"\"\"
	master_volume = 1.0
	music_volume = 0.8
	effects_volume = 0.9
	voice_volume = 1.0
	ambient_volume = 0.7
	ui_volume = 0.8
	
	sample_rate = 44100
	bit_depth = 16
	audio_channels = 2
	
	enable_3d_audio = true
	doppler_effect = true
	reverb_enabled = true
	audio_occlusion = true
	distance_attenuation = 1.0
	
	voice_enabled = true
	briefing_voice_enabled = true
	subtitles_enabled = false
	subtitle_size = 1
	subtitle_background = true
	
	audio_device = \"Default\"
	buffer_size = 1024
	enable_audio_monitoring = false
	
	audio_cues_enabled = false
	visual_audio_indicators = false
	hearing_impaired_mode = false
	audio_ducking = false
	
	dynamic_range_compression = false
	audio_normalization = true
	crossfade_duration = 0.5
	audio_fade_out_time = 2.0