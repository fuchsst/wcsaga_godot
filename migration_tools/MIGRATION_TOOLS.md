# WCS-Godot Migration Tools

## Overview
This directory contains all tools and scripts for migrating Wing Commander Saga assets to Godot format. These tools are separated from the main Godot project to keep migration logic distinct from runtime code.

## Directory Structure
```
migration_tools/
├── asset_pipeline/           # GDScript asset pipeline (moved from scripts/)
│   ├── vp_archive.gd        # VP archive reader
│   ├── vp_manager.gd        # Multi-archive management
│   ├── table_parser.gd      # WCS table file parser
│   ├── migrators/           # Format-specific migration scripts
│   │   ├── pof_migrator.gd  # POF to GLTF/TSCN conversion
│   │   ├── vp_migrator.gd   # Batch VP migration
│   │   └── table_migrator.gd # Table to .tres conversion
│   ├── resources/           # Godot resource definitions
│   │   ├── ship_data.gd     # Enhanced ship data structure
│   │   ├── weapon_data.gd   # Enhanced weapon data structure
│   │   ├── ai_profile_data.gd
│   │   ├── subsystem_data.gd
│   │   ├── mission_data.gd
│   │   └── campaign_data.gd
│   └── CLAUDE.md           # Asset pipeline documentation
├── python_tools/            # Python migration utilities
│   ├── vp_extractor.py     # VP archive extraction
│   ├── pof_file_viewer.py  # POF file analysis
│   ├── sexp_parser.py      # SEXP expression parsing
│   ├── code_analyzer.py    # C++ code analysis
│   └── convert.py          # Main conversion orchestrator
└── MIGRATION_TOOLS.md      # This documentation
```

## Tool Categories

### GDScript Asset Pipeline
**Location**: `asset_pipeline/`
**Purpose**: Runtime asset loading and conversion within Godot
**Usage**: Used by the Godot project during development and runtime

These tools are integrated with the Godot project through the AssetManager autoload and provide:
- VP archive reading and management
- Table file parsing and resource generation
- POF model conversion to Godot scenes
- Batch asset migration capabilities

### Python Migration Tools
**Location**: `python_tools/` (inherits existing scripts)
**Purpose**: Standalone analysis and conversion tools
**Usage**: Run independently for asset preparation and analysis

These tools provide:
- VP archive extraction for inspection
- POF file format analysis and debugging
- SEXP script parsing and conversion planning
- C++ source code analysis for reverse engineering

## Migration Workflow

### Phase 1: Analysis
1. Use `code_analyzer.py` to understand WCS data structures
2. Use `pof_file_viewer.py` to inspect 3D model formats
3. Use `vp_extractor.py` to extract sample assets

### Phase 2: Batch Conversion
1. Use `convert.py` to orchestrate large-scale migration
2. Use GDScript `VPMigrator` for asset pipeline integration
3. Use `TableMigrator` for data structure conversion

### Phase 3: Runtime Integration
1. `AssetManager` coordinates runtime asset loading
2. `VPManager` handles multiple archive precedence
3. Enhanced resource classes provide typed game data

## Key Features

### Format Support
- **VP Archives**: Complete reader with precedence handling
- **POF Models**: Conversion to GLTF/TSCN with hardpoint preservation
- **Table Files**: All WCS .tbl formats with expression parsing
- **Mission Files**: .fs2 mission parsing and conversion
- **Campaign Files**: .fc2 campaign structure conversion

### Performance Optimization
- LRU caching for frequent asset access
- Object pooling for runtime efficiency
- Lazy loading and streaming support
- Memory usage monitoring and limits

### Data Integrity
- Complete WCS data model preservation
- Validation and error checking throughout pipeline
- Metadata preservation in Godot resources
- Conversion verification and testing

## Usage Examples

### Load VP Archives in Godot
```gdscript
# AssetManager automatically loads from configured paths
var ship_scene: PackedScene = AssetManager.load_asset("data/models/gvf_ares.pof")
var ship_data: ShipData = AssetManager.load_asset("data/tables/ships.tbl")
```

### Batch Migration
```gdscript
var migrator: VPMigrator = VPMigrator.new()
migrator.set_output_directory("res://migrated_assets/")
migrator.migrate_vp_archive("data/root_fs2.vp")
```

### Python Analysis
```bash
# Extract VP contents for inspection
python vp_extractor.py root_fs2.vp --output extracted/

# Analyze POF model structure
python pof_file_viewer.py extracted/data/models/gvf_ares.pof

# Convert specific assets
python convert.py --input data/ --output migrated/ --format all
```

## Integration with Main Project

### Autoload Integration
The asset pipeline integrates with the main Godot project through:
- `AssetManager` autoload for unified asset access
- Runtime migration capabilities for missing assets
- Performance monitoring through debug overlay

### Development Workflow
1. Use migration tools to convert WCS assets to Godot format
2. Assets automatically loaded through AssetManager during development
3. Debug overlay shows asset pipeline status and performance
4. Unit tests validate conversion accuracy and performance

## Performance Targets
- VP archive access: <10ms per file
- Table file parsing: <50ms for typical files
- POF model conversion: <200ms for standard ships
- Memory usage: <100MB for typical asset sets
- Cache hit ratio: >90% for repeated access

## Dependencies
- **Godot 4.4+**: For GDScript asset pipeline
- **Python 3.8+**: For standalone migration tools
- **ffmpeg**: For audio/video conversion (optional)
- **ImageMagick**: For advanced texture processing (optional)

This migration tools suite provides a complete solution for converting WCS content to Godot while preserving gameplay fidelity and enabling modern development workflows.