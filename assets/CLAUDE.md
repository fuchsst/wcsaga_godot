# Assets Directory

## Purpose
This directory contains all game assets, such as 3D models, textures, audio files, and UI elements. The structure is designed to be intuitive and scalable for a Wing Commander-style space combat game, with a focus on campaign-based organization and shared resources.

## Asset Folder Structure

- **`common/`**: Contains assets shared across all campaigns and parts of the game.
  - **`audio/`**: Globally used sound effects and music.
    - **`sfx/`**: Common sound effects (e.g., explosions, generic alerts).
    - **`ui_feedback/`**: Sounds for button clicks, menu navigation, etc.
  - **`fonts/`**: Standard font files (`.ttf`, `.otf`).
  - **`icons/`**: Shared UI icons for generic actions or symbols.
  - **`materials/`**: A library of reusable base materials (e.g., standard metal, glass, thruster plasma).
  - **`effects/`**: Common particle effects and shaders (e.g., standard explosions, muzzle flashes).

- **`campaigns/`**: Contains all assets and data specific to a single campaign. Each campaign is a self-contained unit.
  - **`wing_commander_saga/`**: An example campaign folder.
    - **`ships/`**: Models, textures, and cockpit assets for ships appearing in this campaign.
    - **`weapons/`**: Projectiles, effects, and audio for campaign-specific weapons.
    - **`environments/`**: Skyboxes, asteroids, and nebulas unique to this campaign's missions.
    - **`missions/`**: Data files (`.json`, `.tres`) defining mission objectives, ship layouts, and events.
    - **`cutscenes/`**: Videos, animations, and audio for campaign-specific cinematics.
    - **`ui/`**: HUD elements, briefing screens, or UI themes specific to this campaign.
    - **`audio/`**: Voiceovers, music tracks, and sound effects exclusive to this campaign.
    - **`campaign_data.tres`**: A custom resource defining the campaign's mission progression and story flow.
  - **`another_campaign/`**: A placeholder for a future campaign, following the same structure.

- **`ui/`**: Contains assets for global UI elements that are not part of a specific campaign.
  - **`main_menu/`**: Assets for the main menu scene.
  - **`options_screen/`**: Assets for the settings and options menus.
  - **`themes/`**: Global `Theme` resources for a consistent UI look and feel.

## Key Guidelines
- Use descriptive, `snake_case` filenames (e.g., `terran_fighter_albedo.png`).
- Prefer `.glb` for 3D models to keep mesh and material data bundled.
- A campaign should be self-contained. If an asset is needed in more than one campaign, it should be moved to the `common/` directory.
