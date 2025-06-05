# Tests Directory

## Purpose
Unit tests and validation for WCS-Godot systems using GdUnit4.

## Key Guidelines
- Use GdUnit4 framework: `addons/gdUnit4/`
- Follow the same subdirectory structure as the script being tested (do not use the epicname as filename)
- Test file naming: `test_*.gd`
- Run tests: `bash addons/gdUnit4/runtest.sh -a tests/`
- Static typing required in all test files

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

Read `TEST_STRUCTURE.md` before adding/editing tests.
Update `TEST_STRUCTURE.md` after adding/editing tests.