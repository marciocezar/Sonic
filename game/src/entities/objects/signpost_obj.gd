class_name SignpostObj
extends GameObject
## Placa de fim de ato (ID 0x0D). Ao passar (0 <= jogador.x - x < 0x20): para o tempo e trava a câmera;
## gira 3 ciclos de 60 quadros soltando brilhos; trava controles com "direita" até o jogador sair pela
## direita (limite + 0x128); então calcula bônus: tempo (tabela medida, índice (min·60+s)/15) e anéis×10.
## Confirmado (ROM 0xEB28; bônus em 0xECF0; posições dos brilhos em 0xEC44).

const TIME_BONUS := [5000, 5000, 1000, 500, 400, 400, 300, 300, 200, 200, 200, 200, 100, 100, 100, 100, 50, 50, 50, 50, 0]
const SPARKLES := [[-24, -16], [8, 8], [-16, 0], [24, -8], [0, -8], [16, 0], [-24, 8], [24, 16]]

var spin_time: int = 0
var sparkle_time: int = 0
var sparkle_id: int = 0


func init() -> bool:
	art = "signpost"
	routine = 2
	act_width = 0x18
	priority = 4
	return true


func update() -> void:
	var p: Player = sim.player
	match routine:
		2:
			var d0 := p.x - x
			if d0 >= 0 and d0 < 0x20:
				sim.emit_sfx("signpost")
				sim.time_running = false
				sim.limit_left2 = sim.limit_right2
				routine = 4
		4:
			timer += 1
			spin_time -= 1
			if spin_time < 0:
				spin_time = 60
				anim += 1
				if anim == 3:
					routine = 6
			sparkle_time -= 1
			if sparkle_time < 0:
				sparkle_time = 0xB
				var sp: Array = SPARKLES[sparkle_id >> 1]
				sparkle_id = (sparkle_id + 2) & 0xE
				var r := RingObj.new()
				r.kind = 0x25
				r.routine = 6
				r.x = Fx.u16(x + int(sp[0]))
				r.y = Fx.u16(y + int(sp[1]))
				r.art = "ring"
				r.priority = 2
				r.act_width = 8
				sim.objects.place(r)
		6:
			if (p.status & Player.ST_AIR) == 0:
				sim.lock_ctrl = true
				sim.forced_hold = Player.IN_RIGHT
			if p.routine != Player.RT_DEATH and p.x < Fx.u16(sim.limit_right2 + 0x128):
				pass
			else:
				routine = 8
				_got_through()
		8:
			pass
	var d := (x & 0xFF80) - ((Fx.u16(sim.camera.x) - 0x80) & 0xFF80)
	if Fx.u16(d) > 0x280:
		delete()


func _got_through() -> void:
	if sim.level_complete:
		return
	sim.limit_left2 = sim.limit_right2
	sim.invincible = false
	sim.time_running = false
	var secs: int = sim.time_min * 60 + sim.time_sec
	var idx := mini(secs / 15, 20)
	sim.time_bonus = TIME_BONUS[idx]
	sim.ring_bonus = sim.rings * 10
	sim.level_complete = true
	sim.emit_music("gotthrough")
