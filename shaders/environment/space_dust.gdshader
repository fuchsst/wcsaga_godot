shader_type spatial;
render_mode additive, vertex_lighting, shadows_disabled, depth_draw_opaque;

uniform float dust_density : hint_range(0.0, 2.0) = 1.0;
uniform vec3 dust_color : source_color = vec3(0.8, 0.7, 0.6);
uniform float drift_speed : hint_range(0.0, 5.0) = 1.0;
uniform float particle_size : hint_range(0.1, 2.0) = 1.0;
uniform float twinkle_rate : hint_range(0.0, 10.0) = 3.0;
uniform sampler2D particle_texture : source_color;

varying vec3 world_position;
varying vec2 particle_uv;
varying float particle_brightness;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    particle_uv = UV;
    
    // Individual particle brightness variation
    particle_brightness = 0.5 + 0.5 * sin(TIME * twinkle_rate + world_position.x * 10.0);
}

void fragment() {
    // Sample particle texture
    vec4 particle_sample = texture(particle_texture, particle_uv);
    
    // Distance from particle center
    vec2 center_offset = particle_uv - vec2(0.5);
    float distance_from_center = length(center_offset) * 2.0;
    
    // Particle falloff
    float particle_falloff = 1.0 - smoothstep(0.0, particle_size, distance_from_center);
    
    // Dust mote intensity
    float dust_intensity = particle_sample.r * particle_falloff * dust_density;
    dust_intensity *= particle_brightness;
    
    // Motion blur effect for fast-moving dust
    float motion_blur = 1.0 - min(1.0, length(velocity) * 0.1);
    dust_intensity *= motion_blur;
    
    // Atmospheric perspective - distant dust is dimmer
    float view_distance = length(CAMERA_POSITION_WORLD - world_position);
    float distance_dim = exp(-view_distance * 0.0001);
    dust_intensity *= distance_dim;
    
    // Subtle color variation
    vec3 warm_dust = dust_color * vec3(1.2, 1.0, 0.8);
    vec3 cool_dust = dust_color * vec3(0.8, 0.9, 1.2);
    vec3 final_color = mix(cool_dust, warm_dust, particle_sample.g);
    
    ALBEDO = final_color;
    EMISSION = final_color * dust_intensity * 0.5;
    ALPHA = dust_intensity;
}