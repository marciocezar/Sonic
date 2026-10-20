class_name SpikesObj
extends GameObject
## Espinhos (ID 0x36). Subtipo: nibble alto = variante (quadro, meia-largura) medida em ROM 0xCE3A;
## nibble baixo = movimento (0 fixo, 1 vertical, 2 horizontal; 32 px em passos de 0x800, pausa 60).
## Dano (REV00, confirmado em ROM 0xCE28): verificado SÓ contra invencibilidade — a invulnerabilidade
## temporária após dano NÃO protege. Para cima: dano ao pisar ou tocar topo/base; laterais: ao tocar o lado.

const VARIANTS := [[0, 0x14], [1, 0x10], [2, 4], [3, 0x1C], [4, 0x40], [5, 0x10]]
var orig_x: int = 0
var orig_y: int = 0
var offset: int = 0
var moving_status: int = 0
var wait: int = 0


func init() -> bool:
	art = "spikes"
	render |= 4
	priority = 4
	routine = 2
	var v: int = (sub & 0xF0) >> 4
	sub &= 0xF
	var var_ent: Array = VARIANTS[mini(v, 5)]
	frame = var_ent[0]
	act_width = var_ent[1]
	orig_x = x
	orig_y = y
	vars["spikes"] = true
	return true


func update() -> void:
	_move()
	var p: Player = sim.player
	var hurt := false
	if frame == 5 or frame == 1:
		var d2 := 0x14 if frame == 1 else 4
		var r := SolidHelpers.solid_object(self, 0x1B, d2, d2 + 1, x)
		if (status & 8) == 0 and r == 1:
			hurt = true
	else:
		var r2 := SolidHelpers.solid_object(self, act_width + 0xB, 0x10, 0x11, x)
		if (status & 8) != 0 or r2 < 0:
			hurt = true
	if hurt and not sim.invincible and p.routine < Player.RT_HURT:
		var pos := ((p.y << 16) | p.ys) - (p.yv << 8)
		p.y = (pos >> 16) & 0xFFFF
		p.ys = pos & 0xFFFF
		p.hurt(x, true)
	var d0 := (orig_x & 0xFF80) - ((Fx.u16(sim.camera.x) - 0x80) & 0xFF80)
	if Fx.u16(d0) > 0x280:
		delete()


func _move() -> void:
	if sub == 0:
		return
	if wait != 0:
		wait -= 1
		if wait == 0 and (render & 0x80):
			sim.emit_sfx("spikes_move")
	elif moving_status != 0:
		offset -= 0x800
		if offset < 0:
			offset = 0
			moving_status = 0
			wait = 60
	else:
		offset += 0x800
		if offset >= 0x2000:
			offset = 0x2000
			moving_status = 1
			wait = 60
	if sub == 1:
		y = Fx.u16(orig_y + (offset >> 8))
	elif sub == 2:
		x = Fx.u16(orig_x + (offset >> 8))
