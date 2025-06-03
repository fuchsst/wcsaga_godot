shader_type canvas_item;

uniform float bloom_threshold : hint_range(0.0, 2.0) = 1.0;
uniform float bloom_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float bloom_radius : hint_range(0.1, 10.0) = 2.0;
uniform sampler2D screen_texture : source_color, hint_screen_texture;

vec3 sample_bloom(vec2 uv, float radius) {
    vec3 bloom_color = vec3(0.0);
    float total_weight = 0.0;
    
    // Gaussian blur for bloom effect
    for (float x = -radius; x <= radius; x += 1.0) {
        for (float y = -radius; y <= radius; y += 1.0) {
            vec2 offset = vec2(x, y) * TEXTURE_PIXEL_SIZE;
            float weight = exp(-(x*x + y*y) / (radius * radius));
            
            vec3 sample_color = texture(screen_texture, uv + offset).rgb;
            
            // Only include bright pixels in bloom
            float brightness = dot(sample_color, vec3(0.299, 0.587, 0.114));
            if (brightness > bloom_threshold) {
                bloom_color += sample_color * weight;
                total_weight += weight;
            }
        }
    }
    
    return bloom_color / max(total_weight, 0.001);
}

void fragment() {
    vec3 original_color = texture(screen_texture, SCREEN_UV).rgb;
    
    // Calculate bloom contribution
    vec3 bloom_color = sample_bloom(SCREEN_UV, bloom_radius);
    
    // Combine original with bloom
    vec3 final_color = original_color + bloom_color * bloom_intensity;
    
    COLOR = vec4(final_color, 1.0);
}