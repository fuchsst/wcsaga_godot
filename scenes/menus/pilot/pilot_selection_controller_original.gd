class_name PilotSelectionController
extends Control

## Simplified WCS pilot selection scene controller for scene-based UI approach.
## Displays available pilots with preview, statistics, and selection functionality.
## Integrates with PilotDataManager for complete pilot lifecycle management.

signal pilot_selected(profile: PlayerProfile)
signal pilot_creation_requested()
signal pilot_deletion_requested(callsign: String)
signal pilot_stats_requested(callsign: String)

# UI configuration
@export var show_pilot_preview: bool = true
@export var show_pilot_statistics: bool = true
@export var enable_pilot_deletion: bool = true
@export var pilots_per_page: int = 8
@export var auto_select_first_pilot: bool = true

# Scene references (from pilot_selection.tscn)
@onready var main_container: VBoxContainer = $MainContainer
@onready var title_label: Label = $MainContainer/HeaderContainer/TitleLabel
@onready var content_container: HBoxContainer = $MainContainer/ContentContainer
@onready var pilot_list_panel: VBoxContainer = $MainContainer/ContentContainer/PilotListPanel
@onready var pilot_scroll: ScrollContainer = $MainContainer/ContentContainer/PilotListPanel/PilotScroll
@onready var pilot_list_container: VBoxContainer = $MainContainer/ContentContainer/PilotListPanel/PilotScroll/PilotListContainer
@onready var preview_panel: VBoxContainer = $MainContainer/ContentContainer/PreviewPanel
@onready var preview_image: TextureRect = $MainContainer/ContentContainer/PreviewPanel/PreviewContent/PreviewImage
@onready var preview_info_container: VBoxContainer = $MainContainer/ContentContainer/PreviewPanel/PreviewContent/PreviewInfoContainer
@onready var preview_callsign: Label = $MainContainer/ContentContainer/PreviewPanel/PreviewContent/PreviewInfoContainer/PreviewCallsign
@onready var preview_squadron: Label = $MainContainer/ContentContainer/PreviewPanel/PreviewContent/PreviewInfoContainer/PreviewSquadron
@onready var preview_rank: Label = $MainContainer/ContentContainer/PreviewPanel/PreviewContent/PreviewInfoContainer/PreviewRank
@onready var preview_score: Label = $MainContainer/ContentContainer/PreviewPanel/PreviewContent/PreviewInfoContainer/PreviewScore
@onready var preview_missions: Label = $MainContainer/ContentContainer/PreviewPanel/PreviewContent/PreviewInfoContainer/PreviewMissions
@onready var preview_last_played: Label = $MainContainer/ContentContainer/PreviewPanel/PreviewContent/PreviewInfoContainer/PreviewLastPlayed
@onready var button_container: HBoxContainer = $MainContainer/ButtonContainer
@onready var select_button: Button = $MainContainer/ButtonContainer/SelectButton
@onready var create_button: Button = $MainContainer/ButtonContainer/CreateButton
@onready var delete_button: Button = $MainContainer/ButtonContainer/DeleteButton
@onready var stats_button: Button = $MainContainer/ButtonContainer/StatsButton
@onready var cancel_button: Button = $MainContainer/ButtonContainer/CancelButton
@onready var back_button: Button = $MainContainer/HeaderContainer/BackButton

# Pagination
@onready var pagination_container: HBoxContainer = $MainContainer/ContentContainer/PilotListPanel/PaginationContainer
@onready var prev_page_button: Button = $MainContainer/ContentContainer/PilotListPanel/PaginationContainer/PrevPageButton
@onready var page_label: Label = $MainContainer/ContentContainer/PilotListPanel/PaginationContainer/PageLabel
@onready var next_page_button: Button = $MainContainer/ContentContainer/PilotListPanel/PaginationContainer/NextPageButton

# Dialogs
@onready var confirmation_dialog: ConfirmationDialog = $ConfirmationDialog

# Data management
var pilot_manager: PilotDataManager = null
var pilot_list: Array[String] = []
var pilot_items: Array[Control] = []
var selected_pilot_callsign: String = ""
var pilot_info_cache: Dictionary = {}
var current_page: int = 0
var total_pages: int = 0

# Theme integration
var ui_theme_manager: UIThemeManager = null
var portrait_textures: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_pilot_selection()

func _initialize_pilot_selection() -> void:
	"""Initialize pilot selection scene."""
	print("PilotSelectionController: Initializing pilot selection interface")
	
	# Connect to theme manager
	_connect_to_theme_manager()
	
	# Initialize pilot manager
	pilot_manager = PilotDataManager.new()
	pilot_manager.pilot_deleted.connect(_on_pilot_deleted)
	
	# Setup UI
	_setup_scene_styling()
	_connect_ui_signals()
	_load_pilot_list()
	
	# Auto-select first pilot if enabled
	if auto_select_first_pilot and not pilot_list.is_empty():
		_select_pilot(pilot_list[0])

func _connect_to_theme_manager() -> void:
	"""Connect to UIThemeManager for consistent styling."""
	var theme_manager: Node = get_tree().get_first_node_in_group("ui_theme_manager")
	if theme_manager and theme_manager is UIThemeManager:
		ui_theme_manager = theme_manager as UIThemeManager
		ui_theme_manager.theme_changed.connect(_on_theme_changed)

func _connect_ui_signals() -> void:
	"""Connect UI signals for pilot selection interface."""
	# Connect button signals
	if select_button:
		select_button.pressed.connect(_on_select_pilot_pressed)
	
	if create_button:
		create_button.pressed.connect(_on_create_pilot_pressed)
	
	if delete_button:
		delete_button.pressed.connect(_on_delete_pilot_pressed)
	
	if stats_button:
		stats_button.pressed.connect(_on_stats_pilot_pressed)
	
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	
	if back_button:
		back_button.pressed.connect(_on_cancel_pressed)
	
	# Connect pagination
	if prev_page_button:
		prev_page_button.pressed.connect(_on_prev_page_pressed)
	
	if next_page_button:
		next_page_button.pressed.connect(_on_next_page_pressed)
	
	# Connect confirmation dialog
	if confirmation_dialog:
		confirmation_dialog.confirmed.connect(_on_delete_confirmed)

func _setup_scene_styling() -> void:
	"""Apply WCS styling to scene components."""
	if not ui_theme_manager:
		return
	
	# Apply theme to controls
	ui_theme_manager.apply_theme_to_control(self)
	
	# Set initial preview text
	_clear_preview()

func _load_pilot_list() -> void:
	"""Load the list of available pilots."""
	pilot_list.clear()
	pilot_info_cache.clear()
	
	if pilot_manager:
		pilot_list = pilot_manager.get_pilot_list()
	
	# Calculate pagination
	_update_pagination()
	_populate_pilot_list()

func _update_pagination() -> void:
	"""Update pagination controls."""
	total_pages = max(1, (pilot_list.size() + pilots_per_page - 1) / pilots_per_page)
	current_page = clamp(current_page, 0, total_pages - 1)
	
	if page_label:
		page_label.text = "Page %d of %d" % [current_page + 1, total_pages]
	
	if prev_page_button:
		prev_page_button.disabled = (current_page <= 0)
	
	if next_page_button:
		next_page_button.disabled = (current_page >= total_pages - 1)

func _populate_pilot_list() -> void:
	"""Populate the pilot list for current page."""
	if not pilot_list_container:
		return
	
	# Clear existing pilot items
	for child in pilot_list_container.get_children():
		child.queue_free()
	pilot_items.clear()
	
	# Calculate page range
	var start_index: int = current_page * pilots_per_page
	var end_index: int = min(start_index + pilots_per_page, pilot_list.size())
	
	# Create pilot items for current page
	for i in range(start_index, end_index):
		var callsign: String = pilot_list[i]
		var pilot_item: Control = _create_pilot_item(callsign)
		pilot_list_container.add_child(pilot_item)
		pilot_items.append(pilot_item)

func _create_pilot_item(callsign: String) -> Control:
	"""Create a pilot list item."""
	var item: Button = Button.new()
	item.name = "PilotItem_" + callsign
	item.text = callsign
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.custom_minimum_size = Vector2(0, 40)
	item.pressed.connect(_on_pilot_item_pressed.bind(callsign))
	
	# Get pilot info for display
	var pilot_info: Dictionary = _get_pilot_info(callsign)
	if pilot_info.has("squadron") and not pilot_info.squadron.is_empty():
		item.text += " (" + pilot_info.squadron + ")"
	
	return item

func _get_pilot_info(callsign: String) -> Dictionary:
	"""Get pilot information, using cache if available."""
	if not pilot_info_cache.has(callsign):
		var info: Dictionary = {}
		if pilot_manager:
			var profile: PlayerProfile = pilot_manager.get_pilot_profile(callsign)
			if profile:
				info = {
					"callsign": profile.callsign,
					"squadron": profile.squadron,
					"rank": profile.rank,
					"score": profile.total_score,
					"missions": profile.missions_flown,
					"last_played": profile.last_played_date,
					"portrait": profile.portrait
				}
		pilot_info_cache[callsign] = info
	
	return pilot_info_cache[callsign]

func _select_pilot(callsign: String) -> void:
	"""Select a pilot and update preview."""
	selected_pilot_callsign = callsign
	
	# Update visual selection state
	for item in pilot_items:
		if item is Button:
			item.button_pressed = (item.name == "PilotItem_" + callsign)
	
	# Update preview
	_update_preview()
	
	# Update button states
	_update_button_states()

func _update_preview() -> void:
	"""Update the pilot preview panel."""
	if not preview_panel or selected_pilot_callsign.is_empty():
		_clear_preview()
		return
	
	var pilot_info: Dictionary = _get_pilot_info(selected_pilot_callsign)
	
	# Update preview labels
	if preview_callsign:
		preview_callsign.text = "Callsign: " + pilot_info.get("callsign", "Unknown")
	
	if preview_squadron:
		var squadron: String = pilot_info.get("squadron", "")
		preview_squadron.text = "Squadron: " + (squadron if not squadron.is_empty() else "None")
	
	if preview_rank:
		preview_rank.text = "Rank: " + pilot_info.get("rank", "Ensign")
	
	if preview_score:
		preview_score.text = "Score: " + str(pilot_info.get("score", 0))
	
	if preview_missions:
		preview_missions.text = "Missions: " + str(pilot_info.get("missions", 0))
	
	if preview_last_played:
		var last_played: String = pilot_info.get("last_played", "Never")
		preview_last_played.text = "Last Played: " + last_played
	
	# Update preview image
	if preview_image:
		var portrait: String = pilot_info.get("portrait", "")
		if not portrait.is_empty() and portrait_textures.has(portrait):
			preview_image.texture = portrait_textures[portrait]
		else:
			preview_image.texture = null

func _clear_preview() -> void:
	"""Clear the preview panel."""
	if preview_callsign:
		preview_callsign.text = "Callsign: [Select a pilot]"
	if preview_squadron:
		preview_squadron.text = "Squadron: [Select a pilot]"
	if preview_rank:
		preview_rank.text = "Rank: [Select a pilot]"
	if preview_score:
		preview_score.text = "Score: [Select a pilot]"
	if preview_missions:
		preview_missions.text = "Missions: [Select a pilot]"
	if preview_last_played:
		preview_last_played.text = "Last Played: [Select a pilot]"
	if preview_image:
		preview_image.texture = null

func _update_button_states() -> void:
	"""Update button states based on selection."""
	var has_selection: bool = not selected_pilot_callsign.is_empty()
	
	if select_button:
		select_button.disabled = not has_selection
	
	if delete_button:
		delete_button.disabled = not has_selection or not enable_pilot_deletion
	
	if stats_button:
		stats_button.disabled = not has_selection or not show_pilot_statistics

# Signal handlers
func _on_pilot_item_pressed(callsign: String) -> void:
	_select_pilot(callsign)

func _on_select_pilot_pressed() -> void:
	"""Handle select pilot button press."""
	if selected_pilot_callsign.is_empty():
		return
	
	if pilot_manager:
		var profile: PlayerProfile = pilot_manager.get_pilot_profile(selected_pilot_callsign)
		if profile:
			pilot_selected.emit(profile)

func _on_create_pilot_pressed() -> void:
	"""Handle create pilot button press."""
	pilot_creation_requested.emit()

func _on_delete_pilot_pressed() -> void:
	"""Handle delete pilot button press."""
	if selected_pilot_callsign.is_empty():
		return
	
	if confirmation_dialog:
		confirmation_dialog.dialog_text = "Are you sure you want to delete pilot '%s'?\nThis action cannot be undone." % selected_pilot_callsign
		confirmation_dialog.popup_centered()

func _on_delete_confirmed() -> void:
	"""Handle delete confirmation."""
	if selected_pilot_callsign.is_empty():
		return
	
	pilot_deletion_requested.emit(selected_pilot_callsign)
	
	if pilot_manager:
		pilot_manager.delete_pilot_profile(selected_pilot_callsign)

func _on_stats_pilot_pressed() -> void:
	"""Handle view statistics button press."""
	if selected_pilot_callsign.is_empty():
		return
	
	pilot_stats_requested.emit(selected_pilot_callsign)

func _on_cancel_pressed() -> void:
	"""Handle cancel/back button press."""
	# Could emit a signal or call scene transition
	pass

func _on_prev_page_pressed() -> void:
	"""Handle previous page button press."""
	if current_page > 0:
		current_page -= 1
		_update_pagination()
		_populate_pilot_list()

func _on_next_page_pressed() -> void:
	"""Handle next page button press."""
	if current_page < total_pages - 1:
		current_page += 1
		_update_pagination()
		_populate_pilot_list()

func _on_pilot_deleted(callsign: String) -> void:
	"""Handle pilot deletion."""
	pilot_list.erase(callsign)
	pilot_info_cache.erase(callsign)
	
	if selected_pilot_callsign == callsign:
		selected_pilot_callsign = ""
		_clear_preview()
		_update_button_states()
	
	_update_pagination()
	_populate_pilot_list()

func _on_theme_changed(theme_name: String) -> void:
	"""Handle theme change."""
	_setup_scene_styling()

# Public interface
func refresh_pilot_list() -> void:
	"""Refresh the pilot list from data."""
	_load_pilot_list()

func get_selected_pilot() -> String:
	"""Get the currently selected pilot callsign."""
	return selected_pilot_callsign

func select_pilot_by_callsign(callsign: String) -> bool:
	"""Select a pilot by callsign."""
	if callsign in pilot_list:
		_select_pilot(callsign)
		return true
	return false