shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 3.0;
uniform float darkening : hint_range(0.0, 1.0) = 0.4;

void fragment() {
    // Sample the screen texture at the specified LOD (Level of Detail)
    vec4 blurred_color = textureLod(screen_texture, SCREEN_UV, blur_amount);

    // Mix with black to darken the background
    COLOR = mix(blurred_color, vec4(0.0, 0.0, 0.0, 1.0), darkening);
}
