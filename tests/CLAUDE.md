# Tests Directory

## Purpose
Unit tests and validation for WCS-Godot systems using GdUnit4.

## Structure
- **Core manager tests**: Autoload functionality validation
- **Asset pipeline tests**: Asset loading and conversion
- **Mission data tests**: Mission validation framework
- **Configuration tests**: Settings and preferences

## Key Guidelines
- Use GdUnit4 framework: `addons/gdUnit4/`
- Test file naming: `test_*.gd`
- Run tests: `bash addons/gdUnit4/runtest.sh -a tests/`
- Static typing required in all test files
- Follow the same subdirectory structure as in the `scripts` folder

## Test Categories
- **Unit Tests**: Individual component testing
- **Integration Tests**: System interaction testing
- **Performance Tests**: Load and memory validation
- **Validation Tests**: Asset and data integrity

## Implementation Notes
- Tests verify EPIC architecture compliance
- Asset tests use addon structure paths
- Manager tests verify initialization order
- Comprehensive validation framework included