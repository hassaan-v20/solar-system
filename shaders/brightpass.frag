#version 330 core

in vec2 v_uv;

uniform sampler2D scene;
uniform float threshold;

out vec4 frag_color;

void main() {
    vec3 c = texture(scene, v_uv).rgb;
    float b = dot(c, vec3(0.2126, 0.7152, 0.0722));
    float w = max(b - threshold, 0.0) / max(b, 1e-4);
    frag_color = vec4(c * w, 1.0);
}
