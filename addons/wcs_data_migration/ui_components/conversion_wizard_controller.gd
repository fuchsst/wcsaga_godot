@tool
extends Control
class_name ConversionWizardController

## WCS to Godot Conversion Wizard Controller
## Manages the step-by-step wizard workflow for converting WCS assets to Godot format
## Coordinates between wizard steps and provides navigation logic

signal wizard_completed()
signal wizard_cancelled()

const CONFIG_FILE = "user://wcs_migration_config.cfg"

# Wizard steps enum
enum WizardStep {
	SET_PATHS = 1,
	EXTRACT_ARCHIVES = 2,
	CREATE_MAPPING = 3,
	CONVERT_ASSETS = 4
}

# UI References
var step_indicator: Label
var step1_button: Button
var step2_button: Button
var step3_button: Button
var step4_button: Button
var wizard_content: Control
var step_paths: WizardStepPaths
var step_extraction: WizardStepExtraction
var step_mapping: WizardStepMapping
var step_conversion: WizardStepConversion
var back_button: Button
var next_button: Button
var status_label: Label

# State
var current_step: WizardStep = WizardStep.SET_PATHS
var wizard_steps: Array[WizardStepBase] = []
var is_exiting: bool = false
var wizard_data: Dictionary = {
	"game_directory": "",
	"extraction_directory": "",
	"target_directory": "",
	"python_path": "",
	"vp_files": [],
	"asset_mappings": [],
	"selected_asset_types": []
}

func _ready() -> void:
	name = "WCS Asset Mapper"
	_load_config()
	# Defer setup to ensure all child nodes are ready
	call_deferred("_deferred_setup")

func _deferred_setup() -> void:
	"""Setup wizard after all nodes are ready."""
	_get_ui_nodes()
	_setup_wizard()
	_connect_signals()
	_show_step(WizardStep.SET_PATHS)

func _get_ui_nodes() -> void:
	"""Get UI nodes using find_child for robust access."""
	step_indicator = find_child("StepCounter", true, false)
	step1_button = find_child("Step1Button", true, false)
	step2_button = find_child("Step2Button", true, false)
	step3_button = find_child("Step3Button", true, false)
	step4_button = find_child("Step4Button", true, false)
	wizard_content = find_child("WizardContent", true, false)
	step_paths = find_child("Step1Panel", true, false)
	step_extraction = find_child("Step2Panel", true, false)
	step_mapping = find_child("Step3Panel", true, false)
	step_conversion = find_child("Step4Panel", true, false)
	back_button = find_child("BackButton", true, false)
	next_button = find_child("NextButton", true, false)
	status_label = find_child("StatusLabel", true, false)
	
	# Check if nodes were found
	if not step_indicator:
		printerr("StepCounter not found")
	if not step1_button:
		printerr("Step1Button not found")
	if not wizard_content:
		printerr("WizardContent not found")

func _setup_wizard() -> void:
	"""Initialize wizard controller and steps."""
	# Register wizard steps
	wizard_steps = [step_paths, step_extraction, step_mapping, step_conversion]
	
	# Setup each step and hide them initially
	for step in wizard_steps:
		if step and is_instance_valid(step):
			step.set_wizard_data(wizard_data)
			step.step_completed.connect(_on_step_completed)
			step.step_validation_changed.connect(_on_step_validation_changed)
			step.status_message.connect(_on_status_message)
			step.data_changed.connect(_on_step_data_changed)
			step.visible = false  # Hide all steps initially

func _connect_signals() -> void:
	"""Connect UI signals."""
	# Navigation
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	
	# Step navigation buttons
	if step1_button:
		step1_button.pressed.connect(func(): _go_to_step(WizardStep.SET_PATHS))
	if step2_button:
		step2_button.pressed.connect(func(): _go_to_step(WizardStep.EXTRACT_ARCHIVES))
	if step3_button:
		step3_button.pressed.connect(func(): _go_to_step(WizardStep.CREATE_MAPPING))
	if step4_button:
		step4_button.pressed.connect(func(): _go_to_step(WizardStep.CONVERT_ASSETS))

func _show_step(step: WizardStep) -> void:
	"""Show the specified wizard step."""
	# Deactivate current step
	if current_step <= wizard_steps.size() and wizard_steps[current_step - 1] and is_instance_valid(wizard_steps[current_step - 1]):
		wizard_steps[current_step - 1].deactivate_step()
	
	current_step = step
	
	# Activate new step
	if current_step <= wizard_steps.size() and wizard_steps[current_step - 1] and is_instance_valid(wizard_steps[current_step - 1]):
		var current_step_node = wizard_steps[current_step - 1]
		current_step_node.activate_step()
		current_step_node.set_wizard_data(wizard_data)
	
	_update_step_display()
	_update_navigation()

func _go_to_step(step: WizardStep) -> void:
	"""Navigate to specified step if accessible."""
	if is_exiting: return
	if _is_step_accessible(step):
		_show_step(step)

func _is_step_accessible(step: WizardStep) -> bool:
	"""Check if step is accessible based on prerequisites."""
	match step:
		WizardStep.SET_PATHS:
			return true
		WizardStep.EXTRACT_ARCHIVES:
			return wizard_steps[0].is_valid  # Paths must be configured
		WizardStep.CREATE_MAPPING:
			return wizard_steps[0].is_valid and wizard_steps[1].is_completed  # Paths + extraction
		WizardStep.CONVERT_ASSETS:
			return wizard_steps[0].is_valid and wizard_steps[1].is_completed and wizard_steps[2].is_completed
		_:
			return false

func _update_step_display() -> void:
	"""Update step indicator and progress buttons."""
	if step_indicator:
		step_indicator.text = "Step %d of 4" % current_step
	
	# Update step button states
	if step1_button:
		step1_button.disabled = false
		step1_button.flat = current_step != WizardStep.SET_PATHS
	if step2_button:
		step2_button.disabled = not _is_step_accessible(WizardStep.EXTRACT_ARCHIVES)
		step2_button.flat = current_step != WizardStep.EXTRACT_ARCHIVES
	if step3_button:
		step3_button.disabled = not _is_step_accessible(WizardStep.CREATE_MAPPING)
		step3_button.flat = current_step != WizardStep.CREATE_MAPPING
	if step4_button:
		step4_button.disabled = not _is_step_accessible(WizardStep.CONVERT_ASSETS)
		step4_button.flat = current_step != WizardStep.CONVERT_ASSETS

func _update_navigation() -> void:
	"""Update navigation button states."""
	if back_button:
		back_button.disabled = current_step == WizardStep.SET_PATHS
	
	var current_step_valid = false
	if current_step <= wizard_steps.size():
		current_step_valid = wizard_steps[current_step - 1].is_valid
	
	var is_last_step = current_step == WizardStep.CONVERT_ASSETS
	if next_button:
		next_button.disabled = not current_step_valid or is_last_step
		next_button.text = "Finish" if is_last_step else "Next →"

func _get_step_title(step: WizardStep) -> String:
	"""Get display title for step."""
	match step:
		WizardStep.SET_PATHS:
			return "Configure Paths"
		WizardStep.EXTRACT_ARCHIVES:
			return "Extract Archives"
		WizardStep.CREATE_MAPPING:
			return "Create Mapping"
		WizardStep.CONVERT_ASSETS:
			return "Convert Assets"
		_:
			return "Unknown Step"

func _on_step_data_changed(data: Dictionary) -> void:
	"""Handle data changes from steps."""
	wizard_data.merge(data)

func _on_back_pressed() -> void:
	"""Handle back button press."""
	if is_exiting: return
	if current_step > WizardStep.SET_PATHS:
		_show_step(current_step - 1)

func _on_next_pressed() -> void:
	"""Handle next button press."""
	if is_exiting: return
	if current_step < WizardStep.CONVERT_ASSETS:
		_show_step(current_step + 1)
	else:
		# Finish wizard
		wizard_completed.emit()

func _on_step_completed() -> void:
	"""Handle step completion."""
	if is_exiting: return
	_update_step_display()
	_update_navigation()
	
	# Auto-advance to next step if available
	if current_step < WizardStep.CONVERT_ASSETS and _is_step_accessible(current_step + 1):
		await get_tree().create_timer(0.5).timeout  # Brief delay for user feedback
		if is_exiting: return # Check again after await
		_show_step(current_step + 1)

func _on_step_validation_changed(is_valid: bool) -> void:
	"""Handle step validation changes."""
	_update_step_display()
	_update_navigation()

func _on_status_message(message: String) -> void:
	"""Handle status messages from steps."""
	if status_label:
		status_label.text = message

func _exit_tree() -> void:
	is_exiting = true
	_save_config()
	
	# Disconnect signals to prevent errors on deactivation
	if back_button and is_instance_valid(back_button):
		back_button.pressed.disconnect(_on_back_pressed)
	if next_button and is_instance_valid(next_button):
		next_button.pressed.disconnect(_on_next_pressed)
		
	if step1_button and is_instance_valid(step1_button):
		step1_button.pressed.disconnect(_go_to_step)
	if step2_button and is_instance_valid(step2_button):
		step2_button.pressed.disconnect(_go_to_step)
	if step3_button and is_instance_valid(step3_button):
		step3_button.pressed.disconnect(_go_to_step)
	if step4_button and is_instance_valid(step4_button):
		step4_button.pressed.disconnect(_go_to_step)
		
	for step in wizard_steps:
		if step and is_instance_valid(step):
			step.step_completed.disconnect(_on_step_completed)
			step.step_validation_changed.disconnect(_on_step_validation_changed)
			step.status_message.disconnect(_on_status_message)
			step.data_changed.disconnect(_on_step_data_changed)

	# Clear arrays to break reference cycles and prevent memory leaks
	wizard_steps.clear()

func _save_config() -> void:
	var config = ConfigFile.new()
	config.set_value("wizard_data", "game_directory", wizard_data.get("game_directory", ""))
	config.set_value("wizard_data", "extraction_directory", wizard_data.get("extraction_directory", ""))
	config.set_value("wizard_data", "target_directory", wizard_data.get("target_directory", ""))
	config.set_value("wizard_data", "python_path", wizard_data.get("python_path", ""))
	config.save(CONFIG_FILE)

func _load_config() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_FILE)
	if err == OK:
		wizard_data.game_directory = config.get_value("wizard_data", "game_directory", "")
		wizard_data.extraction_directory = config.get_value("wizard_data", "extraction_directory", "")
		wizard_data.target_directory = config.get_value("wizard_data", "target_directory", "")
		wizard_data.python_path = config.get_value("wizard_data", "python_path", "")
