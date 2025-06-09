class_name HUDLayoutPresets
extends RefCounted

## EPIC-012 HUD-004: HUD Layout Presets Management
## Defines and manages predefined HUD layout configurations for different use cases

signal preset_applied(preset_name: String)
signal preset_changed(preset_name: String, preset_data: Dictionary)

# Layout presets definition
var layout_presets: Dictionary = {}

# Screen resolution categories
enum ResolutionCategory {
	STANDARD_4_3,    # 1024x768, 1280x960, etc.
	WIDESCREEN_16_9, # 1920x1080, 2560x1440, etc.
	ULTRAWIDE_21_9,  # 2560x1080, 3440x1440, etc.
	MOBILE_PORTRAIT, # 1080x1920, etc.
	MOBILE_LANDSCAPE # 1920x1080 mobile, etc.
}

func initialize() -> void:
	_create_default_presets()
	print("HUDLayoutPresets: Initialized with %d presets" % layout_presets.size())

## Create default layout presets
func _create_default_presets() -> void:
	# Standard WCS Layout
	layout_presets["standard"] = {
		"name": "Standard Layout",
		"description": "Default WCS HUD layout optimized for combat",
		"category": "general",
		"visibility_flags": _get_standard_visibility_flags(),
		"element_positions": _get_standard_positions(),
		"color_scheme": "green",
		"resolution_optimized": ResolutionCategory.STANDARD_4_3,
		"ui_scale": 1.0
	}
	
	# Minimal HUD for focused gameplay
	layout_presets["minimal"] = {
		"name": "Minimal HUD",
		"description": "Essential elements only for immersive gameplay",
		"category": "immersive",
		"visibility_flags": _get_minimal_visibility_flags(),
		"element_positions": _get_minimal_positions(),
		"color_scheme": "green",
		"resolution_optimized": ResolutionCategory.WIDESCREEN_16_9,
		"ui_scale": 0.9
	}
	
	# Observer mode for replay viewing
	layout_presets["observer"] = {
		"name": "Observer Mode",
		"description": "Simplified HUD for replay viewing and spectating",
		"category": "spectator",
		"visibility_flags": _get_observer_visibility_flags(),
		"element_positions": _get_observer_positions(),
		"color_scheme": "blue",
		"resolution_optimized": ResolutionCategory.WIDESCREEN_16_9,
		"ui_scale": 0.8
	}
	
	# Compact layout for smaller screens
	layout_presets["compact"] = {
		"name": "Compact Layout",
		"description": "Optimized for smaller screens and mobile devices",
		"category": "mobile",
		"visibility_flags": _get_compact_visibility_flags(),
		"element_positions": _get_compact_positions(),
		"color_scheme": "amber",
		"resolution_optimized": ResolutionCategory.MOBILE_LANDSCAPE,
		"ui_scale": 1.2
	}
	
	# Widescreen optimized layout
	layout_presets["widescreen"] = {
		"name": "Widescreen Layout",
		"description": "Optimized for 16:9 and ultrawide displays",
		"category": "widescreen",
		"visibility_flags": _get_widescreen_visibility_flags(),
		"element_positions": _get_widescreen_positions(),
		"color_scheme": "green",
		"resolution_optimized": ResolutionCategory.ULTRAWIDE_21_9,
		"ui_scale": 1.0
	}
	
	# Combat focused layout
	layout_presets["combat_focused"] = {
		"name": "Combat Focus",
		"description": "Optimized for intense combat scenarios",
		"category": "combat",
		"visibility_flags": _get_combat_visibility_flags(),
		"element_positions": _get_combat_positions(),
		"color_scheme": "red",
		"resolution_optimized": ResolutionCategory.WIDESCREEN_16_9,
		"ui_scale": 1.1
	}
	
	# Navigation focused layout
	layout_presets["navigation"] = {
		"name": "Navigation Focus",
		"description": "Optimized for navigation and exploration",
		"category": "navigation",
		"visibility_flags": _get_navigation_visibility_flags(),
		"element_positions": _get_navigation_positions(),
		"color_scheme": "blue",
		"resolution_optimized": ResolutionCategory.WIDESCREEN_16_9,
		"ui_scale": 1.0
	}

## Get standard visibility flags (WCS default)
func _get_standard_visibility_flags() -> int:
	# All essential HUD elements visible
	return (
		HUDConfigExtended.GAUGE_SPEED |
		HUDConfigExtended.GAUGE_WEAPONS |
		HUDConfigExtended.GAUGE_OBJECTIVES |
		HUDConfigExtended.GAUGE_TARGET_BOX |
		HUDConfigExtended.GAUGE_TARGET_SHIELD |
		HUDConfigExtended.GAUGE_PLAYER_SHIELD |
		HUDConfigExtended.GAUGE_AFTERBURNER |
		HUDConfigExtended.GAUGE_WEAPON_ENERGY |
		HUDConfigExtended.GAUGE_AUTO_SPEED |
		HUDConfigExtended.GAUGE_AUTO_TARGET |
		HUDConfigExtended.GAUGE_CMEASURE |
		HUDConfigExtended.GAUGE_TALKING_HEAD |
		HUDConfigExtended.GAUGE_DAMAGE |
		HUDConfigExtended.GAUGE_MESSAGE_LINES |
		HUDConfigExtended.GAUGE_RADAR |
		HUDConfigExtended.GAUGE_ESCORT |
		HUDConfigExtended.GAUGE_DIRECTIVES |
		HUDConfigExtended.GAUGE_THREAT |
		HUDConfigExtended.GAUGE_LEAD |
		HUDConfigExtended.GAUGE_LOCK |
		HUDConfigExtended.GAUGE_LEAD_SIGHT |
		HUDConfigExtended.GAUGE_ORIENTATION_TEE
	)

## Get minimal visibility flags (essential only)
func _get_minimal_visibility_flags() -> int:
	return (
		HUDConfigExtended.GAUGE_SPEED |
		HUDConfigExtended.GAUGE_TARGET_BOX |
		HUDConfigExtended.GAUGE_TARGET_SHIELD |
		HUDConfigExtended.GAUGE_PLAYER_SHIELD |
		HUDConfigExtended.GAUGE_WEAPONS |
		HUDConfigExtended.GAUGE_AFTERBURNER |
		HUDConfigExtended.GAUGE_RADAR |
		HUDConfigExtended.GAUGE_LEAD |
		HUDConfigExtended.GAUGE_LOCK
	)

## Get observer visibility flags (minimal for spectating)
func _get_observer_visibility_flags() -> int:
	return (
		HUDConfigExtended.GAUGE_TARGET_BOX |
		HUDConfigExtended.GAUGE_TARGET_SHIELD |
		HUDConfigExtended.GAUGE_OBJECTIVES |
		HUDConfigExtended.GAUGE_MESSAGE_LINES |
		HUDConfigExtended.GAUGE_RADAR |
		HUDConfigExtended.GAUGE_ESCORT
	)

## Get compact visibility flags (mobile optimized)
func _get_compact_visibility_flags() -> int:
	return (
		HUDConfigExtended.GAUGE_SPEED |
		HUDConfigExtended.GAUGE_WEAPONS |
		HUDConfigExtended.GAUGE_TARGET_BOX |
		HUDConfigExtended.GAUGE_PLAYER_SHIELD |
		HUDConfigExtended.GAUGE_AFTERBURNER |
		HUDConfigExtended.GAUGE_RADAR |
		HUDConfigExtended.GAUGE_OBJECTIVES |
		HUDConfigExtended.GAUGE_MESSAGE_LINES
	)

## Get widescreen visibility flags (full featured)
func _get_widescreen_visibility_flags() -> int:
	# Include additional elements that work well on widescreen
	return _get_standard_visibility_flags() | (
		HUDConfigExtended.GAUGE_SQUADMSG |
		HUDConfigExtended.GAUGE_LAG |
		HUDConfigExtended.GAUGE_MINI_TARGET_BOX |
		HUDConfigExtended.GAUGE_OFFSCREEN |
		HUDConfigExtended.GAUGE_BRACKETS |
		HUDConfigExtended.GAUGE_WEAPON_LINKING
	)

## Get combat visibility flags (combat optimized)
func _get_combat_visibility_flags() -> int:
	return (
		HUDConfigExtended.GAUGE_SPEED |
		HUDConfigExtended.GAUGE_WEAPONS |
		HUDConfigExtended.GAUGE_TARGET_BOX |
		HUDConfigExtended.GAUGE_TARGET_SHIELD |
		HUDConfigExtended.GAUGE_PLAYER_SHIELD |
		HUDConfigExtended.GAUGE_AFTERBURNER |
		HUDConfigExtended.GAUGE_WEAPON_ENERGY |
		HUDConfigExtended.GAUGE_CMEASURE |
		HUDConfigExtended.GAUGE_DAMAGE |
		HUDConfigExtended.GAUGE_RADAR |
		HUDConfigExtended.GAUGE_THREAT |
		HUDConfigExtended.GAUGE_LEAD |
		HUDConfigExtended.GAUGE_LOCK |
		HUDConfigExtended.GAUGE_LEAD_SIGHT |
		HUDConfigExtended.GAUGE_BRACKETS |
		HUDConfigExtended.GAUGE_WEAPON_LINKING
	)

## Get navigation visibility flags (exploration optimized)
func _get_navigation_visibility_flags() -> int:
	return (
		HUDConfigExtended.GAUGE_SPEED |
		HUDConfigExtended.GAUGE_AUTO_SPEED |
		HUDConfigExtended.GAUGE_AUTO_TARGET |
		HUDConfigExtended.GAUGE_OBJECTIVES |
		HUDConfigExtended.GAUGE_MESSAGE_LINES |
		HUDConfigExtended.GAUGE_RADAR |
		HUDConfigExtended.GAUGE_ESCORT |
		HUDConfigExtended.GAUGE_DIRECTIVES |
		HUDConfigExtended.GAUGE_ORIENTATION_TEE |
		HUDConfigExtended.GAUGE_OFFSCREEN
	)

## Get standard element positions
func _get_standard_positions() -> Dictionary:
	return {
		"radar": {"anchor": "bottom_left", "offset": Vector2(20, -120)},
		"target_box": {"anchor": "top_right", "offset": Vector2(-20, 20)},
		"player_shield": {"anchor": "bottom_center", "offset": Vector2(-150, -20)},
		"target_shield": {"anchor": "top_right", "offset": Vector2(-20, 80)},
		"weapons": {"anchor": "bottom_right", "offset": Vector2(-20, -120)},
		"speed": {"anchor": "bottom_left", "offset": Vector2(20, -20)},
		"afterburner": {"anchor": "bottom_center", "offset": Vector2(0, -20)},
		"objectives": {"anchor": "top_left", "offset": Vector2(20, 20)},
		"message_lines": {"anchor": "top_left", "offset": Vector2(20, 150)},
		"talking_head": {"anchor": "center_left", "offset": Vector2(20, 0)},
		"escort": {"anchor": "top_right", "offset": Vector2(-200, 20)},
		"damage": {"anchor": "bottom_center", "offset": Vector2(150, -20)}
	}

## Get minimal element positions (spread out for clarity)
func _get_minimal_positions() -> Dictionary:
	return {
		"radar": {"anchor": "bottom_left", "offset": Vector2(20, -100)},
		"target_box": {"anchor": "top_center", "offset": Vector2(0, 20)},
		"player_shield": {"anchor": "bottom_center", "offset": Vector2(-100, -20)},
		"target_shield": {"anchor": "top_center", "offset": Vector2(0, 80)},
		"weapons": {"anchor": "bottom_right", "offset": Vector2(-20, -100)},
		"speed": {"anchor": "bottom_left", "offset": Vector2(20, -20)},
		"afterburner": {"anchor": "bottom_center", "offset": Vector2(100, -20)}
	}

## Get observer element positions (minimal and unobtrusive)
func _get_observer_positions() -> Dictionary:
	return {
		"target_box": {"anchor": "top_center", "offset": Vector2(0, 20)},
		"target_shield": {"anchor": "top_center", "offset": Vector2(0, 80)},
		"objectives": {"anchor": "top_left", "offset": Vector2(20, 20)},
		"message_lines": {"anchor": "bottom_left", "offset": Vector2(20, -100)},
		"radar": {"anchor": "bottom_right", "offset": Vector2(-120, -20)},
		"escort": {"anchor": "top_right", "offset": Vector2(-20, 20)}
	}

## Get compact element positions (optimized for small screens)
func _get_compact_positions() -> Dictionary:
	return {
		"radar": {"anchor": "bottom_left", "offset": Vector2(10, -80)},
		"target_box": {"anchor": "top_center", "offset": Vector2(0, 10)},
		"player_shield": {"anchor": "bottom_center", "offset": Vector2(-80, -10)},
		"weapons": {"anchor": "bottom_right", "offset": Vector2(-10, -80)},
		"speed": {"anchor": "bottom_left", "offset": Vector2(10, -10)},
		"afterburner": {"anchor": "bottom_center", "offset": Vector2(80, -10)},
		"objectives": {"anchor": "top_left", "offset": Vector2(10, 10)},
		"message_lines": {"anchor": "top_left", "offset": Vector2(10, 80)}
	}

## Get widescreen element positions (utilize screen width)
func _get_widescreen_positions() -> Dictionary:
	return {
		"radar": {"anchor": "bottom_left", "offset": Vector2(20, -120)},
		"target_box": {"anchor": "top_right", "offset": Vector2(-20, 20)},
		"player_shield": {"anchor": "bottom_center", "offset": Vector2(-200, -20)},
		"target_shield": {"anchor": "top_right", "offset": Vector2(-20, 80)},
		"weapons": {"anchor": "bottom_right", "offset": Vector2(-20, -120)},
		"speed": {"anchor": "bottom_left", "offset": Vector2(20, -20)},
		"afterburner": {"anchor": "bottom_center", "offset": Vector2(0, -20)},
		"objectives": {"anchor": "top_left", "offset": Vector2(20, 20)},
		"message_lines": {"anchor": "top_left", "offset": Vector2(20, 150)},
		"escort": {"anchor": "top_right", "offset": Vector2(-300, 20)},
		"squadmsg": {"anchor": "center_left", "offset": Vector2(20, -100)},
		"mini_target_box": {"anchor": "center_right", "offset": Vector2(-20, 0)},
		"damage": {"anchor": "bottom_center", "offset": Vector2(200, -20)}
	}

## Get combat element positions (optimized for combat visibility)
func _get_combat_positions() -> Dictionary:
	return {
		"radar": {"anchor": "bottom_left", "offset": Vector2(20, -100)},
		"target_box": {"anchor": "top_center", "offset": Vector2(0, 20)},
		"player_shield": {"anchor": "bottom_center", "offset": Vector2(-120, -20)},
		"target_shield": {"anchor": "top_center", "offset": Vector2(0, 80)},
		"weapons": {"anchor": "bottom_right", "offset": Vector2(-20, -100)},
		"speed": {"anchor": "bottom_left", "offset": Vector2(20, -20)},
		"afterburner": {"anchor": "bottom_center", "offset": Vector2(0, -20)},
		"weapon_energy": {"anchor": "bottom_center", "offset": Vector2(120, -20)},
		"cmeasure": {"anchor": "bottom_right", "offset": Vector2(-20, -20)},
		"damage": {"anchor": "center_right", "offset": Vector2(-20, 0)},
		"threat": {"anchor": "center_left", "offset": Vector2(20, 0)},
		"lead": {"anchor": "center", "offset": Vector2(0, 0)},
		"lock": {"anchor": "center", "offset": Vector2(0, 50)}
	}

## Get navigation element positions (exploration focused)
func _get_navigation_positions() -> Dictionary:
	return {
		"speed": {"anchor": "bottom_left", "offset": Vector2(20, -20)},
		"auto_speed": {"anchor": "bottom_left", "offset": Vector2(20, -60)},
		"auto_target": {"anchor": "bottom_left", "offset": Vector2(20, -100)},
		"objectives": {"anchor": "top_left", "offset": Vector2(20, 20)},
		"message_lines": {"anchor": "top_left", "offset": Vector2(20, 150)},
		"radar": {"anchor": "bottom_right", "offset": Vector2(-120, -20)},
		"escort": {"anchor": "top_right", "offset": Vector2(-20, 20)},
		"directives": {"anchor": "top_center", "offset": Vector2(0, 20)},
		"orientation_tee": {"anchor": "center", "offset": Vector2(0, 0)},
		"offscreen": {"anchor": "center", "offset": Vector2(0, 0)}
	}

## Apply layout preset
func apply_preset(preset_name: String) -> bool:
	if not has_preset(preset_name):
		print("HUDLayoutPresets: Error - Preset not found: %s" % preset_name)
		return false
	
	var preset_data = layout_presets[preset_name]
	
	# Apply preset through signal emission
	preset_applied.emit(preset_name)
	
	print("HUDLayoutPresets: Applied preset: %s" % preset_name)
	return true

## Check if preset exists
func has_preset(preset_name: String) -> bool:
	return layout_presets.has(preset_name)

## Get preset data
func get_preset(preset_name: String) -> Dictionary:
	return layout_presets.get(preset_name, {})

## Get all preset names
func get_preset_names() -> Array[String]:
	var names: Array[String] = []
	for name in layout_presets.keys():
		names.append(name)
	return names

## Get presets by category
func get_presets_by_category(category: String) -> Array[String]:
	var presets: Array[String] = []
	
	for preset_name in layout_presets:
		var preset_data = layout_presets[preset_name]
		if preset_data.has("category") and preset_data.category == category:
			presets.append(preset_name)
	
	return presets

## Get all categories
func get_categories() -> Array[String]:
	var categories: Array[String] = []
	
	for preset_name in layout_presets:
		var preset_data = layout_presets[preset_name]
		if preset_data.has("category"):
			var category = preset_data.category
			if not categories.has(category):
				categories.append(category)
	
	return categories

## Add custom preset
func add_custom_preset(preset_name: String, preset_data: Dictionary) -> bool:
	if preset_name.is_empty():
		print("HUDLayoutPresets: Error - Empty preset name")
		return false
	
	# Validate preset data
	if not _validate_preset_data(preset_data):
		print("HUDLayoutPresets: Error - Invalid preset data for: %s" % preset_name)
		return false
	
	# Add custom category if not specified
	if not preset_data.has("category"):
		preset_data["category"] = "custom"
	
	layout_presets[preset_name] = preset_data
	preset_changed.emit(preset_name, preset_data)
	
	print("HUDLayoutPresets: Added custom preset: %s" % preset_name)
	return true

## Remove custom preset
func remove_preset(preset_name: String) -> bool:
	if not layout_presets.has(preset_name):
		print("HUDLayoutPresets: Error - Preset not found: %s" % preset_name)
		return false
	
	# Prevent removal of default presets
	var preset_data = layout_presets[preset_name]
	if preset_data.has("category") and preset_data.category != "custom":
		print("HUDLayoutPresets: Error - Cannot remove system preset: %s" % preset_name)
		return false
	
	layout_presets.erase(preset_name)
	
	print("HUDLayoutPresets: Removed preset: %s" % preset_name)
	return true

## Validate preset data
func _validate_preset_data(preset_data: Dictionary) -> bool:
	# Check required fields
	var required_fields = ["name", "description"]
	for field in required_fields:
		if not preset_data.has(field):
			return false
	
	# Validate visibility flags if present
	if preset_data.has("visibility_flags") and not (preset_data.visibility_flags is int):
		return false
	
	# Validate element positions if present
	if preset_data.has("element_positions") and not (preset_data.element_positions is Dictionary):
		return false
	
	# Validate color scheme if present
	if preset_data.has("color_scheme") and not (preset_data.color_scheme is String):
		return false
	
	return true

## Get recommended preset for screen resolution
func get_recommended_preset(screen_size: Vector2) -> String:
	var aspect_ratio = screen_size.x / screen_size.y
	var resolution_category: ResolutionCategory
	
	# Determine resolution category
	if aspect_ratio < 1.5:
		if screen_size.x < screen_size.y:
			resolution_category = ResolutionCategory.MOBILE_PORTRAIT
		else:
			resolution_category = ResolutionCategory.STANDARD_4_3
	elif aspect_ratio < 2.0:
		if screen_size.x < 1600:
			resolution_category = ResolutionCategory.MOBILE_LANDSCAPE
		else:
			resolution_category = ResolutionCategory.WIDESCREEN_16_9
	else:
		resolution_category = ResolutionCategory.ULTRAWIDE_21_9
	
	# Find best matching preset
	for preset_name in layout_presets:
		var preset_data = layout_presets[preset_name]
		if preset_data.has("resolution_optimized") and preset_data.resolution_optimized == resolution_category:
			return preset_name
	
	# Fallback to standard
	return "standard"

## Get preset summary
func get_preset_summary(preset_name: String) -> Dictionary:
	if not has_preset(preset_name):
		return {}
	
	var preset_data = layout_presets[preset_name]
	var element_count = 0
	
	# Count visible elements
	if preset_data.has("visibility_flags"):
		var flags = preset_data.visibility_flags
		for i in range(32):  # Check all bits
			if flags & (1 << i):
				element_count += 1
	
	return {
		"name": preset_data.get("name", preset_name),
		"description": preset_data.get("description", ""),
		"category": preset_data.get("category", "unknown"),
		"element_count": element_count,
		"has_custom_positions": preset_data.has("element_positions"),
		"color_scheme": preset_data.get("color_scheme", "default"),
		"ui_scale": preset_data.get("ui_scale", 1.0),
		"resolution_optimized": preset_data.get("resolution_optimized", ResolutionCategory.STANDARD_4_3)
	}

## Export presets to file
func export_presets(file_path: String, preset_names: Array[String] = []) -> bool:
	var presets_to_export = {}
	
	if preset_names.is_empty():
		presets_to_export = layout_presets
	else:
		for preset_name in preset_names:
			if has_preset(preset_name):
				presets_to_export[preset_name] = layout_presets[preset_name]
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		print("HUDLayoutPresets: Error - Cannot create export file: %s" % file_path)
		return false
	
	file.store_string(JSON.stringify(presets_to_export, "\t"))
	file.close()
	
	print("HUDLayoutPresets: Exported %d presets to: %s" % [presets_to_export.size(), file_path])
	return true

## Import presets from file
func import_presets(file_path: String) -> int:
	if not FileAccess.file_exists(file_path):
		print("HUDLayoutPresets: Error - Import file not found: %s" % file_path)
		return 0
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("HUDLayoutPresets: Error - Cannot read import file: %s" % file_path)
		return 0
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("HUDLayoutPresets: Error - Invalid JSON in import file")
		return 0
	
	var imported_presets = json.data
	if not (imported_presets is Dictionary):
		print("HUDLayoutPresets: Error - Invalid preset data format")
		return 0
	
	var import_count = 0
	for preset_name in imported_presets:
		var preset_data = imported_presets[preset_name]
		if _validate_preset_data(preset_data):
			layout_presets[preset_name] = preset_data
			import_count += 1
			preset_changed.emit(preset_name, preset_data)
	
	print("HUDLayoutPresets: Imported %d presets from: %s" % [import_count, file_path])
	return import_count
