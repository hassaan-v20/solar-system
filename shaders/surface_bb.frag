#version 330 core

in vec2 v_uv;

uniform sampler2D tex;
uniform vec3 color;
uniform int lit;          // 1 = shade as a volumetric creature, 0 = flat sprite

out vec4 frag_color;

void main() {
    vec4 t = texture(tex, v_uv);
    if (t.a < 0.35) discard;

    if (lit == 1) {
        // Height (bulge) is baked in the green channel; derive a normal from it.
        vec2 ts = 1.0 / vec2(textureSize(tex, 0));
        float hL = texture(tex, v_uv - vec2(ts.x, 0.0)).g;
        float hR = texture(tex, v_uv + vec2(ts.x, 0.0)).g;
        float hB = texture(tex, v_uv - vec2(0.0, ts.y)).g;
        float hT = texture(tex, v_uv + vec2(0.0, ts.y)).g;
        vec3 N = normalize(vec3((hL - hR) * 3.0, (hB - hT) * 3.0, 0.6));
        vec3 L = normalize(vec3(-0.45, 0.55, 0.80));
        float diff = max(dot(N, L), 0.0);
        float rim = pow(1.0 - clamp(N.z, 0.0, 1.0), 2.0) * 0.25;
        vec3 body = color * t.r * (0.38 + 0.85 * diff) + rim * color;
        vec3 eye = vec3(1.0, 1.0, 0.92) * t.b;     // glowing eyes
        frag_color = vec4(body + eye, 1.0);
    } else {
        frag_color = vec4(t.rgb * color, 1.0);
    }
}
