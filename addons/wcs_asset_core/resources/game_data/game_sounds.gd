# addons/wcs_asset_core/resources/game_data/game_sounds_data.gd
# Resource defining the structure for storing loaded sound and music definitions.
# This resource is typically populated by a tool script (e.g., populate_game_sounds.gd)
# by parsing original game data tables (sounds.tbl, music.tbl).
@tool
extends Resource
class_name GameSoundsData

# Preload dependent resources
const SoundEntry = preload("sound_entry.gd")
const MusicEntry = preload("music_entry.gd")

## Dictionary storing SoundEntry resources, keyed by their id_name (e.g., "SND_LASER_FIRE").
## This combines both game sounds and interface sounds for easier lookup.
@export var sound_entries: Dictionary = {}

## Dictionary storing MusicEntry resources, keyed by a unique identifier.
## Using the pattern enum value (int) as the key seems appropriate for event music lookup.
## Example: { MusicEntry.MusicPattern.NRML_1 : <MusicEntry Resource>, ... }
@export var music_entries: Dictionary = {}

# Note: No functions or internal state related to playback management here.
# This script purely defines the data structure for the .tres resource file.
