// scripts/graphics/shaders/model_base.gdshader
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Uniforms to control features (mirroring SDR_FLAG_*)
uniform bool use_light = true;
uniform bool use_fog = false; // Fog handled by WorldEnvironment or custom shader logic
uniform bool use_diffuse_map = true;
uniform bool use_glow_map = false;
uniform bool use_specular_map = false;
uniform bool use_normal_map = false;
uniform bool use_height_map = false; // Parallax Occlusion Mapping
uniform bool use_env_map = false;

// Textures
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_emission : source_color, hint_default_black, filter_linear_mipmap, repeat_enable; // Glow map
uniform sampler2D texture_metallic_specular : hint_default_white, filter_linear_mipmap, repeat_enable; // Combined Metallic(R)/Roughness(G)/Specular(B) or just Specular(RGB)
uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_depth : hint_default_black, filter_linear_mipmap, repeat_enable; // Height map for POM
uniform samplerCUBE texture_sky : hint_default_black, filter_linear_mipmap; // Environment map

// Material Properties
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float emission_strength : hint_range(0.0, 16.0) = 1.0;
uniform vec3 emission_color : source_color = vec3(0.0, 0.0, 0.0); // Separate emission color if glow map isn't used directly for color
uniform float metallic : hint_range(0.0, 1.0) = 0.0; // Use if not using metallic map
uniform float roughness : hint_range(0.0, 1.0) = 0.5; // Use if not using roughness map
uniform float specular_intensity : hint_range(0.0, 1.0) = 0.5; // Use if not using specular map

// Parallax Mapping Properties
uniform float height_scale = 0.05;
uniform int min_layers = 8;
uniform int max_layers = 32;

// TODO: Add uniforms for other effects like alpha testing, cloak, etc. if needed

varying vec3 view_dir_tangent;
varying vec3 light_dir_tangent; // For one primary light, expand for multiple if needed
varying vec2 uv_offset;

// Function to calculate parallax offset
vec2 parallax_map_offset(sampler2D depth_texture, vec2 uv, vec3 view_dir) {
	float num_layers = mix(float(max_layers), float(min_layers), abs(dot(vec3(0.0, 0.0, 1.0), view_dir)));
	float layer_depth = 1.0 / num_layers;
	float current_layer_depth = 0.0;
	vec2 p = view_dir.xy * height_scale;
	vec2 delta = p / num_layers;
	vec2 current_uv = uv;
	float depth_from_tex = texture(depth_texture, current_uv).r;

	// Note: This loop condition should be '<=' to include the last layer check,
	// but Godot 4.x GLSL might have issues with non-constant loop conditions.
	// Using '<' is safer, though might slightly under-sample. Adjust if needed.
	// For robust POM, consider alternative implementations or Godot 4.3+ features if available.
	for (int i = 0; i < int(num_layers); i++) {
		current_layer_depth += layer_depth;
		current_uv -= delta;
		depth_from_tex = texture(depth_texture, current_uv).r;
		if (depth_from_tex < current_layer_depth) {
			// Parallax collision found - interpolate between current and previous layer
			vec2 prev_uv = current_uv + delta;
			float after_depth = depth_from_tex - current_layer_depth;
			float before_depth = texture(depth_texture, prev_uv).r - current_layer_depth + layer_depth;
			// Avoid division by zero or near-zero
			if (abs(after_depth - before_depth) < 0.001) {
				return prev_uv; // Return previous UV if depths are too close
			}
			float weight = after_depth / (after_depth - before_depth);
			// Clamp weight to avoid issues outside the 0-1 range
			weight = clamp(weight, 0.0, 1.0);
			return mix(current_uv, prev_uv, weight); // Interpolate UVs
		}
	}
	return current_uv; // Return last UV if no collision found within layers
}


void vertex() {
	if (use_normal_map) {
		// Ensure TANGENT and BINORMAL are valid before creating TBN
		// Godot usually generates these during import if enabled
		if (length(TANGENT) > 0.0 && length(BINORMAL) > 0.0) {
			vec3 normal = normalize(NORMAL);
			vec3 tangent = normalize(TANGENT);
			// Recalculate binormal for orthogonality if needed, though Godot's should be orthogonal
			vec3 binormal = normalize(cross(normal, tangent) * BINORMAL_SIGN);
			mat3 tbn = mat3(tangent, binormal, normal);

			// Transform view vector to tangent space
			// VIEW is view vector in view space, needs transform to tangent space
			// This calculation might need adjustment depending on coordinate spaces
			// A common way is: TBN * normalize(VERTEX - CAMERA_POSITION_WORLD)
			// Or simpler if VIEW is already world/model space relative to vertex:
			view_dir_tangent = normalize(VIEW * tbn); // Check if VIEW variable is appropriate here

			// Transform light vector to tangent space
			if (use_light) {
				// Example: Assuming LIGHT0_DIRECTION is available (needs setup in scene/environment)
				// light_dir_tangent = normalize(LIGHT0_DIRECTION * tbn);

				// Placeholder if LIGHT0 is not automatically available in this context
				light_dir_tangent = normalize(vec3(1.0, 1.0, 1.0) * tbn);
			}
		} else {
			// Fallback or error if TANGENT/BINORMAL are missing
			use_normal_map = false; // Disable normal mapping if TBN is invalid
		}
	}

	// Calculate parallax offset UVs in the vertex shader
	if (use_height_map && use_normal_map) { // Requires valid TBN
		// Calculate view direction in tangent space for parallax
		vec3 view_dir_world = normalize(CAMERA_POSITION_WORLD - VERTEX); // Vector from vertex to camera
		mat3 tbn = mat3(normalize(TANGENT), normalize(cross(NORMAL, TANGENT) * BINORMAL_SIGN), normalize(NORMAL));
		vec3 view_dir_tangent_calc = view_dir_world * tbn; // Transform world view dir to tangent space
		uv_offset = parallax_map_offset(texture_depth, UV, view_dir_tangent_calc);
	} else {
		uv_offset = UV; // Use original UVs if no height mapping
	}

	// Pass the calculated offset UV to the fragment shader
	UV = uv_offset; // Overwrite UV for fragment shader use (or use a separate varying)
}

void fragment() {
	// Use the UV passed from the vertex shader (which includes parallax offset if applied)
	vec2 final_uv = UV;

	// Albedo
	vec4 albedo_tex = texture(texture_albedo, final_uv);
	ALBEDO = albedo_tex.rgb * albedo_color.rgb;
	ALPHA = albedo_tex.a * albedo_color.a;

	// Normal Mapping
	if (use_normal_map) {
		vec3 normal_tex = texture(texture_normal, final_uv).rgb;
		NORMAL_MAP = normalize(normal_tex * 2.0 - 1.0);
		NORMAL_MAP_DEPTH = 1.0; // Adjust if needed
	}

	// Emission (Glow)
	if (use_glow_map) {
		vec3 emission_tex = texture(texture_emission, final_uv).rgb;
		EMISSION = emission_tex * emission_strength;
	} else {
		EMISSION = emission_color * emission_strength; // Use uniform color if no map
	}

	// Metallic/Roughness/Specular
	if (use_specular_map) {
		vec4 mrs_tex = texture(texture_metallic_specular, final_uv);
		// Assuming Metallic in R, Roughness in G, Specular Intensity in B
		// Adjust based on how textures are packed
		METALLIC = mrs_tex.r;
		ROUGHNESS = mrs_tex.g;
		SPECULAR = mrs_tex.b; // Or use specular_intensity uniform if B is not specular
	} else {
		METALLIC = metallic;
		ROUGHNESS = roughness;
		SPECULAR = specular_intensity;
	}

	// Environment Mapping (Reflection) - Basic implementation
	// Godot's standard material handles this better with Sky contribution
	// This is a simplified example if you need custom cube map reflections controlled by uniform
	if (use_env_map) {
		// NORMAL should be world normal here. If using NORMAL_MAP, it's already applied.
		// If not using NORMAL_MAP, transform NORMAL to world space.
		vec3 world_normal = normalize(inverse(transpose(mat3(MODEL_MATRIX))) * NORMAL); // Or use NORMAL_MAP if active
		vec3 view_vec_world = normalize(CAMERA_POSITION_WORLD - VERTEX); // Vector from vertex to camera
		vec3 reflect_vec = reflect(-view_vec_world, world_normal); // Reflect view vector
		vec4 env_color = texture(texture_sky, reflect_vec);

		// Mix reflection with albedo based on metallic/roughness or fresnel
		float fresnel = pow(1.0 - clamp(dot(world_normal, view_vec_world), 0.0, 1.0), 5.0);
		float reflection_mix = mix(0.04, 1.0, fresnel) * METALLIC; // Basic metallic workflow mix
		ALBEDO = mix(ALBEDO, env_color.rgb, reflection_mix);
	}

	// Lighting is handled implicitly by Godot's PBR pipeline when METALLIC, ROUGHNESS, SPECULAR are set.
	// If `use_light` is false, you might want to set these to 0 or handle lighting manually.
	if (!use_light) {
		// Disable PBR lighting contribution if needed, though setting METALLIC/ROUGHNESS/SPECULAR to 0 often suffices.
		// Or, handle custom unlit logic here. Example: Make it fully bright
		// ALBEDO = albedo_tex.rgb * albedo_color.rgb; // Keep albedo
		// EMISSION += ALBEDO; // Add albedo to emission to make it appear unlit
		// Or simply rely on EMISSION channel if that's the desired unlit look.
	}

	// Fog is usually handled by WorldEnvironment or a separate fog shader pass.
	// If custom per-pixel fog is needed based on C++ logic:
	// if (use_fog) {
	//     float fog_factor = smoothstep(FOG_PARAMS.x, FOG_PARAMS.y, FRAGCOORD.z); // FOG_PARAMS needs setup
	//     ALBEDO = mix(ALBEDO, FOG_COLOR.rgb, fog_factor);
	// }
}
