# scripts/resources/persona_data.gd
# Defines a character persona for messages.
# Corresponds to C++ 'Persona' struct.
class_name PersonaData
extends Resource

# --- Persona Definition ---
@export var name: String = "" # Unique name of the persona
@export var type_flags: int = 0 # Bitmask: PERSONA_FLAG_WINGMAN, PERSONA_FLAG_COMMAND, etc.
@export var species_index: int = 0 # Index into SpeciesInfo array
@export var auto_assign: bool = false # Whether this persona can be auto-assigned

# --- Runtime State ---
# These are not exported, they are set during gameplay
var used: bool = false # Flag if this persona has been assigned in the current mission
