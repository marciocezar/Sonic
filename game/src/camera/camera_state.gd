class_name CameraState
extends RefCounted
## Câmera determinística (posição 16.16), regras especificadas em docs/gameplay/camera.md.
## Janela horizontal: alvo entre 144 e 160 px da borda esquerda, avanço máximo 16 px/quadro.
## Vertical: alvo a look_shift (padrão 0x60) do topo; velocidade limitada conforme estado.

var x: int = 0
var xs: int = 0
var y: int = 0
var ys: int = 0
var shift_x: int = 0
var shift_y: int = 0


func update(sim) -> void:
	_horizontal(sim)
	_vertical(sim)


func _horizontal(sim) -> void:
	var p: Player = sim.player
	# diferença em 16 bits sem sinal, como no processador de referência
	var du: int = Fx.u16(p.x - x)
	var nx: int
	if du < 0x90:
		nx = Fx.s16(x + du - 0x90)
		if not (nx > Fx.s16(sim.limit_left2)):
			nx = Fx.s16(sim.limit_left2)
	else:
		var d := du - 0xA0
		if d < 0:
			shift_x = 0
			return
		if d >= 0x10:
			d = 0x10
		nx = Fx.s16(x + d)
		if not (nx < Fx.s16(sim.limit_right2)):
			nx = Fx.s16(sim.limit_right2)
	shift_x = Fx.s16((nx - x) << 8)
	x = Fx.u16(nx)


func _vertical(sim) -> void:
	var p: Player = sim.player
	var d: int = Fx.s16(p.y - y)
	if p.status & Player.ST_ROLL:
		d -= 5
	var speed := 0
	var mode := ""  # "none" | "exact" | "capped"
	if p.status & Player.ST_AIR:
		d += 0x20
		d -= sim.look_shift
		if d < 0:
			speed = 0x1000
			mode = _cap(d, 0x10)
		else:
			d -= 0x40
			if d >= 0:
				speed = 0x1000
				mode = _cap(d, 0x10)
			elif sim.bg_scroll_vert:
				d = 0
				sim.bg_scroll_vert = false
				mode = "exact"
			else:
				shift_y = 0
				return
	else:
		d -= sim.look_shift
		if d == 0:
			if sim.bg_scroll_vert:
				sim.bg_scroll_vert = false
				mode = "exact"
			else:
				shift_y = 0
				return
		elif sim.look_shift == 0x60:
			var g: int = absi(p.gs)
			if g >= 0x800:
				speed = 0x1000
				mode = _cap(d, 0x10)
			else:
				speed = 0x600
				mode = _cap(d, 6)
		else:
			speed = 0x200
			mode = _cap(d, 2)
	var pos := (Fx.u16(y) << 16) | ys
	var npos: int
	var going_down: bool
	if mode == "exact":
		npos = (Fx.u16(y + d)) << 16
		going_down = d >= 0
	elif mode == "up":
		npos = pos - (speed << 8)
		going_down = false
	else:
		npos = pos + (speed << 8)
		going_down = true
	var ny := Fx.s16(npos >> 16)
	if not going_down:
		if not (ny > Fx.s16(sim.limit_top2)):
			if ny > -0x100:
				npos = (Fx.u16(sim.limit_top2)) << 16
			else:
				ny &= 0x7FF
				p.y &= 0x7FF
				y &= 0x7FF
				pos = (Fx.u16(y) << 16) | ys
				npos = (ny << 16) | (npos & 0xFFFF)
	else:
		if not (ny < Fx.s16(sim.limit_bottom2)):
			var w := Fx.u16(ny) - 0x800
			if w < 0:
				npos = (Fx.u16(sim.limit_bottom2)) << 16
			else:
				p.y &= 0x7FF
				y = Fx.u16(y - 0x800)
				pos = (Fx.u16(y) << 16) | ys
				npos = (Fx.u16(w) << 16) | (npos & 0xFFFF)
	npos &= 0xFFFFFFFF
	var delta := Fx.s32(npos - ((Fx.u16(y) << 16) | ys))
	shift_y = Fx.s16(delta >> 8)
	y = (npos >> 16) & 0xFFFF
	ys = npos & 0xFFFF


## Decide entre movimento exato (|d| <= cap) ou limitado ("down"/"up").
static func _cap(d: int, cap: int) -> String:
	if d > cap:
		return "down"
	if d < -cap:
		return "up"
	return "exact"
