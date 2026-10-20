class_name Player
extends RefCounted
## Física do personagem em tick fixo (60 Hz), aritmética inteira.
## Especificação: docs/gameplay/fisica-e-colisao.md. Parâmetros com evidência no ledger.
##
## Unidades: posição 16.16 (pixel + subpixel), velocidades 8.8 (1/256 px por quadro),
## ângulo em 256 passos (0 = chão, 0x40 = parede esquerda... sentido horário com Y para baixo).

# bits de status
const ST_LEFT := 1
const ST_AIR := 2
const ST_ROLL := 4
const ST_ON_OBJ := 8
const ST_ROLLJUMP := 16
const ST_PUSH := 32
const ST_WATER := 64

# bits de entrada (layout do controle de referência)
const IN_UP := 1
const IN_DOWN := 2
const IN_LEFT := 4
const IN_RIGHT := 8
const IN_B := 16
const IN_C := 32
const IN_A := 64
const IN_START := 128
const IN_JUMP := IN_A | IN_B | IN_C

# IDs de animação (comparáveis com a referência)
const AN_WALK := 0
const AN_RUN := 1
const AN_ROLL := 2
const AN_ROLL2 := 3
const AN_PUSH := 4
const AN_WAIT := 5
const AN_BALANCE := 6
const AN_LOOKUP := 7
const AN_DUCK := 8
const AN_STOP := 0x0D
const AN_SPRING := 0x10
const AN_HURT := 0x1A  # ROM 0x1B066
const AN_DEATH := 0x18
const AN_DROWN := 0x17

# rotinas
const RT_INIT := 0
const RT_CONTROL := 2
const RT_HURT := 4
const RT_DEATH := 6
const RT_RESET := 8

const RADIUS_STAND_Y := 0x13
const RADIUS_STAND_X := 9
const RADIUS_ROLL_Y := 0x0E
const RADIUS_ROLL_X := 7

var sim  # GameSim (tipagem fraca evita dependência cíclica)

var x: int = 0
var xs: int = 0
var y: int = 0
var ys: int = 0
var xv: int = 0
var yv: int = 0
var gs: int = 0
var angle: int = 0
var status: int = 0
var routine: int = RT_INIT
var anim: int = AN_WALK
var next_anim: int = 0
var frame: int = 0
var ani_frame: int = 0
var time_frame: int = 0
var xr: int = RADIUS_STAND_X
var yr: int = RADIUS_STAND_Y
var move_lock: int = 0
var stick: int = 0
var jumping: int = 0
var flash_time: int = 0
var inv_time: int = 0
var shoe_time: int = 0
var render: int = 0  # bit0 espelho X, bit6 caminho de loop, bit7 visível na tela
var standing_on = null  # objeto sob o jogador (ST_ON_OBJ)
var visible: bool = true
var death_timer: int = 0
var angle_buf_a: int = 0
var angle_buf_b: int = 0


func _init(game) -> void:
	sim = game


func init_at(px: int, py: int) -> void:
	x = px
	y = py
	xs = 0
	ys = 0
	xv = 0
	yv = 0
	gs = 0
	routine = RT_CONTROL
	yr = RADIUS_STAND_Y
	xr = RADIUS_STAND_X
	status = 0
	anim = AN_WAIT


func alt_path() -> bool:
	return (render & 0x40) != 0


func terrain() -> Terrain:
	return sim.terrain


# --- quadro --------------------------------------------------------------------

func tick() -> void:
	match routine:
		RT_CONTROL:
			_control()
		RT_HURT:
			_hurt()
		RT_DEATH:
			_death()
		_:
			pass


func _control() -> void:
	if not sim.lock_multi:
		var mode := status & (ST_AIR | ST_ROLL)
		if mode == 0:
			_mode_normal()
		elif mode == ST_ROLL:
			_mode_roll()
		else:
			_mode_air()
	_display_timers()
	_water()
	angle_buf_a = terrain().ang_a
	angle_buf_b = terrain().ang_b
	_animate()
	if not sim.lock_multi_neg:
		sim.react_to_items(self)
	_loops()


func _mode_normal() -> void:
	if _jump():
		return
	_slope_resist()
	_move()
	_roll_start()
	_level_bound()
	_speed_to_pos()
	_angle_pos()
	_slope_repel()


func _mode_roll() -> void:
	if _jump():
		return
	_roll_repel()
	_roll_speed()
	_level_bound()
	_speed_to_pos()
	_angle_pos()
	_slope_repel()


func _mode_air() -> void:
	_jump_height()
	_jump_direction()
	_level_bound()
	_object_fall()
	if status & ST_WATER:
		yv = Fx.s16(yv - 0x28)
	_jump_angle()
	_air_collision()


# --- movimento ---------------------------------------------------------------------

func _hold() -> int:
	return sim.pad_hold


func _press() -> int:
	return sim.pad_press


func _move() -> void:
	var top: int = sim.speed_max
	var acc: int = sim.speed_acc
	var dec: int = sim.speed_dec
	if not sim.jump_only:
		if move_lock != 0:
			_reset_look()
		else:
			if _hold() & IN_LEFT:
				_move_left(top, acc, dec)
			if _hold() & IN_RIGHT:
				_move_right(top, acc, dec)
			if ((angle + 0x20) & 0xC0) != 0 or gs != 0:
				_reset_look()
			else:
				status &= ~ST_PUSH
				anim = AN_WAIT
				if _standing_idle_checks():
					pass
		# atrito quando nenhuma direção horizontal está pressionada
		if (_hold() & (IN_LEFT | IN_RIGHT)) == 0 and gs != 0:
			if gs > 0:
				gs = gs - acc
				if gs < 0:
					gs = 0
			else:
				gs = gs + acc
				if gs > 0:
					gs = 0
	_ground_velocity_from_speed()
	_ground_wall_check()


## Parado em superfície plana: equilíbrio na borda, olhar para cima/baixo. Retorna true se tratou.
func _standing_idle_checks() -> bool:
	var balance_dir := 0  # 0 nenhum, 1 = virado à direita (borda à direita), -1 = à esquerda
	var do_look := true
	if status & ST_ON_OBJ and standing_on != null:
		var o = standing_on
		var w: int = o.act_width
		var d1: int = w + x - o.x
		var d2: int = w * 2 - 4
		if d1 < 4:
			balance_dir = -1
			do_look = false
		elif d1 >= d2:
			balance_dir = 1
			do_look = false
	else:
		var fd: Array = terrain().obj_floor_dist(x, y, yr, alt_path())
		if fd[0] >= 0xC:
			if angle_buf_a == 3:
				balance_dir = 1
				do_look = false
			elif angle_buf_b == 3:
				balance_dir = -1
				do_look = false
	if not do_look:
		if balance_dir == 1:
			status &= ~ST_LEFT
		else:
			status |= ST_LEFT
		anim = AN_BALANCE
		_reset_look()
		return true
	if _hold() & IN_UP:
		anim = AN_LOOKUP
		if sim.look_shift != 0xC8:
			sim.look_shift += 2
	elif _hold() & IN_DOWN:
		anim = AN_DUCK
		if sim.look_shift != 8:
			sim.look_shift -= 2
	else:
		_reset_look()
	return true


func _reset_look() -> void:
	if sim.look_shift == 0x60:
		return
	if sim.look_shift < 0x60:
		sim.look_shift += 4
	sim.look_shift -= 2


func _move_left(top: int, acc: int, dec: int) -> void:
	var d := gs
	if d > 0:
		d -= dec
		if d < 0:
			d = -0x80
		gs = d
		# ROM 0x130BE: o byte baixo de d0 é substituído pelo teste de ângulo (= 0); compara só o byte alto
		if ((angle + 0x20) & 0xC0) == 0 and Fx.s16(d & 0xFF00) >= 0x400:
			anim = AN_STOP
			status &= ~ST_LEFT
			sim.emit_sfx("skid")
		return
	if (status & ST_LEFT) == 0:
		status &= ~ST_PUSH
		next_anim = 1
	status |= ST_LEFT
	d -= acc
	if d <= -top:
		d = -top
	gs = d
	anim = AN_WALK


func _move_right(top: int, acc: int, dec: int) -> void:
	var d := gs
	if d < 0:
		d += dec
		if d >= 0:
			d = 0x80
		gs = d
		# ROM 0x13124: mesmo reaproveitamento de registrador (byte alto da velocidade)
		if ((angle + 0x20) & 0xC0) == 0 and Fx.s16(d & 0xFF00) <= -0x400:
			anim = AN_STOP
			status |= ST_LEFT
			sim.emit_sfx("skid")
		return
	if status & ST_LEFT:
		status &= ~ST_LEFT
		status &= ~ST_PUSH
		next_anim = 1
	d += acc
	if d >= top:
		d = top
	gs = d
	anim = AN_WALK


func _ground_velocity_from_speed() -> void:
	var sc := Trig.sincos(angle)
	xv = Fx.s16((sc.y * gs) >> 8)
	yv = Fx.s16((sc.x * gs) >> 8)


## Verificação de parede à frente durante a corrida (usa a velocidade do próximo quadro).
func _ground_wall_check() -> void:
	if ((angle + 0x40) & 0x80) != 0:
		return
	if gs == 0:
		return
	var d1 := 0x40 if gs < 0 else -0x40
	var a := (angle + d1) & 0xFF
	var dist := _walk_speed_probe(a)
	if dist >= 0:
		return
	var push := Fx.s16(dist << 8)
	var q := (a + 0x20) & 0xC0
	if q == 0:
		yv = Fx.s16(yv + push)
	elif q == 0x40:
		xv = Fx.s16(xv - push)
		status |= ST_PUSH
		gs = 0
	elif q == 0x80:
		yv = Fx.s16(yv - push)
	else:
		xv = Fx.s16(xv + push)
		status |= ST_PUSH
		gs = 0


## Sonda à distância de 10 px na direção do ângulo dado, na posição do próximo quadro.
func _walk_speed_probe(a: int) -> int:
	var nx := ((x << 16) | xs) + (xv << 8)
	var ny := ((y << 16) | ys) + (yv << 8)
	var px := Fx.u16(nx >> 16)
	var py := Fx.u16(ny >> 16)
	var t := terrain()
	t.ang_a = a
	t.ang_b = a
	var q := _quadrant_rounded(a)
	if q == 0:
		return t.floor_10(px, py, alt_path())[0]
	if q == 0x80:
		return t.ceiling_10(px, py, alt_path())[0]
	if (a & 0x38) == 0:
		py += 8
	if q == 0x40:
		return t.wall_left_10(px, py, alt_path())[0]
	return t.wall_right_10(px, py, alt_path())[0]


## Quadrante com arredondamento assimétrico (favorece o modo atual em ângulos de 45°).
static func _quadrant_rounded(a: int) -> int:
	var d: int
	if ((a + 0x20) & 0x80) != 0:
		d = a
		if d & 0x80:
			d -= 1
		d += 0x20
	else:
		d = a
		if d & 0x80:
			d += 1
		d += 0x1F
	return d & 0xC0


func _roll_start() -> void:
	if sim.jump_only:
		return
	if absi(gs) < 0x80:
		return
	if _hold() & (IN_LEFT | IN_RIGHT):
		return
	if _hold() & IN_DOWN:
		start_roll()


func start_roll() -> void:
	if status & ST_ROLL:
		return
	status |= ST_ROLL
	yr = RADIUS_ROLL_Y
	xr = RADIUS_ROLL_X
	anim = AN_ROLL
	y = Fx.u16(y + 5)
	sim.emit_sfx("roll")
	if gs == 0:
		gs = 0x200


## Salto. Retorna true se saltou (o restante do modo é ignorado neste quadro).
func _jump() -> bool:
	if (_press() & IN_JUMP) == 0:
		return false
	var room: Array = _room_over_head((angle + 0x80) & 0xFF)
	if room[0] < 6:
		return false
	var spd := 0x680
	if status & ST_WATER:
		spd = 0x380
	var sc := Trig.sincos((angle - 0x40) & 0xFF)
	xv = Fx.s16(xv + ((sc.y * spd) >> 8))
	yv = Fx.s16(yv + ((sc.x * spd) >> 8))
	status |= ST_AIR
	status &= ~ST_PUSH
	jumping = 1
	stick = 0
	sim.emit_sfx("jump")
	yr = RADIUS_STAND_Y
	xr = RADIUS_STAND_X
	if status & ST_ROLL:
		status |= ST_ROLLJUMP
	else:
		yr = RADIUS_ROLL_Y
		xr = RADIUS_ROLL_X
		anim = AN_ROLL
		status |= ST_ROLL
		y = Fx.u16(y + 5)
	return true


## Espaço livre na direção do ângulo dado (dois sensores). Retorna [dist, outro, angulo].
func _room_over_head(a: int) -> Array:
	var t := terrain()
	t.ang_a = a
	t.ang_b = a
	var q := (a + 0x20) & 0xC0
	if q == 0x40:
		return t.hit_left_pair(x, y, xr, yr, alt_path())
	if q == 0x80:
		return t.hit_ceiling(x, y, xr, yr, alt_path())
	if q == 0xC0:
		return t.hit_right_pair(x, y, xr, yr, alt_path())
	return t.hit_floor(x, y, xr, yr, alt_path())


func _slope_resist() -> void:
	if ((angle + 0x60) & 0xFF) >= 0xC0:
		return
	var d := (Trig.sine(angle) * 0x20) >> 8
	if gs == 0:
		return
	if gs > 0:
		if d == 0:
			return
	gs = Fx.s16(gs + d)


func _roll_repel() -> void:
	if ((angle + 0x60) & 0xFF) >= 0xC0:
		return
	var d := (Trig.sine(angle) * 0x50) >> 8
	if gs >= 0:
		if d < 0:
			d >>= 2
	else:
		if d >= 0:
			d >>= 2
	gs = Fx.s16(gs + d)


func _roll_speed() -> void:
	var acc: int = sim.speed_acc >> 1
	var dec: int = sim.speed_dec >> 2
	if not sim.jump_only:
		if move_lock == 0:
			if _hold() & IN_LEFT:
				if gs > 0:
					var d := gs - dec
					if d < 0:
						d = -0x80
					gs = d
				else:
					status |= ST_LEFT
					anim = AN_ROLL
			if _hold() & IN_RIGHT:
				if gs < 0:
					var d2 := gs + dec
					if d2 >= 0:
						d2 = 0x80
					gs = d2
				else:
					status &= ~ST_LEFT
					anim = AN_ROLL
		if gs != 0:
			if gs > 0:
				gs -= acc
				if gs < 0:
					gs = 0
			else:
				gs += acc
				if gs > 0:
					gs = 0
		if gs == 0:
			status &= ~ST_ROLL
			yr = RADIUS_STAND_Y
			xr = RADIUS_STAND_X
			anim = AN_WAIT
			y = Fx.u16(y - 5)
	var sc := Trig.sincos(angle)
	yv = Fx.s16((sc.x * gs) >> 8)
	var vx := (sc.y * gs) >> 8
	vx = clampi(vx, -0x1000, 0x1000)
	xv = Fx.s16(vx)
	_ground_wall_check()


func _slope_repel() -> void:
	if stick != 0:
		return
	if move_lock != 0:
		move_lock -= 1
		return
	if ((angle + 0x20) & 0xC0) == 0:
		return
	if absi(gs) >= 0x280:
		return
	gs = 0
	status |= ST_AIR
	move_lock = 0x1E


func _level_bound() -> void:
	var nx := ((x << 16) | xs) + (xv << 8)
	var px := Fx.u16(nx >> 16)
	var left: int = Fx.u16(sim.limit_left2 + 0x10)
	var hit := -1
	if left > px:
		hit = left
	else:
		var right: int = sim.limit_right2 + 0x128
		if not sim.lock_screen:
			right += 0x40
		right = Fx.u16(right)
		if right <= px:
			hit = right
	if hit >= 0:
		x = hit
		xs = 0
		xv = 0
		gs = 0
	if Fx.s16(sim.limit_bottom2 + 0xE0) < Fx.s16(y):
		sim.player_fell_out(self)


func _speed_to_pos() -> void:
	var nx := ((x << 16) | xs) + (xv << 8)
	var ny := ((y << 16) | ys) + (yv << 8)
	x = (nx >> 16) & 0xFFFF
	xs = nx & 0xFFFF
	y = (ny >> 16) & 0xFFFF
	ys = ny & 0xFFFF


func _object_fall() -> void:
	var nx := ((x << 16) | xs) + (xv << 8)
	var ny := ((y << 16) | ys) + (yv << 8)
	yv = Fx.s16(yv + 0x38)
	x = (nx >> 16) & 0xFFFF
	xs = nx & 0xFFFF
	y = (ny >> 16) & 0xFFFF
	ys = ny & 0xFFFF


# --- chão: ajuste por sensores ------------------------------------------------------------

func _angle_pos() -> void:
	var t := terrain()
	if status & ST_ON_OBJ:
		t.ang_a = 0
		t.ang_b = 0
		return
	t.ang_a = 3
	t.ang_b = 3
	var q := _quadrant_rounded(angle)
	var r: Array
	var alt := alt_path()
	if q == 0x40:
		var xx := (x - yr) ^ 0xF
		var d1 := t._sense(1, 0, xx, y - xr, 13, 0x800, -16, alt)
		var d2 := t._sense(1, 1, xx, y + xr, 13, 0x800, -16, alt)
		r = t.pick(d1, d2, angle_cardinal_hint())
		_apply_snap(r, 2)
	elif q == 0x80:
		var yy := (y - yr) ^ 0xF
		var d1c := t._sense(0, 0, x + xr, yy, 13, 0x1000, -16, alt)
		var d2c := t._sense(0, 1, x - xr, yy, 13, 0x1000, -16, alt)
		r = t.pick(d1c, d2c, angle_cardinal_hint())
		_apply_snap(r, 3)
	elif q == 0xC0:
		var d1r := t._sense(1, 0, x + yr, y - xr, 13, 0, 16, alt)
		var d2r := t._sense(1, 1, x + yr, y + xr, 13, 0, 16, alt)
		r = t.pick(d1r, d2r, angle_cardinal_hint())
		_apply_snap(r, 1)
	else:
		var d1f := t._sense(0, 0, x + xr, y + yr, 13, 0, 16, alt)
		var d2f := t._sense(0, 1, x - xr, y + yr, 13, 0, 16, alt)
		r = t.pick(d1f, d2f, angle_cardinal_hint())
		_apply_snap(r, 0)


## Ângulo usado quando o sensor retorna ângulo ímpar: arredonda o ângulo atual ao cardinal.
func angle_cardinal_hint() -> int:
	return (angle + 0x20) & 0xC0


## Aplica a distância do par de sensores. axis: 0 chão(+y), 1 parede dir(+x), 2 parede esq(-x), 3 teto(-y)
func _apply_snap(r: Array, axis: int) -> void:
	angle = r[2]
	var d: int = r[0]
	if d == 0:
		return
	if d < 0:
		if d < -14:
			return
	elif d > 14:
		if stick == 0:
			status |= ST_AIR
			status &= ~ST_PUSH
			next_anim = 1
			return
	match axis:
		0:
			y = Fx.u16(y + d)
		1:
			x = Fx.u16(x + d)
		2:
			x = Fx.u16(x - d)
		3:
			y = Fx.u16(y - d)


# --- ar ----------------------------------------------------------------------------------

func _jump_height() -> void:
	if jumping != 0:
		var cap := -0x400
		if status & ST_WATER:
			cap = -0x200
		if cap > yv and (_hold() & IN_JUMP) == 0:
			yv = cap
	else:
		if yv < -0xFC0:
			yv = -0xFC0


func _jump_direction() -> void:
	var top: int = sim.speed_max
	var acc: int = sim.speed_acc << 1
	if (status & ST_ROLLJUMP) == 0:
		var d := xv
		if _hold() & IN_LEFT:
			status |= ST_LEFT
			d -= acc
			if d <= -top:
				d = -top
		if _hold() & IN_RIGHT:
			status &= ~ST_LEFT
			d += acc
			if d >= top:
				d = top
		xv = Fx.s16(d)
	_reset_look()
	# arrasto do ar perto do ápice (-0x400 <= yv < 0)
	if (yv & 0xFFFF) < 0xFC00:
		return
	var v := xv
	var drag := v >> 5
	if drag == 0:
		return
	var nv := v - drag
	if drag > 0:
		if (v & 0xFFFF) < (drag & 0xFFFF):
			nv = 0
	else:
		if not ((v & 0xFFFF) < (drag & 0xFFFF)):
			nv = 0
	xv = Fx.s16(nv)


func _jump_angle() -> void:
	var a := angle
	if a == 0:
		return
	if a & 0x80:
		a += 2
		if a >= 0x100:
			a = 0
	else:
		a -= 2
		if a < 0:
			a = 0
	angle = a & 0xFF


func _air_collision() -> void:
	var t := terrain()
	var dir := (Trig.angle_of(xv, yv) - 0x20) & 0xC0
	var alt := alt_path()
	if dir == 0x40:
		_air_moving_left(t, alt)
		return
	if dir == 0x80:
		_air_moving_up(t, alt)
		return
	if dir == 0xC0:
		_air_moving_right(t, alt)
		return
	# descendo
	var wl: Array = t.wall_left_10(x, y, alt)
	if wl[0] < 0:
		x = Fx.u16(x - wl[0])
		xv = 0
	var wr: Array = t.wall_right_10(x, y, alt)
	if wr[0] < 0:
		x = Fx.u16(x + wr[0])
		xv = 0
	var fl: Array = t.hit_floor(x, y, xr, yr, alt)
	var d1: int = fl[0]
	var d0: int = fl[1]
	if d1 >= 0:
		return
	var lim := Fx.s8(-(((yv >> 8) & 0xFF) + 8))
	if not (Fx.s8(d1) >= lim) and Fx.s8(d0) < lim:
		return
	y = Fx.u16(y + d1)
	var a: int = fl[2]
	angle = a
	reset_on_floor()
	anim = AN_WALK
	if ((a + 0x20) & 0x40) != 0:
		xv = 0
		if yv > 0xFC0:
			yv = 0xFC0
		gs = yv
		if a & 0x80:
			gs = Fx.s16(-gs)
		return
	if ((a + 0x10) & 0x20) == 0:
		yv = 0
		gs = xv
		return
	yv = yv >> 1
	gs = yv
	if a & 0x80:
		gs = Fx.s16(-gs)


func _air_moving_left(t: Terrain, alt: bool) -> void:
	var wl: Array = t.wall_left_10(x, y, alt)
	if wl[0] < 0:
		x = Fx.u16(x - wl[0])
		xv = 0
		gs = yv
		return
	var c: Array = t.hit_ceiling(x, y, xr, yr, alt)
	if c[0] < 0:
		y = Fx.u16(y - c[0])
		if yv < 0:
			yv = 0
		return
	if yv < 0:
		return
	var fl: Array = t.hit_floor(x, y, xr, yr, alt)
	if fl[0] >= 0:
		return
	y = Fx.u16(y + fl[0])
	angle = fl[2]
	reset_on_floor()
	anim = AN_WALK
	yv = 0
	gs = xv


func _air_moving_up(t: Terrain, alt: bool) -> void:
	var wl: Array = t.wall_left_10(x, y, alt)
	if wl[0] < 0:
		x = Fx.u16(x - wl[0])
		xv = 0
	var wr: Array = t.wall_right_10(x, y, alt)
	if wr[0] < 0:
		x = Fx.u16(x + wr[0])
		xv = 0
	var c: Array = t.hit_ceiling(x, y, xr, yr, alt)
	if c[0] >= 0:
		return
	y = Fx.u16(y - c[0])
	var a: int = c[2]
	if ((a + 0x20) & 0x40) == 0:
		yv = 0
		return
	angle = a
	reset_on_floor()
	gs = yv
	if a & 0x80:
		gs = Fx.s16(-gs)


func _air_moving_right(t: Terrain, alt: bool) -> void:
	var wr: Array = t.wall_right_10(x, y, alt)
	if wr[0] < 0:
		x = Fx.u16(x + wr[0])
		xv = 0
		gs = yv
		return
	var c: Array = t.hit_ceiling(x, y, xr, yr, alt)
	if c[0] < 0:
		y = Fx.u16(y - c[0])
		if yv < 0:
			yv = 0
		return
	if yv < 0:
		return
	var fl: Array = t.hit_floor(x, y, xr, yr, alt)
	if fl[0] >= 0:
		return
	y = Fx.u16(y + fl[0])
	angle = fl[2]
	reset_on_floor()
	anim = AN_WALK
	yv = 0
	gs = xv


func reset_on_floor() -> void:
	status &= ~(ST_PUSH | ST_AIR | ST_ROLLJUMP)
	if status & ST_ROLL:
		status &= ~ST_ROLL
		yr = RADIUS_STAND_Y
		xr = RADIUS_STAND_X
		anim = AN_WALK
		y = Fx.u16(y - 5)
	jumping = 0
	sim.item_bonus = 0


# --- temporizadores, água, loops -----------------------------------------------------------

func _display_timers() -> void:
	if flash_time != 0:
		var t := flash_time
		flash_time -= 1
		visible = ((t >> 2) & 1) == 1
	else:
		visible = true
	if sim.invincible and inv_time != 0:
		inv_time -= 1
		if inv_time == 0:
			sim.invincible = false
			sim.emit_music("zone")
	if sim.shoes and shoe_time != 0:
		shoe_time -= 1
		if shoe_time == 0:
			sim.speed_max = 0x600
			sim.speed_acc = 0xC
			sim.speed_dec = 0x80
			sim.shoes = false
			sim.emit_music("slow")


func _water() -> void:
	if sim.level.zone != 1 or sim.water_level < 0:
		return
	if sim.water_level >= Fx.s16(y):
		if status & ST_WATER:
			status &= ~ST_WATER
			sim.speed_max = 0x600
			sim.speed_acc = 0xC
			sim.speed_dec = 0x80
			yv = Fx.s16(yv << 1)
			if yv != 0:
				if yv < -0x1000:
					yv = -0x1000
				sim.emit_sfx("splash")
		return
	if status & ST_WATER:
		return
	status |= ST_WATER
	sim.speed_max = 0x300
	sim.speed_acc = 6
	sim.speed_dec = 0x40
	xv = xv >> 1
	yv = yv >> 1
	yv = yv >> 1
	if yv != 0:
		sim.emit_sfx("splash")


func _loops() -> void:
	var z: int = sim.level.zone
	if z != 0 and z != 3:
		return
	var idx := ((y >> 1) & 0x380) + ((x >> 8) & 0x7F)
	var cid: int = sim.level.layout[idx]
	var L: LevelData = sim.level
	if cid == L.roll_chunks[0] or cid == L.roll_chunks[1]:
		start_roll()
		return
	var is_loop1: bool = cid == L.loop_chunks[0]
	var is_loop2: bool = cid == L.loop_chunks[1]
	if not is_loop1 and not is_loop2:
		render &= ~0x40
		return
	if is_loop2 and not is_loop1 and (status & ST_AIR):
		render &= ~0x40
		return
	var lx := x & 0xFF
	if lx < 0x2C:
		render &= ~0x40
		return
	if lx >= 0xE0:
		render |= 0x40
		return
	if (render & 0x40) == 0:
		if angle == 0 or angle > 0x80:
			return
		render |= 0x40
	else:
		if angle <= 0x80:
			return
		render &= ~0x40


# --- animação (IDs e temporização; quadros dependem de dados de animação) ----------------------

func _animate() -> void:
	sim.animator.animate_player(self)


# --- dano e morte ----------------------------------------------------------------------------

func hurt(source_x: int, spikes: bool) -> void:
	if sim.shield:
		sim.shield = false
	elif sim.rings > 0:
		sim.scatter_rings(self)
	else:
		kill()
		return
	routine = RT_HURT
	reset_on_floor()
	status |= ST_AIR
	yv = -0x400
	xv = -0x200
	if status & ST_WATER:
		yv = -0x200
		xv = -0x100
	if not (x < source_x):
		xv = -xv
	gs = 0
	anim = AN_HURT
	flash_time = 120
	sim.emit_sfx("spikes" if spikes else "hurt")


func kill() -> void:
	if routine == RT_DEATH:
		return
	sim.invincible = false
	routine = RT_DEATH
	reset_on_floor()
	status |= ST_AIR
	yv = -0x700
	xv = 0
	gs = 0
	anim = AN_DEATH
	sim.emit_sfx("death")


func _hurt() -> void:
	_speed_to_pos()
	yv = Fx.s16(yv + 0x30)
	if status & ST_WATER:
		yv = Fx.s16(yv - 0x20)
	_hurt_stop()
	_level_bound()
	_animate()


func _hurt_stop() -> void:
	if Fx.s16(sim.limit_bottom2 + 0xE0) < Fx.s16(y):
		kill()
		return
	_air_collision()
	if status & ST_AIR:
		return
	yv = 0
	xv = 0
	gs = 0
	anim = AN_WALK
	routine = RT_CONTROL
	flash_time = 120


func _death() -> void:
	# fim da queda: limite inferior + 0x100 (comparação sem sinal)
	if Fx.u16(sim.limit_bottom2 + 0x100) < y:
		yv = -0x38
		routine = RT_RESET
		sim.player_death_finished(self)
	_object_fall_simple()
	_animate()


func _object_fall_simple() -> void:
	var nx := ((x << 16) | xs) + (xv << 8)
	var ny := ((y << 16) | ys) + (yv << 8)
	yv = Fx.s16(yv + 0x38)
	x = (nx >> 16) & 0xFFFF
	xs = nx & 0xFFFF
	y = (ny >> 16) & 0xFFFF
	ys = ny & 0xFFFF
