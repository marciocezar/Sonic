class_name RomAssets
extends RefCounted
## Assets gráficos decodificados da ROM do próprio usuário (nada disso vai no build).
## Nemesis/Enigma: implementação própria, validada contra VRAM/RAM capturadas por emulação (`make rom-assets-check`,
## evidência EV-ART). Endereços: cabeçalho de fase 0x1D5A2, tabela de PLC 0x1D612, tabela de paletas 0x2168.

const LEVEL_HEADERS := 0x1D5A2
const PLC_TABLE := 0x1D612
const PAL_TABLE := 0x2168
const PAL_SONIC := 3
## PLCs carregadas em toda fase (HUD/anéis/monitores, objetos comuns, explosão) — medido na VRAM de todas as zonas.
const PLC_COMMON := [0, 1, 16]

var rom: PackedByteArray
var _nem_cache: Dictionary = {}


func _init(r: PackedByteArray) -> void:
	rom = r


func _w(a: int) -> int:
	return (rom[a] << 8) | rom[a + 1]


func _l(a: int) -> int:
	return (_w(a) << 16) | _w(a + 2)


## Leitor de bits MSB-primeiro: st = [posição do byte, bit atual].
func _bits(st: PackedInt32Array, n: int) -> int:
	var v := 0
	for _i in range(n):
		v = (v << 1) | ((rom[st[0]] >> (7 - st[1])) & 1)
		st[1] += 1
		if st[1] == 8:
			st[1] = 0
			st[0] += 1
	return v


## Descompressão Nemesis: padrões 8x8 de 4 bpp (32 bytes por tile).
func nemesis(pos: int) -> PackedByteArray:
	if _nem_cache.has(pos):
		return _nem_cache[pos]
	var hdr := _w(pos)
	var xor_mode := (hdr & 0x8000) != 0
	var tiles := hdr & 0x7FFF
	var p := pos + 2
	# tabela de códigos: chave = (comprimento << 8) | código -> (nibble << 8) | repetições
	var table := {}
	var nib := 0
	var b: int = rom[p]
	p += 1
	while b != 0xFF:
		if b & 0x80:
			nib = b & 0x0F
			b = rom[p]
			p += 1
			continue
		var count := ((b >> 4) & 7) + 1
		var length := b & 0x0F
		table[(length << 8) | rom[p]] = (nib << 8) | count
		p += 1
		b = rom[p]
		p += 1
	var st := PackedInt32Array([p, 0])
	var out := PackedByteArray()
	out.resize(tiles * 32)
	var rows := tiles * 8
	var total := 0
	var row := 0
	var nibs := 0
	var prev := 0
	while total < rows:
		var code := 0
		var length := 0
		var val := 0
		var count := 0
		while true:
			code = (code << 1) | _bits(st, 1)
			length += 1
			if length == 6 and code == 0x3F:
				count = _bits(st, 3) + 1
				val = _bits(st, 4)
				break
			var key := (length << 8) | code
			if table.has(key):
				var e: int = table[key]
				val = e >> 8
				count = e & 0xFF
				break
			if length > 8:
				push_error("Nemesis: código inválido em 0x%X" % pos)
				return out
		for _i in range(count):
			row = ((row << 4) | val) & 0xFFFFFFFF
			nibs += 1
			if nibs == 8:
				if xor_mode:
					row ^= prev
					prev = row
				var o := total * 4
				out[o] = (row >> 24) & 0xFF
				out[o + 1] = (row >> 16) & 0xFF
				out[o + 2] = (row >> 8) & 0xFF
				out[o + 3] = row & 0xFF
				row = 0
				nibs = 0
				total += 1
				if total >= rows:
					break
	_nem_cache[pos] = out
	return out


## Descompressão Enigma (mapeamentos de tiles). Retorna palavras de 16 bits.
func enigma(pos: int, base: int = 0) -> PackedInt32Array:
	var n_bits: int = rom[pos]
	var mask: int = rom[pos + 1]
	var inc := (_w(pos + 2) + base) & 0xFFFF
	var common := (_w(pos + 4) + base) & 0xFFFF
	var st := PackedInt32Array([pos + 6, 0])
	var out := PackedInt32Array()
	while true:
		if _bits(st, 1) == 0:
			var c := _bits(st, 1)
			var n := _bits(st, 4) + 1
			for _i in range(n):
				if c == 0:
					out.append(inc)
					inc = (inc + 1) & 0xFFFF
				else:
					out.append(common)
		else:
			var mode := _bits(st, 2)
			var cnt := _bits(st, 4)
			if mode == 3 and cnt == 0xF:
				break
			var v := 0
			if mode != 3:
				v = _eni_inline(st, mask, n_bits, base)
			for _i in range(cnt + 1):
				match mode:
					0:
						out.append(v)
					1:
						out.append(v)
						v = (v + 1) & 0xFFFF
					2:
						out.append(v)
						v = (v - 1) & 0xFFFF
					_:
						out.append(_eni_inline(st, mask, n_bits, base))
	return out


func _eni_inline(st: PackedInt32Array, mask: int, n_bits: int, base: int) -> int:
	var v := 0
	if mask & 0x10 and _bits(st, 1):
		v |= 0x8000
	if mask & 0x08 and _bits(st, 1):
		v |= 0x4000
	if mask & 0x04 and _bits(st, 1):
		v |= 0x2000
	if mask & 0x02 and _bits(st, 1):
		v |= 0x1000
	if mask & 0x01 and _bits(st, 1):
		v |= 0x0800
	return ((v | _bits(st, n_bits)) + base) & 0xFFFF


func header(zone: int) -> Dictionary:
	var h := LEVEL_HEADERS + zone * 16
	return {"plc1": rom[h], "art": _l(h) & 0xFFFFFF, "plc2": rom[h + 4], "blocks": _l(h + 4) & 0xFFFFFF,
			"chunks": _l(h + 8) & 0xFFFFFF, "music": rom[h + 13], "pal": rom[h + 14]}


## Lista de carga de padrões: [[ponteiro Nemesis, endereço VRAM], ...]
func plc(id: int) -> Array:
	var s := PLC_TABLE + _w(PLC_TABLE + id * 2)
	var n := _w(s) + 1
	var out: Array = []
	for k in range(n):
		out.append([_l(s + 2 + k * 6) & 0xFFFFFF, _w(s + 6 + k * 6)])
	return out


func apply_plc(vram: PackedByteArray, id: int) -> void:
	for e in plc(id):
		var data := nemesis(e[0])
		var dst: int = e[1]
		for i in range(mini(data.size(), 0x10000 - dst)):
			vram[dst + i] = data[i]


## VRAM durante o cartão de título (arte do cartão em 0xB000, PLC 16).
func card_vram(zone: int) -> PackedByteArray:
	return level_vram_card(zone)


## VRAM em jogo: depois do cartão o jogo carrega explosões (PLC 2) e os animais da zona (PLC 0x15+zona) por cima
## da arte do cartão (ROM 0xC41C/0xC42E).
func game_vram(zone: int) -> PackedByteArray:
	var v := level_vram_card(zone)
	apply_plc(v, 2)
	apply_plc(v, 0x15 + zone)
	return v


func level_vram(zone: int) -> PackedByteArray:
	return game_vram(zone)


## VRAM de uma fase como o jogo a monta ao iniciar o ato (sem o Sonic, que usa carga dinâmica).
func level_vram_card(zone: int) -> PackedByteArray:
	var vram := PackedByteArray()
	vram.resize(0x10000)
	var hd := header(zone)
	for id in [PLC_COMMON[0], PLC_COMMON[1], hd["plc1"], hd["plc2"], PLC_COMMON[2]]:
		apply_plc(vram, id)
	return vram


## Paleta: entrada da tabela 0x2168 -> palavras de cor escritas a partir do índice CRAM de destino.
func apply_palette(cram: PackedInt32Array, id: int) -> void:
	var e := PAL_TABLE + id * 8
	var src := _l(e) & 0xFFFFFF
	var dst := (_w(e + 4) - 0xFB00) / 2
	var n := (_w(e + 6) + 1) * 2
	for i in range(n):
		if dst + i < cram.size():
			cram[dst + i] = _w(src + i * 2)


func level_cram(zone: int) -> PackedInt32Array:
	var cram := PackedInt32Array()
	cram.resize(64)
	apply_palette(cram, PAL_SONIC)
	apply_palette(cram, header(zone)["pal"])
	return cram


## Blocos 16x16: 4 palavras de tile por bloco.
func level_blocks(zone: int) -> PackedInt32Array:
	return enigma(header(zone)["blocks"])
