@tool
extends Control

## Import Dashboard
## Provides a UI to trigger the WCS import process within the editor.

const WCSImporter = preload("res://addons/wcs_import/core/wcs_importer.gd")

# List of interesting types to show in dropdown
const IMPORT_TYPES = [
	"All",
	"ships",
	"weapons",
	"mission",
	"campaign",
	"animation",
	"sounds",
	"music",
	"asteroids",
	"nebula",
	"stars",
	"species",
	"icons",
	"hud_gauges",
	"ai_profiles",
	"ai_classes"
]

var _importer: WCSImporter

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var run_button: Button = $VBoxContainer/RunButton
@onready var type_option: OptionButton = $VBoxContainer/HBoxContainer/TypeOptionButton


func _ready() -> void:
	if run_button:
		run_button.pressed.connect(_on_run_button_pressed)

	if type_option:
		type_option.clear()
		for type in IMPORT_TYPES:
			type_option.add_item(type)
		type_option.select(0)

	status_label.text = "Ready to import."


func _on_run_button_pressed() -> void:
	status_label.text = "Running import..."
	run_button.disabled = true

	await get_tree().process_frame

	var selected_idx = type_option.selected
	var selected_type = type_option.get_item_text(selected_idx)

	_importer = WCSImporter.new()

	# Determine filters
	var types_to_process = []
	if selected_type != "All":
		types_to_process.append(selected_type)

	var output_dir = "res://"

	print("Starting import from Dashboard. Type: " + selected_type)

	var success = _importer.process_batch(output_dir, "", types_to_process)

	if success:
		status_label.text = "Import completed successfully!"
	else:
		status_label.text = "Import completed with errors. Check console."

	run_button.disabled = false
	_importer = null
