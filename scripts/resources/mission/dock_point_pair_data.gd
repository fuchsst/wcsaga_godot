# scripts/resources/dock_point_pair_data.gd
# Defines a pair of docking points for initial docking setup.
class_name DockPointPairData
extends Resource

# Note: These names refer back to the ShipInstanceData names, not the dock point names themselves.
# The actual dock point names are stored within this resource.
@export var docker_instance_name: String = "" # Name of the ShipInstanceData initiating docking
@export var dockee_instance_name: String = "" # Name of the ShipInstanceData being docked to

@export var docker_point_name: String = "" # Name of the dock point on the docker ship model
@export var dockee_point_name: String = "" # Name of the dock point on the dockee ship model
