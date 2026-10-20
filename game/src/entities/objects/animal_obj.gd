class_name AnimalObj
extends GameObject
## Animal libertado de um inimigo. Tipo sorteado (gerador pseudoaleatório) entre 2 por zona; cai,
## pousa e segue saltando (tipos terrestres) ou voando (tipos 1 e 5). Parâmetros medidos (EV-OBJ):
## índice por zona e velocidades (x, y) por tipo.

const ZONE_TYPES := [[0, 5], [2, 3], [6, 3], [4, 5], [4, 1], [0, 1]]
const SPEEDS := [[-0x200, -0x400], [-0x200, -0x300], [-0x180, -0x300], [-0x140, -0x180],
		[-0x1C0, -0x300], [-0x300, -0x400], [-0x280, -0x380]]
const FLYING := [1, 5]

var kind_type: int = 0
var spd_x: int = 0
var spd_y: int = 0


func _init() -> void:
	kind = 0x28


func init() -> bool:
	kind = 0x28
	art = "animal"
	var r: int = sim.random() & 1
	var z: int = sim.level.zone if sim.level.zone < 6 else 0
	kind_type = ZONE_TYPES[z][r]
	spd_x = SPEEDS[kind_type][0]
	spd_y = SPEEDS[kind_type][1]
	height = 0xC
	render |= 1
	priority = 6
	act_width = 8
	time_frame = 7
	frame = 2
	yv = -0x400
	routine = 2
	if not sim.boss_active:
		var pts := PointsObj.new()
		pts.x = x
		pts.y = y
		pts.frame = int(vars.get("points_frame", 0))
		sim.objects.place(pts)
	return false


func update() -> void:
	if routine == 2:
		if (render & 0x80) == 0:
			delete()
			return
		object_fall()
		if yv >= 0:
			var fd: Array = sim.terrain.obj_floor_dist(x, y, height, false)
			if fd[0] < 0:
				y = Fx.u16(y + fd[0])
				xv = spd_x
				yv = spd_y
				frame = 1
				routine = 4
		return
	if kind_type in FLYING:
		speed_to_pos()
		yv = Fx.s16(yv + 0x18)
		if yv >= 0:
			var fd2: Array = sim.terrain.obj_floor_dist(x, y, height, false)
			if fd2[0] < 0:
				y = Fx.u16(y + fd2[0])
				yv = spd_y
		time_frame -= 1
		if time_frame < 0:
			time_frame = 1
			frame = (frame + 1) & 1
	else:
		object_fall()
		frame = 1
		if yv >= 0:
			frame = 0
			var fd3: Array = sim.terrain.obj_floor_dist(x, y, height, false)
			if fd3[0] < 0:
				y = Fx.u16(y + fd3[0])
				yv = spd_y
	if (render & 0x80) == 0:
		delete()
