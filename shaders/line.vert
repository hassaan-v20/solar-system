#version 330 core

in vec3 in_position;

uniform mat4 view;
uniform mat4 proj;

void main() {
    gl_Position = proj * view * vec4(in_position, 1.0);
}
