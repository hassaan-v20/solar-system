#version 330 core

in vec3 in_position;
in float in_brightness;

uniform mat4 view;
uniform mat4 proj;

out float v_brightness;

void main() {
    v_brightness = in_brightness;
    gl_Position = proj * view * vec4(in_position, 1.0);
    gl_PointSize = 1.5 + in_brightness * 2.0;
}
