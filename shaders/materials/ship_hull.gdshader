shader_type spatial;

uniform sampler2D diffuse_texture : source_color;
uniform sampler2D normal_texture : hint_normal;
uniform sampler2D damage_texture : source_color;
uniform float damage_level : hint_range(0.0, 1.0) = 0.0;
uniform float hull_metallic : hint_range(0.0, 1.0) = 0.3;
uniform float hull_roughness : hint_range(0.0, 1.0) = 0.7;
uniform vec3 hull_tint : source_color = vec3(1.0);
uniform float fresnel_power : hint_range(0.0, 5.0) = 2.0;

varying vec3 world_normal;
varying vec3 world_position;
varying vec3 view_direction;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    view_direction = normalize(CAMERA_POSITION_WORLD - world_position);
}

void fragment() {
    vec4 diffuse = texture(diffuse_texture, UV);
    vec4 damage = texture(damage_texture, UV);
    vec3 normal_map = texture(normal_texture, UV).rgb * 2.0 - 1.0;
    
    // Apply damage blending
    vec3 base_color = diffuse.rgb * hull_tint;
    vec3 damaged_color = mix(base_color, damage.rgb, damage_level * damage.a);
    
    // WCS-style edge highlighting
    float fresnel = 1.0 - dot(world_normal, view_direction);
    fresnel = pow(fresnel, fresnel_power);
    vec3 edge_highlight = vec3(hull_metallic * fresnel * 0.3);
    
    vec3 final_color = damaged_color + edge_highlight;
    
    ALBEDO = final_color;
    METALLIC = hull_metallic;
    ROUGHNESS = hull_roughness;
    NORMAL_MAP = normal_map;
    ALPHA = diffuse.a;
}