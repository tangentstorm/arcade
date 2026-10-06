shader_type canvas_item;
// Deep-space backdrop behind the starfield: soft nebula + dust stars.
uniform vec2 offset = vec2(0.0);
uniform float time = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV * vec2(1.78, 1.0) * 1.6 + offset;
	float n = fbm(uv + vec2(time * 0.004, 0.0));
	float m = fbm(uv * 1.7 + vec2(4.0, 2.0));
	vec3 deep = vec3(0.012, 0.012, 0.035);
	vec3 neb = mix(vec3(0.20, 0.04, 0.30), vec3(0.00, 0.22, 0.32), m);
	vec3 col = deep + neb * smoothstep(0.42, 0.95, n) * 0.7;
	vec2 g = floor((UV * vec2(1.78, 1.0) + offset * 0.5) * 260.0);
	float s = hash(g);
	if (s > 0.996) {
		col += vec3(0.55, 0.6, 0.75) * (s - 0.996) * 250.0 * (0.6 + 0.4 * sin(time * 2.0 + s * 40.0));
	}
	COLOR = vec4(col, 1.0);
}
