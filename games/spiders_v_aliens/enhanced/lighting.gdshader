shader_type canvas_item;
// Spiders v. Aliens Enhanced: per-pixel 2D lighting + palette regrade.
// One shader, three materials (mode): 0 = actors (sprites), 1 = Environment tiles,
// 2 = Decorations tiles. Lights are world-space circles fed in by stage.gd every frame.

const int MAX_LIGHTS = 32;

uniform int mode = 0;
uniform vec3 ambient = vec3(0.42, 0.46, 0.60);
uniform int light_count = 0;
uniform vec4 lights[MAX_LIGHTS];        // xy = world position, z = radius, w = intensity
uniform vec4 light_colors[MAX_LIGHTS];  // rgb
uniform float time = 0.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = COLOR;
	vec3 col = c.rgb;
	vec3 emit = vec3(0.0);
	float mx = max(col.r, max(col.g, col.b));
	float mn = min(col.r, min(col.g, col.b));
	if (mode == 1) {
		if (mx - mn < 0.03) {
			// grey deck plating -> cool brushed steel
			col = mix(vec3(0.06, 0.07, 0.12), vec3(0.80, 0.85, 0.95), pow(mx, 1.1));
		} else if (col.g > 0.7 && col.b > 0.9 && col.r < 0.2) {
			// cyan wall trim -> neon, slow breathing shimmer along the hull
			col = vec3(0.30, 0.96, 1.0);
			emit = col * (0.82 + 0.18 * sin(time * 1.7 + (world_pos.x + world_pos.y) * 0.015));
		} else if (col.b > 0.9 && col.r < 0.2) {
			// bright blue window bands
			col = vec3(0.12, 0.50, 1.0);
			emit = col * 0.45;
		} else if (col.g > 0.5 && col.r < 0.3 && col.b < 0.5) {
			// green cage floor
			emit = col * 0.5;
		} else {
			// navy hull fill: deeper, a little more saturated
			col *= vec3(0.55, 0.78, 1.0);
		}
	} else if (mode == 2) {
		if (mn > 0.72) {
			emit = vec3(0.86, 0.96, 1.0);           // fluorescent tube
		} else if (col.g > 0.5 && col.r < 0.75 && col.b < 0.4) {
			emit = col * 0.55;                       // power conduit
		} else if (col.g > 0.7 && col.b > 0.9) {
			emit = col;                              // cyan rail
		}
	}
	vec3 light = ambient;
	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= light_count) {
			break;
		}
		vec4 l = lights[i];
		float d = distance(world_pos, l.xy);
		float f = clamp(1.0 - d / l.z, 0.0, 1.0);
		light += light_colors[i].rgb * (f * f * l.w);
	}
	COLOR = vec4(max(col * light, emit), c.a);
}
