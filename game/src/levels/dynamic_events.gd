class_name DynamicEvents
extends RefCounted
## Eventos dinâmicos de limites de câmera por zona/ato (especificação em docs/gameplay/progressao.md).
## Cada ato ajusta o limite inferior-alvo (limit_bottom1) conforme a posição da câmera;
## GameSim aproxima limit_bottom2 do alvo a 2 px/quadro (8 px no ar perto do limite).
## Zonas sem roteiro implementado ficam com os limites iniciais (status registrado em docs/qa).


static func run(sim) -> void:
	match sim.level.zone:
		0:
			_ghz(sim)
		_:
			pass


static func _ghz(sim) -> void:
	var cx: int = sim.camera.x
	match sim.level.act:
		0:
			sim.limit_bottom1 = 0x300
			if cx >= 0x1780:
				sim.limit_bottom1 = 0x400
		1:
			sim.limit_bottom1 = 0x300
			if cx >= 0xED0:
				sim.limit_bottom1 = 0x200
				if cx >= 0x1600:
					sim.limit_bottom1 = 0x400
					if cx >= 0x1D60:
						sim.limit_bottom1 = 0x300
		2:
			_ghz3(sim, cx)


static func _ghz3(sim, cx: int) -> void:
	match sim.dle_routine:
		0:
			sim.limit_bottom1 = 0x300
			if cx < 0x380:
				return
			sim.limit_bottom1 = 0x310
			if cx < 0x960:
				return
			if sim.camera.y >= 0x280:
				sim.limit_bottom1 = 0x400
				if cx < 0x1380:
					sim.limit_bottom1 = 0x4C0
					sim.limit_bottom2 = 0x4C0
				if cx < 0x1700:
					return
			sim.limit_bottom1 = 0x300
			sim.dle_routine = 2
		2:
			if cx < 0x960:
				sim.dle_routine = 0
			if cx < 0x2960:
				return
			sim.objects.spawn_boss_ghz()
			sim.emit_music("boss")
			sim.lock_screen = true
			sim.dle_routine = 4
		4:
			sim.limit_left2 = cx
