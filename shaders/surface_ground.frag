#version 330 core

in vec2 v_uv;
in vec3 v_world;

uniform sampler2D tex;
uniform vec3 tint;
uniform vec3 sky;
uniform vec3 cam;

out vec4 frag_color;

void main() {
    vec3 c = texture(tex, v_uv).rgb * tint;
    float d = length(v_world.xz - cam.xz);
    float fog = clamp((d - 28.0) / 60.0, 0.0, 1.0);
    frag_color = vec4(mix(c, sky, fog), 1.0);
}
