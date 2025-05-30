# Scripts Directory

## Purpose
Core game systems implementation following WCS-Godot architecture.

## Structure
- **core/**: EPIC-001 - Foundation systems and utilities
  - **foundation/**: Constants, types, core utilities  
  - **archives/**: VP archive handling and extraction
  - **platform/**: Platform abstraction and debugging tools
  - **filesystem/**: File management utilities
- **debug/**: Development and debugging tools
- **effects/**: Visual and audio effects management
- **graphics/**: Graphics utilities and post-processing
- **hud/**: EPIC-012 - HUD gauge system (complete library)
- **mission_system/**: EPIC-005 - Mission management and coordination
- **missions/**: Mission controller implementation
- **object/**: Game object implementations (asteroids, debris, weapons)
- **player/**: Player ship and pilot management
- **sound_animation/**: Audio and 2D animation systems

## Key Guidelines
- Follow static typing throughout: `var name: Type`
- Use signals for inter-system communication
- Core classes: WCSObject, WCSObjectData, CustomPhysicsBody
- Reference addon resources via `addons/wcs_asset_core/resources/`

## Implementation Notes
- Core foundation complete (EPIC-001)
- HUD system complete with 30+ gauge implementations (EPIC-012) 
- Mission system framework in place (EPIC-005)
- Asset management via wcs_asset_core addon (EPIC-002)
- Physics integration through CustomPhysicsBody
- Object system replaces C++ pointer management