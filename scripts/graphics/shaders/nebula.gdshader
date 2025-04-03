shader_type spatial;
render_mode unshaded, cull_front, blend_add; // Render inside sphere, additive blending

uniform vec4 nebula_color_1 : source_color = vec4(0.1, 0.2, 0.4, 1.0);
uniform vec4 nebula_color_2 : source_color = vec4(0.3, 0.1, 0.3, 1.0);
uniform float density = 0.3;
uniform float falloff = 2.0; // Controls the sharpness of the cloud edges
uniform float scale = 1.0; // Overall scale of the noise pattern
uniform float speed = 0.02; // Speed at which the nebula evolves/moves
uniform float brightness = 1.0;
uniform vec3 parallax_scale = vec3(0.3, 0.3, 0.3); // Parallax effect for nebula

// Noise functions (can use Godot's built-in noise or custom ones)
// Using a simple pseudo-random for demonstration if no noise texture is set up
float rand(vec2 co){
	return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

// 3D Noise function (example using multiple rand calls - replace with better noise like Simplex/Perlin if possible)
float noise(vec3 x) {
	vec3 p = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f); // Smoothstep

	float n = p.x + p.y * 157.0 + 113.0 * p.z;
	return mix(mix(mix(rand(vec2(n)), rand(vec2(n + 1.0)), f.x),
				   mix(rand(vec2(n + 157.0)), rand(vec2(n + 158.0)), f.x), f.y),
			   mix(mix(rand(vec2(n + 113.0)), rand(vec2(n + 114.0)), f.x),
				   mix(rand(vec2(n + 270.0)), rand(vec2(n + 271.0)), f.x), f.y), f.z);
}

// Fractional Brownian Motion (FBM) for more detailed noise
float fbm(vec3 p) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 0.0;
	for (int i = 0; i < 4; i++) { // 4 octaves
		value += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	// Use VERTEX for direction in world space from origin
	vec3 direction = normalize(VERTEX);

	// Apply parallax shift based on camera position
	vec3 parallax_direction = direction + (CAMERA_POSITION_WORLD * parallax_scale);
	parallax_direction = normalize(parallax_direction);

	// Calculate noise value based on direction and time for evolution
	vec3 noise_coord = parallax_direction * scale + TIME * speed;
	float noise_value = fbm(noise_coord);

	// Add another layer of noise for color variation
	vec3 color_noise_coord = parallax_direction * scale * 0.5 + TIME * speed * 0.3;
	float color_noise = fbm(color_noise_coord);

	// Determine nebula intensity based on noise and density/falloff
	float intensity = pow(noise_value, falloff) * density;
	intensity = clamp(intensity, 0.0, 1.0);

	// Mix colors based on the second noise layer
	vec3 final_color = mix(nebula_color_1.rgb, nebula_color_2.rgb, clamp(color_noise * 2.0, 0.0, 1.0));

	// Apply intensity and brightness
	ALBEDO = final_color * intensity * brightness;
	ALPHA = intensity; // Use intensity for alpha blending
}
