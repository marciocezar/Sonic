class_name RomImporter
extends RefCounted
## Importa as fases originais a partir da ROM fornecida pelo PRÓPRIO usuário, em tempo de execução.
## O build não contém nenhum dado da ROM; a ROM fica só no dispositivo do usuário (user://).
## Tabelas e descompressão Kosinski (implementação própria) validadas contra a extração por emulação
## (`make rom-import-check`, evidência EV-IMP). Aceita somente a revisão REV00 verificada por SHA-256.

const REV00_SHA256 := "46160baa06362c711c9f1a5017cb7371026444936c8af5e93a78996cf32ff2a6"
const LEVEL_HEADERS := 0x1D5A2
const LAYOUT_INDEX := 0x68BD6
const LEVEL_SIZES := 0x5F1C
const START_LOCS := 0x6112
const LOOP_CHUNKS := 0x6182
const COLL_INDEX_PTRS := 0x4100
const OBJPOS_INDEX := 0x6B000
const WATER_HEIGHTS := 0x3C2A
const ANGLES := 0x62900
const HEIGHTS := 0x62A00
const WIDTHS := 0x63A00
const STORE_PATH := "user://rom/rom.bin"  # legado: só para apagar cópias antigas

const LEVEL_IDS := {
	"ghz1": [0, 0], "ghz2": [0, 1], "ghz3": [0, 2], "lz1": [1, 0], "lz2": [1, 1], "lz3": [1, 2], "sbz3": [1, 3],
	"mz1": [2, 0], "mz2": [2, 1], "mz3": [2, 2], "slz1": [3, 0], "slz2": [3, 1], "slz3": [3, 2],
	"syz1": [4, 0], "syz2": [4, 1], "syz3": [4, 2], "sbz1": [5, 0], "sbz2": [5, 1], "fz": [5, 2],
}
const ZONE_NAMES := ["Green Hill", "Labyrinth", "Marble", "Star Light", "Spring Yard", "Scrap Brain"]

var rom: PackedByteArray = PackedByteArray()
var assets: RomAssets
var _chunk_cache: Dictionary = {}
var _art_cache: Dictionary = {}
var _collision: Dictionary = {}


static func sha256_hex(data: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish().hex_encode()


## Valida e guarda a ROM. Retorna "" se ok, ou a mensagem de erro.
func load_rom(data: PackedByteArray) -> String:
	if data.size() != 0x80000:
		return "tamanho inesperado (%d bytes; esperado 524288)" % data.size()
	if data.slice(0x100, 0x10F).get_string_from_ascii() != "SEGA MEGA DRIVE":
		return "não é uma ROM de Mega Drive (assinatura ausente em 0x100)"
	var h := sha256_hex(data)
	if h != REV00_SHA256:
		return "revisão não suportada (SHA-256 %s…); use a REV00 'GM 00001009-00'" % h.substr(0, 12)
	rom = data
	assets = RomAssets.new(rom)
	_chunk_cache.clear()
	_art_cache.clear()
	_collision = {}
	return ""


func is_loaded() -> bool:
	return rom.size() == 0x80000


## Conteúdo embutido apenas nos builds privados (`make build-private-<alvo>`); ausente nos builds públicos.
const EMBEDDED_PATH := "res://private_pack/content.bin"


func load_embedded() -> bool:
	if not FileAccess.file_exists(EMBEDDED_PATH):
		return false
	return load_rom(FileAccess.get_file_as_bytes(EMBEDDED_PATH)) == ""


static func forget_user_rom() -> void:
	if FileAccess.file_exists(STORE_PATH):
		DirAccess.remove_absolute(STORE_PATH)


func _w(a: int) -> int:
	return (rom[a] << 8) | rom[a + 1]


func _sw(a: int) -> int:
	return Fx.s16(_w(a))


func _l(a: int) -> int:
	return (_w(a) << 16) | _w(a + 2)


## Descompressão Kosinski (campo de descrição de 16 bits little-endian, bits do menos significativo).
func kosinski(pos: int) -> PackedByteArray:
	var out := PackedByteArray()
	var field := rom[pos] | (rom[pos + 1] << 8)
	pos += 2
	var left := 16
	var p := pos
	var bits := [field, left, p]
	while true:
		if _bit(bits):
			out.append(rom[bits[2]])
			bits[2] += 1
			continue
		var count := 0
		var offset := 0
		if _bit(bits) == 0:
			var b1 := _bit(bits)
			var b0 := _bit(bits)
			count = ((b1 << 1) | b0) + 2
			offset = rom[bits[2]] - 0x100
			bits[2] += 1
		else:
			var lo: int = rom[bits[2]]
			var hi: int = rom[bits[2] + 1]
			bits[2] += 2
			offset = (((hi & 0xF8) << 5) | lo) - 0x2000
			count = hi & 7
			if count == 0:
				var c: int = rom[bits[2]]
				bits[2] += 1
				if c == 0:
					break
				if c == 1:
					continue
				count = c + 1
			else:
				count += 2
		for _i in range(count):
			out.append(out[out.size() + offset])
	return out


func _bit(st: Array) -> int:
	var b: int = st[0] & 1
	st[0] = st[0] >> 1
	st[1] -= 1
	if st[1] == 0:
		st[0] = rom[st[2]] | (rom[st[2] + 1] << 8)
		st[2] += 2
		st[1] = 16
	return b


func collision_tables() -> Dictionary:
	if _collision.is_empty():
		var hs: Array = []
		var ws: Array = []
		for i in range(4096):
			hs.append(Fx.s8(rom[HEIGHTS + i]))
			ws.append(Fx.s8(rom[WIDTHS + i]))
		var an: Array = []
		for i in range(256):
			an.append(rom[ANGLES + i])
		_collision = {"heights": hs, "widths": ws, "angles": an}
	return _collision


## Monta o dicionário de fase (schema 1) para o id dado ("ghz1".."fz").
func level_dict(lid: String) -> Dictionary:
	var za: Array = LEVEL_IDS[lid]
	var zone: int = za[0]
	var act: int = za[1]
	var chunks_ptr := _l(LEVEL_HEADERS + zone * 16 + 8) & 0xFFFFFF
	if not _chunk_cache.has(chunks_ptr):
		_chunk_cache[chunks_ptr] = kosinski(chunks_ptr)
	var raw: PackedByteArray = _chunk_cache[chunks_ptr]
	var chunks: Array = []
	for c in range(raw.size() / 512):
		var ch: Array = []
		ch.resize(256)
		for i in range(256):
			ch[i] = (raw[c * 512 + i * 2] << 8) | raw[c * 512 + i * 2 + 1]
		chunks.append(ch)
	var fg: Array = []
	var bg: Array = []
	for _r in range(8):
		var a1: Array = []
		a1.resize(0x40)
		a1.fill(0)
		fg.append(a1)
		var a2: Array = []
		a2.resize(0x40)
		a2.fill(0)
		bg.append(a2)
	for which in [0, 2]:
		var dst: Array = fg if which == 0 else bg
		var idx: int = (zone * 8 + act * 2) * 3 + which
		var p := LAYOUT_INDEX + _w(LAYOUT_INDEX + idx)
		var wdt: int = rom[p] + 1
		var hgt: int = rom[p + 1] + 1
		p += 2
		for r in range(hgt):
			for c in range(wdt):
				if r < 8 and c < 0x40:
					dst[r][c] = rom[p]
				p += 1
	var si := LEVEL_SIZES + (zone * 16 + act * 4) * 3
	var limits := {"left": _sw(si + 2), "right": _sw(si + 4), "top": _sw(si + 6), "bottom": _sw(si + 8)}
	var st := START_LOCS + zone * 16 + act * 4
	var start := {"x": _w(st), "y": _w(st + 2)}
	var lc := LOOP_CHUNKS + zone * 4
	var ci_ptr := _l(COLL_INDEX_PTRS + zone * 4) & 0xFFFFFF
	var maxid := 0
	for row in fg + bg:
		for b in row:
			maxid = maxi(maxid, int(b) & 0x7F)
	var nblocks := 1
	for ci in range(mini(chunks.size(), maxid + 1)):
		for x in chunks[ci]:
			nblocks = maxi(nblocks, (int(x) & 0x3FF) + 1)
	var coll: Array = []
	for i in range(nblocks):
		coll.append(rom[ci_ptr + i])
	var objs: Array = []
	var op := OBJPOS_INDEX + _w(OBJPOS_INDEX + zone * 16 + act * 4)
	while _w(op) != 0xFFFF:
		var yraw := _w(op + 2)
		objs.append({"x": _w(op), "yraw": yraw, "y": yraw & 0xFFF, "id": rom[op + 4], "sub": rom[op + 5]})
		op += 6
	var art := zone_art(zone)
	var bw: PackedInt32Array = art["blocks"]
	var blocks: Array = []
	for i in range(maxi(nblocks, bw.size() / 4)):
		if i * 4 + 3 < bw.size():
			blocks.append([bw[i * 4], bw[i * 4 + 1], bw[i * 4 + 2], bw[i * 4 + 3]])
		else:
			blocks.append([0, 0, 0, 0])
	return {
		"schema": 1, "id": lid, "zone": zone, "act": act, "zone_name": ZONE_NAMES[zone],
		"start": start, "limits": limits, "layout_fg": fg, "layout_bg": bg, "chunks": chunks,
		"blocks": blocks, "collision_index": coll,
		"loop_chunks": [rom[lc], rom[lc + 1]], "roll_chunks": [rom[lc + 2], rom[lc + 3]],
		"water_level": _sw(WATER_HEIGHTS + act * 2) if zone == 1 else null,
		"objects": objs, "cram": Array(art["cram"]),
		# cor de fundo: a inicialização da fase escreve $8720 no VDP (registrador 7 = linha 2, cor 0; ROM 0x3868)
		"vdp_regs": [0x04, 0x74, 0x30, 0x28, 0x07, 0x7C, 0x00, 0x20],
	}


## Arte da zona (VRAM montada pelas PLCs, paleta e blocos 16x16), decodificada uma vez por zona.
func zone_art(zone: int) -> Dictionary:
	if not _art_cache.has(zone):
		_art_cache[zone] = {"vram": assets.game_vram(zone), "card_vram": assets.card_vram(zone),
				"cram": assets.level_cram(zone),
				"blocks": assets.level_blocks(zone)}
	return _art_cache[zone]


func load_level(lid: String) -> LevelData:
	if not is_loaded() or not LEVEL_IDS.has(lid):
		return null
	var L := LevelData.from_dict(level_dict(lid), collision_tables(), "rom:" + lid)
	L.is_private = true
	L.vram = zone_art(int(LEVEL_IDS[lid][0]))["vram"]
	L.rom = rom
	L.card_vram = zone_art(int(LEVEL_IDS[lid][0]))["card_vram"]
	return L
