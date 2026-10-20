class_name MotobugObj
extends GameObject
## Inimigo terrestre (ID 0x40): cai até o chão; alterna pausa de 60 quadros e patrulha a 0x100,
## virando em bordas/degraus (distância do chão fora de [-8, 12)); solta fumaça a cada 16 quadros.
## Comportamento confirmado na listagem (código em ROM 0xF61A). Animações medidas (tabela 0xF782).

const ANIMS := [[15, 2, -1], [7, 0, 1, 0, 2, -1], [1, 3, 6, 3, 6, 4, 6, 4, 6, 4, 6, 5, -4]]

var smoke_delay: int = 0
var is_smoke: bool = false


func init() -> bool:
	art = "enemy"
	priority = 4
	act_width = 0x14
	if is_smoke:
		art = "smoke"
		routine = 4
		_animate_smoke()
		return false
	height = 0xE
	width = 8
	col_type = 0x0C
	object_fall()
	var fd: Array = sim.terrain.obj_floor_dist(x, y, height, false)
	if fd[0] < 0:
		y = Fx.u16(y + fd[0])
		yv = 0
		routine = 2
		status ^= 1
	else:
		inited = false  # continua na rotina de queda no próximo quadro
	return false


func update() -> void:
	match routine:
		2:
			if routine2 == 0:
				timer -= 1
				if timer < 0:
					routine2 = 2
					xv = -0x100
					anim = 1
					var old := status & 1
					status ^= 1
					if old == 0:
						xv = 0x100
			else:
				speed_to_pos()
				var fd: Array = sim.terrain.obj_floor_dist(x, y, height, false)
				var d: int = fd[0]
				if d < -8 or d >= 0xC:
					routine2 = 0
					timer = 59
					xv = 0
					anim = 0
				else:
					y = Fx.u16(y + d)
					smoke_delay -= 1
					if smoke_delay < 0:
						smoke_delay = 0xF
						var s := MotobugObj.new()
						s.is_smoke = true
						s.kind = 0x40
						s.x = x
						s.y = y
						s.status = status
						s.anim = 2
						sim.objects.place(s)
			ObjAnim.animate(self, ANIMS)
			if out_of_range_check():
				return
		4:
			_animate_smoke()
		6:
			delete()


func _animate_smoke() -> void:
	ObjAnim.animate(self, ANIMS)
