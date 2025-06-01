class_name PilotStatsController
extends Control

## WCS pilot statistics display controller providing detailed pilot progression data.
## Shows comprehensive pilot statistics, medals, campaign progress, and performance metrics.
## Integrates with PlayerProfile system for complete pilot data visualization.

signal stats_view_closed()
signal pilot_profile_requested(callsign: String)

# UI configuration
@export var show_detailed_stats: bool = true
@export var show_medal_display: bool = true
@export var show_campaign_progress: bool = true
@export var enable_stats_comparison: bool = false

# Internal components
var main_container: VBoxContainer = null
var title_label: Label = null
var pilot_header: Control = null
var pilot_image: TextureRect = null
var pilot_info_container: VBoxContainer = null
var stats_tabs: TabContainer = null
var general_stats_tab: Control = null
var combat_stats_tab: Control = null
var campaign_stats_tab: Control = null
var medals_tab: Control = null
var button_container: HBoxContainer = null
var close_button: MenuButton = null

# Statistics display containers
var general_stats_container: VBoxContainer = null
var combat_stats_container: VBoxContainer = null
var campaign_stats_container: VBoxContainer = null
var medals_container: GridContainer = null

# Data management
var pilot_manager: PilotDataManager = null
var current_profile: PlayerProfile = null
var current_callsign: String = ""

# Theme integration
var ui_theme_manager: UIThemeManager = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_pilot_stats()

func _initialize_pilot_stats() -> void:
	"""Initialize pilot statistics scene with WCS styling and components."""
	print("PilotStatsController: Initializing pilot statistics interface")
	
	# Connect to theme manager
	_connect_to_theme_manager()
	
	# Initialize pilot manager
	pilot_manager = PilotDataManager.new()
	
	# Setup scene structure
	_create_scene_structure()
	_setup_scene_styling()

func _connect_to_theme_manager() -> void:
	"""Connect to UIThemeManager for consistent styling."""
	var theme_manager: Node = get_tree().get_first_node_in_group("ui_theme_manager")
	if theme_manager and theme_manager is UIThemeManager:
		ui_theme_manager = theme_manager as UIThemeManager
		ui_theme_manager.theme_changed.connect(_on_theme_changed)

func _create_scene_structure() -> void:
	"""Create the pilot statistics scene structure."""
	# Set as full-screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Main container
	main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 20)
	add_child(main_container)
	
	# Title
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Pilot Statistics"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title_label)
	
	# Pilot header
	_create_pilot_header()
	
	# Statistics tabs
	_create_statistics_tabs()
	
	# Button container
	button_container = HBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 15)
	main_container.add_child(button_container)
	
	_create_action_buttons()

func _create_pilot_header() -> void:
	"""Create pilot header with image and basic info."""
	pilot_header = Control.new()
	pilot_header.name = "PilotHeader"
	pilot_header.custom_minimum_size = Vector2(0, 120)
	main_container.add_child(pilot_header)
	
	var header_container: HBoxContainer = HBoxContainer.new()
	header_container.name = "HeaderContainer"
	header_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_container.add_theme_constant_override("separation", 20)
	pilot_header.add_child(header_container)
	
	# Pilot image
	pilot_image = TextureRect.new()
	pilot_image.name = "PilotImage"
	pilot_image.custom_minimum_size = Vector2(96, 96)
	pilot_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	pilot_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header_container.add_child(pilot_image)
	
	# Pilot info
	pilot_info_container = VBoxContainer.new()
	pilot_info_container.name = "PilotInfoContainer"
	pilot_info_container.add_theme_constant_override("separation", 5)
	pilot_info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(pilot_info_container)

func _create_statistics_tabs() -> void:
	"""Create statistics tab container."""
	stats_tabs = TabContainer.new()
	stats_tabs.name = "StatsTabContainer"
	stats_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(stats_tabs)
	
	# General stats tab
	_create_general_stats_tab()
	
	# Combat stats tab
	_create_combat_stats_tab()
	
	# Campaign progress tab
	if show_campaign_progress:
		_create_campaign_stats_tab()
	
	# Medals tab
	if show_medal_display:
		_create_medals_tab()

func _create_general_stats_tab() -> void:
	"""Create general statistics tab."""
	general_stats_tab = Control.new()
	general_stats_tab.name = "General"
	stats_tabs.add_child(general_stats_tab)
	
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "GeneralStatsScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	general_stats_tab.add_child(scroll)
	
	general_stats_container = VBoxContainer.new()
	general_stats_container.name = "GeneralStatsContainer"
	general_stats_container.add_theme_constant_override("separation", 10)
	scroll.add_child(general_stats_container)

func _create_combat_stats_tab() -> void:
	"""Create combat statistics tab."""
	combat_stats_tab = Control.new()
	combat_stats_tab.name = "Combat"
	stats_tabs.add_child(combat_stats_tab)
	
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "CombatStatsScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combat_stats_tab.add_child(scroll)
	
	combat_stats_container = VBoxContainer.new()
	combat_stats_container.name = "CombatStatsContainer"
	combat_stats_container.add_theme_constant_override("separation", 10)
	scroll.add_child(combat_stats_container)

func _create_campaign_stats_tab() -> void:
	"""Create campaign progress tab."""
	campaign_stats_tab = Control.new()
	campaign_stats_tab.name = "Campaigns"
	stats_tabs.add_child(campaign_stats_tab)
	
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "CampaignStatsScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	campaign_stats_tab.add_child(scroll)
	
	campaign_stats_container = VBoxContainer.new()
	campaign_stats_container.name = "CampaignStatsContainer"
	campaign_stats_container.add_theme_constant_override("separation", 15)
	scroll.add_child(campaign_stats_container)

func _create_medals_tab() -> void:
	"""Create medals display tab."""
	medals_tab = Control.new()
	medals_tab.name = "Medals"
	stats_tabs.add_child(medals_tab)
	
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "MedalsScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	medals_tab.add_child(scroll)
	
	medals_container = GridContainer.new()
	medals_container.name = "MedalsContainer"
	medals_container.columns = 4
	medals_container.add_theme_constant_override("h_separation", 15)
	medals_container.add_theme_constant_override("v_separation", 15)
	scroll.add_child(medals_container)

func _create_action_buttons() -> void:
	"""Create action buttons."""
	# Close button
	close_button = MenuButton.new()
	close_button.button_text = "Close"
	close_button.button_category = MenuButton.ButtonCategory.SECONDARY
	close_button.pressed.connect(_on_close_pressed)
	button_container.add_child(close_button)

func _setup_scene_styling() -> void:
	"""Apply WCS styling to scene components."""
	if not ui_theme_manager:
		return
	
	# Apply theme to controls
	ui_theme_manager.apply_theme_to_control(self)
	
	# Style title
	title_label.add_theme_color_override("font_color", ui_theme_manager.get_wcs_color("gray_light"))
	
	# Style tabs
	if stats_tabs:
		ui_theme_manager.apply_theme_to_control(stats_tabs)

# ============================================================================
# PILOT STATISTICS DISPLAY
# ============================================================================

func display_pilot_stats(callsign: String) -> void:
	"""Display statistics for specified pilot."""
	current_callsign = callsign
	
	# Load pilot profile
	current_profile = pilot_manager.load_pilot(callsign)
	if not current_profile:
		push_error("Failed to load pilot: %s" % callsign)
		return
	
	print("PilotStatsController: Displaying stats for pilot '%s'" % callsign)
	
	# Update pilot header
	_update_pilot_header()
	
	# Update statistics tabs
	_update_general_stats()
	_update_combat_stats()
	
	if show_campaign_progress:
		_update_campaign_stats()
	
	if show_medal_display:
		_update_medals_display()

func _update_pilot_header() -> void:
	"""Update pilot header information."""
	if not current_profile:
		return
	
	# Clear existing info
	for child in pilot_info_container.get_children():
		child.queue_free()
	
	# Callsign
	var callsign_label: Label = Label.new()
	callsign_label.text = "Callsign: %s" % current_profile.callsign
	callsign_label.add_theme_font_size_override("font_size", 20)
	pilot_info_container.add_child(callsign_label)
	
	# Squadron
	var squadron_label: Label = Label.new()
	squadron_label.text = "Squadron: %s" % current_profile.squad_name
	squadron_label.add_theme_font_size_override("font_size", 16)
	pilot_info_container.add_child(squadron_label)
	
	# Rank
	if current_profile.pilot_stats:
		var rank_label: Label = Label.new()
		rank_label.text = "Rank: %s" % _get_rank_name(current_profile.pilot_stats.rank)
		rank_label.add_theme_font_size_override("font_size", 16)
		pilot_info_container.add_child(rank_label)
	
	# Load pilot image
	_load_pilot_image()

func _load_pilot_image() -> void:
	"""Load pilot portrait image."""
	if not current_profile or not pilot_image:
		return
	
	if current_profile.image_filename.is_empty():
		pilot_image.texture = null
		return
	
	var image_path: String = "res://assets/images/pilots/" + current_profile.image_filename
	var texture: Texture2D = load(image_path) as Texture2D
	if texture:
		pilot_image.texture = texture
	else:
		pilot_image.texture = null

func _update_general_stats() -> void:
	"""Update general statistics display."""
	if not current_profile or not general_stats_container:
		return
	
	# Clear existing stats
	for child in general_stats_container.get_children():
		child.queue_free()
	
	var stats: PilotStatistics = current_profile.pilot_stats
	if not stats:
		var no_stats_label: Label = Label.new()
		no_stats_label.text = "No statistics available"
		general_stats_container.add_child(no_stats_label)
		return
	
	# Create statistics display
	_add_stat_item(general_stats_container, "Total Score", str(stats.score))
	_add_stat_item(general_stats_container, "Missions Flown", str(stats.missions_flown))
	_add_stat_item(general_stats_container, "Flight Hours", _format_flight_time(stats.flight_time))
	_add_stat_item(general_stats_container, "Medals Earned", str(stats.medals_earned))
	
	# Profile timestamps
	_add_stat_item(general_stats_container, "Created", _format_date(current_profile.created_time))
	_add_stat_item(general_stats_container, "Last Played", _format_date(current_profile.last_played))

func _update_combat_stats() -> void:
	"""Update combat statistics display."""
	if not current_profile or not combat_stats_container:
		return
	
	# Clear existing stats
	for child in combat_stats_container.get_children():
		child.queue_free()
	
	var stats: PilotStatistics = current_profile.pilot_stats
	if not stats:
		var no_stats_label: Label = Label.new()
		no_stats_label.text = "No combat statistics available"
		combat_stats_container.add_child(no_stats_label)
		return
	
	# Primary weapon stats
	var primary_section: Label = Label.new()
	primary_section.text = "PRIMARY WEAPONS"
	primary_section.add_theme_font_size_override("font_size", 18)
	if ui_theme_manager:
		primary_section.add_theme_color_override("font_color", ui_theme_manager.get_wcs_color("blue_secondary"))
	combat_stats_container.add_child(primary_section)
	
	_add_stat_item(combat_stats_container, "Shots Fired", str(stats.primary_shots_fired))
	_add_stat_item(combat_stats_container, "Shots Hit", str(stats.primary_shots_hit))
	_add_stat_item(combat_stats_container, "Accuracy", "%.1f%%" % (stats.primary_accuracy * 100.0))
	
	# Secondary weapon stats
	var secondary_section: Label = Label.new()
	secondary_section.text = "SECONDARY WEAPONS"
	secondary_section.add_theme_font_size_override("font_size", 18)
	if ui_theme_manager:
		secondary_section.add_theme_color_override("font_color", ui_theme_manager.get_wcs_color("blue_secondary"))
	combat_stats_container.add_child(secondary_section)
	
	_add_stat_item(combat_stats_container, "Missiles Fired", str(stats.secondary_shots_fired))
	_add_stat_item(combat_stats_container, "Missiles Hit", str(stats.secondary_shots_hit))
	_add_stat_item(combat_stats_container, "Accuracy", "%.1f%%" % (stats.secondary_accuracy * 100.0))
	
	# Kill statistics
	var kills_section: Label = Label.new()
	kills_section.text = "COMBAT RECORD"
	kills_section.add_theme_font_size_override("font_size", 18)
	if ui_theme_manager:
		kills_section.add_theme_color_override("font_color", ui_theme_manager.get_wcs_color("blue_secondary"))
	combat_stats_container.add_child(kills_section)
	
	var total_kills: int = _calculate_total_kills(stats.kills)
	_add_stat_item(combat_stats_container, "Total Kills", str(total_kills))
	_add_stat_item(combat_stats_container, "Assists", str(stats.assists))
	
	# Show detailed kill breakdown if available
	if stats.kills.size() > 0:
		_add_detailed_kill_stats(combat_stats_container, stats.kills)

func _update_campaign_stats() -> void:
	"""Update campaign progress display."""
	if not current_profile or not campaign_stats_container:
		return
	
	# Clear existing stats
	for child in campaign_stats_container.get_children():
		child.queue_free()
	
	if current_profile.campaigns.is_empty():
		var no_campaigns_label: Label = Label.new()
		no_campaigns_label.text = "No campaign progress available"
		campaign_stats_container.add_child(no_campaigns_label)
		return
	
	# Display each campaign
	for campaign_info in current_profile.campaigns:
		if campaign_info is CampaignInfo:
			_create_campaign_display(campaign_info as CampaignInfo)

func _update_medals_display() -> void:
	"""Update medals display."""
	if not current_profile or not medals_container:
		return
	
	# Clear existing medals
	for child in medals_container.get_children():
		child.queue_free()
	
	var stats: PilotStatistics = current_profile.pilot_stats
	if not stats or stats.medals.is_empty():
		var no_medals_label: Label = Label.new()
		no_medals_label.text = "No medals earned"
		medals_container.add_child(no_medals_label)
		return
	
	# Display medals
	for medal_info in stats.medals:
		_create_medal_display(medal_info)

func _add_stat_item(container: VBoxContainer, label: String, value: String) -> void:
	"""Add a statistics item to container."""
	var item_container: HBoxContainer = HBoxContainer.new()
	item_container.add_theme_constant_override("separation", 10)
	
	var label_node: Label = Label.new()
	label_node.text = label + ":"
	label_node.custom_minimum_size.x = 150
	label_node.add_theme_font_size_override("font_size", 14)
	
	var value_node: Label = Label.new()
	value_node.text = value
	value_node.add_theme_font_size_override("font_size", 14)
	value_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Apply styling
	if ui_theme_manager:
		label_node.add_theme_color_override("font_color", ui_theme_manager.get_wcs_color("gray_light"))
		value_node.add_theme_color_override("font_color", Color.WHITE)
	
	item_container.add_child(label_node)
	item_container.add_child(value_node)
	container.add_child(item_container)

func _add_detailed_kill_stats(container: VBoxContainer, kills: Array[int]) -> void:
	"""Add detailed kill statistics breakdown."""
	var kills_detail_label: Label = Label.new()
	kills_detail_label.text = "Kill Breakdown:"
	kills_detail_label.add_theme_font_size_override("font_size", 16)
	if ui_theme_manager:
		kills_detail_label.add_theme_color_override("font_color", ui_theme_manager.get_wcs_color("gray_medium"))
	container.add_child(kills_detail_label)
	
	# Show top ship classes with kills
	for i in range(min(kills.size(), 10)):  # Show top 10
		if kills[i] > 0:
			var ship_class_name: String = _get_ship_class_name(i)
			_add_stat_item(container, "  " + ship_class_name, str(kills[i]))

func _create_campaign_display(campaign_info: CampaignInfo) -> void:
	"""Create campaign progress display."""
	var campaign_container: VBoxContainer = VBoxContainer.new()
	campaign_container.add_theme_constant_override("separation", 8)
	campaign_stats_container.add_child(campaign_container)
	
	# Campaign title
	var title_label: Label = Label.new()
	title_label.text = campaign_info.campaign_filename.get_basename()
	title_label.add_theme_font_size_override("font_size", 18)
	if ui_theme_manager:
		title_label.add_theme_color_override("font_color", ui_theme_manager.get_wcs_color("blue_secondary"))
	campaign_container.add_child(title_label)
	
	# Progress information
	var completion_percent: float = campaign_info.get_completion_percentage()
	_add_stat_item(campaign_container, "Progress", "%.1f%%" % completion_percent)
	_add_stat_item(campaign_container, "Current Mission", str(campaign_info.current_mission + 1))
	
	# Mission completion status
	var completed_missions: int = 0
	for i in range(campaign_info.missions_completed.size()):
		if campaign_info.is_mission_completed(i):
			completed_missions += 1
	
	_add_stat_item(campaign_container, "Missions Completed", str(completed_missions))

func _create_medal_display(medal_info: Dictionary) -> void:
	"""Create medal display item."""
	var medal_container: VBoxContainer = VBoxContainer.new()
	medal_container.custom_minimum_size = Vector2(100, 120)
	medal_container.add_theme_constant_override("separation", 5)
	
	# Medal image placeholder
	var medal_image: ColorRect = ColorRect.new()
	medal_image.color = Color.GOLD
	medal_image.custom_minimum_size = Vector2(64, 64)
	medal_container.add_child(medal_image)
	
	# Medal name
	var medal_name: Label = Label.new()
	medal_name.text = medal_info.get("name", "Unknown Medal")
	medal_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	medal_name.add_theme_font_size_override("font_size", 12)
	medal_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	medal_container.add_child(medal_name)
	
	medals_container.add_child(medal_container)

# ============================================================================
# UTILITY METHODS
# ============================================================================

func _calculate_total_kills(kills: Array[int]) -> int:
	"""Calculate total kills from array."""
	var total: int = 0
	for kill_count in kills:
		total += kill_count as int
	return total

func _get_rank_name(rank_index: int) -> String:
	"""Get rank name from index."""
	var ranks: Array[String] = [
		"Ensign", "2nd Lieutenant", "Lieutenant", "Lt. Commander",
		"Commander", "Captain", "Commodore", "Rear Admiral",
		"Vice Admiral", "Admiral", "Fleet Admiral"
	]
	
	if rank_index >= 0 and rank_index < ranks.size():
		return ranks[rank_index]
	return "Unknown"

func _get_ship_class_name(class_index: int) -> String:
	"""Get ship class name from index."""
	# This would normally come from ship data
	var ship_classes: Array[String] = [
		"Fighter", "Bomber", "Interceptor", "Corvette",
		"Frigate", "Destroyer", "Cruiser", "Capital Ship"
	]
	
	if class_index >= 0 and class_index < ship_classes.size():
		return ship_classes[class_index]
	return "Ship Class %d" % class_index

func _format_flight_time(seconds: int) -> String:
	"""Format flight time in seconds to readable format."""
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	return "%dh %dm" % [hours, minutes]

func _format_date(unix_time: int) -> String:
	"""Format unix timestamp to readable date."""
	if unix_time <= 0:
		return "Never"
	
	var datetime: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d %02d:%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute
	]

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_close_pressed() -> void:
	"""Handle close button press."""
	stats_view_closed.emit()

func _on_theme_changed(theme_name: String) -> void:
	"""Handle theme changes."""
	_setup_scene_styling()

# ============================================================================
# PUBLIC API
# ============================================================================

func show_pilot_statistics(callsign: String) -> void:
	"""Show statistics for specified pilot."""
	display_pilot_stats(callsign)

func get_current_pilot() -> String:
	"""Get current pilot callsign."""
	return current_callsign

func refresh_statistics() -> void:
	"""Refresh statistics display."""
	if not current_callsign.is_empty():
		display_pilot_stats(current_callsign)

func export_statistics() -> Dictionary:
	"""Export current pilot statistics as dictionary."""
	if not current_profile:
		return {}
	
	var export_data: Dictionary = {
		"callsign": current_profile.callsign,
		"squadron": current_profile.squad_name,
		"rank": current_profile.pilot_stats.rank if current_profile.pilot_stats else 0,
		"score": current_profile.pilot_stats.score if current_profile.pilot_stats else 0,
		"missions": current_profile.pilot_stats.missions_flown if current_profile.pilot_stats else 0,
		"flight_time": current_profile.pilot_stats.flight_time if current_profile.pilot_stats else 0,
		"created": current_profile.created_time,
		"last_played": current_profile.last_played
	}
	
	return export_data