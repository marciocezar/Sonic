class_name EdgeWallObj
extends GameObject
## Parede de borda de GHZ (ID 0x44). Subtipo bit 4 = só decoração; senão parede 0x13×0x28 (ROM 0xE1D4).


func init() -> bool:
	art = "wall"
	routine = 2
	render |= 4
	act_width = 8
	priority = 6
	frame = sub & ~0x10
	if sub & 0x10:
		routine = 4
	return true


func update() -> void:
	if routine == 2:
		SolidHelpers.solid_wall(self, 0x13, 0x28)
	out_of_range_check(false)
