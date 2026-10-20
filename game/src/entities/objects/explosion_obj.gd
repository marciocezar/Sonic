class_name ExplosionObj
extends GameObject
## Explosão de inimigo destruído (substitui o inimigo no mesmo slot). Rotina 0: cria animal (busca de
## slot livre); depois 5 quadros de 8 ticks e se apaga. Variante sem animal para monitores/bombas.


func _init() -> void:
	kind = 0x27


func init() -> bool:
	kind = 0x27
	art = "explosion"
	if vars.get("animal", false):
		var a := AnimalObj.new()
		a.x = x
		a.y = y
		a.vars["points_frame"] = int(vars.get("points_frame", 0))
		sim.objects.place(a)
	col_type = 0
	act_width = 0xC
	priority = 1
	time_frame = 7
	frame = 0
	sim.emit_sfx("explode")
	return true


func update() -> void:
	time_frame -= 1
	if time_frame >= 0:
		return
	time_frame = 7
	frame += 1
	if frame == 5:
		delete()
