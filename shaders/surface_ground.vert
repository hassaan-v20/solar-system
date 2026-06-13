#version 330 core

in vec3 in_pos;
in vec3 in_nrm;
in vec2 in_uv;

uniform mat4 view;
uniform mat4 proj;

out vec2 v_uv;
out vec3 v_world;
out vec3 v_nrm;

void main() {
    v_uv = in_uv;
    v_world = in_pos;
    v_nrm = in_nrm;
    gl_Position = proj * view * vec4(in_pos, 1.0);
}
