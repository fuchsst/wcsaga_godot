class_name CutsceneManifest
extends Resource

## Cutscene Manifest
##
## Holds a collection of cutscenes for a campaign.

# Dictionary of cutscenes, keyed by filename (without extension)
@export var cutscenes: Dictionary = {}  # { String: CutsceneResource }
