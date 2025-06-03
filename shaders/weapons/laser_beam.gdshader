shader_type spatial;
render_mode additive, vertex_lighting, shadows_disabled, depth_draw_opaque;

uniform float beam_intensity : hint_range(0.0, 10.0) = 2.0;
uniform vec3 beam_color : source_color = vec3(1.0, 0.0, 0.0);
uniform float beam_width : hint_range(0.1, 2.0) = 1.0;
uniform float flicker_speed : hint_range(0.0, 10.0) = 5.0;
uniform sampler2D noise_texture : source_color;
uniform float energy_variation : hint_range(0.0, 1.0) = 0.2;

varying float distance_from_center;
varying vec2 beam_uv;

void vertex() {
    beam_uv = UV;
    
    // Calculate distance from beam center for intensity falloff
    distance_from_center = abs(UV.y - 0.5) * 2.0;
    
    VERTEX = VERTEX;
}

void fragment() {
    float time_factor = TIME * flicker_speed;
    vec4 noise = texture(noise_texture, beam_uv + vec2(time_factor * 0.1, 0.0));
    
    // Beam intensity falloff from center
    float intensity_falloff = 1.0 - pow(distance_from_center / beam_width, 2.0);
    intensity_falloff = max(0.0, intensity_falloff);
    
    // Add energy variation for realistic laser effect
    float energy_flicker = 1.0 - (energy_variation * (1.0 - noise.r));
    float final_intensity = beam_intensity * intensity_falloff * energy_flicker;
    
    // Pulsing effect along beam length
    float beam_pulse = sin(UV.x * 10.0 + time_factor) * 0.1 + 0.9;
    final_intensity *= beam_pulse;
    
    ALBEDO = beam_color;
    EMISSION = beam_color * final_intensity;
    ALPHA = intensity_falloff;
}