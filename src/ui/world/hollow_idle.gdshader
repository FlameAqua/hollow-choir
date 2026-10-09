shader_type canvas_item;
uniform bool standing = true;
varying vec4 sprite_tint;
void vertex() {
	sprite_tint = COLOR;
}
void fragment() {
	vec2 sample_uv = UV;
	if (standing) {
		vec2 cell = fract(UV * 4.0);
		// Head, mask and planted boots use frame zero of this direction's pair.
		// Only the authored torso/scarf frame changes; no fractional sprite deformation.
		if (mod(floor(UV.x * 4.0), 2.0) > 0.5 && (cell.y < 0.5 || cell.y > 0.8)) {
			sample_uv.x -= 0.25;
		}
	}
	COLOR = sprite_tint * texture(TEXTURE, sample_uv);
}
