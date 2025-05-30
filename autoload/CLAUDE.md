# Autoload Directory - EPIC-001 Core Foundation

## Purpose
Core foundation autoloads providing essential system managers for WCS-Godot.

## Autoload Order (Critical)
1. **GameStateManager** - Game state coordination
2. **PhysicsManager** - Physics simulation  
3. **InputManager** - Input processing
4. **ConfigurationManager** - Settings management
5. **SaveGameManager** - Save/load operations
6. **ObjectManager** - Object lifecycle
7. **VPResourceManager** - VP archive loading

## Key Classes
- All autoloads extend Node and are globally accessible
- Use explicit `preload()` statements for addon classes
- ConfigurationManager loads: GameSettings, UserPreferences, SystemConfiguration
- SaveGameManager loads: SaveSlotInfo, PlayerProfile, CampaignState

## Integration Notes
- Autoloads reference `addons/wcs_asset_core/resources/` for data classes
- Manager coordination handled via signals
- Initialization order enforced by dependencies