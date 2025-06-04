class_name TextureQualityManager
extends RefCounted

## Manages texture quality settings and optimization for different hardware capabilities
## Provides dynamic quality adjustment based on performance and memory constraints

signal quality_preset_applied(preset_name: String, quality_level: int)
signal texture_optimized(texture_path: String, original_size: int, optimized_size: int)
signal quality_recommendation_generated(recommended_quality: int, reason: String)

enum QualityPreset {
	POTATO = 0,    # Minimum quality for very low-end hardware
	LOW = 1,       # Low quality for budget hardware
	MEDIUM = 2,    # Medium quality for mainstream hardware
	HIGH = 3,      # High quality for enthusiast hardware
	ULTRA = 4      # Maximum quality for high-end hardware
}

var quality_presets: Dictionary = {}
var current_preset: QualityPreset = QualityPreset.MEDIUM
var hardware_capabilities: Dictionary = {}
var texture_type_settings: Dictionary = {}

func _init() -> void:
	_initialize_quality_presets()
	_initialize_texture_type_settings()
	_detect_hardware_capabilities()

func _initialize_quality_presets() -> void:
	quality_presets = {
		QualityPreset.POTATO: {
			"name": "Potato",
			"description": "Minimum quality for very low-end hardware",
			"texture_scale": 0.25,
			"compression_enabled": true,
			"mipmap_enabled": false,
			"anisotropic_filtering": 0,
			"texture_limit_mb": 64,
			"ui_scale": 0.5,
			"effect_scale": 0.25
		},
		QualityPreset.LOW: {
			"name": "Low",
			"description": "Low quality for budget hardware",
			"texture_scale": 0.5,
			"compression_enabled": true,
			"mipmap_enabled": true,
			"anisotropic_filtering": 2,
			"texture_limit_mb": 128,
			"ui_scale": 0.75,
			"effect_scale": 0.5
		},
		QualityPreset.MEDIUM: {
			"name": "Medium",
			"description": "Medium quality for mainstream hardware",
			"texture_scale": 0.75,
			"compression_enabled": false,
			"mipmap_enabled": true,
			"anisotropic_filtering": 4,
			"texture_limit_mb": 256,
			"ui_scale": 1.0,
			"effect_scale": 0.75
		},
		QualityPreset.HIGH: {
			"name": "High",
			"description": "High quality for enthusiast hardware",
			"texture_scale": 1.0,
			"compression_enabled": false,
			"mipmap_enabled": true,
			"anisotropic_filtering": 8,
			"texture_limit_mb": 512,
			"ui_scale": 1.0,
			"effect_scale": 1.0
		},
		QualityPreset.ULTRA: {
			"name": "Ultra",
			"description": "Maximum quality for high-end hardware",
			"texture_scale": 1.0,
			"compression_enabled": false,
			"mipmap_enabled": true,
			"anisotropic_filtering": 16,
			"texture_limit_mb": 1024,
			"ui_scale": 1.0,
			"effect_scale": 1.0
		}
	}

func _initialize_texture_type_settings() -> void:
	texture_type_settings = {
		"ship_hull": {
			"priority": 10,
			"quality_multiplier": 1.0,
			"compression_threshold": QualityPreset.LOW
		},
		"ship_detail": {
			"priority": 8,
			"quality_multiplier": 0.8,
			"compression_threshold": QualityPreset.MEDIUM
		},
		"weapon_effect": {
			"priority": 7,
			"quality_multiplier": 0.9,
			"compression_threshold": QualityPreset.LOW
		},
		"engine_effect": {
			"priority": 6,
			"quality_multiplier": 0.7,
			"compression_threshold": QualityPreset.MEDIUM
		},
		"environment": {
			"priority": 5,
			"quality_multiplier": 0.6,
			"compression_threshold": QualityPreset.MEDIUM
		},
		"ui_element": {
			"priority": 9,
			"quality_multiplier": 1.0,
			"compression_threshold": QualityPreset.HIGH
		},
		"background": {
			"priority": 3,
			"quality_multiplier": 0.5,
			"compression_threshold": QualityPreset.LOW
		},
		"particle": {
			"priority": 4,
			"quality_multiplier": 0.4,
			"compression_threshold": QualityPreset.LOW
		}
	}

func _detect_hardware_capabilities() -> void:
	# Detect hardware capabilities for automatic quality recommendation
	var rendering_device: RenderingDevice = RenderingServer.create_local_rendering_device()
	
	hardware_capabilities = {
		"vram_mb": _estimate_vram_size(),
		"system_ram_mb": _estimate_system_memory_mb(),
		"cpu_cores": OS.get_processor_count(),
		"renderer": RenderingServer.get_rendering_device().get_device_name() if rendering_device else "Unknown",
		"platform": OS.get_name()
	}
	
	print("TextureQualityManager: Hardware detected - VRAM: %d MB, RAM: %d MB, CPU: %d cores" % [
		hardware_capabilities.vram_mb,
		hardware_capabilities.system_ram_mb, 
		hardware_capabilities.cpu_cores
	])

func _estimate_system_memory_mb() -> int:
	# Rough system memory estimation based on platform
	match OS.get_name():
		"Windows", "macOS", "Linux":
			return 8192  # 8GB conservative estimate for desktop
		"Android", "iOS":
			return 4096  # 4GB for mobile devices
		_:
			return 4096  # Default to 4GB

func _estimate_vram_size() -> int:
	# Rough VRAM estimation based on platform and renderer
	var renderer_name: String = RenderingServer.get_rendering_device().get_device_name() if RenderingServer.get_rendering_device() else ""
	
	# Basic heuristics for VRAM estimation
	if "RTX 40" in renderer_name or "RX 7" in renderer_name:
		return 8192  # 8GB for high-end cards
	elif "RTX 30" in renderer_name or "RX 6" in renderer_name:
		return 6144  # 6GB for mid-high end
	elif "GTX 16" in renderer_name or "RX 5" in renderer_name:
		return 4096  # 4GB for mid-range
	elif "GTX 10" in renderer_name or "RX 4" in renderer_name:
		return 2048  # 2GB for older cards
	else:
		return 1024  # 1GB conservative estimate

func apply_quality_preset(preset: QualityPreset) -> void:
	if preset not in quality_presets:
		push_error("Invalid quality preset: " + str(preset))
		return
	
	current_preset = preset
	var settings: Dictionary = quality_presets[preset]
	
	print("TextureQualityManager: Applying quality preset: %s" % settings.name)
	quality_preset_applied.emit(settings.name, preset)

func get_recommended_quality() -> QualityPreset:
	var vram_mb: int = hardware_capabilities.vram_mb
	var system_ram_mb: int = hardware_capabilities.system_ram_mb
	
	var recommended: QualityPreset
	var reason: String
	
	if vram_mb >= 6144 and system_ram_mb >= 16384:
		recommended = QualityPreset.ULTRA
		reason = "High-end hardware detected"
	elif vram_mb >= 4096 and system_ram_mb >= 8192:
		recommended = QualityPreset.HIGH
		reason = "Mid-high end hardware detected"
	elif vram_mb >= 2048 and system_ram_mb >= 4096:
		recommended = QualityPreset.MEDIUM
		reason = "Mainstream hardware detected"
	elif vram_mb >= 1024 and system_ram_mb >= 2048:
		recommended = QualityPreset.LOW
		reason = "Budget hardware detected"
	else:
		recommended = QualityPreset.POTATO
		reason = "Low-end hardware detected"
	
	quality_recommendation_generated.emit(recommended, reason)
	print("TextureQualityManager: Recommended quality: %s (%s)" % [quality_presets[recommended].name, reason])
	
	return recommended

func optimize_texture(texture: Texture2D, texture_type: String, target_quality: QualityPreset = current_preset) -> Texture2D:
	if not texture or not texture is ImageTexture:
		return texture
	
	var image_texture: ImageTexture = texture as ImageTexture
	var image: Image = image_texture.get_image()
	if not image:
		return texture
	
	var original_size: int = _calculate_image_memory_size(image)
	var optimized_image: Image = _optimize_image(image, texture_type, target_quality)
	var optimized_size: int = _calculate_image_memory_size(optimized_image)
	
	var optimized_texture: ImageTexture = ImageTexture.new()
	optimized_texture.create_from_image(optimized_image)
	
	texture_optimized.emit("optimized_texture", original_size, optimized_size)
	
	return optimized_texture

func _optimize_image(image: Image, texture_type: String, target_quality: QualityPreset) -> Image:
	var optimized: Image = image.duplicate()
	var preset_settings: Dictionary = quality_presets[target_quality]
	var type_settings: Dictionary = texture_type_settings.get(texture_type, {})
	
	# Apply scaling based on quality and texture type
	var quality_multiplier: float = type_settings.get("quality_multiplier", 1.0)
	var scale_factor: float = preset_settings.texture_scale * quality_multiplier
	
	if scale_factor < 1.0:
		var new_width: int = max(1, int(optimized.get_width() * scale_factor))
		var new_height: int = max(1, int(optimized.get_height() * scale_factor))
		optimized.resize(new_width, new_height, Image.INTERPOLATE_LANCZOS)
	
	# Apply compression if enabled
	if preset_settings.compression_enabled:
		var compression_threshold: QualityPreset = type_settings.get("compression_threshold", QualityPreset.MEDIUM)
		if target_quality <= compression_threshold:
			_apply_texture_compression(optimized, target_quality)
	
	# Generate mipmaps if enabled
	if preset_settings.mipmap_enabled and not optimized.has_mipmaps():
		optimized.generate_mipmaps()
	
	return optimized

func _apply_texture_compression(image: Image, quality: QualityPreset) -> void:
	match quality:
		QualityPreset.POTATO:
			image.convert(Image.FORMAT_RGB8)  # Aggressive compression
		QualityPreset.LOW:
			if image.detect_alpha():
				image.convert(Image.FORMAT_RGBA8)
			else:
				image.convert(Image.FORMAT_RGB8)
		_:
			# Higher qualities don't force compression
			pass

func _calculate_image_memory_size(image: Image) -> int:
	var pixel_count: int = image.get_width() * image.get_height()
	var bytes_per_pixel: int = _get_format_bytes_per_pixel(image.get_format())
	var mipmap_factor: float = 1.33 if image.has_mipmaps() else 1.0
	return int(pixel_count * bytes_per_pixel * mipmap_factor)

func _get_format_bytes_per_pixel(format: Image.Format) -> int:
	match format:
		Image.FORMAT_L8, Image.FORMAT_R8:
			return 1
		Image.FORMAT_LA8, Image.FORMAT_RG8:
			return 2
		Image.FORMAT_RGB8:
			return 3
		Image.FORMAT_RGBA8:
			return 4
		_:
			return 4  # Conservative estimate

func get_texture_type_priority(texture_type: String) -> int:
	return texture_type_settings.get(texture_type, {}).get("priority", 5)

func should_use_compression(texture_type: String, quality: QualityPreset) -> bool:
	var type_settings: Dictionary = texture_type_settings.get(texture_type, {})
	var compression_threshold: QualityPreset = type_settings.get("compression_threshold", QualityPreset.MEDIUM)
	return quality <= compression_threshold

func get_quality_settings(quality: QualityPreset = current_preset) -> Dictionary:
	return quality_presets.get(quality, quality_presets[QualityPreset.MEDIUM])

func get_texture_memory_budget(quality: QualityPreset = current_preset) -> int:
	var settings: Dictionary = get_quality_settings(quality)
	return settings.texture_limit_mb * 1024 * 1024

func get_adaptive_quality_for_memory_pressure(memory_pressure: float) -> QualityPreset:
	# Adaptively reduce quality based on memory pressure
	if memory_pressure > 0.9:
		return QualityPreset.POTATO
	elif memory_pressure > 0.8:
		return QualityPreset.LOW
	elif memory_pressure > 0.7:
		return QualityPreset.MEDIUM
	elif memory_pressure > 0.6:
		return QualityPreset.HIGH
	else:
		return QualityPreset.ULTRA

func create_quality_test_scene() -> Dictionary:
	# Create test textures for quality comparison
	var test_textures: Dictionary = {}
	
	for preset in QualityPreset.values():
		var preset_name: String = quality_presets[preset].name
		test_textures[preset_name] = {
			"preset": preset,
			"settings": quality_presets[preset],
			"memory_budget": get_texture_memory_budget(preset)
		}
	
	return test_textures

func get_hardware_info() -> Dictionary:
	return hardware_capabilities.duplicate()

func benchmark_texture_loading() -> Dictionary:
	# Simple benchmark for texture loading performance
	var benchmark_results: Dictionary = {}
	
	var test_image: Image = Image.create(512, 512, false, Image.FORMAT_RGBA8)
	test_image.fill(Color.WHITE)
	
	for preset in QualityPreset.values():
		var start_time: float = Time.get_ticks_msec()
		var optimized: Image = _optimize_image(test_image, "ship_hull", preset)
		var end_time: float = Time.get_ticks_msec()
		
		benchmark_results[quality_presets[preset].name] = {
			"processing_time_ms": end_time - start_time,
			"memory_size": _calculate_image_memory_size(optimized),
			"dimensions": Vector2(optimized.get_width(), optimized.get_height())
		}
	
	return benchmark_results