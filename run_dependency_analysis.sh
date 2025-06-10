#!/bin/bash

# This script runs the GDScript dependency analyzer from within the 'target' directory.
#
# It analyzes the project located in the current directory ('.') and generates
# a dependency report and a visual graph.
#
# The following directories are excluded from the analysis by default:
# - addons: To ignore third-party plugins.
# - tests: To ignore test-related scripts.
#
# You can modify the --exclude list to add or remove directories.

echo "Running GDScript dependency analysis..."
echo "Excluding imported addons"

python ./.util-scripts/gdscript_dependency_analyzer.py --project . --exclude addons/gdUnit4 addons/godot_mcp addons/limboai addons/scene_manager addons/SignalVisualizer .util-scripts

echo "Analysis complete. Report saved to target/reports/dependency_report.txt"
