# WCS Asset Core Addon Package Documentation

## Package Purpose

The WCS Asset Core addon provides a centralized, type-safe asset management system for the Wing Commander Saga to Godot conversion project. This addon eliminates code duplication between the main game and FRED2 editor by providing shared asset definitions, loading, registry, validation, and management capabilities.

## Original C++ Analysis

### Key C++ Components Analyzed

**Ship System (`source/code/ship/ship.cpp`, `ship.h`)**:
- 100+ properties per ship including physics, weapons, visuals
- Complex circular dependencies between ship.h ↔ weapon.h
- Intricate subsystem management and damage modeling
- Performance-critical calculations for movement and combat

**Weapon System (`source/code/weapon/weapons.cpp`, `weapon.h`)**:
- Comprehensive weapon definitions covering lasers, missiles, beams
- Complex firing mechanics with burst modes, homing, and special effects
- Damage calculation with armor penetration and shield piercing
- Trail, particle, and visual effect management

**Asset Management (`source/code/bmpman/bmpman.cpp`)**:
- 4,750-slot texture cache system for performance
- Model caching and LOD management
- VP archive integration for asset loading
- Memory management for large asset collections

### Key Findings
- **Circular Dependencies**: Resolved using Godot Resource references instead of direct C++ includes
- **Complex Caching**: Replaced with Godot's built-in Resource caching system
- **Performance Concerns**: Mitigated by modern hardware handling 15+ year old assets efficiently
- **Data Complexity**: ~50,000+ lines across 21 asset files, requiring careful structure preservation

## Key Classes

### BaseAssetData
**Purpose**: Foundation class for all WCS assets with common properties and validation interface.

**Responsibilities**:
- Provides asset identification (name, ID, type)
- Metadata and tag management
- Validation interface with error reporting
- Memory usage estimation for cache management
- Serialization support for asset conversion

**Usage**:
```gdscript
var asset: BaseAssetData = load("res://assets/ships/terran/colossus.tres")
if asset.is_valid():
    print("Asset: %s (Type: %s)" % [asset.get_display_name(), asset.get_asset_type_name()])
else:
    for error in asset.get_validation_errors():
        print("Error: %s" % error)
```

### ShipData
**Purpose**: Comprehensive ship specifications extracted from WCS ship_info structure.

**Responsibilities**:
- 100+ ship properties covering physics, visuals, weapons, and systems
- Weapon bank configuration with resource path references
- Advanced movement properties (afterburner, gliding, Newtonian physics)
- Destruction and debris specifications
- Ship-specific validation and utility functions

**Usage**:
```gdscript
var ship: ShipData = WCSAssetLoader.load_asset("ships/terran/colossus.tres")
print("Speed: %.1f, Afterburner: %.1f" % [ship.get_max_speed(), ship.get_afterburner_speed()])
print("Combat Rating: %.1f" % ship.get_combat_rating())
```

### WeaponData
**Purpose**: Complete weapon definitions covering all WCS weapon types and mechanics.

**Responsibilities**:
- Damage, physics, and firing properties
- Homing missile configuration
- Beam weapon specifications
- Visual and audio effect definitions
- Special weapon mechanics (swarm, corkscrew, EMP)

**Usage**:
```gdscript
var weapon: WeaponData = WCSAssetLoader.load_asset("weapons/primary/subach_hl7.tres")
print("DPS: %.1f, Range: %.1f" % [weapon.get_dps(), weapon.get_range_effectiveness()])
if weapon.is_homing_weapon():
    print("Tracking: %.2f" % weapon.get_tracking_ability())
```

### ArmorData
**Purpose**: Armor and shield specifications with damage resistance modeling.

**Responsibilities**:
- Damage resistance mappings for different damage types
- Shield piercing properties and calculations
- Armor degradation and repair mechanics
- Balance validation for damage resistances

**Usage**:
```gdscript
var armor: ArmorData = WCSAssetLoader.load_asset("armor/standard_hull.tres")
var kinetic_damage: float = armor.calculate_damage_taken(100.0, "kinetic")
print("Kinetic resistance: %.1f%%" % ((1.0 - armor.get_damage_multiplier("kinetic")) * 100))
```

### AssetLoader (WCSAssetLoader Autoload)
**Purpose**: Centralized asset loading with caching and performance optimization.

**Responsibilities**:
- Synchronous and asynchronous asset loading
- LRU cache management with memory limits
- Type-specific asset loading by AssetTypes.Type
- Performance tracking and optimization

**Usage**:
```gdscript
# Load single asset
var ship: ShipData = WCSAssetLoader.load_asset("ships/terran/colossus.tres")

# Load all weapons of a type
var primary_weapons: Array[WeaponData] = WCSAssetLoader.load_assets_by_type(AssetTypes.Type.PRIMARY_WEAPON)

# Async loading
WCSAssetLoader.load_asset_async("ships/heavy/dreadnought.tres", _on_ship_loaded)
```

### RegistryManager (WCSAssetRegistry Autoload)
**Purpose**: Asset discovery, cataloging, and search capabilities.

**Responsibilities**:
- Directory scanning and asset registration
- Type, category, and tag-based indexing
- Advanced search with filtering and ranking
- Asset group management for batch operations

**Usage**:
```gdscript
# Search for assets
var laser_weapons: Array[String] = WCSAssetRegistry.search_assets("laser", AssetTypes.Type.PRIMARY_WEAPON)

# Filter by multiple criteria
var filters: Dictionary = {"type": AssetTypes.Type.SHIP, "category": "fighter"}
var fighters: Array[String] = WCSAssetRegistry.filter_assets(filters)

# Asset information
var info: Dictionary = WCSAssetRegistry.get_asset_info("ships/terran/colossus.tres")
```

### ValidationManager (WCSAssetValidator Autoload)
**Purpose**: Comprehensive asset validation with error detection and suggestions.

**Responsibilities**:
- Asset-specific validation rules (ships, weapons, armor)
- Performance and dependency validation
- Batch validation capabilities
- Validation statistics and reporting

**Usage**:
```gdscript
var ship: ShipData = load("ships/terran/colossus.tres")
var result: ValidationResult = WCSAssetValidator.validate_asset(ship)

if not result.is_valid:
    for error in result.errors:
        print("Error: %s" % error)

for warning in result.warnings:
    print("Warning: %s" % warning)
```

## Architecture Notes

### Resource-Based Design
The addon leverages Godot's Resource system to:
- Automatically handle asset dependencies and references
- Provide built-in caching without custom cache management
- Enable type-safe asset loading with static typing
- Support serialization and editor integration

### Circular Dependency Resolution
WCS C++ had circular dependencies (ship.h ↔ weapon.h). The addon resolves this by:
- Using resource paths instead of direct object references
- Loading dependencies on-demand through WCSAssetLoader
- Maintaining referential integrity through path validation

### Plugin Architecture
The addon follows Godot plugin conventions:
- `plugin.cfg` for addon configuration
- `AssetCorePlugin.gd` for lifecycle management
- Autoload registration for global access
- Custom type registration for editor integration

### Type Safety
100% static typing throughout:
- All variables, parameters, and return types explicitly typed
- Asset type validation using AssetTypes.Type enum
- Comprehensive validation with typed error reporting

## C++ to Godot Mapping

### Memory Management
- **C++ RAII/destructors** → **Godot automatic Resource cleanup**
- **C++ pointer management** → **Godot Resource references**
- **Custom caching** → **Built-in ResourceLoader caching**

### Data Structures
- **C++ ship_info struct** → **ShipData Resource class**
- **C++ weapon_info struct** → **WeaponData Resource class**
- **C++ ArmorType class** → **ArmorData Resource class**
- **C++ circular includes** → **Resource path references**

### Asset Loading
- **VP archive loading** → **Godot ResourceLoader integration**
- **Manual cache management** → **Automatic Resource caching**
- **Index-based references** → **Resource path references**

### Performance Optimization
- **4,750 texture cache slots** → **Godot's efficient built-in caching**
- **Manual memory management** → **Automatic garbage collection**
- **Complex LOD systems** → **Simplified modern approach**

## Integration Points

### Main Game Integration
```gdscript
# Replace legacy AssetManager calls
# OLD: AssetManager.load_asset(path)
# NEW: WCSAssetLoader.load_asset(path)

# Example integration in ship spawning
func spawn_ship(ship_class: String) -> Node3D:
    var ship_data: ShipData = WCSAssetLoader.load_asset("ships/" + ship_class + ".tres")
    if ship_data and ship_data.is_valid():
        return _create_ship_from_data(ship_data)
    return null
```

### FRED2 Editor Integration
```gdscript
# Asset browser integration
func populate_ship_list() -> void:
    var ships: Array[String] = WCSAssetRegistry.get_asset_paths_by_type(AssetTypes.Type.SHIP)
    for ship_path in ships:
        var info: Dictionary = WCSAssetRegistry.get_asset_info(ship_path)
        asset_list.add_item(info["asset_name"])

# Search functionality
func search_assets(query: String) -> void:
    var results: Array[String] = WCSAssetRegistry.search_assets(query)
    _update_search_results(results)
```

### Asset Pipeline Integration
```gdscript
# Validation in import pipeline
func validate_imported_asset(asset_path: String) -> bool:
    var result: ValidationResult = WCSAssetValidator.validate_by_path(asset_path)
    if not result.is_valid:
        push_error("Asset validation failed: %s" % asset_path)
        return false
    return true
```

## Performance Considerations

### Memory Management
- **LRU Cache**: Automatic eviction of least-recently-used assets
- **Memory Limits**: Configurable cache size limits (default: 100MB)
- **Size Estimation**: Each asset calculates its memory footprint

### Loading Performance
- **Async Loading**: Thread-based async loading for large assets
- **Batch Operations**: Efficient batch loading and validation
- **Preloading**: Asset group preloading for critical assets

### Search Performance
- **Indexed Search**: Pre-built indices for type, category, and tag searches
- **Search Caching**: Cached search results for repeated queries
- **Optimized Filters**: Efficient filtering using built indices

### Validation Performance
- **Cached Validation**: Validation results cached for 5 seconds
- **Timeout Protection**: Validation timeout to prevent blocking
- **Incremental Validation**: Option to validate subsets of properties

## Testing Notes

### Unit Testing
Comprehensive unit tests using GdUnit4 framework:
- **Asset Creation**: Test asset instantiation and property setting
- **Validation Logic**: Test all validation rules and edge cases
- **Loading Mechanics**: Test synchronous and asynchronous loading
- **Search Functionality**: Test search accuracy and performance

### Integration Testing
- **Game Integration**: Test asset loading in actual game scenarios
- **Editor Integration**: Test FRED2 asset browser functionality
- **Performance Testing**: Benchmark loading times and memory usage
- **Migration Testing**: Test conversion from legacy asset formats

### Test Organization
```
tests/
├── unit/
│   ├── test_base_asset_data.gd
│   ├── test_ship_data.gd
│   ├── test_weapon_data.gd
│   ├── test_armor_data.gd
│   ├── test_asset_loader.gd
│   ├── test_registry_manager.gd
│   └── test_validation_manager.gd
├── integration/
│   ├── test_game_integration.gd
│   ├── test_editor_integration.gd
│   └── test_performance.gd
└── fixtures/
    ├── test_ship_data.tres
    ├── test_weapon_data.tres
    └── test_armor_data.tres
```

### Running Tests
```bash
# Run all addon tests
cd /mnt/d/projects/wcsaga_godot_converter/target
export GODOT_BIN="/mnt/d/Godot/Godot_v4.4.1-stable_win64_console.exe"
bash addons/gdUnit4/runtest.sh -a tests/addon_tests

# Run specific test suite
bash addons/gdUnit4/runtest.sh -a tests/unit/test_asset_loader.gd
```

## Implementation Deviations

### Intentional Changes from C++ Original

1. **Resource Path References**: Instead of C++ pointer/index references, uses Godot resource paths for better dependency management and editor integration.

2. **Simplified Caching**: Removes complex custom caching in favor of Godot's built-in Resource caching, which is more efficient and easier to maintain.

3. **Type-Safe Design**: Enforces 100% static typing throughout, unlike the original C++ which had some untyped variants and void pointers.

4. **Validation Integration**: Adds comprehensive validation framework not present in original, enabling better asset quality control.

5. **Modern Architecture**: Uses Godot autoloads and signals for better integration with engine systems and event-driven design.

### Justifications

- **Performance**: Modern hardware easily handles assets designed for 15+ year old systems
- **Maintainability**: Godot-native patterns are easier to understand and maintain
- **Type Safety**: Static typing prevents runtime errors common in original C++
- **Integration**: Plugin architecture enables clean separation and reusability
- **Extensibility**: Resource-based design makes adding new asset types straightforward

## Future Extensibility

The addon is designed for easy extension:

### Adding New Asset Types
```gdscript
# 1. Add to AssetTypes.Type enum
# 2. Create new asset class extending BaseAssetData
class_name MyAssetData
extends BaseAssetData

func _init() -> void:
    asset_type = AssetTypes.Type.MY_ASSET

# 3. Register validator
var my_validator: AssetValidator = MyAssetValidator.new()
WCSAssetValidator.register_validator(AssetTypes.Type.MY_ASSET, my_validator)

# 4. Add directory mapping in FolderPaths
# 5. Register custom type in plugin
```

### Custom Validation Rules
```gdscript
var custom_validator: AssetValidator = AssetValidator.new("Custom Validator")
custom_validator.validate = func(asset: BaseAssetData, result: ValidationResult):
    # Custom validation logic
    pass

WCSAssetValidator.register_global_validator(custom_validator)
```

### Asset Processing Pipeline
```gdscript
# Hook into asset loading for custom processing
WCSAssetLoader.asset_loaded.connect(_on_asset_loaded)

func _on_asset_loaded(asset_path: String, asset: BaseAssetData) -> void:
    # Custom processing after asset loads
    pass
```

This comprehensive documentation provides developers with everything needed to understand, use, extend, and maintain the WCS Asset Core addon effectively.