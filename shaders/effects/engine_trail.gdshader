shader_type spatial;
render_mode additive, vertex_lighting, shadows_disabled, depth_draw_opaque;

uniform float trail_intensity : hint_range(0.0, 5.0) = 2.0;
uniform vec3 trail_color : source_color = vec3(0.0, 0.7, 1.0);
uniform float scroll_speed : hint_range(0.0, 10.0) = 2.0;
uniform float flicker_rate : hint_range(0.0, 20.0) = 8.0;
uniform float turbulence : hint_range(0.0, 1.0) = 0.3;
uniform sampler2D noise_texture : source_color;

varying vec3 world_position;
varying vec2 trail_uv;
varying float trail_width;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    trail_uv = UV;
    
    // Trail gets wider towards the back
    trail_width = 1.0 - abs(UV.y - 0.5) * 2.0;
}

void fragment() {
    // Scrolling effect for particle movement
    float time_factor = TIME * scroll_speed;
    vec2 scrolling_uv = trail_uv + vec2(0.0, -time_factor);
    
    // Sample noise for turbulence
    vec4 noise1 = texture(noise_texture, scrolling_uv * 2.0);
    vec4 noise2 = texture(noise_texture, scrolling_uv * 4.0 + vec2(0.5));
    
    // Combine noise patterns
    float turbulence_effect = mix(noise1.r, noise2.r, 0.5);
    
    // Engine flicker
    float flicker = sin(TIME * flicker_rate + trail_uv.x * 10.0) * 0.2 + 0.8;
    
    // Trail intensity based on position
    float length_factor = pow(1.0 - trail_uv.x, 2.0); // Stronger at engine, weaker at tip
    float width_factor = trail_width;
    
    // Apply turbulence to width
    width_factor *= (1.0 + turbulence_effect * turbulence);
    
    // Core engine glow
    float core_glow = exp(-pow(abs(trail_uv.y - 0.5) * 4.0, 2.0));
    core_glow *= length_factor;
    
    // Outer trail
    float outer_trail = width_factor * length_factor * turbulence_effect;
    
    // Combine effects
    float final_intensity = trail_intensity * flicker * (core_glow * 2.0 + outer_trail);
    
    // Color variation based on intensity
    vec3 hot_core = trail_color * 1.5; // Brighter core
    vec3 cool_outer = trail_color * 0.7; // Dimmer outer
    vec3 final_color = mix(cool_outer, hot_core, core_glow);
    
    ALBEDO = final_color;
    EMISSION = final_color * final_intensity;
    ALPHA = final_intensity * 0.8;
}