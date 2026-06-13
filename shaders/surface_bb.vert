#version 330 core

in vec2 in_corner;   // x in [-0.5,0.5], y in [0,1] (0 = ground)
in vec2 in_uv;

uniform vec3 center;
uniform float size;
uniform vec3 right;
uniform vec3 up;
uniform mat4 view;
uniform mat4 proj;

out vec2 v_uv;

void main() {
    vec3 world = center + (right * in_corner.x + up * in_corner.y) * size;
    v_uv = in_uv;
    gl_Position = proj * view * vec4(world, 1.0);
}
