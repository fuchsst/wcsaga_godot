extends Control
## ProfileEditor UI for viewing and editing player profiles.

signal closed
signal profile_updated(callsign: String)

@onready var callsign_input: LineEdit = (
	$BackgroundPanel/MarginContainer/VBoxContainer/FormContainer/CallsignInput
)
@onready
var rank_label: Label = $BackgroundPanel/MarginContainer/VBoxContainer/FormContainer/RankValue
@onready
var kills_label: Label = $BackgroundPanel/MarginContainer/VBoxContainer/FormContainer/KillsValue
@onready
var squad_input: LineEdit = $BackgroundPanel/MarginContainer/VBoxContainer/FormContainer/SquadInput
@onready var save_button: Button = $BackgroundPanel/MarginContainer/VBoxContainer/Buttons/SaveButton
@onready
var cancel_button: Button = $BackgroundPanel/MarginContainer/VBoxContainer/Buttons/CancelButton


func _ready() -> void:
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	callsign_input.text_changed.connect(_on_callsign_changed)


func open() -> void:
	visible = true
	_load_profile()
	callsign_input.grab_focus()


func _load_profile() -> void:
	var profile: UserProfile = ProfileManager.get_active_profile()
	if not profile:
		push_warning("ProfileEditor: No active profile to edit.")
		return

	callsign_input.text = profile.callsign
	rank_label.text = profile.get_rank_name()
	kills_label.text = str(profile.get_kills())
	squad_input.text = profile.squad_name


func _on_callsign_changed(_text: String) -> void:
	# Visual feedback for valid callsign could be added here
	pass


func _on_save_pressed() -> void:
	var profile: UserProfile = ProfileManager.get_active_profile()
	if not profile:
		return

	var new_callsign := callsign_input.text.strip_edges()
	if new_callsign.is_empty():
		push_warning("ProfileEditor: Callsign cannot be empty.")
		return

	profile.callsign = new_callsign
	profile.short_callsign = new_callsign.left(8)
	profile.squad_name = squad_input.text.strip_edges()
	profile.calculate_rank()

	ProfileManager.save_profile()

	profile_updated.emit(new_callsign)
	closed.emit()
	visible = false


func _on_cancel_pressed() -> void:
	closed.emit()
	visible = false
