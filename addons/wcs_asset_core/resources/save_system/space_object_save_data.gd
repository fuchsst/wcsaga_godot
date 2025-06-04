class_name SpaceObjectSaveData
extends Resource

## Resource for saving BaseSpaceObject state in save games
## Integrates with SaveGameManager for mission and campaign persistence
## Provides efficient serialization for space object collections

# Asset core integration
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const ValidationResult = preload("res://addons/wcs_asset_core/structures/validation_result.gd")

# Save data versioning
@export var save_version: int = 1
@export var save_timestamp: int = 0

# Object collection metadata
@export var total_objects: int = 0
@export var object_types_count: Dictionary = {}  # ObjectType -> count mapping
@export var serialization_options: Dictionary = {}

# Serialized object data
@export var objects_data: Array[Dictionary] = []
@export var relationships_data: Dictionary = {}
@export var performance_metadata: Dictionary = {}

# Incremental save support
@export var last_full_save_timestamp: int = 0
@export var state_hashes: Dictionary = {}  # object_id -> state_hash mapping
@export var changed_objects_only: bool = false

# Validation and integrity
@export var data_checksum: String = ""
@export var compression_used: bool = false

func _init() -> void:
	save_timestamp = Time.get_unix_time_from_system()

## Initialize from object collection
func initialize_from_objects(objects: Array[BaseSpaceObject], options: Dictionary = {}) -> void:
	# Import ObjectSerialization class for access to serialization functions
	var ObjectSerialization = preload("res://scripts/core/objects/object_serialization.gd")
	
	total_objects = objects.size()
	serialization_options = options.duplicate(true)
	save_timestamp = Time.get_unix_time_from_system()
	
	# Count objects by type
	_count_objects_by_type(objects)
	
	# Serialize object collection
	var collection_data: Dictionary = ObjectSerialization.serialize_object_collection(objects, options)
	
	objects_data = collection_data.get("objects", [])
	relationships_data = collection_data.get("relationships", {})
	
	# Extract state hashes for incremental saves
	_extract_state_hashes()
	
	# Generate checksum for integrity verification
	_generate_data_checksum()
	
	# Record performance metadata
	performance_metadata = ObjectSerialization.get_performance_statistics()

## Restore objects from save data (AC3: Recreate with identical state)
func restore_objects(parent_node: Node = null) -> Array[BaseSpaceObject]:
	var ObjectSerialization = preload("res://scripts/core/objects/object_serialization.gd")
	
	# Validate save data integrity first
	var validation_result: ValidationResult = validate_save_data()
	if not validation_result.is_valid:
		push_error("SpaceObjectSaveData: Cannot restore objects - validation failed: %s" % str(validation_result.errors))
		return []
	
	# Reconstruct collection data format
	var collection_data: Dictionary = {
		"serialization_version": save_version,
		"collection_timestamp": save_timestamp,
		"object_count": total_objects,
		"objects": objects_data,
		"relationships": relationships_data
	}
	
	# Deserialize object collection
	var restored_objects: Array[BaseSpaceObject] = ObjectSerialization.deserialize_object_collection(collection_data, parent_node)
	
	if restored_objects.size() != total_objects:
		push_warning("SpaceObjectSaveData: Restored %d objects, expected %d" % [restored_objects.size(), total_objects])
	
	return restored_objects

## Update save data with changed objects only (AC4: Incremental saves)
func update_with_changed_objects(objects: Array[BaseSpaceObject], last_save_data: SpaceObjectSaveData) -> void:
	var ObjectSerialization = preload("res://scripts/core/objects/object_serialization.gd")
	
	# Get objects that have changed since last save
	var last_hashes: Dictionary = last_save_data.state_hashes if last_save_data else {}
	var changed_objects: Array[BaseSpaceObject] = []
	
	for obj in objects:
		if obj:
			var obj_id: String = str(obj.get_object_id())
			var last_hash: String = last_hashes.get(obj_id, "")
			
			if ObjectSerialization.has_object_changed(obj, last_hash):
				changed_objects.append(obj)
	
	# Mark as incremental save
	changed_objects_only = true
	last_full_save_timestamp = last_save_data.save_timestamp if last_save_data else 0
	
	# Initialize from changed objects only
	initialize_from_objects(changed_objects, serialization_options)

## Merge incremental save with base save data
func merge_with_base_save_data(base_save_data: SpaceObjectSaveData) -> SpaceObjectSaveData:
	if not changed_objects_only or not base_save_data:
		return self  # Return self if not incremental or no base data
	
	var merged_save_data = get_script().new()
	
	# Copy base data
	merged_save_data.objects_data = base_save_data.objects_data.duplicate(true)
	merged_save_data.relationships_data = base_save_data.relationships_data.duplicate(true)
	merged_save_data.state_hashes = base_save_data.state_hashes.duplicate(true)
	
	# Apply incremental changes
	for obj_data in objects_data:
		var obj_id: String = str(obj_data.get("object_id", -1))
		
		# Find and replace existing object data
		var found_index: int = -1
		for i in range(merged_save_data.objects_data.size()):
			var existing_obj_data: Dictionary = merged_save_data.objects_data[i]
			if str(existing_obj_data.get("object_id", -1)) == obj_id:
				found_index = i
				break
		
		if found_index >= 0:
			# Update existing object
			merged_save_data.objects_data[found_index] = obj_data.duplicate(true)
		else:
			# Add new object
			merged_save_data.objects_data.append(obj_data.duplicate(true))
	
	# Update metadata
	merged_save_data.total_objects = merged_save_data.objects_data.size()
	merged_save_data.save_timestamp = save_timestamp
	merged_save_data.changed_objects_only = false
	merged_save_data._count_objects_by_type_from_data()
	merged_save_data._extract_state_hashes()
	merged_save_data._generate_data_checksum()
	
	return merged_save_data

## Validate save data integrity (AC5: Data integrity validation)
func validate_save_data() -> ValidationResult:
	var result: ValidationResult = ValidationResult.new("", "Space Object Save Data")
	
	# Check basic structure
	if total_objects < 0:
		result.add_error("Invalid total_objects count: %d" % total_objects)
	
	if objects_data.size() != total_objects:
		result.add_error("Objects data size mismatch: expected %d, got %d" % [total_objects, objects_data.size()])
	
	if save_timestamp <= 0:
		result.add_error("Invalid save timestamp: %d" % save_timestamp)
	
	# Validate checksum if present
	if not data_checksum.is_empty():
		var calculated_checksum: String = _calculate_data_checksum()
		if calculated_checksum != data_checksum:
			result.add_error("Data checksum mismatch - data may be corrupted")
	
	# Validate object data structure
	var validation_errors: int = 0
	for i in range(objects_data.size()):
		var obj_data: Dictionary = objects_data[i]
		var obj_validation: Array[String] = _validate_object_data(obj_data, i)
		
		for error in obj_validation:
			result.add_error("Object %d: %s" % [i, error])
			validation_errors += 1
		
		# Limit error reporting to prevent spam
		if validation_errors > 10:
			result.add_warning("Additional object validation errors suppressed (>10 errors)")
			break
	
	# Validate type counts
	var actual_counts: Dictionary = {}
	for obj_data in objects_data:
		var obj_type: int = obj_data.get("critical", {}).get("object_type_enum", -1)
		if obj_type >= 0:
			actual_counts[obj_type] = actual_counts.get(obj_type, 0) + 1
	
	for type_id in object_types_count:
		var expected_count: int = object_types_count[type_id]
		var actual_count: int = actual_counts.get(type_id, 0)
		if expected_count != actual_count:
			result.add_warning("Type %d count mismatch: expected %d, actual %d" % [type_id, expected_count, actual_count])
	
	return result

## Get summary information for save slot display
func get_save_summary() -> Dictionary:
	return {
		"total_objects": total_objects,
		"object_types": object_types_count.duplicate(),
		"save_timestamp": save_timestamp,
		"save_age_seconds": Time.get_unix_time_from_system() - save_timestamp,
		"is_incremental": changed_objects_only,
		"data_size_bytes": _estimate_data_size(),
		"compression_used": compression_used,
		"validation_status": "valid" if validate_save_data().is_valid else "invalid"
	}

## Export to dictionary for external serialization
func export_to_dictionary() -> Dictionary:
	return {
		"save_version": save_version,
		"save_timestamp": save_timestamp,
		"total_objects": total_objects,
		"object_types_count": object_types_count.duplicate(true),
		"serialization_options": serialization_options.duplicate(true),
		"objects_data": objects_data.duplicate(true),
		"relationships_data": relationships_data.duplicate(true),
		"performance_metadata": performance_metadata.duplicate(true),
		"last_full_save_timestamp": last_full_save_timestamp,
		"state_hashes": state_hashes.duplicate(true),
		"changed_objects_only": changed_objects_only,
		"data_checksum": data_checksum,
		"compression_used": compression_used
	}

## Import from dictionary for external deserialization
func import_from_dictionary(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	
	save_version = data.get("save_version", 1)
	save_timestamp = data.get("save_timestamp", 0)
	total_objects = data.get("total_objects", 0)
	object_types_count = data.get("object_types_count", {})
	serialization_options = data.get("serialization_options", {})
	objects_data = data.get("objects_data", [])
	relationships_data = data.get("relationships_data", {})
	performance_metadata = data.get("performance_metadata", {})
	last_full_save_timestamp = data.get("last_full_save_timestamp", 0)
	state_hashes = data.get("state_hashes", {})
	changed_objects_only = data.get("changed_objects_only", false)
	data_checksum = data.get("data_checksum", "")
	compression_used = data.get("compression_used", false)
	
	# Validate imported data
	var validation_result: ValidationResult = validate_save_data()
	if not validation_result.is_valid:
		push_error("SpaceObjectSaveData: Import validation failed: %s" % str(validation_result.errors))
		return false
	
	return true

## Clone this save data
func clone() -> SpaceObjectSaveData:
	var cloned = get_script().new()
	cloned.import_from_dictionary(export_to_dictionary())
	return cloned

# --- Internal Helper Functions ---

## Count objects by type for metadata
func _count_objects_by_type(objects: Array[BaseSpaceObject]) -> void:
	object_types_count.clear()
	
	for obj in objects:
		if obj:
			var obj_type: int = obj.object_type_enum
			object_types_count[obj_type] = object_types_count.get(obj_type, 0) + 1

## Count objects by type from serialized data
func _count_objects_by_type_from_data() -> void:
	object_types_count.clear()
	
	for obj_data in objects_data:
		var critical_data: Dictionary = obj_data.get("critical", {})
		var obj_type: int = critical_data.get("object_type_enum", -1)
		
		if obj_type >= 0:
			object_types_count[obj_type] = object_types_count.get(obj_type, 0) + 1

## Extract state hashes from serialized data for incremental saves
func _extract_state_hashes() -> void:
	state_hashes.clear()
	
	for obj_data in objects_data:
		var obj_id: String = str(obj_data.get("critical", {}).get("object_id", -1))
		var state_hash: String = obj_data.get("state_hash", "")
		
		if not obj_id.is_empty() and not state_hash.is_empty():
			state_hashes[obj_id] = state_hash

## Generate checksum for data integrity verification
func _generate_data_checksum() -> void:
	data_checksum = _calculate_data_checksum()

## Calculate checksum of current data
func _calculate_data_checksum() -> String:
	var checksum_data: String = ""
	
	# Include critical save data in checksum
	checksum_data += str(save_version)
	checksum_data += str(save_timestamp)
	checksum_data += str(total_objects)
	
	# Include object data in checksum (use JSON for consistency)
	var json_data: String = JSON.stringify(objects_data)
	checksum_data += json_data
	
	# Generate hash
	return checksum_data.sha256_text()

## Validate individual object data structure
func _validate_object_data(obj_data: Dictionary, index: int) -> Array[String]:
	var errors: Array[String] = []
	
	# Check for required top-level fields
	if not obj_data.has("critical"):
		errors.append("Missing critical state data")
	
	if not obj_data.has("serialization_version"):
		errors.append("Missing serialization version")
	
	# Validate critical state
	if obj_data.has("critical"):
		var critical: Dictionary = obj_data["critical"]
		
		if not critical.has("object_id"):
			errors.append("Critical state missing object_id")
		
		if not critical.has("object_type"):
			errors.append("Critical state missing object_type")
		
		if not critical.has("object_type_enum"):
			errors.append("Critical state missing object_type_enum")
		
		if not critical.has("global_position"):
			errors.append("Critical state missing global_position")
	
	# Validate physics state if present
	if obj_data.has("physics"):
		var physics: Dictionary = obj_data["physics"]
		
		if not physics.has("linear_velocity"):
			errors.append("Physics state missing linear_velocity")
		
		if not physics.has("angular_velocity"):
			errors.append("Physics state missing angular_velocity")
	
	return errors

## Estimate data size for performance tracking
func _estimate_data_size() -> int:
	var size_bytes: int = 0
	
	# Estimate based on JSON representation
	var json_string: String = JSON.stringify(export_to_dictionary())
	size_bytes = json_string.length()
	
	return size_bytes