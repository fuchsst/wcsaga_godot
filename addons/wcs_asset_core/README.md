# WCS Asset Core Addon

**Version**: 1.0.0  
**Purpose**: Shared asset data structures and management system for Wing Commander Saga conversion

## Overview

The WCS Asset Core addon provides centralized asset definitions, loading, registry, and validation capabilities for both the main game and FRED2 editor. This eliminates code duplication and ensures consistent asset management across all WCS-Godot systems.

## Features

- **Centralized Asset Definitions**: Single source of truth for all asset data structures
- **Type-Safe Resource System**: Fully typed GDScript resources with validation
- **Asset Loading System**: Efficient loading with caching and dependency resolution
- **Asset Registry**: Discovery and cataloging of available assets
- **Validation System**: Comprehensive asset integrity checking
- **Plugin Integration**: Clean Godot addon with editor integration

## Asset Types

### BaseAssetData
Base class for all WCS assets with common properties:
- Asset name, ID, and description
- File path and metadata
- Validation interface

### ShipData
Comprehensive ship specifications including:
- Physical properties (mass, velocity, rotation)
- Visual elements (models, textures, effects)
- Weapons and subsystems
- Hull, shields, and armor
- AI and sound configuration

### WeaponData
Complete weapon definitions covering:
- Damage and physics properties
- Firing characteristics and ammunition
- Homing and special effects
- Visual and audio effects
- Beam and missile configurations

### ArmorData
Armor and shielding specifications:
- Damage resistance mappings
- Shield piercing properties
- Type-specific modifiers

## Architecture

```
addons/wcs_asset_core/
├── plugin.cfg                    # Addon configuration
├── AssetCorePlugin.gd            # Main plugin class
├── structures/                   # Asset data definitions
│   ├── base_asset_data.gd       # Base asset interface
│   ├── ship_data.gd             # Ship specifications
│   ├── weapon_data.gd           # Weapon definitions
│   └── armor_data.gd            # Armor specifications
├── loaders/                      # Asset loading systems
│   ├── asset_loader.gd          # Core loading functionality
│   ├── registry_manager.gd      # Asset discovery
│   └── validation_manager.gd    # Asset validation
├── constants/                    # Shared constants
│   ├── asset_types.gd           # Asset type definitions
│   └── folder_paths.gd          # Standardized paths
├── utils/                        # Utility functions
│   ├── asset_utils.gd          # Helper functions
│   └── path_utils.gd           # Path management
└── icons/                        # Asset type icons
```

## Usage

### Loading Assets
```gdscript
# Load a ship asset
var ship_data: ShipData = WCSAssetLoader.load_asset("ships/terran/colossus.tres")
if ship_data and ship_data.is_valid():
    configure_ship(ship_data)

# Get all weapons of a type
var primary_weapons: Array[WeaponData] = WCSAssetLoader.load_assets_by_type(AssetTypes.Type.PRIMARY_WEAPON)
```

### Asset Discovery
```gdscript
# Search for assets
var laser_weapons: Array[BaseAssetData] = WCSAssetRegistry.search_assets("laser")

# Get assets by type
var all_ships: Array[BaseAssetData] = WCSAssetRegistry.get_assets_by_type(AssetTypes.Type.SHIP)
```

### Asset Validation
```gdscript
# Validate an asset
var validation_result: ValidationResult = WCSAssetValidator.validate_asset(ship_data)
if not validation_result.is_valid:
    for error in validation_result.errors:
        print("Validation error: ", error)
```

## Integration

### Main Game
The main game imports this addon and uses the provided autoloads for all asset operations, replacing the existing `AssetManager` system gradually.

### FRED2 Editor
The editor integrates with the addon's asset registry for browsing and selecting assets during mission creation.

### Testing
Comprehensive unit tests ensure all components work correctly and maintain asset integrity.

## Dependencies

- Godot 4.4+
- Core Resource system
- FileSystem access
- JSON serialization support

## Performance

- Efficient caching with LRU eviction
- Async loading for large assets
- Indexed search for fast discovery
- Memory management with configurable limits

## Development

This addon follows strict GDScript standards:
- 100% static typing
- Comprehensive documentation
- Unit test coverage
- Clean architecture patterns

## License

Part of the WCS-Godot conversion project.