# WCS Data Migration UI Components

## Package Overview

This package provides Godot editor UI components for the WCS Data Migration & Conversion Tools addon. All UI components follow Godot best practices using scene composition rather than procedural UI construction.

## Key Components

### Conversion Wizard (Modular Architecture)

**Complete step-by-step wizard interface for WCS to Godot conversion workflow, built with modular, maintainable components:**

#### Core Components:

**`conversion_wizard_controller.gd`** - Main wizard controller that coordinates between steps
- Manages wizard state and navigation
- Handles step validation and accessibility
- Provides shared wizard data across all steps
- Controls step progression and completion

**`wizard_step_base.gd`** - Base class for all wizard steps
- Common functionality for step validation, completion tracking
- Signal-based communication with wizard controller  
- Shared wizard data management
- Activation/deactivation lifecycle methods

#### Individual Wizard Steps:

1. **`wizard_step_paths.gd/.tscn`** - Set Source and Target Paths
   - Configure game directory, extraction directory, and target assets directory
   - Auto-detection of common paths
   - Path validation and browse dialogs

2. **`wizard_step_extraction.gd/.tscn`** - Extract VP Archives  
   - Scan for VP files and extract them using Python tools
   - Progress tracking for extraction operations
   - Selective extraction of VP archives

3. **`wizard_step_mapping.gd/.tscn`** - Create Asset Mapping
   - Analyze extracted assets and create semantic mapping to Godot structure
   - Asset mapping table with source → target file mapping
   - Asset detail panel showing dependent resources
   - Filtering and statistics for asset mapping

4. **`wizard_step_conversion.gd/.tscn`** - Convert Assets
   - Select specific asset types to convert
   - Live progress tracking and logging
   - Conversion result reporting

#### Modular Benefits:
- **Maintainability**: Each step is self-contained and focused
- **Reusability**: Step components can be used independently  
- **Testability**: Individual steps can be tested in isolation
- **Extensibility**: Easy to add new steps or modify existing ones
- **Performance**: Only active step logic runs at any time

#### Single Conversion Pathway:
- **Unified Workflow**: All WCS assets converted through the wizard interface
- **No Duplication**: Removed redundant import plugins that duplicated wizard functionality
- **Consistent Output**: All conversions follow DM-018 semantic organization standards
- **Quality Control**: Comprehensive validation, conflict detection, and duplicate handling

## Architecture

### Scene-Based Design
All UI components use `.tscn` scene files with `@onready` node references rather than procedural construction. This follows Godot best practices for:
- Better editor integration
- Visual design capabilities  
- Maintainable code structure
- Proper separation of layout and logic

### Python Backend Integration
The wizard interface delegates all conversion logic to existing Python scripts:
- **Single Source of Truth**: All conversion logic centralized in Python tools
- **No Duplication**: Wizard calls same tools as CLI for consistency  
- **Proper Error Handling**: Comprehensive error reporting and progress tracking
- **Quality Control**: Validation, semantic organization, and conflict resolution

### Signal-Based Communication
Uses Godot signals for:
- Conversion progress updates
- Status changes
- Error reporting
- Inter-component communication

## Usage

### Editor Integration
The asset mapping wizard appears as a main editor tab when the addon is enabled:
- **Location**: Main editor window (like LimboAI, Asset Library)
- **Access**: Via "WCS Asset Mapper" tab in the main editor
- **Visibility**: Automatically shows when extracted campaign content is detected

### Typical Workflow
1. **Set Paths**: Configure WCS game directory, extraction target, and assets target
2. **Extract Archives**: Scan game directory for VP files and extract selected archives
3. **Create Mapping**: Analyze extracted assets and generate semantic mapping table
4. **Convert Assets**: Select asset types to convert and run conversion with progress tracking

### Asset Organization
Follows DM-018 semantic asset organization:
```
target/assets/campaigns/wing_commander_saga/
├── ships/
├── weapons/
├── environments/objects/asteroids/
├── effects/
├── audio/
└── ui/
```

## Settings Persistence

### Automatic Settings Storage
The campaign conversion dock automatically remembers user preferences:

- **Directory Paths**: VP game directory, extraction target, campaign source, assets target
- **Recent Paths**: Last 5 used directories for quick access via dropdown menus
- **Conversion Preferences**: Selected asset types, auto-detection settings
- **UI State**: Expanded/collapsed sections (planned)

### Settings File Location
Settings stored in: `user://wcs_campaign_conversion_settings.cfg`

### Recent Paths Feature
- **Source Recent Button**: Quick access to recently used campaign directories
- **Target Recent Button**: Quick access to recently used target directories  
- **Auto-validation**: Non-existent paths automatically removed from recent lists
- **Tooltips**: Full paths shown on hover for disambiguation

### Settings Methods
```gdscript
# Load settings from file
settings.load_settings()

# Save current state
settings.save_settings()

# Add to recent paths
settings.add_recent_campaign_path(path)
settings.add_recent_target_path(path)

# Reset to defaults
settings.reset_to_defaults()
```

## Development Notes

- All dynamic content (lists, trees, progress) populated programmatically
- Static UI layout defined in scene files
- Python script paths resolved using `ProjectSettings.globalize_path()`
- Error handling includes graceful degradation when tools unavailable
- Comprehensive logging for debugging and user feedback
- Settings automatically saved on directory changes and conversion operations