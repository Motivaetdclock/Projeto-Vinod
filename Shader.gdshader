shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 point_color : source_color = vec4(0.1, 1.0, 0.6, 1.0);
uniform float point_size = 0.05;      // world-space size of each point (billboard)
uniform float base_alpha = 1.0;
uniform sampler2D point_texture : hint_default_white, filter_linear_mipmap;

void vertex() {
    // Billboard: face the camera using the modelview matrix.
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
        INV_VIEW_MATRIX[0],
        INV_VIEW_MATRIX[1],
        INV_VIEW_MATRIX[2],
        MODEL_MATRIX[3]
    );
    // Scale the quad by point_size. Quad vertex coords are roughly [-0.5, 0.5].
    MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
        vec4(point_size, 0.0, 0.0, 0.0),
        vec4(0.0, point_size, 0.0, 0.0),
        vec4(0.0, 0.0, point_size, 0.0),
        vec4(0.0, 0.0, 0.0, 1.0)
    );
}

void fragment() {
    // UV is 0..1 across the quad -> distance from center for a round point.
    vec2 centered = UV * 2.0 - 1.0;
    float dist = length(centered);
    if (dist > 1.0) discard;
    
    // Soft round falloff
    float alpha = (1.0 - smoothstep(0.5, 1.0, dist)) * base_alpha;
    
    // Optional color tint from per-instance color
    vec3 tint = point_color.rgb * COLOR.rgb;
    
    ALBEDO = tint;
    ALPHA = alpha * COLOR.a * point_color.a;
    // Additive blending benefits from an emissive feel:
    EMISSION = tint * 1.5;
}