shader_type canvas_item;
// Starfield twinkle for the Outside parallax layer (unlit).
uniform float time = 0.0;
varying vec2 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = COLOR;
	float h = hash(floor(world_pos / 7.0));
	float tw = 0.7 + 0.3 * sin(time * (1.5 + 3.0 * h) + h * 6.2831);
	// the 2011 tiles are stars on opaque black: key the black out so the nebula shows
	float mx = max(c.r, max(c.g, c.b));
	COLOR = vec4(c.rgb * tw, c.a * smoothstep(0.03, 0.25, mx));
}
