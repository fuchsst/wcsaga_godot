shader_type canvas_item;

uniform sampler2D custom_texture;

void fragment() {
    vec4 tex_color = texture(custom_texture, UV);
    if (tex_color.rgb == vec3(0.0)) {
        tex_color.a = 0.0;
    }
    COLOR = tex_color;
}
