shader_type spatial;
render_mode cull_front, depth_draw_opaque, depth_test_disabled, shadows_disabled;

uniform float shield_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec3 shield_color : source_color = vec3(0.0, 0.5, 1.0);
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float impact_intensity : hint_range(0.0, 5.0) = 0.0;
uniform vec3 impact_position : source_color;
uniform float impact_radius : hint_range(0.0, 2.0) = 0.5;
uniform float hexagon_scale : hint_range(1.0, 20.0) = 8.0;
uniform sampler2D hexagon_pattern : source_color;

varying vec3 world_position;
varying vec3 world_normal;
varying float fresnel;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    
    vec3 camera_dir = normalize(CAMERA_POSITION_WORLD - world_position);
    fresnel = 1.0 - dot(world_normal, camera_dir);
}

void fragment() {
    float time_pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    
    // Hexagonal shield pattern
    vec2 hex_uv = UV * hexagon_scale;
    vec4 pattern = texture(hexagon_pattern, hex_uv);
    
    // Calculate impact effect
    float impact_distance = distance(world_position, impact_position);
    float impact_effect = 1.0 - smoothstep(0.0, impact_radius, impact_distance);
    impact_effect *= impact_intensity;
    
    // Ripple effect from impact
    float ripple = sin(impact_distance * 10.0 - TIME * 20.0) * impact_effect;
    
    // Shield visibility calculation
    float shield_alpha = shield_strength * fresnel;
    shield_alpha *= (0.3 + 0.2 * time_pulse + pattern.r * 0.5);
    shield_alpha += impact_effect + ripple * 0.3;
    
    // Energy crackle effects
    float crackle = pattern.g * time_pulse * shield_strength;
    
    // Additional energy web pattern
    float web_pattern = sin(UV.x * 30.0) * sin(UV.y * 30.0) * 0.1;
    
    vec3 final_color = shield_color + vec3(crackle) + vec3(impact_effect) + vec3(web_pattern);
    
    ALBEDO = final_color;
    EMISSION = final_color * (0.5 + impact_effect + crackle);
    ALPHA = clamp(shield_alpha, 0.0, 0.8);
}