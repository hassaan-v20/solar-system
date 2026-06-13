#version 330 core

in vec2 v_uv;

uniform sampler2D scene;
uniform sampler2D bloom;
uniform float exposure;

out vec4 frag_color;

void main() {
    vec3 hdr = texture(scene, v_uv).rgb + texture(bloom, v_uv).rgb * 1.3;
    // Exposure tone mapping keeps the bright Sun from clipping harshly.
    vec3 mapped = vec3(1.0) - exp(-hdr * exposure);
    frag_color = vec4(mapped, 1.0);
}
