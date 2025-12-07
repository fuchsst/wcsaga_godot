shader_type canvas_item;

// Grid parameters
uniform vec4 grid_color : source_color = vec4(0.3, 0.5, 0.7, 0.3);
uniform float grid_size = 50.0;
uniform float line_thickness = 1.0;

void fragment() {
	// Calculate grid position
	vec2 grid_pos = UV * grid_size;

	// Create grid lines using fract
	vec2 grid_line = fract(grid_pos);

	// Check if we're near a grid line (within line_thickness)
	float line_x = step(grid_line.x, line_thickness / grid_size) + step(1.0 - grid_line.x, line_thickness / grid_size);
	float line_y = step(grid_line.y, line_thickness / grid_size) + step(1.0 - grid_line.y, line_thickness / grid_size);

	// Combine X and Y grid lines
	float grid_mask = max(line_x, line_y);

	// Apply grid color
	COLOR = grid_color * grid_mask;
}
