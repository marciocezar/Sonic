class_name HelixObj
extends GameObject
## Tronco de espinhos giratórios de GHZ (ID 0x17): subtipo = quantidade de segmentos (16 px). Cada
## segmento gira em 8 quadros defasados (contador sincronizado 0) e só machuca (0x84) no quadro 0.
## Construção em n-1 iterações com o objeto pai como segmento central. ROM 0x7CA2..0x7DD0.

var children: Array = []
var phase: int = 0
var is_child: bool = false


func init() -> bool:
	if is_child:
		routine = 8
		return true
	art = "helix"
	routine = 2
	status = 7
	render |= 4
	priority = 3
	act_width = 8
	var n := sub
	sub = 0
	var d3 := x - (n >> 1) * 16
	var d6 := 0
	children.clear()
	for _i in range(maxi(n - 1, 0)):
		var c := HelixObj.new()
		c.is_child = true
		c.kind = kind
		c.art = "helix"
		c.routine = 8
		c.priority = 3
		c.act_width = 8
		c.x = d3
		c.y = y
		c.phase = d6
		if sim.objects.place(c, ObjectManager.FIRST_LEVEL_SLOT, true) == null:
			break
		sub += 1
		children.append(c)
		d6 = (d6 + 1) & 7
		d3 += 0x10
		if d3 == x:
			phase = d6
			d6 = (d6 + 1) & 7
			d3 += 0x10
			sub += 1
	return true


func update() -> void:
	_rotate()
	if is_child:
		return
	var d0 := (x & 0xFF80) - ((Fx.u16(sim.camera.x) - 0x80) & 0xFF80)
	if Fx.u16(d0) > 0x280:
		for c in children:
			c.delete()
		delete()


func _rotate() -> void:
	col_type = 0
	var f: int = (sim.osc.sync[1] + phase) & 7
	frame = f
	if f == 0:
		col_type = 0x84
