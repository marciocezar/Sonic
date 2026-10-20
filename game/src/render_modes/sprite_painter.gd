class_name SpritePainter
extends RefCounted
## Sprites PRÓPRIOS desenhados com primitivas (personagem, anéis, monitores, inimigos...).
## Mesmo desenho nos dois perfis; no Fidelity é rasterizado a 320x224 (aspecto pixelado),
## no Enhanced a 640x448 com rotação suave. Hitboxes/lógica não dependem disto.

const BLUE := Color("1f5fe0")
const BLUE_D := Color("143f9f")
const SKIN := Color("f0c090")
const RED := Color("e03030")
const GOLD := Color("ffd23f")
const GOLD_D := Color("c08a10")

## Deslocamento de câmera atual (definido pelo WorldView antes de desenhar).
static var cam: Vector2 = Vector2.ZERO


static func _xf(ci: CanvasItem, pos: Vector2, rot: float = 0.0, sc: Vector2 = Vector2.ONE) -> void:
	ci.draw_set_transform(pos - cam, rot, sc)


static func _reset(ci: CanvasItem) -> void:
	ci.draw_set_transform(-cam, 0.0, Vector2.ONE)


static func draw_player(ci: CanvasItem, p: Player, smooth: bool, t: int) -> void:
	if not p.visible:
		return
	var pos := Vector2(p.x, p.y)
	var face := -1.0 if (p.status & Player.ST_LEFT) else 1.0
	var rolling := p.anim == Player.AN_ROLL or p.anim == Player.AN_ROLL2 or (p.status & Player.ST_ROLL) != 0
	if rolling:
		_ball(ci, pos, float(t) * 0.6 * face, 14.0)
		return
	var rot := 0.0
	if p.anim == Player.AN_WALK or p.anim == Player.AN_RUN:
		# ângulo 0 = chão; rotação visual no mesmo sentido (Y para baixo); Fidelity em passos de 45°
		var a := p.angle if smooth else ((p.angle + 0x10) & 0xE0)
		rot = float(a) / 256.0 * TAU
	_xf(ci, pos, rot, Vector2(face, 1.0))
	var speed: int = absi(p.gs)
	var phase := float(t) * (0.15 + float(speed) / 4096.0)
	# espinhos
	var spikes := PackedVector2Array([Vector2(-4, -14), Vector2(-17, -10), Vector2(-6, -6), Vector2(-19, -2),
			Vector2(-6, 2), Vector2(-15, 7), Vector2(-3, 6)])
	ci.draw_colored_polygon(spikes, BLUE_D)
	# corpo e cabeça
	ci.draw_circle(Vector2(0, -6), 9.0, BLUE)
	ci.draw_circle(Vector2(2, 4), 6.0, BLUE)
	ci.draw_circle(Vector2(4, 5), 4.0, SKIN)
	# rosto
	ci.draw_circle(Vector2(5, -6), 4.5, SKIN)
	ci.draw_circle(Vector2(4, -9), 3.2, Color.WHITE)
	ci.draw_circle(Vector2(5, -9), 1.4, Color.BLACK)
	ci.draw_circle(Vector2(9.5, -5), 1.3, Color.BLACK)
	# pernas/sapatos
	var legs := 0.0
	if p.anim == Player.AN_WALK or p.anim == Player.AN_RUN or p.anim == Player.AN_PUSH:
		legs = sin(phase * 4.0) * 5.0
	var ly := 12.0 if p.anim != Player.AN_DUCK else 8.0
	ci.draw_line(Vector2(0, 8), Vector2(-2 + legs, ly), BLUE_D, 2.5)
	ci.draw_line(Vector2(3, 8), Vector2(4 - legs, ly), BLUE_D, 2.5)
	ci.draw_rect(Rect2(Vector2(-6 + legs, ly), Vector2(7, 4)), RED)
	ci.draw_rect(Rect2(Vector2(0 - legs, ly), Vector2(7, 4)), RED)
	if p.anim == Player.AN_HURT or p.anim == Player.AN_DEATH:
		ci.draw_line(Vector2(2, -12), Vector2(8, -8), Color.BLACK, 1.5)
	_reset(ci)


static func _ball(ci: CanvasItem, pos: Vector2, ang: float, r: float) -> void:
	_xf(ci, pos, ang)
	ci.draw_circle(Vector2.ZERO, r, BLUE)
	for i in range(5):
		var a := float(i) / 5.0 * TAU
		var tip := Vector2(cos(a), sin(a)) * (r + 3.0)
		var s1 := Vector2(cos(a + 0.5), sin(a + 0.5)) * (r - 2.0)
		var s2 := Vector2(cos(a - 0.5), sin(a - 0.5)) * (r - 2.0)
		ci.draw_colored_polygon(PackedVector2Array([tip, s1, s2]), BLUE_D)
	ci.draw_arc(Vector2.ZERO, r * 0.55, 0.3, 1.6, 8, Color(1, 1, 1, 0.5), 2.0)
	_reset(ci)


static func draw_object(ci: CanvasItem, o: GameObject, t: int) -> void:
	var pos := Vector2(o.x, o.y)
	match o.art:
		"ring":
			var w := absf(cos(float(t + o.x) * 0.08)) * 6.0 + 1.5
			if o.routine >= 4:
				_sparkle(ci, pos, o.timer)
			else:
				_xf(ci, pos, 0.0, Vector2(w / 7.5, 1.0))
				ci.draw_arc(Vector2.ZERO, 6.0, 0, TAU, 20, GOLD, 3.0)
				ci.draw_arc(Vector2.ZERO, 6.0, 0.4, 1.8, 6, Color.WHITE, 1.0)
				_reset(ci)
		"monitor":
			if o.frame == 0xB:
				ci.draw_rect(Rect2(pos + Vector2(-14, 4), Vector2(28, 11)), Color("5f5f6f"))
				return
			ci.draw_rect(Rect2(pos + Vector2(-14, -15), Vector2(28, 30)), Color("8f8f9f"))
			ci.draw_rect(Rect2(pos + Vector2(-11, -12), Vector2(22, 18)), Color("202030"))
			ci.draw_rect(Rect2(pos + Vector2(-14, 9), Vector2(28, 6)), Color("5f5f6f"))
			_icon(ci, pos + Vector2(0, -3), o.anim, t)
		"powerup":
			_icon(ci, pos, o.anim, t)
		"explosion":
			var r := 4.0 + float(o.timer) * 0.4
			ci.draw_circle(pos, r, Color(1, 0.6, 0.1, 1.0 - float(o.timer) / 40.0))
			ci.draw_circle(pos, r * 0.6, Color(1, 1, 0.6, 1.0 - float(o.timer) / 40.0))
		"points":
			PixelFont.draw(ci, pos - Vector2(8, 4), ["100", "200", "500", "1000", "10000", "1000"][clampi(o.frame, 0, 5)], Color.WHITE)
		"animal":
			ci.draw_circle(pos, 5.0, Color("ffffff"))
			ci.draw_circle(pos + Vector2(3, -3), 2.0, Color("ff9f9f"))
		"spring":
			var _dir: String = str(o.vars.get("dir", "up"))
			var col := Color("ffd23f") if o.sub & 2 else RED
			ci.draw_rect(Rect2(pos + Vector2(-14, -2), Vector2(28, 6)), Color("9f9f9f"))
			ci.draw_rect(Rect2(pos + Vector2(-14, -10 + (4 if o.timer > 0 else 0)), Vector2(28, 6)), col)
		"spikes":
			var n := 3
			for i in range(n):
				var bx := -12.0 + float(i) * 8.0
				ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(bx, 16), pos + Vector2(bx + 4, -16), pos + Vector2(bx + 8, 16)]), Color("c0c0d0"))
		"enemy":
			ci.draw_circle(pos, 10.0, Color("d03030"))
			ci.draw_circle(pos + Vector2(-4 if o.status & 1 else 4, -3), 3.0, Color.WHITE)
			ci.draw_circle(pos + Vector2(0, 10), 4.0, Color("303030"))
		"signpost":
			ci.draw_rect(Rect2(pos + Vector2(-2, -8), Vector2(4, 32)), Color("9f9f9f"))
			var w2 := absf(cos(float(o.timer) * 0.3)) * 24.0 + 1.0
			ci.draw_rect(Rect2(pos + Vector2(-w2 / 2, -32), Vector2(w2, 24)), Color("2f6fdf"))
		"placeholder":
			ci.draw_rect(Rect2(pos - Vector2(8, 8), Vector2(16, 16)), Color(1, 0, 1, 0.6), false, 1.0)
		_:
			ci.draw_rect(Rect2(pos - Vector2(6, 6), Vector2(12, 12)), Color(1, 1, 1, 0.4), false, 1.0)


static func _sparkle(ci: CanvasItem, pos: Vector2, timer: int) -> void:
	var r := 2.0 + float(timer) * 0.3
	for i in range(4):
		var a := float(i) * PI / 2.0 + float(timer) * 0.2
		ci.draw_line(pos, pos + Vector2(cos(a), sin(a)) * r, Color(1, 1, 0.8, 1.0 - float(timer) / 24.0), 1.5)


static func _icon(ci: CanvasItem, pos: Vector2, kind: int, t: int) -> void:
	match kind:
		2:
			ci.draw_circle(pos, 5.0, BLUE)
			PixelFont.draw(ci, pos + Vector2(-2, -3), "1", Color.WHITE, 1, false)
		3:
			ci.draw_rect(Rect2(pos + Vector2(-6, 0), Vector2(12, 4)), RED)
			ci.draw_line(pos + Vector2(-4, -3), pos + Vector2(6, -3), Color.WHITE, 1.0)
		4:
			ci.draw_arc(pos, 6.0, 0, TAU, 16, Color("7fbfff"), 2.0)
		5:
			for i in range(5):
				var a := float(i) / 5.0 * TAU + float(t) * 0.05
				ci.draw_circle(pos + Vector2(cos(a), sin(a)) * 5.0, 1.5, Color("ffff7f"))
		6:
			ci.draw_arc(pos, 4.0, 0, TAU, 12, GOLD, 2.0)
		1:
			ci.draw_circle(pos, 5.0, Color("ff7f2f"))
		_:
			PixelFont.draw(ci, pos + Vector2(-2, -3), "S", Color.WHITE, 1, false)
