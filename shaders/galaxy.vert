#version 330 core

in vec3 in_pos;
in vec2 in_uv;
in vec3 in_color;

uniform mat4 view;
uniform mat4 proj;

out vec2 v_uv;
out vec3 v_color;

void main() {
    v_uv = in_uv;
    v_color = in_color;
    gl_Position = proj * view * vec4(in_pos, 1.0);
}
