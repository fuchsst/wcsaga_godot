class_name FS2MissionIO
extends RefCounted

## FS2 Mission File Import/Export System
## Handles conversion between .fs2 mission files and MissionData resources
##
## This system provides a clean, high-level interface for importing and exporting
## FS2 mission files while maintaining perfect compatibility with the WCS format.

# Dependencies
const MissionData = preload("res://scripts/resources/mission/mission_data.gd")
const ValidationResult = preload("res://scripts/resources/mission/validation_result.gd")
const FS2Parser = preload("res://migration_tools/fs2_parser.gd")
const FS2Writer = preload("res://migration_tools/fs2_writer.gd")

## Result container for import operations
class ImportResult extends RefCounted:
	var success: bool = false
	var mission_data: MissionData = null
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var import_time_ms: int = 0
	var lines_processed: int = 0
	
	func add_error(message: String) -> void:
		errors.append(message)
		success = false
	
	func add_warning(message: String) -> void:
		warnings.append(message)
	
	func get_summary() -> String:
		var summary := ""
		if success:
			summary += "Import successful"
		else:
			summary += "Import failed"
		
		if errors.size() > 0:
			summary += " (%d errors)" % errors.size()
		if warnings.size() > 0:
			summary += " (%d warnings)" % warnings.size()
		
		return summary

## Result container for export operations
class ExportResult extends RefCounted:
	var success: bool = false
	var output_path: String = ""
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var export_time_ms: int = 0
	var lines_written: int = 0
	
	func add_error(message: String) -> void:
		errors.append(message)
		success = false
	
	func add_warning(message: String) -> void:
		warnings.append(message)
	
	func get_summary() -> String:
		var summary := ""
		if success:
			summary += "Export successful"
		else:
			summary += "Export failed"
		
		if errors.size() > 0:
			summary += " (%d errors)" % errors.size()
		if warnings.size() > 0:
			summary += " (%d warnings)" % warnings.size()
		
		return summary

## Signals for progress reporting
signal import_progress(percentage: float, message: String)
signal import_complete(result: ImportResult)
signal export_progress(percentage: float, message: String)
signal export_complete(result: ExportResult)

## Imports an FS2 mission file to MissionData resource
## Returns ImportResult with detailed information about the operation
func import_mission(file_path: String) -> ImportResult:
	var result := ImportResult.new()
	var start_time := Time.get_ticks_msec()
	
	# Validate file exists
	if not FileAccess.file_exists(file_path):
		result.add_error("Mission file does not exist: " + file_path)
		return result
	
	# Open file
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		result.add_error("Cannot open mission file: " + file_path)
		return result
	
	emit_signal("import_progress", 0.0, "Reading mission file...")
	
	# Read all lines
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	
	result.lines_processed = lines.size()
	
	if lines.is_empty():
		result.add_error("Mission file is empty")
		return result
	
	emit_signal("import_progress", 10.0, "Parsing mission data...")
	
	# Parse mission using FS2Parser
	var parser := FS2Parser.new()
	var parse_result := parser.parse_mission(lines)
	
	if not parse_result.success:
		for error in parse_result.errors:
			result.add_error(error)
		for warning in parse_result.warnings:
			result.add_warning(warning)
		return result
	
	emit_signal("import_progress", 80.0, "Converting to MissionData...")
	
	# Convert parsed data to MissionData
	result.mission_data = parse_result.mission_data
	
	# Validate the imported mission
	emit_signal("import_progress", 90.0, "Validating mission...")
	var validation := result.mission_data.validate()
	if not validation.is_valid():
		for error in validation.get_errors():
			result.add_warning("Validation: " + error)
	
	# Finalize result
	result.success = true
	result.import_time_ms = Time.get_ticks_msec() - start_time
	
	emit_signal("import_progress", 100.0, "Import complete")
	emit_signal("import_complete", result)
	
	return result

## Exports MissionData to FS2 mission file format
## Returns ExportResult with detailed information about the operation
func export_mission(mission_data: MissionData, file_path: String) -> ExportResult:
	var result := ExportResult.new()
	var start_time := Time.get_ticks_msec()
	result.output_path = file_path
	
	# Validate mission data first
	emit_signal("export_progress", 0.0, "Validating mission data...")
	var validation := mission_data.validate()
	if not validation.is_valid():
		for error in validation.get_errors():
			result.add_error("Mission validation failed: " + error)
		return result
	
	# Add warnings if any
	for warning in validation.get_warnings():
		result.add_warning("Mission validation: " + warning)
	
	emit_signal("export_progress", 20.0, "Converting to FS2 format...")
	
	# Convert MissionData to FS2 format using FS2Writer
	var writer := FS2Writer.new()
	var write_result := writer.write_mission(mission_data)
	
	if not write_result.success:
		for error in write_result.errors:
			result.add_error(error)
		return result
	
	emit_signal("export_progress", 70.0, "Writing to file...")
	
	# Write to file
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		result.add_error("Cannot create output file: " + file_path)
		return result
	
	file.store_string(write_result.fs2_content)
	file.close()
	
	result.lines_written = write_result.fs2_content.split("\n").size()
	
	# Finalize result
	result.success = true
	result.export_time_ms = Time.get_ticks_msec() - start_time
	
	emit_signal("export_progress", 100.0, "Export complete")
	emit_signal("export_complete", result)
	
	return result

## Validates an FS2 file without full import (quick check)
func validate_fs2_file(file_path: String) -> ValidationResult:
	var result := ValidationResult.new()
	
	if not FileAccess.file_exists(file_path):
		result.add_error("File does not exist: " + file_path)
		return result
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		result.add_error("Cannot open file: " + file_path)
		return result
	
	# Quick validation - check for required sections
	var content := file.get_as_text()
	file.close()
	
	var required_sections := ["#Mission Info", "#Objects"]
	for section in required_sections:
		if not content.contains(section):
			result.add_error("Missing required section: " + section)
	
	# Check file format basics
	if not content.contains("$Version:"):
		result.add_error("Missing version information")
	
	if not content.contains("$Name:"):
		result.add_error("Missing mission name")
	
	# Check for common issues
	if content.length() < 100:
		result.add_warning("File seems very small for a mission")
	
	if content.count("#") < 2:
		result.add_warning("File has very few sections")
	
	return result

## Tests round-trip compatibility (import then export, compare)
func test_round_trip_compatibility(file_path: String) -> Dictionary:
	var test_result := {
		"success": false,
		"import_success": false,
		"export_success": false,
		"validation_success": false,
		"differences": [],
		"errors": []
	}
	
	# Import original
	var import_result := import_mission(file_path)
	test_result.import_success = import_result.success
	
	if not import_result.success:
		test_result.errors.append_array(import_result.errors)
		return test_result
	
	# Export to temp file
	var temp_path := file_path + ".temp"
	var export_result := export_mission(import_result.mission_data, temp_path)
	test_result.export_success = export_result.success
	
	if not export_result.success:
		test_result.errors.append_array(export_result.errors)
		return test_result
	
	# Re-import temp file
	var reimport_result := import_mission(temp_path)
	test_result.validation_success = reimport_result.success
	
	if not reimport_result.success:
		test_result.errors.append_array(reimport_result.errors)
		return test_result
	
	# Compare mission data (basic comparison)
	var original := import_result.mission_data
	var reimported := reimport_result.mission_data
	
	if original.mission_title != reimported.mission_title:
		test_result.differences.append("Mission title differs")
	
	if original.ships.size() != reimported.ships.size():
		test_result.differences.append("Ship count differs")
	
	if original.wings.size() != reimported.wings.size():
		test_result.differences.append("Wing count differs")
	
	# Clean up temp file
	DirAccess.remove_absolute(temp_path)
	
	test_result.success = test_result.differences.is_empty()
	return test_result

## Utility function to get mission statistics from FS2 file without full import
func get_quick_mission_info(file_path: String) -> Dictionary:
	var info := {
		"title": "",
		"author": "",
		"description": "",
		"version": "",
		"file_size": 0,
		"estimated_complexity": 0,
		"errors": []
	}
	
	if not FileAccess.file_exists(file_path):
		info.errors.append("File does not exist")
		return info
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		info.errors.append("Cannot open file")
		return info
	
	info.file_size = file.get_length()
	
	# Parse basic info without full parsing
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		
		if line.begins_with("$Name:"):
			info.title = line.substr(6).strip_edges()
		elif line.begins_with("$Author:"):
			info.author = line.substr(8).strip_edges()
		elif line.begins_with("$Description:"):
			info.description = line.substr(13).strip_edges()
		elif line.begins_with("$Version:"):
			info.version = line.substr(9).strip_edges()
		elif line.begins_with("#"):
			info.estimated_complexity += 1
	
	file.close()
	return info