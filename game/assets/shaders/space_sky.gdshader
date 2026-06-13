shader_type sky;
// Deep-space backdrop: a starfield at infinity (no parallax, so it reads as
// genuinely far) plus a faint coloured nebula. Replaces the old MultiMesh stars,
// which sat at ~500 units and looked congested as you flew.

uniform float star_density = 0.991;
uniform float nebula_strength = 0.55;

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash13(i + vec3(0,0,0)), hash13(i + vec3(1,0,0)), f.x),
			mix(hash13(i + vec3(0,1,0)), hash13(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0,0,1)), hash13(i + vec3(1,0,1)), f.x),
			mix(hash13(i + vec3(0,1,1)), hash13(i + vec3(1,1,1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return s;
}

void sky() {
	vec3 d = normalize(EYEDIR);

	// Stars across three scales so there's a mix of large and tiny pinpoints.
	float star = 0.0;
	vec3 scol = vec3(1.0);
	for (int i = 0; i < 3; i++) {
		float sc = 230.0 * pow(2.0, float(i));
		vec3 q = floor(d * sc);
		float h = hash13(q);
		if (h > star_density) {
			float b = (h - star_density) / (1.0 - star_density);
			star += b * b * (0.9 / float(i + 1));
			float t = hash13(q + 7.0);
			scol = mix(vec3(0.7, 0.82, 1.0), vec3(1.0, 0.86, 0.7), t);
		}
	}

	// Soft nebula clouds.
	float n = fbm(d * 2.2 + 11.0);
	n = smoothstep(0.42, 0.95, n);
	vec3 neb = mix(vec3(0.05, 0.03, 0.10), vec3(0.12, 0.06, 0.22), fbm(d * 4.0));
	vec3 neb2 = mix(vec3(0.02, 0.06, 0.10), vec3(0.04, 0.12, 0.16), fbm(d * 3.0 + 5.0));

	vec3 base = vec3(0.006, 0.009, 0.018);
	COLOR = base + (neb + neb2) * n * nebula_strength + scol * star;
}
