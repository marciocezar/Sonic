class_name MissileObj
extends GameObject
## Míssil da vespa/Newtron (ID 0x23): espera `timer` quadros (cancelado se o atirador explodir),
## clarão (anim 0, avança rotina) e voa em linha reta; machuca ao toque (0x87). ROM 0x9932, anim 0x9A2A.

const ANIMS := [[7, 0, 1, -4], [1, 2, 3, -1]]
var from_newtron: bool = false


func _init() -> void:
	kind = 0x23


func init() -> bool:
	art = "projectile"
	timer -= 1
	if timer >= 0:
		_chk_cancel()
		inited = false
		return false
	routine = 2
	priority = 3
	act_width = 8
	status &= 3
	if from_newtron:
		routine = 8
		col_type = 0x87
		anim = 1
		ObjAnim.animate(self, ANIMS)
		return false
	_chk_cancel()
	ObjAnim.animate(self, ANIMS)
	return false


## ROM 0x99A4: só cancela se o SLOT do atirador contém agora uma explosão (ID 0x27); se o atirador apenas
## saiu da janela, o míssil continua esperando.
func _chk_cancel() -> void:
	if parent == null:
		return
	var occ = sim.objects.slots[parent.slot] if parent.slot < sim.objects.slots.size() else null
	if occ != null and not occ.deleted and occ.kind == 0x27:
		delete()


func update() -> void:
	match routine:
		2:
			_chk_cancel()
			if not deleted:
				ObjAnim.animate(self, ANIMS)
		4:
			col_type = 0x87
			anim = 1
			speed_to_pos()
			ObjAnim.animate(self, ANIMS)
			if Fx.u16(sim.limit_bottom2 + 0xE0) < y:
				delete()
		6:
			delete()
		8:
			if (render & 0x80) == 0:
				delete()
				return
			speed_to_pos()
			ObjAnim.animate(self, ANIMS)
