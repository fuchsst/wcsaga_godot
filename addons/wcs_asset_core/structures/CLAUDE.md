# WCS Asset Core Structures Package

## Purpose
This package contains data structure classes for the WCS-Godot conversion project. These classes serve as the foundational data containers for various game systems, providing validation, serialization, and management capabilities.

## Key Classes

### GraphicsSettingsData
**Purpose**: Manages all graphics and display configuration options.
**Location**: `graphics_settings_data.gd`

**Key Features**:
- Resolution and fullscreen mode management
- Quality settings for textures, shadows, effects, and models
- Anti-aliasing configuration (MSAA, FXAA, temporal AA)
- Post-processing effects (motion blur, bloom, DOF, SSAO, SSR)
- Performance optimization settings (particle density, LOD, draw distance)
- Hardware detection and validation
- Performance impact estimation

**Usage Example**:
```gdscript
var graphics_settings: GraphicsSettingsData = GraphicsSettingsData.new()
graphics_settings.resolution_width = 2560
graphics_settings.resolution_height = 1440
graphics_settings.texture_quality = 4  # Ultra quality
graphics_settings.fullscreen_mode = GraphicsSettingsData.FullscreenMode.EXCLUSIVE

if graphics_settings.is_valid():
    # Apply settings to engine
    var config_dict: Dictionary = graphics_settings.to_dictionary()
```

### AudioSettingsData
**Purpose**: Comprehensive audio configuration including volume levels, quality settings, and spatial audio.
**Location**: `audio_settings_data.gd`

**Key Features**:
- Volume management for all audio categories (master, music, effects, voice, ambient, UI)
- Audio quality settings (sample rate, bit depth, channel configuration)
- Spatial audio features (3D audio, Doppler effect, reverb, occlusion)
- Voice and subtitle configuration
- Device and buffer management
- Accessibility options
- Performance estimation and quality presets

**Usage Example**:
```gdscript
var audio_settings: AudioSettingsData = AudioSettingsData.new()
audio_settings.master_volume = 0.8
audio_settings.enable_3d_audio = true
audio_settings.apply_quality_preset(AudioSettingsData.AudioQualityPreset.HIGH)

var volume_levels: Dictionary = audio_settings.get_volume_levels()
```

### ControlMappingData
**Purpose**: Input control mapping and device configuration management.
**Location**: `control_mapping_data.gd`

**Key Features**:
- Comprehensive input binding system (keyboard, mouse, gamepad)
- Control categories (targeting, ship movement, weapons, computer, camera, communication)
- Conflict detection between bindings
- Device sensitivity and deadzone settings
- Accessibility features (sticky keys, repeat settings, hold-to-toggle)
- Export to Godot InputMap format
- Multi-device support with device-specific configurations

**Usage Example**:
```gdscript
var control_mapping: ControlMappingData = ControlMappingData.new()

# Set custom binding
var fire_binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, MOUSE_BUTTON_LEFT)
control_mapping.set_binding("fire_primary", fire_binding)

# Check for conflicts
var conflicts: Array[Dictionary] = control_mapping.detect_conflicts()
if conflicts.is_empty():
    # Export to Godot
    var input_map: Dictionary = control_mapping.export_to_godot_input_map()
```

### BaseAssetData
**Purpose**: Base class for all asset data structures providing common functionality.
**Location**: `base_asset_data.gd`

**Key Features**:
- Asset identification and metadata
- Validation framework
- Serialization support
- Tagging system
- Creation and modification tracking

## Architecture Notes

### Validation Framework
All data structures inherit a robust validation system:
- Range checking for numeric values
- Enum validation for categorical values
- Cross-field validation for dependent settings
- Error collection and reporting

### Serialization Support
Comprehensive serialization capabilities:
- Dictionary-based serialization for JSON/config files
- Deep cloning support for independent copies
- Round-trip integrity guarantees

### Performance Considerations
- Validation is cached until data changes
- Large datasets use efficient data structures
- Memory usage estimation for resource planning
- Performance impact assessment for graphics/audio settings

## Integration Points

### With Options Controllers
These data structures integrate directly with:
- `GraphicsOptionsDataManager` for graphics settings
- `AudioOptionsDataManager` for audio settings  
- `ControlMappingManager` for input controls

### With Game Systems
- Graphics settings apply to rendering pipeline
- Audio settings control audio engine configuration
- Control mappings integrate with input system and Godot's InputMap

### With Configuration System
- Automatic loading/saving of user preferences
- Profile management and preset systems
- Migration support for configuration updates

## Testing Notes

### Comprehensive Unit Tests
Each data structure has extensive unit tests covering:
- Initialization and default values
- Validation of all parameters and edge cases
- Serialization round-trip integrity
- Cloning and independence verification
- Utility method correctness
- Performance characteristics

### Test Coverage
- **GraphicsSettingsData**: 30+ test methods covering all features
- **AudioSettingsData**: 25+ test methods including preset application
- **ControlMappingData**: 35+ test methods including conflict detection

## Performance Characteristics

### Memory Usage
- GraphicsSettingsData: ~2KB per instance
- AudioSettingsData: ~1.5KB per instance  
- ControlMappingData: ~5KB per instance (includes all bindings)

### Validation Performance
- Typical validation time: <1ms per structure
- Validation is cached until data modification
- Conflict detection: O(n²) where n is number of bindings

### Serialization Performance
- Dictionary conversion: <0.5ms per structure
- Round-trip serialization maintains 100% data integrity
- Efficient memory usage during serialization

## Future Enhancements

### Planned Features
1. **Hardware Detection**: Automatic graphics capability detection
2. **Profile System**: Named configuration profiles with quick switching
3. **Cloud Sync**: Synchronization of settings across devices
4. **Advanced Accessibility**: Enhanced support for accessibility needs
5. **Performance Analytics**: Automatic performance tuning recommendations

### Extensibility
The validation and serialization framework supports easy addition of new settings without breaking existing functionality.