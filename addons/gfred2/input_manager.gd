@tool
extends Node

signal shortcut_triggered(shortcut_name: String)

# Track currently pressed modifiers
var active_modifiers := []

# Shortcut categories
enum ShortcutCategory {
	VIEW,
	CAMERA,
	EDIT,
	TRANSFORM,
	SELECTION,
	SPEED,
	CAMERA_SPEED,
	CAMERA_MODE
}

# Core shortcut definitions 
var shortcuts := {
	# Camera modes
	"camera_free": {"key": KEY_F, "modifiers": [KEY_MASK_SHIFT], "category": ShortcutCategory.CAMERA_MODE},
	"camera_orbit": {"key": KEY_O, "modifiers": [KEY_MASK_SHIFT], "category": ShortcutCategory.CAMERA_MODE},
	"camera_flyby": {"key": KEY_B, "modifiers": [KEY_MASK_SHIFT], "category": ShortcutCategory.CAMERA_MODE},
	"camera_ship": {"key": KEY_V, "modifiers": [KEY_MASK_SHIFT], "category": ShortcutCategory.CAMERA_MODE},
	
	# Camera controls
	"camera_save": {"key": KEY_S, "modifiers": [KEY_MASK_SHIFT, KEY_MASK_ALT], "category": ShortcutCategory.CAMERA},
	"camera_restore": {"key": KEY_R, "modifiers": [KEY_MASK_SHIFT, KEY_MASK_ALT], "category": ShortcutCategory.CAMERA},
	"camera_focus": {"key": KEY_F, "modifiers": [KEY_MASK_CTRL], "category": ShortcutCategory.CAMERA},
	"camera_snap_angles": {"key": KEY_A, "modifiers": [KEY_MASK_SHIFT, KEY_MASK_ALT], "category": ShortcutCategory.CAMERA},
	
	# Camera speeds
	"camera_speed_1": {"key": KEY_1, "modifiers": [KEY_MASK_ALT], "category": ShortcutCategory.CAMERA_SPEED},
	"camera_speed_2": {"key": KEY_2, "modifiers": [KEY_MASK_ALT], "category": ShortcutCategory.CAMERA_SPEED},
	"camera_speed_5": {"key": KEY_3, "modifiers": [KEY_MASK_ALT], "category": ShortcutCategory.CAMERA_SPEED},
	"camera_speed_10": {"key": KEY_4, "modifiers": [KEY_MASK_ALT], "category": ShortcutCategory.CAMERA_SPEED},
	"camera_speed_20": {"key": KEY_5, "modifiers": [KEY_MASK_ALT], "category": ShortcutCategory.CAMERA_SPEED},
	"camera_speed_50": {"key": KEY_6, "modifiers": [KEY_MASK_ALT], "category": ShortcutCategory.CAMERA_SPEED},
	# View controls
	"view_show_grid": {"key": KEY_G, "modifiers": [KEY_MASK_SHIFT, KEY_MASK_ALT], "category": ShortcutCategory.VIEW},
	"view_show_models": {"key": KEY_M, "modifiers": [KEY_MASK_SHIFT, KEY_MASK_ALT], "category": ShortcutCategory.VIEW},
	"view_show_outlines": {"key": KEY_O, "modifiers": [KEY_MASK_SHIFT, KEY_MASK_ALT], "category": ShortcutCategory.VIEW},
	"view_show_coordinates": {"key": KEY_C, "modifiers": [KEY_MASK_SHIFT, KEY_MASK_ALT], "category": ShortcutCategory.VIEW},
	"view_show_distances": {"key": KEY_D, "modifiers": [KEY_MASK_SHIFT, KEY_MASK_ALT], "category": ShortcutCategory.VIEW},
	"view_show_info": {"key": KEY_I, "modifiers": [KEY_MASK_SHIFT, KEY_MASK_ALT], "category": ShortcutCategory.VIEW},
	
	# Camera controls
	"camera_save_pos": {"key": KEY_S, "modifiers": [KEY_MASK_SHIFT, KEY_MASK_ALT], "category": ShortcutCategory.CAMERA},
	"camera_restore_pos": {"key": KEY_R, "modifiers": [KEY_MASK_SHIFT, KEY_MASK_ALT], "category": ShortcutCategory.CAMERA},
	"camera_top": {"key": KEY_PAGEUP, "modifiers": [], "category": ShortcutCategory.CAMERA},
	"camera_bottom": {"key": KEY_PAGEDOWN, "modifiers": [], "category": ShortcutCategory.CAMERA},
	"camera_front": {"key": KEY_HOME, "modifiers": [], "category": ShortcutCategory.CAMERA},
	"camera_back": {"key": KEY_END, "modifiers": [], "category": ShortcutCategory.CAMERA},
	"camera_left": {"key": KEY_DELETE, "modifiers": [], "category": ShortcutCategory.CAMERA},
	"camera_right": {"key": KEY_INSERT, "modifiers": [], "category": ShortcutCategory.CAMERA},
	# Edit controls
	"edit_undo": {"key": KEY_Z, "modifiers": [KEY_MASK_CTRL], "category": ShortcutCategory.EDIT},
	"edit_redo": {"key": KEY_Y, "modifiers": [KEY_MASK_CTRL], "category": ShortcutCategory.EDIT},
	"edit_delete": {"key": KEY_DELETE, "modifiers": [], "category": ShortcutCategory.EDIT},
	"edit_delete_wing": {"key": KEY_DELETE, "modifiers": [KEY_MASK_CTRL], "category": ShortcutCategory.EDIT},
	
	# Transform controls
	"transform_translate": {"key": KEY_T, "modifiers": [], "category": ShortcutCategory.TRANSFORM},
	"transform_rotate": {"key": KEY_R, "modifiers": [], "category": ShortcutCategory.TRANSFORM},
	"transform_scale": {"key": KEY_S, "modifiers": [], "category": ShortcutCategory.TRANSFORM},
	"transform_toggle_space": {"key": KEY_X, "modifiers": [], "category": ShortcutCategory.TRANSFORM},
	"transform_toggle_snap": {"key": KEY_TAB, "modifiers": [], "category": ShortcutCategory.TRANSFORM},
	"transform_increase_snap": {"key": KEY_BRACKETRIGHT, "modifiers": [], "category": ShortcutCategory.TRANSFORM},
	"transform_decrease_snap": {"key": KEY_BRACKETLEFT, "modifiers": [], "category": ShortcutCategory.TRANSFORM},
	
	# Movement modes
	"mode_translate": {"key": KEY_T, "modifiers": []},
	"mode_rotate": {"key": KEY_R, "modifiers": []},
	"mode_scale": {"key": KEY_S, "modifiers": []},
	
	# Transform space
	"toggle_space": {"key": KEY_X, "modifiers": []},
	
	# Selection groups
	"select_group_1": {"key": KEY_1, "modifiers": [KEY_MASK_CTRL]},
	"select_group_2": {"key": KEY_2, "modifiers": [KEY_MASK_CTRL]},
	"select_group_3": {"key": KEY_3, "modifiers": [KEY_MASK_CTRL]},
	"select_group_4": {"key": KEY_4, "modifiers": [KEY_MASK_CTRL]},
	"select_group_5": {"key": KEY_5, "modifiers": [KEY_MASK_CTRL]},
	"select_group_6": {"key": KEY_6, "modifiers": [KEY_MASK_CTRL]},
	"select_group_7": {"key": KEY_7, "modifiers": [KEY_MASK_CTRL]},
	"select_group_8": {"key": KEY_8, "modifiers": [KEY_MASK_CTRL]},
	"select_group_9": {"key": KEY_9, "modifiers": [KEY_MASK_CTRL]},
	
	# Movement speeds
	"speed_movement_1": {"key": KEY_1, "modifiers": []},
	"speed_movement_2": {"key": KEY_2, "modifiers": []}, 
	"speed_movement_3": {"key": KEY_3, "modifiers": []},
	"speed_movement_5": {"key": KEY_4, "modifiers": []},
	"speed_movement_8": {"key": KEY_5, "modifiers": []},
	"speed_movement_10": {"key": KEY_6, "modifiers": []},
	"speed_movement_50": {"key": KEY_7, "modifiers": []},
	"speed_movement_100": {"key": KEY_8, "modifiers": []},
	
	# Rotation speeds
	"speed_rotation_1": {"key": KEY_1, "modifiers": [KEY_MASK_SHIFT]},
	"speed_rotation_5": {"key": KEY_2, "modifiers": [KEY_MASK_SHIFT]},
	"speed_rotation_12": {"key": KEY_3, "modifiers": [KEY_MASK_SHIFT]},
	"speed_rotation_25": {"key": KEY_4, "modifiers": [KEY_MASK_SHIFT]},
	"speed_rotation_50": {"key": KEY_5, "modifiers": [KEY_MASK_SHIFT]},
	
	# Essential editors
	"editor_ships": {"key": KEY_S, "modifiers": [KEY_MASK_SHIFT]},
	"editor_wings": {"key": KEY_W, "modifiers": [KEY_MASK_SHIFT]},
	"editor_events": {"key": KEY_E, "modifiers": [KEY_MASK_SHIFT]},
}

func _unhandled_key_input(event: InputEvent):
	if event.pressed:
		# Track modifier keys
		if event.keycode in [KEY_CTRL, KEY_SHIFT, KEY_ALT]:
			var modifier = _get_modifier_mask(event.keycode)
			if !active_modifiers.has(modifier):
				active_modifiers.append(modifier)
		
		# Check shortcuts
		for shortcut_name in shortcuts:
			var shortcut = shortcuts[shortcut_name]
			if event.keycode == shortcut.key:
				# Check if required modifiers match
				var modifiers_match = true
				for modifier in shortcut.modifiers:
					if !active_modifiers.has(modifier):
						modifiers_match = false
						break
				
				if modifiers_match:
					shortcut_triggered.emit(shortcut_name)
					get_viewport().set_input_as_handled()
					break
	
	else: # Key released
		# Remove modifier from active list
		if event.keycode in [KEY_CTRL, KEY_SHIFT, KEY_ALT]:
			var modifier = _get_modifier_mask(event.keycode)
			active_modifiers.erase(modifier)

func _get_modifier_mask(keycode: int) -> int:
	match keycode:
		KEY_CTRL:
			return KEY_MASK_CTRL
		KEY_SHIFT:
			return KEY_MASK_SHIFT
		KEY_ALT:
			return KEY_MASK_ALT
		_:
			return 0

func get_shortcut_text(shortcut_name: String) -> String:
	if !shortcuts.has(shortcut_name):
		return ""
		
	var shortcut = shortcuts[shortcut_name]
	var text = ""
	
	# Add modifier symbols
	if shortcut.modifiers.has(KEY_MASK_CTRL):
		text += "Ctrl+"
	if shortcut.modifiers.has(KEY_MASK_SHIFT):
		text += "Shift+"
	if shortcut.modifiers.has(KEY_MASK_ALT):
		text += "Alt+"
		
	# Add key name
	text += OS.get_keycode_string(shortcut.key)
	
	return text
