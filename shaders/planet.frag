#version 330 core

in vec3 v_pos;
in vec3 v_normal;
in vec2 v_uv;

uniform sampler2D tex;
uniform vec3 sun_pos;
uniform vec3 tint;
uniform float emit;
uniform bool is_ring;

out vec4 frag_color;

void main() {
    if (is_ring) {
        float t = v_uv.y;
        float cassini = smoothstep(0.36, 0.39, t) * (1.0 - smoothstep(0.39, 0.42, t));
        float grain = 0.6 + 0.4 * fract(sin(t * 317.3) * 4375.5);
        float density = (1.0 - cassini) * grain;
        vec3 col = tint * (0.55 + 0.55 * t);
        frag_color = vec4(col, clamp(density * 0.82, 0.0, 1.0));
        return;
    }

    vec3 tex_col = texture(tex, v_uv).rgb * tint;

    if (emit > 0.0) {
        frag_color = vec4(tex_col * emit, 1.0);
        return;
    }

    vec3 norm = normalize(v_normal);
    vec3 light = normalize(sun_pos - v_pos);
    float diff = max(dot(norm, light), 0.0);
    float ambient = 0.04;
    frag_color = vec4(tex_col * (ambient + 0.96 * diff), 1.0);
}
