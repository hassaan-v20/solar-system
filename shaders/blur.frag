#version 330 core

in vec2 v_uv;

uniform sampler2D image;
uniform vec2 direction;   // texel-sized step along one axis

out vec4 frag_color;

void main() {
    float w[5] = float[](0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);
    vec3 result = texture(image, v_uv).rgb * w[0];
    for (int i = 1; i < 5; i++) {
        result += texture(image, v_uv + direction * float(i)).rgb * w[i];
        result += texture(image, v_uv - direction * float(i)).rgb * w[i];
    }
    frag_color = vec4(result, 1.0);
}
