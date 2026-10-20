class_name RockObj
extends GameObject
## Rocha roxa de GHZ (ID 0x3B): sólido de meia-largura 0x1B, meia-altura 0x10.


func init() -> bool:
	art = "rock"
	act_width = 0x13
	priority = 4
	return true


func update() -> void:
	SolidHelpers.solid_object(self, 0x1B, 0x10, 0x10, x)
	out_of_range_check(false)
