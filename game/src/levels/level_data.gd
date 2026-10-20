class_name LevelData
extends RefCounted
## Dados de uma fase em formato neutro do projeto (schema 1).
##
## Fontes possíveis:
##  - "levelpack" privado extraído da ROM do próprio usuário (private/extracted/levelpacks/<id>);
##    NUNCA empacotado em builds (ver docs/security/distribuicao-assets.md).
##  - fase própria do projeto em res://data/levels/<id>.json (conteúdo original, publicável).
##
## Geometria (validada contra o VDP, evidências EV-EXT-*):
##  layout: 8 linhas x 0x80 bytes (0x40 FG + 0x40 BG intercalados); ID de chunk 0 = vazio;
##  bit 7 = chunk de loop (alternativo = ID+1 quando a flag de caminho do objeto está ativa).
##  chunk: 16x16 palavras: bits 0-10 bloco, 11 espelho X, 12 espelho Y, 13 sólido-topo, 14 sólido-lados/baixo.
##  bloco: 2x2 palavras de tile do VDP.

var id: String = ""
var zone: int = 0
var act: int = 0
var zone_name: String = ""
var source: String = ""
var layout: PackedByteArray = PackedByteArray()  # 0x400 bytes (formato intercalado)
var chunks: PackedInt32Array = PackedInt32Array()  # n*256 palavras
var chunk_count: int = 0
var blocks: PackedInt32Array = PackedInt32Array()  # n*4 palavras de tile
var collision_index: PackedByteArray = PackedByteArray()
var heights: PackedInt32Array = PackedInt32Array()  # 256*16 com sinal
var widths: PackedInt32Array = PackedInt32Array()
var angles: PackedByteArray = PackedByteArray()  # 256
var start_x: int = 0
var start_y: int = 0
var limit_left: int = 0
var limit_right: int = 0
var limit_top: int = 0
var limit_bottom: int = 0
var loop_chunks: PackedInt32Array = PackedInt32Array([0x7F, 0x7F])
var roll_chunks: PackedInt32Array = PackedInt32Array([0x7F, 0x7F])
var water_level: int = -1
var objects: Array = []
var cram: PackedInt32Array = PackedInt32Array()
var vdp_regs: PackedInt32Array = PackedInt32Array()
var theme: String = ""
var vram: PackedByteArray = PackedByteArray()
var is_private: bool = false
## ROM do usuário (somente fases importadas em execução): fonte dos sprites originais.
var rom: PackedByteArray = PackedByteArray()
var card_vram: PackedByteArray = PackedByteArray()  # VRAM durante o cartão de título


static func from_dict(d: Dictionary, collision: Dictionary, src: String) -> LevelData:
	var L := LevelData.new()
	L.source = src
	L.id = str(d.get("id", "level"))
	L.zone = int(d.get("zone", 0))
	L.act = int(d.get("act", 0))
	L.zone_name = str(d.get("zone_name", ""))
	L.layout.resize(0x400)
	var fg: Array = d["layout_fg"]
	var bg: Array = d["layout_bg"]
	for r in range(8):
		for c in range(0x40):
			L.layout[r * 0x80 + c] = int(fg[r][c]) if r < fg.size() and c < (fg[r] as Array).size() else 0
			L.layout[r * 0x80 + 0x40 + c] = int(bg[r][c]) if r < bg.size() and c < (bg[r] as Array).size() else 0
	var ch: Array = d["chunks"]
	L.chunk_count = ch.size()
	L.chunks.resize(L.chunk_count * 256)
	for i in range(L.chunk_count):
		var a: Array = ch[i]
		for j in range(256):
			L.chunks[i * 256 + j] = int(a[j])
	var bl: Array = d["blocks"]
	L.blocks.resize(bl.size() * 4)
	for i in range(bl.size()):
		for j in range(4):
			L.blocks[i * 4 + j] = int(bl[i][j])
	var ci: Array = d["collision_index"]
	L.collision_index.resize(max(ci.size(), 0x800))
	for i in range(ci.size()):
		L.collision_index[i] = int(ci[i])
	var hs: Array = collision["heights"]
	var ws: Array = collision["widths"]
	var an: Array = collision["angles"]
	L.heights.resize(4096)
	L.widths.resize(4096)
	for i in range(4096):
		L.heights[i] = int(hs[i])
		L.widths[i] = int(ws[i])
	L.angles.resize(256)
	for i in range(256):
		L.angles[i] = int(an[i])
	var st: Dictionary = d["start"]
	L.start_x = int(st["x"])
	L.start_y = int(st["y"])
	var lim: Dictionary = d["limits"]
	L.limit_left = int(lim["left"])
	L.limit_right = int(lim["right"])
	L.limit_top = int(lim["top"])
	L.limit_bottom = int(lim["bottom"])
	if d.has("loop_chunks"):
		L.loop_chunks = PackedInt32Array(d["loop_chunks"])
	if d.has("roll_chunks"):
		L.roll_chunks = PackedInt32Array(d["roll_chunks"])
	if d.get("water_level") != null:
		L.water_level = int(d["water_level"])
	L.objects = d.get("objects", [])
	if d.has("cram"):
		L.cram = PackedInt32Array(d["cram"])
	if d.has("vdp_regs"):
		L.vdp_regs = PackedInt32Array(d["vdp_regs"])
	L.theme = str(d.get("theme", ["ghz", "lz", "mz", "slz", "syz", "sbz"][L.zone] if L.zone < 6 else "lab"))
	return L


## Carrega um levelpack privado (diretório com level.json; collision.json no diretório pai).
static func load_pack(dir_path: String) -> LevelData:
	var lj := _read_json(dir_path.path_join("level.json"))
	if lj.is_empty():
		return null
	var cj := _read_json(dir_path.get_base_dir().get_base_dir().path_join("collision.json"))
	if cj.is_empty():
		cj = _read_json(dir_path.path_join("collision.json"))
	if cj.is_empty():
		push_error("collision.json ausente para " + dir_path)
		return null
	var L := from_dict(lj, cj, "levelpack:" + dir_path)
	L.is_private = true
	var vf := dir_path.path_join("vram.bin")
	if FileAccess.file_exists(vf):
		L.vram = FileAccess.get_file_as_bytes(vf)
	return L


## Carrega fase própria do projeto (res://data/levels/<id>.json com tabelas de colisão próprias).
static func load_builtin(level_id: String) -> LevelData:
	var d := _read_json("res://data/levels/%s.json" % level_id)
	if d.is_empty():
		return null
	return from_dict(d, d["collision"], "builtin:" + level_id)


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var v: Variant = JSON.parse_string(txt)
	return v if v is Dictionary else {}


## Palavra de bloco (chunk) na posição de mundo (x, y). alt=true usa o chunk alternativo de loop.
func block_word(x: int, y: int, alt: bool) -> int:
	var idx: int = (((y & 0xFFFF) >> 1) & 0x380) + (((x & 0xFFFF) >> 8) & 0x7F)
	var cid: int = layout[idx]
	if cid == 0:
		return 0
	if cid & 0x80:
		cid &= 0x7F
		if alt:
			cid += 1
	var ci: int = cid - 1
	if ci >= chunk_count:
		return 0
	return chunks[ci * 256 + ((y >> 4) & 15) * 16 + ((x >> 4) & 15)]


func layout_fg(col: int, row: int) -> int:
	return layout[(row & 7) * 0x80 + (col & 0x3F)]


func layout_bg(col: int, row: int) -> int:
	return layout[(row & 7) * 0x80 + 0x40 + (col & 0x3F)]


func width_px() -> int:
	var w := 0
	for r in range(8):
		for c in range(0x40):
			if layout[r * 0x80 + c] != 0:
				w = max(w, c + 1)
	return w * 256
