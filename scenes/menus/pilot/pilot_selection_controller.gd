class_name PilotSelectionController
extends Control

## WCS pilot selection scene controller providing pilot browser and management.
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

# Internal components
var main_container: VBoxContainer = null
var title_label: Label = null
var content_container: HBoxContainer = null
var pilot_list_panel: Control = null
var pilot_scroll: ScrollContainer = null
var pilot_list_container: VBoxContainer = null
var preview_panel: Control = null
var preview_image: TextureRect = null
var preview_info_container: VBoxContainer = null
var preview_callsign: Label = null
var preview_squadron: Label = null
var preview_rank: Label = null
var preview_score: Label = null
var preview_missions: Label = null
var preview_last_played: Label = null
var button_container: HBoxContainer = null
var select_button: MenuButton = null
var create_button: MenuButton = null
var delete_button: MenuButton = null
var stats_button: MenuButton = null
var cancel_button: MenuButton = null

# Pagination
var pagination_container: HBoxContainer = null
var prev_page_button: Button = null
var page_label: Label = null
var next_page_button: Button = null
var current_page: int = 0
var total_pages: int = 0

# Data management
var pilot_manager: PilotDataManager = null
var pilot_list: Array[String] = []
var pilot_items: Array[Control] = []
var selected_pilot_callsign: String = ""
var pilot_info_cache: Dictionary = {}

# Theme integration
var ui_theme_manager: UIThemeManager = null
var portrait_textures: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_pilot_selection()

func _initialize_pilot_selection() -> void:
	"""Initialize pilot selection scene with WCS styling and pilot data."""
	print("PilotSelectionController: Initializing pilot selection interface")
	
	# Connect to theme manager
	_connect_to_theme_manager()
	
	# Initialize pilot manager
	pilot_manager = PilotDataManager.new()
	pilot_manager.pilot_list_updated.connect(_on_pilot_list_updated)
	pilot_manager.validation_error.connect(_on_pilot_manager_error)
	
	# Setup scene structure
	_create_scene_structure()
	_setup_scene_styling()
	_load_pilot_portraits()
	
	# Load pilot list
	_refresh_pilot_list()

func _connect_to_theme_manager() -> void:
	"""Connect to UIThemeManager for consistent styling."""
	var theme_manager: Node = get_tree().get_first_node_in_group("ui_theme_manager")
	if theme_manager and theme_manager is UIThemeManager:
		ui_theme_manager = theme_manager as UIThemeManager
		ui_theme_manager.theme_changed.connect(_on_theme_changed)

func _create_scene_structure() -> void:
	"""Create the pilot selection scene structure."""
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
	title_label.text = "Select Pilot"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title_label)
	
	# Content container with pilot list and preview
	content_container = HBoxContainer.new()
	content_container.name = "ContentContainer"
	content_container.add_theme_constant_override("separation", 30)
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(content_container)
	
	# Pilot list panel
	_create_pilot_list_panel(content_container)
	
	# Preview panel
	if show_pilot_preview:
		_create_preview_panel(content_container)
	
	# Pagination
	_create_pagination_controls()
	
	# Button container
	button_container = HBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 15)
	main_container.add_child(button_container)
	
	_create_action_buttons()

func _create_pilot_list_panel(parent: Control) -> void:
	"""Create pilot list panel."""
	pilot_list_panel = Control.new()
	pilot_list_panel.name = "PilotListPanel"
	pilot_list_panel.custom_minimum_size = Vector2(400, 0)
	pilot_list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(pilot_list_panel)
	
	var list_container: VBoxContainer = VBoxContainer.new()
	list_container.name = "ListContainer"
	list_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	list_container.add_theme_constant_override("separation", 10)
	pilot_list_panel.add_child(list_container)
	
	# List title
	var list_title: Label = Label.new()
	list_title.text = "Available Pilots"
	list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_title.add_theme_font_size_override("font_size", 18)
	list_container.add_child(list_title)
	
	# Scroll container for pilot list
	pilot_scroll = ScrollContainer.new()
	pilot_scroll.name = "PilotScroll"
	pilot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_container.add_child(pilot_scroll)
	
	# Pilot list container
	pilot_list_container = VBoxContainer.new()
	pilot_list_container.name = "PilotListContainer"
	pilot_list_container.add_theme_constant_override("separation", 5)
	pilot_scroll.add_child(pilot_list_container)

func _create_preview_panel(parent: Control) -> void:
	"""Create pilot preview panel."""
	preview_panel = Control.new()
	preview_panel.name = "PreviewPanel"
	preview_panel.custom_minimum_size = Vector2(350, 0)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(preview_panel)
	
	var preview_container: VBoxContainer = VBoxContainer.new()
	preview_container.name = "PreviewContainer"
	preview_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_container.add_theme_constant_override("separation", 15)
	preview_panel.add_child(preview_container)
	
	# Preview title
	var preview_title: Label = Label.new()
	preview_title.text = "Pilot Information"
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_title.add_theme_font_size_override("font_size", 18)
	preview_container.add_child(preview_title)
	
	# Preview image
	preview_image = TextureRect.new()
	preview_image.name = "PreviewImage"
	preview_image.custom_minimum_size = Vector2(128, 128)
	preview_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_container.add_child(preview_image)
	
	# Preview info container
	preview_info_container = VBoxContainer.new()
	preview_info_container.name = "PreviewInfoContainer"
	preview_info_container.add_theme_constant_override("separation", 8)
	preview_container.add_child(preview_info_container)
	
	# Create info labels
	_create_preview_info_labels()

func _create_preview_info_labels() -> void:
	"""Create preview information labels."""
	# Callsign
	var callsign_container: HBoxContainer = HBoxContainer.new()
	var callsign_label: Label = Label.new()
	callsign_label.text = "Callsign:"
	callsign_label.custom_minimum_size.x = 100
	callsign_label.add_theme_font_size_override("font_size", 14)
	preview_callsign = Label.new()
	preview_callsign.text = "<none selected>"
	preview_callsign.add_theme_font_size_override("font_size", 14)
	callsign_container.add_child(callsign_label)
	callsign_container.add_child(preview_callsign)
	preview_info_container.add_child(callsign_container)
	
	# Squadron
	var squadron_container: HBoxContainer = HBoxContainer.new()
	var squadron_label: Label = Label.new()
	squadron_label.text = "Squadron:"
	squadron_label.custom_minimum_size.x = 100
	squadron_label.add_theme_font_size_override("font_size", 14)
	preview_squadron = Label.new()
	preview_squadron.text = "<none selected>"
	preview_squadron.add_theme_font_size_override("font_size", 14)
	squadron_container.add_child(squadron_label)
	squadron_container.add_child(preview_squadron)
	preview_info_container.add_child(squadron_container)
	
	# Rank
	var rank_container: HBoxContainer = HBoxContainer.new()
	var rank_label: Label = Label.new()
	rank_label.text = "Rank:"
	rank_label.custom_minimum_size.x = 100
	rank_label.add_theme_font_size_override("font_size", 14)
	preview_rank = Label.new()
	preview_rank.text = "<none selected>"
	preview_rank.add_theme_font_size_override("font_size", 14)
	rank_container.add_child(rank_label)
	rank_container.add_child(preview_rank)
	preview_info_container.add_child(rank_container)
	
	# Score
	var score_container: HBoxContainer = HBoxContainer.new()
	var score_label: Label = Label.new()
	score_label.text = "Score:"
	score_label.custom_minimum_size.x = 100
	score_label.add_theme_font_size_override("font_size", 14)
	preview_score = Label.new()
	preview_score.text = "<none selected>"
	preview_score.add_theme_font_size_override("font_size", 14)
	score_container.add_child(score_label)
	score_container.add_child(preview_score)
	preview_info_container.add_child(score_container)
	
	# Missions
	var missions_container: HBoxContainer = HBoxContainer.new()
	var missions_label: Label = Label.new()
	missions_label.text = "Missions:"
	missions_label.custom_minimum_size.x = 100
	missions_label.add_theme_font_size_override("font_size", 14)
	preview_missions = Label.new()
	preview_missions.text = "<none selected>"
	preview_missions.add_theme_font_size_override("font_size", 14)
	missions_container.add_child(missions_label)
	missions_container.add_child(preview_missions)
	preview_info_container.add_child(missions_container)
	
	# Last played
	var last_played_container: HBoxContainer = HBoxContainer.new()
	var last_played_label: Label = Label.new()
	last_played_label.text = "Last Played:"
	last_played_label.custom_minimum_size.x = 100
	last_played_label.add_theme_font_size_override("font_size", 14)
	preview_last_played = Label.new()
	preview_last_played.text = "<none selected>"
	preview_last_played.add_theme_font_size_override("font_size", 14)
	last_played_container.add_child(last_played_label)
	last_played_container.add_child(preview_last_played)
	preview_info_container.add_child(last_played_container)

func _create_pagination_controls() -> void:
	"""Create pagination controls."""
	pagination_container = HBoxContainer.new()
	pagination_container.name = "PaginationContainer"
	pagination_container.alignment = BoxContainer.ALIGNMENT_CENTER
	pagination_container.add_theme_constant_override("separation", 10)
	main_container.add_child(pagination_container)
	
	# Previous page button
	prev_page_button = Button.new()
	prev_page_button.text = "< Previous"
	prev_page_button.disabled = true
	prev_page_button.pressed.connect(_on_prev_page_pressed)
	pagination_container.add_child(prev_page_button)
	
	# Page label
	page_label = Label.new()
	page_label.text = "Page 1 of 1"
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.custom_minimum_size.x = 100
	pagination_container.add_child(page_label)
	
	# Next page button
	next_page_button = Button.new()
	next_page_button.text = "Next >"
	next_page_button.disabled = true
	next_page_button.pressed.connect(_on_next_page_pressed)
	pagination_container.add_child(next_page_button)

func _create_action_buttons() -> void:
	"""Create action buttons."""
	# Select button
	select_button = MenuButton.new()
	select_button.button_text = "Select Pilot"
	select_button.button_category = MenuButton.ButtonCategory.PRIMARY
	select_button.disabled = true
	select_button.pressed.connect(_on_select_pilot_pressed)
	button_container.add_child(select_button)
	
	# Create new pilot button
	create_button = MenuButton.new()
	create_button.button_text = "Create New"
	create_button.button_category = MenuButton.ButtonCategory.SUCCESS
	create_button.pressed.connect(_on_create_pilot_pressed)
	button_container.add_child(create_button)
	
	# Delete pilot button
	if enable_pilot_deletion:
		delete_button = MenuButton.new()
		delete_button.button_text = "Delete"
		delete_button.button_category = MenuButton.ButtonCategory.DANGER
		delete_button.disabled = true
		delete_button.pressed.connect(_on_delete_pilot_pressed)
		button_container.add_child(delete_button)
	
	# Stats button
	if show_pilot_statistics:
		stats_button = MenuButton.new()
		stats_button.button_text = "Statistics"
		stats_button.button_category = MenuButton.ButtonCategory.SECONDARY
		stats_button.disabled = true
		stats_button.pressed.connect(_on_stats_pilot_pressed)
		button_container.add_child(stats_button)
	
	# Cancel button
	cancel_button = MenuButton.new()
	cancel_button.button_text = "Cancel"
	cancel_button.button_category = MenuButton.ButtonCategory.SECONDARY
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_container.add_child(cancel_button)

func _setup_scene_styling() -> void:
	"""Apply WCS styling to scene components."""
	if not ui_theme_manager:
		return
	
	# Apply theme to controls
	ui_theme_manager.apply_theme_to_control(self)
	
	# Style title
	title_label.add_theme_color_override("font_color", ui_theme_manager.get_wcs_color("gray_light"))
	
	# Style pagination buttons
	if prev_page_button:
		ui_theme_manager.apply_theme_to_control(prev_page_button)
	if next_page_button:
		ui_theme_manager.apply_theme_to_control(next_page_button)

func _load_pilot_portraits() -> void:
	"""Load pilot portrait textures for preview."""
	portrait_textures.clear()
	
	# Load default portraits
	var portrait_dir: String = "res://assets/images/pilots/"
	var dir: DirAccess = DirAccess.open(portrait_dir)
	
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		
		while not file_name.is_empty():
			if not dir.current_is_dir() and _is_image_file(file_name):
				var portrait_path: String = portrait_dir + file_name
				var texture: Texture2D = load(portrait_path) as Texture2D
				if texture:
					portrait_textures[file_name] = texture
			file_name = dir.get_next()
		
		dir.list_dir_end()

func _is_image_file(filename: String) -> bool:
	"""Check if file is a supported image format."""
	var ext: String = filename.get_extension().to_lower()
	return ext in ["png", "jpg", "jpeg", "bmp", "tga", "webp"]

# ============================================================================
# PILOT LIST MANAGEMENT
# ============================================================================

func _refresh_pilot_list() -> void:
	"""Refresh pilot list from manager."""
	pilot_list = pilot_manager.get_pilot_list()
	_update_pagination()
	_populate_pilot_list()
	
	# Auto-select first pilot if enabled and available
	if auto_select_first_pilot and not pilot_list.is_empty():
		_select_pilot(pilot_list[0])

func _update_pagination() -> void:
	"""Update pagination controls."""
	total_pages = max(1, (pilot_list.size() + pilots_per_page - 1) / pilots_per_page)
	current_page = clamp(current_page, 0, total_pages - 1)
	
	# Update pagination UI
	if page_label:
		page_label.text = "Page %d of %d" % [current_page + 1, total_pages]
	
	if prev_page_button:
		prev_page_button.disabled = (current_page <= 0)
	
	if next_page_button:
		next_page_button.disabled = (current_page >= total_pages - 1)

func _populate_pilot_list() -> void:
	"""Populate pilot list for current page."""
	# Clear existing items
	for item in pilot_items:
		item.queue_free()
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
	"""Create pilot list item."""
	var item_container: Control = Control.new()
	item_container.name = "PilotItem_" + callsign
	item_container.custom_minimum_size = Vector2(0, 60)
	
	# Item button
	var item_button: Button = Button.new()
	item_button.name = "ItemButton"
	item_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item_button.text = callsign
	item_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item_button.pressed.connect(_on_pilot_item_selected.bind(callsign))
	
	# Apply styling
	if ui_theme_manager:
		ui_theme_manager.apply_theme_to_control(item_button)
	
	item_container.add_child(item_button)
	
	# Load pilot info
	var pilot_info: Dictionary = pilot_manager.get_pilot_info(callsign)
	if pilot_info.has("squadron") and not pilot_info.squadron.is_empty():
		item_button.text = "%s (%s)" % [callsign, pilot_info.squadron]
	
	return item_container

func _select_pilot(callsign: String) -> void:
	"""Select pilot and update preview."""
	selected_pilot_callsign = callsign
	_update_pilot_selection_ui()
	_update_pilot_preview()

func _update_pilot_selection_ui() -> void:
	"""Update UI to reflect pilot selection."""
	# Update button states
	var has_selection: bool = not selected_pilot_callsign.is_empty()
	
	if select_button:
		select_button.disabled = not has_selection
	
	if delete_button:
		delete_button.disabled = not has_selection
	
	if stats_button:
		stats_button.disabled = not has_selection
	
	# Highlight selected item
	for item in pilot_items:
		var button: Button = item.get_node("ItemButton") as Button
		if button:
			if item.name == "PilotItem_" + selected_pilot_callsign:
				button.modulate = Color.YELLOW  # Highlight selected
			else:
				button.modulate = Color.WHITE   # Normal state

func _update_pilot_preview() -> void:
	"""Update pilot preview panel."""
	if not show_pilot_preview or not preview_panel:
		return
	
	if selected_pilot_callsign.is_empty():
		_clear_pilot_preview()
		return
	
	# Get pilot info
	var pilot_info: Dictionary = pilot_manager.get_pilot_info(selected_pilot_callsign)
	if pilot_info.is_empty():
		_clear_pilot_preview()
		return
	
	# Update preview info
	if preview_callsign:
		preview_callsign.text = pilot_info.get("callsign", "Unknown")
	
	if preview_squadron:
		preview_squadron.text = pilot_info.get("squadron", "Unassigned")
	
	if preview_rank:
		var rank: int = pilot_info.get("rank", 0)
		preview_rank.text = _get_rank_name(rank)
	
	if preview_score:
		var score: int = pilot_info.get("score", 0)
		preview_score.text = str(score)
	
	if preview_missions:
		var missions: int = pilot_info.get("missions", 0)
		preview_missions.text = str(missions)
	
	if preview_last_played:
		var last_played: int = pilot_info.get("last_played", 0)
		preview_last_played.text = _format_date(last_played)
	
	# Update portrait
	if preview_image:
		var image_filename: String = pilot_info.get("image", "")
		if not image_filename.is_empty() and portrait_textures.has(image_filename):
			preview_image.texture = portrait_textures[image_filename]
		else:
			preview_image.texture = null

func _clear_pilot_preview() -> void:
	"""Clear pilot preview panel."""
	if preview_callsign:
		preview_callsign.text = "<none selected>"
	if preview_squadron:
		preview_squadron.text = "<none selected>"
	if preview_rank:
		preview_rank.text = "<none selected>"
	if preview_score:
		preview_score.text = "<none selected>"
	if preview_missions:
		preview_missions.text = "<none selected>"
	if preview_last_played:
		preview_last_played.text = "<none selected>"
	if preview_image:
		preview_image.texture = null

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

func _format_date(unix_time: int) -> String:
	"""Format unix timestamp to readable date."""
	if unix_time <= 0:
		return "Never"
	
	var datetime: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d" % [datetime.year, datetime.month, datetime.day]

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_pilot_item_selected(callsign: String) -> void:
	"""Handle pilot item selection."""
	_select_pilot(callsign)

func _on_select_pilot_pressed() -> void:
	"""Handle select pilot button press."""
	if selected_pilot_callsign.is_empty():
		return
	
	# Load pilot profile
	var profile: PlayerProfile = pilot_manager.load_pilot(selected_pilot_callsign)
	if profile:
		pilot_selected.emit(profile)
	else:
		push_error("Failed to load pilot: %s" % selected_pilot_callsign)

func _on_create_pilot_pressed() -> void:
	"""Handle create pilot button press."""
	pilot_creation_requested.emit()

func _on_delete_pilot_pressed() -> void:
	"""Handle delete pilot button press."""
	if selected_pilot_callsign.is_empty():
		return
	
	# Show confirmation dialog
	var dialog: DialogModal = DialogModal.show_confirmation_dialog(
		get_parent(),
		"Delete Pilot",
		"Are you sure you want to delete pilot '%s'? This action cannot be undone." % selected_pilot_callsign,
		_on_delete_pilot_confirmed
	)

func _on_delete_pilot_confirmed(confirmed: bool, data: Dictionary) -> void:
	"""Handle delete pilot confirmation."""
	if confirmed and not selected_pilot_callsign.is_empty():
		if pilot_manager.delete_pilot(selected_pilot_callsign, true):
			selected_pilot_callsign = ""
			_refresh_pilot_list()

func _on_stats_pilot_pressed() -> void:
	"""Handle stats pilot button press."""
	if not selected_pilot_callsign.is_empty():
		pilot_stats_requested.emit(selected_pilot_callsign)

func _on_cancel_pressed() -> void:
	"""Handle cancel button press."""
	# Return to main menu or previous scene
	get_tree().quit()

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

func _on_pilot_list_updated(pilots: Array[String]) -> void:
	"""Handle pilot list updates from manager."""
	_refresh_pilot_list()

func _on_pilot_manager_error(error_message: String) -> void:
	"""Handle pilot manager errors."""
	push_error("PilotSelectionController: %s" % error_message)

func _on_theme_changed(theme_name: String) -> void:
	"""Handle theme changes."""
	_setup_scene_styling()

# ============================================================================
# PUBLIC API
# ============================================================================

func refresh_pilots() -> void:
	"""Refresh pilot list from manager."""
	_refresh_pilot_list()

func select_pilot_by_callsign(callsign: String) -> bool:
	"""Select pilot by callsign if it exists."""
	if callsign in pilot_list:
		_select_pilot(callsign)
		return true
	return false

func get_selected_pilot() -> String:
	"""Get currently selected pilot callsign."""
	return selected_pilot_callsign

func get_pilot_count() -> int:
	"""Get total number of pilots."""
	return pilot_list.size()

func clear_selection() -> void:
	"""Clear pilot selection."""
	selected_pilot_callsign = ""
	_update_pilot_selection_ui()
	_clear_pilot_preview()