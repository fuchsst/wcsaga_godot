# Main Menu Scene Structure

This document describes the scene structure for `main_menu.tscn` that should be created in Godot editor.

## Scene Tree Structure

```
MainMenu (Control) - Script: main_menu_controller.gd
├── BackgroundContainer (Control)
│   ├── BackgroundImage (TextureRect)
│   │   └── AnimatedBackground (AnimationPlayer)
│   └── OverlayEffects (Control)
├── MenuOptionsContainer (VBoxContainer)
│   ├── PilotManagementButton (Button)
│   ├── CampaignButton (Button)
│   ├── ReadyRoomButton (Button)
│   ├── TechRoomButton (Button)
│   ├── OptionsButton (Button)
│   ├── CreditsButton (Button)
│   └── ExitButton (Button)
├── NavigationPanel (Control)
│   ├── TitleLabel (Label)
│   ├── StatusLabel (Label)
│   └── VersionLabel (Label)
├── StatusDisplay (Control)
│   ├── PerformanceMonitor (Label)
│   └── ConnectionStatus (Label)
├── MainHallAudio (Node)
│   ├── AmbientPlayer (AudioStreamPlayer)
│   ├── EffectsPlayer (AudioStreamPlayer)
│   └── MusicPlayer (AudioStreamPlayer)
└── TransitionEffects (Control)
    ├── FadeOverlay (ColorRect)
    └── TransitionAnimation (AnimationPlayer)
```

## Node Configuration

### MainMenu (Control)
- **Script**: `main_menu_controller.gd`
- **Layout**: Full screen anchoring
- **Mouse Filter**: Pass (to allow button interaction)

### BackgroundContainer (Control)
- **Layout**: Full screen anchoring
- **Mouse Filter**: Ignore (background only)

### BackgroundImage (TextureRect)
- **Texture**: Main hall background image from WCS assets
- **Stretch Mode**: Keep Aspect Centered
- **Layout**: Full screen

### MenuOptionsContainer (VBoxContainer)
- **Layout**: Center-left positioning
- **Separation**: 20 pixels
- **Alignment**: Center

### Menu Buttons
All buttons should have:
- **Custom Minimum Size**: (200, 50)
- **Theme**: WCS-style button theme
- **Text**: Appropriate labels ("Pilot Management", "Campaign", etc.)
- **Focus Mode**: All (for keyboard navigation)

### NavigationPanel (Control)
- **Layout**: Top-right corner
- **Contains**: Title, status, and version information

### MainHallAudio (Node)
- **Purpose**: Audio management for main menu
- **Components**: Ambient sounds, button effects, background music

### TransitionEffects (Control)
- **Layout**: Full screen overlay
- **Purpose**: Manage visual transitions between scenes
- **Initially**: Hidden/transparent

## Required Resources

### Textures
- Main hall background image
- Button normal/pressed/hover states
- UI overlay elements

### Audio
- Ambient main hall sounds
- Button hover/click effects
- Background music

### Themes
- Button theme with WCS styling
- Label themes for consistent typography

## Signals to Connect in Editor

### Button Connections
Each button's `pressed` signal should be connected via the script, not in the editor, for better maintainability.

### Animation Connections
- `AnimationPlayer.animation_finished` for background animations
- `TransitionAnimation.animation_finished` for scene transitions

## Implementation Notes

1. Create this scene structure in Godot editor
2. Assign the `main_menu_controller.gd` script to the root node
3. Configure layouts and anchoring as described
4. Import WCS assets for textures and audio
5. Test button functionality and transitions
6. Ensure performance targets are met (60fps, <100ms transitions)

## Testing Checklist

- [ ] All buttons respond to mouse clicks
- [ ] Keyboard navigation works (arrow keys, enter, escape)
- [ ] Audio plays correctly (ambient, effects, music)
- [ ] Background displays properly
- [ ] Transitions work smoothly
- [ ] Performance targets are met
- [ ] Integration with GameStateManager functions
- [ ] Integration with SceneManager for transitions