class_name MonitorObj
extends GameObject
## Monitor: sólido pelos lados/topo; quebra quando o jogador desce rolando sobre ele ou bate
## por baixo (então cai). Conteúdo pelo subtipo: 1 robô, 2 vida, 3 tênis, 4 escudo,
## 5 invencibilidade, 6 dez anéis, 7 "S". Especificação: docs/gameplay/objetos.md#monitor.

const RT_SOLID := 2
const RT_BREAK := 4
const RT_ANIMATE := 6
const RT_DISPLAY := 8
const ANI_TABLE := 0xA508  # Ani_Monitor (ROM), animado nas rotinas 2 e 6 (0xA276)
const ANIMS_FALLBACK := [[1, 0, 1, 2, -1], [1, 0, 3, 3, 1, 3, 3, 2, 3, 3, -1]]


func init() -> bool:
	art = "monitor"
	routine = RT_SOLID
	height = 0xE
	width = 0xE
	act_width = 0xF
	priority = 3
	if respawn_index >= 0:
		var st: int = sim.objects.respawn[respawn_index]
		sim.objects.respawn[respawn_index] = st & 0x7F
		if st & 1:
			routine = RT_DISPLAY
			frame = 0xB
			return false
	col_type = 0x46
	anim = sub
	return true


func update() -> void:
	match routine:
		RT_SOLID:
			_solid()
			_animate()
			_finish()
		RT_BREAK:
			_break_open()
		RT_ANIMATE:
			_animate()
			_finish()
		RT_DISPLAY:
			_finish()


func _animate() -> void:
	var t := RomAnims.table(sim, ANI_TABLE, ANIMS_FALLBACK)
	if anim < t.size():
		ObjAnim.animate(self, t)


func _finish() -> void:
	out_of_range_check(false)


func _solid() -> void:
	var p: Player = sim.player
	if routine2 == 2:
		# jogador em cima
		if not SolidHelpers.exit_platform(self, act_width + 0xB, (act_width + 0xB) * 2):
			SolidHelpers.move_player_on_platform(self, 0x10, x)
		else:
			routine2 = 0
		return
	if routine2 == 4:
		object_fall()
		var fd: Array = sim.terrain.obj_floor_dist(x, y, height, false)
		if fd[0] < 0:
			y = Fx.u16(y + fd[0])
			yv = 0
			routine2 = 0
		return
	var r: Array = _solid_sides(0x1A, 0xF)
	var hit: int = r[0]
	if hit == 0 or (p.yv >= 0 and p.anim == Player.AN_ROLL):
		if status & 0x20:
			p.anim = 0
			p.next_anim = 1
			status &= ~0x20
			p.status &= ~Player.ST_PUSH
		return
	var d0: int = r[1]
	var d3: int = r[2]
	if hit < 0:
		p.y = Fx.u16(p.y - d3)
		SolidHelpers.land_on(self, p)
		routine2 = 2
		return
	if d0 != 0:
		if d0 > 0:
			if p.xv >= 0:
				p.x = Fx.u16(p.x - d0)
				p.gs = 0
				p.xv = 0
		else:
			if p.xv < 0:
				p.x = Fx.u16(p.x - d0)
				p.gs = 0
				p.xv = 0
	if p.status & Player.ST_AIR:
		status &= ~0x20
		p.status &= ~Player.ST_PUSH
		return
	p.status |= Player.ST_PUSH
	status |= 0x20


## Retorna [resultado, d0 (empurrão x), d3 (empurrão y)]: 0 sem contato, 1 lado, -1 topo.
func _solid_sides(d1: int, d2: int) -> Array:
	var p: Player = sim.player
	var d0 := Fx.s16(p.x - x + d1)
	if d0 < 0:
		return [0, 0, 0]
	var d3w := d1 * 2
	if Fx.u16(d0) > Fx.u16(d3w):
		return [0, 0, 0]
	d2 += Fx.s8(p.yr)
	var d3 := Fx.s16(p.y - y + d2)
	if d3 < 0:
		return [0, 0, 0]
	if Fx.u16(d3) >= Fx.u16(d2 * 2):
		return [0, 0, 0]
	if sim.lock_multi_neg or p.routine >= Player.RT_DEATH:
		return [0, 0, 0]
	if not (Fx.u16(d1) >= Fx.u16(d0)):
		d0 -= d1 * 2
	if Fx.u16(d3) < 0x10:
		var w := act_width + 4
		var dd := Fx.s16(w + p.x - x)
		if dd < 0 or Fx.u16(dd) >= Fx.u16(w * 2):
			return [1, d0, d3]
		return [-1, d0, d3]
	return [1, d0, d3]


func touch_item(p: Player) -> void:
	# reação específica de monitor (categoria item, tamanho 6)
	if p.yv < 0:
		var d0 := Fx.u16(p.y - 0x10)
		if d0 < Fx.u16(y):
			return
		p.yv = Fx.s16(-p.yv)
		yv = -0x180
		if routine2 == 0:
			routine2 = 4
		return
	if p.anim != Player.AN_ROLL:
		return
	p.yv = Fx.s16(-p.yv)
	routine = RT_BREAK


func _break_open() -> void:
	routine = RT_ANIMATE
	col_type = 0
	var pu := PowerUpObj.new()
	pu.x = x
	pu.y = y
	pu.anim = anim
	sim.objects.place(pu)
	var ex := ExplosionObj.new()
	ex.x = x
	ex.y = y
	ex.vars["animal"] = false
	ex.vars["no_points"] = true
	sim.objects.place(ex)
	if respawn_index >= 0:
		sim.objects.respawn[respawn_index] |= 1
	anim = 9
	frame = 0xB
