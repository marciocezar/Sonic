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


var warm_ids: Array = []
var warm_i: int = 0
var warm_done: bool = false
var bg_count: int = 0
var bg_ready: bool = false
var bg_atlas: ImageTexture
var layout_tex: ImageTexture
var atlas_cols: int = 8
var _atlas_img: Image
var _slot_of: PackedByteArray = PackedByteArray()


## Texturas (baixa/alta prioridade) de um chunk do plano FG ou BG. Cache por id (bit 7 de loop não muda a arte).
func chunk_textures(cid: int) -> Array:
	var id := cid & 0x7F
	if chunk_cache.has(id):
		return chunk_cache[id]
	var imgs := _chunk_images(id)
	var res := [ImageTexture.create_from_image(imgs[0]), ImageTexture.create_from_image(imgs[1])]
	chunk_cache[id] = res
	return res


func _chunk_images(id: int) -> Array:
	var low := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var high := Image.create(256, 256, false, Image.FORMAT_RGBA8)
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
	return [low, high]


## Prepara o atlas do fundo (deformação numa única passagem na GPU) e a fila dos chunks do ato.
func queue_warm() -> void:
	var seen := {}
	var bg_ids: Array = []
	var fg_ids: Array = []
	for row in range(8):
		for col in range(0x40):
			var bid: int = level.layout_bg(col, row) & 0x7F
			var fid: int = level.layout_fg(col, row) & 0x7F
			if bid != 0 and not seen.has(bid):
				seen[bid] = true
				bg_ids.append(bid)
			if fid != 0 and not seen.has(fid):
				seen[fid] = true
				fg_ids.append(fid)
	_slot_of = PackedByteArray()
	_slot_of.resize(128)
	bg_count = bg_ids.size()
	var rows: int = maxi(1, (bg_count + atlas_cols - 1) / atlas_cols)
	_atlas_img = Image.create(atlas_cols * 256, rows * 256, false, Image.FORMAT_RGBA8)
	for i in range(bg_count):
		_slot_of[int(bg_ids[i])] = i + 1
	var li := Image.create(64, 8, false, Image.FORMAT_RGBA8)
	for row in range(8):
		for col in range(0x40):
			var id: int = level.layout_bg(col, row) & 0x7F
			var slot: int = int(_slot_of[id]) if id > 0 and id < 128 else 0
			li.set_pixel(col, row, Color8(slot, 0, 0, 255))
	layout_tex = ImageTexture.create_from_image(li)
	warm_ids = bg_ids + fg_ids
	warm_i = 0
	warm_done = warm_ids.is_empty()
	bg_ready = bg_count == 0
	if bg_ready:
		_atlas_img = null


## Monta alguns chunks por quadro (o cartão de título cobre a espera) para o ato entrar sem travar.
func warm(budget: int) -> void:
	if warm_done:
		return
	var n := 0
	while warm_i < warm_ids.size() and n < budget:
		var id: int = warm_ids[warm_i]
		var imgs: Array = _chunk_images(id)
		if id > 0 and id < _slot_of.size() and _slot_of[id] != 0 and _atlas_img != null:
			var slot: int = int(_slot_of[id]) - 1
			var pos := Vector2i((slot % atlas_cols) * 256, int(slot / atlas_cols) * 256)
			_atlas_img.blit_rect(imgs[0], Rect2i(0, 0, 256, 256), pos)
			_atlas_img.blend_rect(imgs[1], Rect2i(0, 0, 256, 256), pos)
		if not chunk_cache.has(id):
			chunk_cache[id] = [ImageTexture.create_from_image(imgs[0]), ImageTexture.create_from_image(imgs[1])]
		warm_i += 1
		n += 1
		if not bg_ready and warm_i >= bg_count:
			_finish_bg()
	if warm_i >= warm_ids.size():
		if not bg_ready:
			_finish_bg()
		warm_done = true


func _finish_bg() -> void:
	if _atlas_img != null:
		bg_atlas = ImageTexture.create_from_image(_atlas_img)
		_atlas_img = null
	bg_ready = true


func backdrop_color() -> Color:
	var bgi: int = (level.vdp_regs[7] & 0x3F) if level.vdp_regs.size() > 7 else 0
	return palette_colors[bgi] if bgi < palette_colors.size() else Color.BLACK
