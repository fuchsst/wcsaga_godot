shader_type canvas_item;

// Hologram panel shader with HDR glow support
// Requires WorldEnvironment with glow enabled for full effect

// Base appearance
uniform vec4 base_color : source_color = vec4(0.0, 0.4, 0.8, 0.3);
uniform float scanline_count = 80.0;
uniform float scanline_speed = -1.5;
uniform float aberration_amount : hint_range(0.0, 10.0) = 1.5;
uniform float flicker_speed = 12.0;

// Glow parameters
uniform vec4 glow_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float edge_glow_intensity : hint_range(0.0, 8.0) = 1.0;
uniform float edge_thickness : hint_range(0.02, 0.2) = 0.08;
uniform float glow_softness : hint_range(0.01, 0.3) = 0.1;

// Random noise function for flicker
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;

    // 1. Chromatic Aberration (Shift RGB channels)
    vec2 dist_from_center = uv - 0.5;
    vec2 aber_offset = dist_from_center * aberration_amount * SCREEN_PIXEL_SIZE;

    vec4 texture_col;
    texture_col.r = texture(TEXTURE, uv - aber_offset).r;
    texture_col.g = texture(TEXTURE, uv).g;
    texture_col.b = texture(TEXTURE, uv + aber_offset).b;
    texture_col.a = texture(TEXTURE, uv).a;

    // 2. Scanlines
    float scanline = sin(uv.y * scanline_count + TIME * scanline_speed);
    scanline = smoothstep(0.0, 1.0, scanline) * 0.15 + 0.85;

    // 3. Flicker (Rare random opacity drops)
    float noise = random(vec2(TIME * flicker_speed, 0.0));
    float opacity_mod = noise > 0.97 ? 0.7 : 1.0;

    // 4. Base color with effects
    COLOR = base_color * texture_col;
    COLOR.rgb *= scanline;
    COLOR.a *= opacity_mod;

    // 5. Edge detection for glow
    // Calculate distance from edge (0 = at edge, 1 = center)
    float edge_dist_x = min(uv.x, 1.0 - uv.x);
    float edge_dist_y = min(uv.y, 1.0 - uv.y);
    float edge_dist = min(edge_dist_x, edge_dist_y);

    // Soft edge glow falloff
    float edge_factor = 1.0 - smoothstep(0.0, edge_thickness + glow_softness, edge_dist);

    // Apply HDR glow (values > 1.0 will bloom with WorldEnvironment glow)
    // The edge_glow_intensity multiplier creates HDR values for bloom effect
    vec3 hdr_glow = glow_color.rgb * edge_factor * edge_glow_intensity;
    COLOR.rgb += hdr_glow;

    // Corner emphasis (corners glow slightly more)
    float corner_dist = length(abs(uv - 0.5) - 0.5);
    float corner_glow = smoothstep(0.1, 0.0, corner_dist) * 0.3;
    COLOR.rgb += glow_color.rgb * corner_glow * edge_glow_intensity;
}
