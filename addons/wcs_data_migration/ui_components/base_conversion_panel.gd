@tool
extends Control
class_name BaseConversionPanel

## Base class for conversion UI panels
## Implements common functionality following Single Responsibility Principle

signal conversion_started(conversion_type: String)
signal conversion_completed(conversion_type: String, success: bool)
signal status_updated(message: String)

var python_exe_path: String
var conversion_script_path: String

func _ready() -> void:
	_initialize_panel()
	_setup_ui_components()
	_connect_panel_signals()

func _initialize_panel() -> void:
	"""Initialize panel-specific settings - override in subclasses"""
	pass

func _setup_ui_components() -> void:
	"""Setup UI components - override in subclasses"""
	pass

func _connect_panel_signals() -> void:
	"""Connect signals - override in subclasses"""
	pass

func get_python_executable() -> String:
	"""Get the Python executable path for conversion tools"""
	var possible_paths: PackedStringArray = PackedStringArray([
		"/mnt/d/projects/wcsaga_godot_converter/target/venv/Scripts/python.exe",
		"/mnt/d/projects/wcsaga_godot_converter/target/venv/bin/python",
		"python",
		"python3"
	])
	
	for path in possible_paths:
		if FileAccess.file_exists(path) or _check_command_exists(path):
			return path
	
	return "python"

func _check_command_exists(command: String) -> bool:
	"""Check if a command exists in the system PATH"""
	var output: Array = []
	var result: int = OS.execute("which", [command], output, true)
	return result == 0

func execute_conversion_command(args: PackedStringArray) -> bool:
	"""Execute a conversion command with proper error handling"""
	var python_exe: String = get_python_executable()
	var output: Array = []
	var result: int = OS.execute(python_exe, args, output, true)
	
	if result != 0:
		var error_msg: String = "Conversion failed: " + str(result)
		_emit_status(error_msg)
		return false
	
	return true

func _emit_status(message: String) -> void:
	"""Emit status update"""
	status_updated.emit(message)

func _emit_conversion_started(type: String) -> void:
	"""Emit conversion started signal"""
	conversion_started.emit(type)

func _emit_conversion_completed(type: String, success: bool) -> void:
	"""Emit conversion completed signal"""
	conversion_completed.emit(type, success)

func show_file_dialog(mode: EditorFileDialog.FileMode, filters: PackedStringArray, callback: Callable) -> void:
	"""Show a file dialog with the specified parameters"""
	var file_dialog: EditorFileDialog = EditorFileDialog.new()
	file_dialog.file_mode = mode
	
	for filter in filters:
		var parts: PackedStringArray = filter.split(";")
		if parts.size() == 2:
			file_dialog.add_filter(parts[0], parts[1])
	
	file_dialog.current_dir = "res://"
	
	add_child(file_dialog)
	
	# Connect appropriate signal based on mode
	if mode == EditorFileDialog.FILE_MODE_OPEN_FILE:
		file_dialog.file_selected.connect(callback)
	elif mode == EditorFileDialog.FILE_MODE_OPEN_DIR:
		file_dialog.dir_selected.connect(callback)
	
	file_dialog.popup_centered(Vector2i(800, 600))

func cleanup_dialog(dialog: EditorFileDialog) -> void:
	"""Clean up file dialog after use"""
	if dialog and dialog.get_parent():
		dialog.queue_free()
