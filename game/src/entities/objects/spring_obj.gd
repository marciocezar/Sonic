class_name SpringObj
extends GameObject
## Mola (ID 0x41). Subtipo: bit 4 lateral, bit 5 para baixo, bit 1 amarela (-0xA00) senão vermelha (-0x1000).
## Para cima/baixo: sólido 0x1B×8; lateral: sólido 0x13×0xE e impulso horizontal com trava de 15 quadros.
## Confirmado (ROM 0xDABE; anim 0xDCFE).

const ANIMS := [[0, 1, 0, 0, 2, 2, 2, 2, 2, 2, 0, -4], [0, 4, 3, 3, 5, 5, 5, 5, 5, 5, 3, -4]]
var power: int = -0x1000


func init() -> bool:
	art = "spring"
	routine = 2
	render |= 4
	act_width = 0x10
	priority = 4
	if sub & 0x10:
		routine = 8
		anim = 1
		frame = 3
		act_width = 8
		vars["dir"] = "side"
	if sub & 0x20:
		routine = 0xE
		status |= 2
		vars["dir"] = "down"
	power = -0xA00 if (sub & 0xF) == 2 else -0x1000
	if (sub & 0xF) != 0 and (sub & 0xF) != 2:
		power = -0x1000
	return false


func update() -> void:
	var p: Player = sim.player
	match routine:
		2:
			SolidHelpers.solid_object(self, 0x1B, 8, 0x10, x)
			if routine2 != 0:
				routine = 4
				p.y = Fx.u16(p.y + 8)
				p.yv = power
				p.status |= Player.ST_AIR
				p.status &= ~Player.ST_ON_OBJ
				p.standing_on = null
				p.anim = Player.AN_SPRING
				p.routine = Player.RT_CONTROL
				status &= ~8
				routine2 = 0
				sim.emit_sfx("spring")
				ObjAnim.animate(self, ANIMS)
		4, 0xA, 0x10:
			ObjAnim.animate(self, ANIMS)
		6:
			vars["next_anim"] = 1
			routine = 2
		8:
			SolidHelpers.solid_object(self, 0x13, 0xE, 0xF, x)
			if routine == 2:
				routine = 8
			if status & 0x20:
				routine = 0xA
				p.xv = power
				p.x = Fx.u16(p.x + 8)
				if (status & 1) == 0:
					p.x = Fx.u16(p.x - 0x10)
					p.xv = Fx.s16(-p.xv)
				p.move_lock = 0xF
				p.gs = p.xv
				p.status ^= Player.ST_LEFT
				if (p.status & Player.ST_ROLL) == 0:
					p.anim = Player.AN_WALK
				status &= ~0x20
				p.status &= ~Player.ST_PUSH
				sim.emit_sfx("spring")
				ObjAnim.animate(self, ANIMS)
		0xC:
			vars["next_anim"] = 2
			routine = 8
		0xE:
			var r := SolidHelpers.solid_object(self, 0x1B, 8, 0x10, x)
			if routine == 2:
				routine = 0xE
			if routine2 == 0 and r < 0:
				routine = 0x10
				p.y = Fx.u16(p.y - 8)
				p.yv = Fx.s16(-power)
				p.status |= Player.ST_AIR
				p.status &= ~Player.ST_ON_OBJ
				p.standing_on = null
				p.routine = Player.RT_CONTROL
				status &= ~8
				routine2 = 0
				sim.emit_sfx("spring")
				ObjAnim.animate(self, ANIMS)
		0x12:
			vars["next_anim"] = 1
			routine = 0xE
	if not deleted:
		out_of_range_check(false)
