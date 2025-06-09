# Assets Directory

## Purpose
This directory contains all game assets, such as 3D models, textures, audio files, and UI elements. The structure is designed to be intuitive and scalable for a Wing Commander-style space combat game, with a focus on campaign-based organization and shared resources.

## Asset Folder Structure

- **`common/`**: Contains assets shared across all campaigns and parts of the game.
  - **`audio/`**: Globally used sound effects and music.
    - **`sfx/`**: `explosion_small.ogg`, `shield_impact.ogg`
    - **`ui_feedback/`**: `button_click.ogg`, `menu_swoosh.ogg`
  - **`fonts/`**: `main_font.ttf`, `hud_font.otf`
  - **`icons/`**: `target_reticle.png`, `missile_lock_icon.svg`
  - **`materials/`**: `standard_hull_metal.material`, `glass_canopy.material`
  - **`effects/`**: Reusable particle effects and shaders.
    - **`explosions/`**: `small_ship_explosion.tscn`
    - **`muzzle_flashes/`**: `laser_cannon_flash.tscn`

- **`campaigns/`**: Contains all assets and data specific to a single campaign.
  - **`wing_commander_saga/`**: An example campaign folder.
    - **`ships/`**: All ship assets, organized by faction and class.
      - **`terran/`**
        - **`fighters/`**
          - **`hornet/`**: `hornet.glb`, `hornet_albedo.png`, `hornet_normal.png`, `ship_configuration.tres`
          - **`rapier/`**: `rapier.glb`, `rapier_albedo.png`, `ship_configuration.tres`
        - **`capital_ships/`**
          - **`bengal_carrier/`**: `bengal_carrier.glb`, `bengal_carrier_textureset_a.png`
      - **`kilrathi/`**
        - **`fighters/`**
          - **`dralthi/`**: `dralthi.glb`, `dralthi_albedo.png`
        - **`capital_ships/`**
          - **`fralthi_cruiser/`**: `fralthi_cruiser.glb`
    - **`weapons/`**: Campaign-specific weapon assets.
      - **`laser_cannon/`**: `laser_bolt_red.tscn`, `laser_fire.ogg`
      - **`image_recon_missile/`**: `ir_missile.glb`, `ir_missile_trail.tscn`
    - **`environments/`**:
      - **`enigma_sector/`**: `enigma_nebula.tscn`, `enigma_skybox.png`
    - **`missions/`**:
      - **`e01m01/`**: `mission_data.json`, `briefing_text.txt`, `briefing_map.png`
    - **`cutscenes/`**:
      - **`intro/`**: `intro_video.ogv`, `admiral_tolwyn_vo.ogg`
    - **`ui/`**:
      - **`hud/`**: `terran_hud_layout.tscn`, `terran_target_box.png`
    - **`audio/`**:
      - **`music/`**: `enigma_sector_combat.ogg`
      - **`voice/`**: `terran_pilot_vo_set/`
    - **`campaign_data.tres`**: A resource defining the campaign's mission progression.

## Key Guidelines
- Use descriptive, `snake_case` filenames (e.g., `terran_fighter_albedo.png`).
- Prefer `.glb` for 3D models to keep mesh and material data bundled.
- A campaign should be self-contained. If an asset is needed in more than one campaign, it should be moved to the `common/` directory.
