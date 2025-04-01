# script_condition.gd
# Base class or Resource defining a single condition for a ConditionedHook.
# Specific condition types would inherit from this or this script would
# contain logic to handle different condition_type values.
class_name ScriptCondition
extends Resource # Using Resource allows defining conditions in .tres files

# Import constants for condition types
const GlobalConstants = preload("res://scripts/globals/global_constants.gd")

## The type of condition to check (e.g., STATE, SHIPCLASS, MISSION).
@export var condition_type: GlobalConstants.HookConditionType = GlobalConstants.HookConditionType.NONE

## Data associated with the condition (e.g., state name, ship class name).
## Using String for flexibility, specific checks will parse/use it accordingly.
@export var condition_data: String = ""

## Optional numerical data (e.g., key scancode for KEYPRESS).
@export var condition_value: int = -1


## Checks if this condition is met given the current game context.
## The context dictionary should contain relevant information based on the action
## that triggered the hook check (e.g., current_state, ship_node, key_event).
## Returns true if the condition is met, false otherwise.
func is_valid(context: Dictionary) -> bool:
	match condition_type:
		GlobalConstants.HookConditionType.NONE:
			return true # A 'NONE' condition is always true? Or should it be false? Assuming true for now.

		GlobalConstants.HookConditionType.STATE:
			var current_state_id = context.get("current_state_id", GlobalConstants.GameState.NONE)
			# Need a way to map state ID back to the name used in condition_data
			# This might require GameManager or GameSequenceManager access.
			# Placeholder: Assume condition_data holds the expected state *name*.
			var current_state_name = _get_state_name_from_id(current_state_id) # Helper needed
			if current_state_name.is_empty():
				push_warning("Could not get current state name for hook condition check.")
				return false
			return current_state_name.nocasecmp_to(condition_data) == 0

		GlobalConstants.HookConditionType.MISSION:
			# Context needs: "mission_name": String (e.g., "sm1-01.fs2")
			var current_mission_filename = context.get("mission_name", "")
			if current_mission_filename.is_empty():
				# If no mission name in context, condition cannot be met.
				# This might happen if checked outside of an active mission state.
				# push_warning("Mission name not found in context for CHC_MISSION check.")
				return false
			# Compare base filenames (without extension), case-insensitive.
			# condition_data should store the target mission filename (e.g., "sm1-01").
			var current_base_name = current_mission_filename.get_basename().get_file()
			var target_base_name = condition_data.get_basename().get_file()
			# print("Checking MISSION condition: Current='%s', Target='%s'" % [current_base_name, target_base_name]) # Debug
			return current_base_name.nocasecmp_to(target_base_name) == 0

		GlobalConstants.HookConditionType.CAMPAIGN:
			# Context needs: "campaign_name": String (e.g., "wcsaga.fc2")
			var current_campaign_filename = context.get("campaign_name", "")
			if current_campaign_filename.is_empty():
				# push_warning("Campaign name not found in context for CHC_CAMPAIGN check.")
				return false
			# Compare base filenames, case-insensitive.
			# condition_data should store the target campaign filename (e.g., "wcsaga").
			var current_base_name = current_campaign_filename.get_basename().get_file()
			var target_base_name = condition_data.get_basename().get_file()
			# print("Checking CAMPAIGN condition: Current='%s', Target='%s'" % [current_base_name, target_base_name]) # Debug
			return current_base_name.nocasecmp_to(target_base_name) == 0

		GlobalConstants.HookConditionType.SHIP:
			# Context needs: "ship_node": Node (e.g., ShipBase instance)
			var ship_node = context.get("ship_node")
			# Assuming ShipBase has get_ship_name() method
			if not is_instance_valid(ship_node) or not ship_node.has_method("get_ship_name"):
				# push_warning("Ship node not found or invalid in context for CHC_SHIP check.")
				return false
			var ship_name = ship_node.get_ship_name()
			# print("Checking SHIP condition: Current='%s', Target='%s'" % [ship_name, condition_data]) # Debug
			return ship_name.nocasecmp_to(condition_data) == 0

		GlobalConstants.HookConditionType.SHIPCLASS:
			# Context needs: "ship_node": Node (e.g., ShipBase instance)
			var ship_node = context.get("ship_node")
			# Assuming ShipBase has get_ship_class_name() method
			if not is_instance_valid(ship_node) or not ship_node.has_method("get_ship_class_name"):
				# push_warning("Ship node not found or invalid in context for CHC_SHIPCLASS check.")
				return false
			var class_name = ship_node.get_ship_class_name()
			# print("Checking SHIPCLASS condition: Current='%s', Target='%s'" % [class_name, condition_data]) # Debug
			return class_name.nocasecmp_to(condition_data) == 0

		GlobalConstants.HookConditionType.SHIPTYPE:
			# Context needs: "ship_node": Node (e.g., ShipBase instance)
			var ship_node = context.get("ship_node")
			# Assuming ShipBase has get_ship_type_name() method
			if not is_instance_valid(ship_node) or not ship_node.has_method("get_ship_type_name"):
				# push_warning("Ship node not found or invalid in context for CHC_SHIPTYPE check.")
				return false
			var type_name = ship_node.get_ship_type_name()
			# print("Checking SHIPTYPE condition: Current='%s', Target='%s'" % [type_name, condition_data]) # Debug
			return type_name.nocasecmp_to(condition_data) == 0

		GlobalConstants.HookConditionType.WEAPONCLASS:
			# Context needs: "weapon_node": Node (e.g., WeaponProjectile instance) or "weapon_data": WeaponData
			var weapon_class_name = ""
			var weapon_node = context.get("weapon_node")
			var weapon_data = context.get("weapon_data") # Allow passing data directly too
			if is_instance_valid(weapon_node) and weapon_node.has_method("get_weapon_class_name"):
				weapon_class_name = weapon_node.get_weapon_class_name()
			elif weapon_data is WeaponData:
				weapon_class_name = weapon_data.name # Assuming WeaponData has a 'name' property
			else:
				# push_warning("Weapon node/data not found or invalid in context for CHC_WEAPONCLASS check.")
				return false
			# print("Checking WEAPONCLASS condition: Current='%s', Target='%s'" % [weapon_class_name, condition_data]) # Debug
			return weapon_class_name.nocasecmp_to(condition_data) == 0

		GlobalConstants.HookConditionType.OBJECTTYPE:
			# Context needs: "object_node": Node (any BaseObject derivative)
			var obj_node = context.get("object_node")
			# Assuming BaseObject has get_object_type_name()
			if not is_instance_valid(obj_node) or not obj_node.has_method("get_object_type_name"):
				return false
			return obj_node.get_object_type_name().nocasecmp_to(condition_data) == 0

		GlobalConstants.HookConditionType.KEYPRESS:
			# Context needs: "key_event": InputEventKey
			var key_event = context.get("key_event")
			if not key_event is InputEventKey:
				return false
			# Compare physical keycode? Or scancode name?
			# Original used textify_scancode. Need similar mapping.
			if condition_value != -1:
				# Compare using the stored integer value (likely scancode from original table)
				# Godot's keycodes might differ, need mapping or use OS.find_keycode_from_string
				# For now, assume condition_value holds a Godot Key enum value or physical keycode
				# print("Checking KEYPRESS condition (value): Event=%d, Target=%d" % [key_event.physical_keycode, condition_value]) # Debug
				return key_event.physical_keycode == condition_value # Or key_event.keycode? Needs testing.
			elif not condition_data.is_empty():
				# Compare using the string name (e.g., "A", "Space", "Enter")
				var key_string = OS.get_keycode_string(key_event.physical_keycode).to_upper()
				var target_key_string = condition_data.to_upper()
				# print("Checking KEYPRESS condition (name): Event='%s', Target='%s'" % [key_string, target_key_string]) # Debug
				# This might need refinement based on how keys are named in original tables vs Godot.
				# Consider checking key_event.unicode as well for printable characters?
				return key_string == target_key_string
			else:
				push_warning("Invalid KEYPRESS condition: Neither condition_value nor condition_data is set.")
				return false

		GlobalConstants.HookConditionType.VERSION:
			# condition_data should hold the version string to compare against (e.g., "3.8.0")
			var current_version_dict = Engine.get_version_info()
			var current_version_str = "%d.%d.%d" % [current_version_dict.major, current_version_dict.minor, current_version_dict.patch]
			# Simple equality check for now. Could implement >, < checks if needed.
			# print("Checking VERSION condition: Current='%s', Target='%s'" % [current_version_str, condition_data]) # Debug
			# TODO: Implement proper version comparison (handle builds, revisions if necessary)
			return current_version_str == condition_data # Basic check

		GlobalConstants.HookConditionType.APPLICATION:
			# condition_data should be "FRED" or "FS2" (case-insensitive)
			var is_editor = Engine.is_editor_hint()
			var target_is_editor = (condition_data.nocasecmp_to("FRED") == 0 or \
									condition_data.nocasecmp_to("FRED2") == 0 or \
									condition_data.nocasecmp_to("FRED2_Open") == 0)
			var target_is_game = (condition_data.nocasecmp_to("FS2") == 0 or \
								  condition_data.nocasecmp_to("FS2_Open") == 0 or \
								  condition_data.nocasecmp_to("Freespace 2") == 0)

			# print("Checking APPLICATION condition: IsEditor=%s, Target='%s'" % [is_editor, condition_data]) # Debug
			if target_is_editor:
				return is_editor
			elif target_is_game:
				return not is_editor
			else:
				push_warning("Unknown application name in hook condition: %s" % condition_data)
				return false
#			var is_editor = Engine.is_editor_hint()
#			if condition_data.nocasecmp_to("FRED") == 0 or \
#			   condition_data.nocasecmp_to("FRED2_Open") == 0:
			   return is_editor
			elif condition_data.nocasecmp_to("FS2_Open") == 0 or \
				 condition_data.nocasecmp_to("Freespace 2") == 0:
				 return not is_editor
			else:
				push_warning("Unknown application name in hook condition: %s" % condition_data)
				return false

		_:
			push_error("Unknown hook condition type: %d" % condition_type)
			return false

	return false # Should not be reached


# --- Helper Functions ---

# Placeholder: Needs access to GameSequenceManager or similar to map ID to name
func _get_state_name_from_id(state_id: int) -> String:
	# This needs proper implementation, potentially calling a global function
	# or accessing a mapping dictionary.
	match state_id:
		GlobalConstants.GameState.MAIN_MENU: return "GS_STATE_MAIN_MENU"
		GlobalConstants.GameState.GAME_PLAY: return "GS_STATE_GAMEPLAY"
		GlobalConstants.GameState.BRIEFING: return "GS_STATE_BRIEFING"
		GlobalConstants.GameState.DEBRIEF: return "GS_STATE_DEBRIEFING"
		# ... add mappings for all relevant states used in hooks ...
		_: return ""
