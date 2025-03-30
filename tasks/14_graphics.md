# Wing Commander Saga: Godot Conversion Analysis - 14 Graphics

This document analyzes the graphics rendering components of the original Wing Commander Saga C++ codebase (`graphics/` and `render/` directories) and outlines a strategy for implementing equivalent functionality in Godot.

## 1. Identify Key Features

The original graphics system handles a wide range of functionalities:

*   **Core Rendering Pipeline:** Setting up view and projection matrices, managing OpenGL state (textures, blending, depth testing, culling, fog, lighting), handling extensions.
*   **2D Drawing:** Rendering bitmaps, anti-aliased bitmaps, text (fonts), lines, circles, gradients, rectangles, UI elements.
*   **3D Drawing:** Rendering textured/untextured polygons, lines, spheres, lasers, beams, rotated billboards (bitmaps), perspective bitmaps (for backgrounds).
*   **Texture Management:** Loading, caching (tcache), handling various formats (DDS, TGA, PNG, JPG, PCX), mipmapping, texture compression (S3TC), render-to-texture (FBOs), texture addressing modes (wrap, clamp, mirror), anisotropic filtering.
*   **Lighting:** Handling directional, point, and tube lights; managing active lights; ambient lighting; specular highlights; emissive materials.
*   **Shaders:** A custom shader system combining vertex and fragment shaders based on material properties (diffuse, glow, spec, normal, height, env maps, fog). Includes main model shaders and post-processing shaders.
*   **Post-Processing:** Effects like bloom, potentially depth of field, and other screen-space effects managed via a post-processing pipeline.
*   **Vertex Buffers (VBOs/TNL):** Managing vertex data, normals, UVs, tangents in buffers for efficient rendering. Includes instancing support.
*   **Clipping:** Frustum culling and user-defined clip planes.
*   **Coordinate Systems:** Handling screen coordinates, world coordinates, view coordinates, and transformations between them.
*   **Font Rendering:** Loading custom font formats (.fnt) and rendering text.
*   **Color & Palette:** Managing current drawing color, alpha blending modes, clear color, gamma correction. (Palette system is largely obsolete in a high-color engine like Godot).
*   **Screen Management:** Flipping buffers, clearing the screen, saving/restoring screen contents, handling screen resolution and aspect ratio.
*   **Special Effects:** Nebulae, starfields (likely handled here or closely related), particle systems (though potentially separate).

## 2. List Potential Godot Solutions

Godot offers native solutions for most of these features:

*   **Core Rendering Pipeline:** Managed by `RenderingServer`, `Camera3D`, `Viewport`. OpenGL state is abstracted via Materials and Shaders. Extensions are handled internally.
*   **2D Drawing:** `CanvasLayer` for UI/HUD, `Control` nodes (`TextureRect`, `Label`, `Panel`), `_draw()` with `draw_*` methods, `Sprite2D`.
*   **3D Drawing:** `MeshInstance3D` with various `Mesh` types (`PlaneMesh`, `SphereMesh`, `BoxMesh`, `ArrayMesh`, `ImmediateMesh`), `GPUParticles3D`, `Sprite3D`. Lasers/beams might use `ImmediateMesh`, custom `ArrayMesh`, or potentially `RibbonTrailMesh`/`TubeTrailMesh`.
*   **Texture Management:** Godot's resource system handles loading, caching, and format conversion (via import settings). `Texture2D`, `Texture3D`, `CompressedTexture2D`, `ImageTexture`, `ViewportTexture`. Mipmaps and anisotropic filtering are import settings. Render-to-texture uses `SubViewport`. Addressing modes are material properties (`BaseMaterial3D.texture_filter`, `ShaderMaterial` uniforms).
*   **Lighting:** `DirectionalLight3D`, `OmniLight3D`, `SpotLight3D`. Ambient/environment lighting via `WorldEnvironment`. Specular highlights controlled by `Material` properties (metallic, roughness, specular). Emissive materials via `BaseMaterial3D.emission_enabled`.
*   **Shaders:** `ShaderMaterial` using Godot Shading Language (`.gdshader`). Replaces the custom C++ shader system entirely. Material properties (albedo, glow, metallic, roughness, normal, height, AO, emission) are handled via shader uniforms and textures. Fog is typically a shader effect or `WorldEnvironment` setting.
*   **Post-Processing:** `WorldEnvironment` node (Glow/Bloom, SSAO, SSR, SDFGI, Tonemapping). Custom effects via screen-space shaders on `Camera3D` or `Viewport`.
*   **Vertex Buffers (VBOs/TNL):** Handled internally by Godot. Geometry defined via `Mesh` resources (`ArrayMesh`, `SurfaceTool`). Instancing via `MultiMeshInstance3D`.
*   **Clipping:** Frustum culling is automatic via `Camera3D`. User clip planes can be implemented via custom shaders if needed.
*   **Coordinate Systems:** Managed by Godot's `Node3D` transforms and `Camera3D` projection. Methods like `project_position`, `unproject_position` are available.
*   **Font Rendering:** `FontFile`, `DynamicFont`, `Label` node, `RichTextLabel`, `Theme`. Import `.ttf`/`.otf` directly. Custom `.fnt` likely needs a converter or custom loader.
*   **Color & Palette:** `Color` struct. Alpha blending via `Material.transparency` or shader logic. Clear color via `Camera3D` or `WorldEnvironment`. Gamma via `ProjectSettings` or `WorldEnvironment`. Palettes are obsolete.
*   **Screen Management:** Handled by Godot's main loop and `DisplayServer`. Buffer flipping is automatic. Clearing via `Camera3D` background or `WorldEnvironment`. Saving screen via `Viewport.get_texture().get_image()`. Resolution/aspect via `ProjectSettings` and `Viewport`.
*   **Special Effects:** Nebula/Starfield via shaders (`Sky`, `PanoramaSkyMaterial`, custom shaders). Particles via `GPUParticles3D`.

## 3. Outline Target Code Structure

```
scripts/graphics/
├── graphics_utilities.gd   # Helper functions for graphics tasks (if needed).
├── post_processing.gd      # Script attached to Camera3D/Viewport for custom PP effects.
└── shaders/                # Directory for .gdshader files
    ├── model_base.gdshader     # Base shader for ships/objects, handling lighting, textures.
    ├── nebula.gdshader         # Shader for rendering nebula effects.
    ├── starfield.gdshader      # Shader for rendering the starfield background.
    ├── bloom_pp.gdshader       # Custom bloom/glow post-processing shader (if needed beyond WorldEnvironment).
    ├── laser_beam.gdshader     # Shader for laser/beam effects.
    └── particle.gdshader       # Custom particle shaders (if needed).
scenes/effects/             # Scenes for particle effects, explosions, etc.
├── explosion.tscn
├── laser_hit.tscn
└── beam_effect.tscn        # Scene for beam weapon visuals.
resources/graphics/         # Graphics-related resources
├── materials/              # Pre-configured materials (.material files).
│   ├── ship_hull.material
│   └── cockpit_glass.material
├── themes/                 # UI themes (.theme files).
│   └── hud_theme.tres
└── environment/            # WorldEnvironment resources (.tres).
    ├── space_default.tres
    └── nebula_env.tres
scenes/core/
└── skybox.tscn             # Scene containing the starfield/nebula setup (using Sky).
```

## 4. Identify Important Methods, Classes, and Data Structures

*   **`graphics/2d.cpp/.h`:**
    *   `gr_screen`: Global struct holding screen state. Map to `DisplayServer`, `ProjectSettings`, `Viewport`.
    *   `gr_init`, `gr_close`: Map to Godot project initialization/cleanup (handled by engine).
    *   `gr_flip`: Automatic in Godot's main loop.
    *   `gr_set_clip`, `gr_reset_clip`: `Viewport` properties, `Camera3D` culling, potentially `CanvasItem.clip_children`.
    *   `gr_clear`: `Camera3D` background settings or `clear()` method if drawing manually.
    *   `gr_bitmap`, `gr_bitmap_ex`: `TextureRect` (UI), `Sprite2D` (2D scene), `Sprite3D` (3D scene), or textured `PlaneMesh`.
    *   `gr_aabitmap`, `gr_aabitmap_ex`: Similar to `gr_bitmap`, potentially using specific texture filtering (`Texture.FLAG_FILTER`). Anti-aliasing is a project setting or handled by MSAA/FXAA/TAA.
    *   `gr_string`, `gr_printf`: `Label`, `RichTextLabel`.
    *   `gr_line`, `gr_aaline`, `gr_circle`, `gr_rect`, `gr_shade`: `_draw()` methods in `Control` or `Node2D`, or `ImmediateMesh` in 3D.
    *   `gr_set_color`, `gr_init_color`, `gr_init_alphacolor`: Setting `modulate` property or using Godot `Color`.
    *   `gr_set_bitmap`: Setting the `texture` property of relevant nodes (`TextureRect`, `Sprite*`, `MeshInstance3D` material).
    *   `gr_set_font`: Setting `theme_override_fonts` or `font` property on `Label`/`RichTextLabel`.
    *   `poly_list`: Represents vertex data. Map to `PackedVector3Array`, `PackedVector2Array`, `PackedColorArray` used by `ArrayMesh` or `SurfaceTool`.
*   **`graphics/font.cpp/.h`:**
    *   `font`: Struct holding font data. Godot uses `FontFile` or `DynamicFont` resources. A converter for `.fnt` might be needed.
    *   `gr_create_font`, `gr_font_init`: Handled by Godot's resource loading.
    *   `gr_get_string_size`: `Label.get_minimum_size()`, `Font.get_string_size()`.
*   **`graphics/gropengl.cpp/.h`, `graphics/gropenglstate.cpp/.h`:**
    *   OpenGL initialization (`gr_opengl_init`, `opengl_init_display_device`): Handled by Godot engine startup based on project settings (rendering method).
    *   OpenGL state functions (`GL_state.*`, `glEnable`, `glDisable`, `glBlendFunc`, etc.): Abstracted by Godot's `RenderingServer`, `Material` properties, and shader logic. Direct OpenGL calls are generally avoided.
    *   `gr_opengl_flip`, `gr_opengl_clear`: Handled by Godot main loop and `Camera3D`/`WorldEnvironment`.
    *   `gr_opengl_set_clip`, `gr_opengl_reset_clip`: `Viewport` properties, `Camera3D` culling.
    *   `gr_opengl_zbuffer_*`: `Material.depth_draw_mode`, `Material.depth_test`. Z-clearing is automatic or via `Camera3D` background.
    *   `gr_opengl_fog_set`: `WorldEnvironment.fog_enabled`, `fog_density`, `fog_color`, or custom fog shader.
    *   `gr_opengl_set_cull`: `BaseMaterial3D.cull_mode`.
*   **`graphics/gropengltexture.cpp/.h`, `graphics/gropenglbmpman.cpp/.h`:**
    *   `tcache_slot_opengl`: Represents a texture in VRAM. Godot handles this via `Texture2D` resources and internal caching.
    *   `opengl_tcache_init`, `opengl_tcache_flush`, `opengl_tcache_shutdown`: Handled by Godot's resource management.
    *   `gr_opengl_tcache_set`: Setting `texture` properties on materials or nodes.
    *   `opengl_create_texture`, `opengl_create_texture_sub`: Handled by Godot's texture import process.
    *   `opengl_make_render_target`, `opengl_set_render_target`: `SubViewport` node and `ViewportTexture` resource.
    *   Texture addressing/filtering functions: Material properties (`BaseMaterial3D.texture_filter`, `texture_repeat`) or shader uniforms.
*   **`graphics/gropengllight.cpp/.h`:**
    *   `opengl_light`: Struct holding light properties. Map to `DirectionalLight3D`, `OmniLight3D`, `SpotLight3D` properties.
    *   `gr_opengl_make_light`, `gr_opengl_modify_light`, `gr_opengl_destroy_light`: Creating, modifying, and deleting Light3D nodes.
    *   `gr_opengl_set_light`: Adding Light3D nodes to the scene tree.
    *   `gr_opengl_reset_lighting`: Removing/disabling Light3D nodes.
    *   `gr_opengl_set_lighting`: Enabling/disabling lighting via `WorldEnvironment` or globally.
    *   `gr_opengl_set_ambient_light`: Setting `WorldEnvironment.ambient_light_color`.
*   **`graphics/gropenglshader.cpp/.h`:**
    *   `opengl::shader`, `opengl::main_shader`, `opengl::post_shader`, `opengl::special_shader`: Replaced by Godot `ShaderMaterial` and `.gdshader` files.
    *   `opengl::shader_manager`: Replaced by Godot's shader compilation and caching system.
    *   Shader flags (`SDR_FLAG_*`): Replaced by shader `uniform` variables and conditional logic (`if`/`#ifdef`) within `.gdshader` files. Texture presence checked via uniforms.
*   **`graphics/gropenglpostprocessing.cpp/.h`:**
    *   `opengl::post_processing`, `opengl::bloom`, `opengl::simple_effects`: Replaced by `WorldEnvironment` node settings (glow/bloom) and custom screen-space shaders attached to `Camera3D` or `Viewport`.
    *   `gr_opengl_post_process_*` functions: Map to enabling/disabling `WorldEnvironment` effects or managing custom post-processing shader scripts.
*   **`graphics/gropengltnl.cpp/.h`:**
    *   VBO functions (`gr_opengl_make_buffer`, `gr_opengl_render_buffer`, `gr_opengl_set_buffer`): Handled internally by Godot when rendering `MeshInstance3D`. Geometry is built using `ArrayMesh` or `SurfaceTool`.
    *   Instancing functions (`gr_opengl_start_instance_matrix`, etc.): Setting `Node3D.transform`. For large numbers, use `MultiMeshInstance3D`.
    *   Matrix stack (`glPushMatrix`, `glPopMatrix`): Handled by Godot's scene graph transforms.
    *   View/Projection setup (`gr_opengl_set_projection_matrix`, `gr_opengl_set_view_matrix`): Setting `Camera3D` properties (`fov`, `near`, `far`, `transform`).
*   **`render/3d*.cpp/.h`:**
    *   `g3_start_frame`, `g3_end_frame`: Implicit in Godot's `_process` or `_physics_process`.
    *   `g3_set_view_matrix`, `g3_set_view_angles`: Setting `Camera3D.transform` and properties.
    *   `g3_start_instance_matrix`, `g3_done_instance`: Setting `Node3D.transform`.
    *   `g3_rotate_vertex`, `g3_project_vertex`: Handled internally by Godot's renderer.
    *   `g3_draw_poly`, `g3_draw_poly_constant_sw`: Creating/drawing `MeshInstance3D` with `ArrayMesh`.
    *   `g3_draw_bitmap`, `g3_draw_rotated_bitmap`: `Sprite3D` or textured `PlaneMesh`.
    *   `g3_draw_sphere`, `g3_draw_sphere_ez`: `MeshInstance3D` with `SphereMesh`.
    *   `g3_draw_laser`, `g3_draw_rod`: Custom mesh generation (`ImmediateMesh`, `ArrayMesh`) or particle systems (`GPUParticles3D`).
    *   Clipping functions (`clip_polygon`, `clip_line`, `g3_start_user_clip_plane`): Automatic frustum culling. User clipping via custom shaders if necessary.
    *   `Frustum`: `Camera3D` provides `is_position_in_frustum`.

## 5. Identify Relations

*   **Core Dependency:** The Graphics/Render system is fundamental and used by almost every other system to display visuals.
*   **Model System:** Provides the geometry data (`vertex`, `vec3d`, normals, UVs) that the graphics system renders.
*   **Ship/Weapon Systems:** Call graphics functions to draw ships, weapons, projectiles, and effects (explosions, lasers). Relies on instancing and transformations.
*   **HUD System:** Uses 2D drawing functions (bitmaps, text, lines, shapes) to render the interface.
*   **Mission System:** May trigger specific graphical effects, set up environments (nebula, lighting).
*   **Core Systems:** Manages the main loop which calls rendering functions, handles camera setup.
*   **Lighting System:** Provides light data used by the 3D rendering pipeline and shaders.
*   **Effects (Particles, Nebula, Starfield):** These are specialized rendering tasks often integrated within the main graphics pipeline or using dedicated subsystems/shaders.

**Conversion Notes:**

*   The biggest shift is moving from direct OpenGL calls and state management to Godot's higher-level abstractions (Nodes, Scenes, Materials, Shaders, RenderingServer).
*   The custom C++ shader system needs complete replacement with Godot's shader language. Shader logic will need to be ported, likely simplified by using built-in material properties where possible.
*   Texture loading and caching are handled by Godot's resource system. The `tcache` logic is replaced.
*   VBO management is handled internally by Godot. Focus shifts to creating `Mesh` resources correctly.
*   Post-processing will primarily use `WorldEnvironment` and potentially custom screen-space shaders.
*   2D drawing for the HUD will use Godot's Control nodes.
*   The fixed-function pipeline aspects (like `glTexEnv`) are replaced by shader logic.
