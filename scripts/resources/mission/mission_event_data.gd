# scripts/resources/mission_event_data.gd
# Defines a mission event triggered by a SEXP formula.
# Corresponds to the C++ 'mission_event' struct.
class_name MissionEventData
extends Resource

# --- Nested Resource Definition ---
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd") # Assuming SexpNode exists

# --- Event Definition ---
@export var name: String = "" # Optional name for the event
@export var formula_sexp: SexpNode = null # SEXP node for the trigger condition
@export var repeat_count: int = 1 # How many times to trigger (-1 for infinite until formula false?)
@export var trigger_count: int = 1 # Alternative trigger count (FS2 feature)
@export var interval_seconds: int = -1 # Delay between repeats in seconds (-1 means no interval)
@export var score: int = 0 # Score awarded when triggered
@export var chain_delay_seconds: int = -1 # Delay before next chained event can trigger (-1 means not chained)
@export var objective_text: String = "" # Text to display on HUD directives when active
@export var objective_key_text: String = "" # Key binding text associated with the objective
@export var team: int = -1 # Team this event applies to (-1 for all)

# --- Runtime State (Managed by MissionManager) ---
# These are not exported, they are set during gameplay
var result: bool = false # Current evaluation result
var flags: int = 0 # Runtime flags (e.g., MEF_CURRENT, MEF_USING_TRIGGER_COUNT)
var count: int = 0 # Runtime counter (e.g., for directives)
var satisfied_time: float = 0.0 # Mission time when first satisfied
var born_on_date: int = 0 # Timestamp when first became active
var timestamp: int = -1 # Timestamp for next interval check
