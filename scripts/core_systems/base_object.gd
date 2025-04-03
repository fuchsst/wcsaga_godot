# scripts/core_systems/base_object.gd
# Base class for all significant gameplay objects (ships, weapons, asteroids, debris).
# Handles registration with ObjectManager, common properties like signature, type, flags.
class_name BaseObject
extends Node3D # Most game objects will have a 3D presence

# --- Object Properties (Mirroring parts of C++ 'object' struct) ---

# Type of the object (e.g., SHIP, WEAPON). Use GlobalConstants.ObjectType enum.
@export var object_type: GlobalConstants.ObjectType = GlobalConstants.ObjectType.UNKNOWN

# Unique signature for identification (especially important for network/saves).
# Will be assigned by ObjectManager if not set, often using instance ID as fallback.
@export var signature: int = -1

# Object flags (Mirroring OF_* flags where applicable). Use bitmasks.
# Example: OF_PLAYER_SHIP, OF_PROTECTED, OF_COLLIDES, etc.
# Define these constants in GlobalConstants.gd
@export_flags("Player Ship", "Protected", "Collides", "Targetable", "Invulnerable", "Hidden From Sensors") var object_flags: int = 0

# Parent object reference (e.g., for weapons fired by a ship). Store instance ID.
var parent_object_id: int = -1
var parent_signature: int = -1 # Store parent sig for validation
var parent_type: int = GlobalConstants.ObjectType.NONE # Store parent type

# Collision Group ID (Maps to Godot Physics Layers/Masks)
# We'll use Godot's built-in layer/mask system instead of a separate ID.
# Export these for easier setup in the editor.
@export_flags_physics_layer_3d var collision_layer: int = 1
@export_flags_physics_layer_3d var collision_mask: int = 1

# Docking Information (Placeholder - Needs Docking System Integration)
# Corresponds to dock_list and dead_dock_list in C++ object struct
# Using Dictionaries: { dockpoint_index_or_name: docked_object_instance_id }
# Ensure these are initialized properly
var dock_list: Dictionary = {}
var dead_dock_list: Dictionary = {}

# Sound Handles (Placeholder - Needs Sound System Integration)
# Corresponds to objsnd_num array
var sound_handles: Dictionary = {} # { sound_type_or_index: sound_player_node_or_id }

# --- Lifecycle Methods ---

func _ready():
	# Set physics layers based on export
	set_collision_layer(collision_layer)
	set_collision_mask(collision_mask)

	# Register with the ObjectManager singleton
	if Engine.has_singleton("ObjectManager"):
		ObjectManager.register_object(self, signature)
		# Retrieve the signature assigned by ObjectManager if it wasn't pre-set
		# ObjectManager now sets the meta tag directly.
		signature = get_meta("signature", get_instance_id())
	else:
		printerr("BaseObject %s: ObjectManager singleton not found!" % name)

func _exit_tree():
	# Stop any associated sounds
	_stop_all_sounds()

	# Notify DockingManager about deletion *before* unregistering
	if Engine.has_singleton("DockingManager"):
		DockingManager.handle_object_deletion(self)
	#else:
		# printerr("BaseObject %s: DockingManager singleton not found during exit!" % name)

	# Unregister from the ObjectManager singleton
	if Engine.has_singleton("ObjectManager"):
		ObjectManager.unregister_object(self)
	#else:
		# Might be shutting down, manager might already be gone.
		# printerr("BaseObject %s: ObjectManager singleton not found during exit!" % name)

# --- Public Methods ---

func get_object_type() -> GlobalConstants.ObjectType:
	return object_type

func get_signature() -> int:
	# Return the assigned signature (might be instance ID if not otherwise set)
	return get_meta("signature", get_instance_id())

func set_flag(flag: int):
	object_flags |= flag

func clear_flag(flag: int):
	object_flags &= ~flag

func has_flag(flag: int) -> bool:
	return (object_flags & flag) != 0

func set_parent_object(parent_obj: Node):
	if is_instance_valid(parent_obj):
		parent_object_id = parent_obj.get_instance_id()
		parent_signature = parent_obj.get_meta("signature", parent_object_id) # Get parent's signature
		if parent_obj.has_method("get_object_type"):
			parent_type = parent_obj.get_object_type()
		else:
			parent_type = GlobalConstants.ObjectType.UNKNOWN
	else:
		parent_object_id = -1
		parent_signature = -1
		parent_type = GlobalConstants.ObjectType.NONE

func get_parent_object() -> Node:
	if parent_object_id != -1:
		var parent_node = instance_from_id(parent_object_id)
		# Validate signature if possible (important for network/replays)
		if is_instance_valid(parent_node) and parent_node.get_meta("signature", -1) == parent_signature:
			return parent_node
		else:
			# Parent is gone or signature mismatch, clear references
			parent_object_id = -1
			parent_signature = -1
			parent_type = GlobalConstants.ObjectType.NONE
			return null
	return null

# --- Virtual Methods (To be overridden by derived classes) ---

# Applies damage to the object. Should be implemented in ShipBase, Asteroid, Debris, etc.
func apply_damage(damage: float, source_pos: Vector3, source_obj: Node = null, damage_type_key = -1):
	push_warning("apply_damage() called on BaseObject %s - should be overridden." % name)
	pass

# Returns the team affiliation (IFF_* constant).
func get_team() -> int:
	# Default implementation for objects without teams.
	return -1 # TEAM_NEUTRAL or equivalent

# Returns true if the object is considered destroyed or dying.
func is_destroyed() -> bool:
	# Default: Check if marked for deletion. Derived classes (ShipBase) override this.
	return has_flag(GlobalConstants.OF_SHOULD_BE_DEAD)

# Returns true if the object is currently in an arrival sequence.
func is_arriving() -> bool:
	# Default: False. ShipBase overrides this.
	return false

# --- Sound Handling (Placeholder) ---
# Corresponds to obj_snd_* functions

# Assigns a looping sound to this object. Returns a handle/index or -1 on failure.
func assign_sound(sound_index: int, offset: Vector3 = Vector3.ZERO, is_main_engine: bool = false) -> int:
	# TODO: Integrate with SoundManager singleton
	# Example:
	# var handle = SoundManager.assign_object_sound(self, sound_index, offset, is_main_engine)
	# if handle != -1:
	#     sound_handles[handle] = handle # Store handle (or maybe the player node?)
	# return handle
	push_warning("assign_sound() not implemented yet.")
	return -1

# Stops a specific sound instance or all sounds for this object.
func stop_sound(handle: int = -1):
	# TODO: Integrate with SoundManager singleton
	# if handle == -1:
	#     for h in sound_handles.keys():
	#         SoundManager.stop_object_sound(h)
	#     sound_handles.clear()
	# elif sound_handles.has(handle):
	#     SoundManager.stop_object_sound(handle)
	#     sound_handles.erase(handle)
	push_warning("stop_sound() not implemented yet.")
	pass

# Internal helper to stop all sounds when the object is destroyed/removed.
func _stop_all_sounds():
	stop_sound(-1)


# --- Docking Handling (Placeholder) ---
# Corresponds to object_is_docked, dock_list, dead_dock_list

func is_docked() -> bool:
	return not dock_list.is_empty()

func is_dead_docked() -> bool:
	return not dead_dock_list.is_empty()

# TODO: Add methods for adding/removing/finding dock instances when DockingSystem is implemented.
# func add_dock_instance(...)
# func remove_dock_instance(...)
# func find_dock_instance(...)
# func add_dead_dock_instance(...)
# func remove_dead_dock_instance(...)
# func find_dead_dock_instance(...)
