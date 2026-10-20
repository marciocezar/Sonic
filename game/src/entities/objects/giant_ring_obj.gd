class_name GiantRingObj
extends GameObject
## Anel gigante (ID 0x4B): presente só com >= 50 anéis e menos de 6 esmeraldas; ao tocar leva ao
## estágio especial. Estágios especiais NÃO estão reconstruídos: o toque gera um evento que o app trata
## seguindo para o próximo ato (registrado como BLOQUEADO na matriz). ROM 0x9E06.


func init() -> bool:
	art = "giant_ring"
	act_width = 0x40
	return true


func update() -> void:
	if routine == 0:
		if (render & 0x80) and sim.emeralds < 6:
			if sim.rings >= 50:
				routine = 2
				priority = 2
				col_type = 0x52
		out_of_range_check(false)
		return
	if routine == 4:
		sim.big_ring_entered = true
		sim.events.append({"type": "special_stage"})
		delete()
		return
	out_of_range_check(false)


func touch_item(p: Player) -> void:
	if p.flash_time >= 90:
		return
	if routine == 2:
		routine = 4
		col_type = 0
