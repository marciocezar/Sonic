class_name RomSprites
extends RefCounted
## Sprites originais montados em execução a partir da ROM do usuário: mapeamentos (5 bytes por peça:
## y s8, tamanho, palavra de tile, x s8), padrões da VRAM da fase e, para o Sonic, carga dinâmica (DPLC 0x217FE,
## arte sem compressão 0x21AFE -> VRAM 0xF000). Texturas por (mapeamento, quadro, base de arte) em cache.

const SONIC_MAP := 0x211E2
const SONIC_DPLC := 0x217FE
const SONIC_ART := 0x21AFE
const SONIC_GFX := 0x780

var rom: PackedByteArray
var vram: PackedByteArray
var cram: PackedInt32Array
var _cache: Dictionary = {}
var _palettes: Array = []


func _init(r: PackedByteArray, level_vram: PackedByteArray, level_cram: PackedInt32Array) -> void:
	rom = r
	vram = level_vram
	cram = level_cram
	for line in range(4):
		var pal: Array = []
		for i in range(16):
			var c: int = cram[line * 16 + i] if line * 16 + i < cram.size() else 0
			pal.append(VramArt.md_color(c))
		_palettes.append(pal)


func clear_cache() -> void:
	_cache.clear()


func _w(a: int) -> int:
	return (rom[a] << 8) | rom[a + 1]


func _s8(v: int) -> int:
	return v - 256 if v >= 128 else v


## Peças do quadro: [[x, y, largura_tiles, altura_tiles, palavra_tile], ...]
## single=true (render bit 5): o ponteiro aponta direto para UMA peça (fragmentos).
func pieces(map_addr: int, frame: int, single: bool = false) -> Array:
	var n := 1
	var p := map_addr
	if not single:
		# deslocamento com sinal (adda.w): quadros podem apontar para outro mapeamento (ex.: resultados -> cartão)
		var f := map_addr + Fx.s16(_w(map_addr + frame * 2))
		n = rom[f]
		p = f + 1
	var out: Array = []
	for _i in range(n):
		var y := _s8(rom[p])
		var sz: int = rom[p + 1]
		var tw := _w(p + 2)
		var x := _s8(rom[p + 4])
		out.append([x, y, ((sz >> 2) & 3) + 1, (sz & 3) + 1, tw])
		p += 5
	return out


## Tiles do Sonic para o quadro (DPLC), na ordem em que vão para a VRAM a partir de 0xF000.
func _sonic_tiles(frame: int) -> PackedByteArray:
	var e := SONIC_DPLC + _w(SONIC_DPLC + frame * 2)
	var n: int = rom[e]
	var out := PackedByteArray()
	var p := e + 1
	for _i in range(n):
		var cnt := (rom[p] >> 4) + 1
		var idx := ((rom[p] & 0x0F) << 8) | rom[p + 1]
		out.append_array(rom.slice(SONIC_ART + idx * 32, SONIC_ART + (idx + cnt) * 32))
		p += 2
	return out


## Textura do quadro + deslocamento do canto superior esquerdo em relação à origem do objeto.
func frame_texture(map_addr: int, frame: int, gfx: int, sonic: bool = false, single: bool = false) -> Array:
	var key := "%x:%d:%x:%s:%s" % [map_addr, frame, gfx, sonic, single]
	if _cache.has(key):
		return _cache[key]
	var ps := pieces(map_addr, frame, single)
	if ps.is_empty():
		_cache[key] = []
		return []
	var x0 := 9999
	var y0 := 9999
	var x1 := -9999
	var y1 := -9999
	for pc in ps:
		x0 = mini(x0, pc[0])
		y0 = mini(y0, pc[1])
		x1 = maxi(x1, pc[0] + pc[2] * 8)
		y1 = maxi(y1, pc[1] + pc[3] * 8)
	var img := Image.create(x1 - x0, y1 - y0, false, Image.FORMAT_RGBA8)
	var dpl := _sonic_tiles(frame) if sonic else PackedByteArray()
	# hardware: a 1ª peça tem prioridade (fica por cima) -> compor da última para a primeira
	for k in range(ps.size() - 1, -1, -1):
		var pc: Array = ps[k]
		var tw: int = (int(pc[4]) + gfx) & 0xFFFF
		var pal: Array = _palettes[(tw >> 13) & 3]
		var hf := (tw & 0x0800) != 0
		var vf := (tw & 0x1000) != 0
		var base := tw & 0x7FF
		var w: int = pc[2]
		var h: int = pc[3]
		# tiles da peça em ordem coluna a coluna (de cima para baixo, depois da esquerda para a direita)
		for cx in range(w):
			for cy in range(h):
				var t := base + cx * h + cy
				var src := vram
				var off := t * 32
				if sonic:
					src = dpl
					off = (t - SONIC_GFX) * 32
				if off < 0 or off + 32 > src.size():
					continue
				var dx: int = (w - 1 - cx) if hf else cx
				var dy: int = (h - 1 - cy) if vf else cy
				var ox: int = int(pc[0]) - x0 + dx * 8
				var oy: int = int(pc[1]) - y0 + dy * 8
				for row in range(8):
					for col in range(8):
						var byte: int = src[off + row * 4 + (col >> 1)]
						var ci: int = (byte >> 4) if (col & 1) == 0 else (byte & 0xF)
						if ci == 0:
							continue
						var px: int = (7 - col) if hf else col
						var py: int = (7 - row) if vf else row
						img.set_pixel(ox + px, oy + py, pal[ci])
	var res := [ImageTexture.create_from_image(img), Vector2(x0, y0)]
	_cache[key] = res
	return res


## Desenha o quadro na posição de mundo `pos` (espelhamentos como no hardware: bit0 X, bit1 Y).
func draw(ci: CanvasItem, cam: Vector2, pos: Vector2, map_addr: int, frame: int, gfx: int, render: int,
		sonic: bool = false) -> bool:
	var ft := frame_texture(map_addr, frame, gfx, sonic, (render & 0x20) != 0)
	if ft.is_empty():
		return false
	var sx := -1.0 if (render & 1) else 1.0
	var sy := -1.0 if (render & 2) else 1.0
	ci.draw_set_transform((pos - cam).floor(), 0.0, Vector2(sx, sy))
	ci.draw_texture(ft[0], ft[1])
	ci.draw_set_transform(-cam, 0.0, Vector2.ONE)
	return true
