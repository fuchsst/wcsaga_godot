# Assets Directory

## Purpose
Converted WCS assets (textures, models, audio) for Godot import.

## Structure
- **hermes_cbanims/**: Command briefing animations
- **hermes_core/**: Core game graphics
- **hermes_effects/**: Visual effects and particles
- **hermes_interface/**: UI elements and interface graphics

## Key Guidelines
- Assets converted from original WCS VP archives
- Proper Godot import settings applied automatically
- Texture compression and optimization configured
- Original WCS asset organization preserved

## Asset Pipeline
1. **Extraction**: VP archives → raw assets (EPIC-003)
2. **Conversion**: Format conversion to Godot-compatible
3. **Import**: Godot automatic import with proper settings
4. **Organization**: Maintain WCS folder structure

## Implementation Notes
- Asset catalog system tracks all imports (EPIC-003)
- Conversion tools generate correct import configurations
- Asset loading optimized for runtime performance
- Compatible with WCS asset referencing patterns