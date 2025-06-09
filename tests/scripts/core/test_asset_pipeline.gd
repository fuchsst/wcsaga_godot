class_name TestAssetPipeline
extends RefCounted

## Comprehensive unit tests for the WCS asset pipeline.
## Tests VP archive reading, table parsing, asset migration, and coordination.

var vp_archive: VPArchive
var vp_manager: VPManager
var table_parser: TableParser
var asset_manager: AssetManager

# Test data
var test_vp_data: PackedByteArray
var test_table_content: String

func before_each() -> void:
	"""Set up test environment before each test."""
	
	vp_archive = VPArchive.new()
	vp_manager = VPManager.new()
	table_parser = TableParser.new()
	asset_manager = AssetManager.new()
	
	_create_test_data()

func after_each() -> void:
	"""Clean up after each test."""
	
	if vp_archive:
		vp_archive.close_archive()
	if vp_manager:
		vp_manager.unload_all_archives()
	if asset_manager:
		asset_manager.clear_cache()

## VP Archive Tests

func test_vp_archive_creation() -> bool:
	"""Test VP archive creation and basic properties."""
	
	assert(vp_archive != null, "VPArchive should be created")
	assert(not vp_archive.is_loaded, "Archive should not be loaded initially")
	assert(vp_archive.file_entries.is_empty(), "File entries should be empty initially")
	assert(vp_archive.file_lookup.is_empty(), "File lookup should be empty initially")
	
	return true

func test_vp_archive_header_validation() -> bool:
	"""Test VP archive header validation."""
	
	# Test with invalid magic number
	var invalid_data: PackedByteArray = PackedByteArray()
	invalid_data.append_array("FAKE".to_utf8_buffer())  # Wrong magic
	invalid_data.append_array(_int32_to_bytes(2117))    # Version
	invalid_data.append_array(_int32_to_bytes(100))     # Index offset
	invalid_data.append_array(_int32_to_bytes(5))       # Num files
	
	# This should fail with invalid magic
	var temp_file: String = "res://temp_test.vp"
	_save_test_file(temp_file, invalid_data)
	
	var result: bool = vp_archive.load_archive(temp_file)
	assert(not result, "Loading should fail with invalid magic")
	
	# Clean up
	DirAccess.remove_absolute(temp_file)
	
	return true

func test_vp_file_extraction() -> bool:
	"""Test file extraction from VP archives."""
	
	# This would require a valid test VP file
	# For now, test the extraction interface
	
	var fake_filename: String = "test.txt"
	var has_file: bool = vp_archive.has_file(fake_filename)
	assert(not has_file, "Should not have file before loading archive")
	
	var extracted_data: PackedByteArray = vp_archive.extract_file(fake_filename)
	assert(extracted_data.is_empty(), "Should return empty data for non-existent file")
	
	return true

## VP Manager Tests

func test_vp_manager_creation() -> bool:
	"""Test VP manager creation and initialization."""
	
	assert(vp_manager != null, "VPManager should be created")
	assert(vp_manager.loaded_archives.is_empty(), "Should have no loaded archives initially")
	assert(vp_manager.archive_precedence.is_empty(), "Should have no precedence initially")
	
	return true

func test_vp_manager_precedence() -> bool:
	"""Test VP manager precedence handling."""
	
	# Test precedence ordering logic
	var info: Dictionary = vp_manager.get_archive_info()
	assert(info.has("num_archives"), "Archive info should include num_archives")
	assert(info.num_archives == 0, "Should have 0 archives initially")
	
	return true

func test_vp_manager_file_resolution() -> bool:
	"""Test file resolution across multiple archives."""
	
	# Test file existence checking
	var has_file: bool = vp_manager.has_file("nonexistent.txt")
	assert(not has_file, "Should not find non-existent file")
	
	var file_list: Array[String] = vp_manager.get_file_list()
	assert(file_list.is_empty(), "Should have empty file list with no archives")
	
	return true

## Table Parser Tests

func test_table_parser_creation() -> bool:
	"""Test table parser creation and initialization."""
	
	assert(table_parser != null, "TableParser should be created")
	assert(table_parser.parsed_tables.is_empty(), "Should have no parsed tables initially")
	assert(table_parser.parse_errors.is_empty(), "Should have no parse errors initially")
	
	return true

func test_table_parsing_basic() -> bool:
	"""Test basic table file parsing."""
	
	var test_content: String = """
; Test table file
$Name: Test Ship
$Mass: 100.5
$Max Velocity: 50 60 70
"""
	
	var result: Dictionary = table_parser.parse_table_file(test_content, "test_ships")
	assert(not result.is_empty(), "Should parse basic table content")
	assert(result.has("table_name"), "Result should include table name")
	assert(result.table_name == "test_ships", "Table name should match")
	
	return true

func test_table_parsing_errors() -> bool:
	"""Test table parser error handling."""
	
	# Test empty content
	var empty_result: Dictionary = table_parser.parse_table_file("", "empty")
	assert(empty_result.is_empty(), "Should return empty result for empty content")
	
	# Test malformed content  
	var malformed_content: String = "This is not a valid table file!!!"
	var malformed_result: Dictionary = table_parser.parse_table_file(malformed_content, "malformed")
	# Parser should handle malformed content gracefully
	
	return true

func test_table_tokenization() -> bool:
	"""Test table file tokenization."""
	
	var simple_content: String = "$Name: \"Test Value\" 123"
	var result: Dictionary = table_parser.parse_table_file(simple_content, "tokenize_test")
	
	# Should successfully tokenize basic content
	assert(not result.is_empty(), "Should tokenize simple content")
	
	return true

## Asset Manager Tests

func test_asset_manager_initialization() -> bool:
	"""Test asset manager initialization."""
	
	assert(asset_manager != null, "AssetManager should be created")
	
	# Test debug stats
	var stats: Dictionary = asset_manager.get_debug_stats()
	assert(stats.has("loaded_vp_archives"), "Debug stats should include VP archive count")
	assert(stats.has("cached_assets"), "Debug stats should include cached asset count")
	assert(stats.loaded_vp_archives == 0, "Should have 0 VP archives initially")
	assert(stats.cached_assets == 0, "Should have 0 cached assets initially")
	
	return true

func test_asset_loading_interface() -> bool:
	"""Test asset loading interface."""
	
	# Test non-existent asset
	var asset: Resource = asset_manager.load_asset("nonexistent.txt")
	assert(asset == null, "Should return null for non-existent asset")
	
	# Test asset existence checking
	var has_asset: bool = asset_manager.has_asset("nonexistent.txt")
	assert(not has_asset, "Should not have non-existent asset")
	
	# Test asset info
	var info: Dictionary = asset_manager.get_asset_info("nonexistent.txt")
	assert(info.has("source"), "Asset info should include source")
	assert(info.source == "not_found", "Non-existent asset should have 'not_found' source")
	
	return true

func test_asset_caching() -> bool:
	"""Test asset caching functionality."""
	
	# Test cache stats
	var initial_stats: Dictionary = asset_manager.get_cache_stats()
	assert(initial_stats.cached_assets == 0, "Should start with empty cache")
	assert(initial_stats.cache_hits == 0, "Should start with no cache hits")
	assert(initial_stats.cache_misses == 0, "Should start with no cache misses")
	
	# Test cache clearing
	asset_manager.clear_cache()
	var cleared_stats: Dictionary = asset_manager.get_cache_stats()
	assert(cleared_stats.cached_assets == 0, "Cache should be empty after clearing")
	
	return true

func test_migration_interface() -> bool:
	"""Test asset migration interface."""
	
	# Test migration of non-existent asset
	var success: bool = asset_manager.migrate_asset("nonexistent.pof")
	assert(not success, "Should fail to migrate non-existent asset")
	
	# Test batch migration
	var migrated_count: int = asset_manager.batch_migrate_by_type("models")
	assert(migrated_count == 0, "Should migrate 0 models with no VP archives")
	
	return true

## Resource Creation Tests

func test_ship_data_resource() -> bool:
	"""Test ShipData resource creation and functionality."""
	
	var ship: ShipData = ShipData.new()
	assert(ship != null, "ShipData should be created")
	
	# Test default values
	assert(ship.ship_name.is_empty(), "Ship name should be empty initially")
	assert(ship.mass == 100.0, "Mass should have default value")
	assert(ship.max_hull_strength == 100.0, "Hull strength should have default value")
	
	# Test utility functions
	assert(ship.get_max_speed() == 50.0, "Max speed should match max_vel.z")
	assert(not ship.is_fighter_class(), "Should not be fighter class with default type")
	assert(ship.get_threat_level() > 0, "Threat level should be calculated")
	
	# Test data setting
	ship.ship_name = "Test Fighter"
	ship.ship_class_type = "fighter"
	assert(ship.ship_name == "Test Fighter", "Ship name should be set")
	assert(ship.is_fighter_class(), "Should be fighter class after setting type")
	
	return true

func test_weapon_data_resource() -> bool:
	"""Test WeaponData resource creation and functionality."""
	
	var weapon: WeaponData = WeaponData.new()
	assert(weapon != null, "WeaponData should be created")
	
	# Test default values
	assert(weapon.weapon_name.is_empty(), "Weapon name should be empty initially")
	assert(weapon.subtype == "Primary", "Should default to Primary type")
	assert(weapon.damage == 10.0, "Should have default damage value")
	
	# Test utility functions
	assert(weapon.is_primary_weapon(), "Should be primary weapon by default")
	assert(not weapon.is_secondary_weapon(), "Should not be secondary weapon by default")
	assert(not weapon.is_homing_weapon(), "Should not be homing weapon by default")
	assert(weapon.get_dps() > 0, "DPS should be calculated")
	
	# Test secondary weapon
	weapon.subtype = "Secondary"
	weapon.homing_type = "heat"
	weapon.turn_rate = 180.0
	assert(weapon.is_secondary_weapon(), "Should be secondary weapon after setting")
	assert(weapon.is_homing_weapon(), "Should be homing weapon with turn rate")
	
	return true

## Integration Tests

func test_full_pipeline_integration() -> bool:
	"""Test integration between all asset pipeline components."""
	
	# Test that all components can work together
	var vp_info: Dictionary = asset_manager.vp_manager.get_archive_info()
	var cache_stats: Dictionary = asset_manager.get_cache_stats()
	var debug_stats: Dictionary = asset_manager.get_debug_stats()
	
	# Verify data consistency
	assert(vp_info.num_archives == debug_stats.loaded_vp_archives, 
		"VP archive count should be consistent")
	assert(cache_stats.cached_assets == debug_stats.cached_assets,
		"Cached asset count should be consistent")
	
	return true

func test_error_handling() -> bool:
	"""Test error handling across the asset pipeline."""
	
	# Test VP archive error handling
	var invalid_load: bool = vp_archive.load_archive("nonexistent.vp")
	assert(not invalid_load, "Should handle non-existent VP file gracefully")
	
	# Test table parser error handling
	var invalid_parse: Dictionary = table_parser.parse_table_file("", "empty")
	assert(invalid_parse.is_empty(), "Should handle empty table content gracefully")
	
	# Test asset manager error handling
	var invalid_asset: Resource = asset_manager.load_asset("nonexistent.asset")
	assert(invalid_asset == null, "Should handle non-existent asset gracefully")
	
	return true

## Utility functions for tests

func _create_test_data() -> void:
	"""Create test data for various tests."""
	
	# Create minimal VP header data
	test_vp_data = PackedByteArray()
	test_vp_data.append_array("VPVP".to_utf8_buffer())  # Magic
	test_vp_data.append_array(_int32_to_bytes(2117))    # Version
	test_vp_data.append_array(_int32_to_bytes(16))      # Index offset  
	test_vp_data.append_array(_int32_to_bytes(0))       # Num files
	
	# Create test table content
	test_table_content = """
; Test ships table
$Name: Test Fighter
	$Mass: 75.0
	$Max Velocity: 65 65 80
	$Hull Strength: 120
	$Shield Strength: 80

$Name: Test Bomber  
	$Mass: 150.0
	$Max Velocity: 45 45 60
	$Hull Strength: 200
	$Shield Strength: 120
"""

func _int32_to_bytes(value: int) -> PackedByteArray:
	"""Convert int32 to little-endian byte array."""
	
	var bytes: PackedByteArray = PackedByteArray()
	bytes.append(value & 0xFF)
	bytes.append((value >> 8) & 0xFF)
	bytes.append((value >> 16) & 0xFF)
	bytes.append((value >> 24) & 0xFF)
	return bytes

func _save_test_file(path: String, data: PackedByteArray) -> bool:
	"""Save test data to a file."""
	
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	
	file.store_buffer(data)
	file.close()
	return true

## Test Runner

func run_all_tests() -> Dictionary:
	"""Run all asset pipeline tests and return results."""
	
	var results: Dictionary = {
		"total": 0,
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	
	var tests: Array[String] = [
		"test_vp_archive_creation",
		"test_vp_archive_header_validation",
		"test_vp_file_extraction",
		"test_vp_manager_creation",
		"test_vp_manager_precedence", 
		"test_vp_manager_file_resolution",
		"test_table_parser_creation",
		"test_table_parsing_basic",
		"test_table_parsing_errors",
		"test_table_tokenization",
		"test_asset_manager_initialization",
		"test_asset_loading_interface",
		"test_asset_caching",
		"test_migration_interface",
		"test_ship_data_resource",
		"test_weapon_data_resource",
		"test_full_pipeline_integration",
		"test_error_handling"
	]
	
	for test_name in tests:
		results.total += 1
		before_each()
		
		var success: bool = false
		if has_method(test_name):
			success = call(test_name)
		else:
			success = false
			results.failures.append(test_name + ": Method not found")
		
		if success:
			results.passed += 1
			print("✓ " + test_name)
		else:
			results.failed += 1
			results.failures.append(test_name + ": Test assertion failed")
			print("✗ " + test_name)
		
		after_each()
	
	print("\nAsset Pipeline Test Results: %d/%d passed" % [results.passed, results.total])
	if results.failed > 0:
		print("Failures:")
		for failure in results.failures:
			print("  - " + failure)
	
	return results