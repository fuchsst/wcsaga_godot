class_name TargetDisplay
extends HUDElementBase

## EPIC-012 HUD-005: Primary Target Display System
## Central target information display with comprehensive target monitoring

signal target_changed(new_target: Node)
signal target_lost()
signal subsystem_selected(subsystem_name: String)
signal threat_level_changed(threat_level: int)

# Display components
@onready var info_panel: TargetInfoPanel
@onready var status_visualizer: TargetStatusVisualizer
@onready var subsystem_display: SubsystemDisplay
@onready var tactical_analyzer: TacticalAnalyzer

# Current target data
var current_target: Node = null
var target_data: Dictionary = {}

# Update configuration
@export var smooth_transitions: bool = true
@export var auto_switch_on_destroy: bool = true

func _init() -> void:
	super._init()
	element_id = "target_display"
	element_priority = 8  # High priority for targeting
	
	# Initialize components
	info_panel = TargetInfoPanel.new()
	status_visualizer = TargetStatusVisualizer.new()
	subsystem_display = SubsystemDisplay.new()
	tactical_analyzer = TacticalAnalyzer.new()

func _ready() -> void:
	super._ready()
	_setup_target_display()
	_connect_signals()
	
	# Configure data sources for targeting
	data_sources = ["targeting_data", "ship_status", "tactical_data"]
	print("TargetDisplay: Initialized with %.1f Hz update frequency" % update_frequency)

## Setup target display components
func _setup_target_display() -> void:
	# Add child components
	add_child(info_panel)
	add_child(status_visualizer)
	add_child(subsystem_display)
	
	# Position components
	_arrange_display_components()
	
	# Initialize tactical analyzer
	tactical_analyzer.setup()
	
	print("TargetDisplay: Component setup complete")

## Arrange display components in layout
func _arrange_display_components() -> void:
	# Main info panel at top
	info_panel.position = Vector2(0, 0)
	info_panel.size = Vector2(300, 120)
	
	# Status visualizer below info panel
	status_visualizer.position = Vector2(0, 130)
	status_visualizer.size = Vector2(300, 100)
	
	# Subsystem display at bottom
	subsystem_display.position = Vector2(0, 240)
	subsystem_display.size = Vector2(300, 80)
	
	# Adjust total size
	custom_minimum_size = Vector2(300, 330)

## Connect component signals
func _connect_signals() -> void:
	# Subsystem display signals
	if subsystem_display:
		subsystem_display.subsystem_selected.connect(_on_subsystem_selected)
	
	# Status visualizer signals
	if status_visualizer:
		status_visualizer.critical_damage.connect(_on_critical_damage)
	
	# Tactical analyzer signals
	if tactical_analyzer:
		tactical_analyzer.threat_assessment_updated.connect(_on_threat_assessment_updated)

## Core target management
func set_target(target: Node) -> void:
	if current_target == target:
		return
	
	var previous_target = current_target
	current_target = target
	
	if current_target:
		print("TargetDisplay: Target set to %s" % _get_target_name(current_target))
		_update_target_data()
		_update_all_displays()
		target_changed.emit(current_target)
	else:
		print("TargetDisplay: Target cleared")
		_clear_target_data()
		target_lost.emit()
	
	if smooth_transitions:
		_animate_target_transition(previous_target, current_target)

## Update target information
func update_target_info(target: Node) -> void:
	if target != current_target:
		return
	
	_update_target_data()
	_update_all_displays()

## Display target status
func display_target_status(hull: float, shields: float) -> void:
	if not current_target:
		return
	
	# Update status visualizer
	if status_visualizer:
		status_visualizer.update_hull_display(hull)
		status_visualizer.update_shield_display(_get_shield_quadrants(shields))

## Show subsystem status
func show_subsystem_status(subsystems: Dictionary) -> void:
	if not current_target or not subsystem_display:
		return
	
	subsystem_display.update_subsystem_status(subsystems)

## Update target data from current target
func _update_target_data() -> void:
	if not current_target:
		target_data.clear()
		return
	
	# Collect basic target information
	target_data = {
		"name": _get_target_name(current_target),
		"class": _get_target_class(current_target),
		"type": _get_target_type(current_target),
		"hull_percentage": _get_hull_percentage(current_target),
		"shield_percentage": _get_shield_percentage(current_target),
		"shield_quadrants": _get_shield_quadrants(100.0),
		"distance": _get_target_distance(current_target),
		"velocity": _get_target_velocity(current_target),
		"heading": _get_target_heading(current_target),
		"hostility": _get_hostility_status(current_target),
		"subsystems": _get_subsystem_data(current_target),
		"weapons": _get_weapon_data(current_target),
		"cargo": _get_cargo_data(current_target)
	}
	
	# Perform tactical assessment
	var assessment = tactical_analyzer.assess_target_threat(current_target)
	target_data["tactical_assessment"] = assessment
	
	last_update_time = Time.get_time_dict_from_system()["unix"]

## Update all display components
func _update_all_displays() -> void:
	if not current_target:
		return
	
	# Update info panel
	if info_panel:
		info_panel.update_target_info(target_data)
	
	# Update status visualizer
	if status_visualizer:
		var hull = target_data.get("hull_percentage", 0.0)
		var shields = target_data.get("shield_quadrants", [])
		status_visualizer.update_hull_display(hull)
		status_visualizer.update_shield_display(shields)
		status_visualizer.update_threat_display(target_data.get("tactical_assessment", {}))
	
	# Update subsystem display
	if subsystem_display:
		var subsystems = target_data.get("subsystems", {})
		subsystem_display.update_subsystem_status(subsystems)

## Clear target data and displays
func _clear_target_data() -> void:
	target_data.clear()
	
	if info_panel:
		info_panel.clear_display()
	
	if status_visualizer:
		status_visualizer.clear_display()
	
	if subsystem_display:
		subsystem_display.clear_display()

## Target data extraction methods
func _get_target_name(target: Node) -> String:
	if target.has_method("get_ship_name"):
		return target.get_ship_name()
	elif target.has_method("get_name"):
		return target.get_name()
	else:
		return target.name

func _get_target_class(target: Node) -> String:
	if target.has_method("get_ship_class"):
		return target.get_ship_class()
	else:
		return "Unknown Class"

func _get_target_type(target: Node) -> String:
	if target.has_method("get_ship_type"):
		return target.get_ship_type()
	else:
		return "Unknown Type"

func _get_hull_percentage(target: Node) -> float:
	if target.has_method("get_hull_percentage"):
		return target.get_hull_percentage()
	elif target.has_method("get_health_percentage"):
		return target.get_health_percentage()
	else:
		return 100.0

func _get_shield_percentage(target: Node) -> float:
	if target.has_method("get_shield_percentage"):
		return target.get_shield_percentage()
	else:
		return 0.0

func _get_shield_quadrants(base_shields: float) -> Array[float]:
	# Return individual shield quadrant values
	if current_target and current_target.has_method("get_shield_quadrants"):
		return current_target.get_shield_quadrants()
	else:
		# Default to even distribution
		var quadrant_value = base_shields / 4.0
		return [quadrant_value, quadrant_value, quadrant_value, quadrant_value]

func _get_target_distance(target: Node) -> float:
	if not target.has_method("get_global_position"):
		return 0.0
	
	# Get player position for distance calculation
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.has_method("get_global_position"):
		return 0.0
	
	return target.get_global_position().distance_to(player.get_global_position())

func _get_target_velocity(target: Node) -> Vector3:
	if target.has_method("get_velocity"):
		return target.get_velocity()
	else:
		return Vector3.ZERO

func _get_target_heading(target: Node) -> float:
	if target.has_method("get_heading"):
		return target.get_heading()
	elif target.has_method("get_global_rotation"):
		return target.get_global_rotation().y
	else:
		return 0.0

func _get_hostility_status(target: Node) -> String:
	if target.has_method("get_hostility_status"):
		return target.get_hostility_status()
	elif target.has_method("get_team"):
		var team = target.get_team()
		match team:
			0: return "friendly"
			1: return "hostile"
			2: return "neutral"
			_: return "unknown"
	else:
		return "unknown"

func _get_subsystem_data(target: Node) -> Dictionary:
	if target.has_method("get_subsystem_status"):
		return target.get_subsystem_status()
	else:
		# Return default subsystem data
		return {
			"engines": {"health": 100.0, "operational": true},
			"weapons": {"health": 100.0, "operational": true},
			"sensors": {"health": 100.0, "operational": true},
			"communication": {"health": 100.0, "operational": true}
		}

func _get_weapon_data(target: Node) -> Array[Dictionary]:
	if target.has_method("get_weapon_loadout"):
		return target.get_weapon_loadout()
	else:
		return []

func _get_cargo_data(target: Node) -> Dictionary:
	if target.has_method("get_cargo_info"):
		return target.get_cargo_info()
	else:
		return {}

## Animation and transitions
func _animate_target_transition(old_target: Node, new_target: Node) -> void:
	if not smooth_transitions:
		return
	
	# Create smooth transition effect
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fade out old target info
	if old_target:
		tween.tween_property(self, "modulate:a", 0.5, 0.15)
	
	# Fade in new target info
	if new_target:
		tween.tween_property(self, "modulate:a", 1.0, 0.15)
		tween.tween_delay(0.15)

## Signal handlers
func _on_subsystem_selected(subsystem_name: String) -> void:
	print("TargetDisplay: Subsystem selected: %s" % subsystem_name)
	subsystem_selected.emit(subsystem_name)

func _on_critical_damage() -> void:
	print("TargetDisplay: Critical damage detected on target")
	# Flash display or add warning indicator
	_flash_critical_warning()

func _on_threat_assessment_updated(assessment: Dictionary) -> void:
	var threat_level = assessment.get("threat_level", 0)
	threat_level_changed.emit(threat_level)

## Visual effects
func _flash_critical_warning() -> void:
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

## Public interface for HUD system
func get_element_data() -> Dictionary:
	return target_data

func get_current_target() -> Node:
	return current_target

func has_active_target() -> bool:
	return current_target != null
