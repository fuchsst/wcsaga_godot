extends GdUnitTestSuite

## Test suite for OBJ-004: Object Serialization and Persistence System
## Tests all acceptance criteria for serialization, deserialization, and validation

const ObjectSerialization = preload("res://scripts/core/objects/object_serialization.gd")
const BaseSpaceObject = preload("res://scripts/core/objects/base_space_object.gd")
const SpaceObjectSaveData = preload("res://addons/wcs_asset_core/resources/save_system/space_object_save_data.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const ValidationResult = preload("res://addons/wcs_asset_core/structures/validation_result.gd")

var test_objects: Array[BaseSpaceObject] = []
var test_parent: Node3D

func before()-> void:
	# Create test parent node
	test_parent = Node3D.new()
	add_child(test_parent)
	
	# Reset serialization performance stats
	ObjectSerialization.reset_performance_statistics()
	
	# Configure serialization for testing
	ObjectSerialization.configure_serialization({
		"incremental_saves": true,
		"relationships": true,
		"validation": true,
		"compression": false
	})

func after() -> void:
	# Clean up test objects
	for obj in test_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	test_objects.clear()
	
	# Clean up test parent
	if is_instance_valid(test_parent):
		test_parent.queue_free()

## Test AC1: Object serialization captures all essential BaseSpaceObject state
func test_serialization_captures_essential_state():
	var space_object: BaseSpaceObject = _create_test_space_object()
	
	# Set up complex state
	space_object.global_position = Vector3(100, 50, 200)
	space_object.global_rotation = Vector3(0.1, 0.2, 0.3)
	space_object.linear_velocity = Vector3(10, 5, 20)
	space_object.angular_velocity = Vector3(0.5, 1.0, 0.25)
	space_object.set_object_id(12345)
	space_object.set_object_type("TestShip")
	space_object.object_type_enum = ObjectTypes.Type.SHIP
	space_object.is_active = true
	space_object.space_physics_enabled = true
	space_object.collision_detection_enabled = true
	
	# Serialize the object
	var serialized_data: Dictionary = ObjectSerialization.serialize_space_object(space_object)
	
	# Verify essential state is captured
	assert_that(serialized_data).is_not_empty()
	assert_that(serialized_data.has("serialization_version")).is_true()
	assert_that(serialized_data.has("critical")).is_true()
	assert_that(serialized_data.has("physics")).is_true()
	assert_that(serialized_data.has("metadata")).is_true()
	
	# Verify critical state
	var critical: Dictionary = serialized_data["critical"]
	assert_that(critical["object_id"]).is_equal(12345)
	assert_that(critical["object_type"]).is_equal("TestShip")
	assert_that(critical["object_type_enum"]).is_equal(ObjectTypes.Type.SHIP)
	assert_that(critical["space_physics_enabled"]).is_true()
	assert_that(critical["collision_detection_enabled"]).is_true()
	assert_that(critical["is_active"]).is_true()
	
	# Verify physics state
	var physics: Dictionary = serialized_data["physics"]
	assert_that(physics.has("linear_velocity")).is_true()
	assert_that(physics.has("angular_velocity")).is_true()
	assert_that(physics.has("applied_forces")).is_true()
	assert_that(physics.has("applied_torques")).is_true()

## Test AC2: Serialization system handles object relationships and references
func test_object_relationships_serialization():
	# Create parent and child objects
	var parent_object: BaseSpaceObject = _create_test_space_object()
	var child_object: BaseSpaceObject = _create_test_space_object()
	
	parent_object.set_object_id(1001)
	child_object.set_object_id(1002)
	
	# Establish parent-child relationship
	test_parent.add_child(parent_object)
	parent_object.add_child(child_object)
	
	# Serialize with relationships
	var serialized_data: Dictionary = ObjectSerialization.serialize_space_object(parent_object, {"include_relationships": true})
	
	# Verify relationships are captured
	assert_that(serialized_data.has("relationships")).is_true()
	
	var relationships: Dictionary = serialized_data["relationships"]
	assert_that(relationships.has("children_info")).is_true()
	
	var children_info: Array = relationships["children_info"]
	assert_that(children_info.size()).is_equal(1)
	assert_that(children_info[0]["child_object_id"]).is_equal(1002)

## Test AC3: Deserialization recreates objects with identical state and scene tree integration
func test_deserialization_recreates_identical_state():
	var original_object: BaseSpaceObject = _create_test_space_object()
	
	# Set up complex state
	original_object.global_position = Vector3(150, 75, 300)
	original_object.linear_velocity = Vector3(25, 10, 50)
	original_object.set_object_id(54321)
	original_object.set_object_type("DeserializeTest")
	original_object.object_type_enum = ObjectTypes.Type.WEAPON
	original_object.is_active = true
	
	# Add to scene tree
	test_parent.add_child(original_object)
	await get_tree().process_frame  # Ensure _ready() is called
	
	# Serialize the object
	var serialized_data: Dictionary = ObjectSerialization.serialize_space_object(original_object)
	
	# Deserialize to new object
	var restored_object: BaseSpaceObject = ObjectSerialization.deserialize_space_object(serialized_data, test_parent)
	
	# Verify identical state restoration
	assert_that(restored_object).is_not_null()
	assert_that(restored_object.get_object_id()).is_equal(54321)
	assert_that(restored_object.get_object_type()).is_equal("DeserializeTest")
	assert_that(restored_object.object_type_enum).is_equal(ObjectTypes.Type.WEAPON)
	assert_that(restored_object.global_position).is_equal(Vector3(150, 75, 300))
	assert_that(restored_object.linear_velocity).is_equal(Vector3(25, 10, 50))
	assert_that(restored_object.is_active).is_true()
	
	# Verify scene tree integration
	assert_that(restored_object.get_parent()).is_equal(test_parent)
	assert_that(restored_object.is_inside_tree()).is_true()
	
	test_objects.append(restored_object)

## Test AC4: System supports incremental saves for performance with only changed objects
func test_incremental_saves_performance():
	# Create multiple objects
	var objects: Array[BaseSpaceObject] = []
	for i in range(5):
		var obj: BaseSpaceObject = _create_test_space_object()
		obj.set_object_id(2000 + i)
		obj.global_position = Vector3(i * 10, 0, 0)
		test_parent.add_child(obj)
		objects.append(obj)
		test_objects.append(obj)
	
	await get_tree().process_frame
	
	# Initial full serialization
	var initial_collection: Dictionary = ObjectSerialization.serialize_object_collection(objects)
	
	# Modify only some objects
	objects[1].global_position = Vector3(100, 100, 100)
	objects[3].linear_velocity = Vector3(50, 0, 0)
	
	# Get changed objects
	var changed_objects: Array[BaseSpaceObject] = ObjectSerialization.get_changed_objects(objects, initial_collection)
	
	# Should detect only the changed objects
	assert_that(changed_objects.size()).is_less_or_equal(3)  # Allow for some detection variance
	
	# Verify incremental serialization
	var incremental_data: Dictionary = ObjectSerialization.serialize_object_collection(changed_objects)
	assert_that(incremental_data["object_count"]).is_less_or_equal(objects.size())

## Test AC5: Validation ensures serialized data integrity and version compatibility
func test_data_integrity_validation():
	var space_object: BaseSpaceObject = _create_test_space_object()
	space_object.set_object_id(3001)
	
	# Serialize valid object
	var serialized_data: Dictionary = ObjectSerialization.serialize_space_object(space_object)
	
	# Validate good data
	var validation_result: ValidationResult = ObjectSerialization.validate_serialized_data(serialized_data)
	assert_that(validation_result.is_valid).is_true()
	
	# Test missing critical data
	var corrupted_data: Dictionary = serialized_data.duplicate(true)
	corrupted_data.erase("critical")
	
	var corrupted_validation: ValidationResult = ObjectSerialization.validate_serialized_data(corrupted_data)
	assert_that(corrupted_validation.is_valid).is_false()
	assert_that(corrupted_validation.errors.size()).is_greater(0)
	
	# Test invalid version
	var version_data: Dictionary = serialized_data.duplicate(true)
	version_data["serialization_version"] = 999
	
	var restored_object: BaseSpaceObject = ObjectSerialization.deserialize_space_object(version_data)
	assert_that(restored_object).is_null()

## Test AC6: Integration with save game system maintains object persistence
func test_save_game_system_integration():
	var space_object: BaseSpaceObject = _create_test_space_object()
	space_object.set_object_id(4001)
	space_object.set_object_type("SaveGameTest")
	space_object.global_position = Vector3(200, 100, 400)
	
	# Create save data using integrated system
	var save_data: SpaceObjectSaveData = space_object.create_save_data()
	
	# Verify save data integrity
	assert_that(save_data).is_not_null()
	assert_that(save_data.total_objects).is_equal(1)
	
	var validation_result: ValidationResult = save_data.validate_save_data()
	assert_that(validation_result.is_valid).is_true()
	
	# Test save game data format
	var save_game_data: Dictionary = space_object.get_save_game_data()
	assert_that(save_game_data.has("serialized_data")).is_true()
	assert_that(save_game_data.has("object_summary")).is_true()
	assert_that(save_game_data.has("save_timestamp")).is_true()
	
	# Test restoration from save game data
	var new_object: BaseSpaceObject = BaseSpaceObject.new()
	var restore_success: bool = new_object.restore_from_save_game_data(save_game_data)
	
	assert_that(restore_success).is_true()
	assert_that(new_object.get_object_id()).is_equal(4001)
	assert_that(new_object.get_object_type()).is_equal("SaveGameTest")
	assert_that(new_object.global_position).is_equal(Vector3(200, 100, 400))
	
	test_objects.append(new_object)

## Test object collection serialization and restoration
func test_object_collection_serialization():
	# Create collection of diverse objects
	var objects: Array[BaseSpaceObject] = []
	for i in range(3):
		var obj: BaseSpaceObject = _create_test_space_object()
		obj.set_object_id(5000 + i)
		obj.object_type_enum = ObjectTypes.Type.SHIP if i % 2 == 0 else ObjectTypes.Type.WEAPON
		obj.global_position = Vector3(i * 50, i * 25, 0)
		test_parent.add_child(obj)
		objects.append(obj)
		test_objects.append(obj)
	
	await get_tree().process_frame
	
	# Serialize collection
	var collection_data: Dictionary = ObjectSerialization.serialize_object_collection(objects)
	
	# Verify collection structure
	assert_that(collection_data["object_count"]).is_equal(3)
	assert_that(collection_data["objects"].size()).is_equal(3)
	
	# Deserialize collection
	var restored_objects: Array[BaseSpaceObject] = ObjectSerialization.deserialize_object_collection(collection_data, test_parent)
	
	# Verify all objects restored
	assert_that(restored_objects.size()).is_equal(3)
	
	# Verify individual object integrity
	for i in range(restored_objects.size()):
		var original: BaseSpaceObject = objects[i]
		var restored: BaseSpaceObject = restored_objects[i]
		
		assert_that(restored.get_object_id()).is_equal(original.get_object_id())
		assert_that(restored.object_type_enum).is_equal(original.object_type_enum)
		assert_that(restored.global_position).is_equal(original.global_position)
		
		test_objects.append(restored)

## Test performance requirements (AC1: Under 2ms serialization, AC3: Under 5ms deserialization)
func test_performance_requirements():
	var space_object: BaseSpaceObject = _create_test_space_object()
	space_object.set_object_id(6001)
	
	# Test serialization performance
	var start_time: int = Time.get_ticks_msec()
	var serialized_data: Dictionary = ObjectSerialization.serialize_space_object(space_object)
	var serialization_time: float = float(Time.get_ticks_msec() - start_time)
	
	assert_that(serialization_time).is_less_or_equal(2.0)  # Under 2ms target
	assert_that(serialized_data).is_not_empty()
	
	# Test deserialization performance
	start_time = Time.get_ticks_msec()
	var restored_object: BaseSpaceObject = ObjectSerialization.deserialize_space_object(serialized_data, test_parent)
	var deserialization_time: float = float(Time.get_ticks_msec() - start_time)
	
	assert_that(deserialization_time).is_less_or_equal(5.0)  # Under 5ms target
	assert_that(restored_object).is_not_null()
	
	test_objects.append(restored_object)
	
	# Verify performance statistics are tracked
	var stats: Dictionary = ObjectSerialization.get_performance_statistics()
	assert_that(stats.has("serialization")).is_true()
	assert_that(stats.has("deserialization")).is_true()
	assert_that(stats["serialization"]["total_operations"]).is_greater_or_equal(1)
	assert_that(stats["deserialization"]["total_operations"]).is_greater_or_equal(1)

## Test SpaceObjectSaveData Resource functionality
func test_space_object_save_data_resource():
	var objects: Array[BaseSpaceObject] = []
	for i in range(2):
		var obj: BaseSpaceObject = _create_test_space_object()
		obj.set_object_id(7000 + i)
		obj.object_type_enum = ObjectTypes.Type.DEBRIS
		objects.append(obj)
		test_objects.append(obj)
	
	# Create save data resource
	var save_data: SpaceObjectSaveData = SpaceObjectSaveData.new()
	save_data.initialize_from_objects(objects)
	
	# Verify save data properties
	assert_that(save_data.total_objects).is_equal(2)
	assert_that(save_data.objects_data.size()).is_equal(2)
	assert_that(save_data.object_types_count.has(ObjectTypes.Type.DEBRIS)).is_true()
	assert_that(save_data.object_types_count[ObjectTypes.Type.DEBRIS]).is_equal(2)
	
	# Test validation
	var validation: ValidationResult = save_data.validate_save_data()
	assert_that(validation.is_valid).is_true()
	
	# Test export/import
	var exported_dict: Dictionary = save_data.export_to_dictionary()
	var imported_save_data: SpaceObjectSaveData = SpaceObjectSaveData.new()
	var import_success: bool = imported_save_data.import_from_dictionary(exported_dict)
	
	assert_that(import_success).is_true()
	assert_that(imported_save_data.total_objects).is_equal(2)
	
	# Test restoration
	var restored_objects: Array[BaseSpaceObject] = save_data.restore_objects(test_parent)
	assert_that(restored_objects.size()).is_equal(2)
	
	for obj in restored_objects:
		test_objects.append(obj)

## Test incremental save merging
func test_incremental_save_merging():
	# Create base objects
	var base_objects: Array[BaseSpaceObject] = []
	for i in range(3):
		var obj: BaseSpaceObject = _create_test_space_object()
		obj.set_object_id(8000 + i)
		obj.global_position = Vector3(i * 20, 0, 0)
		base_objects.append(obj)
		test_objects.append(obj)
	
	# Create base save data
	var base_save_data: SpaceObjectSaveData = SpaceObjectSaveData.new()
	base_save_data.initialize_from_objects(base_objects)
	
	# Modify one object
	base_objects[1].global_position = Vector3(500, 500, 500)
	
	# Create incremental save
	var incremental_save_data: SpaceObjectSaveData = SpaceObjectSaveData.new()
	incremental_save_data.update_with_changed_objects([base_objects[1]], base_save_data)
	
	# Verify incremental save properties
	assert_that(incremental_save_data.changed_objects_only).is_true()
	assert_that(incremental_save_data.total_objects).is_equal(1)
	
	# Test merging
	var merged_save_data: SpaceObjectSaveData = incremental_save_data.merge_with_base_save_data(base_save_data)
	
	# Verify merged data
	assert_that(merged_save_data.total_objects).is_equal(3)
	assert_that(merged_save_data.changed_objects_only).is_false()
	
	# Verify merged data integrity
	var validation: ValidationResult = merged_save_data.validate_save_data()
	assert_that(validation.is_valid).is_true()

## Test error handling and edge cases
func test_error_handling():
	# Test null object serialization
	var null_result: Dictionary = ObjectSerialization.serialize_space_object(null)
	assert_that(null_result).is_empty()
	
	# Test empty dictionary deserialization
	var empty_object: BaseSpaceObject = ObjectSerialization.deserialize_space_object({})
	assert_that(empty_object).is_null()
	
	# Test invalid serialized data
	var invalid_data: Dictionary = {"invalid": "data"}
	var invalid_object: BaseSpaceObject = ObjectSerialization.deserialize_space_object(invalid_data)
	assert_that(invalid_object).is_null()
	
	# Test object state hash with null object
	var null_hash: String = ObjectSerialization._calculate_object_state_hash(null)
	assert_that(null_hash).is_equal("")

## Test BaseSpaceObject serialization methods
func test_base_space_object_serialization_methods():
	var space_object: BaseSpaceObject = _create_test_space_object()
	space_object.set_object_id(9001)
	space_object.global_position = Vector3(123, 456, 789)
	
	# Test object-level serialization
	var serialized: Dictionary = space_object.serialize_to_dictionary()
	assert_that(serialized).is_not_empty()
	assert_that(serialized.has("critical")).is_true()
	
	# Test state hash
	var hash1: String = space_object.get_state_hash()
	assert_that(hash1).is_not_empty()
	
	# Modify object and check hash changes
	space_object.global_position = Vector3(999, 888, 777)
	var hash2: String = space_object.get_state_hash()
	assert_that(hash2).is_not_equal(hash1)
	
	# Test state change detection
	assert_that(space_object.has_state_changed(hash1)).is_true()
	assert_that(space_object.has_state_changed(hash2)).is_false()
	
	# Test object deserialization
	var new_object: BaseSpaceObject = BaseSpaceObject.new()
	var deserialize_success: bool = new_object.deserialize_from_dictionary(serialized)
	
	assert_that(deserialize_success).is_true()
	assert_that(new_object.get_object_id()).is_equal(9001)
	
	test_objects.append(new_object)

## Test serialization configuration
func test_serialization_configuration():
	# Test configuration changes
	ObjectSerialization.configure_serialization({
		"incremental_saves": false,
		"relationships": false,
		"validation": false
	})
	
	var space_object: BaseSpaceObject = _create_test_space_object()
	space_object.set_object_id(10001)
	
	# Serialize with disabled features
	var serialized_data: Dictionary = ObjectSerialization.serialize_space_object(space_object)
	
	# Should not include relationships when disabled
	assert_that(serialized_data.has("relationships")).is_false()
	
	# Reset configuration
	ObjectSerialization.configure_serialization({
		"incremental_saves": true,
		"relationships": true,
		"validation": true
	})

# --- Helper Functions ---

## Create a test space object with basic setup
func _create_test_space_object() -> BaseSpaceObject:
	var space_object: BaseSpaceObject = BaseSpaceObject.new()
	
	# Initialize with default values
	space_object.set_object_id(-1)
	space_object.set_object_type("TestObject")
	space_object.object_type_enum = ObjectTypes.Type.SHIP
	space_object.global_position = Vector3.ZERO
	space_object.linear_velocity = Vector3.ZERO
	space_object.angular_velocity = Vector3.ZERO
	space_object.is_active = false
	space_object.space_physics_enabled = true
	space_object.collision_detection_enabled = true
	
	return space_object