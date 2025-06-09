class_name FiringOpportunityAlert
extends Node2D

## Optimal firing timing alerts for HUD-007
## Analyzes multiple factors to determine optimal firing windows
## Provides visual and audio cues for maximum combat effectiveness

# Opportunity types
enum OpportunityType {
	PERFECT_SHOT,		# Perfect firing opportunity
	HIGH_DAMAGE,		# High damage potential
	CRITICAL_HIT,		# Critical hit opportunity
	SUBSYSTEM_SHOT,		# Subsystem targeting opportunity
	DEFLECTION_SHOT,	# Deflection shooting opportunity
	CONVERGENCE_OPTIMAL,# Weapons optimally converged
	ENERGY_EFFICIENT,	# Energy efficient firing window
	STEALTH_BREAK		# Target stealth breaking opportunity
}

# Alert priority levels
enum AlertPriority {
	LOW,				# Minor opportunity
	MEDIUM,				# Good opportunity
	HIGH,				# Excellent opportunity
	CRITICAL			# Perfect opportunity
}

# Alert display styles
enum AlertStyle {
	SUBTLE,				# Subtle visual cues
	STANDARD,			# Standard alert display
	AGGRESSIVE,			# Aggressive attention-getting
	MINIMAL				# Minimal distraction
}

# Firing opportunity data
class FiringOpportunity:
	var opportunity_type: OpportunityType = OpportunityType.PERFECT_SHOT
	var priority: AlertPriority = AlertPriority.LOW
	var duration: float = 0.0
	var time_remaining: float = 0.0
	var confidence: float = 0.0
	var damage_multiplier: float = 1.0
	var hit_probability: float = 0.0
	var description: String = ""

# Display configuration
@export_group("Display Configuration")
@export var alert_style: AlertStyle = AlertStyle.STANDARD
@export var show_opportunity_text: bool = true
@export var show_timing_bar: bool = true
@export var show_damage_prediction: bool = true
@export var show_confidence_indicator: bool = true
@export var max_simultaneous_alerts: int = 3

# Visual settings
@export_group("Visual Settings")
@export var alert_position: Vector2 = Vector2(400, 100)
@export var alert_spacing: float = 40.0
@export var timing_bar_width: float = 200.0
@export var timing_bar_height: float = 8.0
@export var confidence_bar_width: float = 100.0
@export var alert_icon_size: float = 24.0

# Color settings
@export_group("Colors")
@export var color_critical: Color = Color.RED
@export var color_high: Color = Color.ORANGE
@export var color_medium: Color = Color.YELLOW
@export var color_low: Color = Color.LIGHT_GRAY
@export var color_timing_bar: Color = Color.CYAN
@export var color_confidence: Color = Color.GREEN
@export var color_background: Color = Color(0.0, 0.0, 0.0, 0.8)

# Animation settings
@export_group("Animation")
@export var flash_critical_alerts: bool = true
@export var flash_frequency: float = 3.0
@export var pulse_high_priority: bool = true
@export var slide_in_animation: bool = true
@export var fade_out_duration: float = 0.5

# Audio settings
@export_group("Audio")
@export var play_audio_alerts: bool = true
@export var audio_volume: float = 0.7
@export var different_sounds_per_priority: bool = true

# Current opportunities
var active_opportunities: Array[FiringOpportunity] = []
var opportunity_start_times: Array[float] = []

# Alert analysis parameters
var target_analysis_data: Dictionary = {}
var weapon_analysis_data: Dictionary = {}
var tactical_situation: Dictionary = {}

# Animation state
var _animation_time: float = 0.0
var _flash_state: bool = false
var _alert_slide_positions: Array[float] = []

# Audio components
@onready var critical_alert_audio: AudioStreamPlayer = $CriticalAlertAudio
@onready var high_alert_audio: AudioStreamPlayer = $HighAlertAudio
@onready var medium_alert_audio: AudioStreamPlayer = $MediumAlertAudio

# References
var player_ship: Node3D = null
var weapon_manager: Node = null
var targeting_system: Node = null

# Performance optimization
var analysis_frequency: float = 10.0  # Hz
var last_analysis_time: float = 0.0

func _ready() -> void:
	set_process(true)
	_initialize_firing_opportunity_alert()
	_setup_audio_components()

## Initialize firing opportunity alert system
func _initialize_firing_opportunity_alert() -> void:
	"""Initialize firing opportunity analysis system."""
	# Get player ship reference
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		player_ship = player_nodes[0]
		
		# Get weapon manager
		if player_ship.has_method("get_weapon_manager"):
			weapon_manager = player_ship.get_weapon_manager()
		
		# Get targeting system
		if player_ship.has_method("get_targeting_system"):
			targeting_system = player_ship.get_targeting_system()

## Setup audio components
func _setup_audio_components() -> void:
	"""Setup audio streams for different alert types."""
	if critical_alert_audio:
		# critical_alert_audio.stream = preload("res://audio/hud/critical_opportunity.ogg")
		critical_alert_audio.volume_db = linear_to_db(audio_volume)
	
	if high_alert_audio:
		# high_alert_audio.stream = preload("res://audio/hud/high_opportunity.ogg")
		high_alert_audio.volume_db = linear_to_db(audio_volume * 0.8)
	
	if medium_alert_audio:
		# medium_alert_audio.stream = preload("res://audio/hud/medium_opportunity.ogg")
		medium_alert_audio.volume_db = linear_to_db(audio_volume * 0.6)

## Update firing opportunity analysis
func update_firing_analysis(
	target_data: Dictionary,
	weapon_data: Dictionary,
	tactical_data: Dictionary
) -> void:
	"""Update firing opportunity analysis with current game state."""
	var current_time: float = Time.get_ticks_msec() / 1000.0
	
	# Limit analysis frequency for performance
	if current_time - last_analysis_time < (1.0 / analysis_frequency):
		return
	
	last_analysis_time = current_time
	
	# Store analysis data
	target_analysis_data = target_data
	weapon_analysis_data = weapon_data
	tactical_situation = tactical_data
	
	# Update existing opportunities
	_update_existing_opportunities(current_time)
	
	# Analyze for new opportunities
	_analyze_firing_opportunities()
	
	# Sort opportunities by priority
	_sort_opportunities_by_priority()
	
	# Limit number of simultaneous alerts
	_limit_simultaneous_alerts()
	
	queue_redraw()

## Update existing opportunities
func _update_existing_opportunities(current_time: float) -> void:
	"""Update timing and validity of existing opportunities."""
	var i: int = 0
	while i < active_opportunities.size():
		var opportunity: FiringOpportunity = active_opportunities[i]
		var start_time: float = opportunity_start_times[i]
		
		# Update time remaining
		var elapsed_time: float = current_time - start_time
		opportunity.time_remaining = maxf(0.0, opportunity.duration - elapsed_time)
		
		# Remove expired opportunities
		if opportunity.time_remaining <= 0.0:
			active_opportunities.remove_at(i)
			opportunity_start_times.remove_at(i)
			_alert_slide_positions.remove_at(i)
		else:
			i += 1

## Analyze for new firing opportunities
func _analyze_firing_opportunities() -> void:
	"""Analyze current situation for new firing opportunities."""
	if not target_analysis_data or not weapon_analysis_data:
		return
	
	# Analyze different opportunity types
	_analyze_perfect_shot_opportunity()
	_analyze_high_damage_opportunity()
	_analyze_critical_hit_opportunity()
	_analyze_subsystem_opportunity()
	_analyze_deflection_shot_opportunity()
	_analyze_convergence_opportunity()
	_analyze_energy_efficiency_opportunity()
	_analyze_stealth_break_opportunity()

## Analyze perfect shot opportunity
func _analyze_perfect_shot_opportunity() -> void:
	"""Analyze for perfect shot opportunities."""
	var hit_prob: float = target_analysis_data.get("hit_probability", 0.0)
	var target_stability: float = target_analysis_data.get("stability", 0.0)
	var weapon_readiness: float = weapon_analysis_data.get("readiness", 0.0)
	
	# Perfect shot requires high hit probability, stable target, and ready weapons
	if hit_prob >= 0.9 and target_stability >= 0.8 and weapon_readiness >= 0.9:
		var confidence: float = (hit_prob + target_stability + weapon_readiness) / 3.0
		
		if not _has_opportunity_type(OpportunityType.PERFECT_SHOT):
			_create_opportunity(
				OpportunityType.PERFECT_SHOT,
				AlertPriority.CRITICAL,
				2.0,  # 2 second window
				confidence,
				1.5,  # 50% damage bonus
				hit_prob,
				"Perfect Shot!"
			)

## Analyze high damage opportunity
func _analyze_high_damage_opportunity() -> void:
	"""Analyze for high damage opportunities."""
	var target_vulnerability: float = target_analysis_data.get("vulnerability", 0.0)
	var weapon_damage_potential: float = weapon_analysis_data.get("damage_potential", 0.0)
	var range_optimality: float = target_analysis_data.get("range_optimality", 0.0)
	
	# High damage when target is vulnerable and weapons are optimal
	if target_vulnerability >= 0.7 and weapon_damage_potential >= 0.8 and range_optimality >= 0.7:
		var confidence: float = (target_vulnerability + weapon_damage_potential + range_optimality) / 3.0
		var damage_mult: float = 1.0 + (target_vulnerability * 0.5) + (weapon_damage_potential * 0.3)
		
		if not _has_opportunity_type(OpportunityType.HIGH_DAMAGE):
			_create_opportunity(
				OpportunityType.HIGH_DAMAGE,
				AlertPriority.HIGH,
				3.0,
				confidence,
				damage_mult,
				target_analysis_data.get("hit_probability", 0.0),
				"High Damage Window"
			)

## Analyze critical hit opportunity
func _analyze_critical_hit_opportunity() -> void:
	"""Analyze for critical hit opportunities."""
	var target_angle: float = target_analysis_data.get("angle", 0.0)
	var target_shields: float = target_analysis_data.get("shield_strength", 1.0)
	var critical_angle_window: bool = abs(target_angle) < deg_to_rad(15.0)  # Rear/side shot
	
	# Critical hit when target has low shields and good angle
	if target_shields <= 0.3 and critical_angle_window:
		var confidence: float = (1.0 - target_shields) * 0.7 + 0.3
		
		if not _has_opportunity_type(OpportunityType.CRITICAL_HIT):
			_create_opportunity(
				OpportunityType.CRITICAL_HIT,
				AlertPriority.HIGH,
				2.5,
				confidence,
				2.0,  # Double damage potential
				target_analysis_data.get("hit_probability", 0.0),
				"Critical Hit!"
			)

## Analyze subsystem targeting opportunity
func _analyze_subsystem_opportunity() -> void:
	"""Analyze for subsystem targeting opportunities."""
	var subsystem_exposed: bool = target_analysis_data.get("subsystem_exposed", false)
	var subsystem_critical: bool = target_analysis_data.get("subsystem_critical", false)
	var precision_weapons: bool = weapon_analysis_data.get("has_precision_weapons", false)
	
	# Subsystem opportunity when exposed and we have precision weapons
	if subsystem_exposed and precision_weapons:
		var priority: AlertPriority = AlertPriority.HIGH if subsystem_critical else AlertPriority.MEDIUM
		var confidence: float = 0.7 if subsystem_critical else 0.5
		
		if not _has_opportunity_type(OpportunityType.SUBSYSTEM_SHOT):
			_create_opportunity(
				OpportunityType.SUBSYSTEM_SHOT,
				priority,
				4.0,
				confidence,
				1.2,
				target_analysis_data.get("hit_probability", 0.0),
				"Subsystem Exposed"
			)

## Analyze deflection shot opportunity
func _analyze_deflection_shot_opportunity() -> void:
	"""Analyze for deflection shooting opportunities."""
	var target_predictable: bool = target_analysis_data.get("movement_predictable", false)
	var intercept_solution: bool = weapon_analysis_data.get("has_intercept_solution", false)
	var target_velocity: float = target_analysis_data.get("velocity_magnitude", 0.0)
	
	# Deflection shot when target movement is predictable and we have solution
	if target_predictable and intercept_solution and target_velocity > 50.0:
		var confidence: float = target_analysis_data.get("prediction_confidence", 0.0)
		
		if not _has_opportunity_type(OpportunityType.DEFLECTION_SHOT):
			_create_opportunity(
				OpportunityType.DEFLECTION_SHOT,
				AlertPriority.MEDIUM,
				3.5,
				confidence,
				1.3,
				target_analysis_data.get("hit_probability", 0.0),
				"Deflection Shot"
			)

## Analyze weapon convergence opportunity
func _analyze_convergence_opportunity() -> void:
	"""Analyze for optimal weapon convergence opportunities."""
	var convergence_quality: float = weapon_analysis_data.get("convergence_quality", 0.0)
	var target_at_convergence: bool = target_analysis_data.get("at_convergence_range", false)
	
	# Convergence opportunity when target is at optimal convergence range
	if convergence_quality >= 0.8 and target_at_convergence:
		var confidence: float = convergence_quality
		
		if not _has_opportunity_type(OpportunityType.CONVERGENCE_OPTIMAL):
			_create_opportunity(
				OpportunityType.CONVERGENCE_OPTIMAL,
				AlertPriority.MEDIUM,
				2.0,
				confidence,
				1.4,  # Convergence damage bonus
				target_analysis_data.get("hit_probability", 0.0),
				"Optimal Convergence"
			)

## Analyze energy efficiency opportunity
func _analyze_energy_efficiency_opportunity() -> void:
	"""Analyze for energy efficient firing opportunities."""
	var energy_level: float = weapon_analysis_data.get("energy_level", 0.0)
	var energy_recharge: bool = weapon_analysis_data.get("energy_recharging", false)
	var shot_efficiency: float = weapon_analysis_data.get("shot_efficiency", 0.0)
	
	# Energy efficiency when we have good energy and efficient shot opportunity
	if energy_level >= 0.8 and shot_efficiency >= 0.7 and not energy_recharge:
		var confidence: float = (energy_level + shot_efficiency) / 2.0
		
		if not _has_opportunity_type(OpportunityType.ENERGY_EFFICIENT):
			_create_opportunity(
				OpportunityType.ENERGY_EFFICIENT,
				AlertPriority.LOW,
				3.0,
				confidence,
				1.1,
				target_analysis_data.get("hit_probability", 0.0),
				"Energy Efficient"
			)

## Analyze stealth break opportunity
func _analyze_stealth_break_opportunity() -> void:
	"""Analyze for stealth breaking opportunities."""
	var target_stealth: float = target_analysis_data.get("stealth_level", 0.0)
	var stealth_breaking: bool = target_analysis_data.get("stealth_breaking", false)
	var detection_window: bool = target_analysis_data.get("detection_window", false)
	
	# Stealth break opportunity when stealth is compromised
	if target_stealth > 0.3 and (stealth_breaking or detection_window):
		var confidence: float = 1.0 - target_stealth
		
		if not _has_opportunity_type(OpportunityType.STEALTH_BREAK):
			_create_opportunity(
				OpportunityType.STEALTH_BREAK,
				AlertPriority.HIGH,
				1.5,  # Short window
				confidence,
				1.6,  # Significant damage bonus for stealth break
				target_analysis_data.get("hit_probability", 0.0),
				"Stealth Compromised!"
			)

## Create new firing opportunity
func _create_opportunity(
	type: OpportunityType,
	priority: AlertPriority,
	duration: float,
	confidence: float,
	damage_mult: float,
	hit_prob: float,
	description: String
) -> void:
	"""Create a new firing opportunity alert."""
	var opportunity := FiringOpportunity.new()
	opportunity.opportunity_type = type
	opportunity.priority = priority
	opportunity.duration = duration
	opportunity.time_remaining = duration
	opportunity.confidence = confidence
	opportunity.damage_multiplier = damage_mult
	opportunity.hit_probability = hit_prob
	opportunity.description = description
	
	active_opportunities.append(opportunity)
	opportunity_start_times.append(Time.get_ticks_msec() / 1000.0)
	_alert_slide_positions.append(0.0)  # Start off-screen
	
	# Play audio alert
	_play_audio_alert(priority)

## Check if opportunity type already exists
func _has_opportunity_type(type: OpportunityType) -> bool:
	"""Check if we already have an alert of this type."""
	for opportunity in active_opportunities:
		if opportunity.opportunity_type == type:
			return true
	return false

## Sort opportunities by priority
func _sort_opportunities_by_priority() -> void:
	"""Sort opportunities by priority level."""
	# Create combined array for sorting
	var combined_data: Array = []
	for i in range(active_opportunities.size()):
		combined_data.append([active_opportunities[i], opportunity_start_times[i], _alert_slide_positions[i]])
	
	# Sort by priority (higher priority first)
	combined_data.sort_custom(func(a, b): return a[0].priority > b[0].priority)
	
	# Reconstruct arrays
	active_opportunities.clear()
	opportunity_start_times.clear()
	_alert_slide_positions.clear()
	
	for data in combined_data:
		active_opportunities.append(data[0])
		opportunity_start_times.append(data[1])
		_alert_slide_positions.append(data[2])

## Limit simultaneous alerts
func _limit_simultaneous_alerts() -> void:
	"""Limit number of simultaneous alerts shown."""
	while active_opportunities.size() > max_simultaneous_alerts:
		# Remove lowest priority alerts
		var lowest_priority: int = AlertPriority.CRITICAL
		var lowest_index: int = -1
		
		for i in range(active_opportunities.size()):
			if active_opportunities[i].priority < lowest_priority:
				lowest_priority = active_opportunities[i].priority
				lowest_index = i
		
		if lowest_index >= 0:
			active_opportunities.remove_at(lowest_index)
			opportunity_start_times.remove_at(lowest_index)
			_alert_slide_positions.remove_at(lowest_index)

## Play audio alert
func _play_audio_alert(priority: AlertPriority) -> void:
	"""Play audio alert based on priority."""
	if not play_audio_alerts:
		return
	
	match priority:
		AlertPriority.CRITICAL:
			if critical_alert_audio:
				critical_alert_audio.play()
		AlertPriority.HIGH:
			if high_alert_audio:
				high_alert_audio.play()
		AlertPriority.MEDIUM:
			if medium_alert_audio:
				medium_alert_audio.play()

## Get priority color
func _get_priority_color(priority: AlertPriority) -> Color:
	"""Get color based on alert priority."""
	match priority:
		AlertPriority.CRITICAL:
			return color_critical
		AlertPriority.HIGH:
			return color_high
		AlertPriority.MEDIUM:
			return color_medium
		AlertPriority.LOW:
			return color_low
		_:
			return Color.WHITE

## Main drawing method
func _draw() -> void:
	"""Main drawing method for firing opportunity alerts."""
	if active_opportunities.is_empty():
		return
	
	# Draw based on alert style
	match alert_style:
		AlertStyle.SUBTLE:
			_draw_subtle_alerts()
		AlertStyle.STANDARD:
			_draw_standard_alerts()
		AlertStyle.AGGRESSIVE:
			_draw_aggressive_alerts()
		AlertStyle.MINIMAL:
			_draw_minimal_alerts()

## Draw subtle alerts
func _draw_subtle_alerts() -> void:
	"""Draw subtle alert display."""
	for i in range(active_opportunities.size()):
		var opportunity: FiringOpportunity = active_opportunities[i]
		var position: Vector2 = alert_position + Vector2(0, i * alert_spacing)
		var priority_color: Color = _get_priority_color(opportunity.priority)
		
		# Subtle indicator - just a small colored dot and text
		draw_circle(position, 4, priority_color)
		
		if show_opportunity_text:
			var font := ThemeDB.fallback_font
			var font_size := 12
			draw_string(font, position + Vector2(10, 4), opportunity.description,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, priority_color)

## Draw standard alerts
func _draw_standard_alerts() -> void:
	"""Draw standard alert display."""
	for i in range(active_opportunities.size()):
		var opportunity: FiringOpportunity = active_opportunities[i]
		var position: Vector2 = alert_position + Vector2(0, i * alert_spacing)
		
		_draw_opportunity_panel(position, opportunity, i)

## Draw aggressive alerts
func _draw_aggressive_alerts() -> void:
	"""Draw aggressive attention-getting alerts."""
	for i in range(active_opportunities.size()):
		var opportunity: FiringOpportunity = active_opportunities[i]
		var position: Vector2 = alert_position + Vector2(0, i * alert_spacing)
		
		# Enhanced visual effects for aggressive style
		var priority_color: Color = _get_priority_color(opportunity.priority)
		
		# Flash critical alerts
		if opportunity.priority == AlertPriority.CRITICAL and flash_critical_alerts and _flash_state:
			priority_color = priority_color.lerp(Color.WHITE, 0.5)
		
		_draw_opportunity_panel(position, opportunity, i, priority_color)
		
		# Additional visual effects for high priority
		if opportunity.priority >= AlertPriority.HIGH:
			var pulse_size: float = alert_icon_size * (1.0 + 0.2 * sin(_animation_time * 4.0))
			draw_circle(position + Vector2(alert_icon_size / 2, alert_icon_size / 2), pulse_size, 
				Color(priority_color.r, priority_color.g, priority_color.b, 0.3))

## Draw minimal alerts
func _draw_minimal_alerts() -> void:
	"""Draw minimal distraction alerts."""
	# Only show highest priority alert
	if not active_opportunities.is_empty():
		var opportunity: FiringOpportunity = active_opportunities[0]
		var position: Vector2 = alert_position
		var priority_color: Color = _get_priority_color(opportunity.priority)
		
		# Just a small icon
		_draw_opportunity_icon(position, opportunity.opportunity_type, priority_color)

## Draw opportunity panel
func _draw_opportunity_panel(position: Vector2, opportunity: FiringOpportunity, index: int, override_color: Color = Color.TRANSPARENT) -> void:
	"""Draw complete opportunity alert panel."""
	var priority_color: Color = override_color if override_color != Color.TRANSPARENT else _get_priority_color(opportunity.priority)
	
	# Background panel
	var panel_width: float = 300.0
	var panel_height: float = 35.0
	var panel_rect := Rect2(position, Vector2(panel_width, panel_height))
	
	draw_rect(panel_rect, color_background)
	draw_rect(panel_rect, priority_color, false, 2.0)
	
	# Opportunity icon
	var icon_pos: Vector2 = position + Vector2(5, 5)
	_draw_opportunity_icon(icon_pos, opportunity.opportunity_type, priority_color)
	
	# Opportunity text
	var font := ThemeDB.fallback_font
	var font_size := 14
	if show_opportunity_text:
		var text_pos: Vector2 = position + Vector2(35, font_size + 5)
		draw_string(font, text_pos, opportunity.description,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, priority_color)
	
	# Timing bar
	if show_timing_bar:
		var bar_pos: Vector2 = position + Vector2(150, 8)
		_draw_timing_bar(bar_pos, opportunity)
	
	# Confidence indicator
	if show_confidence_indicator:
		var conf_pos: Vector2 = position + Vector2(150, 20)
		_draw_confidence_indicator(conf_pos, opportunity)
	
	# Damage prediction
	if show_damage_prediction:
		var damage_pos: Vector2 = position + Vector2(260, font_size + 5)
		_draw_damage_prediction(damage_pos, opportunity)

## Draw opportunity icon
func _draw_opportunity_icon(position: Vector2, type: OpportunityType, color: Color) -> void:
	"""Draw icon representing opportunity type."""
	var size: float = alert_icon_size
	
	match type:
		OpportunityType.PERFECT_SHOT:
			# Crosshair with center dot
			draw_line(position, position + Vector2(size, 0), color, 2.0)
			draw_line(position + Vector2(0, size/2), position + Vector2(size, size/2), color, 2.0)
			draw_line(position + Vector2(size/2, 0), position + Vector2(size/2, size), color, 2.0)
			draw_circle(position + Vector2(size/2, size/2), 3, color)
		
		OpportunityType.HIGH_DAMAGE:
			# Lightning bolt shape
			var points: PackedVector2Array = PackedVector2Array([
				position + Vector2(size*0.3, 0),
				position + Vector2(size*0.7, size*0.4),
				position + Vector2(size*0.5, size*0.4),
				position + Vector2(size*0.8, size),
				position + Vector2(size*0.4, size*0.6),
				position + Vector2(size*0.6, size*0.6)
			])
			draw_polyline(points, color, 2.0)
		
		OpportunityType.CRITICAL_HIT:
			# Exclamation mark
			draw_line(position + Vector2(size/2, 0), position + Vector2(size/2, size*0.7), color, 3.0)
			draw_circle(position + Vector2(size/2, size*0.85), 2, color)
		
		OpportunityType.SUBSYSTEM_SHOT:
			# Target with center marked
			draw_circle(position + Vector2(size/2, size/2), size/2, color, false, 2.0)
			draw_circle(position + Vector2(size/2, size/2), size/4, color, false, 2.0)
			draw_circle(position + Vector2(size/2, size/2), 2, color)
		
		_:
			# Default circle
			draw_circle(position + Vector2(size/2, size/2), size/2, color, false, 2.0)

## Draw timing bar
func _draw_timing_bar(position: Vector2, opportunity: FiringOpportunity) -> void:
	"""Draw timing bar showing remaining opportunity window."""
	var bar_rect := Rect2(position, Vector2(timing_bar_width, timing_bar_height))
	var progress: float = opportunity.time_remaining / opportunity.duration
	var fill_width: float = timing_bar_width * progress
	var fill_rect := Rect2(position, Vector2(fill_width, timing_bar_height))
	
	# Background
	draw_rect(bar_rect, Color.BLACK)
	
	# Fill
	draw_rect(fill_rect, color_timing_bar)
	
	# Border
	draw_rect(bar_rect, Color.WHITE, false, 1.0)

## Draw confidence indicator
func _draw_confidence_indicator(position: Vector2, opportunity: FiringOpportunity) -> void:
	"""Draw confidence level indicator."""
	var bar_rect := Rect2(position, Vector2(confidence_bar_width, 4))
	var confidence_width: float = confidence_bar_width * opportunity.confidence
	var conf_rect := Rect2(position, Vector2(confidence_width, 4))
	
	# Background
	draw_rect(bar_rect, Color.BLACK)
	
	# Fill
	draw_rect(conf_rect, color_confidence)
	
	# Border
	draw_rect(bar_rect, Color.WHITE, false, 1.0)

## Draw damage prediction
func _draw_damage_prediction(position: Vector2, opportunity: FiringOpportunity) -> void:
	"""Draw predicted damage multiplier."""
	var font := ThemeDB.fallback_font
	var font_size := 12
	var damage_text: String = "x%.1f" % opportunity.damage_multiplier
	var text_color: Color = color_high if opportunity.damage_multiplier > 1.5 else color_medium
	
	draw_string(font, position, damage_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

## Process animation updates
func _process(delta: float) -> void:
	"""Process firing opportunity alert animations."""
	# Update animation time
	_animation_time += delta
	
	# Update flash state
	_flash_state = fmod(_animation_time * flash_frequency, 1.0) < 0.5
	
	# Update slide animations
	for i in range(_alert_slide_positions.size()):
		if slide_in_animation:
			_alert_slide_positions[i] = move_toward(_alert_slide_positions[i], 1.0, delta * 3.0)
	
	# Redraw if we have active alerts
	if not active_opportunities.is_empty():
		queue_redraw()

## Public interface

## Set alert display style
func set_alert_style(style: AlertStyle) -> void:
	"""Set alert display style."""
	alert_style = style
	queue_redraw()

## Configure display elements
func configure_display_elements(
	text: bool = true,
	timing: bool = true,
	damage: bool = true,
	confidence: bool = true
) -> void:
	"""Configure which alert elements are displayed."""
	show_opportunity_text = text
	show_timing_bar = timing
	show_damage_prediction = damage
	show_confidence_indicator = confidence
	queue_redraw()

## Set alert position
func set_alert_position(position: Vector2) -> void:
	"""Set base position for alert display."""
	alert_position = position
	queue_redraw()

## Enable/disable audio alerts
func set_audio_alerts_enabled(enabled: bool) -> void:
	"""Enable or disable audio alerts."""
	play_audio_alerts = enabled

## Get active opportunities
func get_active_opportunities() -> Array[Dictionary]:
	"""Get array of active firing opportunities."""
	var opportunities: Array[Dictionary] = []
	
	for opportunity in active_opportunities:
		opportunities.append({
			"type": opportunity.opportunity_type,
			"priority": opportunity.priority,
			"time_remaining": opportunity.time_remaining,
			"confidence": opportunity.confidence,
			"damage_multiplier": opportunity.damage_multiplier,
			"description": opportunity.description
		})
	
	return opportunities

## Check if critical opportunity is active
func has_critical_opportunity() -> bool:
	"""Check if any critical opportunities are active."""
	for opportunity in active_opportunities:
		if opportunity.priority == AlertPriority.CRITICAL:
			return true
	return false

## Get best opportunity
func get_best_opportunity() -> Dictionary:
	"""Get the highest priority active opportunity."""
	if active_opportunities.is_empty():
		return {}
	
	var best_opportunity: FiringOpportunity = active_opportunities[0]
	return {
		"type": best_opportunity.opportunity_type,
		"priority": best_opportunity.priority,
		"time_remaining": best_opportunity.time_remaining,
		"confidence": best_opportunity.confidence,
		"damage_multiplier": best_opportunity.damage_multiplier,
		"description": best_opportunity.description
	}

## Clear all opportunities
func clear_all_opportunities() -> void:
	"""Clear all active opportunities."""
	active_opportunities.clear()
	opportunity_start_times.clear()
	_alert_slide_positions.clear()
	queue_redraw()
