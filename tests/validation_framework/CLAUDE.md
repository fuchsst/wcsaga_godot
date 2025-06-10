# Validation Framework Directory

## Purpose
Comprehensive validation system for WCS-Godot asset integrity and quality assurance.

## Structure
- **comprehensive_validation_manager.gd**: Main validation orchestrator
- **asset_integrity_validator.gd**: Asset file validation
- **visual_fidelity_validator.gd**: Visual quality validation
- **validation_report_generator.gd**: Report generation
- **comprehensive_validator.py**: Python validation tools

## Key Guidelines
- Validates all converted WCS assets
- Ensures addon structure compliance
- Generates detailed validation reports
- Integrates with EPIC-003 conversion pipeline

## Validation Types
- **Asset Integrity**: File format and structure validation
- **Visual Fidelity**: Texture and model quality checks
- **System Integration**: Manager and autoload validation
- **Performance**: Memory and loading time validation

## Implementation Notes
- Framework validates EPIC architecture compliance
- Python tools for batch validation operations
- Godot tools for runtime validation
- Comprehensive reporting for quality assurance

## Run Tests
- Use `bash addons/gdUnit4/runtest.sh -a tests/` for Godot Tests
- Use `venv/Scripts/python.exe -m pytest` for Python Tests