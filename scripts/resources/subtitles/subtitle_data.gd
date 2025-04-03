# scripts/resources/subtitles/subtitle_data.gd
extends Resource
class_name SubtitleData

## Defines the content and properties for a single subtitle display.
## Corresponds to the subtitle class in C++.

# --- Exports ---
@export_multiline var text: String = ""
@export var image_path: String = "" # Path to the image/animation texture

@export var display_time: float = 3.0 # Duration the subtitle stays fully visible
@export var fade_time: float = 0.5  # Duration of fade-in and fade-out

@export var text_color: Color = Color.WHITE
@export var position_x: int = 0 # Screen X position (can be negative for right-alignment)
@export var position_y: int = 0 # Screen Y position (can be negative for bottom-alignment)
@export var center_x: bool = true # Center horizontally on screen
@export var center_y: bool = false # Center vertically on screen
@export var width: int = 0 # Optional fixed width for text wrapping or image scaling (0 = auto)
@export var height: int = 0 # Optional fixed height for image scaling (0 = auto)
@export var post_shaded: bool = false # Render after post-processing (e.g., bloom)

# --- Internal ---
# These might be set at runtime by the SubtitleManager
var start_time: float = 0.0
var end_time: float = 0.0
var current_alpha: float = 0.0

func calculate_duration() -> float:
	return display_time + (2.0 * fade_time)
