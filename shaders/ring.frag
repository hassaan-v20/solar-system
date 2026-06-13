#version 330 core

in vec3 v_pos;
in vec3 v_normal;
in vec2 v_uv;

uniform sampler2D tex;
uniform vec3 sun_pos;
uniform vec3 planet_pos;
uniform float planet_radius;

out vec4 frag_color;

void main() {
    // v_uv.y runs 0 (inner edge) -> 1 (outer edge): sample the ring strip radially.
    vec4 t = texture(tex, vec2(v_uv.y, 0.5));

    // Soft shadow where the planet body occludes the ring from the Sun.
    vec3 L = normalize(sun_pos - v_pos);
    vec3 to_planet = planet_pos - v_pos;
    float along = dot(to_planet, L);
    float shadow = 1.0;
    if (along > 0.0) {
        vec3 closest = v_pos + L * along;
        float d = length(closest - planet_pos);
        shadow = smoothstep(planet_radius * 0.9, planet_radius * 1.15, d);
    }
    shadow = mix(0.35, 1.0, shadow);

    frag_color = vec4(t.rgb * shadow, t.a);
}
