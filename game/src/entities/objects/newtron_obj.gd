class_name NewtronObj
extends GameObject
## Camaleão (ID 0x42). Aparece quando o jogador está a < 0x80 px (vira para ele). Tipo 0: após aparecer
## cai, pousa e corre a 0x200 seguindo o chão (sai do chão → segue reto). Tipo 1: aparece, dispara um
## míssil (subtipo 1) no quadro 2 da animação e some ao fim dela. ROM 0xDD68; anim 0xDF1A.

const ANIMS := [[15, 0xA, -1], [19, 0, 1, 3, 4, 5, -2, 1], [2, 6, 7, -1], [2, 8, 9, -1],
		[19, 0, 1, 1, 2, 1, 1, 0, -4]]
var fired: bool = false
var alt_palette: bool = false


func init() -> bool:
	art = "enemy"
	routine = 2
	render |= 4
	priority = 4
	act_width = 0x14
	height = 0x10
	width = 8
	return true


func update() -> void:
	if routine == 4:
		delete()
		return
	var p: Player = sim.player
	match routine2:
		0:
			status |= 1
			var d0 := Fx.u16(p.x - x)
			if Fx.u16(p.x) < Fx.u16(x):
				d0 = Fx.u16(x - p.x)
				status &= ~1
			if d0 < 0x80:
				routine2 = 2
				anim = 1
				if sub != 0:
					alt_palette = true
					routine2 = 8
					anim = 4
		2:
			if frame < 4:
				status |= 1
				if Fx.u16(p.x) < Fx.u16(x):
					status &= ~1
			else:
				if frame == 1:
					col_type = 0xC
				object_fall()
				var fd: Array = sim.terrain.obj_floor_dist(x, y, height, false)
				if fd[0] < 0:
					y = Fx.u16(y + fd[0])
					yv = 0
					routine2 = 4
					anim = 2
					if alt_palette:
						anim = 3
					col_type = 0xD
					xv = 0x200
					if (status & 1) == 0:
						xv = -0x200
		4:
			speed_to_pos()
			var fd2: Array = sim.terrain.obj_floor_dist(x, y, height, false)
			if fd2[0] < -8 or fd2[0] >= 0xC:
				routine2 = 6
			else:
				y = Fx.u16(y + fd2[0])
		6:
			speed_to_pos()
		8:
			if frame == 1:
				col_type = 0xC
			if frame == 2 and not fired:
				fired = true
				var m := MissileObj.new()
				m.from_newtron = true
				m.x = x
				m.y = Fx.u16(y - 8)
				m.xv = 0x200
				var dx := 0x14
				if (status & 1) == 0:
					dx = -dx
					m.xv = -0x200
				m.x = Fx.u16(m.x + dx)
				m.status = status
				m.sub = 1
				sim.objects.place(m)
	ObjAnim.animate(self, ANIMS)
	out_of_range_check()
