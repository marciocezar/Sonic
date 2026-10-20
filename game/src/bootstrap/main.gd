extends Node
## Controlador principal: estados do aplicativo, laço de simulação em tick fixo (60 Hz),
## composição da visão (SubViewport com escala inteira/letterbox) e menus.
##
## Argumentos (após "--"), usados pelos alvos do Makefile e testes de fumaça:
##   --profile=fidelity|enhanced  --levelpacks=<dir privado>  --level=<id>
##   --autoplay=<replay.json>  --quit-after=<quadros>  --screenshot=<png>  --touch=on|off
##   --force-clear=<quadro> (teste: encerra o ato e mostra os resultados)

const TICK := 1.0 / 60.0
const MAX_STEPS := 4

var state: String = "title"
var sim: GameSim
var catalog := LevelCatalog.new()
var level_id: String = ""
var level_title: String = ""
var args: Dictionary = {}
var viewport: SubViewport
var view_rect: TextureRect
var world: WorldView
var overlay: GameOverlay
var touch_layer: CanvasLayer
var acc: float = 0.0
var menu_index: int = 0
var ui_scale: int = 1
var view_w: int = 320
var view_h: int = 224
var anim_t: int = 0
var titlecard_t: int = 0
var bonus_time: int = 0
var bonus_rings: int = 0
var actclear_t: int = 0
var remap_action: String = ""
var prev_bits: int = 0
var frame_bits: int = 0
var autoplay: Replay
var autoplay_frame: int = 0
var frames_run: int = 0
var _quitting: bool = false
var options_return: String = "title"
var checkpoint: Dictionary = {}
var packs_dir: String = ""
var title_message: String = ""
var title_message_t: int = 0
var select_scroll: int = 0
var boss_wait: int = 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	if args.has("lint") or OS.get_cmdline_user_args().has("--lint"):
		_lint_and_quit()
		return
	if args.has("profile"):
		Settings.profile = "fidelity" if args["profile"] == "fidelity" else "enhanced"
	if args.has("touch"):
		Settings.touch_mode = args["touch"]
	packs_dir = args.get("levelpacks", OS.get_environment("SONIC_LEVELPACKS"))
	# conteúdo do jogo: embutido no build privado (dist-private/) ou --rom= (testes/laboratório)
	RomImporter.forget_user_rom()  # cópias deixadas por versões antigas (opção "carregar ROM" removida)
	catalog.importer.load_embedded()
	if args.has("rom") and FileAccess.file_exists(args["rom"]):
		var imp := RomImporter.new()
		if imp.load_rom(FileAccess.get_file_as_bytes(args["rom"])) == "":
			catalog.importer = imp
	catalog.scan(packs_dir)
	_build_tree()
	_apply_profile()
	if args.has("autoplay"):
		autoplay = Replay.load_file(args["autoplay"])
	if args.has("level"):
		start_level(args["level"])
	if args.has("test-progression"):
		_test_progression()
		return
	get_viewport().size_changed.connect(_layout_view)
	_layout_view()


## Carrega e recompila todos os scripts (com autoloads disponíveis) e encerra (make lint).
func _lint_and_quit() -> void:
	var stack := ["res://src", "res://tests"]
	var total := 0
	var bad := 0
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				total += 1
				var sc := load(dir.path_join(f)) as GDScript
				if sc == null or not sc.can_instantiate():
					bad += 1
					print("LINTFAIL ", dir.path_join(f))
		for d in DirAccess.get_directories_at(dir):
			stack.append(dir.path_join(d))
	print("LINT scripts=%d falhas=%d" % [total, bad])
	get_tree().quit.call_deferred(0 if bad == 0 else 1)


func _build_tree() -> void:
	var root_ui := Control.new()
	root_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ui)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(bg)
	viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	world = WorldView.new()
	viewport.add_child(world)
	overlay = GameOverlay.new()
	overlay.main = self
	viewport.add_child(overlay)
	view_rect = TextureRect.new()
	view_rect.texture = viewport.get_texture()
	view_rect.stretch_mode = TextureRect.STRETCH_SCALE
	view_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(view_rect)
	touch_layer = CanvasLayer.new()
	touch_layer.layer = 10
	add_child(touch_layer)
	var tov := preload("res://src/input/touch_overlay.gd").new()
	touch_layer.add_child(tov)


func _apply_profile() -> void:
	if Settings.profile == "enhanced":
		view_w = 640
		view_h = 448
		ui_scale = 2
	else:
		view_w = 320
		view_h = 224
		ui_scale = 1
	viewport.size = Vector2i(view_w, view_h)
	if sim != null:
		world.configure(sim, Settings.profile)
	_sync_filter()
	_layout_view()


## Arte original fica nítida (inclusive o 2x do perfil enhanced). O linear só vale para a arte própria.
func _sync_filter() -> void:
	if view_rect == null:
		return
	var procedural := Settings.profile == "enhanced" and (world == null or world.vram_art == null)
	view_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if procedural else CanvasItem.TEXTURE_FILTER_NEAREST


func _layout_view() -> void:
	if view_rect == null:
		return
	var avail := get_viewport().get_visible_rect().size
	var k := minf(avail.x / float(view_w), avail.y / float(view_h))
	if Settings.profile == "fidelity" and k >= 1.0:
		var wpx := Vector2(DisplayServer.window_get_size())
		var ratio := wpx.x / maxf(avail.x, 1.0)
		var kp := floorf(k * ratio) / ratio  # escala inteira em pixels físicos
		if kp > 0.0:
			k = kp
	var size := Vector2(view_w, view_h) * k
	view_rect.position = ((avail - size) / 2.0).floor()
	view_rect.size = size


# --- laço principal ---------------------------------------------------------------------

func _process(delta: float) -> void:
	anim_t += 1
	if title_message_t > 0:
		title_message_t -= 1
	var bits := _read_bits()
	frame_bits = bits
	var press := bits & ~prev_bits
	prev_bits = bits
	match state:
		"title":
			_title_input(press)
		"levelselect":
			_select_input(press)
		"options":
			_options_input(press)
		"titlecard":
			titlecard_t += 1
			var card: RomTitleCard = world.title_card
			if card != null:
				# cartão original: entra sobre tela preta (60 Hz); a fase começa quando o número do ato chega
				acc += minf(delta, 0.25)
				while acc >= TICK:
					acc -= TICK
					card.step()
					if card.arrived() and world.art_ready():
						card.release()
						world.black_out = false
						state = "playing"
						acc = 0.0
						break
			elif world.art_ready() and (titlecard_t >= 120 or (press & 0xF0) != 0):
				state = "playing"
				acc = 0.0
		"playing", "dead":
			if press & 128 and state == "playing":
				state = "paused"
				menu_index = 0
				get_tree().paused = false
			else:
				_run_sim(delta)
		"paused":
			_pause_input(press)
		"actclear":
			actclear_t += 1
			var res: RomResults = world.results
			if res != null:
				acc += minf(delta, 0.25)
				while acc >= TICK:
					acc -= TICK
					sim.tick(0)
					frames_run += 1
					AudioBus.handle_events(sim.events)
					res.step(sim)
					AudioBus.handle_events(sim.events)
					if res.finished:
						world.results = null
						_next_level()
						break
			elif actclear_t > 240 or (actclear_t > 60 and (press & 0xF0) != 0):
				_next_level()
		"gameover":
			if press & 0xF0:
				_to_title()
	_check_quit()


func _read_bits() -> int:
	if autoplay != null and (state == "playing" or state == "dead"):
		return autoplay.input_at(autoplay_frame + 1)
	return InputRouter.read_bits()


func _run_sim(delta: float) -> void:
	acc += minf(delta, 0.25)
	var steps := 0
	while acc >= TICK and steps < MAX_STEPS:
		var b := frame_bits if autoplay == null else autoplay.input_at(autoplay_frame + 1)
		if autoplay != null:
			autoplay_frame += 1
		sim.tick(b & 0x7F if state == "playing" else 0)
		if world.title_card != null:
			world.title_card.step()
			if world.title_card.done():
				world.title_card = null
		AudioBus.handle_events(sim.events)
		frames_run += 1
		acc -= TICK
		steps += 1
		_after_tick()
	if steps == MAX_STEPS:
		acc = 0.0


func _after_tick() -> void:
	# teste: --force-clear=N encerra o ato no quadro N (tela de resultados)
	if args.has("force-clear") and frames_run == int(args["force-clear"]):
		sim.level_complete = true
	for e in sim.events:
		if e.get("type") == "special_stage" and state == "playing":
			# estágios especiais não reconstruídos: segue para o fim do ato (registrado como BLOQUEADO)
			_show_message("ESTAGIO ESPECIAL AINDA NAO RECONSTRUIDO")
			sim.level_complete = true
	if not sim.level_complete and _boss_act_end_reached():
		boss_wait += 1
		if boss_wait == 1:
			_show_message("CHEFE AINDA NAO RECONSTRUIDO - AVANCANDO")
		if boss_wait > 180:
			sim.level_complete = true
	if sim.level_complete and state == "playing":
		_begin_actclear()
		return
	if sim.game_over:
		state = "gameover"
		return
	if sim.restart_requested:
		var goto: Dictionary = {}
		for e in sim.events:
			if e.get("type") == "goto_level":
				goto = e
		if not goto.is_empty():
			start_level("sbz3")
		else:
			_restart_level()


func _check_quit() -> void:
	if _quitting:
		return
	if args.has("quit-after") and frames_run >= int(args["quit-after"]) and (state == "playing" or state == "dead" or state == "actclear"):
		_quitting = true
		set_process(false)
		if args.has("screenshot"):
			await RenderingServer.frame_post_draw
			var img := viewport.get_texture().get_image()
			img.save_png(args["screenshot"])
		print("smoke: %d quadros; estado=%s; x=%d y=%d anéis=%d" % [frames_run, state, sim.player.x, sim.player.y, sim.rings])
		get_tree().quit(0)


# --- fases --------------------------------------------------------------------------------

## Atos com chefe (3º ato e FZ): como os chefes ainda não foram reconstruídos, ao chegar ao fim da área
## o jogo avança para o próximo ato (provisório e explícito na tela).
func _boss_act_end_reached() -> bool:
	if not level_id in ["ghz3", "mz3", "syz3", "lz3", "slz3", "fz"]:
		return false
	var p := sim.player
	return p.routine == Player.RT_CONTROL and p.x >= sim.limit_right2 + 160


## Teste automatizado da progressão (make test-progression): completa cada ato e registra a sequência.
func _test_progression() -> void:
	var order: PackedStringArray = []
	start_level(LevelCatalog.ORIGINAL_ORDER[0])
	var guard := 0
	while state != "title" and guard < 40:
		order.append(level_id + ":" + str(sim.level.chunk_count > 0))
		sim.level_complete = true
		state = "playing"
		_after_tick()
		actclear_t = 999
		_next_level()
		guard += 1
	print("progressao: " + ",".join(order))
	get_tree().quit(0)


func _dress_lab(L: LevelData) -> void:
	if L == null or not L.id.begins_with("lab") or not catalog.importer.is_loaded():
		return
	var art: Dictionary = catalog.importer.zone_art(0)
	L.sprite_rom = catalog.importer.rom
	L.sprite_vram = art["vram"]
	L.sprite_cram = PackedInt32Array(art["cram"])


func _show_message(t: String) -> void:
	title_message = t
	title_message_t = 240


func start_level(lid: String, keep_score: bool = false) -> void:
	var L := catalog.load_level(lid)
	if L == null:
		push_error("fase indisponível: " + lid)
		return
	_dress_lab(L)
	var old := sim
	sim = GameSim.new()
	sim.setup(L)
	if keep_score and old != null:
		sim.score = old.score
		sim.lives = old.lives
	level_id = lid
	boss_wait = 0
	level_title = LevelCatalog._title(lid)
	if lid == "lab1":
		level_title = "LAB ZONE"
	elif lid == "lab2":
		level_title = "LAB ZONE 2"
	world.configure(sim, Settings.profile)
	_sync_filter()
	_setup_title_card(L)
	state = "titlecard"
	titlecard_t = 0
	checkpoint = {}
	Settings.progress_level = lid
	Settings.save_settings()


func _setup_title_card(L: LevelData) -> void:
	world.results = null
	world.title_card = null
	world.black_out = false
	if world.rom_sprites != null and L.card_vram.size() == 0x10000:
		world.title_card = RomTitleCard.new(L.rom, L.card_vram, L.cram, L.zone, L.act)
		world.black_out = true


func _restart_level() -> void:
	var lives := sim.lives
	var score := sim.score
	var lamp := sim.lamp_save
	var L := catalog.load_level(level_id)
	_dress_lab(L)
	sim = GameSim.new()
	sim.setup(L, lamp)
	sim.lives = lives
	sim.score = score
	world.configure(sim, Settings.profile)
	_sync_filter()
	_setup_title_card(L)
	state = "titlecard"
	titlecard_t = 60


func _begin_actclear() -> void:
	state = "actclear"
	actclear_t = 0
	# bônus medidos (placa, ROM 0xECF0): tempo por (min*60+s)/15 e anéis*10, em unidades de 10 pontos
	if sim.time_bonus == 0 and sim.ring_bonus == 0:
		var secs := sim.time_min * 60 + sim.time_sec
		sim.time_bonus = SignpostObj.TIME_BONUS[mini(secs / 15, 20)]
		sim.ring_bonus = sim.rings * 10
	bonus_time = sim.time_bonus * 10
	bonus_rings = sim.ring_bonus * 10
	if world.rom_hud != null and sim.level.card_vram.size() == 0x10000:
		# resultados originais: os pontos são transferidos aos poucos pela própria tela (0xC642)
		world.results = RomResults.new(sim.level.rom, world.rom_hud, sim.level.card_vram, sim.level.act,
				sim.time_bonus, sim.ring_bonus)
		return
	sim.add_score(sim.time_bonus + sim.ring_bonus)


func _next_level() -> void:
	var n := catalog.next_of(level_id)
	if n == "":
		_to_title()
		return
	start_level(n, true)


func _to_title() -> void:
	state = "title"
	menu_index = 0
	sim = null
	world.sim = null


# --- menus --------------------------------------------------------------------------------

## Itens do título como pares [ação, rótulo].
func title_actions() -> Array:
	var items: Array = []
	if catalog.has_originals():
		items.append(["play_original", "JOGAR"])
		items.append(["select", "SELECIONAR FASE"])
	items.append(["play_lab", "JOGAR LAB ZONE"])
	items.append(["play_lab2", "JOGAR LAB ZONE 2"])
	items.append(["options", "OPCOES"])
	if not PlatformInfo.is_web() and not PlatformInfo.is_mobile_native():
		items.append(["quit", "SAIR"])
	return items


func title_items() -> Array:
	var out: Array = []
	for it in title_actions():
		out.append(it[1])
	return out


func select_items() -> Array:
	var out: Array = []
	for e in catalog.entries:
		if e["source"] != "builtin":
			out.append(e)
	return out


func _menu_nav(press: int, count: int) -> void:
	if press & 1:
		menu_index = (menu_index - 1 + count) % count
		AudioBus.play_sfx("select")
	if press & 2:
		menu_index = (menu_index + 1) % count
		AudioBus.play_sfx("select")


func _title_input(press: int) -> void:
	var items := title_actions()
	if menu_index >= items.size():
		menu_index = 0
	_menu_nav(press, items.size())
	if (press & (128 | 64 | 32 | 16)) == 0:
		return
	match items[menu_index][0]:
		"play_original":
			start_level(LevelCatalog.ORIGINAL_ORDER[0])
		"select":
			state = "levelselect"
			menu_index = 0
		"play_lab":
			start_level("lab1")
		"play_lab2":
			start_level("lab2")
		"options":
			options_return = "title"
			state = "options"
			menu_index = 0
		"quit":
			get_tree().quit(0)


func _select_input(press: int) -> void:
	var items := select_items()
	if items.is_empty():
		state = "title"
		return
	_menu_nav(press, items.size() + 1)
	if press & (128 | 64 | 32 | 16):
		if menu_index >= items.size():
			state = "title"
			menu_index = 0
		else:
			start_level(items[menu_index]["id"])


func option_items() -> Array:
	return [
		"PERFIL VISUAL: " + Settings.profile.to_upper(),
		"CONTROLE DE TOQUE: " + Settings.touch_mode.to_upper(),
		"TAMANHO DO TOQUE: %d%%" % int(Settings.touch_size * 100),
		"OPACIDADE DO TOQUE: %d%%" % int(Settings.touch_opacity * 100),
		"VOLUME EFEITOS: %d%%" % int(Settings.sfx_volume * 100),
		"REMAPEAR A (%s)" % InputRouter.key_names("btn_a"),
		"REMAPEAR B (%s)" % InputRouter.key_names("btn_b"),
		"REMAPEAR C (%s)" % InputRouter.key_names("btn_c"),
		"REMAPEAR START (%s)" % InputRouter.key_names("start"),
		"RESTAURAR TECLAS PADRAO",
		"DEPURACAO: " + ("SIM" if Settings.show_debug else "NAO"),
		"VOLTAR",
	]


func _options_input(press: int) -> void:
	if remap_action != "":
		return
	var items := option_items()
	_menu_nav(press, items.size())
	var left := (press & 4) != 0
	var right := (press & 8) != 0
	var ok := (press & (128 | 64 | 32 | 16)) != 0
	var delta := (-1 if left else (1 if right else 0))
	match menu_index:
		0:
			if ok or delta != 0:
				Settings.profile = "fidelity" if Settings.profile == "enhanced" else "enhanced"
				_apply_profile()
		1:
			if ok or delta != 0:
				var modes := ["auto", "on", "off"]
				Settings.touch_mode = modes[(modes.find(Settings.touch_mode) + 1) % 3]
		2:
			Settings.touch_size = clampf(Settings.touch_size + 0.1 * delta, 0.5, 1.8)
		3:
			Settings.touch_opacity = clampf(Settings.touch_opacity + 0.05 * delta, 0.15, 1.0)
		4:
			Settings.sfx_volume = clampf(Settings.sfx_volume + 0.1 * delta, 0.0, 1.0)
		5, 6, 7, 8:
			if ok:
				remap_action = ["btn_a", "btn_b", "btn_c", "start"][menu_index - 5]
		9:
			if ok:
				InputRouter.reset_bindings()
		10:
			if ok or delta != 0:
				Settings.show_debug = not Settings.show_debug
		11:
			if ok:
				Settings.save_settings()
				state = options_return
				menu_index = 0
				return
	if ok or delta != 0:
		Settings.save_settings()


func _input(event: InputEvent) -> void:
	if remap_action != "" and event is InputEventKey and event.pressed and not event.echo:
		InputRouter.rebind(remap_action, (event as InputEventKey).physical_keycode)
		remap_action = ""
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_F3:
		Settings.show_debug = not Settings.show_debug


func _pause_input(press: int) -> void:
	_menu_nav(press, 4)
	if press & 128 and menu_index == 0:
		state = "playing"
		return
	if press & (64 | 32 | 16 | 128):
		match menu_index:
			0:
				state = "playing"
			1:
				_restart_level()
			2:
				options_return = "paused"
				state = "options"
				menu_index = 0
			3:
				_to_title()
