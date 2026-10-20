class_name RingLossObj
extends GameObject
## Anel perdido após dano: quica com gravidade 0x18, verifica o chão a cada 4 quadros
## (fase depende do slot), expira quando o temporizador global zera.


var loader: bool = false


func _init() -> void:
	kind = 0x37


func init() -> bool:
	kind = 0x37
	init_ring()
	if loader:
		loader = false
		sim.objects.ring_loss_spawn(self)
	return true


func init_ring() -> void:
	kind = 0x37
	art = "ring"
	col_type = 0x47
	act_width = 8
	height = 8
	width = 8
	priority = 3
	routine = 2


func update() -> void:
	match routine:
		2:
			frame = sim.objects.sync_ring_frame
			speed_to_pos()
			yv = Fx.s16(yv + 0x18)
			if yv >= 0:
				var d7 := 0x7F - slot
				if ((sim.vbla_count + d7) & 3) == 0:
					var fd: Array = sim.terrain.obj_floor_dist(x, y, height, false)
					if fd[0] < 0:
						y = Fx.u16(y + fd[0])
						var v := yv >> 2
						yv = Fx.s16(-(yv - v))
			if sim.objects.ring_loss_timer == 0:
				delete()
				return
			if Fx.u16(sim.limit_bottom2 + 0xE0) < y:
				delete()
		4:
			routine = 6
			col_type = 0
			priority = 1
			sim.add_rings(1)
			ObjAnim.animate(self, RingObj.SPARKLE)
		6:
			ObjAnim.animate(self, RingObj.SPARKLE)
		8:
			delete()


func touch_item(p: Player) -> void:
	if p.flash_time >= 90:
		return
	if routine == 2:
		routine = 4
