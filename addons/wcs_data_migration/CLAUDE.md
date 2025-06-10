# WCS Data Migration & Conversion Tools Addon

## Package Overview

This addon provides the complete EPIC-003 data migration and conversion pipeline integrated directly into the Godot editor. It combines all Python conversion tools with native Godot import plugins and a comprehensive UI for managing WCS to Godot asset conversion.

## Key Components

### Core Conversion Tools (Python Backend)

The powerful Python backend tools are organized within the addon structure, providing a clear separation between the backend logic and the Godot editor integration.

- **Unified Asset Mapper (`tools/asset_mapper.py`)**: A consolidated tool for both standard and semantic asset mapping. It analyzes WCS table files and other assets to generate a comprehensive `semantic_asset_index.json`.
- **Configuration Migrator (`tools/config_migrator.py`)**: A dedicated tool for migrating WCS configuration files, player settings, and control bindings to Godot-compatible formats.
- **Core Modules (`core/`)**: A collection of shared Python modules for asset discovery, classification, path resolution, relationship building, validation, and other utilities.
- **Specialized Converters**: A suite of specialized converters for missions (`mission_converter/`), POF models (`pof_parser/`), and tables (`table_converters/`). The table converters now include:
  - `ai_profiles_table_converter.py`
  - `ai_table_converter.py`
  - `armor_table_converter.py`
  - `asteroid_table_converter.py`
  - `cutscenes_table_converter.py`
  - `fireball_table_converter.py`
  - `iff_table_converter.py`
  - `lightning_table_converter.py`
  - `medals_table_converter.py`
  - `music_table_converter.py`
  - `rank_table_converter.py`
  - `scripting_table_converter.py`
  - `ship_table_converter.py`
  - `sounds_table_converter.py`
  - `species_defs_table_converter.py`
  - `species_table_converter.py`
  - `stars_table_converter.py`
  - `weapon_table_converter.py`

### Godot Editor Integration

- **UI and Import Components (`ui_components/`)**: A comprehensive set of components for editor integration. This includes the main **Conversion Dock UI** for managing the pipeline, as well as the native **Godot Import Plugins** that seamlessly integrate WCS assets (POF, VP, missions) into the editor workflow. The main UI logic is driven by `ui_components/plugin.gd`.

### Architecture

The addon follows a clean, modular architecture that separates backend processing from frontend UI. The `tools/` directory contains all the command-line Python scripts, which are executed by the GDScript-based UI components in the `ui_components/` directory. This structure ensures that the addon is both powerful and easy to maintain.

**Implementation Status**: All core functionalities have been refactored and consolidated for improved clarity and maintainability. The addon now follows a more robust, organized structure.
