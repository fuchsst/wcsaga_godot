shader_type canvas_item;

// Line glow shader - creates a soft glowing effect for Line2D
// The line appears to have a blurred, glowing edge

uniform vec4 line_color : source_color = vec4(0.4, 0.7, 1.0, 0.8);
uniform vec4 glow_color : source_color = vec4(0.3, 0.6, 1.0, 0.6);
uniform float glow_amount : hint_range(0.0, 1.0) = 0.5;
uniform float glow_intensity : hint_range(0.5, 4.0) = 1.5;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Distance from center of line (UV.x = 0.5 is center for Line2D)
    float dist_from_center = abs(UV.x - 0.5) * 2.0;
    
    // Create soft glow falloff
    float glow_falloff = 1.0 - smoothstep(0.0, 1.0, dist_from_center);
    float outer_glow = smoothstep(0.3, 1.0, dist_from_center) * glow_amount;
    
    // Core line color
    vec3 core = line_color.rgb * tex_color.rgb;
    
    // Add glow around edges
    vec3 glow = glow_color.rgb * outer_glow * glow_intensity;
    
    // Combine with alpha falloff for soft edges
    float alpha = tex_color.a * glow_falloff;
    alpha = max(alpha, outer_glow * glow_color.a);
    
    COLOR.rgb = core + glow;
    COLOR.a = alpha * line_color.a;
}
