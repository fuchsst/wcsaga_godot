# WCS-Godot Conversion Tools

## Package Purpose

This package provides comprehensive asset conversion and organization tools for migrating Wing Commander Saga (WCS) assets to Godot Engine format. It implements the EPIC-003 architecture design for data migration and conversion tools.

## Original C++ Analysis

### Key WCS Source Files Analyzed
- **`source/code/cfile/cfilearchive.cpp`**: VP archive implementation and format specification
- **`source/code/cfile/cfilesystem.cpp`**: File system and archive management
- **`source/code/bmpman/bmpman.cpp`**: Bitmap/texture management and format handling
- **`source/code/model/modelread.cpp`**: POF model format parsing and loading
- **`source/code/mission/missionparse.cpp`**: Mission file format parsing

### WCS Architecture Insights
The analysis revealed **exceptionally clean architecture** with minimal dependencies:
- VP archive system is foundational but completely self-contained
- Image format utilities (5 formats) follow identical patterns - trivial to implement
- POF model parsing is complex but isolated in modelread.cpp
- Clean separation enables standalone conversion tools

## Key Classes

### ConversionManager
Main orchestrator for the entire WCS to Godot conversion pipeline.
- **Purpose**: Manages conversion jobs, dependencies, and parallel processing
- **Key Methods**: `scan_wcs_assets()`, `create_conversion_plan()`, `execute_conversion_plan()`
- **Architecture**: Follows EPIC-003 design with phase-based conversion (VP extraction → core assets → dependent assets)

### AssetCatalog
Comprehensive asset cataloging and organization system.
- **Purpose**: Creates searchable database of all converted assets with metadata and relationships
- **Key Methods**: `scan_directory()`, `validate_assets()`, `search_assets()`, `generate_manifest()`
- **Storage**: Dual storage (JSON + SQLite) for performance and compatibility

### FormatValidator
Lightweight validation system for converted assets.
- **Purpose**: Ensures conversion accuracy and format compliance
- **Key Methods**: `validate_file()`, `validate_directory()`, `generate_validation_report()`
- **Approach**: Format-specific validation with graceful degradation for missing dependencies

## Usage Examples

### Basic Conversion
```bash
# Convert all WCS assets to Godot format
run_script.sh convert_wcs_assets --source /path/to/wcs --target /path/to/godot/project

# Dry run to preview conversion plan
run_script.sh convert_wcs_assets --source /path/to/wcs --target /path/to/godot/project --dry-run

# Convert with validation
run_script.sh convert_wcs_assets --source /path/to/wcs --target /path/to/godot/project --validate

# Test mesh conversion
run_script.sh pof_parser.test_mesh_conversion

# Convert POF models to GLB format
run_script.sh pof_parser.cli convert ship.pof --output ship.glb --textures textures/
```

### Asset Cataloging
```bash
# Catalog existing converted assets
run_script.sh convert_wcs_assets --target /path/to/godot/project --catalog-only

# Search assets programmatically
run_script.sh asset_catalog search --query "fighter" --type "model"
```

### Validation Only
```bash
# Validate converted assets
run_script.sh asset_catalog validate --directory converted_assets/
```

## Architecture Notes

### EPIC-003 Compliance
The implementation strictly follows the EPIC-003 architecture:
- **Simplified Structure**: Based on clean WCS architecture analysis (25 files vs original 67 estimate)
- **Python-Based**: Standalone Python scripts with minimal dependencies
- **Parallel Development**: Independent converters enable simultaneous development
- **Godot Integration**: Minimal import plugins for seamless editor integration

### Directory Structure
```
conversion_tools/
├── convert_wcs_assets.py      # Main CLI interface
├── conversion_manager.py      # Conversion orchestrator
├── asset_catalog.py          # Asset cataloging system
├── vp_extractor.py           # VP archive extraction
├── config/                   # Configuration files
├── utilities/                # Helper utilities
├── validation/               # Validation systems
├── templates/               # Output templates
└── tests/                   # Test infrastructure
```

### Phase-Based Conversion
1. **Phase 1**: VP Archive Extraction (priority 1, sequential)
2. **Phase 2**: Core Assets (textures, models, audio - priority 2, parallel)
3. **Phase 3**: Dependent Assets (missions, tables - priority 3, parallel)

## C++ to Godot Mapping

### Asset Type Conversions
- **VP Archives** → Extracted directory structure with organized assets
- **POF Models** → GLB/GLTF with materials and animations
- **DDS/PCX/TGA Textures** → PNG with proper import settings
- **FS2 Mission Files** → .tres resources with converted SEXP scripts
- **TBL Data Files** → .tres resources following EPIC-002 asset structures
- **WAV/OGG Audio** → OGG with compression optimization

### Dependency Resolution
- VP extraction enables access to packed assets
- Texture conversion supports model material mapping
- Asset catalog maintains relationship integrity
- Validation ensures dependency completeness

## Integration Points

### EPIC-002 Asset Management
- Uses BaseAssetData structures for resource generation
- Integrates with WCSAssetRegistry for runtime discovery
- Follows EPIC-002 directory organization standards

### GFRED2 Mission Editor
- Provides converted assets for editor asset browser
- Maintains WCS compatibility for mission editing workflow
- Supports asset relationship preservation

### Godot Project Integration
- Creates proper .import files for seamless editor integration
- Updates project.godot settings for WCS asset paths
- Follows Godot best practices for asset organization

## Performance Considerations

### Parallel Processing
- Phase-based execution prevents dependency conflicts
- ThreadPoolExecutor for CPU-intensive conversions
- ProcessPoolExecutor for memory-intensive operations (future enhancement)

### Memory Management
- Streaming VP extraction for large archives
- Progressive asset cataloging to handle large datasets
- SQLite indexing for fast asset searches

### Scalability
- Designed to handle 1000+ assets efficiently
- Resume functionality for interrupted conversions (planned)
- Incremental cataloging for updated assets

## Testing Notes

### Unit Testing
- Test VP extraction with sample archives
- Validate format converters with known good assets
- Verify asset catalog accuracy with controlled datasets

### Integration Testing
- End-to-end conversion pipeline validation
- Asset catalog integration with EPIC-002 systems
- Godot project integration verification

### Performance Testing
- Large asset collection processing (500+ assets)
- Memory usage validation during conversion
- Parallel processing efficiency measurement

## Implementation Deviations

### Simplified vs Original Architecture
- **Reduced File Count**: 25 files vs 67 originally estimated (63% reduction)
- **Eliminated Complexity**: No complex dependency resolution pipelines needed
- **Direct Implementation**: WCS source provides exact algorithms
- **Minimal Dependencies**: Self-contained converters reduce external requirements

### Pragmatic Choices
- **JSON + SQLite**: Dual storage for performance and compatibility
- **Python-First**: Leverage existing Python ecosystem for file processing
- **Graceful Degradation**: Validation works without optional dependencies (PIL, etc.)
- **Progressive Enhancement**: Basic functionality first, advanced features as needed

---

**Implementation Status**: DM-001, DM-002, DM-003, and DM-005 completed following EPIC-003 architecture  
**Quality**: Production-ready with comprehensive error handling and validation  
**Performance**: Designed for efficiency with large WCS asset collections  
**Integration**: Seamless integration with EPIC-002 asset management and Godot workflow