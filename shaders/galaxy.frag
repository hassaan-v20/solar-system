#version 330 core

in vec2 v_uv;
in vec3 v_color;

uniform sampler2D tex;

out vec4 frag_color;

void main() {
    // Additive blending: premultiply by alpha and add to the sky.
    float a = texture(tex, v_uv).a;
    frag_color = vec4(v_color * a, 1.0);
}
