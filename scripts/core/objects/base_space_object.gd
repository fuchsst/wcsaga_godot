class_name BaseSpaceObject
extends WCSObject

## Enhanced space object with physics integration and asset core support
## Uses composition pattern with RigidBody3D for optimal Godot performance
## Integrates with EPIC-002 wcs_asset_core addon for type definitions and physics profiles

# EPIC-002 Asset Core Integration (MANDATORY for OBJ-001)
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")
const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")
const PhysicsProfile = preload("res://addons/wcs_asset_core/resources/object/physics_profile.gd")
const ObjectTypeData = preload("res://addons/wcs_asset_core/structures/object_type_data.gd")

# Enhanced Space Object Signals (OBJ-001 AC7)
signal object_destroyed(object: BaseSpaceObject)
signal collision_detected(other: BaseSpaceObject, collision_info: Dictionary)
signal physics_state_changed()
signal object_type_changed(old_type: int, new_type: int)
signal distance_threshold_changed(distance_level: int)

# COMPOSITION PATTERN - Physics components as child nodes (OBJ-001 AC1)
@export var physics_body: RigidBody3D
@export var collision_shape: CollisionShape3D
@export var mesh_instance: MeshInstance3D
@export var audio_source: AudioStreamPlayer3D

# Asset integration with type safety (OBJ-001 AC2 & AC5)
@export var object_type_enum: int = 0  # ObjectTypes.Type.NONE
var physics_profile = null  # PhysicsProfile type from wcs_asset_core
# var object_type_data: ObjectTypeData  # Will be added in OBJ-002
@export var collision_layer_bits: int = 0
@export var collision_mask_bits: int = 0

# Enhanced space object properties
@export var space_physics_enabled: bool = true
@export var collision_detection_enabled: bool = true

# Physics state
var linear_velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
var applied_forces: Array[Vector3] = []
var applied_torques: Array[Vector3] = []

# Lifecycle state
var is_active: bool = false
var destruction_pending: bool = false

func _init() -> void:
	# Initialize with proper asset core integration (OBJ-001 AC5)
	object_type_enum = ObjectTypes.Type.NONE
	object_type = ObjectTypes.get_type_name(object_type_enum)
	
	# Set default update frequency using asset core constants
	update_frequency = UpdateFrequencies.get_update_interval_ms(UpdateFrequencies.Frequency.MEDIUM)

func _ready() -> void:
	super._ready()
	
	if not _setup_physics_composition():
		push_error("BaseSpaceObject: Failed to setup physics composition")
		return
	
	_setup_asset_integration()
	_setup_signal_connections()
	_register_with_space_systems()

## Setup physics composition pattern with RigidBody3D (OBJ-001 AC1)
func _setup_physics_composition() -> bool:
	# Create RigidBody3D as child for physics simulation
	if not physics_body:
		physics_body = RigidBody3D.new()
		physics_body.name = "PhysicsBody"
		physics_body.gravity_scale = 0.0  # Space physics - no gravity
		physics_body.linear_damp = 0.1
		physics_body.angular_damp = 0.1
		add_child(physics_body)
	
	# Create collision shape as child of physics body
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape"
		# Default to sphere collision - will be overridden by physics profile
		var sphere_shape: SphereShape3D = SphereShape3D.new()
		sphere_shape.radius = 1.0
		collision_shape.shape = sphere_shape
		physics_body.add_child(collision_shape)
	
	# Create mesh instance for visuals
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance"
		physics_body.add_child(mesh_instance)
	
	# Create audio source for object sounds
	if not audio_source:
		audio_source = AudioStreamPlayer3D.new()
		audio_source.name = "AudioSource"
		physics_body.add_child(audio_source)
	
	return true

## Setup integration with wcs_asset_core addon (OBJ-001 AC2 & AC6)
func _setup_asset_integration() -> void:
	# Default collision configuration using asset core constants
	collision_layer_bits = CollisionLayers.create_layer_bit(CollisionLayers.Layer.SHIPS)
	collision_mask_bits = CollisionLayers.Mask.SHIP_STANDARD
	
	# Apply collision configuration to physics body
	if physics_body:
		physics_body.collision_layer = collision_layer_bits
		physics_body.collision_mask = collision_mask_bits

## Setup signal connections for space object behavior (OBJ-001 AC7)
func _setup_signal_connections() -> void:
	# Connect to physics body signals
	if physics_body:
		physics_body.body_entered.connect(_on_collision_body_entered)
		physics_body.body_exited.connect(_on_collision_body_exited)

## Register with space-specific systems (OBJ-001 AC8)
func _register_with_space_systems() -> void:
	pass
	# Register with ObjectManager using enhanced space object interface
	# TODO: Re-enable when ObjectManager compilation is fixed
	# if ObjectManager:
	#	 # Connect to ObjectManager signals for lifecycle coordination
	#	 object_destroyed.connect(ObjectManager._on_space_object_destroyed)

## Enhanced object initialization with physics profile (OBJ-001 AC3)
func initialize_space_object_enhanced(obj_type: int, physics_profile = null, object_data = null) -> void:
	var old_type: int = object_type_enum
	object_type_enum = obj_type
	object_type = ObjectTypes.get_type_name(obj_type)
	
	# Apply physics profile if provided
	if physics_profile:
		self.physics_profile = physics_profile
		_apply_physics_profile()
	else:
		_create_default_physics_profile()
	
	# Apply object data if provided (legacy support for WCSObjectData)
	if object_data:
		# Handle legacy WCSObjectData or dictionary data
		if object_data.has_method("get_object_type"):
			# This is likely WCSObjectData, extract relevant properties
			pass
		elif object_data is Dictionary:
			# Handle dictionary-based object data
			pass
	
	# Update collision configuration based on object type
	_update_collision_configuration()
	
	# Initialize as WCSObject
	initialize_default()
	
	# Emit type change signal
	if old_type != object_type_enum:
		object_type_changed.emit(old_type, object_type_enum)

## Legacy compatibility method
func initialize_space_object(space_data: WCSObjectData) -> void:
	initialize_from_data(space_data)
	
	# Apply space-specific properties
	if physics_body and space_data:
		physics_body.mass = space_data.mass
		linear_velocity = space_data.velocity
		angular_velocity = space_data.angular_velocity
		
		# Apply initial velocity to physics body
		physics_body.linear_velocity = linear_velocity
		physics_body.angular_velocity = angular_velocity
	
	is_active = true

## Activate the space object for simulation
func activate() -> void:
	if not is_active:
		is_active = true
		set_visible(true)
		
		if physics_body:
			physics_body.set_freeze_mode(RigidBody3D.FREEZE_MODE_KINEMATIC)
			physics_body.freeze = false
		
		# Register with enhanced force application system (OBJ-006)
		_register_force_application()
		
		# Register with ObjectManager
		# TODO: Re-enable when ObjectManager compilation is fixed
		# if ObjectManager:
		#	 ObjectManager.register_object(self)

## Deactivate the space object
func deactivate() -> void:
	if is_active:
		is_active = false
		set_visible(false)
		
		if physics_body:
			physics_body.freeze = true
		
		# Unregister from enhanced force application system (OBJ-006)
		_unregister_force_application()
		
		# Unregister from ObjectManager
		# TODO: Re-enable when ObjectManager compilation is fixed
		# if ObjectManager:
		#	 ObjectManager.unregister_object(self)

## Destroy the space object
func destroy() -> void:
	if not destruction_pending:
		destruction_pending = true
		object_destroyed.emit(self)
		
		# Clean up physics
		if physics_body:
			physics_body.linear_velocity = Vector3.ZERO
			physics_body.angular_velocity = Vector3.ZERO
		
		# Deactivate and queue for removal
		deactivate()
		queue_free()

## Apply physics profile to object configuration
func _apply_physics_profile() -> void:
	if not physics_profile or not physics_body:
		return
	
	# Apply physics properties
	physics_body.mass = physics_profile.mass
	physics_body.gravity_scale = physics_profile.gravity_scale
	physics_body.linear_damp = physics_profile.linear_damping
	physics_body.angular_damp = physics_profile.angular_damping
	
	# Apply collision configuration
	collision_layer_bits = physics_profile.collision_layer
	collision_mask_bits = physics_profile.collision_mask
	physics_body.collision_layer = collision_layer_bits
	physics_body.collision_mask = collision_mask_bits
	
	# Set physics behavior flags
	space_physics_enabled = physics_profile.is_physics_enabled()
	collision_detection_enabled = physics_profile.requires_collision_detection()

## Create default physics profile for object type
func _create_default_physics_profile() -> void:
	match object_type_enum:
		ObjectTypes.Type.SHIP, ObjectTypes.Type.FIGHTER, ObjectTypes.Type.BOMBER:
			physics_profile = PhysicsProfile.create_fighter_profile()
		ObjectTypes.Type.CAPITAL:
			physics_profile = PhysicsProfile.create_capital_profile()
		ObjectTypes.Type.WEAPON:
			physics_profile = PhysicsProfile.create_weapon_projectile_profile()
		ObjectTypes.Type.DEBRIS:
			physics_profile = PhysicsProfile.create_debris_profile()
		ObjectTypes.Type.BEAM:
			physics_profile = PhysicsProfile.create_beam_weapon_profile()
		ObjectTypes.Type.EFFECT:
			physics_profile = PhysicsProfile.create_effect_profile()
		_:
			physics_profile = PhysicsProfile.new()
	
	_apply_physics_profile()

## Apply object type data configuration
func _apply_object_type_data() -> void:
	# Note: object_type_data will be implemented in OBJ-002
	# This method is a placeholder for future ObjectTypeData integration
	pass

## Update collision configuration based on object type (OBJ-001 AC6)
func _update_collision_configuration() -> void:
	# Get appropriate collision layers for object type
	if ObjectTypes.is_ship_type(object_type_enum):
		collision_layer_bits = CollisionLayers.create_layer_bit(CollisionLayers.Layer.SHIPS)
		collision_mask_bits = CollisionLayers.get_ship_collision_mask(object_type_enum)
	elif ObjectTypes.is_weapon_type(object_type_enum):
		collision_layer_bits = CollisionLayers.create_layer_bit(CollisionLayers.Layer.WEAPONS)
		collision_mask_bits = CollisionLayers.get_weapon_collision_mask(object_type_enum)
	elif object_type_enum == ObjectTypes.Type.DEBRIS:
		collision_layer_bits = CollisionLayers.create_layer_bit(CollisionLayers.Layer.DEBRIS)
		collision_mask_bits = CollisionLayers.Mask.DEBRIS_STANDARD
	elif object_type_enum == ObjectTypes.Type.ASTEROID:
		collision_layer_bits = CollisionLayers.create_layer_bit(CollisionLayers.Layer.ASTEROIDS)
		collision_mask_bits = CollisionLayers.Mask.ASTEROID_STANDARD
	
	# Apply to physics body
	if physics_body:
		physics_body.collision_layer = collision_layer_bits
		physics_body.collision_mask = collision_mask_bits

## Enhanced collision event handlers (OBJ-001 AC7)
func _on_collision_body_entered(body: Node) -> void:
	if body == self or not body is BaseSpaceObject:
		return
	
	var other_object: BaseSpaceObject = body as BaseSpaceObject
	var collision_info: Dictionary = {
		"other_object": other_object,
		"position": physics_body.global_position,
		"normal": Vector3.UP,  # TODO: Calculate actual collision normal
		"impulse": linear_velocity.length(),
		"timestamp": Time.get_ticks_msec()
	}
	
	collision_detected.emit(other_object, collision_info)

func _on_collision_body_exited(body: Node) -> void:
	# Handle collision exit if needed
	pass

# EPIC-009 OBJ-006: Force Application and Momentum Systems

## Apply force to this space object with proper momentum conservation
func apply_force(force: Vector3, application_point: Vector3 = Vector3.ZERO, impulse: bool = false) -> bool:
	"""Apply force to this space object using the enhanced force application system.
	
	Args:
		force: Force vector in world coordinates
		application_point: Point to apply force (local coordinates, Vector3.ZERO for center of mass)
		impulse: true for instantaneous impulse, false for continuous force
		
	Returns:
		true if force applied successfully, false otherwise
	"""
	if not physics_body or not space_physics_enabled:
		return false
	
	# Use PhysicsManager's enhanced force application if available
	var physics_manager = get_node_or_null("/root/PhysicsManager")
	if physics_manager and physics_manager.has_method("apply_force_to_space_object"):
		physics_manager.apply_force_to_space_object(physics_body, force, impulse, application_point)
		return true
	
	# Fallback to direct Godot physics
	if impulse:
		if application_point == Vector3.ZERO:
			physics_body.apply_central_impulse(force)
		else:
			physics_body.apply_impulse(force, application_point)
	else:
		if application_point == Vector3.ZERO:
			physics_body.apply_central_force(force)
		else:
			physics_body.apply_force(force, application_point)
	
	# Track applied forces
	applied_forces.append(force)
	physics_state_changed.emit()
	
	return true

## Set thruster input for realistic ship movement (OBJ-006 AC1, AC5)
func set_thruster_input(forward: float, side: float, vertical: float, afterburner: bool = false) -> bool:
	"""Set thruster input for this space object using WCS-style thruster physics.
	
	Args:
		forward: Forward thrust (0-1, where 1 is maximum forward thrust)
		side: Side thrust (-1 to 1, negative for left, positive for right)
		vertical: Vertical thrust (-1 to 1, negative for down, positive for up)
		afterburner: true to activate afterburner boost
		
	Returns:
		true if thruster input applied successfully, false otherwise
	"""
	if not physics_body or not space_physics_enabled:
		return false
	
	# Use enhanced ForceApplication system through PhysicsManager
	var physics_manager = get_node_or_null("/root/PhysicsManager")
	if physics_manager and physics_manager.has_method("set_thruster_input"):
		return physics_manager.set_thruster_input(physics_body, forward, side, vertical, afterburner)
	
	# Fallback thruster implementation
	var thrust_force: float = 1000.0  # Default thrust magnitude
	var thrust_vector: Vector3 = Vector3(-side, vertical, -forward) * thrust_force
	
	if afterburner:
		thrust_vector *= 2.0  # Afterburner boost
	
	# Transform to world coordinates and apply
	thrust_vector = global_transform.basis * thrust_vector
	return apply_force(thrust_vector, Vector3.ZERO, false)

## Apply WCS-style physics damping to maintain authentic space flight feel (OBJ-006 AC2)
func apply_physics_damping(delta: float) -> void:
	"""Apply WCS-style exponential damping for authentic space physics feel.
	
	Args:
		delta: Time step for physics integration
	"""
	if not physics_body or not space_physics_enabled:
		return
	
	# Use enhanced damping system through PhysicsManager  
	var physics_manager = get_node_or_null("/root/PhysicsManager")
	if physics_manager and physics_manager.has_method("apply_wcs_damping"):
		physics_manager.apply_wcs_damping(physics_body, delta)
		return
	
	# Fallback basic damping
	var damping_factor: float = 0.1
	physics_body.linear_velocity *= exp(-delta / damping_factor)
	physics_body.angular_velocity *= exp(-delta / damping_factor)

## Get current momentum state of this object (OBJ-006 AC2)
func get_momentum_state() -> Dictionary:
	"""Get current momentum state for physics analysis and debugging.
	
	Returns:
		Dictionary containing momentum data including linear/angular momentum, velocity, mass
	"""
	if not physics_body:
		return {}
	
	# Use enhanced momentum tracking through PhysicsManager
	var physics_manager = get_node_or_null("/root/PhysicsManager")
	if physics_manager and physics_manager.has_method("get_momentum_state"):
		return physics_manager.get_momentum_state(physics_body)
	
	# Fallback momentum calculation
	return {
		"linear_momentum": physics_body.linear_velocity * physics_body.mass,
		"angular_momentum": physics_body.angular_velocity,  # Simplified
		"mass": physics_body.mass,
		"linear_velocity": physics_body.linear_velocity,
		"angular_velocity": physics_body.angular_velocity,
		"kinetic_energy": 0.5 * physics_body.mass * physics_body.linear_velocity.length_squared()
	}

## Get current thruster state of this object (OBJ-006 AC5)
func get_thruster_state() -> Dictionary:
	"""Get current thruster state for display and debugging.
	
	Returns:
		Dictionary containing thruster configuration and current thrust levels
	"""
	if not physics_body:
		return {}
	
	# Use enhanced thruster tracking through PhysicsManager
	var physics_manager = get_node_or_null("/root/PhysicsManager")
	if physics_manager and physics_manager.has_method("get_thruster_state"):
		return physics_manager.get_thruster_state(physics_body)
	
	# Fallback empty state
	return {
		"forward_thrust": 0.0,
		"side_thrust": 0.0,
		"vert_thrust": 0.0,
		"afterburner_active": false,
		"max_thrust_force": 1000.0,
		"thrust_efficiency": 1.0,
		"current_thrust_vector": Vector3.ZERO
	}

## Register this object with the enhanced force application system
func _register_force_application() -> void:
	"""Register this object with PhysicsManager's enhanced force application system."""
	var physics_manager = get_node_or_null("/root/PhysicsManager")
	if physics_body and physics_manager and physics_manager.has_method("register_space_physics_body"):
		var physics_profile_resource = physics_profile if physics_profile else null
		physics_manager.register_space_physics_body(physics_body, physics_profile_resource)

## Unregister this object from the enhanced force application system
func _unregister_force_application() -> void:
	"""Unregister this object from PhysicsManager's enhanced force application system.""" 
	var physics_manager = get_node_or_null("/root/PhysicsManager")
	if physics_body and physics_manager and physics_manager.has_method("unregister_space_physics_body"):
		physics_manager.unregister_space_physics_body(physics_body)

## Reset object state for pooling
func reset_state() -> void:
	super.reset_state()
	
	# Reset physics state
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	applied_forces.clear()
	applied_torques.clear()
	
	# Reset lifecycle state
	is_active = false
	destruction_pending = false
	
	# Reset physics body
	if physics_body:
		physics_body.linear_velocity = Vector3.ZERO
		physics_body.angular_velocity = Vector3.ZERO
		physics_body.freeze = true

## Get object type enumeration
func get_object_type_enum() -> int:
	return object_type_enum

## Set object type enumeration
func set_object_type_enum(type_enum: int) -> void:
	object_type_enum = type_enum

## Check if object is actively simulating
func is_object_active() -> bool:
	return is_active and not destruction_pending

## Enhanced space object information with asset core integration
func get_space_object_info() -> Dictionary:
	return {
		"object_id": object_id,
		"object_type": ObjectTypes.get_type_name(object_type_enum),
		"object_type_enum": object_type_enum,
		"position": global_position,
		"velocity": linear_velocity,
		"angular_velocity": angular_velocity,
		"collision_layer": collision_layer_bits,
		"collision_mask": collision_mask_bits,
		"is_physics_enabled": space_physics_enabled,
		"is_collision_enabled": collision_detection_enabled,
		"is_destroyed": destruction_pending,
		"physics_profile": physics_profile.get_description() if physics_profile else "None"
	}

## Enhanced debug information using asset core types
func debug_info() -> String:
	var base_info: String = super.debug_info() if has_method("debug_info") else ""
	var space_info: String = "[Type:%s, Vel:(%.1f,%.1f,%.1f), Mass:%.1f]" % [
		ObjectTypes.get_type_name(object_type_enum),
		linear_velocity.x, linear_velocity.y, linear_velocity.z,
		physics_body.mass if physics_body else 1.0
	]
	return base_info + " " + space_info

# --- Serialization Support (OBJ-004) ---

## Serialize this space object to dictionary format
## AC1: Captures all essential BaseSpaceObject state
func serialize_to_dictionary(options: Dictionary = {}) -> Dictionary:
	var ObjectSerialization = preload("res://scripts/core/objects/object_serialization.gd")
	return ObjectSerialization.serialize_space_object(self, options)

## Deserialize space object state from dictionary
## AC3: Recreates object with identical state
func deserialize_from_dictionary(serialized_data: Dictionary) -> bool:
	var ObjectSerialization = preload("res://scripts/core/objects/object_serialization.gd")
	
	# Validate data first
	if not serialized_data.has("critical"):
		push_error("BaseSpaceObject: Cannot deserialize - missing critical data")
		return false
	
	# Restore critical state
	if serialized_data.has("critical"):
		ObjectSerialization._restore_critical_state(self, serialized_data["critical"])
	
	# Restore physics state
	if serialized_data.has("physics"):
		ObjectSerialization._restore_physics_state(self, serialized_data["physics"])
	
	# Restore metadata
	if serialized_data.has("metadata"):
		ObjectSerialization._restore_metadata_state(self, serialized_data["metadata"])
	
	# Restore visual state if present
	if serialized_data.has("visual"):
		ObjectSerialization._restore_visual_state(self, serialized_data["visual"])
	
	return true

## Check if object state has changed for incremental saves
## AC4: Support for incremental saves with only changed objects
func has_state_changed(last_state_hash: String) -> bool:
	var ObjectSerialization = preload("res://scripts/core/objects/object_serialization.gd")
	return ObjectSerialization.has_object_changed(self, last_state_hash)

## Get state hash for incremental save comparison
func get_state_hash() -> String:
	var ObjectSerialization = preload("res://scripts/core/objects/object_serialization.gd")
	return ObjectSerialization._calculate_object_state_hash(self)

## Create a save data resource for this object
## AC6: Integration with save game system
func create_save_data(options: Dictionary = {}) -> Resource:
	var SpaceObjectSaveData = preload("res://addons/wcs_asset_core/resources/save_system/space_object_save_data.gd")
	
	var save_data = SpaceObjectSaveData.new()
	save_data.initialize_from_objects([self], options)
	
	return save_data

## Restore object state from save data resource
## AC6: Integration with save game system
func restore_from_save_data(save_data: Resource) -> bool:
	if not save_data:
		push_error("BaseSpaceObject: Cannot restore from null save data")
		return false
	
	var objects: Array[BaseSpaceObject] = save_data.restore_objects()
	if objects.is_empty():
		push_error("BaseSpaceObject: Failed to restore objects from save data")
		return false
	
	# Use first object's data to restore this object
	var source_data: Dictionary = objects[0].serialize_to_dictionary()
	return deserialize_from_dictionary(source_data)

## Get object data for save game integration
## Used by SaveGameManager for mission persistence
func get_save_game_data() -> Dictionary:
	return {
		"object_class": get_script().resource_path if get_script() else "",
		"serialized_data": serialize_to_dictionary({"include_relationships": true}),
		"save_timestamp": Time.get_unix_time_from_system(),
		"object_summary": {
			"id": get_object_id(),
			"type": get_object_type(),
			"position": global_position,
			"health": get("current_health") if "current_health" in self else (get("max_health") if "max_health" in self else 100.0)
		}
	}

## Restore object from save game data
## Used by SaveGameManager for mission loading
func restore_from_save_game_data(save_game_data: Dictionary) -> bool:
	if not save_game_data.has("serialized_data"):
		push_error("BaseSpaceObject: Save game data missing serialized_data")
		return false
	
	return deserialize_from_dictionary(save_game_data["serialized_data"])

## Enhanced RigidBody3D state restoration (deferred call)
func _restore_rigid_body_state(physics_data: Dictionary) -> void:
	if not physics_body or physics_data.is_empty():
		return
	
	# Restore RigidBody3D properties
	if physics_data.has("linear_velocity"):
		physics_body.linear_velocity = str_to_var(physics_data["linear_velocity"])
	
	if physics_data.has("angular_velocity"):
		physics_body.angular_velocity = str_to_var(physics_data["angular_velocity"])
	
	if physics_data.has("gravity_scale"):
		physics_body.gravity_scale = physics_data["gravity_scale"]
	
	if physics_data.has("linear_damp"):
		physics_body.linear_damp = physics_data["linear_damp"]
	
	if physics_data.has("angular_damp"):
		physics_body.angular_damp = physics_data["angular_damp"]
	
	if physics_data.has("collision_layer"):
		physics_body.collision_layer = physics_data["collision_layer"]
	
	if physics_data.has("collision_mask"):
		physics_body.collision_mask = physics_data["collision_mask"]
	
	if physics_data.has("continuous_cd"):
		physics_body.continuous_cd = physics_data["continuous_cd"]
	
	if physics_data.has("max_contacts_reported"):
		physics_body.max_contacts_reported = physics_data["max_contacts_reported"]
