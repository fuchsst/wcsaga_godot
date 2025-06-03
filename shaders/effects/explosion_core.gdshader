shader_type spatial;
render_mode additive, vertex_lighting, shadows_disabled, depth_draw_opaque;

uniform float explosion_intensity : hint_range(0.0, 10.0) = 5.0;
uniform float explosion_scale : hint_range(0.1, 5.0) = 1.0;
uniform vec3 explosion_color : source_color = vec3(1.0, 0.5, 0.0);
uniform float time_factor : hint_range(0.0, 2.0) = 0.0;
uniform sampler2D noise_texture : source_color;
uniform sampler2D fire_texture : source_color;

varying vec3 world_position;
varying vec2 explosion_uv;
varying float radial_distance;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    explosion_uv = UV;
    
    // Calculate distance from center for spherical explosion
    vec2 center_offset = UV - vec2(0.5);
    radial_distance = length(center_offset) * 2.0;
}

void fragment() {
    // Expanding explosion front
    float explosion_front = 1.0 - smoothstep(0.0, time_factor * explosion_scale, radial_distance);
    
    // Fireball core
    float core_intensity = 1.0 - smoothstep(0.0, 0.4, radial_distance);
    
    // Turbulent fire pattern
    vec2 fire_uv = explosion_uv + vec2(sin(TIME * 3.0), cos(TIME * 2.0)) * 0.1;
    vec4 fire_pattern = texture(fire_texture, fire_uv * 2.0);
    
    // Noise for explosion turbulence
    vec2 noise_uv = explosion_uv + vec2(TIME * 0.5, TIME * 0.3);
    vec4 turbulence = texture(noise_texture, noise_uv * 3.0);
    
    // Explosion stages
    float initial_flash = exp(-time_factor * 10.0); // Bright initial flash
    float fireball_stage = smoothstep(0.0, 0.5, time_factor) * (1.0 - smoothstep(0.5, 1.5, time_factor));
    float dissipation = 1.0 - smoothstep(1.0, 2.0, time_factor);
    
    // Combine patterns
    float explosion_pattern = fire_pattern.r * turbulence.r;
    float final_intensity = explosion_intensity * explosion_front * explosion_pattern;
    
    // Stage-based intensity
    final_intensity *= (initial_flash * 3.0 + fireball_stage * 2.0 + dissipation);
    
    // Core enhancement
    final_intensity += core_intensity * explosion_intensity * 0.5;
    
    // Color evolution during explosion
    vec3 flash_color = vec3(1.0, 1.0, 0.8); // Bright white-yellow flash
    vec3 fire_color = explosion_color; // Orange fire
    vec3 smoke_color = vec3(0.3, 0.2, 0.1); // Dark smoke
    
    vec3 stage_color;
    if (time_factor < 0.2) {
        stage_color = mix(flash_color, fire_color, time_factor * 5.0);
    } else if (time_factor < 1.0) {
        stage_color = fire_color;
    } else {
        stage_color = mix(fire_color, smoke_color, (time_factor - 1.0));
    }
    
    ALBEDO = stage_color;
    EMISSION = stage_color * final_intensity;
    ALPHA = final_intensity * 0.9;
}