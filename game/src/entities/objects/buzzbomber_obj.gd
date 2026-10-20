class_name BuzzBomberObj
extends GameObject
## Vespa (ID 0x22): paira e voa a 0x400 por 128 quadros; perto do jogador (< 0x60 px, visível) para e
## dispara um míssil (0x23) após 30 quadros. Confirmado (ROM 0x97DE; anim 0x9A18).

const ANIMS := [[1, 0, 1, -1], [1, 2, 3, -1], [1, 4, 5, -1]]
var buzz_status: int = 0


func init() -> bool:
	art = "enemy"
	routine = 2
	priority = 3
	col_type = 8
	act_width = 0x18
	return true


func update() -> void:
	if routine2 == 0:
		timer -= 1
		if timer < 0:
			if buzz_status & 2:
				_fire()
			else:
				routine2 = 2
				timer = 127
				xv = 0x400
				anim = 1
				if (status & 1) == 0:
					xv = -0x400
	else:
		timer -= 1
		if timer < 0:
			buzz_status = 0
			status ^= 1
			timer = 59
			_stop()
		else:
			speed_to_pos()
			if buzz_status == 0:
				var d := absi(Fx.s16(sim.player.x - x))
				if d < 0x60 and (render & 0x80):
					buzz_status = 2
					timer = 29
					_stop()
	ObjAnim.animate(self, ANIMS)
	out_of_range_check()


func _stop() -> void:
	routine2 = 0
	xv = 0
	anim = 0


func _fire() -> void:
	var m := MissileObj.new()
	m.kind = 0x23
	m.x = x
	m.y = Fx.u16(y + 0x1C)
	m.yv = 0x200
	m.xv = 0x200
	var dx := 0x18
	if (status & 1) == 0:
		dx = -dx
		m.xv = -0x200
	m.x = Fx.u16(m.x + dx)
	m.status = status
	m.timer = 0xE
	m.parent = self
	if sim.objects.place(m) == null:
		return
	buzz_status = 1
	timer = 0x3B
	anim = 2
