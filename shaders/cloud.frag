#version 330 core

in vec3 v_pos;
in vec3 v_normal;
in vec2 v_uv;

uniform sampler2D tex;
uniform vec3 sun_pos;

out vec4 frag_color;

void main() {
    vec3 c = texture(tex, v_uv).rgb;
    float alpha = dot(c, vec3(0.333));
    vec3 N = normalize(v_normal);
    vec3 L = normalize(sun_pos - v_pos);
    float diff = max(dot(N, L), 0.0);
    frag_color = vec4(vec3(1.0) * (0.05 + 0.95 * diff), alpha * 0.85);
}
