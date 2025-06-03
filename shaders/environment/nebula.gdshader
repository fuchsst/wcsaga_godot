shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, depth_test_disabled;

uniform float nebula_density : hint_range(0.0, 2.0) = 1.0;
uniform vec3 nebula_color_1 : source_color = vec3(0.5, 0.2, 0.8);
uniform vec3 nebula_color_2 : source_color = vec3(0.2, 0.5, 1.0);
uniform vec3 nebula_color_3 : source_color = vec3(1.0, 0.3, 0.4);
uniform float drift_speed : hint_range(0.0, 2.0) = 0.5;
uniform float turbulence_scale : hint_range(0.1, 5.0) = 1.0;
uniform sampler2D noise_texture_1 : source_color;
uniform sampler2D noise_texture_2 : source_color;

varying vec3 world_position;
varying vec2 nebula_uv;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    nebula_uv = UV;
}

void fragment() {
    // Multiple layers of drifting nebula
    float time_drift = TIME * drift_speed;
    
    // Layer 1 - Main nebula structure
    vec2 drift_uv_1 = nebula_uv + vec2(time_drift * 0.1, time_drift * 0.05);
    vec4 noise_1 = texture(noise_texture_1, drift_uv_1 * turbulence_scale);
    
    // Layer 2 - Secondary wisps
    vec2 drift_uv_2 = nebula_uv + vec2(-time_drift * 0.07, time_drift * 0.12);
    vec4 noise_2 = texture(noise_texture_2, drift_uv_2 * turbulence_scale * 0.7);
    
    // Layer 3 - Fine details
    vec2 drift_uv_3 = nebula_uv + vec2(time_drift * 0.15, -time_drift * 0.08);
    vec4 noise_3 = texture(noise_texture_1, drift_uv_3 * turbulence_scale * 2.0);
    
    // Combine noise layers
    float nebula_layer_1 = noise_1.r;
    float nebula_layer_2 = noise_2.r * 0.7;
    float nebula_layer_3 = noise_3.r * 0.4;
    
    // Create density variation
    float total_density = (nebula_layer_1 + nebula_layer_2 + nebula_layer_3) * nebula_density;
    total_density = pow(total_density, 1.5); // Enhance contrast
    
    // Color mixing based on density layers
    vec3 color_mix_1 = mix(nebula_color_1, nebula_color_2, noise_1.g);
    vec3 color_mix_2 = mix(color_mix_1, nebula_color_3, noise_2.g * 0.5);
    
    // Distance-based fading for depth
    float view_distance = length(CAMERA_POSITION_WORLD - world_position);
    float distance_fade = 1.0 - exp(-view_distance * 0.001);
    
    // Final nebula visibility
    float nebula_alpha = total_density * distance_fade;
    nebula_alpha = clamp(nebula_alpha, 0.0, 0.8); // Prevent full opacity
    
    // Add subtle internal glow
    float internal_glow = pow(total_density, 2.0) * 0.3;
    
    ALBEDO = color_mix_2;
    EMISSION = color_mix_2 * internal_glow;
    ALPHA = nebula_alpha;
}