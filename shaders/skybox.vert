#version 330 core

in vec3 in_position;

uniform mat4 view;
uniform mat4 proj;

out vec3 v_dir;

void main() {
    v_dir = in_position;
    // Strip translation so the galaxy sits at infinity (rotates, never moves).
    mat4 rot_view = mat4(mat3(view));
    gl_Position = proj * rot_view * vec4(in_position, 1.0);
}
