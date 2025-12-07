extends Node

# GlobalSettings.gd
# Manages application-wide settings (Audio, Video, Controls)

const CONFIG_FILE = "user://settings.cfg"

static var _config: ConfigFile

static func _ensure_config():
	if _config == null:
		_config = ConfigFile.new()
		var err = _config.load(CONFIG_FILE)
		if err != OK:
			print("Creating new settings file")
			_save_config()

static func _save_config():
	if _config:
		_config.save(CONFIG_FILE)

func set_audio_volume(bus_name: String, value: float):
	_ensure_config()
	print("Setting Audio Bus ", bus_name, " to ", value)
	_config.set_value("audio", bus_name + "_volume", value)

	# Apply to AudioServer
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		var db_value = linear_to_db(value)
		AudioServer.set_bus_volume_db(bus_idx, db_value)

	_save_config()

func get_audio_volume(bus_name: String) -> float:
	_ensure_config()
	return _config.get_value("audio", bus_name + "_volume", 1.0)

func set_video_setting(setting: String, value):
	_ensure_config()
	print("Setting Video ", setting, " to ", value)
	_config.set_value("video", setting, value)

	match setting:
		"resolution":
			if value is Vector2i:
				DisplayServer.window_set_size(value)
		"window_mode":
			match value:
				"Fullscreen":
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				"Windowed":
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				"Borderless":
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
					DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		"hologram_quality":
			# This will be used by the UI shaders to adjust quality
			pass

	_save_config()

func get_video_setting(setting: String, default = null):
	_ensure_config()
	return _config.get_value("video", setting, default)

func set_input_binding(action: String, event: InputEvent):
	_ensure_config()
	# Clear existing bindings
	InputMap.action_erase_events(action)
	# Add new binding
	InputMap.action_add_event(action, event)

	# Save to config
	var event_dict = {
		"type": event.get_class(),
		"keycode": event.keycode if event is InputEventKey else -1,
		"button_index": event.button_index if event is InputEventMouseButton else -1,
		"physical_keycode": event.physical_keycode if event is InputEventKey else -1
	}
	_config.set_value("controls", action, event_dict)
	_save_config()

static func load_input_bindings():
	_ensure_config()
	# Get all actions from InputMap
	for action in InputMap.get_actions():
		if _config.has_section_key("controls", action):
			var event_dict = _config.get_value("controls", action)
			# Reconstruct the event based on type
			var event: InputEvent = null
			match event_dict.get("type", ""):
				"InputEventKey":
					event = InputEventKey.new()
					event.physical_keycode = event_dict.get("physical_keycode", 0)
				"InputEventMouseButton":
					event = InputEventMouseButton.new()
					event.button_index = event_dict.get("button_index", 1)

			if event:
				InputMap.action_erase_events(action)
				InputMap.action_add_event(action, event)
