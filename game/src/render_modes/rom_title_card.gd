class_name RomTitleCard
extends RefCounted
## Cartão de título original (objeto 0x34, ROM 0xC306): 4 peças — nome da zona, "ZONE", ato e oval — com
## posições inicial/final por zona (0xC448) e altura/quadro por peça (0xC438); mapeamento 0xC9E6, arte 0x8580.
## Entrada a 16 px/quadro (0xC3B4); depois de liberadas, esperam 60 quadros e saem a 32 px/quadro (0xC3DA).

const MAP := 0xC9E6
const GFX := 0x8580
const POS := 0xC448
const PIECES := 0xC438

var sprites: RomSprites
var pieces: Array = []  # [x, start, target, y, frame, routine, timer, alive]
var released := false
var finished_plc := false  # peça do nome terminou: o jogo carrega PLC 2 + animais


func _init(rom: PackedByteArray, vram: PackedByteArray, cram: PackedInt32Array, zone: int, act: int) -> void:
	sprites = RomSprites.new(rom, vram, cram)
	var zid := (zone << 8) | act
	var d0 := zone
	if zid == 0x103:
		d0 = 5
	var d2 := d0
	if zid == 0x502:
		d0 = 6
		d2 = 0xB
	for i in range(4):
		var a := POS + d0 * 16 + i * 4
		var start := (rom[a] << 8) | rom[a + 1]
		var target := (rom[a + 2] << 8) | rom[a + 3]
		var b := PIECES + i * 4
		var y := (rom[b] << 8) | rom[b + 1]
		var fr: int = rom[b + 3]
		if fr == 0:
			fr = d2
		if fr == 7:
			fr += act
			if act == 3:
				fr -= 1
		pieces.append([Fx.s16(start), Fx.s16(start), Fx.s16(target), y, fr, 2, 0x3C, true])


## Peça do ato chegou ao destino (fim do laço de entrada do nível).
func arrived() -> bool:
	return pieces[2][0] == pieces[2][2]


## Começo do jogo: nome +2 (rotina 4), demais +4 (rotina 6) — como o laço de início de fase.
func release() -> void:
	released = true
	for i in range(4):
		pieces[i][5] += 2 if i == 0 else 4


func done() -> bool:
	for pc in pieces:
		if pc[7]:
			return false
	return true


func step() -> void:
	for i in range(4):
		var pc: Array = pieces[i]
		if not pc[7]:
			continue
		if pc[5] == 2:
			if pc[0] != pc[2]:
				pc[0] += 16 if pc[2] > pc[0] else -16
		else:
			if pc[6] > 0:
				pc[6] -= 1
				continue
			var vis: bool = pc[0] >= 0 and pc[0] < 0x200
			if vis and pc[0] != pc[1]:
				pc[0] += 32 if pc[1] > pc[0] else -32
				continue
			if pc[5] == 4:
				finished_plc = true
			pc[7] = false


## Ordem do hardware: a 1ª peça na lista de sprites fica por cima -> desenhar da última para a primeira.
func draw(ci: CanvasItem) -> void:
	for k in range(pieces.size() - 1, -1, -1):
		var pc: Array = pieces[k]
		if not pc[7] or pc[0] < 0 or pc[0] >= 0x200:
			continue
		sprites.draw(ci, Vector2.ZERO, Vector2(pc[0] - 0x80, pc[3] - 0x80), MAP, pc[4], GFX, 0)
