class_name PlaceholderObj
extends GameObject
## Objeto ainda não reconstruído: permanece inerte (sem colisão) e é removido fora da janela.


func init() -> bool:
	art = "placeholder"
	act_width = 8
	return true


func update() -> void:
	out_of_range_check()
