class_name GameOverlay
extends Node2D
## HUD e menus desenhados dentro da visão do jogo (fonte pixelada própria).

var main  # referência ao controlador principal (main.gd)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if main == null:
		return
	var s: int = main.ui_scale
	_draw_state(s)
	_banner(s)


func _draw_state(s: int) -> void:
	match main.state:
		"title":
			_title(s)
		"options":
			_options(s)
		"levelselect":
			_levelselect(s)
		"playing", "paused", "titlecard", "actclear", "dead":
			_hud(s)
			if main.state == "paused":
				_pause(s)
			elif main.state == "titlecard":
				_titlecard(s)
			elif main.state == "actclear":
				_actclear(s)
		"gameover":
			_hud(s)
			_center_text("GAME OVER", 100 * s, Color(1, 0.9, 0.3), 3 * s)
			_center_text("START: TITULO", 140 * s, Color.WHITE, s)


func _banner(s: int) -> void:
	if main.title_message_t <= 0:
		return
	var y: int = main.view_h - 40 * s
	draw_rect(Rect2(0, y - 4 * s, main.view_w, 16 * s), Color(0, 0, 0, 0.75))
	_center_text(main.title_message, y, Color(1, 0.95, 0.6), s)


func _center_text(t: String, y: int, c: Color, sc: int) -> void:
	var w := PixelFont.width(t, sc)
	PixelFont.draw(self, Vector2((main.view_w - w) / 2, y), t, c, sc)


func _title(s: int) -> void:
	draw_rect(Rect2(0, 0, main.view_w, main.view_h), Color("0b1640"))
	for i in range(24):
		var x := fposmod(float(i) * 41.0 - float(main.anim_t) * 0.5 * (1 + i % 3), float(main.view_w))
		draw_rect(Rect2(x, float((i * 37) % main.view_h), s, s), Color(1, 1, 1, 0.6))
	_center_text("MEGADRIVE", 28 * s, Color("5fbfff"), 3 * s)
	_center_text("PLATFORMER LAB", 54 * s, Color("ffd23f"), 2 * s)
	_center_text("RECONSTRUCAO DE PESQUISA - SEM AFILIACAO", 74 * s, Color(0.7, 0.8, 1), s)
	var y := 96 * s
	var items: Array = main.title_items()
	for i in range(items.size()):
		var sel: bool = i == main.menu_index
		var c := Color(1, 0.9, 0.3) if sel else Color.WHITE
		var t: String = ("> " if sel else "  ") + str(items[i])
		PixelFont.draw(self, Vector2(40 * s, y), t, c, s)
		y += 11 * s
	PixelFont.draw(self, Vector2(8 * s, (main.view_h / s - 12) * s), "PERFIL: " + Settings.profile.to_upper() + "   " + PlatformInfo.name().to_upper(), Color(0.6, 0.7, 0.9), s)
	if not main.catalog.has_originals():
		_center_text("BUILD PUBLICO: SO A LAB ZONE", (main.view_h / s - 34) * s, Color(0.8, 0.8, 0.5), s)
		_center_text("ZONAS ORIGINAIS: MAKE BUILD-PRIVATE-<ALVO>", (main.view_h / s - 24) * s, Color(0.8, 0.8, 0.5), s)


func _levelselect(s: int) -> void:
	draw_rect(Rect2(0, 0, main.view_w, main.view_h), Color("101828"))
	_center_text("SELECIONAR FASE", 10 * s, Color("ffd23f"), 2 * s)
	var items: Array = main.select_items()
	var rows := 15
	var first := clampi(main.menu_index - rows / 2, 0, maxi(0, items.size() + 1 - rows))
	var y := 32 * s
	for i in range(first, mini(items.size() + 1, first + rows)):
		var sel: bool = i == main.menu_index
		var label: String = "VOLTAR" if i >= items.size() else str(items[i]["title"])
		PixelFont.draw(self, Vector2(40 * s, y), ("> " if sel else "  ") + label, Color(1, 0.9, 0.3) if sel else Color.WHITE, s)
		y += 12 * s


func _options(s: int) -> void:
	draw_rect(Rect2(0, 0, main.view_w, main.view_h), Color("101828"))
	_center_text("OPCOES", 14 * s, Color("ffd23f"), 2 * s)
	var y := 40 * s
	var items: Array = main.option_items()
	for i in range(items.size()):
		var sel: bool = i == main.menu_index
		var c := Color(1, 0.9, 0.3) if sel else Color.WHITE
		PixelFont.draw(self, Vector2(16 * s, y), ("> " if sel else "  ") + str(items[i]), c, s)
		y += 11 * s
	if main.remap_action != "":
		draw_rect(Rect2(20 * s, 80 * s, main.view_w - 40 * s, 40 * s), Color(0, 0, 0, 0.85))
		_center_text("PRESSIONE A TECLA PARA " + main.remap_action.to_upper(), 96 * s, Color.WHITE, s)


func _hud(s: int) -> void:
	var sim: GameSim = main.sim
	if sim == null:
		return
	if main.world.rom_hud != null and not Settings.show_debug:
		return  # placar original desenhado pelo WorldView (sprite + dígitos da ROM)
	var x := 16 * s
	var y := 8 * s
	var flash: bool = (sim.rings == 0 and (main.anim_t / 8) % 2 == 0)
	PixelFont.draw(self, Vector2(x, y), "SCORE", Color("ffd23f"), s)
	PixelFont.draw(self, Vector2(x + 48 * s, y), str(sim.score * 10), Color.WHITE, s)
	PixelFont.draw(self, Vector2(x, y + 12 * s), "TIME", Color("ffd23f"), s)
	PixelFont.draw(self, Vector2(x + 48 * s, y + 12 * s), "%d:%02d" % [sim.time_min, sim.time_sec], Color.WHITE, s)
	PixelFont.draw(self, Vector2(x, y + 24 * s), "RINGS", Color(1, 0.3, 0.3) if flash else Color("ffd23f"), s)
	PixelFont.draw(self, Vector2(x + 48 * s, y + 24 * s), str(sim.rings), Color.WHITE, s)
	PixelFont.draw(self, Vector2(x, main.view_h - 16 * s), "x%d" % sim.lives, Color.WHITE, s)
	if Settings.show_debug:
		var p := sim.player
		var lines := [
			"X %04X.%04X Y %04X.%04X" % [p.x, p.xs, p.y, p.ys],
			"VX %d VY %d GS %d" % [p.xv, p.yv, p.gs],
			"ANG %02X ST %02X AN %02X RT %d" % [p.angle, p.status, p.anim, p.routine],
			"CAM %d %d F %d" % [sim.camera.x, sim.camera.y, sim.frame],
		]
		for i in range(lines.size()):
			PixelFont.draw(self, Vector2(main.view_w - PixelFont.width(lines[i], s) - 4 * s, (8 + i * 9) * s), lines[i], Color(0.7, 1, 0.7), s)


func _pause(s: int) -> void:
	draw_rect(Rect2(0, 0, main.view_w, main.view_h), Color(0, 0, 0, 0.45))
	_center_text("PAUSA", 80 * s, Color.WHITE, 2 * s)
	var items := ["CONTINUAR", "REINICIAR FASE", "OPCOES", "SAIR PARA TITULO"]
	var y := 108 * s
	for i in range(items.size()):
		var sel: bool = i == main.menu_index
		_center_text(("> " if sel else "") + items[i], y, Color(1, 0.9, 0.3) if sel else Color.WHITE, s)
		y += 11 * s


func _titlecard(s: int) -> void:
	if main.world.title_card != null:
		return  # cartão original desenhado pelo WorldView
	var t: int = main.titlecard_t
	var a := 1.0 if t < 90 else maxf(0.0, 1.0 - float(t - 90) / 30.0)
	var name: String = main.level_title
	draw_rect(Rect2(0, 70 * s, main.view_w, 40 * s), Color(0.05, 0.1, 0.4, 0.8 * a))
	_center_text(name, 84 * s, Color(1, 1, 1, a), 2 * s)


func _actclear(s: int) -> void:
	if main.world.results != null:
		return  # resultados originais desenhados pelo WorldView
	var sim: GameSim = main.sim
	_center_text("ATO CONCLUIDO", 60 * s, Color("ffd23f"), 2 * s)
	_center_text("BONUS TEMPO  %d" % main.bonus_time, 96 * s, Color.WHITE, s)
	_center_text("BONUS ANEIS  %d" % main.bonus_rings, 110 * s, Color.WHITE, s)
	_center_text("PONTOS  %d" % (sim.score * 10), 130 * s, Color.WHITE, s)
