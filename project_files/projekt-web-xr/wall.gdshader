shader_type spatial;

void fragment() {
	vec2 tile_uv = UV * vec2(20.0, 10.0);
	vec2 tile_id = floor(tile_uv);
	vec2 tile_fract = fract(tile_uv);

	float h = fract(sin(dot(tile_id, vec2(127.1, 311.7))) * 43758.5453);
	float h2 = fract(sin(dot(tile_id + 5.1, vec2(269.5, 183.3))) * 47453.5453);

	float brightness = 0.8 + h * 0.35;
	vec3 color = vec3(0.15, 0.3, 0.75) * brightness;

	float border = 0.05;
	bool is_border = tile_fract.x < border || tile_fract.x > (1.0 - border)
	              || tile_fract.y < border || tile_fract.y > (1.0 - border);
	if (is_border) {
		color *= 0.55;
	}

	if (h2 < 0.1) {
		color *= 0.75;
	}

	ALBEDO = color;
	ROUGHNESS = 0.9;
}
