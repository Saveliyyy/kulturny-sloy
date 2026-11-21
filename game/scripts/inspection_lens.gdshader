shader_type canvas_item;

uniform sampler2D artifact : filter_nearest, repeat_disable;
uniform vec2 focus;
uniform vec2 sample_span;
uniform float artifact_angle = 0.0;

void fragment() {
	vec2 offset = UV - vec2(0.5);
	float radius = length(offset);
	if (radius > 0.5) {
		discard;
	}
	float c = cos(artifact_angle);
	float s = sin(artifact_angle);
	vec2 local_offset = vec2(c * offset.x + s * offset.y, -s * offset.x + c * offset.y);
	vec2 sample_uv = focus + local_offset * sample_span;
	vec4 pixel = vec4(0.0);
	if (all(greaterThanEqual(sample_uv, vec2(0.0))) && all(lessThan(sample_uv, vec2(1.0)))) {
		pixel = texture(artifact, sample_uv);
	}
	vec3 glass = mix(vec3(0.145, 0.20, 0.175), pixel.rgb, pixel.a);
	vec3 color = glass;
	if (radius > 0.452) {
		color = vec3(0.62, 0.47, 0.29);
	}
	if (radius > 0.470) {
		color = vec3(0.86, 0.71, 0.47);
	}
	if (radius > 0.488) {
		color = vec3(0.21, 0.165, 0.12);
	}
	COLOR = vec4(color, 1.0);
}
