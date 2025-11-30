extends SceneTree

func _init():
	var runner = load("res://addons/wcs_import/cli_runner.gd").new()
	var input_path = "res://../source_assets/wcs_hermes_campaign/hermes_core/stars.tbl"
	var output_dir = "res://../target/assets/environment/stars"
	
	print("Running star conversion verification...")
	
	# Clean up previous run
	var dir = DirAccess.open(output_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					# Recursive delete not simple in GDScript without helper, 
					# but we can just check if files are created/overwritten
					pass
			file_name = dir.get_next()
			
	var success = runner._process_stars(input_path, output_dir)
	
	if success:
		print("Conversion reported success.")
		_verify_files(output_dir)
	else:
		print("Conversion failed.")
		quit(1)
		
	quit(0)

func _verify_files(output_dir: String):
	# output_dir is target/assets/environment/stars
	# Images are in output_dir
	# Suns are in ../suns
	# Debris are in ../debris
	var expected_suns = ["sung0.tres", "sung2.tres", "sunk0.tres"] # Sample
	var expected_bitmaps = ["planet_vega_iii.png", "neb17.png"] # Sample PNGs
	# Debris are now PNGs, names depend on source files.
	
	var suns_dir = output_dir.get_base_dir().path_join("suns")
	var debris_dir = output_dir.get_base_dir().path_join("debris")
	
	print("Verifying Suns in: " + suns_dir)
	for sun_file in expected_suns:
		var path = suns_dir.path_join(sun_file)
		if not FileAccess.file_exists(path):
			print("Missing sun resource: " + sun_file)
		else:
			# Verify texture loading
			var sun_res = load(path)
			if sun_res:
				if sun_res.sunglow:
					print("Sun " + sun_file + " has sunglow texture: " + sun_res.sunglow.resource_path)
				else:
					print("Sun " + sun_file + " MISSING sunglow texture")
					
				if not sun_res.flares.is_empty():
					print("Sun " + sun_file + " has " + str(sun_res.flares.size()) + " flares")
					if sun_res.flares[0].texture:
						print("  Flare 0 has texture: " + sun_res.flares[0].texture.resource_path)
					else:
						print("  Flare 0 MISSING texture")
			
	# Check bitmaps (PNGs)
	print("Generated Bitmaps (PNGs) in: " + output_dir)
	_list_files(output_dir)
	
	print("Generated Debris (PNGs) in: " + debris_dir)
	_list_files(debris_dir)
	
	var debris_neb_dir = output_dir.get_base_dir().path_join("debris_neb")
	print("Generated Nebula Debris (PNGs) in: " + debris_neb_dir)
	_list_files(debris_neb_dir)

func _list_files(path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and not file_name.ends_with(".import"):
				print(" - " + file_name)
			file_name = dir.get_next()
	else:
		print("Directory not found: " + path)
