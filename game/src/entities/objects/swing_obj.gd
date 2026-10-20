class_name SwingObj
extends GameObject
## Plataforma balançante (ID 0x15; GHZ/MZ). Subtipo: bits 0-3 = elos da corrente, bit 4 = bola com espinhos
## (machuca, 0x81). Ângulo = oscilador $FE78 (espelhado se status bit 0). Posições por seno/cosseno do
## raio de cada elo. Plataforma só-topo de meia-largura 0x18, altura 8. Confirmado (ROM 0x7952..0x7C3C).

var links: Array = []
var orig_x: int = 0
var orig_y: int = 0
var radius: int = 0
var is_link: bool = false


func init() -> bool:
	if is_link:
		routine = 0xA
		return false
	art = "swing"
	routine = 2
	render = (render & ~0x7F) | 4 | (render & 3)
	priority = 3
	act_width = 0x18
	height = 8
	orig_y = y
	orig_x = x
	var z: int = sim.level.zone
	var s0 := sub
	var n := s0 & 0xF
	sub = 0
	var d3 := n * 16 + 8
	radius = d3 & 0xFF
	d3 -= 8
	var count := n
	if frame != 0:
		d3 += 8
		count -= 1
	links.clear()
	for _i in range(maxi(count + 1, 0)):
		var lk := SwingObj.new()
		lk.is_link = true
		lk.kind = kind
		lk.art = "chain"
		lk.priority = 4
		lk.act_width = 8
		lk.frame = 1
		lk.radius = d3 & 0xFF
		var nd := d3 - 0x10
		if nd < 0:
			lk.frame = 2
			lk.priority = 3
		d3 = nd & 0xFF if nd >= 0 else (nd & 0xFF)
		if z == 0:
			# medido (make sprite-check): elos com paleta 0, âncora com paleta 2
			lk.gfx = 0x380 if lk.frame == 1 else 0x4380
		lk.routine = 0xA
		if sim.objects.place(lk, ObjectManager.FIRST_LEVEL_SLOT, true) == null:
			break
		sub += 1
		links.append(lk)
		if nd < 0:
			d3 = nd & 0xFF
	links.append(self)
	vars["angle_word"] = 0x4080
	vars["spd"] = -0x200
	if s0 & 0x10:
		art = "spikeball"
		frame = 1
		priority = 2
		col_type = 0x81
	if z == 5:
		_move()
		_chk_del()
		return false
	SolidHelpers.platform_land_h(self, act_width, height)
	_move()
	_chk_del()
	return false


func update() -> void:
	if is_link:
		return
	match routine:
		2:
			SolidHelpers.platform_land_h(self, act_width, height)
			_move()
		4:
			SolidHelpers.exit_platform2(self, act_width, act_width)
			var old_x := x
			_move()
			SolidHelpers.move_player_on_platform(self, height + 1, old_x)
		0xC:
			_move()
	_chk_del()


func _move() -> void:
	var a: int = sim.osc.byte_at(0xFE78)
	if status & 1:
		a = (0x80 - a)
	var sc := Trig.sincos(a & 0xFF)
	for lk in links:
		var r: int = lk.radius if lk != self else radius
		lk.y = Fx.u16(orig_y + ((r * sc.x) >> 8))
		lk.x = Fx.u16(orig_x + ((r * sc.y) >> 8))


func _chk_del() -> void:
	var d0 := (orig_x & 0xFF80) - ((Fx.u16(sim.camera.x) - 0x80) & 0xFF80)
	if Fx.u16(d0) > 0x280:
		for lk in links:
			lk.delete()
		delete()
