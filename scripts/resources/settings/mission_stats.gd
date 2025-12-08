class_name MissionStats
extends Resource
## Stats for a single completed mission. Persisted per-mission, overwritten on replay.

## Unique mission identifier
@export var mission_id: String = ""

## Score earned in this mission
@export var score: int = 0

## Number of kills in this mission
@export var kills: int = 0

## Number of assists in this mission
@export var assists: int = 0

## Kills broken down by ship class
@export var kills_by_ship: Array[ShipKillEntry] = []

## Primary weapon shots fired
@export var primary_shots_fired: int = 0

## Primary weapon shots that hit
@export var primary_shots_hit: int = 0

## Secondary weapon shots fired
@export var secondary_shots_fired: int = 0

## Secondary weapon shots that hit
@export var secondary_shots_hit: int = 0

## Friendly fire hits (primary + secondary)
@export var bonehead_hits: int = 0

## Friendly kills
@export var bonehead_kills: int = 0

## Number of times player died
@export var player_deaths: int = 0

## Medal earned index (-1 = none)
@export var medal_earned: int = -1

## Whether a promotion was earned
@export var promotion_earned: bool = false

## ISO timestamp when mission was completed
@export var completed_at: String = ""


## Calculate primary weapon accuracy percentage.
func get_primary_accuracy() -> float:
	if primary_shots_fired == 0:
		return 0.0
	return float(primary_shots_hit) / float(primary_shots_fired) * 100.0


## Calculate secondary weapon accuracy percentage.
func get_secondary_accuracy() -> float:
	if secondary_shots_fired == 0:
		return 0.0
	return float(secondary_shots_hit) / float(secondary_shots_fired) * 100.0


## Record a ship kill.
func add_ship_kill(ship_class_id: String, count: int = 1) -> void:
	for entry in kills_by_ship:
		if entry.ship_class_id == ship_class_id:
			entry.kill_count += count
			kills += count
			return

	var new_entry := ShipKillEntry.new()
	new_entry.ship_class_id = ship_class_id
	new_entry.kill_count = count
	kills_by_ship.append(new_entry)
	kills += count
