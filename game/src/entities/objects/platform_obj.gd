class_name PlatformObj
extends GameObject
## Plataforma (ID 0x18; GHZ/SYZ/SLZ). Só-topo, meia-largura 0x20; afunda até 4 px sob o jogador
## (seno do ângulo 0..0x40, passos de 4). Tipos (nibble baixo do subtipo): 0 parada; 1/5 horizontal e
## 2/6 vertical pelo oscilador $FE78; 3 cai 30+32 quadros após pisar; 7/8 sobe 0x200 com botão;
## 0xA vertical curta; 0xB/0xC vertical pelo oscilador $FE6C. Confirmado (ROM 0x7E32..0x80F6).

var orig_x: int = 0
var orig_y: int = 0
var base_y: int = 0  # $2C (16.16 com fração em base_ys)
var base_ys: int = 0
var sag: int = 0
var motion: int = 0
var delay: int = 0


func init() -> bool:
	art = "platform"
	routine = 2
	act_width = 0x20
	if sim.level.zone == 3:
		sub = 3
	render |= 4
	priority = 4
	base_y = y
	orig_y = y
	orig_x = x
	motion = 0
	frame = 0
	if sub == 0xA:
		frame = 1
	return true


func update() -> void:
	match routine:
		2:
			if sag != 0:
				sag -= 4
			SolidHelpers.platform_land(self, act_width, y - 8, true)
			_move()
			_nudge()
		4:
			if sag != 0x40:
				sag += 4
			SolidHelpers.exit_platform2(self, act_width, act_width)
			var old_x := x
			_move()
			_nudge()
			var p: Player = sim.player
			if not (sim.lock_multi_neg or p.routine >= Player.RT_DEATH):
				p.y = Fx.u16(y - 9 - p.yr)
				p.x = Fx.u16(p.x - (old_x - x))
		6:
			delete()
			return
		8:
			_move()
			_nudge()
	var d0 := (orig_x & 0xFF80) - ((Fx.u16(sim.camera.x) - 0x80) & 0xFF80)
	if Fx.u16(d0) > 0x280:
		delete()


func _nudge() -> void:
	var s := Trig.sine(sag)
	y = Fx.u16(base_y + ((s * 0x400) >> 16))


func _osc(addr: int) -> int:
	return sim.osc.byte_at(addr)


func _move() -> void:
	var t := sub & 0xF
	match t:
		1, 5:
			var d1 := (motion - 0x40) & 0xFF if t == 1 else ((-motion) + 0x40) & 0xFF
			x = Fx.u16(orig_x + Fx.s8(d1))
			motion = _osc(0xFE78)
		2, 6:
			var d2 := (motion - 0x40) & 0xFF if t == 2 else ((-motion) + 0x40) & 0xFF
			base_y = Fx.u16(orig_y + Fx.s8(d2))
			motion = _osc(0xFE78)
		0xB, 0xC:
			var o := _osc(0xFE6C)
			var d3 := (o - 0x30) & 0xFF if t == 0xB else ((-o) + 0x30) & 0xFF
			base_y = Fx.u16(orig_y + Fx.s8(d3))
			motion = _osc(0xFE78)
		0xA:
			var d4 := Fx.s8((motion - 0x40) & 0xFF) >> 1
			base_y = Fx.u16(orig_y + d4)
			motion = _osc(0xFE78)
		3:
			if delay != 0:
				delay -= 1
				if delay == 0:
					delay = 32
					sub += 1
			elif status & 8:
				delay = 30
		4:
			if delay != 0:
				delay -= 1
				if delay == 0:
					if status & 8:
						var p: Player = sim.player
						p.status |= Player.ST_AIR
						p.status &= ~Player.ST_ON_OBJ
						p.standing_on = null
						p.routine = Player.RT_CONTROL
						status &= ~8
						routine2 = 0
						p.yv = yv
					routine = 8
			var pos := ((base_y << 16) | base_ys) + (yv << 8)
			base_y = (pos >> 16) & 0xFFFF
			base_ys = pos & 0xFFFF
			yv = Fx.s16(yv + 0x38)
			if not (Fx.u16(sim.limit_bottom2 + 0xE0) >= base_y):
				routine = 6
		7:
			if delay != 0:
				delay -= 1
				if delay == 0:
					sub += 1
			elif sim.switches[(sub >> 4) & 0xF] != 0:
				delay = 60
		8:
			base_y = Fx.u16(base_y - 2)
			if Fx.u16(orig_y - 0x200) == base_y:
				sub = 0
