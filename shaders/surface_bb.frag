#version 330 core

in vec2 v_uv;

uniform sampler2D tex;
uniform vec3 color;

out vec4 frag_color;

void main() {
    vec4 t = texture(tex, v_uv);
    if (t.a < 0.35) discard;
    frag_color = vec4(t.rgb * color, 1.0);
}
