shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;

uniform sampler2D video_tex : filter_linear;

// Vert exact LTX : #13ff09
uniform vec3  key_color  = vec3(0.075, 1.0, 0.035);
uniform float threshold  = 0.28;
uniform float smoothness = 0.12;
uniform float opacity    = 0.88;
uniform float emission   = 0.35;
uniform bool  flip_u     = false;

void fragment() {
	vec2 uv = flip_u ? vec2(1.0 - UV.x, UV.y) : UV;
	vec4 col = texture(video_tex, uv);

	// Chroma key : canal vert dominant + distance couleur
	float dg    = col.g - max(col.r, col.b);
	float dist  = distance(col.rgb, key_color);
	float key   = max(dg * 2.5, 0.0);
	float alpha = smoothstep(threshold, threshold + smoothness, dist - key);

	ALBEDO   = col.rgb;
	EMISSION = col.rgb * emission;
	ALPHA    = alpha * opacity;
}
