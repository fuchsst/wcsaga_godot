# IFF (Identification Friend or Foe) System

## Overview
The IFF system handles faction relationships, colors, and identification mechanics for different teams in Wing Commander Saga. It determines which ships are enemies, how they perceive each other, and what colors to display on the HUD.

## Components

### IFFResource
The base resource class that defines the properties of an IFF team:
- `name`: Team name (e.g., "Friendly", "Hostile")
- `display_color`: Color used for HUD/radar display
- `attacks`: List of team names this IFF attacks
- `perceptions`: Dictionary mapping other IFF names to how this IFF perceives them
- `flags`: Special behavior flags
- `default_ship_flags`: Default ship flags
- `default_ship_flags2`: Additional ship flags

### IFFManager (Autoload)
Singleton that manages the IFF database and provides lookup functionality:
- Loads all IFF resources at startup
- Provides methods to query IFF relationships
- Handles color lookups for HUD display

### IFFInterface
Simplified interface for common IFF queries:
- `are_enemies()`: Check if two IFFs are enemies
- `get_hud_color()`: Get display color for an IFF
- `get_perceived_color()`: Get how one IFF perceives another

## Usage

### Checking Relationships
```gdscript
# Check if two ships are enemies
if IFFInterface.are_enemies(ship1.iff_team, ship2.iff_team):
    # Ships are enemies, engage combat logic
```

### Displaying Colors
```gdscript
# Get HUD color for a ship
var hud_color = IFFInterface.get_hud_color(ship.iff_team)
# Apply to UI element
hud_element.modulate = hud_color
```

### Perception Mechanics
```gdscript
# Get how one ship perceives another (for stealth/cloaking)
var perceived_color = IFFInterface.get_perceived_color(viewer_ship.iff_team, target_ship.iff_team)
```

## Adding New IFF Teams
1. Create a new `.tres` file in `assets/data/iff/` using the IFFResource format
2. The IFFManager will automatically load it at startup
3. No code changes are needed for basic functionality

## Conversion from TBL Files
The `iff_converter.py` script in the data converter can be used to convert additional IFF definitions from TBL format to Godot resources.