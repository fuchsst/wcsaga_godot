# BTFlyFormation - Wing Formation Flying
# Maintains position relative to wing leader
# Implements formation flying from legacy aicode.cpp

@tool
extends BTAction

## Formation type
enum FormationType {
	VIC, ## V-formation
	ECHELON, ## Diagonal line
	LINE, ## Horizontal line
	DIAMOND ## Diamond pattern
}

## Formation slot index (0 = leader, 1-3 = wingmen)
@export var formation_slot: int = 1
@export var formation_type: FormationType = FormationType.VIC

## Distance between formation positions
@export var spacing: float = 50.0

## How tightly to maintain position
@export var tightness: float = 0.8

## Blackboard variable for wing leader
@export var leader_var: StringName = &"wing_leader"


func _generate_name() -> String:
	var type_names = ["Vic", "Echelon", "Line", "Diamond"]
	return "FlyFormation [%s, slot=%d]" % [type_names[formation_type], formation_slot]


func _tick(_delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	var leader = blackboard.get_var(leader_var)

	if not ship or not is_instance_valid(ship):
		return FAILURE

	# If no leader or we ARE the leader
	if not leader or not is_instance_valid(leader) or leader == ship:
		return SUCCESS # Leader doesn't need to follow anyone

	# Calculate formation position
	var formation_pos = _calculate_formation_position(leader)

	# Navigate to formation position
	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(formation_pos)
	else:
		blackboard.set_var("desired_position", formation_pos)

	# Match leader's speed
	if "velocity" in leader:
		var leader_speed = leader.velocity.length()
		blackboard.set_var("desired_speed", leader_speed * tightness)

	return RUNNING


func _calculate_formation_position(leader: Node) -> Vector3:
	"""Calculate world position for this formation slot"""
	var leader_pos: Vector3 = leader.global_position
	var has_transform = "global_transform" in leader
	var leader_basis: Basis = leader.global_transform.basis if has_transform else Basis()

	var leader_fwd = - leader_basis.z
	var leader_right = leader_basis.x
	var leader_up = leader_basis.y

	var offset: Vector3 = Vector3.ZERO

	match formation_type:
		FormationType.VIC:
			# V-formation: slots behind and to sides
			var side = 1.0 if formation_slot % 2 == 1 else -1.0
			var row = (formation_slot + 1) / 2
			offset = (
				leader_fwd * (-spacing * row) +
				leader_right * (spacing * row * side * 0.8)
			)

		FormationType.ECHELON:
			# Diagonal line formation
			var side = 1.0 if formation_slot % 2 == 1 else -1.0
			offset = (
				leader_fwd * (-spacing * formation_slot) +
				leader_right * (spacing * formation_slot * side)
			)

		FormationType.LINE:
			# Horizontal line
			var side = 1.0 if formation_slot % 2 == 1 else -1.0
			var slot_offset = ((formation_slot + 1) / 2) * side
			offset = leader_right * (spacing * slot_offset)

		FormationType.DIAMOND:
			# Diamond pattern
			match formation_slot:
				1: offset = leader_fwd * (-spacing) + leader_right * spacing
				2: offset = leader_fwd * (-spacing) - leader_right * spacing
				3: offset = leader_fwd * (-spacing * 2)
				_: offset = leader_fwd * (-spacing * formation_slot)

	return leader_pos + offset
