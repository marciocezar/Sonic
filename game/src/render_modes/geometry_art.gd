class_name GeometryArt
extends RefCounted
## Arte PRÓPRIA gerada a partir da geometria de colisão (mapas de altura): usada no perfil
## Enhanced (sempre) e no Fidelity quando não há arte privada. Nunca usa pixels da ROM.
## scale = 1 (pixel) ou 2 (alta resolução). Paletas por tema são originais do projeto.

const THEMES := {
	"ghz": {"soil_a": Color("8a5a2b"), "soil_b": Color("6e4520"), "top": Color("3fbf3f"), "top2": Color("2a8f2a"),
		"rim": Color("c9934e"), "sky_top": Color("2a5fd8"), "sky_bot": Color("8fd0ff"), "hill": Color("2f8f4f"), "plat": Color("b07a3a")},
	"mz": {"soil_a": Color("4f6b3a"), "soil_b": Color("3e5530"), "top": Color("7fbf5f"), "top2": Color("5f9f3f"),
		"rim": Color("9fbf7f"), "sky_top": Color("3a1f4f"), "sky_bot": Color("9f5f6f"), "hill": Color("5f2f3f"), "plat": Color("9f9f9f")},
	"syz": {"soil_a": Color("6f3f8f"), "soil_b": Color("5a3075"), "top": Color("ff8fbf"), "top2": Color("d06f9f"),
		"rim": Color("ffd0e0"), "sky_top": Color("0f1f4f"), "sky_bot": Color("3f4f9f"), "hill": Color("2f2f6f"), "plat": Color("ffbf3f")},
	"lz": {"soil_a": Color("4f7f5f"), "soil_b": Color("3f6a4f"), "top": Color("8fdfaf"), "top2": Color("5fbf8f"),
		"rim": Color("bfffdf"), "sky_top": Color("1f3f3f"), "sky_bot": Color("3f7f7f"), "hill": Color("2f5f5f"), "plat": Color("9fdfbf")},
	"slz": {"soil_a": Color("3f4f8f"), "soil_b": Color("2f3f75"), "top": Color("9fafff"), "top2": Color("6f7fdf"),
		"rim": Color("dfe5ff"), "sky_top": Color("05051f"), "sky_bot": Color("1f1f5f"), "hill": Color("10103f"), "plat": Color("ffdf5f")},
	"sbz": {"soil_a": Color("5f5f6f"), "soil_b": Color("4a4a58"), "top": Color("afafbf"), "top2": Color("8f8f9f"),
		"rim": Color("dfdfef"), "sky_top": Color("2f1f1f"), "sky_bot": Color("6f3f2f"), "hill": Color("3f2f2f"), "plat": Color("bfbf9f")},
	"lab": {"soil_a": Color("2f6f8f"), "soil_b": Color("255a75"), "top": Color("5fefbf"), "top2": Color("3fbf9f"),
		"rim": Color("bffff0"), "sky_top": Color("10204f"), "sky_bot": Color("5f8fdf"), "hill": Color("1f3f6f"), "plat": Color("ffcf4f")},
}

var level: LevelData
var scale: int = 1
var theme: Dictionary
var chunk_cache: Dictionary = {}
var inside: PackedByteArray = PackedByteArray()  # 1 = interior de terreno (bloco sem colisão)
var bw_cols: int = 0


func _init(l: LevelData, s: int) -> void:
	level = l
	scale = s
	theme = THEMES.get(l.theme, THEMES["lab"])
	_compute_inside()


## Varre cada coluna de blocos de cima para baixo: após uma superfície de piso sólida,
## blocos vazios são interior até encontrar uma superfície de teto (alturas negativas).
func _compute_inside() -> void:
	bw_cols = 0x40 * 16
	inside.resize(bw_cols * 128)
	inside.fill(0)
	for bx in range(bw_cols):
		var state := false
		for by in range(128):
			var bw := level.block_word(bx * 16, by * 16, false)
			var blk := bw & 0x3FF
			var kind := 0  # 0 vazio, 1 piso, 2 teto, 3 cheio
			if blk != 0 and (bw & 0x6000) != 0:
				var idx: int = level.collision_index[blk] if blk < level.collision_index.size() else 0
				if idx != 0:
					var h: int = level.heights[idx * 16 + 8]
					if bw & 0x1000:
						h = -h
					if h >= 16 or h <= -16:
						kind = 3
					elif h > 0:
						kind = 1
					elif h < 0:
						kind = 2
			if kind == 1 or kind == 3:
				state = true
			elif kind == 2:
				state = false
			elif state:
				inside[by * bw_cols + bx] = 1


## Altura sólida de uma coluna (0..16) e se é preenchida a partir de cima (teto).
func _column(bw: int, col: int) -> Vector2i:
	var blk := bw & 0x3FF
	if blk == 0 or (bw & 0x6000) == 0:
		return Vector2i(0, 0)
	var idx: int = level.collision_index[blk] if blk < level.collision_index.size() else 0
	if idx == 0:
		return Vector2i(0, 0)
	var c := col
	if bw & 0x800:
		c = 15 - c
	var h: int = level.heights[idx * 16 + c]
	var from_top := h < 0
	h = absi(h)
	if bw & 0x1000:
		from_top = not from_top
	return Vector2i(h, 1 if from_top else 0)


func chunk_textures_at(col: int, row: int, cid: int) -> Array:
	var key := (row << 8) | col
	if chunk_cache.has(key):
		return chunk_cache[key]
	var S := 256 * scale
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var id := cid & 0x7F
	if id - 1 < level.chunk_count:
		for by in range(16):
			for bx in range(16):
				var bw: int = level.chunks[(id - 1) * 256 + by * 16 + bx] if id != 0 else 0
				var gx := col * 16 + bx
				var gy := (row & 7) * 16 + by
				if (bw & 0x3FF) == 0 or (bw & 0x6000) == 0 or level.collision_index[bw & 0x3FF] == 0:
					if gx < bw_cols and inside[gy * bw_cols + gx] == 1:
						var checker := (((col * 256 + bx * 16) / 32) + ((by * 16 + row * 256) / 32)) % 2 == 0
						img.fill_rect(Rect2i(bx * 16 * scale, by * 16 * scale, 16 * scale, 16 * scale),
								theme["soil_a"] if checker else theme["soil_b"])
					continue
				_paint_block(img, bw, bx * 16, by * 16, id, bx, by)
	var res := [ImageTexture.create_from_image(img), null]
	chunk_cache[key] = res
	if chunk_cache.size() > 40:
		chunk_cache.erase(chunk_cache.keys()[0])
	return res


func _paint_block(img: Image, bw: int, ox: int, oy: int, cid: int, bx: int, by: int) -> void:
	var top_only := false  # blocos só-topo são desenhados como terreno (o interior é inferido)
	var checker := ((ox / 32) + (oy / 32)) % 2 == 0
	var soil: Color = theme["soil_a"] if checker else theme["soil_b"]
	var above_empty := true
	if by > 0:
		var aw: int = level.chunks[(cid - 1) * 256 + (by - 1) * 16 + bx]
		above_empty = (aw & 0x3FF) == 0
	for col in range(16):
		var cv := _column(bw, col)
		var h := cv.x
		if h == 0:
			continue
		var x := (ox + col) * scale
		if top_only:
			var y0 := (oy + 16 - h) * scale
			img.fill_rect(Rect2i(x, y0, scale, 4 * scale), theme["plat"])
			img.fill_rect(Rect2i(x, y0 + 4 * scale, scale, scale), theme["plat"].darkened(0.4))
			continue
		var y_start: int
		var y_end: int
		if cv.y == 1:
			y_start = oy * scale
			y_end = (oy + h) * scale
		else:
			y_start = (oy + 16 - h) * scale
			y_end = (oy + 16) * scale
		img.fill_rect(Rect2i(x, y_start, scale, y_end - y_start), soil)
		if cv.y == 0 and (h < 16 or above_empty):
			var g := 3 * scale
			img.fill_rect(Rect2i(x, y_start, scale, mini(g, y_end - y_start)), theme["top"])
			if y_end - y_start > g:
				img.fill_rect(Rect2i(x, y_start + g, scale, scale), theme["top2"])


func backdrop_color() -> Color:
	return theme["sky_bot"]
