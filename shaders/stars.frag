#version 330 core

in float v_brightness;

out vec4 frag_color;

void main() {
    vec2 c = gl_PointCoord - 0.5;
    float d = length(c);
    if (d > 0.5) discard;
    float alpha = (1.0 - smoothstep(0.2, 0.5, d)) * v_brightness;
    frag_color = vec4(1.0, 0.97, 0.92, alpha);
}
