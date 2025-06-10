#!/bin/bash

# This script runs a Python module located within the 'conversion_tools' directory or its subdirectories,
# using the virtual environment in 'target/venv'.

# Determine the script's directory and the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)" # Moves up two level from conversion_tools to target
PROJECT_ROOT_DIR="$(cd "$TARGET_DIR/.." && pwd)" # Moves up one level from target to project root
VENV_PATH="$TARGET_DIR/venv"

# Check if a Python module name is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <python_module_to_run> [args...]"
  echo "Example: $0 pof_parser.cli --input my_file.pof"
  exit 1
fi

PYTHON_MODULE=$1
shift # Remove the module name from the arguments list, so $@ contains only args for the python script

# Activate virtual environment
# Check for Windows-style venv activation (Git Bash, etc.)
if [ -f "$VENV_PATH/Scripts/activate" ]; then
  # shellcheck disable=SC1091
  source "$VENV_PATH/Scripts/activate"
# Check for Unix-style venv activation (WSL, Linux, macOS)
elif [ -f "$VENV_PATH/bin/activate" ]; then
  # shellcheck disable=SC1091
  source "$VENV_PATH/bin/activate"
else
  echo "Error: Virtual environment activation script not found at $VENV_PATH/Scripts/activate or $VENV_PATH/bin/activate"
  exit 1
fi

echo "Running python -m $PYTHON_MODULE $@"
# Execute the Python module, passing all remaining arguments
# Run from the project root so relative paths in python scripts work as expected from project root
# Use correct Python executable path based on platform
if [ -f "$VENV_PATH/Scripts/python.exe" ]; then
  PYTHON_EXE="$VENV_PATH/Scripts/python.exe"
elif [ -f "$VENV_PATH/bin/python" ]; then
  PYTHON_EXE="$VENV_PATH/bin/python"
else
  echo "Error: Python executable not found in virtual environment"
  exit 1
fi

# Convert relative --source and --output to absolute paths
args=()
while (( "$#" )); do
  case "$1" in
    --source|--output)
      args+=("$1")
      shift
      # Use realpath to resolve the path
      args+=("$(realpath "$1")")
      shift
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

(cd "$SCRIPT_DIR" && "$PYTHON_EXE" -m "$PYTHON_MODULE" "${args[@]}")

# Deactivate virtual environment (optional, as script exits, but good practice)
deactivate
