class_name ChopperObj
extends GameObject
## Peixe saltador (ID 0x2B): salta a -0x700 com gravidade 0x18 e volta à altura original.
## Animação: rápida perto da base, lenta no alto, parada no ápice. Confirmado (ROM 0xAB20, anim 0xABB8).

const ANIMS := [[7, 0, 1, -1], [3, 0, 1, -1], [7, 0, -1]]
var home_y: int = 0


func init() -> bool:
	art = "enemy"
	routine = 2
	priority = 4
	col_type = 9
	act_width = 0x10
	yv = -0x700
	home_y = y
	update()
	return false


func update() -> void:
	ObjAnim.animate(self, ANIMS)
	speed_to_pos()
	yv = Fx.s16(yv + 0x18)
	var d0 := home_y
	if Fx.u16(d0) < Fx.u16(y):
		y = d0
		yv = -0x700
	anim = 1
	d0 -= 0xC0
	if not (Fx.u16(d0) >= Fx.u16(y)):
		anim = 0
		if yv >= 0:
			anim = 2
	out_of_range_check()
