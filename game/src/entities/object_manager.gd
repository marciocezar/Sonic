class_name ObjectManager
extends RefCounted
## Objetos em slots fixos: slot 0 = jogador; 1..0x1F reservados (efeitos/HUD); 0x20..0x7F objetos
## de fase. A ordem dos slots define a ordem de execução e de teste de toque; a busca de slot
## livre começa em 0x20 (objetos de fase) ou após o slot atual (filhos), como medido na referência.
## Especificação: docs/gameplay/objetos.md.

## Tamanhos de toque (meia-largura, meia-altura) por índice 1..0x24.
## Parâmetro funcional medido (evidência EV-TAB-0004: tabela em ROM 0x1AE40); não é arte nem layout.
const TOUCH_SIZES := [
	[0x14, 0x14], [0x0C, 0x14], [0x14, 0x0C], [0x04, 0x10], [0x0C, 0x12], [0x10, 0x10], [0x06, 0x06],
	[0x18, 0x0C], [0x0C, 0x10], [0x10, 0x0C], [0x08, 0x08], [0x14, 0x10], [0x14, 0x08], [0x0E, 0x0E],
	[0x18, 0x18], [0x28, 0x10], [0x10, 0x18], [0x08, 0x10], [0x20, 0x70], [0x40, 0x20], [0x80, 0x20],
	[0x20, 0x20], [0x08, 0x08], [0x04, 0x04], [0x20, 0x08], [0x0C, 0x0C], [0x08, 0x04], [0x18, 0x04],
	[0x28, 0x04], [0x04, 0x08], [0x04, 0x18], [0x04, 0x28], [0x04, 0x20], [0x18, 0x18], [0x0C, 0x18],
	[0x48, 0x08],
]

const SLOTS := 0x80
const FIRST_LEVEL_SLOT := 0x20

var sim
var layout: Array = []
var slots: Array = []
var respawn: PackedByteArray = PackedByteArray()
var cursor_right: int = 0
var cursor_left: int = 0
var opl_screen: int = -1
var factory: ObjectFactory
var current_slot: int = 0
## Tempo de vida global dos anéis perdidos e quadro sincronizado dos anéis vêm de Oscillators (sync).
var ring_loss_timer: int:
	get:
		return sim.osc.lost_ring_time()
	set(v):
		sim.osc.set_lost_ring_time(v)
var sync_ring_frame: int:
	get:
		return sim.osc.ring_frame()


func _init(game) -> void:
	sim = game
	factory = ObjectFactory.new()
	respawn.resize(0x200)
	slots.resize(SLOTS)


func initial_load() -> void:
	slots.fill(null)
	layout.clear()
	var idx := 0
	for o in sim.level.objects:
		# formato da lista: x, y (bits 0-11 = y, bit 14 = espelho X, bit 15 = espelho Y),
		# id (bit 7 = lembrar estado), subtipo — validado contra a referência (EV-OBJ-0001)
		var yraw := int(o.get("yraw", o["y"]))
		var raw_id := int(o["id"])
		var e := {"x": int(o["x"]), "y": yraw & 0xFFF, "render": ((yraw >> 14) & 1) | (((yraw >> 15) & 1) << 1),
				"id": raw_id & 0x7F, "sub": int(o["sub"]), "rid": -1}
		if raw_id & 0x80:
			e["rid"] = idx
			idx += 1
		layout.append(e)
	respawn.fill(0)
	# cursores iniciais (ROM 0xD92A): d6 = max(câmera - 0x80, 0) & ~0x7F;
	# direito = 1º x >= d6; esquerdo = 1º x >= d6 - 0x80 (se d6 >= 0x80)
	var d6 := Fx.u16(sim.camera.x) - 0x80
	if d6 < 0:
		d6 = 0
	d6 &= 0xFF80
	cursor_right = 0
	while cursor_right < layout.size() and int(layout[cursor_right]["x"]) < d6:
		cursor_right += 1
	cursor_left = 0
	if d6 - 0x80 >= 0:
		while cursor_left < layout.size() and int(layout[cursor_left]["x"]) < d6 - 0x80:
			cursor_left += 1
	opl_screen = -1
	_load_by_camera()


func free_slot(from: int = FIRST_LEVEL_SLOT) -> int:
	for i in range(from, SLOTS):
		if slots[i] == null:
			return i
	return -1


## Coloca o objeto no primeiro slot livre a partir de `from` (busca da referência). A inicialização
## acontece quando o laço de slots alcançar o objeto (neste quadro se o slot for maior que o atual).
func place(o: GameObject, from: int = FIRST_LEVEL_SLOT, skip_init: bool = false) -> GameObject:
	var s := free_slot(from)
	if s < 0:
		return null
	o.sim = sim
	o.slot = s
	o.inited = skip_init
	slots[s] = o
	return o


## Filho criado por um objeto: procura slot livre após o slot atual.
func add_child(o: GameObject) -> GameObject:
	return place(o, maxi(current_slot + 1, FIRST_LEVEL_SLOT))


## Cria o objeto da lista. Retorna false só quando não há slot livre (a carga para nesse ponto).
func _spawn(e: Dictionary) -> bool:
	var rid: int = e["rid"]
	if rid >= 0:
		if respawn[rid] & 0x80:
			return true
	var s := free_slot()
	if s < 0:
		return false
	var o: GameObject = factory.create(int(e["id"]))
	if o == null:
		return true
	if rid >= 0:
		respawn[rid] |= 0x80
	o.sim = sim
	o.kind = e["id"]
	o.sub = e["sub"]
	o.x = e["x"]
	o.layout_x = e["x"]
	o.y = e["y"]
	o.status = int(e["render"])
	o.render = int(e["render"])
	o.respawn_index = rid
	o.remember = rid >= 0
	o.slot = s
	slots[s] = o
	return true


func release(o: GameObject) -> void:
	if o.respawn_index >= 0:
		respawn[o.respawn_index] &= 0x7F


func remember_gone(o: GameObject) -> void:
	if o.respawn_index >= 0:
		respawn[o.respawn_index] |= 0x80


## Passagens de objetos executadas pela inicialização da fase antes do 1º quadro do laço principal
## (sem jogador, câmera ou tempo). Quantidade medida contra o estado F0 da referência.
func prestart(passes: int) -> void:
	for _p in range(passes):
		_run_slots(false)


func execute() -> void:
	_run_slots(true)


func _run_slots(with_player: bool) -> void:
	current_slot = 0
	if with_player:
		sim.player.tick()
	var dead: bool = sim.player.routine >= Player.RT_DEATH
	var last := 0x20 if dead else SLOTS
	for i in range(1, last):
		var o = slots[i]
		if o == null:
			continue
		current_slot = i
		if o.deleted:
			slots[i] = null
			continue
		o.step()
		if o.deleted and slots[i] == o:
			slots[i] = null
	for i in range(SLOTS):
		var o2 = slots[i]
		if o2 != null and o2.deleted:
			slots[i] = null


func after_camera() -> void:
	for o in slots:
		if o == null:
			continue
		if sim.on_screen(o.x, o.y, o.act_width, o.height if (o.render & 0x10) else -1):
			o.render |= 0x80
		else:
			o.render &= ~0x80
	var p: Player = sim.player
	if sim.on_screen(p.x, p.y, 0x18):
		p.render |= 0x80
	else:
		p.render &= ~0x80
	_load_by_camera()


## Carga/descarga pela câmera com a mesma regra de cursores da referência (ROM 0xD980..0xDA3A).
func _load_by_camera() -> void:
	# passo por quadro (ROM 0xD980): bloco = câmera & ~0x7F
	var d6 := Fx.s16(Fx.u16(sim.camera.x) & 0xFF80)
	if d6 == opl_screen:
		return
	if d6 >= opl_screen:
		opl_screen = d6
		var lim := d6 + 0x280
		while cursor_right < layout.size() and int(layout[cursor_right]["x"]) < lim:
			if not _spawn(layout[cursor_right]):
				break
			cursor_right += 1
		var t := d6 - 0x80
		if t >= 0:
			while cursor_left < layout.size() and int(layout[cursor_left]["x"]) < t:
				cursor_left += 1
	else:
		opl_screen = d6
		var t2 := d6 - 0x80
		if t2 >= 0:
			while cursor_left > 0 and int(layout[cursor_left - 1]["x"]) > t2:
				if not _spawn(layout[cursor_left - 1]):
					break
				cursor_left -= 1
		var t3 := t2 + 0x300
		while cursor_right > 0 and int(layout[cursor_right - 1]["x"]) >= t3:
			cursor_right -= 1


func slot_dump() -> Array:
	var out: Array = []
	for i in range(FIRST_LEVEL_SLOT, SLOTS):
		var o = slots[i]
		if o != null and not o.deleted:
			out.append([i, o.kind, o.x, o.y, o.routine, o.routine2, o.status, o.sub])
	return out


## Sprite de cada objeto no mesmo formato do trace ("ospr"): [slot, id, quadro, flags, arte, mapeamento].
func sprite_dump() -> Array:
	var out: Array = []
	for i in range(FIRST_LEVEL_SLOT, SLOTS):
		var o = slots[i]
		if o != null and not o.deleted:
			var e := ObjectArtTable.lookup(sim.level.zone, o.kind, o.sub)
			var mp: int = o.map_addr if o.map_addr >= 0 else (e[0] if e.size() > 0 else -1)
			var gf: int = o.gfx if o.gfx >= 0 else (e[1] if e.size() > 1 else -1)
			out.append([i, o.kind, o.frame & 0xFF, o.render & 3, gf, mp])
	return out


func each() -> Array:
	var out: Array = []
	for o in slots:
		if o != null and not o.deleted:
			out.append(o)
	return out


# --- colisão por toque ------------------------------------------------------------------

static func _overlap(obj_pos: int, half: int, p_pos: int, p_span: int) -> bool:
	var a := Fx.u16(obj_pos - half)
	var b := Fx.u16(p_pos)
	if a >= b:
		return a - b <= p_span
	return (a - b) + half * 2 >= 0


func react_to_items(p: Player) -> void:
	var px := p.x - 8
	var hy := p.yr - 3
	var py := p.y - hy
	if p.frame == 0x39:
		py += 0xC
		hy = 0xA
	var ph := hy * 2
	for i in range(FIRST_LEVEL_SLOT, SLOTS):
		var o = slots[i]
		if o == null or o.deleted or (o.render & 0x80) == 0 or o.col_type == 0:
			continue
		var si: int = o.col_type & 0x3F
		if si == 0 or si > TOUCH_SIZES.size():
			continue
		var sz: Array = TOUCH_SIZES[si - 1]
		if not _overlap(o.x, sz[0], px, 0x10):
			continue
		if not _overlap(o.y, sz[1], py, ph):
			continue
		_react(p, o)
		return


func _react(p: Player, o: GameObject) -> void:
	var cat: int = o.col_type & 0xC0
	if cat == 0x40:
		o.touch_item(p)
	elif cat == 0:
		_touch_enemy(p, o)
	elif cat == 0x80:
		_touch_hurt(p, o)
	else:
		o.col_prop += 1


func _touch_enemy(p: Player, o: GameObject) -> void:
	if sim.invincible or p.anim == Player.AN_ROLL:
		_enemy_destroyed(p, o)
	else:
		_touch_hurt(p, o)


func _enemy_destroyed(p: Player, o: GameObject) -> void:
	if o.vars.get("boss", false):
		o.on_destroyed(p)
		p.xv = Fx.s16(-p.xv)
		p.yv = Fx.s16(-p.yv)
		return
	remember_gone(o)
	var table := [10, 20, 50, 100]
	var n: int = sim.item_bonus
	var pts := 100
	var points_frame := 3
	if n < 6:
		pts = table[n >> 1]
		points_frame = n >> 1
	if n >= 0x1E:
		pts = 1000
		points_frame = 5
	sim.item_bonus = n + 2
	sim.add_score(pts)
	o.on_destroyed(p)
	var ex := factory.make_explosion(o.x, o.y, true)
	ex.vars["points_frame"] = points_frame
	o.deleted = true
	ex.slot = o.slot
	ex.sim = sim
	ex.status = o.status | 0x80
	slots[o.slot] = ex
	if p.yv < 0:
		p.yv = Fx.s16(p.yv + 0x100)
	elif p.y >= o.y:
		p.yv = Fx.s16(p.yv - 0x100)
	else:
		p.yv = Fx.s16(-p.yv)


func _touch_hurt(p: Player, o: GameObject) -> void:
	if sim.invincible:
		return
	if p.flash_time != 0:
		return
	if p.routine >= Player.RT_HURT:
		return
	p.hurt(o.x, o.vars.get("spikes", false))


## Dano com anéis: coloca o objeto "carregador" de anéis perdidos (busca de slot livre); os anéis são
## criados e o contador zerado quando o carregador executar (mesma temporização da referência).
func spawn_ring_loss(p: Player) -> void:
	var r := RingLossObj.new()
	r.loader = true
	r.x = p.x
	r.y = p.y
	place(r)


## Executado pelo carregador: até 32 anéis em dois círculos, pares espelhados; o 1º anel é o próprio carregador.
func ring_loss_spawn(loader: RingLossObj) -> void:
	var n: int = mini(sim.rings, 32)
	var ang := 0x288
	var vx := 0
	var vy := 0
	for i in range(n):
		var r: RingLossObj = loader if i == 0 else RingLossObj.new()
		if i > 0:
			r.x = loader.x
			r.y = loader.y
		if ang >= 0:
			var sc := Trig.sincos(ang & 0xFF)
			var shift := (ang >> 8) & 0xF
			# ROM 0x9D40: vx = seno << n, vy = cosseno << n
			vx = Fx.s16(sc.x << shift)
			vy = Fx.s16(sc.y << shift)
			var lo := (ang & 0xFF) + 0x10
			ang = (ang & 0xFF00) | (lo & 0xFF)
			if lo >= 0x100:
				ang -= 0x80
				if ang < 0:
					ang = 0x288
		r.xv = vx
		r.yv = vy
		vx = -vx
		ang = -ang
		if i > 0:
			r.init_ring()
			if place(r, FIRST_LEVEL_SLOT, true) == null:
				break
	sim.rings = 0
	sim.hud_dirty = true
	ring_loss_timer = 0xFF
	sim.emit_sfx("ringloss")


func spawn_boss_ghz() -> void:
	var o: GameObject = factory.create(0x3D)
	if o == null:
		return
	o.x = 0x2A60
	o.y = 0x280
	o.layout_x = o.x
	place(o)
