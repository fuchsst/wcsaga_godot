# AudioManager - Game Audio System Manager
# Autoload singleton for sound playback, audio bus management, and music
# Based on legacy gamesnd.cpp functionality

extends Node

## Emitted when audio data is loaded
signal audio_data_loaded

# ==============================================================================
# REGISTRY (typed arrays as per implementation plan)
# ==============================================================================

## All registered gameplay sounds
@export var gameplay_sounds: Array[AudioConfigResource] = []

## All registered interface sounds
@export var interface_sounds: Array[AudioConfigResource] = []

# ==============================================================================
# AUDIO BUS NAMES
# ==============================================================================

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_VOICE: StringName = &"Voice"
const BUS_UI: StringName = &"UI"

# ==============================================================================
# PLAYER POOLS
# ==============================================================================

## Pool of 2D audio players for interface sounds
var _2d_player_pool: Array[AudioStreamPlayer] = []
var _2d_pool_size: int = 8

## Pool of 3D audio players for gameplay sounds
var _3d_player_pool: Array[AudioStreamPlayer3D] = []
var _3d_pool_size: int = 32

# ==============================================================================
# INITIALIZATION
# ==============================================================================


func _ready() -> void:
	print("AudioManager: Initializing...")
	_ensure_audio_buses()
	_create_player_pools()
	_connect_settings()


## Ensure required audio buses exist
func _ensure_audio_buses() -> void:
	# Check if buses exist, create if not
	# Note: In production, buses should be defined in default_bus_layout.tres
	var buses := [BUS_MUSIC, BUS_SFX, BUS_VOICE, BUS_UI]
	for bus_name in buses:
		if AudioServer.get_bus_index(bus_name) == -1:
			push_warning(
				(
					"AudioManager: Audio bus '%s' not found. Define in default_bus_layout.tres"
					% bus_name
				)
			)


## Create audio player pools
func _create_player_pools() -> void:
	# 2D players for interface sounds
	for i in range(_2d_pool_size):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_UI
		add_child(player)
		_2d_player_pool.append(player)

	# 3D players for gameplay sounds
	for i in range(_3d_pool_size):
		var player := AudioStreamPlayer3D.new()
		player.bus = BUS_SFX
		add_child(player)
		_3d_player_pool.append(player)


## Connect to GlobalSettings for volume changes
func _connect_settings() -> void:
	# Connect volume settings if GlobalSettings is available
	if GlobalSettings:
		_apply_volume_settings()
		GlobalSettings.settings_changed.connect(_apply_volume_settings)


## Apply volume settings from GlobalSettings
func _apply_volume_settings() -> void:
	if not GlobalSettings:
		return

	# Get volume values from settings (assuming they exist)
	if GlobalSettings.has_method("get_master_volume"):
		set_bus_volume(BUS_MASTER, GlobalSettings.get_master_volume())
	if GlobalSettings.has_method("get_music_volume"):
		set_bus_volume(BUS_MUSIC, GlobalSettings.get_music_volume())
	if GlobalSettings.has_method("get_sfx_volume"):
		set_bus_volume(BUS_SFX, GlobalSettings.get_sfx_volume())
	if GlobalSettings.has_method("get_voice_volume"):
		set_bus_volume(BUS_VOICE, GlobalSettings.get_voice_volume())


# ==============================================================================
# LOADING API
# ==============================================================================


## Load sounds from a manifest resource
func load_from_manifest(manifest: SoundManifest) -> void:
	if not manifest:
		push_error("AudioManager: Cannot load null manifest")
		return

	# Clear existing sounds
	gameplay_sounds.clear()
	interface_sounds.clear()

	# Sort sounds by category
	for config in manifest.audio_configs:
		if config:
			match config.category:
				AudioConfigResource.SoundCategory.INTERFACE:
					interface_sounds.append(config)
				_:
					gameplay_sounds.append(config)

	print(
		(
			"AudioManager: Loaded %d gameplay sounds, %d interface sounds"
			% [gameplay_sounds.size(), interface_sounds.size()]
		)
	)
	audio_data_loaded.emit()


## Load sounds from a resource path
func load_from_path(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("AudioManager: Manifest not found at: %s" % path)
		return

	var manifest: SoundManifest = ResourceLoader.load(path) as SoundManifest
	load_from_manifest(manifest)


## Preload common sounds (those with preload_sound flag)
func preload_common_sounds() -> void:
	var preloaded_count := 0

	for config in gameplay_sounds:
		if config.preload_sound and config.audio_stream:
			# Force stream to load
			var _stream = config.audio_stream
			preloaded_count += 1

	for config in interface_sounds:
		if config.preload_sound and config.audio_stream:
			var _stream = config.audio_stream
			preloaded_count += 1

	print("AudioManager: Preloaded %d sounds" % preloaded_count)


# ==============================================================================
# LOOKUP API
# ==============================================================================


## Find a sound by symbolic name
func find_sound(symbolic_name: StringName) -> AudioConfigResource:
	# Search gameplay sounds first
	for config in gameplay_sounds:
		if config.symbolic_name == symbolic_name:
			return config

	# Then interface sounds
	for config in interface_sounds:
		if config.symbolic_name == symbolic_name:
			return config

	return null


## Find a sound by signature (legacy index)
func find_sound_by_signature(signature: int) -> AudioConfigResource:
	for config in gameplay_sounds:
		if config.signature == signature:
			return config

	for config in interface_sounds:
		if config.signature == signature:
			return config

	return null


# ==============================================================================
# PLAYBACK API
# ==============================================================================


## Play a 3D sound at a position
func play_sound(
	config: AudioConfigResource, position: Vector3 = Vector3.ZERO
) -> AudioStreamPlayer3D:
	if not config or not config.audio_stream:
		return null

	# Get available 3D player
	var player := _get_available_3d_player()
	if not player:
		push_warning("AudioManager: No available 3D audio players")
		return null

	# Configure and play
	player.stream = config.audio_stream
	player.volume_db = linear_to_db(config.default_volume)
	player.global_position = position

	# Set 3D properties
	if config.is_3d > 0:
		player.max_distance = config.max_distance if config.max_distance > 0 else 100.0
		player.unit_size = config.min_distance if config.min_distance > 0 else 1.0

	# Set bus based on category
	player.bus = _get_bus_for_category(config.category)

	player.play()
	return player


## Play a 2D interface sound
func play_interface(config: AudioConfigResource) -> AudioStreamPlayer:
	if not config or not config.audio_stream:
		return null

	# Get available 2D player
	var player := _get_available_2d_player()
	if not player:
		push_warning("AudioManager: No available 2D audio players")
		return null

	# Configure and play
	player.stream = config.audio_stream
	player.volume_db = linear_to_db(config.default_volume)
	player.bus = BUS_UI
	player.play()
	return player


## Play interface sound by symbolic name (convenience)
func play_interface_by_name(symbolic_name: StringName) -> AudioStreamPlayer:
	var config := find_sound(symbolic_name)
	if config:
		return play_interface(config)
	return null


## Play 3D sound by symbolic name (convenience)
func play_sound_by_name(
	symbolic_name: StringName, position: Vector3 = Vector3.ZERO
) -> AudioStreamPlayer3D:
	var config := find_sound(symbolic_name)
	if config:
		return play_sound(config, position)
	return null


# ==============================================================================
# VOLUME API
# ==============================================================================


## Set volume for an audio bus (linear 0.0-1.0)
func set_bus_volume(bus_name: StringName, linear: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(clamp(linear, 0.0, 1.0)))


## Get volume for an audio bus (linear 0.0-1.0)
func get_bus_volume(bus_name: StringName) -> float:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	return 1.0


## Mute/unmute a bus
func set_bus_mute(bus_name: StringName, muted: bool) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, muted)


# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================


## Get an available 2D player from the pool
func _get_available_2d_player() -> AudioStreamPlayer:
	for player in _2d_player_pool:
		if not player.playing:
			return player
	# Steal the first player if all are playing
	return _2d_player_pool[0] if not _2d_player_pool.is_empty() else null


## Get an available 3D player from the pool
func _get_available_3d_player() -> AudioStreamPlayer3D:
	for player in _3d_player_pool:
		if not player.playing:
			return player
	# Steal the first player if all are playing
	return _3d_player_pool[0] if not _3d_player_pool.is_empty() else null


## Get audio bus for a sound category
func _get_bus_for_category(category: AudioConfigResource.SoundCategory) -> StringName:
	match category:
		AudioConfigResource.SoundCategory.INTERFACE:
			return BUS_UI
		AudioConfigResource.SoundCategory.MUSIC:
			return BUS_MUSIC
		AudioConfigResource.SoundCategory.VOICE:
			return BUS_VOICE
		_:
			return BUS_SFX
