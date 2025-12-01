extends Resource
class_name SupportShipInfo

## Configuration for support/repair ships in the mission
const MissionEnums = preload("res://scripts/resources/missions/mission_enums.gd")

@export var arrival_location: MissionEnums.ArrivalLocation = MissionEnums.ArrivalLocation.HYPERSPACE
@export var arrival_anchor: int = 0
@export var departure_location: MissionEnums.DepartureLocation = MissionEnums.DepartureLocation.HYPERSPACE
@export var departure_anchor: int = 0
@export var max_hull_repair_val: float = 0.0
@export var max_subsys_repair_val: float = 0.0
@export var max_support_ships: int = 0
@export var ship_class: String = ""
@export var tally: int = 0
@export var support_available_for_species: int = 0
