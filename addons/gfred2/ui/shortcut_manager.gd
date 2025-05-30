@tool
class_name GFRED2ShortcutManager
extends RefCounted

## Configurable keyboard shortcut system for GFRED2 with accessibility support.
## Provides customizable shortcuts, conflict detection, and accessibility features.

signal shortcut_triggered(action_name: String, event: InputEvent)
signal shortcut_changed(action_name: String, old_shortcut: InputEventKey, new_shortcut: InputEventKey)
signal conflict_detected(action_name: String, conflicting_action: String)

# Shortcut registry
var shortcuts: Dictionary = {}
var shortcut_contexts: Dictionary = {}
var active_context: String = "global"

# Configuration
var config_path: String = "user://gfred2_shortcuts.cfg"
var default_shortcuts: Dictionary = {}

# Accessibility settings
var enable_sticky_keys: bool = false
var enable_slow_keys: bool = false
var slow_keys_delay: float = 0.5
var enable_bounce_keys: bool = false
var bounce_keys_delay: float = 0.5

# Modifier tracking for accessibility
var modifier_states: Dictionary = {
	"ctrl": false,
	"shift": false,
	"alt": false,
	"meta": false
}

var pending_slow_key: InputEventKey = null
var slow_key_timer: float = 0.0
var last_key_time: float = 0.0

# Action categories for organization
enum Category {
	FILE,
	EDIT,
	VIEW,
	CAMERA,
	OBJECT,
	SELECTION,
	TOOL,
	DEBUG,
	ACCESSIBILITY
}

# Shortcut action definition
class ShortcutAction:
	var name: String
	var display_name: String
	var description: String
	var category: Category
	var default_shortcut: InputEventKey
	var current_shortcut: InputEventKey
	var context: String = "global"
	var is_accessibility: bool = false
	
	func _init(action_name: String, display: String, desc: String, cat: Category, shortcut: InputEventKey, ctx: String = "global") -> void:
		name = action_name
		display_name = display
		description = desc
		category = cat
		default_shortcut = shortcut
		current_shortcut = shortcut.duplicate() if shortcut else null
		context = ctx

func _init() -> void:
	_setup_default_shortcuts()
	load_shortcuts()

func _setup_default_shortcuts() -> void:
	"""Setup all default keyboard shortcuts."""
	# File operations
	_register_shortcut("file_new", "New Mission", "Create a new mission", Category.FILE, _create_key_event(KEY_N, true))
	_register_shortcut("file_open", "Open Mission", "Open an existing mission", Category.FILE, _create_key_event(KEY_O, true))
	_register_shortcut("file_save", "Save Mission", "Save the current mission", Category.FILE, _create_key_event(KEY_S, true))
	_register_shortcut("file_save_as", "Save As", "Save mission with new name", Category.FILE, _create_key_event(KEY_S, true, true))
	_register_shortcut("file_import", "Import Mission", "Import mission from file", Category.FILE, _create_key_event(KEY_I, true))
	_register_shortcut("file_export", "Export Mission", "Export mission to file", Category.FILE, _create_key_event(KEY_E, true))
	
	# Edit operations
	_register_shortcut("edit_undo", "Undo", "Undo last action", Category.EDIT, _create_key_event(KEY_Z, true))
	_register_shortcut("edit_redo", "Redo", "Redo last undone action", Category.EDIT, _create_key_event(KEY_Y, true))
	_register_shortcut("edit_cut", "Cut", "Cut selected objects", Category.EDIT, _create_key_event(KEY_X, true))
	_register_shortcut("edit_copy", "Copy", "Copy selected objects", Category.EDIT, _create_key_event(KEY_C, true))
	_register_shortcut("edit_paste", "Paste", "Paste objects from clipboard", Category.EDIT, _create_key_event(KEY_V, true))
	_register_shortcut("edit_delete", "Delete", "Delete selected objects", Category.EDIT, _create_key_event(KEY_DELETE))
	_register_shortcut("edit_duplicate", "Duplicate", "Duplicate selected objects", Category.EDIT, _create_key_event(KEY_D, true))
	_register_shortcut("edit_select_all", "Select All", "Select all objects", Category.EDIT, _create_key_event(KEY_A, true))
	_register_shortcut("edit_deselect", "Deselect All", "Clear selection", Category.EDIT, _create_key_event(KEY_A, true, true))
	
	# View controls
	_register_shortcut("view_toggle_grid", "Toggle Grid", "Show/hide grid", Category.VIEW, _create_key_event(KEY_G))
	_register_shortcut("view_toggle_wireframe", "Toggle Wireframe", "Toggle wireframe mode", Category.VIEW, _create_key_event(KEY_W))
	_register_shortcut("view_toggle_models", "Toggle Models", "Show/hide ship models", Category.VIEW, _create_key_event(KEY_M))
	_register_shortcut("view_toggle_outlines", "Toggle Outlines", "Show/hide object outlines", Category.VIEW, _create_key_event(KEY_O))
	_register_shortcut("view_fullscreen", "Toggle Fullscreen", "Toggle fullscreen mode", Category.VIEW, _create_key_event(KEY_F11))
	_register_shortcut("view_focus_selection", "Focus Selection", "Focus camera on selection", Category.VIEW, _create_key_event(KEY_F))
	
	# Camera controls
	_register_shortcut("camera_free", "Free Camera", "Switch to free camera mode", Category.CAMERA, _create_key_event(KEY_1))
	_register_shortcut("camera_orbit", "Orbit Camera", "Switch to orbit camera mode", Category.CAMERA, _create_key_event(KEY_2))
	_register_shortcut("camera_locked", "Locked Camera", "Switch to locked camera mode", Category.CAMERA, _create_key_event(KEY_3))
	_register_shortcut("camera_reset", "Reset Camera", "Reset camera to default position", Category.CAMERA, _create_key_event(KEY_HOME))
	_register_shortcut("camera_save_pos", "Save Camera Position", "Save current camera position", Category.CAMERA, _create_key_event(KEY_F9))
	_register_shortcut("camera_restore_pos", "Restore Camera Position", "Restore saved camera position", Category.CAMERA, _create_key_event(KEY_F10))
	
	# Object manipulation
	_register_shortcut("object_create_ship", "Create Ship", "Create new ship object", Category.OBJECT, _create_key_event(KEY_INSERT))
	_register_shortcut("object_create_waypoint", "Create Waypoint", "Create new waypoint", Category.OBJECT, _create_key_event(KEY_INSERT, false, true))
	_register_shortcut("object_properties", "Object Properties", "Open object properties dialog", Category.OBJECT, _create_key_event(KEY_ENTER, false, true))
	_register_shortcut("object_align_grid", "Align to Grid", "Align selected objects to grid", Category.OBJECT, _create_key_event(KEY_G, true))
	
	# Selection
	_register_shortcut("select_group_1", "Selection Group 1", "Store/recall selection group 1", Category.SELECTION, _create_key_event(KEY_1, true))
	_register_shortcut("select_group_2", "Selection Group 2", "Store/recall selection group 2", Category.SELECTION, _create_key_event(KEY_2, true))
	_register_shortcut("select_group_3", "Selection Group 3", "Store/recall selection group 3", Category.SELECTION, _create_key_event(KEY_3, true))
	_register_shortcut("select_group_4", "Selection Group 4", "Store/recall selection group 4", Category.SELECTION, _create_key_event(KEY_4, true))
	_register_shortcut("select_by_type", "Select by Type", "Select all objects of same type", Category.SELECTION, _create_key_event(KEY_T, true))
	_register_shortcut("select_next", "Select Next", "Select next object in hierarchy", Category.SELECTION, _create_key_event(KEY_TAB))
	_register_shortcut("select_previous", "Select Previous", "Select previous object in hierarchy", Category.SELECTION, _create_key_event(KEY_TAB, false, true))
	
	# Tools
	_register_shortcut("tool_translate", "Translate Tool", "Switch to translate tool", Category.TOOL, _create_key_event(KEY_Q))
	_register_shortcut("tool_rotate", "Rotate Tool", "Switch to rotate tool", Category.TOOL, _create_key_event(KEY_E))
	_register_shortcut("tool_scale", "Scale Tool", "Switch to scale tool", Category.TOOL, _create_key_event(KEY_R))
	_register_shortcut("tool_toggle_space", "Toggle Tool Space", "Toggle between local/world space", Category.TOOL, _create_key_event(KEY_SPACE))
	_register_shortcut("tool_toggle_snap", "Toggle Snapping", "Enable/disable snapping", Category.TOOL, _create_key_event(KEY_S))
	
	# Debug and testing
	_register_shortcut("debug_toggle_console", "Toggle Debug Console", "Show/hide debug console", Category.DEBUG, _create_key_event(KEY_QUOTELEFT))
	_register_shortcut("debug_validate_mission", "Validate Mission", "Run mission validation", Category.DEBUG, _create_key_event(KEY_F5))
	_register_shortcut("debug_test_mission", "Test Mission", "Test current mission", Category.DEBUG, _create_key_event(KEY_F6))
	
	# Accessibility shortcuts
	_register_shortcut("accessibility_sticky_keys", "Toggle Sticky Keys", "Enable/disable sticky keys", Category.ACCESSIBILITY, _create_key_event(KEY_SHIFT, false, false, false, false, true), "global", true)
	_register_shortcut("accessibility_slow_keys", "Toggle Slow Keys", "Enable/disable slow keys", Category.ACCESSIBILITY, _create_key_event(KEY_CTRL, false, false, false, false, true), "global", true)
	_register_shortcut("accessibility_high_contrast", "Toggle High Contrast", "Enable/disable high contrast mode", Category.ACCESSIBILITY, _create_key_event(KEY_H, true, true), "global", true)
	_register_shortcut("accessibility_screen_reader", "Screen Reader Help", "Announce current context for screen readers", Category.ACCESSIBILITY, _create_key_event(KEY_F1, false, false, true), "global", true)

func _register_shortcut(action_name: String, display_name: String, description: String, category: Category, shortcut: InputEventKey, context: String = "global", is_accessibility: bool = false) -> void:
	"""Register a new shortcut action."""
	var action = ShortcutAction.new(action_name, display_name, description, category, shortcut, context)
	action.is_accessibility = is_accessibility
	shortcuts[action_name] = action
	
	# Add to context
	if not shortcut_contexts.has(context):
		shortcut_contexts[context] = []
	shortcut_contexts[context].append(action_name)

func _create_key_event(keycode: Key, ctrl: bool = false, shift: bool = false, alt: bool = false, meta: bool = false, repeat: bool = false) -> InputEventKey:
	"""Create an InputEventKey with specified modifiers."""
	var event = InputEventKey.new()
	event.keycode = keycode
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	event.alt_pressed = alt
	event.meta_pressed = meta
	event.echo = repeat
	return event

func handle_input_event(event: InputEvent) -> bool:
	"""Handle input events and trigger appropriate shortcuts."""
	if not event is InputEventKey:
		return false
	
	var key_event = event as InputEventKey
	if not key_event.pressed:
		return false
	
	# Handle accessibility features
	if _handle_accessibility_input(key_event):
		return true
	
	# Process slow keys if enabled
	if enable_slow_keys and _handle_slow_keys(key_event):
		return true
	
	# Handle bounce keys
	if enable_bounce_keys and _handle_bounce_keys(key_event):
		return true
	
	# Find matching shortcut
	var action_name = _find_matching_shortcut(key_event)
	if not action_name.is_empty():
		shortcut_triggered.emit(action_name, key_event)
		return true
	
	return false

func _handle_accessibility_input(event: InputEventKey) -> bool:
	"""Handle accessibility-specific input processing."""
	# Sticky keys implementation
	if enable_sticky_keys:
		if _is_modifier_key(event.keycode):
			_toggle_sticky_modifier(event.keycode)
			return true
	
	# Check for accessibility shortcut activations
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Sticky keys toggle (5x shift)
	if event.keycode == KEY_SHIFT:
		# TODO: Implement 5x shift detection
		pass
	
	return false

func _handle_slow_keys(event: InputEventKey) -> bool:
	"""Handle slow keys processing."""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if pending_slow_key == null:
		# Start slow key timer
		pending_slow_key = event.duplicate()
		slow_key_timer = current_time
		return true
	elif _events_equal(pending_slow_key, event):
		# Check if delay has passed
		if current_time - slow_key_timer >= slow_keys_delay:
			pending_slow_key = null
			return false  # Allow normal processing
		else:
			return true  # Still waiting
	else:
		# Different key pressed, cancel pending
		pending_slow_key = null
		return false

func _handle_bounce_keys(event: InputEventKey) -> bool:
	"""Handle bounce keys processing."""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if current_time - last_key_time < bounce_keys_delay:
		return true  # Ignore rapid keypresses
	
	last_key_time = current_time
	return false

func _find_matching_shortcut(event: InputEventKey) -> String:
	"""Find a shortcut that matches the given input event."""
	var context_actions = shortcut_contexts.get(active_context, [])
	
	# Check active context first
	for action_name in context_actions:
		var action: ShortcutAction = shortcuts[action_name]
		if action.current_shortcut and _events_equal(action.current_shortcut, event):
			return action_name
	
	# Check global context if not already checked
	if active_context != "global":
		var global_actions = shortcut_contexts.get("global", [])
		for action_name in global_actions:
			var action: ShortcutAction = shortcuts[action_name]
			if action.current_shortcut and _events_equal(action.current_shortcut, event):
				return action_name
	
	return ""

func _events_equal(event1: InputEventKey, event2: InputEventKey) -> bool:
	"""Check if two input events are equivalent."""
	if not event1 or not event2:
		return false
	
	return (event1.keycode == event2.keycode and
			event1.ctrl_pressed == event2.ctrl_pressed and
			event1.shift_pressed == event2.shift_pressed and
			event1.alt_pressed == event2.alt_pressed and
			event1.meta_pressed == event2.meta_pressed)

func set_shortcut(action_name: String, new_shortcut: InputEventKey) -> bool:
	"""Set a new shortcut for an action."""
	if not shortcuts.has(action_name):
		push_error("Unknown shortcut action: " + action_name)
		return false
	
	var action: ShortcutAction = shortcuts[action_name]
	var old_shortcut = action.current_shortcut
	
	# Check for conflicts
	var conflicting_action = _find_conflicting_action(new_shortcut, action_name)
	if not conflicting_action.is_empty():
		conflict_detected.emit(action_name, conflicting_action)
		return false
	
	action.current_shortcut = new_shortcut
	shortcut_changed.emit(action_name, old_shortcut, new_shortcut)
	return true

func _find_conflicting_action(shortcut: InputEventKey, exclude_action: String = "") -> String:
	"""Find if a shortcut conflicts with existing actions."""
	for action_name in shortcuts:
		if action_name == exclude_action:
			continue
		
		var action: ShortcutAction = shortcuts[action_name]
		if action.current_shortcut and _events_equal(action.current_shortcut, shortcut):
			return action_name
	
	return ""

func get_shortcut(action_name: String) -> InputEventKey:
	"""Get the current shortcut for an action."""
	if not shortcuts.has(action_name):
		return null
	
	return shortcuts[action_name].current_shortcut

func get_shortcut_display_string(action_name: String) -> String:
	"""Get a human-readable string for a shortcut."""
	var shortcut = get_shortcut(action_name)
	if not shortcut:
		return "None"
	
	var parts: Array[String] = []
	
	if shortcut.ctrl_pressed:
		parts.append("Ctrl")
	if shortcut.shift_pressed:
		parts.append("Shift")
	if shortcut.alt_pressed:
		parts.append("Alt")
	if shortcut.meta_pressed:
		parts.append("Meta")
	
	parts.append(OS.get_keycode_string(shortcut.keycode))
	
	return "+".join(parts)

func reset_shortcut(action_name: String) -> bool:
	"""Reset a shortcut to its default value."""
	if not shortcuts.has(action_name):
		return false
	
	var action: ShortcutAction = shortcuts[action_name]
	var old_shortcut = action.current_shortcut
	action.current_shortcut = action.default_shortcut.duplicate() if action.default_shortcut else null
	
	shortcut_changed.emit(action_name, old_shortcut, action.current_shortcut)
	return true

func reset_all_shortcuts() -> void:
	"""Reset all shortcuts to their default values."""
	for action_name in shortcuts:
		reset_shortcut(action_name)

func get_actions_by_category(category: Category) -> Array[String]:
	"""Get all action names in a specific category."""
	var actions: Array[String] = []
	
	for action_name in shortcuts:
		var action: ShortcutAction = shortcuts[action_name]
		if action.category == category:
			actions.append(action_name)
	
	return actions

func get_action_display_name(action_name: String) -> String:
	"""Get the display name for an action."""
	if not shortcuts.has(action_name):
		return action_name
	
	return shortcuts[action_name].display_name

func get_action_description(action_name: String) -> String:
	"""Get the description for an action."""
	if not shortcuts.has(action_name):
		return ""
	
	return shortcuts[action_name].description

func set_context(context_name: String) -> void:
	"""Set the active shortcut context."""
	active_context = context_name

func get_context() -> String:
	"""Get the current active context."""
	return active_context

func save_shortcuts() -> void:
	"""Save shortcuts to configuration file."""
	var config = ConfigFile.new()
	
	for action_name in shortcuts:
		var action: ShortcutAction = shortcuts[action_name]
		if action.current_shortcut:
			config.set_value("shortcuts", action_name + "_keycode", action.current_shortcut.keycode)
			config.set_value("shortcuts", action_name + "_ctrl", action.current_shortcut.ctrl_pressed)
			config.set_value("shortcuts", action_name + "_shift", action.current_shortcut.shift_pressed)
			config.set_value("shortcuts", action_name + "_alt", action.current_shortcut.alt_pressed)
			config.set_value("shortcuts", action_name + "_meta", action.current_shortcut.meta_pressed)
		else:
			config.set_value("shortcuts", action_name + "_keycode", 0)
	
	# Save accessibility settings
	config.set_value("accessibility", "sticky_keys", enable_sticky_keys)
	config.set_value("accessibility", "slow_keys", enable_slow_keys)
	config.set_value("accessibility", "slow_keys_delay", slow_keys_delay)
	config.set_value("accessibility", "bounce_keys", enable_bounce_keys)
	config.set_value("accessibility", "bounce_keys_delay", bounce_keys_delay)
	
	var save_result = config.save(config_path)
	if save_result != OK:
		push_warning("Failed to save shortcuts: " + str(save_result))

func load_shortcuts() -> void:
	"""Load shortcuts from configuration file."""
	var config = ConfigFile.new()
	var load_result = config.load(config_path)
	
	if load_result != OK:
		print("No saved shortcuts found, using defaults")
		return
	
	# Load shortcuts
	for action_name in shortcuts:
		var keycode = config.get_value("shortcuts", action_name + "_keycode", 0)
		if keycode != 0:
			var event = InputEventKey.new()
			event.keycode = keycode
			event.ctrl_pressed = config.get_value("shortcuts", action_name + "_ctrl", false)
			event.shift_pressed = config.get_value("shortcuts", action_name + "_shift", false)
			event.alt_pressed = config.get_value("shortcuts", action_name + "_alt", false)
			event.meta_pressed = config.get_value("shortcuts", action_name + "_meta", false)
			
			shortcuts[action_name].current_shortcut = event
		else:
			shortcuts[action_name].current_shortcut = null
	
	# Load accessibility settings
	enable_sticky_keys = config.get_value("accessibility", "sticky_keys", false)
	enable_slow_keys = config.get_value("accessibility", "slow_keys", false)
	slow_keys_delay = config.get_value("accessibility", "slow_keys_delay", 0.5)
	enable_bounce_keys = config.get_value("accessibility", "bounce_keys", false)
	bounce_keys_delay = config.get_value("accessibility", "bounce_keys_delay", 0.5)

func enable_accessibility_feature(feature: String, enabled: bool) -> void:
	"""Enable or disable an accessibility feature."""
	match feature:
		"sticky_keys":
			enable_sticky_keys = enabled
		"slow_keys":
			enable_slow_keys = enabled
		"bounce_keys":
			enable_bounce_keys = enabled

func set_accessibility_timing(feature: String, delay: float) -> void:
	"""Set timing parameters for accessibility features."""
	match feature:
		"slow_keys":
			slow_keys_delay = max(0.1, delay)
		"bounce_keys":
			bounce_keys_delay = max(0.1, delay)

func _is_modifier_key(keycode: Key) -> bool:
	"""Check if a keycode is a modifier key."""
	return keycode in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]

func _toggle_sticky_modifier(keycode: Key) -> void:
	"""Toggle sticky modifier state."""
	match keycode:
		KEY_CTRL:
			modifier_states["ctrl"] = not modifier_states["ctrl"]
		KEY_SHIFT:
			modifier_states["shift"] = not modifier_states["shift"]
		KEY_ALT:
			modifier_states["alt"] = not modifier_states["alt"]
		KEY_META:
			modifier_states["meta"] = not modifier_states["meta"]

func get_category_display_name(category: Category) -> String:
	"""Get display name for a category."""
	match category:
		Category.FILE:
			return "File Operations"
		Category.EDIT:
			return "Edit Operations"
		Category.VIEW:
			return "View Controls"
		Category.CAMERA:
			return "Camera Controls"
		Category.OBJECT:
			return "Object Operations"
		Category.SELECTION:
			return "Selection"
		Category.TOOL:
			return "Tools"
		Category.DEBUG:
			return "Debug & Testing"
		Category.ACCESSIBILITY:
			return "Accessibility"
		_:
			return "Unknown"