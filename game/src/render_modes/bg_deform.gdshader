shader_type canvas_item;

// Fundo do Mega Drive: um retângulo 320×224, rolagem horizontal por linha e vertical única.
// layout_map: 64×8, canal R = índice do atlas + 1 (0 = vazio).
// hscroll_map: 224×1, RG = rolagem com sinal em 16 bits (byte baixo, byte alto).
uniform sampler2D atlas : filter_nearest, repeat_disable;
uniform sampler2D layout_map : filter_nearest, repeat_disable;
uniform sampler2D hscroll_map : filter_nearest, repeat_disable;
uniform int vscroll = 0;
uniform int atlas_cols = 8;

void fragment() {
	int sx = int(floor(UV.x * 320.0));
	int sy = int(floor(UV.y * 224.0));
	sx = clamp(sx, 0, 319);
	sy = clamp(sy, 0, 223);
	vec4 hg = texelFetch(hscroll_map, ivec2(sy, 0), 0);
	int lo = int(hg.r * 255.0 + 0.5);
	int hi = int(hg.g * 255.0 + 0.5);
	int raw = lo | (hi << 8);
	int hs = raw > 32767 ? raw - 65536 : raw;
	int px = (sx - hs) & 16383;
	int wy = (vscroll + sy) & 2047;
	int col = (px >> 8) & 63;
	int row = (wy >> 8) & 7;
	int xin = px & 255;
	int yin = wy & 255;
	int slot = int(texelFetch(layout_map, ivec2(col, row), 0).r * 255.0 + 0.5);
	if (slot == 0) {
		discard;
	}
	slot -= 1;
	int ac = slot % atlas_cols;
	int ar = slot / atlas_cols;
	vec4 c = texelFetch(atlas, ivec2(ac * 256 + xin, ar * 256 + yin), 0);
	if (c.a < 0.01) {
		discard;
	}
	COLOR = c;
}
