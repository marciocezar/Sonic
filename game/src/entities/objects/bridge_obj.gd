class_name BridgeObj
extends GameObject
## Ponte de toras (ID 0x11, GHZ): subtipo = número de toras (16 px cada). Afunda sob o jogador.
## Profundidade e curva derivadas por fórmula (verificadas contra as tabelas da ROM 0x76CC/0x77DC):
##   profundidade(n, i) = 2·min(i+1, n-i) (272/272);  curva(k, j) = min(255, seno(((j+1)·64)/(k+1))) (130/136 + errata).

var logs: Array = []  # objetos-tora (inclui self na posição central)
var base_y: int = 0
var bend: int = 0  # ângulo 0..0x40
var pos: int = 0  # tora sob o jogador
var is_log: bool = false
var count: int = 0


static func depth(n: int, i: int) -> int:
	return 2 * mini(i + 1, n - i) if i < n else 0


## Errata medida: 6 de 136 entradas da tabela de referência diferem da fórmula (EV-TAB bridge).
const CURVE_ERRATA := {Vector2i(5, 2): 176, Vector2i(9, 4): 176, Vector2i(11, 2): 92,
		Vector2i(11, 5): 176, Vector2i(11, 8): 234, Vector2i(13, 6): 176}


static func curve(k: int, j: int) -> int:
	if j > k:
		return 0
	var key := Vector2i(k, j)
	if CURVE_ERRATA.has(key):
		return CURVE_ERRATA[key]
	return mini(255, Trig.sine(((j + 1) * 64) / (k + 1)))


func init() -> bool:
	art = "log"
	priority = 3
	if is_log:
		act_width = 8
		routine = 0xA
		return false
	act_width = 0x80
	routine = 2
	var n := sub
	base_y = y
	var d3 := x - (n >> 1) * 16
	logs.clear()
	count = 0
	# n-1 iterações (laço dbf com n-2); o próprio objeto vira a tora na posição x central
	for _it in range(maxi(n - 1, 0)):
		var s: int = sim.objects.free_slot()
		if s < 0:
			break
		count += 1
		if d3 == x:
			d3 += 16
			logs.append(self)
			count += 1
		var lg := BridgeObj.new()
		lg.is_log = true
		lg.kind = 0x11
		lg.x = d3
		lg.y = y
		lg.base_y = y
		lg.routine = 0xA
		lg.art = "log"
		lg.act_width = 8
		lg.priority = 3
		sim.objects.place(lg, ObjectManager.FIRST_LEVEL_SLOT, true)
		logs.append(lg)
		d3 += 16
	sub = count
	vars["base_y"] = base_y
	return true


func update() -> void:
	if is_log:
		return
	if routine == 2:
		var n := sub
		var d1 := n * 8 + 8
		var p: Player = sim.player
		if p.yv >= 0:
			var d0 := Fx.s16(p.x - x + d1)
			if d0 >= 0 and Fx.u16(d0) < Fx.u16(n * 16):
				SolidHelpers.platform_land(self, d1, y - 8, false)
		if bend != 0 and routine == 2:
			bend -= 4
			_bend()
	elif routine == 4:
		var n2 := sub
		var d1b := n2 * 8 + 8
		var p2: Player = sim.player
		var d0b := Fx.s16(p2.x - x + d1b)
		if (p2.status & Player.ST_AIR) or d0b < 0 or not (Fx.u16(d0b) < Fx.u16(n2 * 16)):
			p2.status &= ~Player.ST_ON_OBJ
			if p2.standing_on == self:
				p2.standing_on = null
			routine = 2
			status &= ~8
		else:
			pos = d0b >> 4
			if bend != 0x40:
				bend += 4
			_bend()
			var lg: GameObject = logs[mini(pos, logs.size() - 1)]
			p2.y = Fx.u16(lg.y - 8 - p2.yr)
	_chk_del()


func _bend() -> void:
	var d4 := Trig.sine(bend) & 0xFFFF
	var n := sub
	var d5 := depth(n, pos)
	for i in range(mini(pos + 1, logs.size())):
		var lg: GameObject = logs[i]
		var by: int = lg.base_y if lg != self else base_y
		lg.y = Fx.u16(by + ((((curve(pos, i) + 1) * d5) & 0xFFFFFFFF) * d4 >> 16))
	var right := n - pos - 1
	if right <= 0:
		return
	for k in range(right):
		var idx := pos + 1 + k
		if idx >= logs.size():
			break
		var lg2: GameObject = logs[idx]
		var by2: int = lg2.base_y if lg2 != self else base_y
		lg2.y = Fx.u16(by2 + ((((curve(right, right - 1 - k) + 1) * d5) & 0xFFFFFFFF) * d4 >> 16))


func _chk_del() -> void:
	var d0 := (x & 0xFF80) - ((Fx.u16(sim.camera.x) - 0x80) & 0xFF80)
	if Fx.u16(d0) > 0x280:
		for lg in logs:
			if lg != self:
				lg.delete()
		sim.objects.release(self)
		delete()
