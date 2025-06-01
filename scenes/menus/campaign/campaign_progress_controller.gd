class_name CampaignProgressController
extends Control

## WCS campaign progress display with mission tree visualization and detailed statistics.
## Shows campaign progression, mission completion status, and story branching paths.
## Provides comprehensive campaign progress tracking and navigation.

signal progress_view_closed()
signal mission_details_requested(mission_index: int)
signal campaign_statistics_requested()

# UI components
var main_container: VBoxContainer = null
var title_label: Label = null
var progress_display: HSplitContainer = null
var mission_tree: Tree = null
var details_panel: VBoxContainer = null
var button_container: HBoxContainer = null
var statistics_button: MenuButton = null
var close_button: MenuButton = null

# Mission details components
var details_title: Label = null
var details_description: RichTextLabel = null
var completion_info: VBoxContainer = null
var goals_list: ItemList = null
var events_list: ItemList = null

# Data management
var campaign_manager: CampaignDataManager = null
var ui_theme_manager: UIThemeManager = null
var current_campaign: CampaignData = null

# Tree structure
var mission_tree_items: Array[TreeItem] = []
var tree_root: TreeItem = null

# Configuration
@export var show_mission_details: bool = true
@export var show_completion_statistics: bool = true
@export var enable_mission_navigation: bool = true

func _ready() -> void:
	"""Initialize campaign progress controller."""
	if Engine.is_editor_hint():
		return
	
	print("CampaignProgressController: Initializing progress display")
	
	# Get managers
	_initialize_managers()
	
	# Build UI
	_build_progress_ui()
	
	# Apply theme
	_apply_ui_theme()

# ============================================================================
# UI CONSTRUCTION
# ============================================================================

func _build_progress_ui() -> void:
	"""Build campaign progress user interface."""
	# Main container
	main_container = VBoxContainer.new()
	main_container.name = "CampaignProgressMain"
	add_child(main_container)
	
	# Title
	_create_title_section()
	
	# Progress display
	_create_progress_display()
	
	# Button container
	_create_button_section()

func _create_title_section() -> void:
	"""Create title section."""
	title_label = Label.new()
	title_label.name = "ProgressTitle"
	title_label.text = "Campaign Progress"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title_label)
	
	# Add spacing
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	main_container.add_child(spacer)

func _create_progress_display() -> void:
	"""Create progress display with mission tree and details."""
	progress_display = HSplitContainer.new()
	progress_display.name = "ProgressDisplay"
	progress_display.custom_minimum_size = Vector2(900, 600)
	main_container.add_child(progress_display)
	
	# Mission tree
	_create_mission_tree()
	
	# Details panel
	if show_mission_details:
		_create_details_panel()

func _create_mission_tree() -> void:
	"""Create mission tree visualization."""
	var tree_container: VBoxContainer = VBoxContainer.new()
	tree_container.name = "MissionTreeContainer"
	progress_display.add_child(tree_container)
	
	# Tree title
	var tree_title: Label = Label.new()
	tree_title.text = "Mission Tree"
	tree_title.add_theme_font_size_override("font_size", 18)
	tree_container.add_child(tree_title)
	
	# Mission tree
	mission_tree = Tree.new()
	mission_tree.name = "MissionTree"
	mission_tree.custom_minimum_size = Vector2(400, 500)
	mission_tree.hide_root = true
	mission_tree.item_selected.connect(_on_mission_tree_item_selected)
	tree_container.add_child(mission_tree)

func _create_details_panel() -> void:
	"""Create mission details panel."""
	details_panel = VBoxContainer.new()
	details_panel.name = "MissionDetailsPanel"
	progress_display.add_child(details_panel)
	
	# Details title
	details_title = Label.new()
	details_title.name = "DetailsTitle"
	details_title.text = "Select a mission"
	details_title.add_theme_font_size_override("font_size", 20)
	details_panel.add_child(details_title)
	
	# Details description
	details_description = RichTextLabel.new()
	details_description.name = "DetailsDescription"
	details_description.custom_minimum_size = Vector2(0, 100)
	details_description.bbcode_enabled = true
	details_description.fit_content = true
	details_panel.add_child(details_description)
	
	# Completion info
	if show_completion_statistics:
		_create_completion_info_section()

func _create_completion_info_section() -> void:
	"""Create completion information section."""
	completion_info = VBoxContainer.new()
	completion_info.name = "CompletionInfo"
	details_panel.add_child(completion_info)
	
	# Goals section
	var goals_title: Label = Label.new()
	goals_title.text = "Mission Goals"
	goals_title.add_theme_font_size_override("font_size", 16)
	completion_info.add_child(goals_title)
	
	goals_list = ItemList.new()
	goals_list.name = "GoalsList"
	goals_list.custom_minimum_size = Vector2(0, 120)
	completion_info.add_child(goals_list)
	
	# Events section
	var events_title: Label = Label.new()
	events_title.text = "Mission Events"
	events_title.add_theme_font_size_override("font_size", 16)
	completion_info.add_child(events_title)
	
	events_list = ItemList.new()
	events_list.name = "EventsList"
	events_list.custom_minimum_size = Vector2(0, 120)
	completion_info.add_child(events_list)

func _create_button_section() -> void:
	"""Create button section."""
	# Add spacing
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	main_container.add_child(spacer)
	
	button_container = HBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_child(button_container)
	
	# Statistics button
	if show_completion_statistics:
		statistics_button = MenuButton.new()
		statistics_button.category = MenuButton.ButtonCategory.SECONDARY
		statistics_button.text = "Campaign Statistics"
		statistics_button.pressed.connect(_on_statistics_pressed)
		button_container.add_child(statistics_button)
		
		# Add spacing
		var button_spacer: Control = Control.new()
		button_spacer.custom_minimum_size = Vector2(20, 0)
		button_container.add_child(button_spacer)
	
	# Close button
	close_button = MenuButton.new()
	close_button.category = MenuButton.ButtonCategory.STANDARD
	close_button.text = "Close"
	close_button.pressed.connect(_on_close_pressed)
	button_container.add_child(close_button)

# ============================================================================
# CAMPAIGN PROGRESS DISPLAY
# ============================================================================

func show_campaign_progress(campaign: CampaignData) -> void:
	"""Display progress for specified campaign."""
	current_campaign = campaign
	
	if not current_campaign:
		return
	
	# Update title
	title_label.text = "Campaign Progress - " + current_campaign.name
	
	# Build mission tree
	_build_mission_tree()
	
	# Clear details
	_clear_mission_details()
	
	print("CampaignProgressController: Showing progress for campaign: %s" % current_campaign.name)

func _build_mission_tree() -> void:
	"""Build mission tree visualization."""
	if not mission_tree or not current_campaign:
		return
	
	mission_tree.clear()
	mission_tree_items.clear()
	
	# Create root
	tree_root = mission_tree.create_item()
	tree_root.set_text(0, current_campaign.name)
	
	# Add missions to tree
	for i in range(current_campaign.get_mission_count()):
		var mission: CampaignMissionData = current_campaign.get_mission_by_index(i)
		if not mission:
			continue
		
		var mission_item: TreeItem = mission_tree.create_item(tree_root)
		mission_item.set_text(0, "%d. %s" % [i + 1, mission.name])
		mission_item.set_metadata(0, i)
		
		# Set mission icon and color based on completion status
		var completion_state: CampaignDataManager.MissionCompletionState = CampaignDataManager.MissionCompletionState.NOT_AVAILABLE
		if campaign_manager:
			completion_state = campaign_manager.get_mission_completion_state(i)
		
		_apply_mission_tree_styling(mission_item, completion_state)
		mission_tree_items.append(mission_item)
	
	# Expand tree
	tree_root.set_collapsed(false)

func _apply_mission_tree_styling(item: TreeItem, state: CampaignDataManager.MissionCompletionState) -> void:
	"""Apply styling to mission tree item based on completion state."""
	match state:
		CampaignDataManager.MissionCompletionState.COMPLETED:
			item.set_custom_color(0, Color.GREEN)
			item.set_suffix(0, " ✓")
		CampaignDataManager.MissionCompletionState.AVAILABLE:
			item.set_custom_color(0, Color.YELLOW)
			item.set_suffix(0, " →")
		CampaignDataManager.MissionCompletionState.FAILED:
			item.set_custom_color(0, Color.RED)
			item.set_suffix(0, " ✗")
		CampaignDataManager.MissionCompletionState.SKIPPED:
			item.set_custom_color(0, Color.CYAN)
			item.set_suffix(0, " ⤴")
		_:
			item.set_custom_color(0, Color.GRAY)
			item.set_suffix(0, " 🔒")

func _update_mission_details(mission_index: int) -> void:
	"""Update mission details panel."""
	if not current_campaign or mission_index < 0 or mission_index >= current_campaign.get_mission_count():
		_clear_mission_details()
		return
	
	var mission: CampaignMissionData = current_campaign.get_mission_by_index(mission_index)
	if not mission:
		_clear_mission_details()
		return
	
	# Update title
	details_title.text = mission.name
	
	# Update description
	var description_text: String = mission.notes
	if description_text.is_empty():
		description_text = "No mission notes available."
	details_description.text = "[center]" + description_text + "[/center]"
	
	# Update completion info
	if show_completion_statistics:
		_update_completion_info(mission)

func _clear_mission_details() -> void:
	"""Clear mission details panel."""
	if details_title:
		details_title.text = "Select a mission"
	if details_description:
		details_description.text = ""
	if goals_list:
		goals_list.clear()
	if events_list:
		events_list.clear()

func _update_completion_info(mission: CampaignMissionData) -> void:
	"""Update mission completion information."""
	if not goals_list or not events_list:
		return
	
	# Update goals
	goals_list.clear()
	for goal in mission.goals:
		var status_text: String = _get_completion_status_text(goal.status)
		var item_text: String = "%s [%s]" % [goal.name, status_text]
		goals_list.add_item(item_text)
		
		var item_index: int = goals_list.get_item_count() - 1
		_apply_completion_status_color(goals_list, item_index, goal.status)
	
	# Update events
	events_list.clear()
	for event in mission.events:
		var status_text: String = _get_completion_status_text(event.status)
		var item_text: String = "%s [%s]" % [event.name, status_text]
		events_list.add_item(item_text)
		
		var item_index: int = events_list.get_item_count() - 1
		_apply_completion_status_color(events_list, item_index, event.status)

func _get_completion_status_text(state: CampaignDataManager.MissionCompletionState) -> String:
	"""Get completion status display text."""
	match state:
		CampaignDataManager.MissionCompletionState.COMPLETED:
			return "Complete"
		CampaignDataManager.MissionCompletionState.FAILED:
			return "Failed"
		_:
			return "Incomplete"

func _apply_completion_status_color(list: ItemList, index: int, state: CampaignDataManager.MissionCompletionState) -> void:
	"""Apply color coding to completion status."""
	match state:
		CampaignDataManager.MissionCompletionState.COMPLETED:
			list.set_item_custom_fg_color(index, Color.GREEN)
		CampaignDataManager.MissionCompletionState.FAILED:
			list.set_item_custom_fg_color(index, Color.RED)
		_:
			list.set_item_custom_fg_color(index, Color.GRAY)

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_mission_tree_item_selected() -> void:
	"""Handle mission tree item selection."""
	var selected_item: TreeItem = mission_tree.get_selected()
	if not selected_item:
		return
	
	var mission_index: Variant = selected_item.get_metadata(0)
	if mission_index is int:
		_update_mission_details(mission_index)
		
		if enable_mission_navigation:
			mission_details_requested.emit(mission_index)

func _on_statistics_pressed() -> void:
	"""Handle statistics button press."""
	campaign_statistics_requested.emit()
	print("CampaignProgressController: Campaign statistics requested")

func _on_close_pressed() -> void:
	"""Handle close button press."""
	progress_view_closed.emit()
	print("CampaignProgressController: Progress view closed")

# ============================================================================
# PRIVATE IMPLEMENTATION
# ============================================================================

func _initialize_managers() -> void:
	"""Initialize required managers."""
	# Get campaign manager
	campaign_manager = CampaignDataManager.create_campaign_manager()
	
	# Get UI theme manager
	var theme_nodes: Array[Node] = get_tree().get_nodes_in_group("ui_theme_manager")
	if theme_nodes.size() > 0:
		ui_theme_manager = theme_nodes[0] as UIThemeManager

func _apply_ui_theme() -> void:
	"""Apply UI theme styling."""
	if not ui_theme_manager:
		return
	
	# Apply theme to main components
	ui_theme_manager.apply_container_theme(main_container)
	
	if title_label:
		ui_theme_manager.apply_title_theme(title_label)
	
	if mission_tree:
		ui_theme_manager.apply_tree_theme(mission_tree)
	
	if goals_list:
		ui_theme_manager.apply_list_theme(goals_list)
	
	if events_list:
		ui_theme_manager.apply_list_theme(events_list)

# ============================================================================
# PUBLIC API
# ============================================================================

func get_current_campaign() -> CampaignData:
	"""Get currently displayed campaign."""
	return current_campaign

func refresh_progress_display() -> void:
	"""Refresh progress display."""
	if current_campaign:
		show_campaign_progress(current_campaign)

func get_campaign_completion_percentage() -> float:
	"""Get campaign completion percentage."""
	if campaign_manager:
		return campaign_manager.get_campaign_progress_percentage()
	return 0.0

func get_completed_mission_count() -> int:
	"""Get number of completed missions."""
	if not current_campaign or not campaign_manager:
		return 0
	
	var completed_count: int = 0
	for i in range(current_campaign.get_mission_count()):
		if campaign_manager.is_mission_completed(i):
			completed_count += 1
	
	return completed_count

# ============================================================================
# STATIC FACTORY
# ============================================================================

static func create_progress_display() -> CampaignProgressController:
	"""Create and initialize campaign progress controller."""
	var controller: CampaignProgressController = CampaignProgressController.new()
	controller.name = "CampaignProgressController"
	return controller