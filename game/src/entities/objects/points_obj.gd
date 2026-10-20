class_name PointsObj
extends GameObject
## Indicador de pontos: sobe a -0x300 desacelerando 0x18/quadro e some ao parar.


func _init() -> void:
	kind = 0x29


func init() -> bool:
	kind = 0x29
	art = "points"
	yv = -0x300
	act_width = 8
	priority = 1
	return true


func update() -> void:
	if yv >= 0:
		delete()
		return
	speed_to_pos()
	yv = Fx.s16(yv + 0x18)
