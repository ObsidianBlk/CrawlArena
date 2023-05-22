shader_type spatial;

uniform vec3 src_color : source_color = vec3(1.0);
instance uniform vec3 color : source_color = vec3(1.0);
instance uniform float threshold : hint_range(0.0, 1.0) = 0.05;

void fragment() {
	ALBEDO = COLOR.rgb;COLOR;
	if (distance(src_color, COLOR.rgb) <= threshold){
		ALBEDO = color;
	}
}
