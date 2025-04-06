# scripts/ai/turret/turret_ai.gd
# Manages the independent AI logic for a ship's turret subsystem.
# Corresponds to logic in aiturret.cpp.
class_name TurretAI
extends Node

# --- Dependencies ---
var turret_subsystem: TurretSubsystem # Reference to the parent TurretSubsystem node
var ship_base: ShipBase # Reference to the main ship the turret belongs to
var ai_controller: AIController # Reference to the main ship's AI controller (for profile flags, etc.)

# --- Runtime State ---
var current_enemy_id: int = -1
var current_enemy_sig: int = -1
var targeted_subsystem_on_enemy: Node = null # If targeting a specific subsystem

var next_enemy_check_time: float = 0.0
var next_fire_time: float = 0.0
var time_enemy_in_range: float = 0.0

# --- Configuration (Potentially from TurretSubsystem or AIProfile) ---
# var targeting_order: Array[int] = [] # Priorities (Bombs > Attackers > etc.)
# var optimum_range: float = 1000.0
# var favor_current_facing: float = 0.0

func _ready():
	# Get references assuming this node is a child of TurretSubsystem
	turret_subsystem = get_parent() as TurretSubsystem
	if not turret_subsystem:
		printerr("TurretAI must be a child of a TurretSubsystem node!")
		queue_free()
		return

	# Get references from the turret subsystem's ship base
	if is_instance_valid(turret_subsystem.ship_base):
		ship_base = turret_subsystem.ship_base
		ai_controller = ship_base.find_child("AIController", false, false) # Find AIController on ship
	else:
		printerr("TurretAI could not get ship_base reference from TurretSubsystem!")
		queue_free()
		return

	# Initialize timers
	next_enemy_check_time = Time.get_ticks_msec() / 1000.0 + randf_range(0.5, 1.5) # Initial random delay
	next_fire_time = Time.get_ticks_msec() / 1000.0

	# TODO: Load targeting order/priorities from TurretSubsystem definition or AI profile


func _physics_process(delta: float):
	if not is_instance_valid(turret_subsystem) or not turret_subsystem.is_functional():
		# Stop aiming/firing if turret is destroyed or disrupted
		# TODO: Maybe return turret to neutral position?
		turret_subsystem.target_node = null
		return

	var current_time = Time.get_ticks_msec() / 1000.0

	# 1. Find Target (if needed)
	if current_time >= next_enemy_check_time:
		_find_turret_enemy()
		# TODO: Set next_enemy_check_time based on skill/situation
		next_enemy_check_time = current_time + randf_range(1.0, 2.0) # Simple periodic check

	# Update target node reference in TurretSubsystem for aiming
	var enemy_node = instance_from_id(current_enemy_id)
	if is_instance_valid(enemy_node):
		# TODO: Validate signature?
		# TODO: Check if target is still valid (not destroyed, still hostile, etc.)
		turret_subsystem.target_node = enemy_node
		turret_subsystem.target_signature = current_enemy_sig
		turret_subsystem.targeted_subsystem = targeted_subsystem_on_enemy # Pass subsystem target
	else:
		# Target is invalid, clear it
		current_enemy_id = -1
		current_enemy_sig = -1
		targeted_subsystem_on_enemy = null
		turret_subsystem.target_node = null
		time_enemy_in_range = 0.0 # Reset timer

	# 2. Aim Turret (Handled by TurretSubsystem._process based on its target_node)

	# 3. Fire Weapon (if target is valid and in arc/range)
	if is_instance_valid(turret_subsystem.target_node):
		if current_time >= next_fire_time:
			# Check if target is within firing parameters (FOV, range, LoS)
			# This check is partially done in TurretSubsystem.is_turret_ready_to_fire
			if turret_subsystem.is_turret_ready_to_fire(turret_subsystem.target_node):
				# TODO: Implement more detailed firing logic from turret_fire_weapon
				# - Select best weapon bank for target? (turret_select_best_weapon)
				# - Check specific weapon cooldowns/ammo/energy
				# - Handle beam/swarm/flak specifics
				# - Apply firing delays based on profile/skill

				# Simple firing logic: Call fire_turret on the subsystem
				# fire_turret handles cooldown setting internally for now
				turret_subsystem.fire_turret()

				# Update time_enemy_in_range (might be better in TurretSubsystem aiming logic)
				time_enemy_in_range += delta
			else:
				# Target not in arc/range, reset timer?
				time_enemy_in_range = 0.0
		else:
			# On cooldown
			pass
	else:
		# No valid target
		time_enemy_in_range = 0.0


func _find_turret_enemy():
	# Placeholder for find_turret_enemy logic
	# Needs to:
	# - Get potential targets (ships, bombs, asteroids) from ObjectManager
	# - Filter based on IFF, range, targetability flags
	# - Prioritize based on targeting_order (Bombs > Attackers > Ships > Asteroids)
	# - Consider turret FOV (turret_fov_test)
	# - Consider weapon flags (WIF_HUGE, WIF_SMALL_ONLY, WIF2_TAGGED_ONLY)
	# - Check max turret ownage limits (max_turret_ownage_target/player)
	# - Potentially select a subsystem on the chosen target
	# - Update current_enemy_id, current_enemy_sig, targeted_subsystem_on_enemy

	# Basic placeholder: Find nearest hostile ship within range (similar to PerceptionComponent)
	var best_target_id = -1
	var best_score = -INF
	var sensor_range = turret_subsystem.subsystem_definition.radius * 5.0 # Example range based on turret size

	if not Engine.has_singleton("ObjectManager") or not Engine.has_singleton("IFFManager"):
		printerr("TurretAI requires ObjectManager and IFFManager singletons!")
		return

	var object_manager = Engine.get_singleton("ObjectManager")
	var iff_manager = Engine.get_singleton("IFFManager")
	var my_team = ship_base.get_team()
	var enemy_team_mask = iff_manager.get_attackee_mask(my_team)

	var potential_targets = object_manager.get_all_ships() # TODO: Add bombs, asteroids

	for target in potential_targets:
		if not is_instance_valid(target): continue
		var target_id = target.get_instance_id()

		if target_id == ship_base.get_instance_id(): continue # Don't target self

		var target_team = target.get_team() if target.has_method("get_team") else -1
		if target_team == -1 or not iff_manager.iff_matches_mask(target_team, enemy_team_mask): continue

		if target.has_method("is_dying") and target.is_dying(): continue
		if target.has_method("is_arriving") and target.is_arriving(): continue
		if target.has_flag(GlobalConst.OF_PROTECTED): continue

		var dist_sq = turret_subsystem.global_position.distance_squared_to(target.global_position)
		if dist_sq > sensor_range * sensor_range: continue

		# TODO: Add FOV check (turret_fov_test)
		# TODO: Add LoS check

		# Simple scoring (inverse distance)
		var score = 1000000.0 / (dist_sq + 1.0)
		# TODO: Add prioritization based on target type (bomb > attacker > ship > asteroid)

		if score > best_score:
			best_score = score
			best_target_id = target_id

	if best_target_id != current_enemy_id:
		current_enemy_id = best_target_id
		targeted_subsystem_on_enemy = null # Reset subsystem target
		time_enemy_in_range = 0.0 # Reset range timer
		if best_target_id != -1:
			var target_node = instance_from_id(best_target_id)
			if is_instance_valid(target_node):
				current_enemy_sig = target_node.get_meta("signature", target_id)
				# TODO: Implement smart subsystem targeting if flag AIPF_SMART_SUBSYSTEM_TARGETING_FOR_TURRETS is set
				# targeted_subsystem_on_enemy = _find_best_subsystem_on_target(target_node)
			else:
				current_enemy_sig = -1 # Target became invalid
		else:
			current_enemy_sig = -1
