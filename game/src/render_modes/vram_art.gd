class_name VramArt
extends RefCounted
## Arte Fidelity a partir da VRAM/CRAM capturadas de um levelpack PRIVADO (ROM do usuário).
## Só existe em execução local de laboratório; builds publicáveis não contêm levelpacks.

var level: LevelData
var atlases: Array = []  # [paleta*4 + flip] -> Image 512x256 (64x32 tiles)
var chunk_cache: Dictionary = {}  # chave -> [ImageTexture baixa, ImageTexture alta]
var palette_colors: Array = []


func _init(l: LevelData) -> void:
	level = l
	_build_palettes()
	_build_atlases()


static func md_color(c: int) -> Color:
	var r := (c >> 1) & 7
	var g := (c >> 5) & 7
	var b := (c >> 9) & 7
	return Color8(r * 36, g * 36, b * 36)


func _build_palettes() -> void:
	palette_colors.clear()
	for i in range(64):
		var c: int = level.cram[i] if i < level.cram.size() else 0
		palette_colors.append(md_color(c))


func _build_atlases() -> void:
	var vram := level.vram
	# 1) índices de cor (independentes de paleta), 64x32 tiles = 512x256 pixels
	var idx := PackedByteArray()
	idx.resize(512 * 256)
	var n: int = mini(2048, vram.size() / 32)
	for t in range(n):
		var tx := (t % 64) * 8
		var ty := (t / 64) * 8
		var base := t * 32
		for row in range(8):
			var o := (ty + row) * 512 + tx
			for colb in range(4):
				var byte: int = vram[base + row * 4 + colb]
				idx[o + colb * 2] = byte >> 4
				idx[o + colb * 2 + 1] = byte & 15
	# 2) uma imagem RGBA por paleta, mais 3 variantes espelhadas
	for pal in range(4):
		var lut := PackedByteArray()
		lut.resize(64)
		for k in range(16):
			var c: Color = palette_colors[pal * 16 + k]
			lut[k * 4] = c.r8
			lut[k * 4 + 1] = c.g8
			lut[k * 4 + 2] = c.b8
			lut[k * 4 + 3] = 0 if k == 0 else 255
		var data := PackedByteArray()
		data.resize(512 * 256 * 4)
		for i in range(512 * 256):
			var k4: int = idx[i] * 4
			var o4 := i * 4
			data[o4] = lut[k4]
			data[o4 + 1] = lut[k4 + 1]
			data[o4 + 2] = lut[k4 + 2]
			data[o4 + 3] = lut[k4 + 3]
		var img := Image.create_from_data(512, 256, false, Image.FORMAT_RGBA8, data)
		for f in range(4):
			var im := img.duplicate() as Image
			if f & 1:
				im.flip_x()
			if f & 2:
				im.flip_y()
			atlases.append(im)


func _tile_rect(tile: int, flip: int) -> Rect2i:
	var c := tile % 64
	var r := (tile / 64) % 32
	if flip & 1:
		c = 63 - c
	if flip & 2:
		r = 31 - r
	return Rect2i(c * 8, r * 8, 8, 8)


## Texturas (baixa/alta prioridade) de um chunk do plano FG ou BG.
func chunk_textures(cid: int) -> Array:
	if chunk_cache.has(cid):
		return chunk_cache[cid]
	var low := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var high := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var id := cid & 0x7F
	for by in range(16):
		for bx in range(16):
			var bw := 0
			if id != 0 and id - 1 < level.chunk_count:
				bw = level.chunks[(id - 1) * 256 + by * 16 + bx]
			var blk := bw & 0x3FF
			if blk * 4 + 3 >= level.blocks.size():
				continue
			for ty in range(2):
				for tx in range(2):
					var sx := tx ^ (1 if bw & 0x800 else 0)
					var sy := ty ^ (1 if bw & 0x1000 else 0)
					var tw: int = level.blocks[blk * 4 + sy * 2 + sx] ^ (bw & 0x1800)
					var pal := (tw >> 13) & 3
					var flip := ((tw >> 11) & 1) | (((tw >> 12) & 1) << 1)
					var dst: Image = high if tw & 0x8000 else low
					var src: Image = atlases[pal * 4 + flip]
					dst.blend_rect(src, _tile_rect(tw & 0x7FF, flip), Vector2i(bx * 16 + tx * 8, by * 16 + ty * 8))
	var res := [ImageTexture.create_from_image(low), ImageTexture.create_from_image(high)]
	chunk_cache[cid] = res
	if chunk_cache.size() > 160:
		chunk_cache.erase(chunk_cache.keys()[0])
	return res


func backdrop_color() -> Color:
	var bgi: int = (level.vdp_regs[7] & 0x3F) if level.vdp_regs.size() > 7 else 0
	return palette_colors[bgi] if bgi < palette_colors.size() else Color.BLACK
