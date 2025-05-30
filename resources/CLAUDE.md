# Resources Directory

## Purpose
Game resources and configuration files for WCS-Godot.

## Structure
- **Static game resources and configuration files**
- **Temporary holding area for non-addon resources**

## Key Guidelines
- **Primary asset location**: Use `addons/wcs_asset_core/resources/` instead
- This directory for project-level resources only
- Game settings, sounds, and pilot tips stored here temporarily
- Convert compatible resources to addon structure when possible

## Migration Status
- Core data structures moved to `addons/wcs_asset_core/resources/`
- Configuration classes available through addon
- Asset loading handled by WCSAssetLoader (EPIC-002)

## Implementation Notes
- Prefer addon resources for reusable assets
- Project-specific resources remain here
- Use ResourceLoader.load() for accessing resources