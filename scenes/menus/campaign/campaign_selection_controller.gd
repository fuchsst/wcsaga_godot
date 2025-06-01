class_name CampaignSelectionController
extends Control

## WCS campaign selection interface with progress display and story branching.
## Provides campaign browser, progress visualization, and mission selection functionality.
## Integrates with SEXP system for conditional campaign options and story branching.

signal campaign_selected(campaign: CampaignData)
signal campaign_mission_selected(campaign: CampaignData, mission_index: int)
signal campaign_selection_cancelled()
signal campaign_progress_requested(campaign: CampaignData)

# UI components
var main_container: VBoxContainer = null
var title_label: Label = null
var campaign_browser: HSplitContainer = null
var campaign_list: ItemList = null
var campaign_preview: VBoxContainer = null
var progress_display: VBoxContainer = null
var button_container: HBoxContainer = null
var select_button: MenuButton = null
var progress_button: MenuButton = null
var cancel_button: MenuButton = null

# Campaign preview components
var preview_title: Label = null
var preview_description: RichTextLabel = null
var preview_info: VBoxContainer = null
var mission_progress_list: ItemList = null

# Data management
var campaign_manager: CampaignDataManager = null
var ui_theme_manager: UIThemeManager = null
var available_campaigns: Array[CampaignData] = []
var selected_campaign: CampaignData = null

# Configuration
@export var show_campaign_browser: bool = true
@export var show_progress_display: bool = true
@export var enable_mission_selection: bool = true
@export var campaigns_per_page: int = 10

func _ready() -> void:
	"""Initialize campaign selection controller."""
	if Engine.is_editor_hint():
		return
	
	print("CampaignSelectionController: Initializing campaign selection interface")
	
	# Get managers
	_initialize_managers()
	
	# Build UI
	_build_campaign_selection_ui()
	
	# Load campaigns
	_refresh_campaign_list()
	
	# Apply theme
	_apply_ui_theme()

# ============================================================================
# UI CONSTRUCTION
# ============================================================================

func _build_campaign_selection_ui() -> void:
	"""Build campaign selection user interface."""
	# Main container
	main_container = VBoxContainer.new()
	main_container.name = "CampaignSelectionMain"
	add_child(main_container)
	
	# Title
	_create_title_section()
	
	# Campaign browser
	if show_campaign_browser:
		_create_campaign_browser()
	
	# Button container
	_create_button_section()

func _create_title_section() -> void:
	"""Create title section."""
	title_label = Label.new()
	title_label.name = "CampaignTitle"
	title_label.text = "Campaign Selection"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title_label)
	
	# Add spacing
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	main_container.add_child(spacer)

func _create_campaign_browser() -> void:
	"""Create campaign browser with list and preview."""
	campaign_browser = HSplitContainer.new()
	campaign_browser.name = "CampaignBrowser"
	campaign_browser.custom_minimum_size = Vector2(800, 500)
	main_container.add_child(campaign_browser)
	
	# Campaign list
	_create_campaign_list()
	
	# Campaign preview
	_create_campaign_preview()

func _create_campaign_list() -> void:
	"""Create campaign list widget."""
	var list_container: VBoxContainer = VBoxContainer.new()
	list_container.name = "CampaignListContainer"
	campaign_browser.add_child(list_container)
	
	# List title
	var list_title: Label = Label.new()
	list_title.text = "Available Campaigns"
	list_title.add_theme_font_size_override("font_size", 18)
	list_container.add_child(list_title)
	
	# Campaign list
	campaign_list = ItemList.new()
	campaign_list.name = "CampaignList"
	campaign_list.custom_minimum_size = Vector2(300, 400)
	campaign_list.item_selected.connect(_on_campaign_selected)
	list_container.add_child(campaign_list)

func _create_campaign_preview() -> void:
	"""Create campaign preview panel."""
	campaign_preview = VBoxContainer.new()
	campaign_preview.name = "CampaignPreview"
	campaign_browser.add_child(campaign_preview)
	
	# Preview title
	preview_title = Label.new()
	preview_title.name = "PreviewTitle"
	preview_title.text = "Select a campaign"
	preview_title.add_theme_font_size_override("font_size", 20)
	campaign_preview.add_child(preview_title)
	
	# Preview description
	preview_description = RichTextLabel.new()
	preview_description.name = "PreviewDescription"
	preview_description.custom_minimum_size = Vector2(0, 120)
	preview_description.bbcode_enabled = true
	preview_description.fit_content = true
	campaign_preview.add_child(preview_description)
	
	# Campaign info
	_create_campaign_info_section()
	
	# Mission progress
	if show_progress_display:
		_create_mission_progress_section()

func _create_campaign_info_section() -> void:
	"""Create campaign information section."""
	preview_info = VBoxContainer.new()
	preview_info.name = "CampaignInfo"
	campaign_preview.add_child(preview_info)

func _create_mission_progress_section() -> void:
	"""Create mission progress display."""
	var progress_title: Label = Label.new()
	progress_title.text = "Mission Progress"
	progress_title.add_theme_font_size_override("font_size", 16)
	campaign_preview.add_child(progress_title)
	
	mission_progress_list = ItemList.new()
	mission_progress_list.name = "MissionProgressList"
	mission_progress_list.custom_minimum_size = Vector2(0, 200)
	if enable_mission_selection:
		mission_progress_list.item_selected.connect(_on_mission_selected)
	campaign_preview.add_child(mission_progress_list)

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
	
	# Select button
	select_button = MenuButton.new()
	select_button.category = MenuButton.ButtonCategory.PRIMARY
	select_button.text = "Select Campaign"
	select_button.disabled = true
	select_button.pressed.connect(_on_select_campaign_pressed)
	button_container.add_child(select_button)
	
	# Add spacing
	var button_spacer: Control = Control.new()
	button_spacer.custom_minimum_size = Vector2(20, 0)
	button_container.add_child(button_spacer)
	
	# Progress button
	progress_button = MenuButton.new()
	progress_button.category = MenuButton.ButtonCategory.SECONDARY
	progress_button.text = "View Progress"
	progress_button.disabled = true
	progress_button.pressed.connect(_on_view_progress_pressed)
	button_container.add_child(progress_button)
	
	# Add spacing
	var button_spacer2: Control = Control.new()
	button_spacer2.custom_minimum_size = Vector2(20, 0)
	button_container.add_child(button_spacer2)
	
	# Cancel button
	cancel_button = MenuButton.new()
	cancel_button.category = MenuButton.ButtonCategory.STANDARD
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_container.add_child(cancel_button)

# ============================================================================
# CAMPAIGN MANAGEMENT
# ============================================================================

func _refresh_campaign_list() -> void:
	"""Refresh campaign list from campaign manager."""
	if not campaign_manager:
		return
	
	available_campaigns = campaign_manager.get_available_campaigns()
	_populate_campaign_list()

func _populate_campaign_list() -> void:
	"""Populate campaign list widget."""
	if not campaign_list:
		return
	
	campaign_list.clear()
	
	for campaign in available_campaigns:
		var item_text: String = campaign.name
		if campaign.description:
			item_text += " - " + campaign.description.substr(0, 50)
			if campaign.description.length() > 50:
				item_text += "..."
		
		campaign_list.add_item(item_text)

func _update_campaign_preview(campaign: CampaignData) -> void:
	"""Update campaign preview panel."""
	if not campaign:
		_clear_campaign_preview()
		return
	
	# Update title
	preview_title.text = campaign.name
	
	# Update description
	var description_text: String = campaign.description
	if description_text.is_empty():
		description_text = "No description available."
	preview_description.text = "[center]" + description_text + "[/center]"
	
	# Update campaign info
	_update_campaign_info(campaign)
	
	# Update mission progress
	if show_progress_display:
		_update_mission_progress(campaign)
	
	# Enable buttons
	select_button.disabled = false
	progress_button.disabled = false

func _clear_campaign_preview() -> void:
	"""Clear campaign preview panel."""
	preview_title.text = "Select a campaign"
	preview_description.text = ""
	
	# Clear info
	for child in preview_info.get_children():
		child.queue_free()
	
	# Clear progress
	if mission_progress_list:
		mission_progress_list.clear()
	
	# Disable buttons
	select_button.disabled = true
	progress_button.disabled = true

func _update_campaign_info(campaign: CampaignData) -> void:
	"""Update campaign information display."""
	# Clear existing info
	for child in preview_info.get_children():
		child.queue_free()
	
	var info_data: Array[Array] = [
		["Type", CampaignDataManager.CampaignType.keys()[campaign.type]],
		["Missions", str(campaign.get_mission_count())],
		["Author", campaign.author if campaign.author else "Unknown"],
		["Version", campaign.version if campaign.version else "1.0"]
	]
	
	for info_item in info_data:
		var info_line: HBoxContainer = HBoxContainer.new()
		preview_info.add_child(info_line)
		
		var label: Label = Label.new()
		label.text = info_item[0] + ":"
		label.custom_minimum_size = Vector2(80, 0)
		info_line.add_child(label)
		
		var value: Label = Label.new()
		value.text = info_item[1]
		info_line.add_child(value)

func _update_mission_progress(campaign: CampaignData) -> void:
	"""Update mission progress display."""
	if not mission_progress_list:
		return
	
	mission_progress_list.clear()
	
	for i in range(campaign.get_mission_count()):
		var mission: CampaignMissionData = campaign.get_mission_by_index(i)
		if not mission:
			continue
		
		var completion_state: CampaignDataManager.MissionCompletionState = CampaignDataManager.MissionCompletionState.NOT_AVAILABLE
		if campaign_manager:
			completion_state = campaign_manager.get_mission_completion_state(i)
		
		var status_text: String = _get_mission_status_text(completion_state)
		var item_text: String = "%d. %s [%s]" % [i + 1, mission.name, status_text]
		
		mission_progress_list.add_item(item_text)
		
		# Color code based on status
		var item_index: int = mission_progress_list.get_item_count() - 1
		match completion_state:
			CampaignDataManager.MissionCompletionState.COMPLETED:
				mission_progress_list.set_item_custom_fg_color(item_index, Color.GREEN)
			CampaignDataManager.MissionCompletionState.AVAILABLE:
				mission_progress_list.set_item_custom_fg_color(item_index, Color.YELLOW)
			CampaignDataManager.MissionCompletionState.FAILED:
				mission_progress_list.set_item_custom_fg_color(item_index, Color.RED)
			_:
				mission_progress_list.set_item_custom_fg_color(item_index, Color.GRAY)

func _get_mission_status_text(state: CampaignDataManager.MissionCompletionState) -> String:
	"""Get mission status display text."""
	match state:
		CampaignDataManager.MissionCompletionState.NOT_AVAILABLE:
			return "Locked"
		CampaignDataManager.MissionCompletionState.AVAILABLE:
			return "Available"
		CampaignDataManager.MissionCompletionState.COMPLETED:
			return "Complete"
		CampaignDataManager.MissionCompletionState.FAILED:
			return "Failed"
		CampaignDataManager.MissionCompletionState.SKIPPED:
			return "Skipped"
		_:
			return "Unknown"

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_campaign_selected(index: int) -> void:
	"""Handle campaign selection from list."""
	if index < 0 or index >= available_campaigns.size():
		return
	
	selected_campaign = available_campaigns[index]
	_update_campaign_preview(selected_campaign)
	
	print("CampaignSelectionController: Campaign selected: %s" % selected_campaign.name)

func _on_mission_selected(index: int) -> void:
	"""Handle mission selection from progress list."""
	if not selected_campaign or not enable_mission_selection:
		return
	
	if index < 0 or index >= selected_campaign.get_mission_count():
		return
	
	# Check if mission is available
	var completion_state: CampaignDataManager.MissionCompletionState = CampaignDataManager.MissionCompletionState.NOT_AVAILABLE
	if campaign_manager:
		completion_state = campaign_manager.get_mission_completion_state(index)
	
	if completion_state == CampaignDataManager.MissionCompletionState.NOT_AVAILABLE:
		print("CampaignSelectionController: Mission %d not available" % index)
		return
	
	campaign_mission_selected.emit(selected_campaign, index)
	print("CampaignSelectionController: Mission selected: %d" % index)

func _on_select_campaign_pressed() -> void:
	"""Handle select campaign button press."""
	if not selected_campaign:
		return
	
	campaign_selected.emit(selected_campaign)
	print("CampaignSelectionController: Campaign selection confirmed: %s" % selected_campaign.name)

func _on_view_progress_pressed() -> void:
	"""Handle view progress button press."""
	if not selected_campaign:
		return
	
	campaign_progress_requested.emit(selected_campaign)
	print("CampaignSelectionController: Progress view requested for: %s" % selected_campaign.name)

func _on_cancel_pressed() -> void:
	"""Handle cancel button press."""
	campaign_selection_cancelled.emit()
	print("CampaignSelectionController: Campaign selection cancelled")

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
	
	if campaign_list:
		ui_theme_manager.apply_list_theme(campaign_list)
	
	if mission_progress_list:
		ui_theme_manager.apply_list_theme(mission_progress_list)

# ============================================================================
# PUBLIC API
# ============================================================================

func refresh_campaigns() -> void:
	"""Refresh campaign list."""
	_refresh_campaign_list()

func get_selected_campaign() -> CampaignData:
	"""Get currently selected campaign."""
	return selected_campaign

func set_selected_campaign(campaign: CampaignData) -> void:
	"""Set selected campaign."""
	selected_campaign = campaign
	
	# Find and select in list
	for i in range(available_campaigns.size()):
		if available_campaigns[i] == campaign:
			campaign_list.select(i)
			_update_campaign_preview(campaign)
			break

func get_campaign_count() -> int:
	"""Get number of available campaigns."""
	return available_campaigns.size()

func has_campaigns() -> bool:
	"""Check if campaigns are available."""
	return available_campaigns.size() > 0

# ============================================================================
# STATIC FACTORY
# ============================================================================

static func create_campaign_selection() -> CampaignSelectionController:
	"""Create and initialize campaign selection controller."""
	var controller: CampaignSelectionController = CampaignSelectionController.new()
	controller.name = "CampaignSelectionController"
	return controller