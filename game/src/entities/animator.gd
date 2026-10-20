class_name Animator
extends RefCounted
## Animação do personagem dirigida por scripts (formato: [duração, quadros..., comando]).
## Comandos: -1 (0xFF) repetir; -2 (0xFE) n voltar n quadros; -3 (0xFD) id trocar para animação id.
## Os scripts padrão são próprios do projeto; um pacote privado pode substituí-los (modo Fidelity).
## Animações "andar/correr/rolar/empurrar" têm duração dependente da velocidade (marcador -1 inicial).

const SPEED_WALKRUN := -1
const SPEED_ROLL := -2
const SPEED_PUSH := -3

var scripts: Dictionary = {
	0: [SPEED_WALKRUN, 8, 9, 10, 11, 6, 7, -1],
	1: [SPEED_WALKRUN, 0x1E, 0x1F, 0x20, 0x21, -1],
	2: [SPEED_ROLL, 0x3D, 0x3E, 0x3F, 0x40, -1],
	3: [SPEED_ROLL, 0x3D, 0x3E, 0x41, 0x3F, 0x40, -1],
	4: [SPEED_PUSH, 0x48, 0x49, 0x4A, 0x4B, -1],
	5: [0x17, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 2, 2, 2, 3, 4, -2, 2],
	6: [0x1F, 0x3A, 0x3B, -1],
	7: [0x3F, 5, -1],
	8: [0x3F, 0x39, -1],
	0x0D: [7, 0x37, 0x38, -1],
	0x10: [0x2F, 0x5A, -3, 0],
	0x17: [0x2F, 0x5D, -1],
	0x18: [3, 0x5C, -1],
	0x19: [3, 0x55, -1],
}
var walk_frames: Array = [8, 9, 10, 11, 6, 7]
var run_frames: Array = [0x1E, 0x1F, 0x20, 0x21]


const ROM_SCRIPTS := 0x13B48  # tabela de roteiros do Sonic (palavras de deslocamento), 31 animações
const ROM_WALK := 0x13B86
const ROM_RUN := 0x13B8E
const ROM_ROLL := 0x13B96
const ROM_ROLL_FAST := 0x13B9E
const ROM_PUSH := 0x13BA6
const ROM_ANIMS := 31

## Roteiros em bytes, exatamente como na ROM (0xFF repetir, 0xFE n voltar, 0xFD id trocar animação).
var raw: Dictionary = {}
var walk_s := PackedByteArray()
var run_s := PackedByteArray()
var roll_s := PackedByteArray()
var roll_fast_s := PackedByteArray()
var push_s := PackedByteArray()


func _init() -> void:
	# reserva própria (sem ROM): converte os roteiros do projeto para o formato em bytes
	for k in scripts.keys():
		raw[k] = _to_bytes(scripts[k])
	walk_s = _to_bytes([SPEED_WALKRUN] + walk_frames + [-1])
	run_s = _to_bytes([SPEED_WALKRUN] + run_frames + [-1])
	roll_s = raw[2]
	roll_fast_s = raw[3]
	push_s = raw[4]


static func _to_bytes(sc: Array) -> PackedByteArray:
	var b := PackedByteArray()
	for v in sc:
		b.append(int(v) & 0xFF)
	return b


## Roteiros reais do jogo, lidos da ROM do usuário (rotina Sonic_Animate 0x139C4, evidência EV-ANI).
func use_rom(rom: PackedByteArray) -> void:
	raw.clear()
	for i in range(ROM_ANIMS):
		var s := ROM_SCRIPTS + ((rom[ROM_SCRIPTS + i * 2] << 8) | rom[ROM_SCRIPTS + i * 2 + 1])
		raw[i] = rom.slice(s, s + 48)
	walk_s = rom.slice(ROM_WALK, ROM_WALK + 8)
	run_s = rom.slice(ROM_RUN, ROM_RUN + 8)
	roll_s = rom.slice(ROM_ROLL, ROM_ROLL + 8)
	roll_fast_s = rom.slice(ROM_ROLL_FAST, ROM_ROLL_FAST + 8)
	push_s = rom.slice(ROM_PUSH, ROM_PUSH + 8)


func load_override(d: Dictionary) -> void:
	for k in d.keys():
		scripts[int(k)] = d[k]
		raw[int(k)] = _to_bytes(d[k])


## Porte de Sonic_Animate (0x139C4).
func animate_player(p: Player) -> void:
	var a := p.anim
	if a != p.next_anim:
		p.next_anim = a
		p.ani_frame = 0
		p.time_frame = 0
	var sc: PackedByteArray = raw.get(a, PackedByteArray([0x3F, 1, 0xFF]))
	var d0: int = sc[0]
	if d0 < 0x80:
		p.render = (p.render & ~3) | (p.status & 1)
		p.time_frame -= 1
		if p.time_frame >= 0:
			return
		p.time_frame = d0
		_step_raw(p, sc)
		return
	p.time_frame -= 1
	if p.time_frame >= 0:
		return
	var gs: int = Fx.s16(p.gs)
	var g: int = absi(gs)
	if d0 == 0xFF:
		var ang: int = p.angle & 0xFF
		var facing: int = p.status & 1
		if facing == 0:
			ang = (~ang) & 0xFF
		ang = (ang + 0x10) & 0xFF
		var d1 := 3 if ang & 0x80 else 0
		p.render = (p.render & ~3) | ((d1 ^ facing) & 3)
		if p.status & Player.ST_PUSH:
			_push_raw(p, gs)
			return
		var sector := (ang >> 4) & 6
		var tbl := run_s
		if g < 0x600:
			tbl = walk_s
			sector += sector >> 1
		var d3 := (sector * 2) & 0xFF
		p.time_frame = maxi(0x800 - g, 0) >> 8
		_step_raw(p, tbl)
		p.frame = (p.frame + d3) & 0xFF
	elif d0 == 0xFE:
		var tbl2 := roll_fast_s if g >= 0x600 else roll_s
		p.time_frame = maxi(0x400 - g, 0) >> 8
		p.render = (p.render & ~3) | (p.status & 1)
		_step_raw(p, tbl2)
	else:
		_push_raw(p, gs)


func _push_raw(p: Player, gs: int) -> void:
	var d2 := gs if gs < 0 else -gs
	p.time_frame = maxi(d2 + 0x800, 0) >> 6
	p.render = (p.render & ~3) | (p.status & 1)
	_step_raw(p, push_s)


## 0x13A0C: avança um quadro do roteiro.
func _step_raw(p: Player, sc: PackedByteArray) -> void:
	var d1: int = p.ani_frame & 0xFF
	var v: int = sc[1 + d1] if 1 + d1 < sc.size() else 0xFF
	if v < 0x80:
		p.frame = v
		p.ani_frame = (p.ani_frame + 1) & 0xFF
		return
	if v == 0xFF:
		p.ani_frame = 1
		p.frame = sc[1]
		return
	if v == 0xFE:
		var back: int = sc[2 + d1]
		p.ani_frame = (p.ani_frame - back) & 0xFF
		d1 = (d1 - back) & 0xFF
		p.frame = sc[1 + d1]
		p.ani_frame = (p.ani_frame + 1) & 0xFF
		return
	if v == 0xFD:
		p.anim = sc[2 + d1]
