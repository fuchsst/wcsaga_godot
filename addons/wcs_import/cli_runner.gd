extends MainLoop

## CLI Runner for WCS Import Addon.
## Usage: godot --headless -s addons/wcs_import/cli_runner.gd -- --input <file> --output <dir> --type <type>

const WCSImporter = preload("res://addons/wcs_import/core/wcs_importer.gd")

var _exit_code = 0


func _initialize():
	pass


func _process(_delta):
	_run()
	return true  # Exit loop


func _run():
	print("Cmdline args: " + str(OS.get_cmdline_args()))
	var args = _parse_args()

	if not run_import(args):
		_exit_code = 1
	else:
		_exit_code = 0


func run_import(args: Dictionary) -> bool:
	var importer = WCSImporter.new()

	var res_path = ProjectSettings.globalize_path("res://")
	if res_path.ends_with("/"):
		res_path = res_path.left(-1)
	var project_root = res_path.get_base_dir()
	var default_source_root = project_root.path_join("source_assets/wcs_hermes_campaign")

	if not args.has("output"):
		if OS.has_feature("editor"):
			print("Running from Editor, defaulting output to 'res://'")
			args["output"] = "res://"
		else:
			print(
				"Usage: godot --headless -s addons/wcs_import/cli_runner.gd -- --output <dir> [--input <file>] [--filter <pattern>]"
			)
			return false

	var output_dir = args["output"]

	# Normalize the output directory to an absolute path
	# The output_dir is the Godot project root (where res:// points to)
	# Subpaths like "assets/weapons" are added by wcs_importer based on asset type
	if output_dir == "." or output_dir == "res://":
		output_dir = res_path
	elif output_dir == "target" or output_dir.ends_with("/target"):
		# Special case: "target" means the Godot project directory
		output_dir = res_path
	elif not output_dir.begins_with("/"):
		# Relative path - assume relative to the repo root (parent of target/)
		output_dir = project_root.path_join(output_dir)
		# If the result points to the same as res_path, use res_path directly
		if output_dir.simplify_path() == res_path.simplify_path():
			output_dir = res_path
		else:
			output_dir = output_dir.simplify_path()

	print("Resolved output_dir: " + output_dir)
	var filter_pattern = args.get("filter", "")

	importer.build_file_map(default_source_root)

	if args.has("input"):
		# Single file mode
		var input_path = args["input"]
		if not input_path.begins_with("/"):
			if input_path.begins_with("../"):
				input_path = res_path.path_join(input_path).simplify_path()
			else:
				input_path = project_root.path_join(input_path).simplify_path()

		var type = args.get("type", "auto")
		if type == "auto":
			type = importer.detect_type(input_path)

		print("Processing single file: " + input_path)
		return importer.process_file(input_path, output_dir, type)
	else:
		# Batch mode
		# CLI batch mode runs everything unless filtered.
		# Pass types_to_process based on args or default to all.
		var types = []  # Empty means all
		return importer.process_batch(output_dir, filter_pattern, types)


func _parse_args() -> Dictionary:
	var args = {}
	var user_args = OS.get_cmdline_user_args()
	print("User args: " + str(user_args))

	var i = 0
	while i < user_args.size():
		var arg = user_args[i]
		if arg.begins_with("--"):
			var key_val = arg.substr(2)
			# Handle --key=value format
			if key_val.contains("="):
				var parts = key_val.split("=", true, 1)  # Split on first = only
				args[parts[0]] = parts[1] if parts.size() > 1 else ""
			else:
				# Handle --key value format
				var key = key_val
				var val = ""
				if i + 1 < user_args.size() and not user_args[i + 1].begins_with("--"):
					val = user_args[i + 1]
					i += 1  # Skip the value in next iteration
				args[key] = val
		i += 1
	return args
