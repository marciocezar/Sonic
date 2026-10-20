class_name CrabmeatObj
extends GameObject
## Inimigo caranguejo (ID 0x1F): pausa 60 quadros e anda 128 quadros a 0x80; nas pausas, se visível,
## alterna disparar 2 projéteis (vx ±0x100, vy -0x400, gravidade). Animação escolhida pelo ângulo do chão.
## Confirmado na listagem (ROM 0x94F0). Projétil: rotinas 6/8 do mesmo ID.

const ANIMS := [[15, 0, -1], [15, 2, -1], [15, 0x22, -1], [15, 1, 0x21, 0, -1], [15, 0x21, 3, 2, -1],
		[15, 1, 0x23, 0x22, -1], [15, 4, -1], [1, 5, 6, -1]]

var is_ball: bool = false
var angle: int = 0
var toggle: int = 0


func init() -> bool:
	priority = 3
	if is_ball:
		art = "projectile"
		routine = 8
		col_type = 0x87
		act_width = 8
		yv = -0x400
		anim = 7
		_ball()
		return false
	art = "enemy"
	height = 0x10
	width = 8
	col_type = 6
	act_width = 0x15
	object_fall()
	var fd: Array = sim.terrain.obj_floor_dist(x, y, height, false)
	if fd[0] < 0:
		y = Fx.u16(y + fd[0])
		angle = fd[1]
		yv = 0
		routine = 2
	else:
		inited = false
	return false


func _set_anim_by_angle() -> int:
	var a := angle
	if a < 0x80:
		if a < 6:
			return 0
		return 1 if status & 1 else 2
	if a > 0xFA:
		return 0
	return 2 if status & 1 else 1


func update() -> void:
	match routine:
		2:
			if routine2 == 0:
				timer -= 1
				if timer < 0:
					var fire := false
					if render & 0x80:
						var old := toggle & 2
						toggle ^= 2
						fire = old != 0
					if fire:
						timer = 0x3B
						anim = 6
						_spawn_ball(-0x10, -0x100)
						_spawn_ball(0x10, 0x100)
					else:
						routine2 = 2
						timer = 0x7F
						xv = 0x80
						anim = _set_anim_by_angle() + 3
						var old2 := status & 1
						status ^= 1
						if old2 == 0:
							xv = -0x80
			else:
				timer -= 1
				if timer < 0:
					_stop()
				else:
					speed_to_pos()
					var old3 := toggle & 1
					toggle ^= 1
					if old3 == 0:
						var px := x + 0x10
						if status & 1:
							px -= 0x20
						var fd: Array = sim.terrain.obj_floor_dist(px, y, height, false)
						if fd[0] < -8 or fd[0] >= 0xC:
							_stop()
					else:
						var fd2: Array = sim.terrain.obj_floor_dist(x, y, height, false)
						y = Fx.u16(y + fd2[0])
						angle = fd2[1]
						anim = _set_anim_by_angle() + 3
			ObjAnim.animate(self, ANIMS)
			out_of_range_check()
		8:
			_ball()


func _stop() -> void:
	routine2 = 0
	timer = 0x3B
	xv = 0
	anim = _set_anim_by_angle()


func _spawn_ball(dx: int, vx: int) -> void:
	var b := CrabmeatObj.new()
	b.is_ball = true
	b.kind = 0x1F
	b.x = Fx.u16(x + dx)
	b.y = y
	b.xv = vx
	sim.objects.place(b)


func _ball() -> void:
	ObjAnim.animate(self, ANIMS)
	object_fall()
	if Fx.u16(sim.limit_bottom2 + 0xE0) < y:
		delete()
