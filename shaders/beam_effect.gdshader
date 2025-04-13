shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always; // Unshaded, double-sided, always draw

// Uniforms to control the beam's appearance and position
uniform vec3 start_point = vec3(0.0, 0.0, 0.0); // World space start
uniform vec3 end_point = vec3(0.0, 0.0, -10.0); // World space end
uniform float beam_width : hint_range(0.01, 100.0) = 1.0;
uniform vec4 beam_color : source_color = vec4(1.0, 0.5, 0.2, 1.0); // Orange-ish default
uniform sampler2D beam_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float texture_scroll_speed : hint_range(0.0, 10.0) = 1.0;
uniform float intensity : hint_range(0.0, 1.0) = 1.0; // For fading

varying vec2 uv_interp;
varying float distance_along_beam; // 0.0 at start, 1.0 at end

void vertex() {
	// Calculate beam direction and length
	vec3 beam_vector = end_point - start_point;
	float beam_length = length(beam_vector);
	vec3 beam_dir = beam_vector / max(beam_length, 0.0001); // Avoid division by zero

	// Calculate camera-facing basis vectors
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - start_point); // Direction from beam start to camera
	vec3 right_vec = normalize(cross(beam_dir, view_dir));
	vec3 up_vec = normalize(cross(right_vec, beam_dir)); // Re-orthogonalize

	// Determine vertex position based on UV
	// UV.x = 0 => start, UV.x = 1 => end
	// UV.y = 0 => bottom edge, UV.y = 1 => top edge
	float half_width = beam_width * 0.5;
	vec3 local_pos = beam_dir * UV.x * beam_length; // Position along the beam center
	local_pos += right_vec * (UV.y - 0.5) * 2.0 * half_width; // Offset sideways

	// World position
	vec3 world_pos = start_point + local_pos;

	// Set output position
	POSITION = world_pos;

	// Pass UV and distance to fragment shader
	uv_interp = UV;
	distance_along_beam = UV.x; // Simple mapping for now
}

void fragment() {
	// Scroll texture based on time and distance
	vec2 scrolled_uv = uv_interp;
	scrolled_uv.x += TIME * texture_scroll_speed;

	// Sample texture
	vec4 tex_color = texture(beam_texture, scrolled_uv);

	// Combine texture, beam color, and intensity
	ALBEDO = tex_color.rgb * beam_color.rgb;
	ALPHA = tex_color.a * beam_color.a * intensity;

	// Optional: Fade alpha towards the end of the beam
	// ALPHA *= (1.0 - distance_along_beam);
}
