extends Control

signal closed
signal launch_requested(campaign_data)

@onready var title_label = $BackgroundPanel/MarginContainer/VBoxContainer/CampaignTitle
@onready var desc_label = $BackgroundPanel/MarginContainer/VBoxContainer/ContentColumns/DescriptionCol/ScrollContainer/DescriptionText
@onready var status_label = $BackgroundPanel/MarginContainer/VBoxContainer/ContentColumns/InfoCol/StatusLabel
@onready var difficulty_label = $BackgroundPanel/MarginContainer/VBoxContainer/ContentColumns/InfoCol/DifficultyLabel
@onready var year_label = $BackgroundPanel/MarginContainer/VBoxContainer/ContentColumns/InfoCol/YearLabel
@onready var era_label = $BackgroundPanel/MarginContainer/VBoxContainer/ContentColumns/InfoCol/EraLabel
@onready var launch_button = $BackgroundPanel/MarginContainer/VBoxContainer/LaunchButton
@onready var close_button = $BackgroundPanel/MarginContainer/VBoxContainer/CloseButton

var current_data: TimelineEventResource

func _ready():
	launch_button.pressed.connect(_on_launch_pressed)
	close_button.pressed.connect(_on_close_pressed)

func setup(data: TimelineEventResource):
	current_data = data
	visible = true

	# Setup UI from TimelineEventResource
	if current_data:
		title_label.text = current_data.title

		var description_text = ""
		if not current_data.long_description.is_empty():
			description_text = current_data.long_description
		elif not current_data.short_description.is_empty():
			description_text = current_data.short_description
		else:
			description_text = "No description available."

		desc_label.text = description_text

		# Update info panel
		if current_data.locked:
			status_label.text = "Status: [color=#ff4444]LOCKED[/color]"
			launch_button.disabled = true
		else:
			status_label.text = "Status: [color=#44ff44]AVAILABLE[/color]"
			launch_button.disabled = false

		difficulty_label.text = "Difficulty: Standard"
		year_label.text = "Year: " + str(current_data.year)
		era_label.text = "Era: " + current_data.era

func _on_launch_pressed():
	if current_data and not current_data.locked:
		# Update profile with current campaign
		var profile = ProfileManager.get_active_profile()
		if profile:
			profile.current_campaign = current_data.title
			profile.active_timeline_year = current_data.year
			ProfileManager.save_profile()

		launch_requested.emit(current_data)
	closed.emit()
	visible = false

func _on_close_pressed():
	closed.emit()
	visible = false
