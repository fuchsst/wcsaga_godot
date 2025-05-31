@tool
class_name EnvironmentData
extends Resource

## Environment configuration data for GFRED2-010 Mission Component Editors.
## Defines asteroid fields, starfields, nebula, and environmental elements.

signal environment_changed(property_name: String, old_value: Variant, new_value: Variant)

# Asteroid field properties
@export var asteroid_field_enabled: bool = false
@export var asteroid_density: float = 0.1
@export var asteroid_size_min: float = 10.0
@export var asteroid_size_max: float = 100.0
@export var asteroid_composition: String = "Rock"
@export var asteroid_debris_enabled: bool = false
@export var asteroid_hazard_level: int = 1

# Starfield properties
@export var starfield_enabled: bool = true
@export var star_density: float = 1.0
@export var star_brightness: float = 1.0
@export var star_color_tint: Color = Color.WHITE
@export var background_bitmap: String = ""

# Nebula properties
@export var nebula_enabled: bool = false
@export var nebula_density: float = 0.2
@export var nebula_color: Color = Color.PURPLE
@export var nebula_lightning_enabled: bool = false
@export var lightning_frequency: float = 1.0
@export var sensor_range: float = 2000.0

# Jump nodes
@export var jump_nodes: Array[JumpNodeData] = []

# Environmental effects
@export var ambient_light_color: Color = Color.WHITE
@export var ambient_light_intensity: float = 0.2
@export var fog_enabled: bool = false
@export var fog_color: Color = Color.GRAY
@export var fog_density: float = 0.1

func _init() -> void:
	# Initialize with default values
	asteroid_field_enabled = false
	starfield_enabled = true
	nebula_enabled = false
	ambient_light_color = Color.WHITE
	ambient_light_intensity = 0.2
	fog_enabled = false

func _set(property: StringName, value: Variant) -> bool:
	var old_value: Variant = get(property)
	var result: bool = false
	
	match property:
		"asteroid_field_enabled":
			asteroid_field_enabled = value as bool
			result = true
		"asteroid_density":
			asteroid_density = clamp(value as float, 0.0, 1.0)
			result = true
		"asteroid_size_min":
			asteroid_size_min = max(1.0, value as float)
			result = true
		"asteroid_size_max":
			asteroid_size_max = max(1.0, value as float)
			result = true
		"asteroid_composition":
			asteroid_composition = value as String
			result = true
		"asteroid_debris_enabled":
			asteroid_debris_enabled = value as bool
			result = true
		"asteroid_hazard_level":
			asteroid_hazard_level = clamp(value as int, 0, 10)
			result = true
		"starfield_enabled":
			starfield_enabled = value as bool
			result = true
		"star_density":
			star_density = max(0.0, value as float)
			result = true
		"star_brightness":
			star_brightness = max(0.0, value as float)
			result = true
		"star_color_tint":
			star_color_tint = value as Color
			result = true
		"background_bitmap":
			background_bitmap = value as String
			result = true
		"nebula_enabled":
			nebula_enabled = value as bool
			result = true
		"nebula_density":
			nebula_density = clamp(value as float, 0.0, 1.0)
			result = true
		"nebula_color":
			nebula_color = value as Color
			result = true
		"nebula_lightning_enabled":
			nebula_lightning_enabled = value as bool
			result = true
		"lightning_frequency":
			lightning_frequency = max(0.0, value as float)
			result = true
		"sensor_range":
			sensor_range = max(100.0, value as float)
			result = true
		"jump_nodes":
			jump_nodes = value as Array[JumpNodeData]
			result = true
		"ambient_light_color":
			ambient_light_color = value as Color
			result = true
		"ambient_light_intensity":
			ambient_light_intensity = clamp(value as float, 0.0, 2.0)
			result = true
		"fog_enabled":
			fog_enabled = value as bool
			result = true
		"fog_color":
			fog_color = value as Color
			result = true
		"fog_density":
			fog_density = clamp(value as float, 0.0, 1.0)
			result = true
	
	if result:
		environment_changed.emit(property, old_value, value)
	
	return result

## Validates the environment configuration
func validate() -> ValidationResult:
	var result: ValidationResult = ValidationResult.new()
	
	# Validate asteroid field
	if asteroid_field_enabled:
		if asteroid_density < 0.0 or asteroid_density > 1.0:
			result.add_error("Asteroid density must be between 0.0 and 1.0")
		
		if asteroid_size_min > asteroid_size_max:
			result.add_error("Asteroid minimum size cannot be greater than maximum size")
		
		if asteroid_size_min <= 0.0 or asteroid_size_max <= 0.0:
			result.add_error("Asteroid sizes must be greater than 0")
		
		if asteroid_hazard_level < 0 or asteroid_hazard_level > 10:
			result.add_error("Asteroid hazard level must be between 0 and 10")
	
	# Validate starfield
	if starfield_enabled:
		if star_density < 0.0:
			result.add_error("Star density cannot be negative")
		
		if star_brightness < 0.0:
			result.add_error("Star brightness cannot be negative")
		
		if not background_bitmap.is_empty() and not FileAccess.file_exists(background_bitmap):
			result.add_warning("Background bitmap file not found: %s" % background_bitmap)
	
	# Validate nebula
	if nebula_enabled:
		if nebula_density < 0.0 or nebula_density > 1.0:
			result.add_error("Nebula density must be between 0.0 and 1.0")
		
		if lightning_frequency < 0.0:
			result.add_error("Lightning frequency cannot be negative")
		
		if sensor_range <= 0.0:
			result.add_error("Sensor range must be greater than 0")
	
	# Validate jump nodes
	for i in range(jump_nodes.size()):
		var jump_node: JumpNodeData = jump_nodes[i]
		if jump_node.name.is_empty():
			result.add_error("Jump node %d: Name cannot be empty" % (i + 1))
	
	# Validate ambient lighting
	if ambient_light_intensity < 0.0 or ambient_light_intensity > 2.0:
		result.add_error("Ambient light intensity must be between 0.0 and 2.0")
	
	# Validate fog
	if fog_enabled:
		if fog_density < 0.0 or fog_density > 1.0:
			result.add_error("Fog density must be between 0.0 and 1.0")
	
	return result

## Exports to WCS mission format
func export_to_wcs() -> Dictionary:
	return {
		"asteroid_field": {
			"enabled": asteroid_field_enabled,
			"density": asteroid_density,
			"size_min": asteroid_size_min,
			"size_max": asteroid_size_max,
			"composition": asteroid_composition,
			"debris_enabled": asteroid_debris_enabled,
			"hazard_level": asteroid_hazard_level
		},
		"starfield": {
			"enabled": starfield_enabled,
			"star_density": star_density,
			"star_brightness": star_brightness,
			"star_color_tint": {"r": star_color_tint.r, "g": star_color_tint.g, "b": star_color_tint.b, "a": star_color_tint.a},
			"background_bitmap": background_bitmap
		},
		"nebula": {
			"enabled": nebula_enabled,
			"density": nebula_density,
			"color": {"r": nebula_color.r, "g": nebula_color.g, "b": nebula_color.b, "a": nebula_color.a},
			"lightning_enabled": nebula_lightning_enabled,
			"lightning_frequency": lightning_frequency,
			"sensor_range": sensor_range
		},
		"jump_nodes": jump_nodes.map(func(node): return node.export_to_wcs() if node.has_method("export_to_wcs") else {}),
		"ambient_light": {
			"color": {"r": ambient_light_color.r, "g": ambient_light_color.g, "b": ambient_light_color.b},
			"intensity": ambient_light_intensity
		},
		"fog": {
			"enabled": fog_enabled,
			"color": {"r": fog_color.r, "g": fog_color.g, "b": fog_color.b},
			"density": fog_density
		}
	}

## Gets environment summary for display
func get_summary() -> Dictionary:
	var active_features: Array[String] = []
	
	if asteroid_field_enabled:
		active_features.append("Asteroid Field")
	if starfield_enabled:
		active_features.append("Starfield")
	if nebula_enabled:
		active_features.append("Nebula")
	if jump_nodes.size() > 0:
		active_features.append("%d Jump Nodes" % jump_nodes.size())
	if fog_enabled:
		active_features.append("Fog")
	
	return {
		"active_features": active_features,
		"asteroid_field_enabled": asteroid_field_enabled,
		"starfield_enabled": starfield_enabled,
		"nebula_enabled": nebula_enabled,
		"jump_node_count": jump_nodes.size(),
		"fog_enabled": fog_enabled,
		"has_background": not background_bitmap.is_empty()
	}

## Applies a predefined environment preset
func apply_preset(preset_name: String) -> void:
	match preset_name.to_lower():
		"clear_space":
			_apply_clear_space_preset()
		"asteroid_field":
			_apply_asteroid_field_preset()
		"nebula":
			_apply_nebula_preset()
		"deep_space":
			_apply_deep_space_preset()
		"combat_zone":
			_apply_combat_zone_preset()
		_:
			print("EnvironmentData: Unknown preset: %s" % preset_name)

func _apply_clear_space_preset() -> void:
	asteroid_field_enabled = false
	starfield_enabled = true
	star_density = 1.0
	star_brightness = 1.0
	star_color_tint = Color.WHITE
	nebula_enabled = false
	ambient_light_intensity = 0.3
	fog_enabled = false

func _apply_asteroid_field_preset() -> void:
	asteroid_field_enabled = true
	asteroid_density = 0.3
	asteroid_size_min = 20.0
	asteroid_size_max = 150.0
	asteroid_composition = "Rock"
	asteroid_debris_enabled = true
	asteroid_hazard_level = 3
	starfield_enabled = true
	star_density = 0.8
	nebula_enabled = false
	ambient_light_intensity = 0.2

func _apply_nebula_preset() -> void:
	nebula_enabled = true
	nebula_density = 0.4
	nebula_color = Color.PURPLE
	nebula_lightning_enabled = true
	lightning_frequency = 2.0
	sensor_range = 1500.0
	starfield_enabled = true
	star_density = 0.5
	star_brightness = 0.7
	ambient_light_intensity = 0.15
	fog_enabled = true
	fog_density = 0.2
	fog_color = Color.PURPLE * 0.3

func _apply_deep_space_preset() -> void:
	asteroid_field_enabled = false
	starfield_enabled = true
	star_density = 1.5
	star_brightness = 1.2
	star_color_tint = Color(0.9, 0.9, 1.0)
	nebula_enabled = false
	ambient_light_intensity = 0.1
	fog_enabled = false

func _apply_combat_zone_preset() -> void:
	asteroid_field_enabled = true
	asteroid_density = 0.2
	asteroid_debris_enabled = true
	asteroid_hazard_level = 5
	starfield_enabled = true
	star_brightness = 0.8
	star_color_tint = Color(1.0, 0.9, 0.8)
	nebula_enabled = false
	ambient_light_intensity = 0.25
	fog_enabled = false

## Duplicates the environment data
func duplicate(deep: bool = true) -> EnvironmentData:
	var copy: EnvironmentData = EnvironmentData.new()
	
	# Copy all properties
	copy.asteroid_field_enabled = asteroid_field_enabled
	copy.asteroid_density = asteroid_density
	copy.asteroid_size_min = asteroid_size_min
	copy.asteroid_size_max = asteroid_size_max
	copy.asteroid_composition = asteroid_composition
	copy.asteroid_debris_enabled = asteroid_debris_enabled
	copy.asteroid_hazard_level = asteroid_hazard_level
	
	copy.starfield_enabled = starfield_enabled
	copy.star_density = star_density
	copy.star_brightness = star_brightness
	copy.star_color_tint = star_color_tint
	copy.background_bitmap = background_bitmap
	
	copy.nebula_enabled = nebula_enabled
	copy.nebula_density = nebula_density
	copy.nebula_color = nebula_color
	copy.nebula_lightning_enabled = nebula_lightning_enabled
	copy.lightning_frequency = lightning_frequency
	copy.sensor_range = sensor_range
	
	copy.ambient_light_color = ambient_light_color
	copy.ambient_light_intensity = ambient_light_intensity
	copy.fog_enabled = fog_enabled
	copy.fog_color = fog_color
	copy.fog_density = fog_density
	
	# Deep copy jump nodes
	if deep:
		for jump_node in jump_nodes:
			copy.jump_nodes.append(jump_node.duplicate() if jump_node.has_method("duplicate") else jump_node)
	else:
		copy.jump_nodes = jump_nodes.duplicate()
	
	return copy