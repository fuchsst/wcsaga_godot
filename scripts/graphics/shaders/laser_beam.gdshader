shader_type spatial;
render_mode unshaded, blend_add, cull_disabled; // Unlit, additive blending, double-sided

uniform vec4 beam_color : source_color = vec4(1.0, 0.8, 0.5, 1.0); // Default orange-ish beam
uniform float intensity : hint_range(0.0, 10.0) = 2.0;
uniform sampler2D beam_texture : hint_default_white, filter_linear, repeat_enable; // Texture for beam pattern/noise
uniform float texture_scroll_speed = 1.0;
uniform float noise_scale = 5.0;
uniform float noise_intensity = 0.1;

// Simple noise function (replace with a better one if needed)
float rand(vec2 co){
	return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}
float simple_noise(vec2 uv) {
	return rand(floor(uv));
}

void fragment() {
	// UV coordinates are assumed to be set up on the beam mesh (e.g., 0-1 along the length)
	vec2 scrolled_uv = UV;
	scrolled_uv.x += TIME * texture_scroll_speed; // Scroll texture along the beam length

	// Sample the beam texture
	vec4 tex_color = texture(beam_texture, scrolled_uv);

	// Add some noise for variation/flicker
	float noise_val = simple_noise(UV * noise_scale + TIME * texture_scroll_speed * 0.5);
	float noise_effect = (noise_val * 2.0 - 1.0) * noise_intensity; // Centered noise

	// Combine texture, color, noise, and intensity
	vec3 final_color = beam_color.rgb * tex_color.rgb * (1.0 + noise_effect) * intensity;

	// Output color and alpha (use texture alpha or beam alpha)
	ALBEDO = final_color;
	ALPHA = tex_color.a * beam_color.a; // Blend based on texture and uniform alpha
}
