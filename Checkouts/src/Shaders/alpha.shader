shader_type canvas_item;
render_mode unshaded;
uniform float alpha : hint_range(0.0, 1.0);

void fragment()
{
	float newalpha = smoothstep(alpha, alpha + 1.0, 1.0);
	COLOR = vec4(COLOR.rgb, newalpha);
}