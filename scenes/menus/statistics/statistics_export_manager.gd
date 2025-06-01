class_name StatisticsExportManager
extends Node

## Statistics export and import manager for pilot data sharing and backup.
## Provides comprehensive export functionality with multiple formats and import validation.
## Supports statistics backup, sharing, and migration between game instances.

signal export_completed(file_path: String, format: ExportFormat)
signal export_failed(error_message: String, format: ExportFormat)
signal import_completed(file_path: String, statistics: Dictionary)
signal import_failed(error_message: String, file_path: String)

# Export formats
enum ExportFormat {
	JSON,           # Human-readable JSON format
	CSV,            # Comma-separated values for spreadsheet analysis
	XML,            # XML format for structured data
	BINARY,         # Compact binary format for game saves
	HUMAN_READABLE  # Text format optimized for readability
}

# Export configuration
@export var default_export_directory: String = "user://exports/"
@export var include_detailed_breakdowns: bool = true
@export var include_historical_data: bool = true
@export var include_medal_progress: bool = true
@export var include_rank_progression: bool = true

# Import configuration
@export var validate_imported_data: bool = true
@export var allow_partial_imports: bool = true
@export var backup_before_import: bool = true

# Security and validation
@export var require_export_signature: bool = false
@export var validate_data_integrity: bool = true
@export var max_import_file_size: int = 10485760  # 10MB

# Performance settings
@export var export_chunk_size: int = 1000
@export var async_export_threshold: int = 5000

func _ready() -> void:
	"""Initialize statistics export manager."""
	_ensure_export_directory()

func _ensure_export_directory() -> void:
	"""Ensure export directory exists."""
	var dir: DirAccess = DirAccess.open("user://")
	if not dir.dir_exists("exports"):
		dir.make_dir("exports")

# ============================================================================
# EXPORT FUNCTIONALITY
# ============================================================================

func export_pilot_statistics(pilot_stats: PilotStatistics, earned_medals: Array[String], 
							  export_format: ExportFormat = ExportFormat.JSON) -> String:
	"""Export pilot statistics to specified format."""
	if not pilot_stats:
		export_failed.emit("No pilot statistics provided", export_format)
		return ""
	
	# Generate timestamp for filename
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var filename: String = "pilot_stats_%s" % timestamp
	
	# Add appropriate extension
	match export_format:
		ExportFormat.JSON:
			filename += ".json"
		ExportFormat.CSV:
			filename += ".csv"
		ExportFormat.XML:
			filename += ".xml"
		ExportFormat.BINARY:
			filename += ".dat"
		ExportFormat.HUMAN_READABLE:
			filename += ".txt"
	
	var file_path: String = default_export_directory + filename
	
	# Perform export based on format
	var success: bool = false
	match export_format:
		ExportFormat.JSON:
			success = _export_to_json(pilot_stats, earned_medals, file_path)
		ExportFormat.CSV:
			success = _export_to_csv(pilot_stats, earned_medals, file_path)
		ExportFormat.XML:
			success = _export_to_xml(pilot_stats, earned_medals, file_path)
		ExportFormat.BINARY:
			success = _export_to_binary(pilot_stats, earned_medals, file_path)
		ExportFormat.HUMAN_READABLE:
			success = _export_to_text(pilot_stats, earned_medals, file_path)
	
	if success:
		export_completed.emit(file_path, export_format)
	else:
		export_failed.emit("Export operation failed", export_format)
	
	return file_path if success else ""

func export_comprehensive_report(statistics_manager: StatisticsDataManager, 
								 export_format: ExportFormat = ExportFormat.JSON) -> String:
	"""Export comprehensive statistics report with all data."""
	if not statistics_manager or not statistics_manager.get_current_statistics():
		export_failed.emit("No statistics manager or current statistics", export_format)
		return ""
	
	var comprehensive_stats: Dictionary = statistics_manager.get_comprehensive_statistics()
	
	# Generate timestamp for filename
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var filename: String = "comprehensive_report_%s" % timestamp
	
	# Add appropriate extension
	match export_format:
		ExportFormat.JSON:
			filename += ".json"
		ExportFormat.XML:
			filename += ".xml"
		ExportFormat.HUMAN_READABLE:
			filename += ".txt"
		_:
			# For other formats, use JSON as fallback
			filename += ".json"
			export_format = ExportFormat.JSON
	
	var file_path: String = default_export_directory + filename
	
	# Perform export
	var success: bool = false
	match export_format:
		ExportFormat.JSON:
			success = _export_comprehensive_json(comprehensive_stats, file_path)
		ExportFormat.XML:
			success = _export_comprehensive_xml(comprehensive_stats, file_path)
		ExportFormat.HUMAN_READABLE:
			success = _export_comprehensive_text(comprehensive_stats, file_path)
	
	if success:
		export_completed.emit(file_path, export_format)
	else:
		export_failed.emit("Comprehensive export failed", export_format)
	
	return file_path if success else ""

# ============================================================================
# FORMAT-SPECIFIC EXPORT METHODS
# ============================================================================

func _export_to_json(pilot_stats: PilotStatistics, earned_medals: Array[String], file_path: String) -> bool:
	"""Export statistics to JSON format."""
	var export_data: Dictionary = {
		"format_version": "1.0",
		"export_timestamp": Time.get_unix_time_from_system(),
		"pilot_statistics": _serialize_pilot_statistics(pilot_stats),
		"earned_medals": earned_medals,
		"metadata": {
			"game_version": "WCS-Godot 1.0",
			"exporter": "StatisticsExportManager",
			"format": "JSON"
		}
	}
	
	# Add optional data sections
	if include_detailed_breakdowns:
		export_data["detailed_breakdowns"] = _create_detailed_breakdowns(pilot_stats)
	
	if include_medal_progress:
		export_data["medal_progress"] = _create_medal_progress_data(pilot_stats, earned_medals)
	
	if include_rank_progression:
		export_data["rank_progression"] = _create_rank_progression_data(pilot_stats)
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false
	
	file.store_string(JSON.stringify(export_data, "\t"))
	file.close()
	return true

func _export_to_csv(pilot_stats: PilotStatistics, earned_medals: Array[String], file_path: String) -> bool:
	"""Export statistics to CSV format for spreadsheet analysis."""
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false
	
	# CSV header
	file.store_line("Category,Statistic,Value,Description")
	
	# Basic statistics
	file.store_line("Basic,Score,%d,Total mission score" % pilot_stats.score)
	file.store_line("Basic,Rank,%d,Current rank index" % pilot_stats.rank)
	file.store_line("Basic,Missions Flown,%d,Total missions completed" % pilot_stats.missions_flown)
	file.store_line("Basic,Flight Time,%d,Total flight time in seconds" % pilot_stats.flight_time)
	file.store_line("Basic,Total Kills,%d,Total confirmed kills" % pilot_stats.kill_count)
	file.store_line("Basic,Valid Kills,%d,Valid kills for statistics" % pilot_stats.kill_count_ok)
	file.store_line("Basic,Assists,%d,Total assists" % pilot_stats.assists)
	
	# Weapon statistics
	file.store_line("Weapons,Primary Shots Fired,%d,Primary weapon shots fired" % pilot_stats.primary_shots_fired)
	file.store_line("Weapons,Primary Shots Hit,%d,Primary weapon hits" % pilot_stats.primary_shots_hit)
	file.store_line("Weapons,Primary Accuracy,%.2f,Primary weapon accuracy percentage" % pilot_stats.primary_accuracy)
	file.store_line("Weapons,Secondary Shots Fired,%d,Secondary weapon shots fired" % pilot_stats.secondary_shots_fired)
	file.store_line("Weapons,Secondary Shots Hit,%d,Secondary weapon hits" % pilot_stats.secondary_shots_hit)
	file.store_line("Weapons,Secondary Accuracy,%.2f,Secondary weapon accuracy percentage" % pilot_stats.secondary_accuracy)
	file.store_line("Weapons,Total Accuracy,%.2f,Combined weapon accuracy" % pilot_stats.get_total_accuracy())
	
	# Friendly fire statistics
	file.store_line("Friendly Fire,Primary FF Hits,%d,Primary friendly fire hits" % pilot_stats.primary_friendly_hits)
	file.store_line("Friendly Fire,Secondary FF Hits,%d,Secondary friendly fire hits" % pilot_stats.secondary_friendly_hits)
	file.store_line("Friendly Fire,Friendly Kills,%d,Friendly fire kills" % pilot_stats.friendly_kills)
	
	# Medal information
	file.store_line("Medals,Total Earned,%d,Number of medals earned" % earned_medals.size())
	for medal in earned_medals:
		file.store_line("Medals,Earned Medal,%s,Medal name" % medal)
	
	file.close()
	return true

func _export_to_xml(pilot_stats: PilotStatistics, earned_medals: Array[String], file_path: String) -> bool:
	"""Export statistics to XML format."""
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false
	
	# XML header
	file.store_line("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
	file.store_line("<pilot_statistics format_version=\"1.0\" export_timestamp=\"%d\">" % Time.get_unix_time_from_system())
	
	# Basic statistics
	file.store_line("  <basic_stats>")
	file.store_line("    <score>%d</score>" % pilot_stats.score)
	file.store_line("    <rank>%d</rank>" % pilot_stats.rank)
	file.store_line("    <missions_flown>%d</missions_flown>" % pilot_stats.missions_flown)
	file.store_line("    <flight_time>%d</flight_time>" % pilot_stats.flight_time)
	file.store_line("    <kill_count>%d</kill_count>" % pilot_stats.kill_count)
	file.store_line("    <kill_count_ok>%d</kill_count_ok>" % pilot_stats.kill_count_ok)
	file.store_line("    <assists>%d</assists>" % pilot_stats.assists)
	file.store_line("  </basic_stats>")
	
	# Weapon statistics
	file.store_line("  <weapon_stats>")
	file.store_line("    <primary_shots_fired>%d</primary_shots_fired>" % pilot_stats.primary_shots_fired)
	file.store_line("    <primary_shots_hit>%d</primary_shots_hit>" % pilot_stats.primary_shots_hit)
	file.store_line("    <primary_accuracy>%.2f</primary_accuracy>" % pilot_stats.primary_accuracy)
	file.store_line("    <secondary_shots_fired>%d</secondary_shots_fired>" % pilot_stats.secondary_shots_fired)
	file.store_line("    <secondary_shots_hit>%d</secondary_shots_hit>" % pilot_stats.secondary_shots_hit)
	file.store_line("    <secondary_accuracy>%.2f</secondary_accuracy>" % pilot_stats.secondary_accuracy)
	file.store_line("  </weapon_stats>")
	
	# Medal information
	file.store_line("  <medals>")
	for medal in earned_medals:
		file.store_line("    <medal>%s</medal>" % medal.xml_escape())
	file.store_line("  </medals>")
	
	file.store_line("</pilot_statistics>")
	file.close()
	return true

func _export_to_binary(pilot_stats: PilotStatistics, earned_medals: Array[String], file_path: String) -> bool:
	"""Export statistics to compact binary format."""
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false
	
	# Write format header
	file.store_32(0x53544154)  # "STAT" magic number
	file.store_16(1)  # Format version
	file.store_64(Time.get_unix_time_from_system())  # Timestamp
	
	# Write pilot statistics
	file.store_32(pilot_stats.score)
	file.store_16(pilot_stats.rank)
	file.store_32(pilot_stats.missions_flown)
	file.store_32(pilot_stats.flight_time)
	file.store_32(pilot_stats.kill_count)
	file.store_32(pilot_stats.kill_count_ok)
	file.store_32(pilot_stats.assists)
	file.store_32(pilot_stats.primary_shots_fired)
	file.store_32(pilot_stats.primary_shots_hit)
	file.store_32(pilot_stats.secondary_shots_fired)
	file.store_32(pilot_stats.secondary_shots_hit)
	file.store_32(pilot_stats.primary_friendly_hits)
	file.store_32(pilot_stats.secondary_friendly_hits)
	file.store_32(pilot_stats.friendly_kills)
	
	# Write medal data
	file.store_16(earned_medals.size())
	for medal in earned_medals:
		file.store_pascal_string(medal)
	
	file.close()
	return true

func _export_to_text(pilot_stats: PilotStatistics, earned_medals: Array[String], file_path: String) -> bool:
	"""Export statistics to human-readable text format."""
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false
	
	# Header
	file.store_line("=".repeat(60))
	file.store_line("PILOT STATISTICS REPORT")
	file.store_line("Generated: %s" % Time.get_datetime_string_from_system())
	file.store_line("=".repeat(60))
	file.store_line("")
	
	# Basic Statistics
	file.store_line("BASIC STATISTICS")
	file.store_line("-".repeat(30))
	file.store_line("Total Score:       %s" % _format_number(pilot_stats.score))
	file.store_line("Current Rank:      %d" % pilot_stats.rank)
	file.store_line("Missions Flown:    %d" % pilot_stats.missions_flown)
	file.store_line("Flight Time:       %s" % _format_time_duration(pilot_stats.flight_time))
	file.store_line("Confirmed Kills:   %d" % pilot_stats.kill_count_ok)
	file.store_line("Total Kills:       %d" % pilot_stats.kill_count)
	file.store_line("Assists:           %d" % pilot_stats.assists)
	file.store_line("")
	
	# Combat Performance
	file.store_line("COMBAT PERFORMANCE")
	file.store_line("-".repeat(30))
	file.store_line("Primary Weapon Accuracy:    %.1f%%" % pilot_stats.primary_accuracy)
	file.store_line("Secondary Weapon Accuracy:  %.1f%%" % pilot_stats.secondary_accuracy)
	file.store_line("Total Weapon Accuracy:      %.1f%%" % pilot_stats.get_total_accuracy())
	file.store_line("Primary Shots Fired:        %s" % _format_number(pilot_stats.primary_shots_fired))
	file.store_line("Primary Shots Hit:          %s" % _format_number(pilot_stats.primary_shots_hit))
	file.store_line("Secondary Shots Fired:      %s" % _format_number(pilot_stats.secondary_shots_fired))
	file.store_line("Secondary Shots Hit:        %s" % _format_number(pilot_stats.secondary_shots_hit))
	file.store_line("")
	
	# Performance Metrics
	file.store_line("PERFORMANCE METRICS")
	file.store_line("-".repeat(30))
	var avg_kills_per_mission: float = float(pilot_stats.kill_count_ok) / float(pilot_stats.missions_flown) if pilot_stats.missions_flown > 0 else 0.0
	var avg_score_per_mission: float = float(pilot_stats.score) / float(pilot_stats.missions_flown) if pilot_stats.missions_flown > 0 else 0.0
	file.store_line("Average Kills per Mission:  %.1f" % avg_kills_per_mission)
	file.store_line("Average Score per Mission:  %.0f" % avg_score_per_mission)
	
	if pilot_stats.flight_time > 0:
		var kills_per_hour: float = float(pilot_stats.kill_count_ok) / (float(pilot_stats.flight_time) / 3600.0)
		var score_per_hour: float = float(pilot_stats.score) / (float(pilot_stats.flight_time) / 3600.0)
		file.store_line("Kills per Hour:             %.1f" % kills_per_hour)
		file.store_line("Score per Hour:             %.0f" % score_per_hour)
	file.store_line("")
	
	# Friendly Fire Statistics
	file.store_line("FRIENDLY FIRE STATISTICS")
	file.store_line("-".repeat(30))
	file.store_line("Primary FF Hits:            %d" % pilot_stats.primary_friendly_hits)
	file.store_line("Secondary FF Hits:          %d" % pilot_stats.secondary_friendly_hits)
	file.store_line("Friendly Kills:             %d" % pilot_stats.friendly_kills)
	
	var primary_ff_rate: float = 0.0
	var secondary_ff_rate: float = 0.0
	if pilot_stats.primary_shots_fired > 0:
		primary_ff_rate = float(pilot_stats.primary_friendly_hits) / float(pilot_stats.primary_shots_fired) * 100.0
	if pilot_stats.secondary_shots_fired > 0:
		secondary_ff_rate = float(pilot_stats.secondary_friendly_hits) / float(pilot_stats.secondary_shots_fired) * 100.0
	
	file.store_line("Primary FF Rate:            %.2f%%" % primary_ff_rate)
	file.store_line("Secondary FF Rate:          %.2f%%" % secondary_ff_rate)
	file.store_line("")
	
	# Medal Information
	file.store_line("MEDALS AND AWARDS")
	file.store_line("-".repeat(30))
	file.store_line("Total Medals Earned:        %d" % earned_medals.size())
	if not earned_medals.is_empty():
		file.store_line("")
		file.store_line("Earned Medals:")
		for i in range(earned_medals.size()):
			file.store_line("  %d. %s" % [i + 1, earned_medals[i]])
	file.store_line("")
	
	# Footer
	file.store_line("=".repeat(60))
	file.store_line("End of Report")
	file.store_line("=".repeat(60))
	
	file.close()
	return true

# ============================================================================
# COMPREHENSIVE EXPORT METHODS
# ============================================================================

func _export_comprehensive_json(comprehensive_stats: Dictionary, file_path: String) -> bool:
	"""Export comprehensive statistics to JSON."""
	var export_data: Dictionary = {
		"format_version": "1.0",
		"export_timestamp": Time.get_unix_time_from_system(),
		"export_type": "comprehensive_report",
		"statistics": comprehensive_stats,
		"metadata": {
			"game_version": "WCS-Godot 1.0",
			"exporter": "StatisticsExportManager",
			"format": "Comprehensive JSON"
		}
	}
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false
	
	file.store_string(JSON.stringify(export_data, "\t"))
	file.close()
	return true

func _export_comprehensive_xml(comprehensive_stats: Dictionary, file_path: String) -> bool:
	"""Export comprehensive statistics to XML."""
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false
	
	file.store_line("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
	file.store_line("<comprehensive_statistics export_timestamp=\"%d\">" % Time.get_unix_time_from_system())
	
	# This would implement full XML serialization of comprehensive stats
	_write_dictionary_as_xml(file, comprehensive_stats, 1)
	
	file.store_line("</comprehensive_statistics>")
	file.close()
	return true

func _export_comprehensive_text(comprehensive_stats: Dictionary, file_path: String) -> bool:
	"""Export comprehensive statistics to human-readable text."""
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false
	
	# Header
	file.store_line("=".repeat(80))
	file.store_line("COMPREHENSIVE PILOT STATISTICS REPORT")
	file.store_line("Generated: %s" % Time.get_datetime_string_from_system())
	file.store_line("=".repeat(80))
	file.store_line("")
	
	# Write each section of comprehensive stats
	for section_name in comprehensive_stats:
		var section_data = comprehensive_stats[section_name]
		file.store_line(section_name.to_upper())
		file.store_line("-".repeat(section_name.length()))
		_write_dictionary_as_text(file, section_data, 0)
		file.store_line("")
	
	file.close()
	return true

# ============================================================================
# IMPORT FUNCTIONALITY
# ============================================================================

func import_statistics_from_file(file_path: String) -> Dictionary:
	"""Import statistics from exported file."""
	if not FileAccess.file_exists(file_path):
		import_failed.emit("File does not exist", file_path)
		return {}
	
	# Check file size
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		import_failed.emit("Cannot open file", file_path)
		return {}
	
	var file_size: int = file.get_length()
	if file_size > max_import_file_size:
		file.close()
		import_failed.emit("File too large (%d bytes)" % file_size, file_path)
		return {}
	
	file.close()
	
	# Determine format and import
	var extension: String = file_path.get_extension().to_lower()
	var imported_data: Dictionary = {}
	
	match extension:
		"json":
			imported_data = _import_from_json(file_path)
		"xml":
			imported_data = _import_from_xml(file_path)
		"csv":
			imported_data = _import_from_csv(file_path)
		"dat":
			imported_data = _import_from_binary(file_path)
		_:
			import_failed.emit("Unsupported file format: %s" % extension, file_path)
			return {}
	
	if imported_data.is_empty():
		import_failed.emit("Failed to parse file data", file_path)
		return {}
	
	# Validate imported data
	if validate_imported_data and not _validate_imported_statistics(imported_data):
		import_failed.emit("Data validation failed", file_path)
		return {}
	
	import_completed.emit(file_path, imported_data)
	return imported_data

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _serialize_pilot_statistics(pilot_stats: PilotStatistics) -> Dictionary:
	"""Serialize pilot statistics to dictionary."""
	return {
		"score": pilot_stats.score,
		"rank": pilot_stats.rank,
		"missions_flown": pilot_stats.missions_flown,
		"flight_time": pilot_stats.flight_time,
		"kill_count": pilot_stats.kill_count,
		"kill_count_ok": pilot_stats.kill_count_ok,
		"assists": pilot_stats.assists,
		"primary_shots_fired": pilot_stats.primary_shots_fired,
		"primary_shots_hit": pilot_stats.primary_shots_hit,
		"secondary_shots_fired": pilot_stats.secondary_shots_fired,
		"secondary_shots_hit": pilot_stats.secondary_shots_hit,
		"primary_friendly_hits": pilot_stats.primary_friendly_hits,
		"secondary_friendly_hits": pilot_stats.secondary_friendly_hits,
		"friendly_kills": pilot_stats.friendly_kills,
		"primary_accuracy": pilot_stats.primary_accuracy,
		"secondary_accuracy": pilot_stats.secondary_accuracy,
		"last_flown": pilot_stats.last_flown
	}

func _create_detailed_breakdowns(pilot_stats: PilotStatistics) -> Dictionary:
	"""Create detailed statistical breakdowns."""
	return {
		"performance_metrics": {
			"total_accuracy": pilot_stats.get_total_accuracy(),
			"kill_efficiency": float(pilot_stats.kill_count_ok) / float(pilot_stats.kill_count) if pilot_stats.kill_count > 0 else 1.0,
			"avg_kills_per_mission": float(pilot_stats.kill_count_ok) / float(pilot_stats.missions_flown) if pilot_stats.missions_flown > 0 else 0.0,
			"avg_score_per_mission": float(pilot_stats.score) / float(pilot_stats.missions_flown) if pilot_stats.missions_flown > 0 else 0.0
		}
	}

func _create_medal_progress_data(pilot_stats: PilotStatistics, earned_medals: Array[String]) -> Dictionary:
	"""Create medal progress data for export."""
	return {
		"earned_medals": earned_medals,
		"medal_count": earned_medals.size()
	}

func _create_rank_progression_data(pilot_stats: PilotStatistics) -> Dictionary:
	"""Create rank progression data for export."""
	return {
		"current_rank": pilot_stats.rank,
		"rank_name": "Rank %d" % pilot_stats.rank  # Would use actual rank names
	}

func _format_number(number: int) -> String:
	"""Format number with thousands separators."""
	var str_num: String = str(number)
	var result: String = ""
	var count: int = 0
	
	for i in range(str_num.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = str_num[i] + result
		count += 1
	
	return result

func _format_time_duration(seconds: int) -> String:
	"""Format time duration as hours:minutes."""
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	return "%d:%02d" % [hours, minutes]

func _write_dictionary_as_xml(file: FileAccess, data: Dictionary, indent_level: int) -> void:
	"""Write dictionary data as XML with proper indentation."""
	var indent: String = "  ".repeat(indent_level)
	
	for key in data:
		var value = data[key]
		if value is Dictionary:
			file.store_line("%s<%s>" % [indent, key])
			_write_dictionary_as_xml(file, value, indent_level + 1)
			file.store_line("%s</%s>" % [indent, key])
		else:
			file.store_line("%s<%s>%s</%s>" % [indent, key, str(value).xml_escape(), key])

func _write_dictionary_as_text(file: FileAccess, data: Dictionary, indent_level: int) -> void:
	"""Write dictionary data as formatted text."""
	var indent: String = "  ".repeat(indent_level)
	
	for key in data:
		var value = data[key]
		if value is Dictionary:
			file.store_line("%s%s:" % [indent, key])
			_write_dictionary_as_text(file, value, indent_level + 1)
		else:
			file.store_line("%s%s: %s" % [indent, key, str(value)])

func _import_from_json(file_path: String) -> Dictionary:
	"""Import statistics from JSON file."""
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}
	
	var content: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(content)
	if parse_result != OK:
		return {}
	
	return json.data

func _import_from_xml(file_path: String) -> Dictionary:
	"""Import statistics from XML file."""
	# XML parsing would be implemented here
	# For now, return empty dictionary
	return {}

func _import_from_csv(file_path: String) -> Dictionary:
	"""Import statistics from CSV file."""
	# CSV parsing would be implemented here
	# For now, return empty dictionary
	return {}

func _import_from_binary(file_path: String) -> Dictionary:
	"""Import statistics from binary file."""
	# Binary parsing would be implemented here
	# For now, return empty dictionary
	return {}

func _validate_imported_statistics(data: Dictionary) -> bool:
	"""Validate imported statistics data."""
	# Check for required fields
	if not data.has("pilot_statistics"):
		return false
	
	var pilot_stats: Dictionary = data.pilot_statistics
	var required_fields: Array[String] = [
		"score", "rank", "missions_flown", "kill_count", "assists"
	]
	
	for field in required_fields:
		if not pilot_stats.has(field):
			return false
	
	# Validate data ranges
	if pilot_stats.score < 0 or pilot_stats.rank < 0 or pilot_stats.missions_flown < 0:
		return false
	
	return true

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_export_manager() -> StatisticsExportManager:
	"""Create a new statistics export manager instance."""
	var manager: StatisticsExportManager = StatisticsExportManager.new()
	manager.name = "StatisticsExportManager"
	return manager