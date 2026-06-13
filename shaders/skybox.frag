#version 330 core

in vec3 v_dir;

uniform sampler2D tex;

out vec4 frag_color;

const float PI = 3.14159265359;

void main() {
    vec3 d = normalize(v_dir);
    float u = atan(d.z, d.x) / (2.0 * PI) + 0.5;
    float v = acos(clamp(d.y, -1.0, 1.0)) / PI;
    vec3 col = texture(tex, vec2(u, v)).rgb;
    frag_color = vec4(col * 0.9, 1.0);
}
