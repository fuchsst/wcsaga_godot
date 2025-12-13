extends Control

# TimelineController.gd
# Controller for the Timeline Main Entry Screen
# Manages timeline nodes, year markers, connectors, and scroll effects

const TimelineEventRes = preload(
	"res://scripts/resources/ui/campaign_timeline/TimelineEventResource.gd"
)

const TIMELINE_NODE_SCENE = preload("res://scenes/ui/campaign_select/TimelineNode.tscn")
const YEAR_MARKER_SCENE = preload("res://scenes/ui/campaign_select/YearMarker.tscn")
const PROFILE_EDITOR_SCENE = preload("res://scenes/ui/profile/ProfileEditor.tscn")
const CAMPAIGN_BRIEFING_SCENE = preload("res://scenes/ui/campaign/CampaignBriefing.tscn")
const ELBOW_CONNECTOR_SCRIPT = preload("res://scenes/ui/campaign_select/ElbowConnector.gd")

var profile_editor: Control
var campaign_briefing: Control
var active_modal: Control

var _target_scroll: float = 0.0
var _edge_margin: float = 200.0
var _selected_node: Control = null
var _timeline_nodes: Array[Control] = []
var _year_markers: Dictionary = {} # year -> YearMarker
var _connectors: Array[Line2D] = [] # All elbow connectors
var _node_to_connector: Dictionary = {} # TimelineNode -> ElbowConnector

# Connector layer (created dynamically)
var _connector_layer: Control = null

# @onready variable declarations
@onready var main_scroll: ScrollContainer = $TimelineLayer/VBoxContainer/MainScroll
@onready var timeline_content: VBoxContainer = $TimelineLayer/VBoxContainer/MainScroll/TimelineContent
@onready var settings_window: Control = $ModalLayer/ModalContainer/SettingsWindow
@onready var profile_widget: HBoxContainer = $TimelineLayer/VBoxContainer/TopBar/PlayerProfileWidget
@onready var modal_layer: CanvasLayer = $ModalLayer
@onready var blur_curtain: ColorRect = $ModalLayer/BlurCurtain
@onready var system_tray: HBoxContainer = $TimelineLayer/VBoxContainer/BottomBar/SystemTray

@onready var btn_campaign: Button = $TimelineLayer/VBoxContainer/BottomBar/SystemTray/Btn_Campaign
@onready var btn_settings: Button = $TimelineLayer/VBoxContainer/BottomBar/SystemTray/Btn_Settings
@onready var btn_profile: Button = $TimelineLayer/VBoxContainer/BottomBar/SystemTray/Btn_Profile
@onready var btn_exit: Button = $TimelineLayer/VBoxContainer/BottomBar/SystemTray/Btn_Exit
@onready var ui_animator: Node = $UIAnimator

# Profile Widget nodes
@onready var profile_callsign: Label = $TimelineLayer/VBoxContainer/TopBar/PlayerProfileWidget/CallsignLabel
@onready var profile_rank: Label = $TimelineLayer/VBoxContainer/TopBar/PlayerProfileWidget/RankLabel
@onready var profile_datetime: Label = $TimelineLayer/VBoxContainer/TopBar/PlayerProfileWidget/DateTimeLabel

# Audio players
@onready var bgm_player: AudioStreamPlayer = $BGM
@onready var snd_select: AudioStreamPlayer = $SndSelect
@onready var snd_popup: AudioStreamPlayer = $SndPopup


func _ready() -> void:
	_setup_connector_layer()
	_setup_modals()
	_setup_timeline()
	_setup_signals()
	_update_profile_widget()
	if main_scroll:
		_target_scroll = _edge_margin

	# Configure BGM to loop
	if bgm_player and bgm_player.stream:
		if bgm_player.stream is AudioStreamOggVorbis:
			bgm_player.stream.loop = true


func _setup_connector_layer() -> void:
	# Create a Control node to hold all connectors
	# Uses top_level for screen-space rendering, z_index -1 to stay behind content
	_connector_layer = Control.new()
	_connector_layer.name = "ConnectorLayer"
	_connector_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connector_layer.top_level = true # Render independently of parent transforms
	_connector_layer.z_index = -1 # Render behind text boxes


func _setup_modals() -> void:
	if settings_window:
		if not settings_window.closed.is_connected(_close_modal):
			settings_window.closed.connect(_close_modal)
		settings_window.visible = false

	if PROFILE_EDITOR_SCENE:
		profile_editor = PROFILE_EDITOR_SCENE.instantiate()
		modal_layer.get_node("ModalContainer").add_child(profile_editor)
		profile_editor.visible = false
		profile_editor.closed.connect(_close_modal)
		profile_editor.profile_updated.connect(_on_profile_updated)

	if CAMPAIGN_BRIEFING_SCENE:
		campaign_briefing = CAMPAIGN_BRIEFING_SCENE.instantiate()
		modal_layer.get_node("ModalContainer").add_child(campaign_briefing)
		campaign_briefing.visible = false
		campaign_briefing.closed.connect(_close_modal)
		campaign_briefing.launch_requested.connect(_on_launch_campaign)


func _setup_signals() -> void:
	if btn_settings:
		btn_settings.pressed.connect(func():
			play_sfx("click")
			_open_settings("Audio")
		)
	if btn_profile:
		btn_profile.pressed.connect(func():
			play_sfx("click")
			_open_profile()
		)
	if btn_campaign:
		btn_campaign.pressed.connect(func():
			play_sfx("click")
			_open_selected_details()
		)
	if btn_exit:
		btn_exit.pressed.connect(func():
			play_sfx("click")
			get_tree().quit()
		)


func _on_timeline_node_clicked(_year: int, data: Resource) -> void:
	play_sfx("click")
	_open_campaign_briefing(data)


func _open_settings(tab_name: String) -> void:
	if settings_window:
		_open_modal(settings_window)
		settings_window.open(tab_name)


func _open_profile() -> void:
	if profile_editor:
		_open_modal(profile_editor)
		profile_editor.open()


func _open_campaign_briefing(data: Resource) -> void:
	if campaign_briefing:
		_open_modal(campaign_briefing)
		campaign_briefing.setup(data)


func _open_modal(modal: Control) -> void:
	if active_modal:
		active_modal.visible = false

	active_modal = modal
	blur_curtain.visible = true
	modal_layer.visible = true
	active_modal.visible = true

	var tween = create_tween()
	blur_curtain.material.set_shader_parameter("blur_amount", 0.0)
	tween.tween_property(blur_curtain.material, "shader_parameter/blur_amount", 3.0, 0.5)

	if ui_animator:
		ui_animator.open_window(active_modal)


func _close_modal() -> void:
	play_sfx("cancel")
	if active_modal:
		var modal_to_close = active_modal
		active_modal = null

		if ui_animator:
			ui_animator.close_window(modal_to_close, func():
				var tween = create_tween()
				tween.tween_property(blur_curtain.material, "shader_parameter/blur_amount", 0.0, 0.3)
				tween.tween_callback(func():
					blur_curtain.visible = false
					modal_layer.visible = false
					modal_to_close.visible = false
				)
			)
		else:
			modal_to_close.visible = false
			blur_curtain.visible = false
			modal_layer.visible = false


func _on_profile_updated(callsign: String) -> void:
	print("Profile updated: ", callsign)
	_update_profile_widget()


func _update_profile_widget() -> void:
	var profile = ProfileManager.get_active_profile()
	if profile and profile_callsign and profile_rank and profile_datetime:
		profile_callsign.text = profile.callsign.to_upper()
		profile_rank.text = profile.get_rank_name().to_upper()
		var year = profile.active_timeline_year
		var day_of_year = 79
		profile_datetime.text = str(year) + "." + str(day_of_year).pad_zeros(3)


func _setup_timeline() -> void:
	var years = TimelineDatabase.get_all_years()
	var first_node: Control = null
	var last_node: Control = null
	var last_year: int = 0

	_timeline_nodes.clear()
	_year_markers.clear()
	_connectors.clear()
	_node_to_connector.clear()

	if main_scroll:
		main_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for child in timeline_content.get_children():
		child.queue_free()

	# Add connector layer first (so it's behind content)
	timeline_content.add_child(_connector_layer)

	var node_counter: int = 0
	var is_first_year: bool = true

	for i in range(years.size()):
		var year: int = years[i]

		if is_first_year:
			var top_margin = Control.new()
			top_margin.custom_minimum_size.y = _edge_margin
			timeline_content.add_child(top_margin)
			is_first_year = false

		if last_year != 0:
			var delta_years = year - last_year
			var spacing = min(delta_years * 20.0, 300.0)
			var spacer = Control.new()
			spacer.custom_minimum_size.y = spacing
			timeline_content.add_child(spacer)

		# Create year marker (one per year)
		var year_marker = _create_year_marker(year)
		_year_markers[year] = year_marker

		var events = TimelineDatabase.get_events_for_year(year)
		events.sort_custom(func(a, b): return a.order_index < b.order_index)

		for event_data in events:
			var node = _create_timeline_node(year, event_data)
			if node:
				node.set_alignment(node_counter % 2 == 0)
				_timeline_nodes.append(node)
				node_counter += 1

				# Create connector for this node
				if year_marker:
					var connector = _create_connector(year_marker, node)
					_node_to_connector[node] = connector

				if last_node:
					node.focus_neighbor_top = last_node.get_path()
					last_node.focus_neighbor_bottom = node.get_path()

				last_node = node

				if first_node == null:
					first_node = node

		last_year = year

	var bottom_margin = Control.new()
	bottom_margin.custom_minimum_size.y = _edge_margin
	timeline_content.add_child(bottom_margin)

	if first_node:
		get_tree().create_timer(0.1).timeout.connect(func(): first_node.grab_focus())


func _create_year_marker(year: int) -> Control:
	if not YEAR_MARKER_SCENE:
		return null

	var marker = YEAR_MARKER_SCENE.instantiate()
	marker.setup(year)
	timeline_content.add_child(marker)
	return marker


func _create_timeline_node(year: int, event_data: Resource) -> Control:
	if TIMELINE_NODE_SCENE:
		var node = TIMELINE_NODE_SCENE.instantiate()
		node.setup(year, event_data, false)
		node.clicked.connect(_on_timeline_node_clicked)
		timeline_content.add_child(node)
		return node

	printerr("Failed to load TimelineNode scene.")
	return null


func _create_connector(year_marker: Control, timeline_node: Control) -> Line2D:
	var connector = Line2D.new()
	connector.set_script(ELBOW_CONNECTOR_SCRIPT)
	_connector_layer.add_child(connector)
	connector.setup(year_marker, timeline_node)
	_connectors.append(connector)
	return connector


func _input(event: InputEvent) -> void:
	# Don't process input if a modal is open
	if active_modal and active_modal.visible:
		return

	# Only handle keyboard input - let ScrollContainer handle mouse wheel natively
	if not event is InputEventKey:
		return

	# Arrow Up/Left - Previous item (allow echo for key repeat)
	if event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_left", true):
		_select_previous_item(not event.is_echo())
		get_viewport().set_input_as_handled()

	# Arrow Down/Right - Next item (allow echo for key repeat)
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_right", true):
		_select_next_item(not event.is_echo())
		get_viewport().set_input_as_handled()

	# Page Up - Previous year
	elif event.is_action_pressed("ui_page_up"):
		_scroll_to_previous_year()
		get_viewport().set_input_as_handled()

	# Page Down - Next year
	elif event.is_action_pressed("ui_page_down"):
		_scroll_to_next_year()
		get_viewport().set_input_as_handled()

	# Space/Enter - Open details
	elif event.is_action_pressed("ui_accept"):
		_open_selected_details()
		get_viewport().set_input_as_handled()


func _select_previous_item(play_sound: bool = true) -> void:
	if _timeline_nodes.is_empty():
		return

	var current_index = _timeline_nodes.find(_selected_node)
	var new_index: int
	if current_index <= 0:
		new_index = 0
	else:
		new_index = current_index - 1

	# Only do something if index actually changed
	if new_index != current_index or current_index < 0:
		_select_node_at_index(new_index, play_sound)


func _select_next_item(play_sound: bool = true) -> void:
	if _timeline_nodes.is_empty():
		return

	var current_index = _timeline_nodes.find(_selected_node)
	var new_index: int
	if current_index < 0:
		new_index = 0
	elif current_index < _timeline_nodes.size() - 1:
		new_index = current_index + 1
	else:
		new_index = current_index

	# Only do something if index actually changed
	if new_index != current_index or current_index < 0:
		_select_node_at_index(new_index, play_sound)


func _select_node_at_index(index: int, play_sound: bool = true) -> void:
	if index < 0 or index >= _timeline_nodes.size():
		return

	var node = _timeline_nodes[index]
	if not is_instance_valid(node):
		return

	# Scroll to center the node
	_scroll_node_to_center(node)

	# Update DateTimeLabel from selected event
	_update_datetime_from_node(node)

	if play_sound:
		play_sfx("select")


func _update_datetime_from_node(node: Control) -> void:
	if not profile_datetime or not node:
		return

	# Get the data from the node
	var data = node.data if "data" in node else null
	if not data:
		return

	# Update DateTimeLabel with year.order_index format
	var year_val: int = data.year if "year" in data else 0
	var order_val: int = data.order_index if "order_index" in data else 0
	profile_datetime.text = str(year_val) + "." + str(order_val).pad_zeros(3)


func _scroll_node_to_center(node: Control) -> void:
	if not main_scroll or not node:
		return

	# Calculate scroll position to center the node
	var node_y = node.position.y + node.size.y / 2.0
	var center_y = main_scroll.size.y / 2.0
	_target_scroll = node_y - center_y


func _scroll_to_previous_year() -> void:
	if _timeline_nodes.is_empty() or _year_markers.is_empty():
		return

	# Get current year
	var current_year = _selected_node.year if _selected_node and "year" in _selected_node else 0
	var years = _year_markers.keys()
	years.sort()

	# Find previous year
	var prev_year = years[0]
	for year in years:
		if year < current_year:
			prev_year = year
		else:
			break

	_scroll_to_year(prev_year)


func _scroll_to_next_year() -> void:
	if _timeline_nodes.is_empty() or _year_markers.is_empty():
		return

	# Get current year
	var current_year = _selected_node.year if _selected_node and "year" in _selected_node else 0
	var years = _year_markers.keys()
	years.sort()

	# Find next year
	var next_year = years[-1]
	for i in range(years.size() - 1, -1, -1):
		if years[i] > current_year:
			next_year = years[i]
		else:
			break

	_scroll_to_year(next_year)


func _scroll_to_year(year: int) -> void:
	if year not in _year_markers:
		return

	var marker = _year_markers[year]
	if not is_instance_valid(marker):
		return

	# Scroll to put year marker at top with margin
	var top_margin = 80.0 # Margin from top panel
	_target_scroll = marker.position.y - top_margin

	# Also select the first item of that year
	for node in _timeline_nodes:
		if is_instance_valid(node) and "year" in node and node.year == year:
			# Don't call _scroll_node_to_center, just trigger selection update
			play_sfx("select")
			break


func _open_selected_details() -> void:
	if _selected_node and is_instance_valid(_selected_node) and "data" in _selected_node:
		play_sfx("popup")
		_open_campaign_briefing(_selected_node.data)


func _process(delta: float) -> void:
	_update_scroll_logic(delta)
	_update_scroll_visuals()
	_update_selection()


func _update_scroll_logic(delta: float) -> void:
	if not main_scroll:
		return

	var max_scroll = max(0, main_scroll.get_v_scroll_bar().max_value - main_scroll.size.y)
	_target_scroll = clamp(_target_scroll, 0, max_scroll)

	var current = float(main_scroll.scroll_vertical)
	if abs(current - _target_scroll) > 1.0:
		var new_pos = lerp(current, _target_scroll, delta * 10.0)
		main_scroll.scroll_vertical = int(new_pos)


func _update_scroll_visuals() -> void:
	if main_scroll:
		var scroll_v = main_scroll.scroll_vertical
		var max_s = max(1.0, main_scroll.get_v_scroll_bar().max_value - main_scroll.size.y)
		var scroll_ratio = scroll_v / max_s

		# Update 3D background
		var bg_viewport = $BackgroundLayer/StarfieldViewport/SubViewport
		if bg_viewport and bg_viewport.has_node("SpaceScene3D"):
			var space_scene = bg_viewport.get_node("SpaceScene3D")
			var target_rotation_x = scroll_ratio * 40.0
			space_scene.rotation_degrees.x = lerp(space_scene.rotation_degrees.x, target_rotation_x, 0.05)
			var target_y = scroll_ratio * 20.0
			space_scene.position.y = lerp(space_scene.position.y, -target_y, 0.05)

	if not timeline_content:
		return

	var center_y = main_scroll.size.y / 2.0
	var scroll_offset = main_scroll.scroll_vertical

	for node in _timeline_nodes:
		if not is_instance_valid(node):
			continue

		var node_y = node.position.y - scroll_offset + (node.size.y / 2.0)
		var dist = abs(center_y - node_y)

		var focus_range = 250.0
		var scale_factor = 0.5 # More aggressive base scale for distant items
		var alpha = 0.2 # Lower alpha for distant items

		if dist < focus_range:
			var t = 1.0 - (dist / focus_range)
			t = ease(t, 0.3)
			scale_factor = 0.5 + (t * 0.5) # Scale from 0.5 to 1.0
			alpha = 0.2 + (t * 0.8) # Alpha from 0.2 to 1.0

		if node.has_method("apply_scroll_effect"):
			node.apply_scroll_effect(scale_factor, alpha)


func _update_selection() -> void:
	if not main_scroll or _timeline_nodes.is_empty():
		return

	var center_y = main_scroll.size.y / 2.0
	var scroll_offset = main_scroll.scroll_vertical

	var closest_node: Control = null
	var closest_dist: float = INF

	for node in _timeline_nodes:
		if not is_instance_valid(node):
			continue

		var node_y = node.position.y - scroll_offset + (node.size.y / 2.0)
		var dist = abs(center_y - node_y)

		if dist < closest_dist:
			closest_dist = dist
			closest_node = node

	# Only select if within reasonable range
	if closest_node and closest_dist < 150.0:
		if _selected_node != closest_node:
			# Deselect previous
			if _selected_node and is_instance_valid(_selected_node):
				if _selected_node.has_method("set_selected"):
					_selected_node.set_selected(false)
				# Unhighlight year marker
				var prev_year = _selected_node.year if "year" in _selected_node else 0
				if prev_year in _year_markers:
					var marker = _year_markers[prev_year]
					if is_instance_valid(marker) and marker.has_method("set_highlighted"):
						marker.set_highlighted(false)
				# Unhighlight connector
				if _selected_node in _node_to_connector:
					var connector = _node_to_connector[_selected_node]
					if is_instance_valid(connector) and connector.has_method("set_highlighted"):
						connector.set_highlighted(false)

			# Select new
			_selected_node = closest_node
			if _selected_node.has_method("set_selected"):
				_selected_node.set_selected(true)

			# Update DateTimeLabel for mouse wheel scrolling
			_update_datetime_from_node(_selected_node)
			play_sfx("select")

			# Highlight corresponding year marker
			var new_year = _selected_node.year if "year" in _selected_node else 0
			if new_year in _year_markers:
				var marker = _year_markers[new_year]
				if is_instance_valid(marker) and marker.has_method("set_highlighted"):
					marker.set_highlighted(true)
			# Highlight connector
			if _selected_node in _node_to_connector:
				var connector = _node_to_connector[_selected_node]
				if is_instance_valid(connector) and connector.has_method("set_highlighted"):
					connector.set_highlighted(true)


func play_sfx(sfx_name: String) -> void:
	# Use dedicated audio players if available
	match sfx_name:
		"click", "popup":
			if snd_popup:
				snd_popup.play()
		"select":
			if snd_select:
				snd_select.play()
		"cancel":
			if snd_select:
				snd_select.play()
		_:
			# Fallback to ui_animator
			if ui_animator and ui_animator.has_method("play_sound"):
				ui_animator.play_sound(sfx_name)


func _on_launch_campaign(campaign_data: Resource) -> void:
	print("Launching Campaign: ", campaign_data.title)
	var profile = ProfileManager.get_active_profile()
	if profile:
		profile.current_campaign = campaign_data.title
		profile.active_timeline_year = campaign_data.year
		ProfileManager.save_profile()

	print("Campaign '", campaign_data.title, "' would launch here!")
