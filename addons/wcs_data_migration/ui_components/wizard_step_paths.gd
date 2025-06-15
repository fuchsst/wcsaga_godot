@tool
extends WizardStepBase
class_name WizardStepPaths

## Step 1: Set Source and Target Paths
## Configures WCS game directory, extraction directory, and target assets directory

# UI References - Using find_child for robust node access
var game_path: LineEdit
var game_path_browse: Button
var extraction_path: LineEdit
var extraction_path_browse: Button
var target_path: LineEdit
var target_path_browse: Button
var target_auto_detect: Button
var python_path: LineEdit
var python_path_browse: Button

# Validation state
var validation_timer: Timer
var auto_progression_enabled: bool = true

func _setup_step() -> void:
	step_number = 1
	step_title = "Configure Project Paths"
	step_description = "Set up source and target directories for WCS asset conversion"
	
	# Get UI nodes using find_child for robustness
	_get_ui_nodes()
	
	# Setup validation timer for debounced validation
	validation_timer = Timer.new()
	validation_timer.wait_time = 0.5
	validation_timer.one_shot = true
	validation_timer.timeout.connect(_validate_paths_debounced)
	add_child(validation_timer)
	
	_auto_detect_paths()
	_on_wizard_data_updated()

func _get_ui_nodes() -> void:
	"""Get UI nodes using find_child for robust access."""
	game_path = find_child("GamePath", true, false)
	game_path_browse = find_child("GamePathBrowse", true, false)
	extraction_path = find_child("ExtractionPath", true, false)
	extraction_path_browse = find_child("ExtractionPathBrowse", true, false)
	target_path = find_child("TargetPath", true, false)
	target_path_browse = find_child("TargetPathBrowse", true, false)
	target_auto_detect = find_child("TargetAutoDetect", true, false)
	python_path = find_child("PythonPath", true, false)
	python_path_browse = find_child("PythonPathBrowse", true, false)
	
	# Debug: Report any missing nodes
	if not game_path:
		print("WARNING: GamePath LineEdit not found")
	if not game_path_browse:
		print("WARNING: GamePathBrowse Button not found")
	if not extraction_path:
		print("WARNING: ExtractionPath LineEdit not found")
	if not extraction_path_browse:
		print("WARNING: ExtractionPathBrowse Button not found")
	if not target_path:
		print("WARNING: TargetPath LineEdit not found")
	if not target_path_browse:
		print("WARNING: TargetPathBrowse Button not found")
	if not target_auto_detect:
		print("WARNING: TargetAutoDetect Button not found")
	if not python_path:
		print("WARNING: PythonPath LineEdit not found")
	if not python_path_browse:
		print("WARNING: PythonPathBrowse Button not found")

func _connect_step_signals() -> void:
	if game_path_browse:
		game_path_browse.pressed.connect(_on_game_path_browse)
	if extraction_path_browse:
		extraction_path_browse.pressed.connect(_on_extraction_path_browse)
	if target_path_browse:
		target_path_browse.pressed.connect(_on_target_path_browse)
	if target_auto_detect:
		target_auto_detect.pressed.connect(_on_target_auto_detect)
	if python_path_browse:
		python_path_browse.pressed.connect(_on_python_path_browse)
	
	# Connect text changes with debounced validation
	if game_path:
		game_path.text_changed.connect(_on_path_changed)
	if extraction_path:
		extraction_path.text_changed.connect(_on_path_changed)
	if target_path:
		target_path.text_changed.connect(_on_path_changed)
	if python_path:
		python_path.text_changed.connect(_on_path_changed)

func _check_step_validity() -> bool:
	var game_dir_valid = _validate_game_directory()
	var extraction_dir_valid = _validate_extraction_directory()
	var target_dir_valid = _validate_target_directory()
	
	_update_field_visuals()
	
	return game_dir_valid and extraction_dir_valid and target_dir_valid

func _validate_game_directory() -> bool:
	if not game_path:
		return false
	
	if game_path.text.length() == 0:
		return false
	
	if not DirAccess.dir_exists_absolute(game_path.text):
		return false
	
	# Check for VP files to validate it's a WCS installation
	var dir = DirAccess.open(game_path.text)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".vp"):
				return true
			file_name = dir.get_next()
		dir.list_dir_end()
	
	return false

func _validate_extraction_directory() -> bool:
	if not extraction_path:
		return false
	
	if extraction_path.text.length() == 0:
		return false
	
	# Check if parent directory exists (we can create the extraction dir)
	var parent_dir = extraction_path.text.get_base_dir()
	return DirAccess.dir_exists_absolute(parent_dir) or parent_dir == ""

func _validate_target_directory() -> bool:
	if not target_path:
		return false
	
	if target_path.text.length() == 0:
		return false
	
	# Check if parent directory exists (we can create the target dir)
	var parent_dir = target_path.text.get_base_dir()
	return DirAccess.dir_exists_absolute(parent_dir) or parent_dir == ""

func _update_field_visuals() -> void:
	"""Update visual feedback for path validation."""
	var valid_color = Color(0.2, 0.5, 0.2, 1)
	var invalid_color = Color(0.5, 0.2, 0.2, 1)
	
	if game_path:
		game_path.right_icon = get_theme_icon("checked" if _validate_game_directory() else "error", "EditorIcons")
	if extraction_path:
		extraction_path.right_icon = get_theme_icon("checked" if _validate_extraction_directory() else "error", "EditorIcons")
	if target_path:
		target_path.right_icon = get_theme_icon("checked" if _validate_target_directory() else "error", "EditorIcons")

func _on_wizard_data_updated() -> void:
	if wizard_data.has("game_directory") and game_path:
		game_path.text = wizard_data.game_directory
	if wizard_data.has("extraction_directory") and extraction_path:
		extraction_path.text = wizard_data.extraction_directory
	if wizard_data.has("target_directory") and target_path:
		target_path.text = wizard_data.target_directory
	if wizard_data.has("python_path") and python_path:
		python_path.text = wizard_data.python_path
	
	_validate_step()

func _auto_detect_paths() -> void:
	"""Auto-detect common paths with intelligent defaults, respecting existing data."""
	var project_path = ProjectSettings.globalize_path("res://")
	
	# Auto-detect WCS game directory only if not already set
	_auto_detect_wcs_installation()
	
	# Set intelligent target path if not already set
	if wizard_data.get("target_directory", "") == "":
		var campaign_assets_path = project_path.path_join("assets/campaigns/wing_commander_saga/")
		if target_path:
			target_path.text = campaign_assets_path
		wizard_data.target_directory = campaign_assets_path
		
		# Create target directory if it doesn't exist
		if not DirAccess.dir_exists_absolute(campaign_assets_path):
			DirAccess.make_dir_recursive_absolute(campaign_assets_path)
	
	# Set temporary extraction path if not already set
	if wizard_data.get("extraction_directory", "") == "":
		var temp_extraction = project_path.path_join("temp_wcs_extraction/")
		if extraction_path:
			extraction_path.text = temp_extraction
		wizard_data.extraction_directory = temp_extraction

func _auto_detect_wcs_installation() -> void:
	"""Try to auto-detect WCS installation directory if not already set."""
	if wizard_data.get("game_directory", "") != "" and DirAccess.dir_exists_absolute(wizard_data.get("game_directory")):
		return  # Don't auto-detect if already set and valid

	var potential_wcs_paths = [
		"C:/Games/WingCommanderSaga/",
		"C:/Program Files/WingCommanderSaga/",
		"C:/Program Files (x86)/WingCommanderSaga/",
		OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("My Games/WCS/"),
		OS.get_environment("USERPROFILE").path_join("Games/WCS/"),
		"/opt/wcs/",  # Linux
		"/usr/local/games/wcs/",  # Linux
		OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("WCS/")  # General documents
	]
	
	for path in potential_wcs_paths:
		if _validate_wcs_directory(path):
			if game_path:
				game_path.text = path
			wizard_data.game_directory = path
			return  # Found one, so we stop

func _validate_wcs_directory(path: String) -> bool:
	"""Check if directory contains WCS VP files."""
	if not DirAccess.dir_exists_absolute(path):
		return false
	
	var dir = DirAccess.open(path)
	if not dir:
		return false
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".vp"):
			dir.list_dir_end()
			return true
		file_name = dir.get_next()
	dir.list_dir_end()
	
	return false

func _get_initial_dialog_path(path_text: String) -> String:
	if path_text.is_empty():
		return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	
	if DirAccess.dir_exists_absolute(path_text):
		return path_text
	
	var base_dir = path_text.get_base_dir()
	if DirAccess.dir_exists_absolute(base_dir):
		return base_dir
		
	return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)

func _on_game_path_browse() -> void:
	if not game_path:
		return
		
	var file_dialog = FileDialog.new()
	add_child(file_dialog)
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.current_dir = _get_initial_dialog_path(game_path.text)
	file_dialog.popup_centered(Vector2i(800, 600))
	
	var dir = await file_dialog.dir_selected
	if dir and dir.length() > 0:
		game_path.text = dir
		_on_path_changed("")
	
	file_dialog.queue_free()

func _on_extraction_path_browse() -> void:
	if not extraction_path:
		return
		
	var file_dialog = FileDialog.new()
	add_child(file_dialog)
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.current_dir = _get_initial_dialog_path(extraction_path.text)
	file_dialog.popup_centered(Vector2i(800, 600))
	
	var dir = await file_dialog.dir_selected
	if dir and dir.length() > 0:
		extraction_path.text = dir
		_on_path_changed("")
	
	file_dialog.queue_free()

func _on_target_path_browse() -> void:
	if not target_path:
		return
		
	var file_dialog = FileDialog.new()
	add_child(file_dialog)
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.current_dir = _get_initial_dialog_path(target_path.text)
	file_dialog.popup_centered(Vector2i(800, 600))
	
	var dir = await file_dialog.dir_selected
	if dir and dir.length() > 0:
		target_path.text = dir
		_on_path_changed("")
	
	file_dialog.queue_free()

func _on_python_path_browse() -> void:
	if not python_path:
		return
		
	var file_dialog = FileDialog.new()
	add_child(file_dialog)
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.exe", "Executables")
	file_dialog.add_filter("*", "All Files")
	file_dialog.current_dir = _get_initial_dialog_path(python_path.text)
	file_dialog.popup_centered(Vector2i(800, 600))
	
	var file = await file_dialog.file_selected
	if file and file.length() > 0:
		python_path.text = file
		_on_path_changed("")
	
	file_dialog.queue_free()

func _on_target_auto_detect() -> void:
	_auto_detect_paths()
	_validate_step()
	_emit_status("Auto-detected paths")

func _validate_paths_debounced() -> void:
	"""Perform validation after debounce delay."""
	_validate_step()
	_update_status_message()
	
	# Complete step if valid
	if is_valid:
		complete_step()
		_emit_status("✅ Paths configured! Click 'Next' to continue.")
	
	# Disable auto-progression
	auto_progression_enabled = false

func _update_status_message() -> void:
	"""Update status message based on validation state."""
	if is_valid:
		_emit_status("✅ All paths configured and validated")
	else:
		var issues: Array[String] = []
		
		if not _validate_game_directory():
			if not game_path or game_path.text.length() == 0:
				issues.append("WCS game directory required")
			elif not DirAccess.dir_exists_absolute(game_path.text):
				issues.append("WCS directory does not exist")
			else:
				issues.append("No VP files found (not a valid WCS installation)")
		
		if not _validate_extraction_directory():
			issues.append("Extraction directory path invalid")
		
		if not _validate_target_directory():
			issues.append("Target directory path invalid")
		
		_emit_status("⚠️ " + issues[0] if issues.size() > 0 else "Please configure paths")

func _on_path_changed(_text: String) -> void:
	# Update wizard data immediately (with null checks)
	if game_path:
		wizard_data.game_directory = game_path.text
	if extraction_path:
		wizard_data.extraction_directory = extraction_path.text
	if target_path:
		wizard_data.target_directory = target_path.text
	if python_path:
		wizard_data.python_path = python_path.text
	
	# Restart debounce timer for validation
	validation_timer.stop()
	validation_timer.start()
	
	data_changed.emit(wizard_data)
