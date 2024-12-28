# Migration Tools

This directory contains tools for analyzing and migrating the Wing Commander Saga C++ project to Godot.

## Project Analyzer

The `project_analyzer.py` script analyzes C++ source files and generates two types of output:
1. A complete file structure of the project
2. Detailed analysis of C++ code (classes, functions, etc.) organized by folder

### Setup

1. Install libclang development files:
```bash
# Ubuntu/Debian
sudo apt-get install libclang-dev

# Windows
# Download and install LLVM from https://releases.llvm.org/
```

2. Install Python dependencies:
```bash
pip install -r requirements.txt
```

### Usage

```bash
# Generate JSON analysis files
python project_analyzer.py /path/to/cpp/project --output-dir analysis_results
# For more detailed logging:
python project_analyzer.py /path/to/cpp/project --output-dir analysis_results --debug

# Convert analysis to markdown
python analysis_formatter.py analysis_results --output-dir analysis_markdown

# Start MCP server
python analysis_mcp_server.py analysis_results --host localhost --port 5000
```

## Analysis Output

### 1. JSON Analysis Files

The project analyzer creates an output directory containing:

1. `file_structure.json` - Complete project structure:
```json
{
  "name": "project_root",
  "type": "dir",
  "path": ".",
  "children": [
    {
      "name": "src",
      "type": "dir",
      "path": "src",
      "children": [
        {
          "name": "main.cpp",
          "type": "file",
          "path": "src/main.cpp"
        }
      ]
    }
  ]
}
```

2. Per-folder analysis files (`analysis_foldername.json`):
```json
{
  "folder": "src/engine",
  "files": [
    {
      "path": "src/engine/game.cpp",
      "classes": [
        {
          "name": "GameEngine",
          "functions": [
            {
              "name": "initialize",
              "return_type": "bool",
              "parameters": ["Config*"],
              "access": "public",
              "is_virtual": false,
              "is_static": false,
              "is_const": false
            }
          ],
          "base_classes": ["Engine"]
        }
      ],
      "global_functions": [
        {
          "name": "initializeSystem",
          "return_type": "void",
          "parameters": [],
          "access": "public",
          "is_virtual": false,
          "is_static": false,
          "is_const": false
        }
      ]
    }
  ]
}
```

### 2. Markdown Analysis Files

The analysis formatter creates one markdown file per top-level folder with a clean, hierarchical representation:

```markdown
# engine

## Directory Structure

📁 engine
  📄 game.cpp
  📄 system.cpp
  📁 core
    📄 base.hpp
    📄 config.cpp

## Code Structure

## 📄 engine/game.cpp

### Classes
class GameEngine : Engine
Functions:
- bool initialize(Config*)
- private void cleanup()

### Global Functions
- void initializeSystem()
```

## MCP Server

The `analysis_mcp_server.py` provides a REST API for querying the analysis data. It supports both JSON and markdown output formats.

### API Endpoints

POST `/` with JSON body:

1. Get Project Structure
```json
{
  "command": "get_project_structure"
}
```

2. Get Folder Files
```json
{
  "command": "get_folder_files",
  "params": {
    "folder": "src/engine"
  }
}
```

3. Get File Info
```json
{
  "command": "get_file_info",
  "params": {
    "file_path": "src/engine/game.cpp"
  }
}
```

4. Get Class Info
```json
{
  "command": "get_class_info",
  "params": {
    "file_path": "src/engine/game.cpp",
    "class_name": "GameEngine"
  }
}
```

5. Get Function Info
```json
{
  "command": "get_function_info",
  "params": {
    "file_path": "src/engine/game.cpp",
    "class_name": "GameEngine",
    "function_name": "initialize"
  }
}
```

6. Search Symbols
```json
{
  "command": "search_symbol",
  "params": {
    "query": "initialize"
  }
}
```

7. Batch Operations
```json
{
  "command": "batch",
  "params": {
    "requests": [
      {"command": "get_file_info", "params": {"file_path": "src/engine/game.cpp"}},
      {"command": "get_class_info", "params": {"file_path": "src/engine/game.cpp", "class_name": "GameEngine"}}
    ]
  }
}
```

### Output Formats

Add `"format": "markdown"` to params to get markdown-formatted output:

```json
{
  "command": "get_class_info",
  "params": {
    "file_path": "src/engine/game.cpp",
    "class_name": "GameEngine",
    "format": "markdown"
  }
}
```

This format is optimized for:
1. Quick understanding of project structure
2. Easy navigation of code elements
3. Efficient input for LLM analysis
4. Integration with other tools via the MCP server
