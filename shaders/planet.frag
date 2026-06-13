#version 330 core

in vec3 v_pos;
in vec3 v_normal;
in vec2 v_uv;

uniform sampler2D tex;
uniform sampler2D night_tex;
uniform vec3 sun_pos;
uniform vec3 cam_pos;
uniform vec3 tint;        // per-body colour multiplier
uniform float emit;       // additive self-illumination (stars, lava, comets)
uniform int  is_earth;    // 1    => day/night, ocean specular, atmosphere
uniform vec3 atmo_color;

out vec4 frag_color;

void main() {
    vec3 base = texture(tex, v_uv).rgb * tint;

    vec3 N = normalize(v_normal);
    vec3 L = normalize(sun_pos - v_pos);
    vec3 V = normalize(cam_pos - v_pos);
    float ndl = dot(N, L);
    float diff = max(ndl, 0.0);

    vec3 color;
    if (is_earth == 1) {
        // Day/night terminator blend with city lights on the dark side.
        vec3 night = texture(night_tex, v_uv).rgb;
        float t = smoothstep(-0.10, 0.25, ndl);
        color = mix(night * 1.4, base * (0.04 + diff), t);

        // Ocean specular: dark base pixels are water.
        float ocean = 1.0 - smoothstep(0.18, 0.34, dot(base, vec3(0.333)));
        vec3 H = normalize(L + V);
        float spec = pow(max(dot(N, H), 0.0), 64.0) * ocean * t;
        color += vec3(0.8, 0.9, 1.0) * spec * 0.7;

        // Atmospheric Fresnel rim.
        float rim = pow(1.0 - max(dot(N, V), 0.0), 3.0);
        color += atmo_color * rim * (0.35 + 0.65 * t);
    } else {
        color = base * (0.03 + 1.08 * diff);
    }

    // Additive self-illumination: stars/comets glow regardless of the Sun,
    // lava worlds get a faint hot glow.
    color += base * emit;
    frag_color = vec4(color, 1.0);
}
