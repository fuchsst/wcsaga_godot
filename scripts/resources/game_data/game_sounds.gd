@tool
extends Resource
class_name GameSounds

# Constants
const MAX_SOUND_PLAYERS := 32  # Maximum concurrent sounds

# Sound arrays organized by category
@export var game_sounds: Array[SoundEntry] = []
@export var interface_sounds: Array[SoundEntry] = []
@export var event_music: Array[MusicEntry] = []

# Settings reference
var _settings: GameSettings

# Sound player pools
var _available_players: Array[AudioStreamPlayer3D] = []
var _active_players: Array[AudioStreamPlayer3D] = []

# Node to hold all sound players
var _sound_root: Node3D

# Signals for sound events
signal sound_started(sound_id: String)
signal sound_finished(sound_id: String)
signal volume_changed(category: SoundEntry.Category)

func _init():
	# Load settings
	_settings = GameSettings.load_or_create()
	
	# Create root node for sound players
	_sound_root = Node3D.new()
	_sound_root.name = "GameSounds"
	
	# Initialize sound player pool
	_initialize_sound_players()
	
	# Connect to settings changes
	if _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.disconnect(_on_settings_changed)
	_settings.changed.connect(_on_settings_changed)

func _initialize_sound_players() -> void:
	# Create pool of audio players
	for i in MAX_SOUND_PLAYERS:
		var player := AudioStreamPlayer3D.new()
		player.name = "SoundPlayer_%d" % i
		_sound_root.add_child(player)
		player.finished.connect(_on_sound_finished.bind(player))
		_available_players.append(player)

# Volume control using GameSettings
func _get_volume_for_category(category: SoundEntry.Category) -> float:
	match category:
		SoundEntry.Category.MASTER, SoundEntry.Category.AMBIENT:
			return _settings.master_volume
		SoundEntry.Category.MUSIC:
			return _settings.master_volume * _settings.music_volume
		SoundEntry.Category.VOICE:
			return _settings.master_volume * _settings.voice_volume
		_:  # All other categories use master volume
			return _settings.master_volume * _settings.effects_volume

func _update_all_volumes() -> void:
	for player in _active_players:
		if is_instance_valid(player):
			_update_player_volume(player)
	
	# Notify volume changes
	for category in SoundEntry.Category.values():
		volume_changed.emit(category)

func _update_category_volume(category: SoundEntry.Category) -> void:
	for player in _active_players:
		if is_instance_valid(player) and player.get_meta("category") == category:
			_update_player_volume(player)
	volume_changed.emit(category)

func _update_player_volume(player: AudioStreamPlayer3D) -> void:
	var category = player.get_meta("category") as SoundEntry.Category
	var base_volume = player.get_meta("base_volume") as float
	var volume = _get_volume_for_category(category) * base_volume
	player.volume_db = linear_to_db(volume)

# Settings change handler
func _on_settings_changed() -> void:
	_update_all_volumes()

# Sound playback
func play_sound(sound: SoundEntry, position: Vector3 = Vector3.ZERO) -> AudioStreamPlayer3D:
	if not sound or not sound.audio_stream or _available_players.is_empty():
		return null
	
	# Use preloaded player if available
	if sound.should_preload and sound.loaded_audio_player:
		var player = sound.loaded_audio_player
		player.position = position
		_update_player_volume(player)
		player.play()
		return player
		
	# Get player from pool
	var player: AudioStreamPlayer3D = _available_players.pop_back()
	_active_players.append(player)
	
	# Configure player
	player.stream = sound.audio_stream
	player.position = position
	player.max_distance = sound.max_distance
	player.unit_size = sound.min_distance
	player.attenuation = sound.attenuation
	
	# Store metadata for volume control
	player.set_meta("category", sound.category)
	player.set_meta("base_volume", sound.default_volume)
	player.set_meta("sound_id", sound.id)
	
	# Set initial volume
	_update_player_volume(player)
	
	# Play sound
	player.play()
	
	return player

func play_interface_sound(sound: SoundEntry) -> AudioStreamPlayer3D:
	# Interface sounds are non-positional
	return play_sound(sound)

func stop_sound(player: AudioStreamPlayer3D) -> void:
	if is_instance_valid(player):
		player.stop()
		_on_sound_finished(player)

func stop_all_sounds() -> void:
	for player in _active_players:
		if is_instance_valid(player):
			player.stop()
	_active_players.clear()
	_available_players.clear()
	_initialize_sound_players()

func _on_sound_finished(player: AudioStreamPlayer3D) -> void:
	# Return player to available pool
	if player in _active_players:
		_active_players.erase(player)
	if not player in _available_players:
		_available_players.append(player)

# Resource management
func preload_sounds() -> void:
	for sound in game_sounds + interface_sounds:
		if sound.should_preload:
			sound.preload_sound()
			if sound.loaded_audio_player:
				_sound_root.add_child(sound.loaded_audio_player)

func unload_sounds() -> void:
	stop_all_sounds()
	for sound in game_sounds + interface_sounds:
		sound.unload_sound()

# Cleanup
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(_sound_root):
			_sound_root.queue_free()
