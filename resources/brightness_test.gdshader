shader_type canvas_item;

uniform float brightness = 1.0;

void fragment() {
    // Create a checkerboard pattern
    vec2 uv = UV * 5.0; // Reduced scale for larger squares
    vec2 grid = floor(uv);
    float checker = mod(grid.x + grid.y, 2.0);
    
    // Base color (alternating dark gray and white for better contrast)
    vec3 color = mix(vec3(0.3), vec3(1.0), checker);
    
    // Apply brightness
    color *= brightness;
    
    COLOR = vec4(color, 1.0);
}
