# scripts/resources/message_data.gd
# Defines a single message entry.
# Corresponds to C++ 'MMessage' struct.
class_name MessageData
extends Resource

@export var name: String = "" # Unique identifier for the message
@export var message_text: String = "" # The text content of the message
@export var persona_index: int = -1 # Index into the global Personas array
@export var multi_team: int = -1 # Team filter for multiplayer (-1 for all)
@export var avi_filename: String = "" # Filename for the talking head animation (e.g., "head-cm1a")
@export var wave_filename: String = "" # Filename for the voice audio (e.g., "TC_001.wav")
