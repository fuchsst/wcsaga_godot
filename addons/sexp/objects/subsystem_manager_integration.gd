class_name SubsystemManagerIntegration
extends RefCounted

## Placeholder for subsystem manager integration
##
## This would integrate with ship subsystem management to handle
## subsystem damage, destruction, and state changes for ship operations.

signal subsystem_status_changed(ship_node: Node, subsystem_name: String, old_status: String, new_status: String)

func damage_subsystem(ship_node: Node, subsystem_name: String, damage_amount: float) -> bool:
	"""Apply damage to a specific subsystem"""
	if ship_node.has_method("damage_subsystem"):
		var old_health = get_subsystem_health(ship_node, subsystem_name)
		ship_node.damage_subsystem(subsystem_name, damage_amount)
		var new_health = get_subsystem_health(ship_node, subsystem_name)
		
		if old_health > 0 and new_health <= 0:
			subsystem_status_changed.emit(ship_node, subsystem_name, "active", "destroyed")
		elif new_health != old_health:
			subsystem_status_changed.emit(ship_node, subsystem_name, "damaged", "damaged")
		
		return true
	return false

func destroy_all_subsystems(ship_node: Node):
	"""Destroy all subsystems on a ship"""
	if ship_node.has_method("destroy_all_subsystems"):
		ship_node.destroy_all_subsystems()
	elif ship_node.has_method("get_subsystems"):
		var subsystems = ship_node.get_subsystems()
		for subsystem_name in subsystems:
			subsystem_status_changed.emit(ship_node, subsystem_name, "active", "destroyed")

func trigger_subsystem_failures(ship_node: Node):
	"""Trigger subsystem failures during ship destruction"""
	if ship_node.has_method("trigger_subsystem_failures"):
		ship_node.trigger_subsystem_failures()

func get_subsystem_health(ship_node: Node, subsystem_name: String) -> float:
	"""Get subsystem health percentage"""
	if ship_node.has_method("get_subsystem_health"):
		return ship_node.get_subsystem_health(subsystem_name)
	return 0.0

func get_subsystem_state(ship_node: Node, subsystem_name: String) -> String:
	"""Get subsystem state"""
	var health = get_subsystem_health(ship_node, subsystem_name)
	if health <= 0:
		return "destroyed"
	elif health < 50:
		return "damaged"
	else:
		return "active"

func get_all_subsystem_states(ship_node: Node) -> Dictionary:
	"""Get all subsystem states"""
	var states: Dictionary = {}
	if ship_node.has_method("get_subsystems"):
		var subsystems = ship_node.get_subsystems()
		for subsystem_name in subsystems:
			states[subsystem_name] = get_subsystem_state(ship_node, subsystem_name)
	return states