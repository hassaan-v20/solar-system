#version 330 core

in vec3 in_position;
in vec3 in_normal;
in vec2 in_texcoord;

uniform mat4 model;
uniform mat4 view;
uniform mat4 proj;

out vec3 v_pos;
out vec3 v_normal;
out vec2 v_uv;

void main() {
    vec4 world = model * vec4(in_position, 1.0);
    v_pos = world.xyz;
    v_normal = normalize(mat3(model) * in_normal);
    v_uv = in_texcoord;
    gl_Position = proj * view * world;
}
