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

# --- Lifecycle Methods ---

func _ready():
	# Register with the ObjectManager singleton
	if Engine.has_singleton("ObjectManager"):
		ObjectManager.register_object(self, signature)
		# Retrieve the signature assigned by ObjectManager if it wasn't pre-set
		signature = get_meta("signature", get_instance_id())
	else:
		printerr("BaseObject %s: ObjectManager singleton not found!" % name)

func _exit_tree():
	# Unregister from the ObjectManager singleton
	if Engine.has_singleton("ObjectManager"):
		ObjectManager.unregister_object(self)
	#else:
		# Might be shutting down, manager might already be gone.
		# printerr("BaseObject %s: ObjectManager singleton not found during exit!" % name)

# --- Public Methods (Placeholders - Override in derived classes) ---

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
	else:
		parent_object_id = -1
		parent_signature = -1

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
			return null
	return null

# Placeholder for damage application - specific logic in derived classes (e.g., ShipBase, Asteroid)
func apply_damage(damage: float, source_pos: Vector3, source_obj: Node = null):
	push_warning("apply_damage() called on BaseObject %s - should be overridden." % name)
	pass

# Placeholder for getting team - specific logic in derived classes (e.g., ShipBase)
func get_team() -> int:
	# Return a default team or -1 if not applicable to this base type
	return -1 # Example: -1 indicates no team affiliation

# Placeholder for checking if destroyed - specific logic in derived classes
func is_destroyed() -> bool:
	return false

# Placeholder for checking arrival status - specific logic in derived classes
func is_arriving() -> bool:
	return false
