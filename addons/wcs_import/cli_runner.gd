extends MainLoop

## CLI Runner for WCS Import Addon.
## Usage: godot --headless -s addons/wcs_import/cli_runner.gd -- --input <file> --output <dir> --type <type>

const WCSImporter = preload("res://addons/wcs_import/core/wcs_importer.gd")

var _exit_code = 0


func _initialize():
	pass


func _process(_delta):
	_run()
	return true # Exit loop


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
		var types = [] # Empty means all
		return importer.process_batch(output_dir, filter_pattern, types)


func _parse_args() -> Dictionary:
	var args = {}
	var user_args = OS.get_cmdline_user_args()
	print("User args: " + str(user_args))

	for i in range(user_args.size()):
		var arg = user_args[i]
		if arg.begins_with("--"):
			var key = arg.substr(2)
			var val = ""
			if i + 1 < user_args.size() and not user_args[i + 1].begins_with("--"):
				val = user_args[i + 1]
			args[key] = val
	return args
