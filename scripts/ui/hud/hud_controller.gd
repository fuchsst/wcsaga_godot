# HUDController - Main HUD System Controller
# Manages all HUD gauges and displays for the player's ship
# Connects to player ship signals to update displays in real-time

class_name HUDController
extends CanvasLayer

# === SIGNALS ===
signal hud_toggled(visible: bool)
signal gauge_flashed(gauge_name: String)

# === CONSTANTS ===
const SILHOUETTE_PATH := "res://assets/cockpits/hud_gauges/"
const MAX_MESSAGES: int = 5
const MESSAGE_DURATION: float = 5.0
const SHIELD_HIT_DURATION: float = 1.4 # 1400ms from legacy hudshield.h
const SHIELD_FLASH_INTERVAL: float = 0.2 # 200ms between flashes

# === CONFIGURATION ===
@export_group("HUD Settings")
@export var hud_config: HudConfigResource = null
@export var hud_color: Color = Color(0.0, 1.0, 0.0, 0.8) # Default green
@export var hud_bright_color: Color = Color(0.2, 1.0, 0.2, 1.0)
@export var hud_dim_color: Color = Color(0.0, 0.7, 0.0, 0.5)
@export var warning_color: Color = Color(1.0, 0.0, 0.0, 1.0)

@export_group("Gauge Scenes")
## Path to main gauges scene from assets
@export var main_gauges_scene: PackedScene = null
## Path to hardpoints gauge scene
@export var hardpoints_scene: PackedScene = null
## Path to custom gauges scene
@export var custom_gauges_scene: PackedScene = null

@export_group("References")
@export var player_ship: NodePath = NodePath("")

# === GAUGE SCENE CONTAINERS ===
var main_gauges_instance: Node2D = null
var hardpoints_instance: Node2D = null
var custom_gauges_instance: Node2D = null

## Ship silhouette textures by ship class
var ship_silhouettes: Dictionary = {
	"arrow": "hp_sil_arrow.png",
	"excalibur": "hp_sil_excalibur.png",
	"hellcat": "hp_sil_hellcat.png",
	"longbow": "hp_sil_longbow.png",
	"sabre": "hp_sil_sabre.png",
	"thunderbolt": "hp_sil_thunderbolt.png",
}

# === NODE REFERENCES (set in _ready or via scene) ===
# Shield/Hull
var shield_container: Control
var hull_bar: ProgressBar
var hull_label: Label

# Weapons
var primary_weapon_label: Label
var secondary_weapon_label: Label
var weapon_energy_bar: ProgressBar
var afterburner_bar: ProgressBar

# Target
var target_container: Control
var target_name_label: Label
var target_hull_bar: ProgressBar
var target_shield_indicator: Control
var target_distance_label: Label

# Radar
var radar_container: Control

# Messages
var message_container: VBoxContainer
var directive_label: Label

# ETS (Energy Transfer System)
var ets_container: Control
var ets_engines_bar: ProgressBar
var ets_shields_bar: ProgressBar
var ets_weapons_bar: ProgressBar

# Speed/Throttle
var speed_label: Label
var throttle_bar: ProgressBar

# Mission
var mission_time_label: Label

var _player: Node = null
var _target: Node = null
var _hud_visible: bool = true
var _flash_timers: Dictionary = {} # gauge_name -> timer
var _messages: Array[Dictionary] = []
var _shield_hit_timers: Array[float] = [0.0, 0.0, 0.0, 0.0] # Per-quadrant flash timers
var _shield_flash_state: Array[bool] = [false, false, false, false] # Flash on/off state
var _hull_hit_timer: float = 0.0


func _ready() -> void:
	layer = 10 # Above 3D scene

	_setup_hud_nodes()
	_instantiate_gauge_scenes()
	_connect_player()

	# Apply config overrides if present
	if hud_config:
		_apply_hud_config()


func _instantiate_gauge_scenes() -> void:
	"""Instantiate gauge scenes from assets"""
	var gauge_container = find_child("HUDRoot", true, false)
	if not gauge_container:
		gauge_container = self

	# Main gauges (shields, weapons energy, afterburner)
	if main_gauges_scene:
		main_gauges_instance = main_gauges_scene.instantiate()
		gauge_container.add_child(main_gauges_instance)

	# Hardpoints display
	if hardpoints_scene:
		hardpoints_instance = hardpoints_scene.instantiate()
		gauge_container.add_child(hardpoints_instance)

	# Custom gauges if any
	if custom_gauges_scene:
		custom_gauges_instance = custom_gauges_scene.instantiate()
		gauge_container.add_child(custom_gauges_instance)


func load_ship_silhouette(ship_class: String) -> void:
	"""Load ship-specific silhouette for hardpoints display"""
	if not hardpoints_instance:
		return

	var silhouette_node = hardpoints_instance.find_child("HP_Silhouette", true, false)
	if not silhouette_node:
		return

	# Find matching silhouette
	var ship_key = ship_class.to_lower().replace(" ", "_")
	var silhouette_file = ship_silhouettes.get(ship_key, "hp_sil_generic.png")
	var path = SILHOUETTE_PATH + silhouette_file

	if ResourceLoader.exists(path):
		var texture = load(path)
		if silhouette_node is Sprite2D:
			silhouette_node.texture = texture
		elif "texture" in silhouette_node:
			silhouette_node.texture = texture


func _process(delta: float) -> void:
	if not _hud_visible or not _player:
		return

	_update_player_gauges(delta)
	_update_target_gauges(delta)
	_update_messages(delta)
	_update_flash_timers(delta)
	_update_shield_hit_timers(delta)


# === SETUP ===


func _setup_hud_nodes() -> void:
	"""Find or create HUD gauge nodes"""
	# These will be populated from child nodes or created dynamically
	# For now, we find them by node name convention
	shield_container = _find_or_null("ShieldContainer")
	hull_bar = _find_or_null("HullBar")
	hull_label = _find_or_null("HullLabel")

	primary_weapon_label = _find_or_null("PrimaryWeaponLabel")
	secondary_weapon_label = _find_or_null("SecondaryWeaponLabel")
	weapon_energy_bar = _find_or_null("WeaponEnergyBar")
	afterburner_bar = _find_or_null("AfterburnerBar")

	target_container = _find_or_null("TargetContainer")
	target_name_label = _find_or_null("TargetNameLabel")
	target_hull_bar = _find_or_null("TargetHullBar")
	target_shield_indicator = _find_or_null("TargetShieldIndicator")
	target_distance_label = _find_or_null("TargetDistanceLabel")

	radar_container = _find_or_null("RadarContainer")
	message_container = _find_or_null("MessageContainer")
	directive_label = _find_or_null("DirectiveLabel")

	ets_container = _find_or_null("ETSContainer")
	ets_engines_bar = _find_or_null("ETSEnginesBar")
	ets_shields_bar = _find_or_null("ETSShieldsBar")
	ets_weapons_bar = _find_or_null("ETSWeaponsBar")

	speed_label = _find_or_null("SpeedLabel")
	throttle_bar = _find_or_null("ThrottleBar")
	mission_time_label = _find_or_null("MissionTimeLabel")


func _find_or_null(node_name: String) -> Node:
	"""Find a child node by name, return null if not found"""
	return find_child(node_name, true, false)


func _connect_player() -> void:
	"""Connect to player ship signals"""
	if player_ship.is_empty():
		# Try to find player in the scene
		await get_tree().process_frame
		var ships = get_tree().get_nodes_in_group("player_ship")
		if ships.size() > 0:
			_player = ships[0]
	else:
		_player = get_node_or_null(player_ship)

	if _player:
		_connect_ship_signals(_player)


func _connect_ship_signals(ship: Node) -> void:
	"""Connect to ship's signals for HUD updates"""
	if ship.has_signal("damage_received"):
		if not ship.damage_received.is_connected(_on_player_damage):
			ship.damage_received.connect(_on_player_damage)

	if ship.has_signal("weapon_fired"):
		if not ship.weapon_fired.is_connected(_on_weapon_fired):
			ship.weapon_fired.connect(_on_weapon_fired)

	if ship.has_signal("target_changed"):
		if not ship.target_changed.is_connected(_on_target_changed):
			ship.target_changed.connect(_on_target_changed)

	if ship.has_signal("afterburner_state_changed"):
		if not ship.afterburner_state_changed.is_connected(_on_afterburner_changed):
			ship.afterburner_state_changed.connect(_on_afterburner_changed)


func _apply_hud_config() -> void:
	"""Apply HUD configuration overrides"""
	if not hud_config:
		return

	for override in hud_config.gauges:
		if override.override_color:
			# Apply color override to specific gauge
			_set_gauge_color(override.gauge_name, override.color)


func _set_gauge_color(gauge_name: String, color: Color) -> void:
	"""Set color for a specific gauge"""
	var gauge = _find_or_null(gauge_name)
	if gauge and gauge is Control:
		gauge.modulate = color


# === UPDATE FUNCTIONS ===


func _update_player_gauges(_delta: float) -> void:
	"""Update gauges based on player ship state"""
	if not _player:
		return

	# Hull
	if hull_bar:
		var hull_percent = _get_player_property("get_hull_percent", 1.0)
		hull_bar.value = hull_percent * 100.0

		# Warning color when low
		if hull_percent < 0.25:
			hull_bar.modulate = warning_color
		else:
			hull_bar.modulate = hud_color

	if hull_label:
		var hull = _get_player_property("current_hull", 0.0)
		hull_label.text = "HULL: %d" % int(hull)

	# Shields - update quadrant display
	_update_shield_display()

	# Weapon Energy
	if weapon_energy_bar:
		var energy = _get_player_property("weapon_energy", 0.0)
		var max_energy = _get_player_stat("max_weapon_energy", 100.0)
		weapon_energy_bar.value = (energy / max_energy) * 100.0 if max_energy > 0 else 0

	# Afterburner
	if afterburner_bar:
		var fuel = _get_player_property("afterburner_fuel", 0.0)
		var max_fuel = _get_player_stat("max_afterburner_fuel", 100.0)
		afterburner_bar.value = (fuel / max_fuel) * 100.0 if max_fuel > 0 else 0

	# Speed
	if speed_label and _player.has_method("get_current_speed"):
		var speed = _player.get_current_speed()
		speed_label.text = "SPEED: %d" % int(speed)

	# Throttle
	if throttle_bar:
		var throttle = _get_player_property("desired_velocity_body", Vector3.ZERO)
		var max_speed = _get_player_stat("max_velocity", Vector3(100, 100, 100))
		if max_speed is Vector3 and max_speed.z > 0:
			throttle_bar.value = (throttle.z / max_speed.z) * 100.0 if throttle is Vector3 else 0

	# Weapon display
	_update_weapon_display()

	# Mission time
	if mission_time_label:
		var mm = _get_mission_manager()
		if mm and "mission_time" in mm:
			var time = mm.mission_time
			var minutes = int(time) / 60
			var seconds = int(time) % 60
			mission_time_label.text = "%02d:%02d" % [minutes, seconds]


func _update_shield_display() -> void:
	"""Update shield quadrant display with flash effects"""
	if not shield_container or not _player:
		return

	# Get shield quadrants from player
	var shields = _get_player_property("shield_quadrants", [])
	if shields.is_empty():
		return

	var max_shield = _get_player_stat("shield_strength", 100.0) / shields.size()

	# Update each quadrant indicator (front, left, right, rear)
	var quadrant_names = ["ShieldFront", "ShieldLeft", "ShieldRight", "ShieldRear"]
	for i in range(min(shields.size(), quadrant_names.size())):
		var indicator = shield_container.find_child(quadrant_names[i], true, false)
		if indicator and indicator is ProgressBar:
			indicator.value = (shields[i] / max_shield) * 100.0 if max_shield > 0 else 0

			# Apply flash effect if shield was recently hit
			if _shield_hit_timers[i] > 0:
				if _shield_flash_state[i]:
					indicator.modulate = hud_bright_color
				else:
					indicator.modulate = hud_dim_color
			# Color based on shield level
			elif shields[i] < max_shield * 0.25:
				indicator.modulate = warning_color
			elif shields[i] < max_shield * 0.5:
				indicator.modulate = Color(1.0, 0.6, 0.0, 1.0) # Orange
			else:
				indicator.modulate = hud_color

	# Update hull hit flash
	if _hull_hit_timer > 0 and hull_bar:
		if fmod(_hull_hit_timer, SHIELD_FLASH_INTERVAL * 2) < SHIELD_FLASH_INTERVAL:
			hull_bar.modulate = hud_bright_color
		else:
			hull_bar.modulate = warning_color


func _update_shield_hit_timers(delta: float) -> void:
	"""Update shield hit flash timers"""
	for i in range(_shield_hit_timers.size()):
		if _shield_hit_timers[i] > 0:
			_shield_hit_timers[i] -= delta
			# Toggle flash state
			if fmod(_shield_hit_timers[i], SHIELD_FLASH_INTERVAL) < delta:
				_shield_flash_state[i] = not _shield_flash_state[i]
		else:
			_shield_flash_state[i] = false

	# Update hull hit timer
	if _hull_hit_timer > 0:
		_hull_hit_timer -= delta


func shield_quadrant_hit(quadrant: int) -> void:
	"""Called when a shield quadrant is hit - triggers flash effect"""
	if quadrant >= 0 and quadrant < _shield_hit_timers.size():
		_shield_hit_timers[quadrant] = SHIELD_HIT_DURATION
		_shield_flash_state[quadrant] = true


func hull_hit() -> void:
	"""Called when hull takes damage - triggers flash effect"""
	_hull_hit_timer = SHIELD_HIT_DURATION


func _update_weapon_display() -> void:
	"""Update weapon status display"""
	if not _player or not "weapon_system" in _player:
		return

	var ws = _player.weapon_system
	if not ws:
		return

	# Primary weapon
	if primary_weapon_label and ws.has_method("get_current_primary_name"):
		primary_weapon_label.text = ws.get_current_primary_name()
	elif primary_weapon_label and "primary_banks" in ws:
		var banks = ws.primary_banks
		if banks.size() > 0:
			var current = ws.current_primary_bank if "current_primary_bank" in ws else 0
			if current < banks.size() and banks[current]:
				primary_weapon_label.text = (
					banks[current].weapon_name if "weapon_name" in banks[current] else "PRIMARY"
				)

	# Secondary weapon
	if secondary_weapon_label and ws.has_method("get_current_secondary_name"):
		secondary_weapon_label.text = ws.get_current_secondary_name()
	elif secondary_weapon_label and "secondary_banks" in ws:
		var banks = ws.secondary_banks
		if banks.size() > 0:
			var current = ws.current_secondary_bank if "current_secondary_bank" in ws else 0
			if current < banks.size() and banks[current]:
				var ammo = banks[current].ammo if "ammo" in banks[current] else 0
				var name = (
					banks[current].weapon_name if "weapon_name" in banks[current] else "SECONDARY"
				)
				secondary_weapon_label.text = "%s: %d" % [name, ammo]


func _update_target_gauges(_delta: float) -> void:
	"""Update target information display"""
	if not target_container:
		return

	if not _target or not is_instance_valid(_target):
		target_container.visible = false
		return

	target_container.visible = true

	# Target name
	if target_name_label:
		var name = _get_target_property("name", "UNKNOWN")
		if _target.has_method("get_display_name"):
			name = _target.get_display_name()
		target_name_label.text = name

	# Target hull
	if target_hull_bar:
		var hull_percent = 1.0
		if _target.has_method("get_hull_percent"):
			hull_percent = _target.get_hull_percent()
		target_hull_bar.value = hull_percent * 100.0

		# IFF color
		target_hull_bar.modulate = _get_target_iff_color()

	# Target distance
	if target_distance_label and _player:
		var dist = _player.global_position.distance_to(_target.global_position)
		target_distance_label.text = _format_distance(dist)


func _update_messages(delta: float) -> void:
	"""Update message display - fade out old messages"""
	if not message_container:
		return

	var to_remove: Array[int] = []

	for i in range(_messages.size()):
		_messages[i]["time"] -= delta
		if _messages[i]["time"] <= 0:
			to_remove.append(i)

	# Remove expired messages (reverse order to preserve indices)
	for i in range(to_remove.size() - 1, -1, -1):
		_messages.remove_at(to_remove[i])

	# Update message display
	_refresh_message_display()


func _update_flash_timers(delta: float) -> void:
	"""Update gauge flash effects"""
	var to_remove: Array[String] = []

	for gauge_name in _flash_timers.keys():
		_flash_timers[gauge_name] -= delta
		if _flash_timers[gauge_name] <= 0:
			to_remove.append(gauge_name)
			_end_gauge_flash(gauge_name)

	for gauge_name in to_remove:
		_flash_timers.erase(gauge_name)


# === HELPER FUNCTIONS ===


func _get_player_property(property: String, default_value = null):
	"""Safely get a property from the player ship"""
	if not _player:
		return default_value

	if _player.has_method(property):
		return _player.call(property)
	if property in _player:
		return _player.get(property)

	return default_value


func _get_player_stat(stat: String, default_value = null):
	"""Get a stat from player's stats resource"""
	if not _player or not "stats" in _player or not _player.stats:
		return default_value

	if stat in _player.stats:
		return _player.stats.get(stat)

	return default_value


func _get_target_property(property: String, default_value = null):
	"""Safely get a property from the target"""
	if not _target or not is_instance_valid(_target):
		return default_value

	if _target.has_method(property):
		return _target.call(property)
	if property in _target:
		return _target.get(property)

	return default_value


func _get_target_iff_color() -> Color:
	"""Get IFF-based color for target display"""
	if not _target or not is_instance_valid(_target):
		return hud_color

	# Check IFF manager
	var iff_manager = _get_iff_manager()
	if iff_manager and _player:
		var player_team = _get_player_property("team", 0)
		var target_team = _get_target_property("team", 0)

		if iff_manager.has_method("get_radar_color"):
			return iff_manager.get_radar_color(player_team, target_team)
		if iff_manager.has_method("is_hostile"):
			if iff_manager.is_hostile(player_team, target_team):
				return Color.RED
			if player_team == target_team:
				return Color.GREEN
			return Color.YELLOW

	return hud_color


func _format_distance(dist: float) -> String:
	"""Format distance for display"""
	if dist >= 1000:
		return "%.1f km" % (dist / 1000.0)
	return "%d m" % int(dist)


func _get_mission_manager() -> Node:
	"""Get MissionManager autoload"""
	return (
		Engine.get_singleton("MissionManager") if Engine.has_singleton("MissionManager") else null
	)


func _get_iff_manager() -> Node:
	"""Get IFFManager autoload"""
	return Engine.get_singleton("IFFManager") if Engine.has_singleton("IFFManager") else null


# === PUBLIC API ===


func set_player(ship: Node) -> void:
	"""Set the player ship to display HUD for"""
	_player = ship
	if _player:
		_connect_ship_signals(_player)


func set_target(target: Node) -> void:
	"""Set the current target"""
	_target = target


func toggle_hud() -> void:
	"""Toggle HUD visibility"""
	_hud_visible = not _hud_visible
	visible = _hud_visible
	hud_toggled.emit(_hud_visible)


func show_hud() -> void:
	"""Show the HUD"""
	_hud_visible = true
	visible = true
	hud_toggled.emit(true)


func hide_hud() -> void:
	"""Hide the HUD"""
	_hud_visible = false
	visible = false
	hud_toggled.emit(false)


func add_message(text: String, priority: int = 0, duration: float = MESSAGE_DURATION) -> void:
	"""Add a message to the HUD message area"""
	_messages.append({"text": text, "priority": priority, "time": duration})

	# Sort by priority and limit count
	_messages.sort_custom(func(a, b): return a["priority"] > b["priority"])
	while _messages.size() > MAX_MESSAGES:
		_messages.pop_back()

	_refresh_message_display()


func flash_gauge(gauge_name: String, duration: float = 1.0) -> void:
	"""Make a gauge flash to draw attention"""
	_flash_timers[gauge_name] = duration

	var gauge = _find_or_null(gauge_name)
	if gauge and gauge is Control:
		# Start flash effect
		var tween = create_tween()
		tween.set_loops(int(duration / 0.2))
		tween.tween_property(gauge, "modulate", hud_bright_color, 0.1)
		tween.tween_property(gauge, "modulate", hud_color, 0.1)

	gauge_flashed.emit(gauge_name)


func set_directive(text: String) -> void:
	"""Set the current mission directive text"""
	if directive_label:
		directive_label.text = text


func _end_gauge_flash(gauge_name: String) -> void:
	"""End a gauge flash effect"""
	var gauge = _find_or_null(gauge_name)
	if gauge and gauge is Control:
		gauge.modulate = hud_color


func _refresh_message_display() -> void:
	"""Refresh the message container with current messages"""
	if not message_container:
		return

	# Clear existing labels
	for child in message_container.get_children():
		child.queue_free()

	# Add current messages
	for msg in _messages:
		var label = Label.new()
		label.text = msg["text"]
		label.add_theme_color_override("font_color", hud_color)

		# Fade out effect based on remaining time
		var alpha = clampf(msg["time"] / MESSAGE_DURATION, 0.0, 1.0)
		label.modulate.a = alpha

		message_container.add_child(label)


# === SIGNAL HANDLERS ===


func _on_player_damage(_ship: Node, _damage_result) -> void:
	"""Handle player taking damage"""
	flash_gauge("HullBar", 0.5)
	flash_gauge("ShieldContainer", 0.5)


func _on_weapon_fired(_ship: Node, _slot: int, _weapon) -> void:
	"""Handle player firing weapon"""
	# Brief flash on weapon display
	if _slot == 0:
		flash_gauge("PrimaryWeaponLabel", 0.2)
	else:
		flash_gauge("SecondaryWeaponLabel", 0.2)


func _on_target_changed(new_target: Node) -> void:
	"""Handle target change"""
	_target = new_target


func _on_afterburner_changed(active: bool) -> void:
	"""Handle afterburner state change"""
	if afterburner_bar:
		afterburner_bar.modulate = hud_bright_color if active else hud_color
