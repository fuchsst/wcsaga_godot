#!/bin/bash

# This script runs pytest within the 'conversion_tools' directory,
# using the virtual environment in 'target/venv'.

# Determine the script's directory and the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$(cd "$SCRIPT_DIR/.." && pwd)" # Moves up one level from conversion_tools to target
PROJECT_ROOT_DIR="$(cd "$TARGET_DIR/.." && pwd)" # Moves up one level from target to project root
VENV_PATH="$TARGET_DIR/venv"

# Default to running all tests if no specific test is provided
TEST_PATH=${1:-"tests/"}
shift # Remove the test path from arguments if provided

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

# Use correct Python executable path based on platform
if [ -f "$VENV_PATH/Scripts/python.exe" ]; then
  PYTHON_EXE="$VENV_PATH/Scripts/python.exe"
elif [ -f "$VENV_PATH/bin/python" ]; then
  PYTHON_EXE="$VENV_PATH/bin/python"
else
  echo "Error: Python executable not found in virtual environment"
  exit 1
fi

# Check if pytest is installed
if ! "$PYTHON_EXE" -c "import pytest" 2>/dev/null; then
  echo "Installing pytest..."
  "$PYTHON_EXE" -m pip install pytest
fi

echo "Running pytest $TEST_PATH $@"
# Execute pytest from the conversion_tools directory
(cd "$SCRIPT_DIR" && "$PYTHON_EXE" -m pytest "$TEST_PATH" "$@" -v)

# Deactivate virtual environment (optional, as script exits, but good practice)
deactivate