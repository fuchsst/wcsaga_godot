shader_type spatial;
render_mode unshaded, cull_front; // Render inside of sphere, unlit

uniform sampler2D star_texture : hint_default_white; // Optional texture for star shapes/colors
uniform float density : hint_range(0.0, 1.0) = 0.97; // Density threshold for stars
uniform float size : hint_range(0.0, 0.1) = 0.005; // Max size of stars
uniform float twinkle_speed : hint_range(0.0, 10.0) = 1.0;
uniform vec3 parallax_scale = vec3(0.1, 0.1, 0.1); // How much stars shift with camera movement

// Simple pseudo-random number generator
float rand(vec2 co){
	return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

// Noise function (simple hash)
float noise(vec3 x) {
	vec3 p = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f); // Smoothstep
	vec2 uv = (p.xy + vec2(37.0, 17.0) * p.z) + f.xy;
	vec2 rg = textureLod(INSTANCE_CUSTOM, (uv + 0.5) / 256.0, 0.0).yx; // Using INSTANCE_CUSTOM as noise texture source - replace if needed
	return mix(rg.x, rg.y, f.z);
	// Alternative if no noise texture: return rand(uv);
}


void fragment() {
	// Use VERTEX for direction in world space from origin (center of sphere)
	vec3 direction = normalize(VERTEX);

	// Apply parallax shift based on camera position relative to origin
	// Assumes camera moves relative to a fixed starfield origin
	vec3 parallax_direction = direction + (CAMERA_POSITION_WORLD * parallax_scale);
	parallax_direction = normalize(parallax_direction);

	// Generate noise based on direction
	// Increase frequency for smaller stars, use multiple layers for variation
	float n = noise(parallax_direction * 500.0); // Base layer
	float n2 = noise(parallax_direction * 1500.0); // Finer detail layer

	// Combine noise layers and apply density threshold
	float star_value = pow(n * n2, 2.0); // Enhance contrast

	if (star_value > density) {
		// Star exists here
		float star_intensity = (star_value - density) / (1.0 - density); // Intensity based on how much it exceeds threshold

		// Twinkling effect
		float twinkle = rand(direction.xy + TIME * twinkle_speed);
		star_intensity *= mix(0.5, 1.0, twinkle); // Modulate intensity

		// Calculate star size based on intensity (brighter stars are bigger)
		float star_size = star_intensity * size;

		// Use a simple point-like shape (optional: use star_texture)
		// This part needs refinement for better star shapes.
		// A common technique is using UVs relative to the star center,
		// but that's complex without geometry shaders or instancing.
		// Simple approach: just output color if star_value is high enough.
		vec3 star_color = vec3(1.0, 1.0, 0.95); // Slightly yellowish white

		// Output final color
		ALBEDO = star_color * star_intensity;
		ALPHA = 1.0; // Stars are opaque

	} else {
		// Empty space
		ALBEDO = vec3(0.0);
		ALPHA = 1.0; // Background is opaque black
	}
}
