class_name Oscillators
extends RefCounted
## Osciladores globais (16 valores que vão e voltam) usados por plataformas e objetos, e contadores de
## animação sincronizada. Mesmo layout de bytes da referência ($FE5E, 66 bytes) para leituras por byte.
## Parâmetros funcionais medidos: estado inicial (ROM 0x412C) e (passo, limite) por oscilador (ROM 0x41C6).

const INIT := [0x7C, 0x80, 0, 0x80, 0, 0x80, 0, 0x80, 0, 0x80, 0, 0x80, 0, 0x80, 0, 0x80, 0, 0x80, 0,
		0x50F0, 0x11E, 0x2080, 0xB4, 0x3080, 0x10E, 0x5080, 0x1C2, 0x7080, 0x276, 0x80, 0, 0x80, 0]
const PARAMS := [[2, 0x10], [2, 0x18], [2, 0x20], [2, 0x30], [4, 0x20], [8, 8], [8, 0x40], [4, 0x40],
		[2, 0x50], [2, 0x50], [2, 0x20], [3, 0x30], [5, 0x50], [7, 0x70], [2, 0x10], [2, 0x10]]

var ram := PackedByteArray()  # 66 bytes ($FE5E..$FE9F)
var sync := PackedByteArray()  # 10 bytes ($FEC0..$FEC9)


func _init() -> void:
	reset()


func reset() -> void:
	ram.resize(66)
	for i in range(33):
		_w(i * 2, INIT[i])
	sync.resize(10)
	sync.fill(0)


func load_hex(osc_hex: String, sync_hex: String) -> void:
	if osc_hex.length() == 132:
		ram = osc_hex.hex_decode()
	if sync_hex.length() == 20:
		sync = sync_hex.hex_decode()


func _r(o: int) -> int:
	return (ram[o] << 8) | ram[o + 1]


func _w(o: int, v: int) -> void:
	ram[o] = (v >> 8) & 0xFF
	ram[o + 1] = v & 0xFF


## Byte no endereço absoluto $FFxxxx (ex.: 0xFE78).
func byte_at(addr: int) -> int:
	return ram[(addr & 0xFFFF) - 0xFE5E]


func word_at(addr: int) -> int:
	return _r((addr & 0xFFFF) - 0xFE5E)


func update_oscillators() -> void:
	var ctrl := _r(0)
	var a1 := 2
	for i in range(16):
		var bit := 15 - i
		var add: int = PARAMS[i][0]
		var lim: int = PARAMS[i][1]
		var spd := _r(a1 + 2)
		if (ctrl >> bit) & 1 == 0:
			spd = (spd + add) & 0xFFFF
			_w(a1 + 2, spd)
			_w(a1, (_r(a1) + spd) & 0xFFFF)
			if not (lim > ram[a1]):
				ctrl |= 1 << bit
		else:
			spd = (spd - add) & 0xFFFF
			_w(a1 + 2, spd)
			_w(a1, (_r(a1) + spd) & 0xFFFF)
			if not (lim <= ram[a1]):
				ctrl &= ~(1 << bit)
		a1 += 4
	_w(0, ctrl)


## Contadores sincronizados: [0..1] ciclo de 12 (8 quadros), [2..3] anéis (8 em 4), [4..5] 8 em 6,
## [6..9] anéis perdidos (tempo de vida + quadro giratório).
func update_sync() -> void:
	sync[0] = (sync[0] - 1) & 0xFF
	if sync[0] >= 0x80:
		sync[0] = 0xB
		sync[1] = (sync[1] - 1) & 7
	sync[2] = (sync[2] - 1) & 0xFF
	if sync[2] >= 0x80:
		sync[2] = 7
		sync[3] = (sync[3] + 1) & 3
	sync[4] = (sync[4] - 1) & 0xFF
	if sync[4] >= 0x80:
		sync[4] = 7
		sync[5] = sync[5] + 1
		if sync[5] >= 6:
			sync[5] = 0
	if sync[6] != 0:
		var acc := ((sync[8] << 8) | sync[9]) + sync[6]
		acc &= 0xFFFF
		sync[8] = acc >> 8
		sync[9] = acc & 0xFF
		var rolled := ((acc << 7) | (acc >> 9)) & 0xFFFF
		sync[7] = rolled & 3
		sync[6] -= 1


func ring_frame() -> int:
	return sync[3]


func lost_ring_time() -> int:
	return sync[6]


func set_lost_ring_time(v: int) -> void:
	sync[6] = v & 0xFF
