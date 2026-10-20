class_name LedgeObj
extends GameObject
## Plataforma que desmorona de GHZ (ID 0x1A, ROM 0x8210; rotinas 0x822A/0x8266/0x828A/0x82BA/0x831A/0x829C).
## Topo inclinado por tabela de alturas (ROM 0x8570, 48 entradas; pouso 0x7520, movimento 0x852A).
## Ao ser pisada, conta 7 quadros ($38) e se desfaz em 25 fragmentos (0x847A): cada fragmento é UMA peça do
## mapeamento (render bit 5, ponteiro direto para a peça) com atraso próprio (tabela 0x8500) antes de cair.

const MAP := 0x85A0
const HEIGHTS := 0x8570
const DELAYS := 0x8500
const N_FRAGMENTS := 0x18

var touched: bool = false  # $3A


func init() -> bool:
	routine = 2
	map_addr = MAP
	gfx = 0x4000
	render |= 4
	priority = 4
	timer = 7
	act_width = 0x64
	frame = sub
	height = 0x38
	render |= 0x10
	_routine_idle()
	return false


func update() -> void:
	match routine:
		2:
			_routine_idle()
		4:
			_routine_standing()
		6:
			_routine_fragment()
		8:
			delete()
		0xA:
			_hold_player()


func _rom() -> PackedByteArray:
	return sim.level.rom


func _height_at(i: int) -> int:
	var r := _rom()
	if r.size() == 0x80000:
		return r[HEIGHTS + clampi(i, 0, 0x5F)]
	return 0x20


## 0x8266: parada; se já foi tocada e o tempo acabou, desmorona.
func _routine_idle() -> void:
	if touched:
		if timer == 0:
			touched = false
			_collapse()
			return
		timer -= 1
	_land_slope(0x30)
	_range_display()


## 0x828A: jogador em cima.
func _routine_standing() -> void:
	if timer == 0:
		_collapse()
		return
	touched = true
	timer -= 1
	_hold_player()
	_range_display()


## 0x829C: sai da plataforma? senão acompanha a altura do topo.
func _hold_player() -> void:
	if not _exit_check(0x30):
		_move_player_slope(0x30)


## 0x75C0: no ar ou fora de [0, 2*d1): solta o jogador e volta à rotina 2.
func _exit_check(d1: int) -> bool:
	var p: Player = sim.player
	if (p.status & Player.ST_AIR) == 0:
		var d0 := Fx.s16(p.x - x + d1)
		if d0 >= 0 and Fx.u16(d0) < Fx.u16(d1 * 2):
			return false
	p.status &= ~Player.ST_ON_OBJ
	if p.standing_on == self:
		p.standing_on = null
	routine = 2
	status &= ~8
	return true


## 0x7520: pouso por cima usando a altura da coluna sob o jogador.
func _land_slope(d1: int) -> void:
	var p: Player = sim.player
	if p.yv < 0:
		return
	var d0 := Fx.s16(p.x - x + d1)
	if d0 < 0 or Fx.u16(d0) >= Fx.u16(d1 * 2):
		return
	if render & 1:
		d0 = Fx.s16(~d0 + d1 * 2)
	var h := _height_at(Fx.u16(d0) >> 1)
	SolidHelpers.platform_land(self, d1, Fx.u16(y - h), false)


## 0x852A: mantém o jogador no topo inclinado (x da plataforma não muda).
func _move_player_slope(d1: int) -> void:
	var p: Player = sim.player
	if (p.status & Player.ST_ON_OBJ) == 0:
		return
	var d0 := Fx.u16(p.x - x + d1) >> 1
	if render & 1:
		d0 = Fx.u16(~d0 + d1) & 0xFFFF
	var h := _height_at(d0)
	p.y = Fx.u16(y - h - p.yr)


## 0x82BA: fragmento — espera o atraso; o fragmento sob o jogador o solta quando cai.
func _routine_fragment() -> void:
	if timer == 0:
		object_fall()
		if (render & 0x80) == 0:
			delete()
		return
	if not touched:
		timer -= 1
		return
	timer -= 1
	_hold_player()
	var p: Player = sim.player
	if p.status & Player.ST_ON_OBJ:
		if timer != 0:
			return
		p.status &= ~(Player.ST_ON_OBJ | Player.ST_PUSH)
		p.standing_on = null
		p.next_anim = 1
	touched = false
	routine = 6


## 0x847A: desmonta em fragmentos, um por peça do mapeamento do quadro atual.
func _collapse() -> void:
	frame = (frame + 2) & 0xFF
	var r := _rom()
	var piece := 0
	if r.size() == 0x80000:
		piece = MAP + ((r[MAP + frame * 2] << 8) | r[MAP + frame * 2 + 1]) + 1
	render |= 0x20
	for i in range(N_FRAGMENTS + 1):
		var f: LedgeObj = self
		if i > 0:
			f = LedgeObj.new()
			f.kind = kind
			f.respawn_index = -1
			f.height = 0  # obHeight não é copiado para os fragmentos
			if sim.objects.place(f, ObjectManager.FIRST_LEVEL_SLOT, true) == null:
				break
			piece += 5
		f.routine = 6
		f.map_addr = piece
		f.render = render
		f.x = x
		f.y = y
		f.gfx = gfx
		f.priority = priority
		f.act_width = act_width
		f.timer = r[DELAYS + i] if r.size() == 0x80000 else 4 + i
		f.touched = f == self and touched
	sim.emit_sfx("collapse")
	_range_display()


## 0xF6AC: fora da janela -> libera recarga e remove.
func _range_display() -> void:
	out_of_range_check(true)
