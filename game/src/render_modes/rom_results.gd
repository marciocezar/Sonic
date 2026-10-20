class_name RomResults
extends RefCounted
## Resultados do ato (objeto 0x3A, ROM 0xC572): 7 peças (tabela 0xC776: x inicial, x final, y, rotina, quadro;
## quadro 6 = "ACT"+ato), mapeamento 0xCBD8, arte 0x8580. A placa recarrega a arte do cartão (PLC 16, 0xECA4).
## A peça "RING BONUS" (quadro 4) controla: espera 180 quadros, transfere 10 pontos por quadro de cada bônus
## (som 0xCD a cada 4 quadros, 0xC5 no fim), espera 180 e passa de fase (0xC6AE). Dígitos dos bônus em VRAM 0xAE00
## (rotina 0x1CA0C: 4 dígitos, zeros à esquerda em branco).

const MAP := 0xCBD8
const GFX := 0x8580
const TABLE := 0xC776

var hud: RomHud
var pieces: Array = []  # [x, start, target, y, routine, frame, timer]
var time_bonus: int = 0
var ring_bonus: int = 0
var finished := false


func _init(rom: PackedByteArray, h: RomHud, card_vram: PackedByteArray, act: int, tb: int, rb: int) -> void:
	hud = h
	time_bonus = tb
	ring_bonus = rb
	for i in range(0xB000, 0xC000):
		hud.vram[i] = card_vram[i]
	for i in range(7):
		var a := TABLE + i * 8
		var start := Fx.s16((rom[a] << 8) | rom[a + 1])
		var target := Fx.s16((rom[a + 2] << 8) | rom[a + 3])
		var y := (rom[a + 4] << 8) | rom[a + 5]
		var fr: int = rom[a + 7]
		if fr == 6:
			fr += act
		pieces.append([start, start, target, y, rom[a + 6], fr, 0])
	_write_bonus()


func _write_bonus() -> void:
	_bonus_digits(0xAE00, time_bonus)
	_bonus_digits(0xAE00 + 4 * 64, ring_bonus)
	hud.sprites.clear_cache()


func _bonus_digits(dst: int, value: int) -> void:
	var seen := false
	for i in range(4):
		var p := int(pow(10, 3 - i))
		var d := (value / p) % 10
		if d != 0:
			seen = true
		if seen:
			for k in range(64):
				hud.vram[dst + i * 64 + k] = hud.rom[RomHud.ART_HUD + d * 64 + k]
		else:
			for k in range(64):
				hud.vram[dst + i * 64 + k] = 0


func step(sim) -> void:
	for pc in pieces:
		match pc[4]:
			2:
				if pc[0] != pc[2]:
					pc[0] += 16 if pc[2] > pc[0] else -16
				elif pc[5] == 4:
					pc[4] = 4
					pc[6] = 180
			4, 8:
				pc[6] -= 1
				if pc[6] == 0:
					pc[4] += 2
			6:
				var d0 := 0
				if time_bonus > 0:
					d0 += 10
					time_bonus -= 10
				if ring_bonus > 0:
					d0 += 10
					ring_bonus -= 10
				if d0 == 0:
					sim.emit_sfx("till")
					pc[4] = 8
					pc[6] = 180
				else:
					sim.add_score(d0)
					if (sim.framecount & 3) == 0:
						sim.emit_sfx("count")
				_write_bonus()
			0xA:
				finished = true


func draw(ci: CanvasItem) -> void:
	for k in range(pieces.size() - 1, -1, -1):
		var pc: Array = pieces[k]
		if pc[0] < 0 or pc[0] >= 0x200:
			continue
		hud.sprites.draw(ci, Vector2.ZERO, Vector2(pc[0] - 0x80, pc[3] - 0x80), MAP, pc[5], GFX, 0)
