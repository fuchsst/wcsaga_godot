shader_type spatial;
render_mode additive, vertex_lighting, shadows_disabled, depth_draw_opaque;

uniform float exhaust_intensity : hint_range(0.0, 5.0) = 2.0;
uniform vec3 trail_color : source_color = vec3(1.0, 0.5, 0.0);
uniform float heat_distortion : hint_range(0.0, 1.0) = 0.1;
uniform float particle_density : hint_range(0.0, 2.0) = 0.8;
uniform float scroll_speed : hint_range(0.0, 10.0) = 3.0;
uniform sampler2D noise_texture : source_color;

varying vec3 world_position;
varying vec2 trail_uv;
varying float trail_falloff;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    trail_uv = UV;
    
    // Calculate falloff along trail length (wider at back, narrower at front)
    trail_falloff = 1.0 - abs(UV.y - 0.5) * 2.0;
}

void fragment() {
    // Scrolling noise for particle movement
    float time_factor = TIME * scroll_speed;
    vec2 scrolling_uv = trail_uv + vec2(0.0, time_factor);
    vec4 noise = texture(noise_texture, scrolling_uv * particle_density);
    
    // Trail intensity based on position
    float length_factor = 1.0 - trail_uv.x; // Fade towards front
    float width_factor = trail_falloff;
    
    // Heat distortion effect
    float distortion = sin(trail_uv.y * 20.0 + time_factor * 5.0) * heat_distortion;
    vec2 distorted_uv = trail_uv + vec2(distortion, 0.0);
    vec4 distorted_noise = texture(noise_texture, distorted_uv * particle_density);
    
    // Combine noise patterns
    float particle_effect = mix(noise.r, distorted_noise.r, 0.5);
    
    // Calculate final intensity
    float final_intensity = exhaust_intensity * length_factor * width_factor * particle_effect;
    
    // Add heat glow
    float heat_glow = pow(width_factor, 2.0) * 0.5;
    
    // Color variation based on heat
    vec3 hot_color = trail_color * 1.5; // Brighter for hot areas
    vec3 cool_color = trail_color * 0.7; // Dimmer for cooler areas
    vec3 final_color = mix(cool_color, hot_color, particle_effect);
    
    ALBEDO = final_color;
    EMISSION = final_color * (final_intensity + heat_glow);
    ALPHA = final_intensity * 0.8;
}