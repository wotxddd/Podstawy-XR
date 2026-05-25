shader_type spatial;

void fragment() {
	// 40x40 kafelków na płaszczyźnie 20x20m = kafelek 0.5m (jak blok MC)
	float tile_count = 40.0;
	vec2 tile_uv = UV * tile_count;
	vec2 tile_id = floor(tile_uv);
	vec2 tile_fract = fract(tile_uv);

	// losowy odcień dla każdego kafelka
	float h = fract(sin(dot(tile_id, vec2(127.1, 311.7))) * 43758.5453);
	float h2 = fract(sin(dot(tile_id + 7.3, vec2(269.5, 183.3))) * 47453.5453);

	float brightness = 0.8 + h * 0.35;
	vec3 color = vec3(0.29, 0.60, 0.13) * brightness;

	// ciemniejsza linia między kafelkami (jak siatka bloków MC)
	float border = 0.05;
	bool is_border = tile_fract.x < border || tile_fract.x > (1.0 - border)
	              || tile_fract.y < border || tile_fract.y > (1.0 - border);
	if (is_border) {
		color *= 0.65;
	}

	// losowe ciemniejsze kafelki (cień / różnorodność)
	if (h2 < 0.12) {
		color *= 0.75;
	}

	ALBEDO = color;
	ROUGHNESS = 1.0;
}
