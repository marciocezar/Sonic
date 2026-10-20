class_name RingObj
extends GameObject
## Grupo de anéis: o objeto da lista vira o primeiro anel e cria os demais conforme o subtipo
## (bits 0-2 = quantidade-1, máx. 6; bits 4-7 = espaçamento). Cada anel lembra se foi coletado
## por um bit no byte de respawn do grupo.

## Brilho de coleta: 4 quadros de 6 ticks e avança a rotina (anim medida em ROM 0x9F8A).
const SPARKLE := [[5, 4, 5, 6, 7, -4]]
var ring_bit: int = 0
var parent_x: int = 0
var is_child: bool = false


func init() -> bool:
	art = "ring"
	col_type = 0x47
	act_width = 8
	priority = 2
	if is_child:
		routine = 2
		return true
	if routine == 6:
		return true  # brilho avulso (placa de fim de ato)
	var state: int = 0
	if respawn_index >= 0:
		state = sim.objects.respawn[respawn_index]
	var count := sub & 7
	if count == 7:
		count = 6
	var sp: Array = ObjectFactory.RING_SPACING[(sub >> 4) & 0xF]
	var px := x
	var py := y
	var bits := state
	parent_x = x
	var first := true
	for i in range(count + 1):
		var collected := (bits & 1) != 0
		bits >>= 1
		if not collected:
			# só grupos com algum anel restante liberam a recarga (bit 7), como na referência
			if respawn_index >= 0:
				sim.objects.respawn[respawn_index] &= 0x7F
			if first:
				x = px
				y = py
				ring_bit = i
				routine = 2
			else:
				var r := RingObj.new()
				r.is_child = true
				r.x = px
				r.y = py
				r.parent_x = parent_x
				r.respawn_index = respawn_index
				r.ring_bit = i
				r.kind = kind
				r.art = "ring"
				r.col_type = 0x47
				r.act_width = 8
				r.priority = 2
				r.routine = 2
				if sim.objects.place(r, ObjectManager.FIRST_LEVEL_SLOT, true) == null:
					break
		px += int(sp[0])
		py += int(sp[1])
		first = false
	if state & 1:
		delete()
		return false
	return true


func update() -> void:
	match routine:
		2:
			frame = sim.objects.sync_ring_frame
			var d0 := (parent_x & 0xFF80) - ((Fx.u16(sim.camera.x) - 0x80) & 0xFF80)
			if Fx.u16(d0) > 0x280:
				delete()
		4:
			routine = 6
			col_type = 0
			priority = 1
			sim.add_rings(1)
			if respawn_index >= 0:
				sim.objects.respawn[respawn_index] |= (1 << ring_bit)
			ObjAnim.animate(self, SPARKLE)
		6:
			ObjAnim.animate(self, SPARKLE)
		8:
			delete()


func touch_item(p: Player) -> void:
	if p.flash_time >= 90:
		return
	if routine == 2:
		routine = 4
