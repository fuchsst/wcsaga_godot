shader_type spatial;
render_mode additive, vertex_lighting, shadows_disabled, depth_draw_opaque;

uniform float debris_intensity : hint_range(0.0, 5.0) = 2.0;
uniform vec3 debris_color : source_color = vec3(0.8, 0.4, 0.1);
uniform float expansion_speed : hint_range(0.0, 10.0) = 3.0;
uniform float rotation_speed : hint_range(0.0, 10.0) = 5.0;
uniform float heat_fade : hint_range(0.0, 5.0) = 2.0;
uniform sampler2D debris_pattern : source_color;

varying vec3 world_position;
varying vec2 debris_uv;
varying float particle_life;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // Rotating debris pieces
    float rotation = TIME * rotation_speed;
    vec2 rotated_uv = UV - vec2(0.5);
    float cos_rot = cos(rotation);
    float sin_rot = sin(rotation);
    rotated_uv = vec2(
        rotated_uv.x * cos_rot - rotated_uv.y * sin_rot,
        rotated_uv.x * sin_rot + rotated_uv.y * cos_rot
    ) + vec2(0.5);
    
    debris_uv = rotated_uv;
    particle_life = TIME * expansion_speed;
}

void fragment() {
    // Debris pattern sampling
    vec4 debris_texture = texture(debris_pattern, debris_uv * 2.0);
    
    // Distance from center for radial effects
    vec2 center_offset = debris_uv - vec2(0.5);
    float distance_from_center = length(center_offset) * 2.0;
    
    // Debris chunk definition
    float debris_chunk = step(0.3, debris_texture.r);
    debris_chunk *= (1.0 - smoothstep(0.0, 1.0, distance_from_center));
    
    // Heat glow that fades over time
    float heat_glow = exp(-particle_life * heat_fade);
    heat_glow *= debris_chunk;
    
    // Sparks and embers
    float spark_pattern = debris_texture.g;
    float sparks = spark_pattern * exp(-particle_life * 2.0);
    
    // Trailing effect
    float trail_effect = smoothstep(0.5, 1.0, debris_uv.y) * debris_chunk;
    trail_effect *= exp(-particle_life);
    
    // Combine all effects
    float total_intensity = debris_intensity * (heat_glow + sparks * 0.5 + trail_effect * 0.3);
    
    // Color transition from hot white to cooler orange/red
    vec3 hot_color = vec3(1.0, 0.8, 0.6); // Hot metal
    vec3 final_color = mix(debris_color, hot_color, heat_glow);
    
    // Add spark color for bright spots
    vec3 spark_color = vec3(1.0, 1.0, 0.8);
    final_color = mix(final_color, spark_color, sparks * 0.5);
    
    ALBEDO = final_color;
    EMISSION = final_color * total_intensity;
    ALPHA = total_intensity * 0.8;
}