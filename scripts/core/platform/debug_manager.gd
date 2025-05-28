class_name DebugManager
extends RefCounted

## Cross-platform debug output system replacing WCS outwnd functionality.
## Routes debug messages to Godot's print functions with proper log levels and filtering.
## Provides WCS-compatible API while leveraging Godot's built-in debugging capabilities.

const WCSConstants = preload("res://scripts/core/foundation/wcs_constants.gd")
const PlatformUtils = preload("res://scripts/core/platform/platform_utils.gd")

## Debug output levels matching WCS outwnd system
enum LogLevel {
	TRACE = 0,      ## Detailed execution tracing
	DEBUG = 1,      ## Debug information for developers
	INFO = 2,       ## General informational messages
	WARNING = 3,    ## Warning messages for potential issues
	ERROR = 4,      ## Error messages for failures
	CRITICAL = 5    ## Critical errors that may crash the application
}

## Debug categories matching WCS outwnd filters
enum Category {
	GENERAL = 0,    ## General system messages
	PHYSICS = 1,    ## Physics simulation and collision
	AI = 2,         ## AI behavior and decision making
	GRAPHICS = 3,   ## Rendering and graphics operations
	SOUND = 4,      ## Audio system and sound effects
	NETWORK = 5,    ## Networking and multiplayer
	INPUT = 6,      ## Input processing and controls
	FILE_IO = 7,    ## File operations and data loading
	SCRIPT = 8,     ## Scripting and mission events
	PERFORMANCE = 9 ## Performance metrics and profiling
}

## Debug output configuration
static var _log_level: LogLevel = LogLevel.INFO
static var _enabled_categories: Array[bool] = []
static var _output_to_file: bool = false
static var _log_file_path: String = "user://debug_log.txt"
static var _log_file: FileAccess
static var _is_initialized: bool = false
static var _message_buffer: Array[Dictionary] = []
static var _max_buffer_size: int = 1000

## Category names for display and configuration
static var _category_names: PackedStringArray = [
	"General", "Physics", "AI", "Graphics", "Sound", 
	"Network", "Input", "FileIO", "Script", "Performance"
]

## Log level names for display
static var _level_names: PackedStringArray = [
	"TRACE", "DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"
]

## Initialize the debug system
static func initialize(enable_file_logging: bool = false, log_file_path: String = "") -> bool:
	if _is_initialized:
		return true
	
	# Initialize category filters (all enabled by default)
	_enabled_categories.resize(Category.size())
	for i: int in range(Category.size()):
		_enabled_categories[i] = true
	
	# Set up file logging if requested
	_output_to_file = enable_file_logging
	if not log_file_path.is_empty():
		_log_file_path = log_file_path
	
	if _output_to_file:
		var success: bool = _open_log_file()
		if success:
			_write_to_file("DebugManager: File logging initialized - %s" % _log_file_path)
		else:
			push_error("DebugManager: Failed to initialize file logging")
			_output_to_file = false
	
	_is_initialized = true
	print("DebugManager: Initialized successfully (file_logging=%s)" % str(_output_to_file))
	
	# Log system information
	log_info(Category.GENERAL, "Platform: %s" % PlatformUtils.get_os_name())
	log_info(Category.GENERAL, "Processor: %s (%d cores)" % [PlatformUtils.get_processor_info()["name"], PlatformUtils.get_processor_info()["count"]])
	log_info(Category.GENERAL, "Memory: %d MB" % PlatformUtils.get_system_memory_mb())
	
	return true

## Shutdown the debug system
static func shutdown() -> void:
	if not _is_initialized:
		return
	
	log_info(Category.GENERAL, "DebugManager: Shutting down...")
	
	if _output_to_file and _log_file != null:
		_write_to_file("DebugManager: Shutdown completed")
		_log_file.close()
		_log_file = null
	
	_message_buffer.clear()
	_is_initialized = false
	print("DebugManager: Shutdown completed")

## Open log file for writing
static func _open_log_file() -> bool:
	if _log_file != null:
		_log_file.close()
	
	_log_file = FileAccess.open(_log_file_path, FileAccess.WRITE)
	if _log_file == null:
		push_error("DebugManager: Failed to open log file: %s" % _log_file_path)
		return false
	
	# Write header information
	_log_file.store_line("=== WCS-Godot Debug Log ===")
	_log_file.store_line("Started: %s" % Time.get_datetime_string_from_system())
	_log_file.store_line("Platform: %s" % OS.get_name())
	_log_file.store_line("Godot Version: %s" % Engine.get_version_info()["string"])
	_log_file.store_line("=======================================")
	_log_file.flush()
	
	return true

## Write message to log file
static func _write_to_file(message: String) -> void:
	if _log_file == null:
		return
	
	var timestamp: String = Time.get_datetime_string_from_system()
	_log_file.store_line("[%s] %s" % [timestamp, message])
	_log_file.flush()

## Core logging function with level and category filtering
static func log_message(level: LogLevel, category: Category, message: String) -> void:
	if not _is_initialized:
		_ensure_initialized()
	
	# Check log level filter
	if level < _log_level:
		return
	
	# Check category filter
	if category >= 0 and category < _enabled_categories.size():
		if not _enabled_categories[category]:
			return
	
	# Format message with metadata
	var level_name: String = _level_names[level] if level < _level_names.size() else "UNKNOWN"
	var category_name: String = _category_names[category] if category < _category_names.size() else "UNKNOWN"
	var formatted_message: String = "[%s:%s] %s" % [level_name, category_name, message]
	
	# Output to Godot console based on level
	match level:
		LogLevel.TRACE, LogLevel.DEBUG, LogLevel.INFO:
			print(formatted_message)
		LogLevel.WARNING:
			push_warning(formatted_message)
		LogLevel.ERROR, LogLevel.CRITICAL:
			push_error(formatted_message)
	
	# Store in message buffer
	_add_to_buffer(level, category, message, formatted_message)
	
	# Write to file if enabled
	if _output_to_file:
		_write_to_file(formatted_message)

## Ensure debug system is initialized with defaults
static func _ensure_initialized() -> void:
	if not _is_initialized:
		initialize(false)

## Add message to circular buffer for debugging UI
static func _add_to_buffer(level: LogLevel, category: Category, message: String, formatted_message: String) -> void:
	var entry: Dictionary = {
		"timestamp": Time.get_unix_time_from_system(),
		"level": level,
		"category": category,
		"message": message,
		"formatted": formatted_message
	}
	
	_message_buffer.append(entry)
	
	# Maintain buffer size limit
	if _message_buffer.size() > _max_buffer_size:
		_message_buffer.pop_front()

## Convenience functions for different log levels

## Log trace message (most verbose)
static func log_trace(category: Category, message: String) -> void:
	log_message(LogLevel.TRACE, category, message)

## Log debug message
static func log_debug(category: Category, message: String) -> void:
	log_message(LogLevel.DEBUG, category, message)

## Log info message
static func log_info(category: Category, message: String) -> void:
	log_message(LogLevel.INFO, category, message)

## Log warning message
static func log_warning(category: Category, message: String) -> void:
	log_message(LogLevel.WARNING, category, message)

## Log error message
static func log_error(category: Category, message: String) -> void:
	log_message(LogLevel.ERROR, category, message)

## Log critical error message
static func log_critical(category: Category, message: String) -> void:
	log_message(LogLevel.CRITICAL, category, message)

## WCS-compatible functions matching outwnd API

## WCS outwnd_printf replacement - general debug output
static func outwnd_printf(id: String = "", format: String = "", args: Array = []) -> void:
	if not _is_initialized:
		_ensure_initialized()
	
	var message: String
	if args.is_empty():
		message = format
	else:
		message = format % args
	
	# Map WCS debug IDs to categories
	var category: Category = _map_wcs_id_to_category(id)
	log_debug(category, message)

## WCS outwnd_printf2 replacement - formatted debug output
static func outwnd_printf2(format: String = "", args: Array = []) -> void:
	outwnd_printf("", format, args)

## Map WCS debug output IDs to debug categories
static func _map_wcs_id_to_category(id: String) -> Category:
	match id.to_lower():
		"general", "":
			return Category.GENERAL
		"physics", "phys":
			return Category.PHYSICS
		"ai", "artificial":
			return Category.AI
		"graphics", "gfx", "render":
			return Category.GRAPHICS
		"sound", "audio", "snd":
			return Category.SOUND
		"network", "net", "multi":
			return Category.NETWORK
		"input", "controls":
			return Category.INPUT
		"file", "io", "cfile":
			return Category.FILE_IO
		"script", "sexp", "mission":
			return Category.SCRIPT
		"performance", "perf", "profile":
			return Category.PERFORMANCE
		_:
			return Category.GENERAL

## Performance logging with timing
static func log_performance(category: Category, operation: String, start_time: float) -> void:
	var duration: float = Time.get_ticks_msec() / 1000.0 - start_time
	log_message(LogLevel.INFO, category, "%s completed in %.3f seconds" % [operation, duration])

## Log performance timing for a code block
static func time_operation(category: Category, operation_name: String, callable: Callable) -> Variant:
	var start_time: float = Time.get_ticks_msec() / 1000.0
	var result: Variant = callable.call()
	log_performance(category, operation_name, start_time)
	return result

## Configuration functions

## Set minimum log level for filtering
static func set_log_level(level: LogLevel) -> void:
	_log_level = level
	log_info(Category.GENERAL, "Log level changed to: %s" % _level_names[level])

## Get current log level
static func get_log_level() -> LogLevel:
	return _log_level

## Enable or disable a debug category
static func set_category_enabled(category: Category, enabled: bool) -> void:
	if category >= 0 and category < _enabled_categories.size():
		_enabled_categories[category] = enabled
		var category_name: String = _category_names[category] if category < _category_names.size() else "Unknown"
		log_info(Category.GENERAL, "Category '%s' %s" % [category_name, "enabled" if enabled else "disabled"])

## Check if a debug category is enabled
static func is_category_enabled(category: Category) -> bool:
	if category >= 0 and category < _enabled_categories.size():
		return _enabled_categories[category]
	return false

## Enable file logging
static func enable_file_logging(log_file_path: String = "") -> bool:
	if not log_file_path.is_empty():
		_log_file_path = log_file_path
	
	if _output_to_file:
		return true  # Already enabled
	
	_output_to_file = true
	var success: bool = _open_log_file()
	if success:
		log_info(Category.GENERAL, "File logging enabled: %s" % _log_file_path)
	else:
		_output_to_file = false
		log_error(Category.GENERAL, "Failed to enable file logging")
	
	return success

## Disable file logging
static func disable_file_logging() -> void:
	if not _output_to_file:
		return
	
	log_info(Category.GENERAL, "File logging disabled")
	
	if _log_file != null:
		_log_file.close()
		_log_file = null
	
	_output_to_file = false

## Get recent debug messages from buffer
static func get_recent_messages(count: int = 100) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start_index: int = max(0, _message_buffer.size() - count)
	
	for i: int in range(start_index, _message_buffer.size()):
		result.append(_message_buffer[i])
	
	return result

## Get messages filtered by level and category
static func get_filtered_messages(min_level: LogLevel = LogLevel.TRACE, category: Category = Category.GENERAL, count: int = 100) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var added: int = 0
	
	# Iterate from newest to oldest
	for i: int in range(_message_buffer.size() - 1, -1, -1):
		if added >= count:
			break
		
		var entry: Dictionary = _message_buffer[i]
		var entry_level: LogLevel = entry.get("level", LogLevel.INFO)
		var entry_category: Category = entry.get("category", Category.GENERAL)
		
		if entry_level >= min_level and (category == Category.GENERAL or entry_category == category):
			result.push_front(entry)  # Add to front to maintain chronological order
			added += 1
	
	return result

## Clear message buffer
static func clear_message_buffer() -> void:
	_message_buffer.clear()
	log_info(Category.GENERAL, "Debug message buffer cleared")

## Get debug system statistics
static func get_debug_stats() -> Dictionary:
	return {
		"initialized": _is_initialized,
		"log_level": _log_level,
		"log_level_name": _level_names[_log_level] if _log_level < _level_names.size() else "Unknown",
		"file_logging": _output_to_file,
		"log_file_path": _log_file_path if _output_to_file else "",
		"buffer_size": _message_buffer.size(),
		"max_buffer_size": _max_buffer_size,
		"categories_enabled": _enabled_categories.size(),
		"total_categories": Category.size()
	}

## Dump system configuration to debug output
static func dump_config() -> void:
	log_info(Category.GENERAL, "=== Debug System Configuration ===")
	var stats: Dictionary = get_debug_stats()
	for key: String in stats:
		log_info(Category.GENERAL, "%s: %s" % [key, str(stats[key])])
	
	log_info(Category.GENERAL, "Category States:")
	for i: int in range(_category_names.size()):
		var enabled: bool = _enabled_categories[i] if i < _enabled_categories.size() else false
		log_info(Category.GENERAL, "  %s: %s" % [_category_names[i], "enabled" if enabled else "disabled"])
	
	log_info(Category.GENERAL, "=== End Configuration ===")

## Load debug configuration from settings
static func load_config_from_settings(settings_manager: SettingsManager) -> void:
	if not _is_initialized:
		_ensure_initialized()
	
	# Load log level
	var level_value: int = settings_manager.os_config_read_uint("Debug", "log_level", LogLevel.INFO)
	if level_value >= 0 and level_value < LogLevel.size():
		set_log_level(level_value)
	
	# Load file logging setting
	var file_logging: bool = settings_manager.os_config_read_uint("Debug", "file_logging", 0) > 0
	var log_path: String = settings_manager.os_config_read_string("Debug", "log_file_path", _log_file_path)
	
	if file_logging:
		enable_file_logging(log_path)
	else:
		disable_file_logging()
	
	# Load category states
	for i: int in range(_category_names.size()):
		var category_key: String = "category_" + _category_names[i].to_lower()
		var enabled: bool = settings_manager.os_config_read_uint("Debug", category_key, 1) > 0
		set_category_enabled(i, enabled)
	
	log_info(Category.GENERAL, "Debug configuration loaded from settings")

## Save debug configuration to settings
static func save_config_to_settings(settings_manager: SettingsManager) -> void:
	if not _is_initialized:
		return
	
	# Save log level
	settings_manager.os_config_write_uint("Debug", "log_level", _log_level)
	
	# Save file logging settings
	settings_manager.os_config_write_uint("Debug", "file_logging", 1 if _output_to_file else 0)
	settings_manager.os_config_write_string("Debug", "log_file_path", _log_file_path)
	
	# Save category states
	for i: int in range(_category_names.size()):
		var category_key: String = "category_" + _category_names[i].to_lower()
		var enabled: bool = _enabled_categories[i] if i < _enabled_categories.size() else true
		settings_manager.os_config_write_uint("Debug", category_key, 1 if enabled else 0)
	
	log_info(Category.GENERAL, "Debug configuration saved to settings")