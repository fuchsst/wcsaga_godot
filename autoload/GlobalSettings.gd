extends Node
## GlobalSettings.gd
## Manages global application settings (graphics, window) and control action registry.
## Per-profile settings (audio, input, gameplay) are stored in UserProfile.settings.

signal settings_changed
signal detail_settings_changed

const GLOBAL_CONFIG_FILE := "user://global_settings.cfg"
const DETAIL_SETTINGS_FILE := "user://detail_settings.tres"

# Global graphics/window settings (shared across profiles)
var detail: DetailSettings
var gamma: float = 1.0
var window_mode: String = "Windowed"
var resolution: Vector2i = Vector2i(1920, 1080)

# Control action registry (typed array)
var control_actions: Array[ControlActionDef] = []

var _config: ConfigFile


func _ready() -> void:
	_load_global_settings()
	_register_control_actions()
	_ensure_audio_buses()
	_apply_detail_settings()


# ============================================================================
# Global Settings I/O
# ============================================================================


func _load_global_settings() -> void:
	_config = ConfigFile.new()
	var err := _config.load(GLOBAL_CONFIG_FILE)
	if err != OK:
		print("GlobalSettings: Creating new global settings file")
		_save_global_settings()
	else:
		gamma = _config.get_value("video", "gamma", 1.0)
		window_mode = _config.get_value("video", "window_mode", "Windowed")
		var res_x: int = _config.get_value("video", "resolution_x", 1920)
		var res_y: int = _config.get_value("video", "resolution_y", 1080)
		resolution = Vector2i(res_x, res_y)

	# Load detail settings resource
	if ResourceLoader.exists(DETAIL_SETTINGS_FILE):
		var loaded := ResourceLoader.load(DETAIL_SETTINGS_FILE)
		if loaded is DetailSettings:
			detail = loaded
	if detail == null:
		detail = DetailSettings.new()


func _save_global_settings() -> void:
	_config.set_value("video", "gamma", gamma)
	_config.set_value("video", "window_mode", window_mode)
	_config.set_value("video", "resolution_x", resolution.x)
	_config.set_value("video", "resolution_y", resolution.y)
	_config.save(GLOBAL_CONFIG_FILE)

	# Save detail settings
	ResourceSaver.save(detail, DETAIL_SETTINGS_FILE)


func set_gamma(value: float) -> void:
	gamma = clampf(value, 0.5, 3.0)
	# Apply gamma via Environment or ColorCorrection shader
	_save_global_settings()
	settings_changed.emit()


func set_window_mode(mode: String) -> void:
	window_mode = mode
	match mode:
		"Fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"Windowed":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		"Borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	_save_global_settings()
	settings_changed.emit()


func set_resolution(res: Vector2i) -> void:
	resolution = res
	DisplayServer.window_set_size(res)
	_save_global_settings()
	settings_changed.emit()


func set_detail_preset(preset_level: int) -> void:
	detail.apply_preset(preset_level)
	_apply_detail_settings()
	_save_global_settings()
	detail_settings_changed.emit()


func _apply_detail_settings() -> void:
	"""Apply detail settings to RenderingServer and ProjectSettings."""
	if not detail:
		return

	# SSR quality (affects reflections)
	RenderingServer.environment_set_ssr_roughness_quality(
		RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_LOW + detail.lighting_quality
	)

	# SSAO quality
	match detail.lighting_quality:
		0, 1:
			RenderingServer.environment_set_ssao_quality(
				RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, true, 0.5, 2, 50.0, 300.0
			)
		2:
			RenderingServer.environment_set_ssao_quality(
				RenderingServer.ENV_SSAO_QUALITY_LOW, true, 0.5, 2, 50.0, 300.0
			)
		3:
			RenderingServer.environment_set_ssao_quality(
				RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0
			)
		4:
			RenderingServer.environment_set_ssao_quality(
				RenderingServer.ENV_SSAO_QUALITY_HIGH, true, 0.5, 2, 50.0, 300.0
			)

	# Note: LOD thresholds are configured per-mesh or via ProjectSettings
	# rendering/mesh_lod/lod_change/threshold_pixels


# ============================================================================
# Audio Bus Management
# ============================================================================


func _ensure_audio_buses() -> void:
	"""Ensure required audio buses exist in AudioServer."""
	var required := ["Master", "Music", "SFX", "Voice", "Interface"]
	for bus_name in required:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, bus_name)
			if bus_name != "Master":
				AudioServer.set_bus_send(idx, "Master")


## Apply volume settings from a GameSettings resource to AudioServer.
func apply_audio_settings(settings: GameSettings) -> void:
	if settings == null:
		return
	_set_bus_volume("Master", settings.master_volume)
	_set_bus_volume("Music", settings.music_volume)
	_set_bus_volume("SFX", settings.sfx_volume)
	_set_bus_volume("Voice", settings.voice_volume)
	_set_bus_volume("Interface", settings.interface_volume)


func _set_bus_volume(bus_name: String, linear_value: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		var db_value := linear_to_db(clampf(linear_value, 0.0, 1.0))
		AudioServer.set_bus_volume_db(bus_idx, db_value)


# ============================================================================
# Control Action Registry
# ============================================================================


func _register_control_actions() -> void:
	"""Register all control actions from legacy controlsconfig.h."""
	control_actions.clear()

	# Tab 0: Targeting
	_add_action("target_next", 0, "Target Next Ship", KEY_T)
	_add_action("target_prev", 0, "Target Previous Ship", KEY_SHIFT | KEY_T)
	_add_action("target_next_hostile", 0, "Target Next Hostile", KEY_H)
	_add_action("target_prev_hostile", 0, "Target Previous Hostile", KEY_SHIFT | KEY_H)
	_add_action("toggle_auto_targeting", 0, "Toggle Auto-Targeting", KEY_INSERT)
	_add_action("target_next_friendly", 0, "Target Next Friendly", KEY_F)
	_add_action("target_prev_friendly", 0, "Target Previous Friendly", KEY_SHIFT | KEY_F)
	_add_action("target_in_reticle", 0, "Target Ship in Reticle", KEY_Y)
	_add_action("target_attacker", 0, "Target Closest Attacker", KEY_R)
	_add_action("target_last_sender", 0, "Target Last Transmission Sender", KEY_J)
	_add_action("stop_targeting", 0, "Stop Targeting Ship", KEY_U)

	# Tab 1: Weapons
	_add_action("fire_primary", 1, "Fire Primary Weapon", KEY_CTRL, 0)
	_add_action("fire_secondary", 1, "Fire Secondary Weapon", KEY_SPACE, 1)
	_add_action("cycle_primary_next", 1, "Cycle Primary Forward", KEY_PERIOD)
	_add_action("cycle_primary_prev", 1, "Cycle Primary Backward", KEY_COMMA)
	_add_action("cycle_secondary", 1, "Cycle Secondary", KEY_SLASH)
	_add_action("cycle_missile_count", 1, "Cycle Missile Count", KEY_SHIFT | KEY_SLASH)
	_add_action("launch_countermeasure", 1, "Launch Countermeasure", KEY_X)

	# Tab 2: Flight Controls
	_add_action("pitch_forward", 2, "Pitch Forward", KEY_A, -1, 1)
	_add_action("pitch_back", 2, "Pitch Back", KEY_Z, -1, 1)
	_add_action("yaw_left", 2, "Yaw Left", KEY_KP_4, -1, 1)
	_add_action("yaw_right", 2, "Yaw Right", KEY_KP_6, -1, 1)
	_add_action("bank_left", 2, "Bank Left", KEY_KP_7, -1, 1)
	_add_action("bank_right", 2, "Bank Right", KEY_KP_9, -1, 1)
	_add_action("forward_thrust", 2, "Forward Thrust", KEY_BACKSLASH, -1, 1)
	_add_action("reverse_thrust", 2, "Reverse Thrust", KEY_MINUS, -1, 1)

	# Tab 3: Throttle
	_add_action("throttle_zero", 3, "Set Throttle to Zero", KEY_BACKSPACE)
	_add_action("throttle_max", 3, "Set Throttle to Max", KEY_EQUAL)
	_add_action("throttle_33", 3, "Set Throttle to 1/3", KEY_BRACKETLEFT)
	_add_action("throttle_66", 3, "Set Throttle to 2/3", KEY_BRACKETRIGHT)
	_add_action("throttle_up", 3, "Increase Throttle 5%", KEY_KP_ADD)
	_add_action("throttle_down", 3, "Decrease Throttle 5%", KEY_KP_SUBTRACT)
	_add_action("match_target_speed", 3, "Match Target Speed", KEY_M)
	_add_action("toggle_auto_match", 3, "Toggle Auto Speed Match", KEY_SHIFT | KEY_M)
	_add_action("afterburner", 3, "Afterburner", KEY_TAB)

	# Tab 4: Squadmate Commands
	_add_action("squadmsg_menu", 4, "Communications Menu", KEY_C)
	_add_action("msg_attack", 4, "Squadmate: Attack Target", KEY_SHIFT | KEY_A)
	_add_action("msg_disarm", 4, "Squadmate: Disarm Target", KEY_SHIFT | KEY_D)
	_add_action("msg_disable", 4, "Squadmate: Disable Target", KEY_SHIFT | KEY_I)
	_add_action("msg_capture", 4, "Squadmate: Capture Target", KEY_SHIFT | KEY_C)
	_add_action("msg_engage", 4, "Squadmate: Engage Enemy", KEY_SHIFT | KEY_E)
	_add_action("msg_form", 4, "Squadmate: Form on My Wing", KEY_SHIFT | KEY_W)
	_add_action("msg_ignore", 4, "Squadmate: Ignore Target", KEY_SHIFT | KEY_G)
	_add_action("msg_protect", 4, "Squadmate: Protect Target", KEY_SHIFT | KEY_P)
	_add_action("msg_cover", 4, "Squadmate: Cover Me", KEY_SHIFT | KEY_V)
	_add_action("msg_warp", 4, "Squadmate: Warp Out", KEY_SHIFT | KEY_J)
	_add_action("msg_rearm", 4, "Squadmate: Rearm Me", KEY_SHIFT | KEY_R)

	# Tab 5: Views
	_add_action("view_chase", 5, "Chase View", KEY_PAGEUP)
	_add_action("view_external", 5, "External View", KEY_PAGEDOWN)
	_add_action("view_external_toggle_lock", 5, "Toggle Camera Lock", KEY_L)
	_add_action("view_slew", 5, "Free Look", KEY_HOME)
	_add_action("view_other_ship", 5, "View Other Ship", KEY_O)
	_add_action("view_dist_increase", 5, "Increase View Distance", KEY_KP_MULTIPLY)
	_add_action("view_dist_decrease", 5, "Decrease View Distance", KEY_KP_DIVIDE)
	_add_action("view_center", 5, "Center View", KEY_END)
	_add_action("padlock_up", 5, "Padlock Up", KEY_UP)
	_add_action("padlock_down", 5, "Padlock Down", KEY_DOWN)
	_add_action("padlock_left", 5, "Padlock Left", KEY_LEFT)
	_add_action("padlock_right", 5, "Padlock Right", KEY_RIGHT)

	# Tab 6: Misc / ETS / Shields
	_add_action("radar_range_cycle", 6, "Cycle Radar Range", KEY_V)
	_add_action("show_goals", 6, "Show Mission Goals", KEY_G)
	_add_action("end_mission", 6, "End Mission", KEY_SHIFT | KEY_ESCAPE)
	_add_action("ets_increase_weapon", 6, "Increase Weapon ETS", KEY_SCROLLLOCK)
	_add_action("ets_decrease_weapon", 6, "Decrease Weapon ETS", KEY_SHIFT | KEY_SCROLLLOCK)
	_add_action("ets_increase_shield", 6, "Increase Shield ETS", KEY_DELETE)
	_add_action("ets_decrease_shield", 6, "Decrease Shield ETS", KEY_SHIFT | KEY_DELETE)
	_add_action("ets_increase_engine", 6, "Increase Engine ETS", KEY_INSERT)
	_add_action("ets_decrease_engine", 6, "Decrease Engine ETS", KEY_SHIFT | KEY_INSERT)
	_add_action("ets_equalize", 6, "Equalize ETS", KEY_QUOTELEFT)
	_add_action("shield_equalize", 6, "Equalize Shields", KEY_Q)
	_add_action("toggle_hud", 6, "Toggle HUD", KEY_H | KEY_SHIFT)
	_add_action("toggle_gliding", 6, "Toggle Gliding", KEY_G)
	_add_action("autopilot_toggle", 6, "Toggle Autopilot", KEY_ALT | KEY_A)
	_add_action("nav_cycle", 6, "Cycle Nav Points", KEY_ALT | KEY_N)

	# Tab 0 (Targeting) - Additional subsystem targeting
	_add_action("target_subobj_reticle", 0, "Target Subsystem in Reticle", KEY_SHIFT | KEY_Y)
	_add_action("target_next_subobj", 0, "Target Next Subsystem", KEY_S)
	_add_action("target_prev_subobj", 0, "Target Previous Subsystem", KEY_SHIFT | KEY_S)
	_add_action("stop_targeting_subsystem", 0, "Stop Targeting Subsystem", KEY_SHIFT | KEY_U)
	_add_action("target_targets_target", 0, "Target Target's Target", KEY_SHIFT | KEY_T)
	_add_action(
		"target_closest_attacker_self", 0, "Target Closest Attacker (Self)", KEY_SHIFT | KEY_R
	)

	# Escort Management
	_add_action("add_remove_escort", 0, "Add/Remove Escort", KEY_SHIFT | KEY_E)
	_add_action("escort_clear", 0, "Clear Escort List", KEY_ALT | KEY_E)
	_add_action("target_next_escort", 0, "Target Next Escort Ship", KEY_E)

	# Special Targeting
	_add_action("target_closest_repair", 0, "Target Closest Repair Ship", 0)
	_add_action("target_next_uninspected", 0, "Target Next Uninspected Cargo", KEY_N)
	_add_action(
		"target_prev_uninspected", 0, "Target Previous Uninspected Cargo", KEY_SHIFT | KEY_N
	)
	_add_action("target_newest_ship", 0, "Target Newest Ship", KEY_SHIFT | KEY_Y)
	_add_action("target_next_turret", 0, "Target Next Live Turret", KEY_K)
	_add_action("target_prev_turret", 0, "Target Previous Live Turret", KEY_SHIFT | KEY_K)
	_add_action("target_next_bomb", 0, "Target Next Bomb/Missile", KEY_B)
	_add_action("target_prev_bomb", 0, "Target Previous Bomb/Missile", KEY_SHIFT | KEY_B)

	# Shield Transfer (Tab 6)
	_add_action("shield_xfer_top", 6, "Transfer Shields to Front", KEY_UP | KEY_ALT)
	_add_action("shield_xfer_bottom", 6, "Transfer Shields to Rear", KEY_DOWN | KEY_ALT)
	_add_action("shield_xfer_left", 6, "Transfer Shields to Left", KEY_LEFT | KEY_ALT)
	_add_action("shield_xfer_right", 6, "Transfer Shields to Right", KEY_RIGHT | KEY_ALT)
	_add_action("xfer_energy_shield", 6, "Transfer Energy to Shields", KEY_BRACKETLEFT | KEY_SHIFT)
	_add_action("xfer_energy_laser", 6, "Transfer Energy to Weapons", KEY_BRACKETRIGHT | KEY_SHIFT)

	# Slide Thrust (Tab 2: Flight)
	_add_action("slide_left", 2, "Slide Left", KEY_A | KEY_SHIFT, -1, 1)
	_add_action("slide_right", 2, "Slide Right", KEY_D | KEY_SHIFT, -1, 1)
	_add_action("slide_up", 2, "Slide Up", KEY_W | KEY_SHIFT, -1, 1)
	_add_action("slide_down", 2, "Slide Down", KEY_S | KEY_SHIFT, -1, 1)
	_add_action("glide_when_pressed", 2, "Glide (Hold)", KEY_CAPSLOCK, -1, 1)
	_add_action("bank_when_pressed", 2, "Bank When Pressed", 0, -1, 1)

	# Multiplayer Messaging (Tab 4)
	_add_action("msg_attack_subsystem", 4, "Squadmate: Attack Subsystem", KEY_ALT | KEY_S)
	_add_action("multi_msg_all", 4, "MP: Message All", KEY_1)
	_add_action("multi_msg_friendly", 4, "MP: Message Friendlies", KEY_2)
	_add_action("multi_msg_hostile", 4, "MP: Message Hostiles", KEY_3)
	_add_action("multi_msg_target", 4, "MP: Message Target", KEY_4)
	_add_action("multi_observer_zoom", 4, "MP: Observer Zoom To", 0)
	_add_action("multi_netinfo_toggle", 4, "MP: Toggle Net Info", 0)
	_add_action("multi_self_destruct", 4, "MP: Self Destruct", 0)

	# Time Controls (Tab 6)
	_add_action("time_speed_up", 6, "Speed Up Time", KEY_SHIFT | KEY_PERIOD)
	_add_action("time_slow_down", 6, "Slow Down Time", KEY_SHIFT | KEY_COMMA)
	_add_action("toggle_hud_contrast", 6, "Toggle HUD Contrast", KEY_ALT | KEY_H)

	# Navigation View (Tab 5)
	_add_action("show_navmap", 5, "Show Navigation Map", KEY_N | KEY_ALT)

	# Ensure all actions are registered in InputMap
	for action_def in control_actions:
		if not InputMap.has_action(action_def.id):
			InputMap.add_action(action_def.id)


func _add_action(
	id: String,
	tab: int,
	text: String,
	key_default: int = 0,
	joy_default: int = -1,
	action_type: int = 0
) -> void:
	var def := ControlActionDef.new(id, tab, text, key_default, joy_default, action_type)
	control_actions.append(def)


## Get control action definition by ID.
func get_action_def(action_id: String) -> ControlActionDef:
	for action_def in control_actions:
		if action_def.id == action_id:
			return action_def
	return null


## Get all actions for a specific tab.
func get_actions_for_tab(tab: int) -> Array[ControlActionDef]:
	var result: Array[ControlActionDef] = []
	for action_def in control_actions:
		if action_def.tab == tab:
			result.append(action_def)
	return result


## Apply input bindings from a GameSettings resource to InputMap.
func apply_input_bindings(settings: GameSettings) -> void:
	if settings == null:
		return

	# First, apply defaults for all actions
	for action_def in control_actions:
		if InputMap.has_action(action_def.id):
			InputMap.action_erase_events(action_def.id)
		else:
			InputMap.add_action(action_def.id)

		var default_binding := action_def.create_default_binding()
		var key_event := default_binding.get_key_event()
		if key_event:
			InputMap.action_add_event(action_def.id, key_event)
		var joy_event := default_binding.get_joy_event()
		if joy_event:
			InputMap.action_add_event(action_def.id, joy_event)

	# Then apply custom bindings from settings
	for binding in settings.input_bindings:
		if binding.action_name.is_empty():
			continue
		if not InputMap.has_action(binding.action_name):
			continue

		InputMap.action_erase_events(binding.action_name)
		var key_event := binding.get_key_event()
		if key_event:
			InputMap.action_add_event(binding.action_name, key_event)
		var joy_event := binding.get_joy_event()
		if joy_event:
			InputMap.action_add_event(binding.action_name, joy_event)
