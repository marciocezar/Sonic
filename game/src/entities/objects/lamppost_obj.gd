class_name LamppostObj
extends GameObject
## Poste de checkpoint (ID 0x79, ROM 0x16E2E). Rotinas: 0x16E4A início, 0x16EAE espera, 0x16F92 parado (aceso),
## 0x16F94 estrela girando (filho). Ao tocar: som 0xA1, estrela, quadro 1 e salvamento do estado (0x16FD2).
## Todas as rotinas terminam em 0xF6AC (fora da janela -> libera recarga e remove).

const MAP := 0x170F8
const GFX := 0x7A0

var cx: int = 0  # $30
var cy: int = 0  # $32
var star_t: int = 0  # $36


func init() -> bool:
	routine = 2
	map_addr = MAP
	gfx = GFX
	render = 4
	act_width = 8
	priority = 5
	var resp: int = sim.objects.respawn[respawn_index] if respawn_index >= 0 else 0
	if respawn_index >= 0:
		resp &= 0x7F
		sim.objects.respawn[respawn_index] = resp
	if (resp & 1) or (sim.lamp_num & 0x7F) >= (sub & 0x7F):
		_set_hit()
	out_of_range_check(true)
	return false


func update() -> void:
	match routine:
		2:
			_wait()
		6:
			_star()
	out_of_range_check(true)


func _set_hit() -> void:
	if respawn_index >= 0:
		sim.objects.respawn[respawn_index] |= 1
	routine = 4
	frame = 3


func _wait() -> void:
	if sim.debug_mode or sim.lock_multi_neg:
		return
	if (sim.lamp_num & 0x7F) >= (sub & 0x7F):
		_set_hit()
		return
	var p: Player = sim.player
	if Fx.u16(p.x - x + 8) >= 0x10 or Fx.u16(p.y - y + 0x40) >= 0x68:
		return
	sim.emit_sfx("lamppost")
	routine = 4
	var st := LamppostObj.new()
	st.kind = kind
	st.respawn_index = -1
	if sim.objects.place(st, ObjectManager.FIRST_LEVEL_SLOT, true) != null:
		st.routine = 6
		st.cx = x
		st.cy = Fx.u16(y - 0x18)
		st.map_addr = MAP
		st.gfx = GFX
		st.render = 4
		st.act_width = 8
		st.priority = 4
		st.frame = 2
		st.star_t = 0x20
	frame = 1
	sim.save_lamppost(sub, x, y)
	if respawn_index >= 0:
		sim.objects.respawn[respawn_index] |= 1


## 0x16F94: estrela gira em volta do topo por 0x20 quadros (raio 0xC00/0x10000 * 256 = 12 px).
func _star() -> void:
	star_t -= 1
	if star_t < 0:
		routine = 4
	var a := status_angle
	status_angle = (status_angle - 0x10) & 0xFF
	var sc := Trig.sincos((a - 0x40) & 0xFF)
	x = Fx.u16(((sc.y * 0xC00) >> 16) + cx)
	y = Fx.u16(((sc.x * 0xC00) >> 16) + cy)


var status_angle: int = 0  # $26
