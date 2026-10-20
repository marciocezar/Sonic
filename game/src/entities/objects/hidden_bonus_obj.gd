class_name HiddenBonusObj
extends GameObject
## Bônus escondido (ID 0x7D): ao entrar na caixa 32x32, soma pontos (subtipo 1: 1000, 2: 100, 3: 1, em
## unidades de 10) e exibe por 120 quadros. Tabela de pontos medida (ROM 0x17212).

const POINTS := [0, 1000, 100, 1]


func init() -> bool:
	art = "bonus"
	return true


func update() -> void:
	if routine == 0:
		var p: Player = sim.player
		var d0 := Fx.u16(p.x - x + 0x10)
		var d1 := Fx.u16(p.y - y + 0x10)
		if d0 < 0x20 and d1 < 0x20 and not sim.big_ring_entered:
			routine = 2
			priority = 0
			act_width = 0x10
			frame = sub
			timer = 119
			sim.emit_sfx("bonus")
			sim.add_score(POINTS[sub & 3])
			return
		out_of_range_check(false)
		return
	timer -= 1
	if timer < 0:
		delete()
		return
	out_of_range_check(false)
