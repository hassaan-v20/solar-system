#version 330 core

in vec2 v_uv;
in vec3 v_world;
in vec3 v_nrm;

uniform sampler2D tex;
uniform vec3 tint;
uniform vec3 sky;
uniform vec3 cam;
uniform vec3 sun_dir;
uniform vec3 sun_col;
uniform vec3 ambient;

out vec4 frag_color;

void main() {
    vec3 base = texture(tex, v_uv).rgb * tint;
    vec3 N = normalize(v_nrm);
    float diff = max(dot(N, normalize(sun_dir)), 0.0);
    // Slope tinting: steep faces look rockier/darker.
    float slope = 1.0 - clamp(N.y, 0.0, 1.0);
    base *= mix(1.0, 0.7, slope);
    vec3 lit = base * (ambient + sun_col * diff);

    float d = length(v_world.xz - cam.xz);
    float fog = clamp((d - 35.0) / 70.0, 0.0, 1.0);
    frag_color = vec4(mix(lit, sky, fog), 1.0);
}
