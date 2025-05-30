# Addons Directory

## Purpose
Editor plugins and runtime addons for WCS-Godot conversion project.

## Structure
- **gfred2/**: EPIC-005 - FRED2 Mission Editor Plugin for Godot
- **wcs_asset_core/**: EPIC-002 - Shared asset management system (enabled in project)
- **wcs_converter/**: EPIC-003 - Asset conversion and import integration
- **scene_manager/**: Scene transitions and management (community plugin)
- **gdUnit4/**: Unit testing framework (community plugin)
- **SignalVisualizer/**: Debug tool for signal visualization (community plugin)
- **godot_mcp/**: Model Context Protocol integration (community plugin)
- **debug_console/**: Debug console overlay utilities

## Key Guidelines
- Enable addons via Project Settings → Plugins
- **wcs_asset_core** must remain enabled for asset classes to work
- Use shared addon resources: `addons/wcs_asset_core/resources/`
- FRED2 requires wcs_asset_core for asset browsing
- SEXP system (EPIC-004) will be implemented as separate addon when ready

## Development Notes
- All WCS asset classes defined in wcs_asset_core addon
- Asset management follows [EPIC-002 Asset structures management addon Architecture](.ai\docs\EPIC-002-asset-structures-management-addon\architecture.md)
- Mission editing capabilities provided by gfred2 addon