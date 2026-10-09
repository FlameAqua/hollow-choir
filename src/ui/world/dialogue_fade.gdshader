shader_type canvas_item;
uniform float scroll_y = 0.0;
uniform float view_height = 120.0;
varying float text_y;
void vertex() {
	text_y = VERTEX.y;
}
void fragment() {
	float y = text_y - scroll_y;
	COLOR.a *= smoothstep(-2.0, 8.0, y) * (1.0 - smoothstep(view_height - 10.0, view_height, y));
}
