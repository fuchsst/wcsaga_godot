@tool
extends RefCounted

## VP Archive Extractor Bridge
## Interfaces with Python VP extraction tool for Godot import plugin integration

class_name VPExtractor

const PYTHON_SCRIPT_PATH: String = "res://conversion_tools/vp_extractor.py"

func extract_vp_archive(vp_file_path: String, output_directory: String, options: Dictionary) -> Dictionary:
	"""Extract VP archive using Python backend and return extraction results"""
	
	# Validate input file
	if not FileAccess.file_exists(vp_file_path):
		return {
			"success": false,
			"error": "VP file does not exist: " + vp_file_path
		}
	
	# Ensure output directory exists
	var dir: DirAccess = DirAccess.open("res://")
	if not dir.dir_exists(output_directory):
		var create_result: Error = dir.make_dir_recursive(output_directory)
		if create_result != OK:
			return {
				"success": false,
				"error": "Failed to create output directory: " + output_directory
			}
	
	# Prepare Python command
	var python_command: Array[String] = [
		ProjectSettings.globalize_path(PYTHON_SCRIPT_PATH),
		"--input", ProjectSettings.globalize_path(vp_file_path),
		"--output", ProjectSettings.globalize_path(output_directory),
		"--verbose"
	]
	
	# Add options to command
	if options.get("organize_by_type", true):
		python_command.append("--organize")
	
	if options.get("generate_manifest", true):
		python_command.append("--manifest")
	
	# Execute Python extraction
	var start_time: float = Time.get_ticks_msec() / 1000.0
	var output: Array = []
	var exit_code: int = OS.execute("python3", python_command, output, true, true)
	var end_time: float = Time.get_ticks_msec() / 1000.0
	
	# Parse results
	if exit_code != 0:
		var error_message: String = "VP extraction failed with exit code: " + str(exit_code)
		if output.size() > 0:
			error_message += "\nOutput: " + str(output)
		
		return {
			"success": false,
			"error": error_message
		}
	
	# Count extracted files
	var file_count: int = _count_extracted_files(output_directory)
	
	# Load manifest if generated
	var manifest_data: Dictionary = {}
	var manifest_path: String = output_directory + "/manifest.json"
	if FileAccess.file_exists(manifest_path):
		manifest_data = _load_manifest(manifest_path)
	
	return {
		"success": true,
		"file_count": file_count,
		"extraction_time": end_time - start_time,
		"manifest": manifest_data,
		"output_messages": output
	}

func _count_extracted_files(directory: String) -> int:
	"""Count total files extracted in directory tree"""
	var count: int = 0
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return 0
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = directory + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			# Recurse into subdirectory
			count += _count_extracted_files(full_path)
		elif not dir.current_is_dir():
			count += 1
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return count

func _load_manifest(manifest_path: String) -> Dictionary:
	"""Load extraction manifest JSON file"""
	var file: FileAccess = FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open manifest file: " + manifest_path)
		return {}
	
	var json_text: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	
	if parse_result != OK:
		push_warning("Failed to parse manifest JSON: " + json.error_string)
		return {}
	
	var data: Variant = json.data
	if data is Dictionary:
		return data as Dictionary
	else:
		push_warning("Manifest JSON root is not a Dictionary")
		return {}

func get_vp_file_info(vp_file_path: String) -> Dictionary:
	"""Get basic information about VP file without extracting"""
	
	if not FileAccess.file_exists(vp_file_path):
		return {
			"success": false,
			"error": "VP file does not exist"
		}
	
	var file: FileAccess = FileAccess.open(vp_file_path, FileAccess.READ)
	if file == null:
		return {
			"success": false,
			"error": "Failed to open VP file"
		}
	
	# Read VP header
	var signature: PackedByteArray = file.get_buffer(4)
	var version: int = file.get_32()
	var directory_offset: int = file.get_32()
	var directory_entries: int = file.get_32()
	
	file.close()
	
	# Validate signature
	var signature_string: String = signature.get_string_from_ascii()
	if signature_string != "VPVP":
		return {
			"success": false,
			"error": "Invalid VP file signature: " + signature_string
		}
	
	return {
		"success": true,
		"version": version,
		"file_count": directory_entries,
		"file_size": FileAccess.get_file_as_bytes(vp_file_path).size()
	}
