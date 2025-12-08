class_name PlayerMedalEntry
extends Resource
## Represents a medal awarded to the player.

## Reference to the MedalResource definition
@export var medal: Resource

## Number of times this medal was awarded
@export var count: int = 1

## Date awarded in ISO format (YYYY-MM-DD)
@export var date_awarded: String = ""
