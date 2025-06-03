shader_type spatial;
render_mode additive, vertex_lighting, shadows_disabled, depth_draw_opaque;

uniform float impact_intensity : hint_range(0.0, 10.0) = 5.0;
uniform vec3 impact_color : source_color = vec3(1.0, 1.0, 0.0);
uniform float spark_density : hint_range(0.0, 2.0) = 1.0;
uniform float energy_dispersion : hint_range(0.0, 1.0) = 0.5;
uniform float flash_duration : hint_range(0.1, 2.0) = 0.3;
uniform sampler2D spark_pattern : source_color;

varying vec3 world_position;
varying vec2 impact_uv;
varying float time_since_impact;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    impact_uv = UV;
    time_since_impact = TIME; // This would normally be set per-impact
}

void fragment() {
    // Calculate distance from impact center
    vec2 center_offset = impact_uv - vec2(0.5);
    float distance_from_center = length(center_offset);
    
    // Flash effect that diminishes over time
    float flash_factor = 1.0 - clamp(time_since_impact / flash_duration, 0.0, 1.0);
    
    // Core impact flash
    float core_flash = 1.0 - smoothstep(0.0, 0.3, distance_from_center);
    core_flash *= pow(flash_factor, 2.0);
    
    // Spark pattern
    vec4 sparks = texture(spark_pattern, impact_uv * spark_density);
    float spark_effect = sparks.r * (1.0 - smoothstep(0.0, 0.8, distance_from_center));
    spark_effect *= flash_factor;
    
    // Energy dispersion ring
    float ring_distance = abs(distance_from_center - energy_dispersion * flash_factor);
    float dispersion_ring = 1.0 - smoothstep(0.0, 0.1, ring_distance);
    dispersion_ring *= flash_factor * 0.5;
    
    // Random flicker for energy chaos
    float flicker = sin(time_since_impact * 50.0) * 0.2 + 0.8;
    
    // Combine all effects
    float total_intensity = (core_flash * 3.0 + spark_effect + dispersion_ring) * impact_intensity * flicker;
    
    // Color shifts from white-hot to orange as it cools
    vec3 hot_color = vec3(1.0, 1.0, 1.0); // White hot
    vec3 final_color = mix(impact_color, hot_color, core_flash);
    
    ALBEDO = final_color;
    EMISSION = final_color * total_intensity;
    ALPHA = total_intensity * 0.9;
}