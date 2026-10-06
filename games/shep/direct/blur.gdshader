shader_type canvas_item;
// Stand-in for Flash's BlurFilter(blurX, blurY) on Game1's bg/fg layers.
// A 9-tap box blur along the blur vector, in pixels.
uniform vec2 blur = vec2(0.0);
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	if (blur.x <= 0.0 && blur.y <= 0.0) {
		COLOR = texture(TEXTURE, UV) * tint;
	} else {
		vec4 acc = vec4(0.0);
		for (int i = -4; i <= 4; i++) {
			float t = float(i) / 8.0;
			acc += texture(TEXTURE, UV + vec2(blur.x * t, 0.0) * TEXTURE_PIXEL_SIZE);
			acc += texture(TEXTURE, UV + vec2(0.0, blur.y * t) * TEXTURE_PIXEL_SIZE);
		}
		COLOR = acc / 18.0 * tint;
	}
}
