class_name GameEntity
extends RigidBody3D

## Base class for all physical game objects
## Handles common properties, identification, collision, and damage integration


## Signals
signal destroyed(entity: GameEntity, killer: Node)
signal damage_received(entity: GameEntity, result: DamageResult)


## Identity
@export_group("Identity")
@export var entity_name: String = "Entity" ## Display name
@export var entity_type: String = "Unknown" ## Type: ship, debris, asteroid, etc.
@export var iff_name: String = "Neutral" ## IFF for collision/targeting


## Combat
@export_group("Combat")
@export var max_hull_strength: float = 100.0 ## Maximum hull hitpoints
var hull_strength: float = 100.0 ## Current hull hitpoints


## Runtime state
var instance_id: int = -1 ## Unique instance ID
var _is_destroyed: bool = false


# ==============================================================================
# INITIALIZATION
# ==============================================================================


func _ready() -> void:
	instance_id = get_instance_id()
	hull_strength = max_hull_strength
	add_to_group("game_entities")
	
	# Defer collision setup to ensure CollisionManager autoload is ready
	call_deferred("_setup_collision")


func _setup_collision() -> void:
	# CollisionManager may not be available if this entity loads before autoloads
	if Engine.has_singleton("CollisionManager") or get_node_or_null("/root/CollisionManager"):
		var cm = get_node_or_null("/root/CollisionManager")
		if cm:
			collision_layer = cm.get_collision_layer(entity_type, iff_name)
			collision_mask = cm.get_collision_mask(entity_type, iff_name)


func _physics_process(_delta: float) -> void:
	# Override in subclasses for entity-specific physics
	pass


# ==============================================================================
# DAMAGE SYSTEM
# ==============================================================================


## Take damage from any source
## Simple interface for basic entities (debris, asteroids)
func take_damage(amount: float, attacker: Node = null) -> void:
	if _is_destroyed:
		return
	
	var result := DamageResult.new()
	result.attacker = attacker
	result.original_damage = amount
	result.actual_damage = amount
	result.final_hull_damage = amount
	result.impact_point = global_position
	
	_apply_damage_result(result)


## Take damage using full DamageResult
## Advanced interface for ships and complex entities
func apply_damage_result(result: DamageResult) -> void:
	if _is_destroyed:
		return
	_apply_damage_result(result)


func _apply_damage_result(result: DamageResult) -> void:
	hull_strength -= result.actual_damage
	
	damage_received.emit(self, result)
	
	if hull_strength <= 0.0 and not _is_destroyed:
		result.mark_killing_blow()
		_on_destroyed(result.attacker)


## Called when entity is destroyed
func _on_destroyed(killer: Node) -> void:
	if _is_destroyed:
		return
	
	_is_destroyed = true
	destroyed.emit(self, killer)
	
	# Spawn effects - override in subclasses for specific behavior
	_spawn_destruction_effects()
	
	# Remove from scene after short delay for effects
	var timer := get_tree().create_timer(0.1)
	timer.timeout.connect(queue_free)


func _spawn_destruction_effects() -> void:
	# Override in subclasses to spawn explosions, debris, etc.
	pass


# ==============================================================================
# QUERIES
# ==============================================================================


func is_alive() -> bool:
	return hull_strength > 0.0 and not _is_destroyed


func is_destroyed() -> bool:
	return _is_destroyed


func get_iff_name() -> String:
	return iff_name


func get_hull_percentage() -> float:
	if max_hull_strength <= 0:
		return 0.0
	return hull_strength / max_hull_strength
