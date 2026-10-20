class_name GameSim
extends RefCounted
## Simulação determinística de uma fase em tick fixo de 60 Hz.
##
## Ordem do quadro (especificada em docs/architecture/simulacao.md, medida na referência):
##  1. entrada (hold/press) lida no início do quadro e temporizador do HUD;
##  2. objetos na ordem dos slots (jogador primeiro);
##  3. câmera e eventos dinâmicos de limites;
##  4. visibilidade na tela (usada pelas colisões do próximo quadro) e carga/descarga de objetos.
## A renderização e o áudio apenas observam o estado e a fila de eventos; nunca o alteram.

## Passagens de objetos antes de F0 (medido: ver docs/reverse-engineering/05-paridade.md).
static var PRESTART_PASSES: int = 1

signal sfx(name: String)
signal music(name: String)

var level: LevelData
var terrain: Terrain
var player: Player
var bg := BgScroll.new()
var camera: CameraState
var objects: ObjectManager
var animator: Animator
var osc: Oscillators = Oscillators.new()

var frame: int = 0
var pad_hold: int = 0
var pad_press: int = 0
var speed_max: int = 0x600
var speed_acc: int = 0xC
var speed_dec: int = 0x80
var look_shift: int = 0x60
var limit_left1: int = 0
var limit_right1: int = 0
var limit_top1: int = 0
var limit_bottom1: int = 0
var limit_left2: int = 0
var limit_right2: int = 0
var limit_top2: int = 0
var limit_bottom2: int = 0
var dle_routine: int = 0
## Poste de checkpoint: número do último poste ($FE30) e estado salvo (0x16FD2), restaurado no reinício (0x1704C).
var lamp_num: int = 0
var lamp_save: Dictionary = {}
var bg_scroll_vert: bool = false
var lock_screen: bool = false
var lock_ctrl: bool = false
var lock_multi: bool = false
var lock_multi_neg: bool = false
var debug_mode: bool = false  # $FE08 (modo de depuração do original; sempre falso aqui)
var jump_only: bool = false
var water_level: int = -1

var rings: int = 0
var lives: int = 3
var score: int = 0
var time_min: int = 0
var time_sec: int = 0
var time_frames: int = 0
var time_running: bool = true
var time_over: bool = false
var item_bonus: int = 0
var extra_life_flags: int = 0
var shield: bool = false
var invincible: bool = false
var shoes: bool = false
var hud_dirty: bool = true
var rng: int = 0
var framecount: int = 0
var vbla_count: int = 0  # contador de VBlanks (inclui quadros de lag)
var last_lamp: int = 0
var restart_requested: bool = false
var game_over: bool = false
var level_complete: bool = false
var reset_timer: int = 0
var events: Array = []  # eventos de áudio/efeitos deste quadro (consumidos pela apresentação)
var boss_defeated: bool = false
var boss_active: bool = false
var forced_hold: int = 0
var time_bonus: int = 0
var ring_bonus: int = 0
var emeralds: int = 0
var big_ring_entered: bool = false
var switches: PackedByteArray = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
var signpost_passed: bool = false


func setup(l: LevelData, lamp: Dictionary = {}) -> void:
	level = l
	terrain = Terrain.new(l)
	player = Player.new(self)
	camera = CameraState.new()
	animator = Animator.new()
	if l.rom.size() == 0x80000:
		animator.use_rom(l.rom)
	elif l.sprite_rom.size() == 0x80000:
		# Lab Zone: o sprite vem da ROM, então os quadros também (os roteiros próprios não batem no mapeamento).
		animator.use_rom(l.sprite_rom)
	objects = ObjectManager.new(self)
	limit_left1 = l.limit_left
	limit_right1 = l.limit_right
	limit_top1 = l.limit_top
	limit_bottom1 = l.limit_bottom
	limit_left2 = l.limit_left
	limit_right2 = l.limit_right
	limit_top2 = l.limit_top
	limit_bottom2 = l.limit_bottom
	water_level = l.water_level
	var sx := l.start_x
	var sy := l.start_y
	if not lamp.is_empty():
		_restore_lamppost(lamp)
		sx = int(lamp["x"])
		sy = int(lamp["y"])
	player.init_at(sx, sy)
	camera.x = clampi(sx - 160, max(l.limit_left, 0), limit_right2)
	camera.y = clampi(sy - 96, l.limit_top, limit_bottom2)
	if lamp.is_empty():
		bg.init(self)
	else:
		bg.init_zone_only(self)
	objects.initial_load()


## 0x16FD2: salva o estado no poste.
func save_lamppost(num: int, px: int, py: int) -> void:
	lamp_num = num
	lamp_save = {"num": num, "x": px, "y": py, "rings": rings,
			"time": [time_min, time_sec, time_frames], "dle": dle_routine, "bottom": limit_bottom2,
			"bg": [bg.bg_x, bg.bg_y, bg.bg2_x, bg.bg2_y, bg.bg3_x], "water": water_level}


## 0x1704C: restaura no reinício da fase (anéis voltam a 0; tempo = salvo com segundos-1 e quadro 59).
func _restore_lamppost(s: Dictionary) -> void:
	lamp_num = int(s["num"])
	lamp_save = s
	rings = 0
	var t: Array = s["time"]
	time_min = int(t[0])
	time_sec = (int(t[1]) - 1) & 0xFF
	time_frames = 0x3B
	dle_routine = int(s["dle"])
	limit_bottom1 = int(s["bottom"])
	limit_bottom2 = int(s["bottom"])
	var b: Array = s["bg"]
	bg.bg_x = (int(b[0]) & 0xFFFF0000) | (bg.bg_x & 0xFFFF)
	bg.bg_y = (int(b[1]) & 0xFFFF0000) | (bg.bg_y & 0xFFFF)
	bg.bg2_x = (int(b[2]) & 0xFFFF0000) | (bg.bg2_x & 0xFFFF)
	bg.bg2_y = int(b[3])
	bg.bg3_x = (int(b[4]) & 0xFFFF0000) | (bg.bg3_x & 0xFFFF)
	if level.zone == 1:
		water_level = int(s["water"])
	if lamp_num & 0x80:
		limit_left2 = Fx.u16(int(s["x"]) - 0xA0)


## Aplica um estado inicial medido (para replays de paridade) sobre o estado padrão.
func apply_snapshot(s: Dictionary) -> void:
	var p := player
	p.x = int(s.get("x", p.x))
	p.xs = int(s.get("xs", 0))
	p.y = int(s.get("y", p.y))
	p.ys = int(s.get("ys", 0))
	p.xv = int(s.get("xv", 0))
	p.yv = int(s.get("yv", 0))
	p.gs = int(s.get("gs", 0))
	p.angle = int(s.get("ang", 0))
	p.status = int(s.get("st", 0))
	p.anim = int(s.get("anim", p.anim))
	p.next_anim = int(s.get("nan", p.anim))
	p.frame = int(s.get("frm", p.frame))
	p.ani_frame = int(s.get("anf", p.ani_frame))
	p.time_frame = Fx.s8(int(s.get("ant", p.time_frame)) & 0xFF)
	if s.has("rnd"):
		p.render = int(s["rnd"])
	p.yr = int(s.get("yr", p.yr))
	p.xr = int(s.get("xr", p.xr))
	camera.x = int(s.get("camx", camera.x))
	camera.xs = int(s.get("camxs", 0))
	camera.y = int(s.get("camy", camera.y))
	camera.ys = int(s.get("camys", 0))
	look_shift = int(s.get("look", 0x60))
	rings = int(s.get("rings", 0))
	lives = int(s.get("lives", 3))
	score = int(s.get("score", 0))
	var t := int(s.get("time", 0))
	time_min = (t >> 16) & 0xFF
	time_sec = (t >> 8) & 0xFF
	time_frames = t & 0xFF
	rng = int(s.get("rng", 0))
	if s.has("lim"):
		var lim: Array = s["lim"]
		limit_left2 = int(lim[0])
		limit_right2 = int(lim[1])
		limit_top2 = int(lim[2])
		limit_bottom2 = int(lim[3])
	if s.has("lim1"):
		var l1: Array = s["lim1"]
		limit_left1 = int(l1[0])
		limit_right1 = int(l1[1])
		limit_top1 = int(l1[2])
		limit_bottom1 = int(l1[3])
	framecount = int(s.get("fc", framecount))
	vbla_count = int(s.get("vb", vbla_count))
	osc.load_hex(str(s.get("osc", "")), str(s.get("sync", "")))
	objects.initial_load()
	objects.prestart(PRESTART_PASSES)


func tick(buttons: int) -> void:
	events.clear()
	var hold := buttons & 0xFF
	if lock_ctrl:
		# controles travados (fim de ato): o jogo força "direita" e não há novas pressões
		pad_hold = forced_hold
		pad_press = 0
	else:
		pad_press = hold & ~pad_hold
		pad_hold = hold
	frame += 1
	vbla_count = (vbla_count + 1) & 0xFFFFFFFF
	framecount = (framecount + 1) & 0xFFFF
	_update_timer()
	objects.execute()
	# com o jogador morto, câmera e eventos de limites não rodam (laço principal da referência)
	if player.routine < Player.RT_DEATH:
		camera.update(self)
		_dynamic_level_events()
		bg.deform(self)
	objects.after_camera()
	if player.routine < Player.RT_DEATH:
		osc.update_oscillators()
	osc.update_sync()
	if reset_timer > 0:
		reset_timer -= 1
		if reset_timer == 0:
			restart_requested = true


## Quadro de lag (alinhamento com a referência): só o contador de VBlank avança.
func vblank_only() -> void:
	vbla_count = (vbla_count + 1) & 0xFFFFFFFF


func _update_timer() -> void:
	if not time_running:
		return
	time_frames += 1
	if time_frames < 60:
		return
	time_frames = 0
	time_sec += 1
	if time_sec >= 60:
		time_sec = 0
		time_min += 1
		if time_min > 9:
			time_min = 9
			time_sec = 59
			time_over = true
			player.kill()
	hud_dirty = true


# --- limites dinâmicos ---------------------------------------------------------------

func _dynamic_level_events() -> void:
	DynamicEvents.run(self)
	var step := 2
	var diff := limit_bottom1 - limit_bottom2
	if diff == 0:
		return
	if diff < 0:
		step = -2
		if not (Fx.u16(camera.y) <= Fx.u16(limit_bottom1)):
			limit_bottom2 = camera.y & 0xFFFE
		limit_bottom2 = Fx.s16(limit_bottom2 + step)
		bg_scroll_vert = true
		return
	if Fx.u16(camera.y + 8) >= Fx.u16(limit_bottom2) and (player.status & Player.ST_AIR):
		step *= 4
	limit_bottom2 = Fx.s16(limit_bottom2 + step)
	bg_scroll_vert = true


# --- interface usada por entidades ----------------------------------------------------------

func emit_sfx(n: String) -> void:
	events.append({"type": "sfx", "name": n})
	sfx.emit(n)


func emit_music(n: String) -> void:
	events.append({"type": "music", "name": n})
	music.emit(n)


func add_rings(n: int) -> void:
	rings = min(rings + n, 999)
	hud_dirty = true
	if rings >= 100 and (extra_life_flags & 1) == 0:
		extra_life_flags |= 1
		_extra_life()
	elif rings >= 200 and (extra_life_flags & 2) == 0:
		extra_life_flags |= 2
		_extra_life()
	else:
		emit_sfx("ring")


## Anéis de monitor (+10): mesma regra de vida extra em 100/200, som de anel caso contrário.
func add_rings_bonus(n: int) -> void:
	rings = min(rings + n, 999)
	hud_dirty = true
	if rings >= 100 and (extra_life_flags & 1) == 0:
		extra_life_flags |= 1
		_extra_life()
		return
	if rings >= 200 and (extra_life_flags & 2) == 0:
		extra_life_flags |= 2
		_extra_life()
		return
	emit_sfx("ring")


func _extra_life() -> void:
	lives = min(lives + 1, 99)
	emit_music("extralife")


func add_score(points: int) -> void:
	var old := score
	score += points
	if score > 999999:
		score = 999999
	hud_dirty = true
	if old / 5000 != score / 5000:
		pass  # vida extra por pontuação: implementar quando medido (ver docs/qa)


func random() -> int:
	## Gerador pseudoaleatório (especificação em docs/gameplay/regras.md). Retorna 32 bits.
	var d1 := rng
	if d1 == 0:
		d1 = 0x2A6D365A
	var d0 := d1
	d1 = (d1 << 2) & 0xFFFFFFFF
	d1 = (d1 + d0) & 0xFFFFFFFF
	d1 = (d1 << 3) & 0xFFFFFFFF
	d1 = (d1 + d0) & 0xFFFFFFFF
	var lo := d1 & 0xFFFF
	var hi := (d1 >> 16) & 0xFFFF
	var w := (lo + hi) & 0xFFFF
	d0 = (d0 & 0xFFFF0000) | w
	rng = (w << 16) | lo
	return d0


func react_to_items(p: Player) -> void:
	objects.react_to_items(p)


func scatter_rings(p: Player) -> void:
	objects.spawn_ring_loss(p)


func player_fell_out(p: Player) -> void:
	if level.zone == 5 and level.act == 1 and p.x >= 0x2000:
		last_lamp = 0
		restart_requested = true
		events.append({"type": "goto_level", "zone": 1, "act": 3})
		return
	p.kill()


func player_death_finished(p: Player) -> void:
	time_running = false
	lives -= 1
	hud_dirty = true
	if lives <= 0 or time_over:
		game_over = true
		emit_music("gameover")
	else:
		reset_timer = 60


## Visibilidade como BuildSprites: horizontal pela largura ativa; vertical por ±0x20 ou, com render bit 4
## ("altura própria"), pela altura do objeto (obHeight). height < 0 = sem bit 4.
func on_screen(px: int, py: int, wid: int, height: int = -1) -> bool:
	var dx := Fx.s16(px - camera.x)
	if dx + wid < 0 or dx - wid >= 320:
		return false
	var dy := Fx.s16(py - camera.y)
	if height >= 0:
		return dy + height >= 0 and dy - height < 224
	return dy + 32 >= 0 and dy - 32 < 224


## Estado comparável com a referência (mesmos nomes de campo dos traces).
func snapshot() -> Dictionary:
	var p := player
	return {
		"f": frame, "x": p.x, "xs": p.xs, "y": p.y, "ys": p.ys, "xv": p.xv, "yv": p.yv, "gs": p.gs,
		"yr": p.yr, "xr": p.xr, "anim": p.anim, "frm": p.frame, "anf": p.ani_frame & 0xFF,
		"ant": p.time_frame & 0xFF, "nan": p.next_anim, "rnd": p.render & 0xFF, "st": p.status, "rt": p.routine,
		"ang": p.angle, "lock": p.move_lock, "stick": p.stick, "jmp": p.jumping, "inv": p.flash_time,
		"camx": camera.x, "camxs": camera.xs, "camy": camera.y, "camys": camera.ys,
		"rings": rings, "lives": lives, "score": score,
		"time": (time_min << 16) | (time_sec << 8) | time_frames,
		"look": look_shift, "lim": [limit_left2, limit_right2, limit_top2, limit_bottom2], "rng": rng,
		"objs": objects.slot_dump(), "ospr": objects.sprite_dump(), "dle": dle_routine,
		"bgx": bg.bg_x, "bgy": bg.bg_y, "bg2x": bg.bg2_x, "bg2y": bg.bg2_y, "bgv": bg.vscroll_bg,
		"hsb": bg.hscroll_rle(),
	}
