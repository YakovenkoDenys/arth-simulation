shader_type spatial;


// Додаємо filter_nearest прямо тут:
uniform sampler2D height_map : source_color, filter_nearest;
uniform sampler2D color_map : source_color, filter_nearest;
uniform float height_scale = 0.02;

void vertex() {
	vec4 rgb = texture(height_map, UV);
	
	// Важливо: переводимо 0.0-1.0 назад у 0-255
	float r = rgb.r * 255.0;
	float g = rgb.g * 255.0;
	float b = rgb.b * 255.0;
	
	// Формула Terrarium
	float h = (r * 256.0 + g + b / 256.0) - 32768.0;
	
	// Підйом. Якщо 0.5 забагато — постав 0.1
	VERTEX.y += h * height_scale * 0.1;
}

void fragment() {
	ALBEDO = texture(color_map, UV).rgb;
}
