shader_type canvas_item;

uniform float blur_strength : hint_range(0.0, 1.0) = 0.1;
uniform int blur_samples : hint_range(1, 32) = 16;
uniform vec2 motion_vector : hint_range(-1.0, 1.0) = vec2(0.0, 0.0);
uniform sampler2D screen_texture : source_color, hint_screen_texture;

void fragment() {
    vec3 final_color = vec3(0.0);
    
    // Calculate motion blur by sampling along motion vector
    for (int i = 0; i < blur_samples; i++) {
        float offset = float(i) / float(blur_samples - 1) - 0.5;
        vec2 sample_uv = SCREEN_UV + motion_vector * blur_strength * offset;
        
        // Clamp UV coordinates to screen bounds
        sample_uv = clamp(sample_uv, vec2(0.0), vec2(1.0));
        
        vec3 sample_color = texture(screen_texture, sample_uv).rgb;
        final_color += sample_color;
    }
    
    final_color /= float(blur_samples);
    
    COLOR = vec4(final_color, 1.0);
}