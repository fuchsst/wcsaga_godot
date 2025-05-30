# GFRED2 Mission Editor - Agent Guidance

## Package Purpose
Modern FRED2-style mission editor as Godot plugin integrating WCS asset management (EPIC-002) and SEXP systems (EPIC-004). Provides visual mission creation with scene-based UI architecture.

## Architecture Reference
- **Main Architecture**: `.ai/docs/epic-005-gfred2-mission-editor/architecture.md`
- **Dependencies**: `.ai/docs/epic-005-gfred2-mission-editor/godot-dependencies.md`
- **File Structure**: `.ai/docs/epic-005-gfred2-mission-editor/godot-files.md`

## Core Integration Points

### EPIC-002 Asset Integration
```gdscript
# Direct asset access - no wrappers
var ship_data: ShipData = WCSAssetLoader.load_asset(ship_path)
var assets: Array[String] = WCSAssetRegistry.get_asset_paths_by_type(AssetTypes.Type.SHIP)
```

### EPIC-004 SEXP Integration  
```gdscript
# Direct SEXP system access
var is_valid: bool = SexpManager.validate_syntax(expression)
var errors: Array[String] = SexpManager.get_validation_errors(expression)
```

## Critical Architecture Rules (NON-NEGOTIABLE)

### Scene-Based UI Only
- **ALL UI components MUST be scenes (.tscn files)**
- **NO programmatic UI construction allowed**
- **Scripts attach to scene root nodes as controllers**
- See Architecture Section 3 for mandatory patterns

### Folder Organization (Post-GFRED2-011)
```
addons/gfred2/
├── scenes/           # ALL UI scenes centralized here
│   ├── docks/        # Editor dock scenes  
│   ├── dialogs/      # Modal dialog scenes
│   ├── components/   # Reusable UI components
│   └── overlays/     # Viewport overlays
├── scripts/          # Logic-only scripts (no UI construction)
├── core/            # Mission data management
├── integration/     # System integration points  
└── tests/           # gdUnit4 test suites
```

### Performance Requirements
- Scene instantiation: < 16ms per component
- UI updates: Batched at 60 FPS
- Real-time validation: < 5ms for standard expressions
- Mission handling: 100+ SEXP expressions at >60 FPS

## Integration Architecture

### Mission Data Flow
```gdscript
# Mission loading with EPIC-004 validation
func load_mission_data(mission_data: MissionData):
    for event in mission_data.events:
        if event.condition_sexp:
            var is_valid: bool = SexpManager.validate_syntax(event.condition_sexp)
            if not is_valid:
                _report_validation_errors(SexpManager.get_validation_errors(event.condition_sexp))
```

### Asset Browser Integration
```gdscript
# Direct EPIC-002 asset browsing
func populate_asset_browser():
    var ship_paths: Array[String] = WCSAssetRegistry.get_asset_paths_by_type(AssetTypes.Type.SHIP)
    for ship_path in ship_paths:
        var ship_data: ShipData = WCSAssetLoader.load_asset(ship_path)
        asset_browser.add_asset_item(ship_data.ship_name, ship_path)
```

## Key Components

### VisualSexpEditor
**Purpose**: Scene-based SEXP editor with EPIC-004 integration  
**Scene**: `scenes/components/sexp_tree_panel.tscn`  
**Performance**: Real-time validation <5ms, 400+ function support

### MissionEditorDock  
**Purpose**: Main editing interface scene  
**Scene**: `scenes/docks/main_editor_dock.tscn`  
**Features**: 3D viewport, object hierarchy, property editing

### AssetBrowserDock
**Purpose**: Asset browsing scene using EPIC-002 system  
**Scene**: `scenes/docks/asset_browser_dock.tscn`  
**Integration**: Direct WCSAssetRegistry access

## Testing Strategy

### Direct Integration Tests
```gdscript
func test_epic004_integration():
    # Verify direct SEXP system access
    assert_not_null(sexp_editor.sexp_manager)
    var is_valid = SexpManager.validate_syntax("(+ 1 2)")
    assert_true(is_valid)

func test_epic002_integration():
    # Verify direct asset system access
    var assets = WCSAssetRegistry.get_asset_paths_by_type(AssetTypes.Type.SHIP)
    assert_true(assets.size() > 0)
```

### Run Tests
```bash
# From target directory
bash addons/gdUnit4/runtest.sh -a addons/gfred2/tests/
```

## Common Patterns

### Scene Controller Pattern
```gdscript
# scene_controller.gd (attached to scene root)
class_name SceneController
extends Control

@onready var child_component: ChildType = $ChildPath
signal component_action(data: Dictionary)

func _ready() -> void:
    _setup_ui_connections()
    _initialize_component_state()
```

### Signal-Based Communication
```gdscript
# Loose coupling between components
signal mission_object_selected(object: MissionObject)
signal validation_status_changed(is_valid: bool, errors: Array[String])
```

## Implementation Notes

### Direct System Access
- Use core systems directly (no wrapper layers)
- Leverage existing EPIC-001 utilities, EPIC-002 assets, EPIC-004 SEXP
- Follow Godot scene composition patterns
- Maintain performance requirements throughout

### Scene Migration (GFRED2-011)
When refactoring existing programmatic UI:
1. Create scene file first
2. Attach script to scene root as controller
3. Use scene composition for complex components
4. Delete programmatic UI construction code
5. Test functionality preservation

**Critical**: Follow Architecture Section 3 for scene-based patterns and performance requirements.