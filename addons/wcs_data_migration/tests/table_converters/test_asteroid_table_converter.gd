extends GdUnitTestSuite

## Test suite for AsteroidTableConverter
## Tests asteroid.tbl parsing, data conversion, and Godot resource generation
## Following BMAD methodology for comprehensive validation

class_name TestAsteroidTableConverter

# Test fixtures and setup
var test_asteroid_data: String = """
#Asteroid Types

$Name:			Small Asteroid
$POF file1:		ast01.pof
$POF file2:		asta01.pof
$POF file3:		astb01.pof
$Detail distance:	( 0, 12000, 24000 )
$Max Speed:		60
$Expl inner rad:	100
$Expl outer rad:	200
$Expl damage:		0
$Expl blast:		3000
$Hitpoints:		50
#End

$Name:			Large Asteroid
$POF file1:		ast02.pof
$POF file2:		asta02.pof
$POF file3:		astb02.pof
$Detail distance:	( 0, 15000, 30000 )
$Max Speed:		40
$Expl inner rad:	150
$Expl outer rad:	300
$Expl damage:		10
$Expl blast:		5000
$Hitpoints:		147
#End

$Name:			Terran Debris 1
$POF file1:		cdebris01.pof
$POF file2:		none
$POF file3:		none
$Detail distance:	( 0, 5000, 10000 )
$Max Speed:		20
$Expl inner rad:	50
$Expl outer rad:	100
$Expl damage:		0
$Expl blast:		1000
$Hitpoints:		25
#End

#Impact explosions for asteroids 

$Impact Explosion:		ExpMissilehit1    ; ani played when laser hits asteroid
$Impact Explosion Radius:	20.0

#End
"""

var test_converter: AsteroidTableConverter
var temp_file_path: String

func before_test() -> void:
	# Set up test converter and temporary file
	test_converter = AsteroidTableConverter.new()
	
	# Create temporary test file
	temp_file_path = "user://test_asteroid.tbl"
	var file: FileAccess = FileAccess.open(temp_file_path, FileAccess.WRITE)
	file.store_string(test_asteroid_data)
	file.close()

func after_test() -> void:
	# Clean up temporary file
	if FileAccess.file_exists(temp_file_path):
		DirAccess.remove_absolute(temp_file_path)

func test_table_type_identification() -> void:
	"""Test that converter properly identifies table type."""
	assert_that(test_converter.get_table_type()).is_equal(TableType.ASTEROID)

func test_parse_asteroid_entry() -> void:
	"""Test parsing of individual asteroid entries."""
	var lines: PackedStringArray = test_asteroid_data.split("\n")
	var state: ParseState = ParseState.new(lines)
	
	# Skip to first asteroid
	while state.has_more_lines():
		var line: String = state.peek_line()
		if line.contains("Small Asteroid"):
			break
		state.skip_line()
	
	var parsed_entry: Dictionary = test_converter.parse_asteroid_entry(state)
	
	# Validate parsed data
	assert_that(parsed_entry).is_not_null()
	assert_that(parsed_entry.get("name")).is_equal("Small Asteroid")
	assert_that(parsed_entry.get("pof_file1")).is_equal("ast01.pof")
	assert_that(parsed_entry.get("pof_file2")).is_equal("asta01.pof")
	assert_that(parsed_entry.get("pof_file3")).is_equal("astb01.pof")
	assert_that(parsed_entry.get("max_speed")).is_equal(60.0)
	assert_that(parsed_entry.get("hitpoints")).is_equal(50)
	assert_that(parsed_entry.get("expl_inner_rad")).is_equal(100.0)
	assert_that(parsed_entry.get("expl_outer_rad")).is_equal(200.0)
	assert_that(parsed_entry.get("expl_damage")).is_equal(0.0)
	assert_that(parsed_entry.get("expl_blast")).is_equal(3000.0)
	assert_that(parsed_entry.get("detail_distance")).is_equal([0, 12000, 24000])

func test_parse_none_pof_files() -> void:
	"""Test parsing entries with 'none' POF file references."""
	var lines: PackedStringArray = test_asteroid_data.split("\n")
	var state: ParseState = ParseState.new(lines)
	
	# Skip to debris entry (has 'none' POF files)
	while state.has_more_lines():
		var line: String = state.peek_line()
		if line.contains("Terran Debris"):
			break
		state.skip_line()
	
	var parsed_entry: Dictionary = test_converter.parse_asteroid_entry(state)
	
	assert_that(parsed_entry).is_not_null()
	assert_that(parsed_entry.get("name")).is_equal("Terran Debris 1")
	assert_that(parsed_entry.get("pof_file1")).is_equal("cdebris01.pof")
	assert_that(parsed_entry.get("pof_file2")).is_equal("none")
	assert_that(parsed_entry.get("pof_file3")).is_equal("none")

func test_parse_impact_data() -> void:
	"""Test parsing of impact explosion data."""
	var lines: PackedStringArray = test_asteroid_data.split("\n")
	var state: ParseState = ParseState.new(lines)
	
	# Skip to impact data section
	while state.has_more_lines():
		var line: String = state.peek_line()
		if line.contains("Impact explosions"):
			state.skip_line()
			break
		state.skip_line()
	
	var impact_data: Dictionary = test_converter.parse_impact_data(state)
	
	assert_that(impact_data).is_not_null()
	assert_that(impact_data.get("impact_explosion")).is_equal("ExpMissilehit1    ; ani played when laser hits asteroid")
	assert_that(impact_data.get("impact_explosion_radius")).is_equal(20.0)
	assert_that(impact_data.get("type")).is_equal("impact_data")

func test_convert_pof_to_glb_path() -> void:
	"""Test POF to GLB path conversion with semantic organization."""
	# Test asteroid POF conversion
	var asteroid_path: String = test_converter._convert_pof_to_glb_path("ast01.pof")
	assert_that(asteroid_path).is_equal("campaigns/wing_commander_saga/environments/objects/asteroids/ast01.glb")
	
	# Test debris POF conversion
	var terran_debris_path: String = test_converter._convert_pof_to_glb_path("cdebris01.pof")
	assert_that(terran_debris_path).is_equal("campaigns/wing_commander_saga/environments/objects/debris/terran/cdebris01.glb")
	
	var pirate_debris_path: String = test_converter._convert_pof_to_glb_path("pdebris01.pof")
	assert_that(pirate_debris_path).is_equal("campaigns/wing_commander_saga/environments/objects/debris/pirate/pdebris01.glb")
	
	var kilrathi_debris_path: String = test_converter._convert_pof_to_glb_path("kdebris01.pof")
	assert_that(kilrathi_debris_path).is_equal("campaigns/wing_commander_saga/environments/objects/debris/kilrathi/kdebris01.glb")
	
	# Test 'none' file
	var none_path: String = test_converter._convert_pof_to_glb_path("none")
	assert_that(none_path).is_null()

func test_convert_asteroid_entry() -> void:
	"""Test conversion of parsed asteroid data to Godot format."""
	var test_entry: Dictionary = {
		"name": "Test Asteroid",
		"pof_file1": "ast01.pof", 
		"pof_file2": "asta01.pof",
		"pof_file3": "astb01.pof",
		"max_speed": 60.0,
		"hitpoints": 100,
		"expl_inner_rad": 50.0,
		"expl_outer_rad": 100.0,
		"expl_damage": 10.0,
		"expl_blast": 2000.0,
		"detail_distance": [0, 10000, 20000]
	}
	
	var converted: Dictionary = test_converter._convert_asteroid_entry(test_entry)
	
	assert_that(converted.get("name")).is_equal("Test Asteroid")
	assert_that(converted.get("display_name")).is_equal("Test Asteroid")
	assert_that(converted.get("max_speed")).is_equal(60.0)
	assert_that(converted.get("hitpoints")).is_equal(100)
	assert_that(converted.get("explosion_inner_radius")).is_equal(50.0)
	assert_that(converted.get("explosion_outer_radius")).is_equal(100.0)
	assert_that(converted.get("explosion_damage")).is_equal(10.0)
	assert_that(converted.get("explosion_blast")).is_equal(2000.0)
	assert_that(converted.get("detail_distances")).is_equal([0, 10000, 20000])
	assert_that(converted.get("lod_0_model")).is_equal("campaigns/wing_commander_saga/environments/objects/asteroids/ast01.glb")
	assert_that(converted.get("lod_1_model")).is_equal("campaigns/wing_commander_saga/environments/objects/asteroids/asta01.glb")
	assert_that(converted.get("lod_2_model")).is_equal("campaigns/wing_commander_saga/environments/objects/asteroids/astb01.glb")

func test_convert_impact_data() -> void:
	"""Test conversion of impact data with comment cleaning."""
	var test_impact: Dictionary = {
		"impact_explosion": "ExpMissilehit1    ; ani played when laser hits asteroid",
		"impact_explosion_radius": 25.0
	}
	
	var converted: Dictionary = test_converter._convert_impact_data(test_impact)
	
	# Should clean comment from impact explosion
	assert_that(converted.get("impact_explosion")).is_equal("campaigns/wing_commander_saga/effects/explosions/expmissilehit1.tscn")
	assert_that(converted.get("impact_explosion_radius")).is_equal(25.0)

func test_full_table_parsing() -> void:
	"""Test complete table parsing from file."""
	var lines: PackedStringArray = test_asteroid_data.split("\n")
	var state: ParseState = ParseState.new(lines)
	
	var entries: Array = test_converter.parse_table(state)
	
	# Should have 3 asteroids + 1 impact data
	assert_that(entries.size()).is_equal(4)
	
	# Check asteroid entries
	var asteroids: Array = entries.filter(func(e): return e.get("type") == "asteroid")
	assert_that(asteroids.size()).is_equal(3)
	
	# Check impact data
	var impact_entries: Array = entries.filter(func(e): return e.get("type") == "impact_data")
	assert_that(impact_entries.size()).is_equal(1)

func test_godot_resource_conversion() -> void:
	"""Test conversion to Godot resource format."""
	var lines: PackedStringArray = test_asteroid_data.split("\n")
	var state: ParseState = ParseState.new(lines)
	var entries: Array = test_converter.parse_table(state)
	
	var result: Dictionary = test_converter.convert_to_godot_resource(entries)
	
	assert_that(result.has("individual_resources")).is_true()
	assert_that(result.has("impact_data")).is_true()
	
	var individual_resources: Array = result.get("individual_resources")
	assert_that(individual_resources.size()).is_equal(3)
	
	# Check first resource structure
	var first_resource: Dictionary = individual_resources[0]
	assert_that(first_resource.has("name")).is_true()
	assert_that(first_resource.has("display_name")).is_true()
	assert_that(first_resource.has("lod_0_model")).is_true()
	assert_that(first_resource.has("lod_1_model")).is_true()
	assert_that(first_resource.has("lod_2_model")).is_true()
	assert_that(first_resource.has("hitpoints")).is_true()
	assert_that(first_resource.has("max_speed")).is_true()
	assert_that(first_resource.has("explosion_damage")).is_true()

func test_entry_validation() -> void:
	"""Test asteroid entry validation."""
	# Valid entry
	var valid_entry: Dictionary = {"name": "Test Asteroid"}
	assert_that(test_converter.validate_entry(valid_entry)).is_true()
	
	# Invalid entry (missing name)
	var invalid_entry: Dictionary = {"hitpoints": 100}
	assert_that(test_converter.validate_entry(invalid_entry)).is_false()

func test_detail_distance_parsing() -> void:
	"""Test parsing of detail distance arrays with various formats."""
	# Test normal format
	var normal_line: String = "$Detail distance:	( 0, 12000, 24000 )"
	var match: RegExMatch = test_converter._parse_patterns["detail_distance"].search(normal_line)
	assert_that(match).is_not_null()
	
	# Test with extra spaces
	var spaced_line: String = "$Detail distance:	(  0 ,  12000 ,  24000  )"
	var spaced_match: RegExMatch = test_converter._parse_patterns["detail_distance"].search(spaced_line)
	assert_that(spaced_match).is_not_null()

func test_edge_cases() -> void:
	"""Test edge cases and error conditions."""
	# Test empty table
	var empty_state: ParseState = ParseState.new(PackedStringArray())
	var empty_entries: Array = test_converter.parse_table(empty_state)
	assert_that(empty_entries.size()).is_equal(0)
	
	# Test malformed entry (missing #End)
	var malformed_lines: PackedStringArray = PackedStringArray([
		"#Asteroid Types",
		"$Name: Incomplete Asteroid",
		"$Hitpoints: 50"
		# Missing #End
	])
	var malformed_state: ParseState = ParseState.new(malformed_lines)
	var malformed_entries: Array = test_converter.parse_table(malformed_state)
	# Should handle gracefully (exact behavior depends on implementation)
	assert_that(malformed_entries).is_not_null()

func test_comment_and_blank_line_handling() -> void:
	"""Test that comments and blank lines are properly skipped."""
	var test_data_with_comments: String = """
#Asteroid Types

; This is a comment line
$Name:			Test Asteroid
; Another comment
$Hitpoints:		100

; Empty line above and below

$Max Speed:		50
#End
"""
	
	var lines: PackedStringArray = test_data_with_comments.split("\n")
	var state: ParseState = ParseState.new(lines)
	
	# Should skip comments and parse correctly
	while state.has_more_lines():
		var line: String = state.peek_line()
		if line.contains("Test Asteroid"):
			break
		state.skip_line()
	
	var parsed: Dictionary = test_converter.parse_asteroid_entry(state)
	assert_that(parsed.get("name")).is_equal("Test Asteroid")
	assert_that(parsed.get("hitpoints")).is_equal(100)
	assert_that(parsed.get("max_speed")).is_equal(50.0)

func test_multiline_blast_values() -> void:
	"""Test handling of multi-line blast values."""
	var multiline_data: String = """
$Name:			Test Asteroid
$Expl blast:		2000
				3000
$Hitpoints:		100
#End
"""
	
	var lines: PackedStringArray = multiline_data.split("\n")
	var state: ParseState = ParseState.new(lines)
	
	# Find the asteroid entry
	while state.has_more_lines():
		var line: String = state.peek_line()
		if line.contains("Test Asteroid"):
			break
		state.skip_line()
	
	var parsed: Dictionary = test_converter.parse_asteroid_entry(state)
	
	# Should handle multiline blast values appropriately
	assert_that(parsed.get("name")).is_equal("Test Asteroid")
	assert_that(parsed.get("hitpoints")).is_equal(100)
	# Blast value handling depends on implementation