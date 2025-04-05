# scripts/resources/mission/persona_data.gd
# Defines a character persona for messages.
# Corresponds to C++ 'Persona' struct.
class_name PersonaData
extends Resource

## Unique identifier name for the persona.
@export var name: String = ""

## Flags indicating the type of persona (Wingman, Support, Large, Command).
## Use bitwise flags from GlobalConstants.PersonaFlags.
@export var type_flags: int = 0

## Index of the species this persona belongs to (references SpeciesInfo data).
@export var species_index: int = -1 # -1 indicates unspecified or default

## Whether this persona can be automatically assigned by the game.
@export var auto_assign: bool = false

# --- Runtime State ---
# These are not exported, they are set during gameplay
var used_this_mission: bool = false # Flag if this persona has been assigned in the current mission
