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

	// Denser stars and dust toward the galactic plane (y ~ 0).
	float band = exp(-pow(d.y * 2.3, 2.0));

	// Stars across four scales with varied colours; brighter near the band.
	float star = 0.0;
	vec3 scol = vec3(1.0);
	for (int i = 0; i < 4; i++) {
		float sc = 200.0 * pow(2.0, float(i));
		vec3 q = floor(d * sc);
		float h = hash13(q);
		float thr = mix(star_density, star_density - 0.004, band);
		if (h > thr) {
			float b = (h - thr) / (1.0 - thr);
			star += b * b * (1.0 / float(i + 1));
			float t = hash13(q + 7.0);
			scol = mix(vec3(0.65, 0.78, 1.0), vec3(1.0, 0.84, 0.66), t);
		}
	}

	// Layered, coloured nebula.
	float n1 = smoothstep(0.45, 0.95, fbm(d * 2.0 + 11.0));
	float n2 = smoothstep(0.50, 0.96, fbm(d * 3.6 + 40.0));
	float n3 = smoothstep(0.58, 0.95, fbm(d * 1.4 + 70.0));
	vec3 neb = vec3(0.10, 0.05, 0.22) * n1
			 + vec3(0.03, 0.12, 0.16) * n2
			 + vec3(0.18, 0.05, 0.11) * n3;
	neb *= (0.45 + 0.9 * band) * nebula_strength;

	vec3 dust = vec3(0.018, 0.026, 0.045) * band;
	vec3 base = vec3(0.004, 0.006, 0.013);
	COLOR = base + neb + dust + scol * star * (1.0 + 0.6 * band);
}
