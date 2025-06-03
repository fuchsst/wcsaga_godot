shader_type spatial;
render_mode additive, vertex_lighting, shadows_disabled, depth_draw_opaque;

uniform float plasma_intensity : hint_range(0.0, 10.0) = 3.0;
uniform vec3 plasma_color : source_color = vec3(0.0, 1.0, 0.5);
uniform float energy_core_size : hint_range(0.1, 1.0) = 0.6;
uniform float plasma_flicker : hint_range(0.0, 1.0) = 0.3;
uniform float pulse_speed : hint_range(0.0, 20.0) = 10.0;
uniform sampler2D noise_texture : source_color;

varying vec3 world_position;
varying vec2 local_uv;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    local_uv = UV;
}

void fragment() {
    // Calculate distance from center for spherical falloff
    vec2 center_uv = local_uv - vec2(0.5);
    float distance_from_center = length(center_uv) * 2.0;
    
    // Core energy field
    float core_intensity = 1.0 - smoothstep(0.0, energy_core_size, distance_from_center);
    
    // Outer plasma field
    float plasma_field = 1.0 - smoothstep(energy_core_size, 1.0, distance_from_center);
    
    // Time-based effects
    float time_factor = TIME * pulse_speed;
    vec4 noise = texture(noise_texture, local_uv + vec2(sin(time_factor * 0.3), cos(time_factor * 0.2)) * 0.1);
    
    // Plasma flickering
    float flicker = 1.0 - (plasma_flicker * (1.0 - noise.r));
    
    // Energy pulsing
    float pulse = sin(time_factor) * 0.3 + 0.7;
    
    // Combine effects
    float final_intensity = (core_intensity * 2.0 + plasma_field) * plasma_intensity * flicker * pulse;
    
    // Add energy corona
    float corona = pow(1.0 - distance_from_center, 3.0) * 0.5;
    
    ALBEDO = plasma_color;
    EMISSION = plasma_color * (final_intensity + corona);
    ALPHA = plasma_field;
}