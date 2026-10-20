class_name ObjAnim
extends RefCounted
## Animação genérica de objetos dirigida por script: [duração, quadros..., comando(, arg)].
## Comandos (mesma semântica medida na referência): -1 repetir; -2 n voltar n; -3 id trocar animação;
## -4 avançar rotina (+2); -5 zerar quadro e rotina2; -6 avançar rotina2 (+2).
## Bits 5-6 do quadro no script indicam espelho (combinados com o status do objeto).


static func animate(o: GameObject, scripts: Array) -> void:
	var a := o.anim
	if a != o.vars.get("next_anim", -1):
		o.vars["next_anim"] = a
		o.ani_frame = 0
		o.time_frame = 0
	o.time_frame -= 1
	if o.time_frame >= 0:
		return
	var sc: Array = scripts[a]
	o.time_frame = sc[0]
	var i := o.ani_frame
	var v: int = sc[i + 1]
	if v < 0:
		match v:
			-1:
				o.ani_frame = 0
				v = sc[1]
			-2:
				var back: int = sc[i + 2]
				o.ani_frame -= back
				i -= back
				v = sc[i + 1]
			-3:
				o.anim = sc[i + 2]
				return
			-4:
				o.routine += 2
				return
			-5:
				o.ani_frame = 0
				o.routine2 = 0
				return
			-6:
				o.routine2 += 2
				return
	o.frame = v & 0x1F
	var flip := ((v >> 5) & 3)
	flip = (((flip << 0) & 3) ^ (o.status & 3)) & 3
	o.render = (o.render & ~3) | flip
	o.ani_frame += 1
