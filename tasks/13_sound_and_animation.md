# Wing Commander Saga: Godot Conversion Analysis - Sound & Animation

This document analyzes the Sound & Animation components of the Wing Commander Saga C++ codebase (`sound`, `gamesnd`, `cutscene`, `anim`) and outlines a strategy for their conversion to Godot.

## III. Codebase Analysis: Sound & Animation

### A. Key Features

*   **Sound Effects Playback:** Playing various sound effects defined in `sounds.tbl` (weapons, explosions, UI clicks, engine sounds, flyby sounds per species, etc.) in both 2D (UI - `gamesnd_play_iface`) and 3D (game world - `snd_play_3d`). Supports volume, panning, and pitch control. (`sound.cpp`, `gamesnd.cpp`, `ds.cpp`)
*   **Event-Driven Music:** Dynamic music system defined in `music.tbl`. Changes tracks based on game events like arrivals (`event_music_arrival`), combat intensity (`hostile_ships_present`), mission success/failure (`event_music_primary_goals_met`, `event_music_primary_goal_failed`), player death/respawn. Uses patterns (normal, battle, arrival, victory, failure, dead) with defined transitions and looping. (`eventmusic.cpp`)
*   **Cutscene Playback:** Handling playback of pre-rendered video cutscenes (MVE, OGG Theora) defined in `cutscenes.tbl`. Includes logic for checking CD presence (likely obsolete). (`cutscenes.cpp`, `movie.cpp`, `mvelib.cpp`, `mveplayer.cpp`, `oggplayer.cpp`)
*   **Animation Playback:** Playing sprite-based animations (.ANI format) using RLE compression variants. Supports keyframes, variable frame rates, looping, ping-pong playback, color translation, and alpha blending (via specific color key or alpha channel in later versions). Can be streamed from disk or loaded into memory. (`animplay.cpp`, `packunpack.cpp`)
*   **Voice Playback:** Handling voice messages (likely pre-recorded WAV/OGG) and potentially text-to-speech via SAPI (Windows only). (`fsspeech.cpp`, `speech.cpp`)
*   **Audio Compression/Decompression:** Handles ADPCM audio compression via ACM (Windows Audio Compression Manager). Ogg Vorbis is handled via libvorbis. (`acm.cpp`, `audiostr.cpp`, `oggplayer.cpp`)
*   **Audio Management:** Loading (`snd_load`), unloading (`snd_unload`), managing sound buffers (DirectSound software/hardware buffers or OpenAL buffers), handling channels (prioritization, instance limiting), volume control, panning. (`sound.cpp`, `ds.cpp`)
*   **3D Audio:** Positional audio for game world sounds using DirectSound3D or OpenAL, including Doppler effects and distance attenuation (min/max distance). Listener position/orientation updates. (`ds3d.cpp`, `ds.cpp`)
*   **Environmental Audio (EAX):** Support for Creative Labs EAX for environmental reverb effects via DirectSound properties (likely deprecated/replaced). (`ds.cpp`)
*   **Redbook Audio:** CD audio playback via MCI (Windows Media Control Interface) (likely deprecated/replaced). (`rbaudio.cpp`)
*   **Voice Recognition:** Input command system based on voice using SAPI (Windows only) and predefined grammar rules. (`voicerec.cpp`, `grammar.h`)
*   **Real-time Voice:** Voice capture, compression (custom codec), and playback for multiplayer (likely deprecated/out of scope). (`rtvoice.cpp`)

### B. List Potential Godot Solutions

*   **Sound Effects Playback (2D/3D):**
    *   `AudioStreamPlayer`: For non-positional UI sounds (`gamesnd_play_iface`).
    *   `AudioStreamPlayer3D`: For positional sounds (`snd_play_3d`). Set `unit_size` for distance attenuation matching original min/max ranges.
    *   `AudioServer`: For global volume control (`Master_sound_volume`, `Master_voice_volume`) and potentially bus effects.
    *   `AudioStreamWAV`, `AudioStreamOggVorbis`: Godot's built-in audio stream types. Convert original sounds to one of these.
*   **Event-Driven Music:**
    *   `AudioStreamPlayer`: For playing music tracks. Use separate players for main track and potential overlays (`EMF_ALLIED_ARRIVAL_OVERLAY`).
    *   GDScript (`MusicManager.gd`): Reimplement the state logic from `eventmusic.cpp`. Use signals from gameplay systems to trigger state changes (e.g., `player.hull_changed`, `ai_manager.enemy_arrived`, `mission_manager.goal_completed`). Manage transitions, looping (`loop_for`), and forced pattern changes (`force_pattern`).
*   **Cutscene Playback:**
    *   `VideoStreamPlayer`: For playing video files. Requires conversion of MVE/OGG to Godot-supported formats (OGV, WebM recommended). `cutscenes.tbl` data can be stored in a Resource or Dictionary.
*   **Animation Playback:**
    *   `AnimatedSprite2D`: Convert .ANI frames to sprite sheets. Use `SpriteFrames` resource. GDScript to handle playback logic (`anim_show_next_frame` equivalent), including looping, ping-pong (`ping_pong`), frame skipping (`skip_frames`), and direction (`direction`). Keyframes might need manual implementation if complex. RLE decompression is replaced by Godot's texture handling. Color translation might need custom shaders if not simple tinting.
    *   `AnimationPlayer`: Could be used for UI animations previously done with .ANI.
*   **Voice Playback:**
    *   `AudioStreamPlayer` / `AudioStreamPlayer3D`: For playing pre-recorded voice files (WAV/OGG).
    *   Text-to-Speech (SAPI): Deprecated/Out of Scope.
*   **Audio Compression/Decompression:**
    *   Godot handles Ogg Vorbis internally. ADPCM (.wav) might be supported directly by Godot's WAV loader, otherwise pre-convert to WAV PCM or Ogg Vorbis.
*   **Audio Management:**
    *   Godot manages audio streams and playback via nodes. `AudioServer` for global settings. Resource preloading (`preload()`) for sounds. Channel prioritization/limiting needs custom logic in `SoundManager.gd` (check number of playing instances of a sound before starting a new one).
*   **3D Audio:**
    *   `AudioStreamPlayer3D` handles positional audio, Doppler (`doppler_tracking` property), and attenuation (`attenuation_model`, `unit_size`). Listener is usually the active `Camera3D`. Update listener transform via `get_viewport().set_listener_3d_transform()`.
*   **Environmental Audio (EAX):**
    *   `AudioServer` bus effects (Reverb (`AudioEffectReverb`), EQ, etc.). Recreate desired reverb presets using bus effects.
*   **Redbook Audio:**
    *   Deprecated. Convert CD tracks to Ogg Vorbis/MP3.
*   **Voice Recognition (SAPI):**
    *   Deprecated/Out of Scope.
*   **Real-time Voice:**
    *   Deprecated/Out of Scope. Godot 4 has some VoIP capabilities, but this is complex.

### C. Outline Target Code Structure

```
wcsaga_godot/
├── assets/
│   ├── sounds/         # Converted WAV/OGG sound effects
│   ├── music/          # Converted OGG/MP3 music tracks
│   ├── voices/         # Converted voiceover files
│   ├── cutscenes/      # Converted OGV/WebM video files
│   └── animations/     # Converted sprite sheets or animation resources
├── resources/
│   ├── game_sounds.tres # Resource defining game sound mappings (replaces sounds.tbl)
│   ├── music_tracks.tres # Resource defining music tracks and event logic (replaces music.tbl)
│   └── sound_environments.tres # (Optional) Resource defining reverb presets
├── scenes/
│   ├── effects/        # Scenes for animated effects using sounds
│   └── cutscenes/      # Scene for the VideoStreamPlayer setup
├── scripts/
│   ├── sound_animation/
│   │   ├── sound_manager.gd      # Singleton/Autoload for managing sound playback (2D/3D), channel limits, volume.
│   │   ├── music_manager.gd      # Singleton/Autoload for managing event music state machine and playback.
│   │   ├── ani_player_2d.gd      # Custom node or script extending AnimatedSprite2D for .ANI playback logic (loop, ping-pong, etc.)
│   │   ├── audio_bus_controller.gd # (Optional) Script to manage audio bus effects (reverb presets).
│   └── globals/
│       ├── game_sounds.gd        # Autoload holding sound effect references (loaded from game_sounds.tres)
│       └── music_data.gd         # Autoload holding music track references/data (loaded from music_tracks.tres)
```

### D. Identify Important Methods, Classes, and Data Structures

*   **`sound.(h|cpp)`:**
    *   `snd_load()`: Loads sound file, returns handle. -> `load()` in Godot, managed by `GameSounds` resource/script.
    *   `snd_unload()`: Unloads sound. -> Godot handles resource unloading automatically.
    *   `snd_play()`: Plays 2D sound. -> `SoundManager.play_sound_2d()`.
    *   `snd_play_3d()`: Plays 3D sound with position, velocity, min/max distance. -> `SoundManager.play_sound_3d()`.
    *   `snd_play_looping()`: Plays looping sound. -> Parameter in `SoundManager` functions.
    *   `snd_stop()`: Stops a specific sound instance (by handle/sig). -> `AudioStreamPlayer.stop()` or freeing the node. Need handle mapping in `SoundManager`.
    *   `snd_set_volume()`, `snd_set_pan()`: -> `AudioStreamPlayer.volume_db`, `AudioStreamPlayer3D.unit_db`, `AudioStreamPlayer3D.set_panning()`.
    *   `snd_is_playing()`: Checks if a sound instance is playing. -> `AudioStreamPlayer.playing`.
    *   `snd_update_listener()`: Updates listener position/orientation. -> `get_viewport().set_listener_3d_transform()`.
    *   `sound` struct: Holds sound data (sid, hid, filename, sig, info). -> Replaced by `AudioStream` resources and `SoundManager` logic.
*   **`gamesnd.(h|cpp)`:**
    *   `game_snd` struct: Defines sound properties (filename, volume, min/max dist, preload). -> `SoundEntry` custom resource (`sound_entry.gd`).
    *   `Snds`, `Snds_iface` arrays: -> `GameSounds` resource (`game_sounds.tres`) containing dictionary mapping names/IDs to `SoundEntry` resources.
    *   `gamesnd_parse_soundstbl()`: Parses `sounds.tbl`. -> GDScript (`populate_game_sounds.gd`) to parse `sounds.tbl` and create `game_sounds.tres`.
    *   `gamesnd_play_iface()`: Plays UI sound. -> `SoundManager.play_sound_2d()`.
*   **`eventmusic.(h|cpp)`:**
    *   `SOUNDTRACK_INFO` struct: Defines soundtrack patterns. -> `MusicTrack` custom resource (`music_entry.gd`).
    *   `Patterns` array: Holds runtime state for music patterns. -> Managed within `MusicManager.gd`.
    *   `event_music_init()`, `event_music_parse_musictbl()`: -> Logic to load `music_tracks.tres` in `MusicManager.gd`.
    *   `event_music_do_frame()`: Core logic for checking state and transitioning music. -> `_process()` or timer logic in `MusicManager.gd`.
    *   `event_music_change_pattern()`, `event_music_force_switch()`: -> Methods in `MusicManager.gd` to handle transitions.
    *   `event_music_arrival()`, `event_music_primary_goals_met()`, etc.: -> Signal handlers or methods in `MusicManager.gd`.
*   **`audiostr.(h|cpp)`:** Low-level streaming. Replaced by Godot's `AudioStreamPlayer` nodes.
*   **`acm.(h|cpp)`:** ADPCM handling. Replaced by Godot or pre-conversion.
*   **`ds.(h|cpp)`, `ds3d.(h|cpp)`:** DirectSound implementation. Replaced by Godot's `AudioServer`, `AudioStreamPlayer`, `AudioStreamPlayer3D`.
*   **`cutscene.(h|cpp)`:**
    *   `cutscene_info` struct: -> Dictionary or custom resource for cutscene data.
    *   `cutscenes_get_cd_num()`, `cutscenes_validate_cd()`: Obsolete CD checking.
    *   `cutscene_mark_viewable()`: -> Update player progress data.
    *   `cutscenes_screen_play()`: -> Function to instance and play the cutscene scene.
*   **`movie.(h|cpp)`:**
    *   `movie_play()`: -> Function in a global script or scene manager to load and play the cutscene scene using `VideoStreamPlayer`.
*   **`mvelib.(h|cpp)`, `mveplayer.(cpp)`, `decoder*.cpp`:** MVE playback. Replaced by Godot's video playback after conversion.
*   **`oggplayer.(h|cpp)`:** OGG playback. Replaced by Godot's `VideoStreamPlayer` / `AudioStreamOggVorbis`.
*   **`anim.(h|cpp)`, `packunpack.(h|cpp)`:**
    *   `anim` struct: Holds animation data (width, height, frames, keys, palette). -> `SpriteFrames` resource.
    *   `anim_instance` struct: Runtime state for an animation instance. -> State within the `ani_player_2d.gd` script.
    *   `anim_load()`: Loads .ANI file. -> Replaced by `load()` for the `SpriteFrames` resource.
    *   `anim_play()`: Creates an animation instance. -> Instancing the scene with `ani_player_2d.gd`.
    *   `anim_show_next_frame()`: Core playback logic. -> `_process()` or timer logic in `ani_player_2d.gd`.
    *   `unpack_frame()`, `unpack_frame_from_file()`: Decompression logic. -> Replaced by Godot's texture loading.
*   **`rtvoice.(h|cpp)`, `fsspeech.(h|cpp)`, `speech.(h|cpp)`, `voicerec.(h|cpp)`, `rbaudio.(h|cpp)`:** Deprecated/Out of Scope.

### E. Identify Relations

*   `GameSounds` resource provides `AudioStream`s to `SoundManager`.
*   `MusicManager` uses `AudioStreamPlayer` and data from `MusicData` (loaded from `music_tracks.tres`).
*   Gameplay scripts (Ship, Weapon, HUD, Mission) call `SoundManager.play_sound_2d/3d()` using sound names/IDs defined in `GameSounds`.
*   Game sequence manager calls a global function/scene manager to play cutscenes using `VideoStreamPlayer`.
*   UI/Effect scenes instance scenes containing `ani_player_2d.gd` (or `AnimatedSprite2D`) to play animations.
*   `SoundManager` interacts with `AudioServer` (implicitly via Players, or explicitly for global settings/bus effects). `AudioStreamPlayer3D` interacts with the `Listener3D` (Camera).
*   UI scripts call `SoundManager.play_sound_2d()` for interface sounds.
*   `MusicManager` receives signals from gameplay systems (AI state, Mission state, Player state) to determine music transitions.

## IV. Godot Implementation Strategy

1.  **Asset Conversion:**
    *   Convert all sound effects and voiceovers to Ogg Vorbis (.ogg) or WAV (.wav). ADPCM WAVs might need pre-conversion to PCM WAV or OGG.
    *   Convert all music tracks to Ogg Vorbis (.ogg).
    *   Convert all cutscenes (MVE/OGG Theora) to OGV (Theora/Vorbis) or WebM (VP9/Opus). MVE requires a dedicated converter.
    *   Develop a tool/script to convert .ANI files (handling RLE decompression and keyframes) into Godot `SpriteFrames` resources. Store palette translation info if needed for shaders.
2.  **Resource Definition:**
    *   Use `populate_game_sounds.gd` script to parse `sounds.tbl` and `*-snd.tbm` files, creating `game_sounds.tres`. This resource (likely a Dictionary) will map sound names/IDs from `gamesnd.h` to `SoundEntry` custom resources containing the `AudioStream` path, default volume, min/max distance.
    *   Create `music_tracks.tres` (Dictionary or custom Resource) based on `music.tbl` and `*-mus.tbm`, storing `AudioStream` paths for each pattern (NRML_1, BTTL_1, etc.) within named soundtracks. Store flags like `EMF_CYCLE_FS1`.
3.  **Sound Management (`SoundManager.gd`):**
    *   Implement `play_sound_2d(sound_id, volume_scale=1.0, priority=SND_PRIORITY_SINGLE_INSTANCE)` and `play_sound_3d(sound_id, position, velocity=Vector3.ZERO, volume_scale=1.0, radius=0.0, priority=SND_PRIORITY_SINGLE_INSTANCE)`.
    *   Use `GameSounds` autoload to get the `SoundEntry` resource based on `sound_id`.
    *   Implement channel/instance limiting based on `priority` and the number of currently playing instances of the same sound (`sound_id`). Keep track of active `AudioStreamPlayer3D` nodes.
    *   Instance `AudioStreamPlayer` or `AudioStreamPlayer3D` nodes dynamically. Add them to the scene tree (potentially under a dedicated 'Sounds' node).
    *   Set stream, volume (`unit_db` or `volume_db`), position, pitch (`pitch_scale`), attenuation (`unit_size` based on min/max distance), panning (for 2D).
    *   Connect the `finished` signal to `queue_free()` or a method to return the node to a pool.
    *   Provide functions to stop sounds by handle (`stop_sound(handle)`), requiring a way to map handles to nodes.
4.  **Music Management (`MusicManager.gd`):**
    *   Implement a state machine mirroring the logic in `eventmusic.cpp` (Normal, Battle, Arrival, Victory, Failure states).
    *   Use one or more `AudioStreamPlayer` nodes.
    *   Load music data from `MusicData` autoload.
    *   Connect to signals from gameplay systems (e.g., `GameManager.battle_state_changed`, `MissionManager.goal_state_changed`, `Player.died`).
    *   Implement smooth fading between tracks on state transitions using `Tween` or `AudioServer.set_bus_volume_db`.
    *   Handle pattern looping (`loop_for`) and forced transitions (`force_pattern`).
5.  **Animation Playback (`ani_player_2d.gd`):**
    *   Extend `AnimatedSprite2D`.
    *   Add properties for `loop`, `ping_pong`, `direction`, `skip_frames`, `framerate_independent` (may need custom timing logic).
    *   Override `_process` or use a `Timer` to implement the frame update logic similar to `anim_show_next_frame`, respecting the added properties.
6.  **Cutscene Playback:**
    *   Create a simple scene `cutscene_player.tscn` with a `VideoStreamPlayer` set to expand.
    *   Script `cutscene_player.gd` with a function `play_cutscene(video_path)` that loads the `VideoStream` and plays it. Handle the `finished` signal to transition back.
7.  **Integration:**
    *   Replace C++ calls like `snd_play(SND_LASER_FIRE, ...)` with `SoundManager.play_sound_3d(GameSounds.SND_LASER_FIRE, position, ...)`.
    *   Replace `gamesnd_play_iface(SND_USER_SELECT)` with `SoundManager.play_sound_2d(GameSounds.SND_USER_SELECT)`.
    *   Connect signals appropriately (e.g., `Ship.enemy_arrived.connect(MusicManager.on_enemy_arrival)`).
    *   Call the cutscene player scene's `play_cutscene` function when needed.
    *   Instance animation scenes (`AnimatedSprite2D` with `ani_player_2d.gd`) and call their play methods.
8.  **Deprecation:**
    *   Confirm EAX, Redbook, Voice Rec, RT Voice, TTS are not required. Remove related C++ code analysis if confirmed.
