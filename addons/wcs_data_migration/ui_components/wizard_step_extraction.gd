@tool
extends WizardStepBase
class_name WizardStepExtraction

## Step 2: Extract VP Archives
## Scans for VP archive files and extracts them to access campaign assets

# UI References
@onready var vp_files_list: ItemList = $ExtractionContainer/ScanSection/VPFilesList
@onready var scan_vp_button: Button = $ExtractionContainer/ControlsSection/ExtractionControls/ScanVPButton
@onready var extract_selected_button: Button = $ExtractionContainer/ControlsSection/ExtractionControls/ExtractSelectedButton
@onready var extract_all_button: Button = $ExtractionContainer/ControlsSection/ExtractionControls/ExtractAllButton
@onready var extraction_progress: ProgressBar = $ExtractionContainer/ControlsSection/ExtractionProgress

# State
var vp_files: Array[String] = []
var extraction_in_progress: bool = false

func _setup_step() -> void:
	step_number = 2
	step_title = "Extract VP Archives"
	step_description = "Scan for VP archive files and extract them to access campaign assets."

func _connect_step_signals() -> void:
	scan_vp_button.pressed.connect(_on_scan_vp_pressed)
	extract_selected_button.pressed.connect(_on_extract_selected_pressed)
	extract_all_button.pressed.connect(_on_extract_all_pressed)
	vp_files_list.item_selected.connect(_on_vp_item_selected)

func _check_step_validity() -> bool:
	return wizard_data.has("vp_files") and wizard_data.vp_files.size() > 0

func _on_step_activated() -> void:
	if wizard_data.has("game_directory") and wizard_data.game_directory.length() > 0:
		_auto_scan_vp_files()

func _on_wizard_data_updated() -> void:
	if wizard_data.has("vp_files"):
		_update_vp_files_display()

func _auto_scan_vp_files() -> void:
	"""Automatically scan for VP files when step is activated."""
	if wizard_data.has("game_directory"):
		_scan_vp_files(wizard_data.game_directory)

func _scan_vp_files(directory: String) -> void:
	"""Scan directory for VP files."""
	_emit_status("Scanning for VP files...")
	vp_files.clear()
	vp_files_list.clear()
	
	if not DirAccess.dir_exists_absolute(directory):
		_emit_status("Invalid game directory")
		return
	
	var dir = DirAccess.open(directory)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".vp"):
				vp_files.append(directory + "/" + file_name)
				vp_files_list.add_item(file_name)
			file_name = dir.get_next()
		
		dir.list_dir_end()
	
	wizard_data.vp_files = vp_files
	_validate_step()
	
	var count = vp_files.size()
	_emit_status("Found %d VP files" % count)
	
	# Enable extraction buttons if VP files found
	extract_selected_button.disabled = count == 0
	extract_all_button.disabled = count == 0

func _update_vp_files_display() -> void:
	"""Update VP files list display."""
	vp_files_list.clear()
	for vp_file in wizard_data.vp_files:
		var file_name = vp_file.get_file()
		vp_files_list.add_item(file_name)

func _extract_vp_files(file_paths: Array[String]) -> void:
	"""Extract specified VP files."""
	if extraction_in_progress:
		_emit_status("Extraction already in progress")
		return
	
	if not wizard_data.has("extraction_directory"):
		_emit_status("Extraction directory not configured")
		return
	
	extraction_in_progress = true
	extraction_progress.visible = true
	extraction_progress.value = 0
	
	_emit_status("Extracting VP files...")
	
	# Ensure extraction directory exists
	var extraction_dir = wizard_data.extraction_directory
	if not DirAccess.dir_exists_absolute(extraction_dir):
		DirAccess.make_dir_absolute(extraction_dir)
	
	# Extract files using Python script
	var python_path = ProjectSettings.globalize_path("res://venv/Scripts/python.exe")
	var extractor_script = ProjectSettings.globalize_path("res://addons/wcs_data_migration/tools/vp_extractor.py")
	
	var total_files = file_paths.size()
	for i in range(total_files):
		var vp_file = file_paths[i]
		_emit_status("Extracting %s..." % vp_file.get_file())
		
		var args = [extractor_script, vp_file, extraction_dir]
		var output = []
		var result = OS.execute(python_path, args, output)
		
		if result != 0:
			_emit_status("Failed to extract %s" % vp_file.get_file())
		
		extraction_progress.value = float(i + 1) / total_files * 100
		await get_tree().process_frame
	
	extraction_in_progress = false
	extraction_progress.visible = false
	
	# Mark step as completed if any extractions succeeded
	if DirAccess.dir_exists_absolute(extraction_dir):
		var dir = DirAccess.open(extraction_dir)
		if dir and dir.get_directories().size() > 0:
			complete_step()
			_emit_status("VP extraction completed successfully")
		else:
			_emit_status("Extraction failed - no files extracted")
	else:
		_emit_status("Extraction failed - directory not created")

func _on_scan_vp_pressed() -> void:
	if wizard_data.has("game_directory"):
		_scan_vp_files(wizard_data.game_directory)
	else:
		_emit_status("Please configure game directory first")

func _on_extract_selected_pressed() -> void:
	var selected_indices = []
	for i in range(vp_files_list.item_count):
		if vp_files_list.is_selected(i):
			selected_indices.append(i)
	
	if selected_indices.size() == 0:
		_emit_status("Please select VP files to extract")
		return
	
	var selected_files: Array[String] = []
	for index in selected_indices:
		selected_files.append(vp_files[index])
	
	_extract_vp_files(selected_files)

func _on_extract_all_pressed() -> void:
	if vp_files.size() == 0:
		_emit_status("No VP files found")
		return
	
	_extract_vp_files(vp_files)

func _on_vp_item_selected(_index: int) -> void:
	extract_selected_button.disabled = false
