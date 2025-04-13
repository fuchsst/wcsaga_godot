# scripts/effects/effect_manager.gd
# Autoload Singleton for managing and creating visual effects.
# This is a basic placeholder implementation.
class_name EffectManager
extends Node

# --- Placeholder Enums (Define properly later, possibly in GlobalConstants) ---
enum ExplosionType { SMALL, MEDIUM, LARGE, ASTEROID, WARP, KNOSSOS }
enum TrailType { LASER, MISSILE, AFTERBURNER }
enum MuzzleFlashType { LASER_STD, FLAK, BEAM_WARMUP } # Example types

func _ready():
	name = "EffectManager"
	print("EffectManager initialized (Placeholder).")

# --- Placeholder Functions ---

# Preload the base explosion scene
const ExplosionScene = preload("res://scenes/effects/explosion_base.tscn")

func create_explosion(position: Vector3, type: ExplosionType, radius: float = 1.0, parent_id: int = -1):
	if not ExplosionScene:
		printerr("EffectManager: ExplosionScene not preloaded!")
		return

	var explosion_node = ExplosionScene.instantiate()
	if not explosion_node:
		printerr("EffectManager: Failed to instantiate ExplosionScene!")
		return

	# Add to a common effects container or the current scene root
	var effects_container = get_tree().root.get_node_or_null("EffectsContainer") # Optional container
	if effects_container:
		effects_container.add_child(explosion_node)
	else:
		get_tree().current_scene.add_child(explosion_node) # Fallback to current scene root

	explosion_node.global_position = position

	# Call setup function on the explosion script if it exists
	if explosion_node.has_method("setup_explosion"):
		explosion_node.setup_explosion(type, radius)
	else:
		# Apply basic scaling if setup function is missing
		explosion_node.scale = Vector3.ONE * clamp(radius / 10.0, 0.2, 5.0) # Example scaling

	# Note: The ExplosionEffect script handles its own lifetime and queue_free()

func create_muzzle_flash(position: Vector3, direction: Vector3, parent_velocity: Vector3, effect_index: int):
	# TODO: Implement muzzle flash instantiation using preloaded scenes/data based on effect_index.
	print(f"EffectManager: Placeholder - Create muzzle flash index {effect_index} at {position} (Dir: {direction})")
	pass

func create_trail(trail_info: Dictionary, parent_node: Node3D):
	# TODO: Implement trail creation (e.g., RibbonTrailMesh, TubeTrailMesh) based on trail_info.
	# trail_info might contain texture path, width, alpha, lifetime, etc.
	var trail_type = trail_info.get("type", "Unknown")
	print(f"EffectManager: Placeholder - Create trail type '{trail_type}' attached to {parent_node.name if is_instance_valid(parent_node) else 'Invalid Node'}")
	pass

func create_shockwave(position: Vector3, shockwave_info: Dictionary, parent_id: int):
	# TODO: Implement shockwave instantiation using preloaded scenes/data based on shockwave_info.
	# shockwave_info might contain radius, speed, damage, blast, texture/model path.
	var sw_type = shockwave_info.get("type", "Unknown")
	print(f"EffectManager: Placeholder - Create shockwave type '{sw_type}' at {position} (ParentID: {parent_id})")
	pass

func create_sparks(position: Vector3, normal: Vector3, count: int = 5, speed: float = 10.0, lifetime: float = 0.5):
	# TODO: Implement spark particle effect instantiation.
	print(f"EffectManager: Placeholder - Create {count} sparks at {position} (Normal: {normal})")
	pass

func create_shield_impact(position: Vector3, normal: Vector3, ship_node: Node3D):
	# TODO: Implement shield impact visual effect (shader effect, particles).
	print(f"EffectManager: Placeholder - Create shield impact at {position} on {ship_node.name if is_instance_valid(ship_node) else 'Invalid Ship'}")
	pass

func create_beam_impact(position: Vector3, normal: Vector3):
	# TODO: Implement beam impact visual effect.
	print(f"EffectManager: Placeholder - Create beam impact at {position}")
	pass

func create_flak_muzzle_flash(position: Vector3, direction: Vector3, parent_velocity: Vector3, weapon_info_index: int):
	# TODO: Implement flak-specific muzzle flash.
	print(f"EffectManager: Placeholder - Create FLAK muzzle flash at {position} (Weapon Index: {weapon_info_index})")
	pass

# Add other effect creation functions as needed (e.g., warp effects, cloak effects)
