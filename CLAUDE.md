Godot Version of Wing Commander Saga converted from C++

Main directories:
* addons/gfred2: Mission Editor (Godot Plugin)
* addons/sepx: S-Expression Engine
* addons/wcs_asst_core: Core structures of assets, like global constants, resource definitions, asset loader and utilties
* addons/wcs_sonverter: Godot addon to import legacy file formats
* each of the above addons should have a tests folder with gdUnit4 tests (`extends GdUnitTestSuite`)
* assets: Target folder of imported assets like images, videaos, audio and 3D models
* autoload: Godot classes/scripts (singletons) laded at startup
* conversion_tools: Godot and Python scripts to convert legacy FS2/WCS game assets (models, tables, mission and campaign files, legacy video and image formats) to Godot compatible assets (use `target\conversion_tools\run_script.sh` to run a Python script and `target\conversion_tools\run_tests.sh` to run Python tests)
* resources: Folder for Godot resource files (.tres) that store game data like mission files, ship parameter etc. (based on the data structures define in addons/wcs_asst_core)
* scenes: Godot scenes that define the UI, composed objects and other game elements
* scripts: The folder for the Godot script game logic (used in scenes and other scripts)
* shaders: Custom shaders to replicate specific WCS effects
* tests: gdUnit4 test suites to test the scripts and scenes (use `target\addons\gdUnit4\runtest.sh` to run the tests)