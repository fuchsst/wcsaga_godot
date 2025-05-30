# addons/wcs_asset_core/resources/mission/mission_event_data.gd
# Defines a mission event triggered by a SEXP formula.
# Corresponds to the C++ 'mission_event' struct.
class_name MissionEventData
extends Resource

# --- Nested Resource Definition ---
const SexpExpression = preload("res://addons/sexp/core/sexp_expression.gd")

# --- Event Definition ---
@export var event_name: String = "" # Optional name for the event
@export var formula: SexpExpression = null # SEXP expression for the trigger condition
@export var repeat_count: int = 1 # How many times to trigger (-1 for infinite until formula false?)
@export var trigger_count: int = 1 # Alternative trigger count (FS2 feature)
@export var interval_ms: int = -1 # Delay between repeats in milliseconds (-1 means no interval)
@export var score: int = 0 # Score awarded when triggered
@export var chain_delay_ms: int = -1 # Delay before next chained event can trigger in milliseconds (-1 means not chained)
@export var objective_text: String = "" # Text to display on HUD directives when active
@export var objective_key_text: String = "" # Key binding text associated with the objective
@export var team: int = -1 # Team this event applies to (-1 for all)

# --- Event Control Flags (QA REMEDIATION - missing from original C++ mission_event struct) ---
@export var flags: int = 0 # Event behavior flags (MEF_* flags from missiongoals.h)
@export var display_count: int = 0 # Object count for directive display
@export var born_on_date: int = 0 # Timestamp at which event was born
@export var satisfied_time: int = 0 # Time when event was satisfied
