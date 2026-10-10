shader_type canvas_item;
render_mode unshaded;
// Local five-tap smoothing for scenic images only; never assigned to UI text.
void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * 0.45;
	vec4 sample_color = texture(TEXTURE, UV) * 0.72;
	sample_color += texture(TEXTURE, UV + vec2(step_uv.x, 0.0)) * 0.07;
	sample_color += texture(TEXTURE, UV - vec2(step_uv.x, 0.0)) * 0.07;
	sample_color += texture(TEXTURE, UV + vec2(0.0, step_uv.y)) * 0.07;
	sample_color += texture(TEXTURE, UV - vec2(0.0, step_uv.y)) * 0.07;
	COLOR = sample_color;
}
