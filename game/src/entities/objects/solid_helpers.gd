class_name SolidHelpers
extends RefCounted
## Rotinas compartilhadas de objetos sólidos/plataformas (pousar, sair, mover o jogador junto).


## Pousa o jogador no objeto: zera ângulo e vy, gs = vx, marca "sobre objeto".
## platform=true reproduz o pouso de plataforma (o objeto anterior em rotina 4 volta para 2);
## false reproduz o pouso de objeto sólido (só limpa as flags do anterior).
static func land_on(o: GameObject, p: Player, platform: bool = false) -> void:
	if p.status & Player.ST_ON_OBJ and p.standing_on != null:
		var prev: GameObject = p.standing_on
		prev.status &= ~8
		prev.routine2 = 0
		if platform and prev.routine == 4:
			prev.routine = 2
	p.standing_on = o
	p.angle = 0
	p.yv = 0
	p.gs = p.xv
	if p.status & Player.ST_AIR:
		p.reset_on_floor()
	p.status |= Player.ST_ON_OBJ
	o.status |= 8


## Verifica se o jogador saiu da plataforma. Retorna true se saiu.
static func exit_platform(o: GameObject, half: int, full: int) -> bool:
	var p: Player = o.sim.player
	var out := false
	if p.status & Player.ST_AIR:
		out = true
	else:
		var d0 := Fx.s16(p.x - o.x + half)
		if d0 < 0 or d0 >= full:
			out = true
	if out:
		p.status &= ~Player.ST_ON_OBJ
		if p.standing_on == o:
			p.standing_on = null
		o.status &= ~8
		return true
	return false


## Mantém o jogador sobre o objeto: y = topo - raio; arrasta x pelo deslocamento do objeto.
static func move_player_on_platform(o: GameObject, d3: int, old_x: int) -> void:
	var p: Player = o.sim.player
	if o.sim.lock_multi_neg or p.routine >= Player.RT_DEATH:
		return
	p.y = Fx.u16(o.y - d3 - p.yr)
	p.x = Fx.u16(p.x - (old_x - o.x))


## Objeto sólido genérico. d1 = meia-largura, d2 = meia-altura (ar), d3 = meia-altura (andando),
## old_x = x do objeto antes de se mover neste quadro. Retorna 0 (nada), 1 (lado) ou -1 (topo/baixo).
## "Em pé" é guardado em o.routine2 (mesmo byte da referência) e no bit 3 de status.
static func solid_object(o: GameObject, d1: int, d2: int, d3: int, old_x: int) -> int:
	var p: Player = o.sim.player
	if o.routine2 != 0:
		var full := d1 * 2
		var leave := (p.status & Player.ST_AIR) != 0
		if not leave:
			var dx := Fx.s16(p.x - o.x + d1)
			if dx < 0 or not (Fx.u16(dx) < Fx.u16(full)):
				leave = true
		if leave:
			p.status &= ~Player.ST_ON_OBJ
			if p.standing_on == o:
				p.standing_on = null
			o.status &= ~8
			o.routine2 = 0
			return 0
		move_player_on_platform(o, d3, old_x)
		return 0
	return _solid_enter(o, d1, d2)


static func _solid_enter(o: GameObject, d1: int, d2: int) -> int:
	var p: Player = o.sim.player
	if (o.render & 0x80) == 0:
		return _solid_ignore(o, p)
	var d0 := Fx.s16(p.x - o.x + d1)
	if d0 < 0:
		return _solid_ignore(o, p)
	var d3w := d1 * 2
	if Fx.u16(d0) > Fx.u16(d3w):
		return _solid_ignore(o, p)
	d2 += Fx.s8(p.yr)
	var d3 := Fx.s16(p.y - o.y + 4 + d2)
	if d3 < 0:
		return _solid_ignore(o, p)
	var d4 := d2 * 2
	if Fx.u16(d3) >= Fx.u16(d4):
		return _solid_ignore(o, p)
	if o.sim.lock_multi_neg or p.routine >= Player.RT_DEATH:
		return _solid_ignore(o, p)
	var d5 := d0
	if not (Fx.u16(d1) >= Fx.u16(d0)):
		d0 = d0 - d1 * 2
		d5 = -d0
	var dy := d3
	if not (Fx.u16(d2) >= Fx.u16(d3)):
		d3 = d3 - 4 - d4
		dy = -d3
	if Fx.u16(d5) > Fx.u16(dy):
		return _solid_top_bottom(o, p, d3)
	if Fx.u16(dy) <= 4:
		_not_pushing(o, p)
		return 1
	var center := false
	if d0 == 0:
		center = true
	elif d0 < 0:
		center = p.xv >= 0
	else:
		center = p.xv < 0
	if not center:
		p.gs = 0
		p.xv = 0
	p.x = Fx.u16(p.x - d0)
	if p.status & Player.ST_AIR:
		_not_pushing(o, p)
		return 1
	p.status |= Player.ST_PUSH
	o.status |= 0x20
	return 1


static func _solid_ignore(o: GameObject, p: Player) -> int:
	# só desfaz o "empurrando" se ESTE objeto estava sendo empurrado
	if o.status & 0x20:
		# ROM 0x8AB0: move.w #1,obAnim(a1) — palavra: anim = 0 e next_anim = 1 (reinicia a animação)
		p.anim = 0
		p.next_anim = 1
		_not_pushing(o, p)
	return 0


static func _not_pushing(o: GameObject, p: Player) -> void:
	o.status &= ~0x20
	p.status &= ~Player.ST_PUSH


static func _solid_top_bottom(o: GameObject, p: Player, d3: int) -> int:
	if d3 < 0:
		if p.yv == 0:
			if (p.status & Player.ST_AIR) == 0:
				p.kill()
			return -1
		if p.yv > 0:
			return -1
		if d3 < 0:
			p.y = Fx.u16(p.y - d3)
			p.yv = 0
		return -1
	if Fx.u16(d3) >= 0x10:
		return _solid_ignore(o, p)
	d3 -= 4
	var w := o.act_width
	var dx := Fx.s16(w + p.x - o.x)
	if dx < 0 or not (Fx.u16(dx) < Fx.u16(w * 2)):
		return 0
	if p.yv < 0:
		return 0
	p.y = Fx.u16(p.y - d3 - 1)
	land_on(o, p)
	o.routine2 = 2
	o.status |= 8
	return -1


## Plataforma só-topo: testa pouso por cima (d1 = meia-largura). Retorna true se pousou.
## (O chamador avança sua rotina; esta função ajusta o jogador.)
static func platform_land(o: GameObject, d1: int, top_y: int, check_x: bool = true) -> bool:
	var p: Player = o.sim.player
	if p.yv < 0:
		return false
	if check_x:
		var d0 := Fx.s16(p.x - o.x + d1)
		if d0 < 0 or not (Fx.u16(d0) < Fx.u16(d1 * 2)):
			return false
	var dy := Fx.s16(top_y - (p.y + Fx.s8(p.yr) + 4))
	if dy > 0:
		return false
	if Fx.u16(dy) < 0xFFF0:
		return false
	if o.sim.lock_multi_neg or p.routine >= Player.RT_DEATH:
		return false
	p.y = Fx.u16(p.y + dy + 3)
	o.routine += 2
	land_on(o, p, true)
	return true


## Sai da plataforma? (no ar ou fora de [0, 2·meia-largura)). Se sair: limpa flags e rotina do objeto = 2.
## Retorna true se o jogador continua sobre ela.
static func exit_platform2(o: GameObject, d1: int, d2: int) -> bool:
	var p: Player = o.sim.player
	var full := d2 * 2
	if (p.status & Player.ST_AIR) == 0:
		var d0 := Fx.s16(p.x - o.x + d1)
		if d0 >= 0 and Fx.u16(d0) < Fx.u16(full):
			return true
	p.status &= ~Player.ST_ON_OBJ
	if p.standing_on == o:
		p.standing_on = null
	o.routine = 2
	o.status &= ~8
	return false


## Plataforma só-topo com altura explícita (variante d1/d3 da referência): topo = y - d3.
static func platform_land_h(o: GameObject, d1: int, d3: int) -> bool:
	return platform_land(o, d1, o.y - d3, true)


## Parede sólida só pelos lados/baixo (rotina compartilhada ROM 0x8A62). d1 meia-largura, d2 meia-altura.
static func solid_wall(o: GameObject, d1: int, d2: int) -> void:
	var p: Player = o.sim.player
	var r := _wall_test(o, p, d1, d2)
	var res: int = r[0]
	if res == 0:
		if o.status & 0x20:
			p.anim = 0
			p.next_anim = 1
			o.status &= ~0x20
			p.status &= ~Player.ST_PUSH
		return
	if res < 0:
		var d3: int = r[2]
		if p.yv < 0 and d3 < 0:
			p.y = Fx.u16(p.y - d3)
			p.yv = 0
		return
	var d0: int = r[1]
	if d0 != 0:
		var stop := false
		if d0 > 0:
			stop = p.xv >= 0
		else:
			stop = p.xv < 0
		if stop:
			p.x = Fx.u16(p.x - d0)
			p.gs = 0
			p.xv = 0
	if p.status & Player.ST_AIR:
		o.status &= ~0x20
		p.status &= ~Player.ST_PUSH
		return
	p.status |= Player.ST_PUSH
	o.status |= 0x20


static func _wall_test(o: GameObject, p: Player, d1: int, d2: int) -> Array:
	var d0 := Fx.s16(p.x - o.x + d1)
	if d0 < 0 or Fx.u16(d0) > Fx.u16(d1 * 2):
		return [0, 0, 0]
	d2 += Fx.s8(p.yr)
	var d3 := Fx.s16(p.y - o.y + d2)
	if d3 < 0:
		return [0, 0, 0]
	var d4 := d2 * 2
	if Fx.u16(d3) >= Fx.u16(d4):
		return [0, 0, 0]
	if o.sim.lock_multi_neg or p.routine >= Player.RT_DEATH:
		return [0, 0, 0]
	var d5 := d0
	if not (Fx.u16(d1) >= Fx.u16(d0)):
		d0 -= d1 * 2
		d5 = -d0
	var dy := d3
	if not (Fx.u16(d2) >= Fx.u16(d3)):
		d3 -= d4
		dy = -d3
	if Fx.u16(d5) > Fx.u16(dy):
		return [-1, d0, d3]
	return [1, d0, d3]
