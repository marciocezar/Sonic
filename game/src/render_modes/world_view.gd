class_name WorldView
extends Node2D
## Desenha o estado da simulação. Somente leitura: nunca altera a simulação.
## Perfis: "fidelity" (320x224, escala inteira) e "enhanced" (640x448, a mesma arte original
## em 2x nítido quando a fase tem VRAM; senão arte própria). O fundo deformado vai à GPU.

var sim: GameSim
var profile: String = "enhanced"
var art_scale: int = 2
var vram_art: VramArt
var rom_sprites: RomSprites
var rom_hud: RomHud
var title_card: RomTitleCard
var results: RomResults
var black_out: bool = false
var geo_art: GeometryArt
var tick_count: int = 0
var view_size: Vector2 = Vector2(320, 224)
var _bg: BgLayer
var _backdrop: BgLayer.BackdropDraw


func configure(s: GameSim, prof: String) -> void:
	var keep := sim == s and vram_art != null and vram_art.warm_done
	sim = s
	profile = prof
	art_scale = 2 if prof == "enhanced" else 1
	scale = Vector2(art_scale, art_scale)
	if keep:
		queue_redraw()
		return
	_drop_layers()
	vram_art = null
	rom_sprites = null
	rom_hud = null
	geo_art = GeometryArt.new(s.level, art_scale)
	if s.level.is_private and s.level.vram.size() >= 0x10000 and s.level.cram.size() >= 64:
		vram_art = VramArt.new(s.level)
		vram_art.queue_warm()
		if s.level.rom.size() == 0x80000:
			rom_sprites = RomSprites.new(s.level.rom, s.level.vram, s.level.cram, vram_art.atlases)
			rom_hud = RomHud.new(s.level.rom, s.level.vram, s.level.cram)
		_backdrop = BgLayer.BackdropDraw.new()
		_backdrop.fill = vram_art.backdrop_color()
		_backdrop.show_behind_parent = true
		_backdrop.z_index = -2
		_backdrop.visible = false
		add_child(_backdrop)
	elif s.level.sprite_rom.size() == 0x80000 and s.level.sprite_vram.size() >= 0x10000:
		rom_sprites = RomSprites.new(s.level.sprite_rom, s.level.sprite_vram, s.level.sprite_cram)
	queue_redraw()


func art_ready() -> bool:
	return vram_art == null or vram_art.warm_done


func _drop_layers() -> void:
	if _bg != null and is_instance_valid(_bg):
		_bg.visible = false
		_bg.queue_free()
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.visible = false
		_backdrop.queue_free()
	_bg = null
	_backdrop = null


func _attach_bg() -> void:
	if vram_art == null or vram_art.bg_atlas == null or vram_art.layout_tex == null:
		return
	if _bg != null and is_instance_valid(_bg):
		return
	_bg = BgLayer.new()
	_bg.view = self
	_bg.show_behind_parent = true
	_bg.z_index = -1
	_bg.visible = false
	_bg.setup(vram_art.bg_atlas, vram_art.layout_tex, vram_art.atlas_cols)
	add_child(_bg)


func _sync_layers() -> void:
	var on := vram_art != null and not black_out
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.visible = on
	if _bg != null and is_instance_valid(_bg):
		_bg.visible = on and vram_art.bg_ready


func _process(_d: float) -> void:
	if vram_art != null and not vram_art.warm_done:
		var before := vram_art.bg_ready
		vram_art.warm(4)
		if vram_art.bg_ready and not before:
			_attach_bg()
	elif vram_art != null and vram_art.bg_ready and _bg == null:
		_attach_bg()
	_sync_layers()
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	if black_out:
		draw_rect(Rect2(Vector2.ZERO, view_size), Color.BLACK)
		if title_card != null:
			title_card.draw(self)
		return
	tick_count = sim.frame
	var cx := float(sim.camera.x)
	var cy := float(sim.camera.y)
	_draw_background(cx, cy)
	SpritePainter.cam = Vector2(cx, cy)
	draw_set_transform(Vector2(-cx, -cy), 0.0, Vector2.ONE)
	_draw_plane(cx, cy, false)
	var objs := sim.objects.each()
	# como BuildSprites: prioridade menor fica na frente; no empate, o slot menor fica por cima
	objs.sort_custom(func(a, b): return a.priority > b.priority or (a.priority == b.priority and a.slot > b.slot))
	for o in objs:
		if sim.on_screen(o.x, o.y, 64) and not _draw_rom_object(o):
			SpritePainter.draw_object(self, o, tick_count)
	if profile == "enhanced" and sim.shield:
		draw_arc(Vector2(sim.player.x, sim.player.y), 20.0, 0, TAU, 32, Color(0.5, 0.8, 1, 0.7), 2.0)
	if rom_sprites != null:
		_draw_rom_player()
	else:
		SpritePainter.draw_player(self, sim.player, profile == "enhanced", tick_count)
	if sim.invincible:
		for i in range(4):
			var a := float(tick_count) * 0.25 + float(i) * PI / 2.0
			draw_circle(Vector2(sim.player.x, sim.player.y) + Vector2(cos(a), sin(a)) * 18.0, 2.0, Color(1, 1, 0.6))
	if vram_art != null:
		_draw_plane(cx, cy, true)
	if sim.water_level >= 0:
		var wy := float(sim.water_level)
		draw_rect(Rect2(cx - 8, wy, 340, 400), Color(0.1, 0.4, 0.9, 0.35))
		draw_line(Vector2(cx - 8, wy), Vector2(cx + 340, wy), Color(0.8, 0.95, 1, 0.8), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if rom_hud != null:
		rom_hud.draw(self, sim)
	if title_card != null:
		title_card.draw(self)
	if results != null:
		results.draw(self)


func _draw_background(cx: float, cy: float) -> void:
	if vram_art != null and _backdrop != null and _backdrop.visible:
		return
	if vram_art != null:
		draw_rect(Rect2(Vector2.ZERO, view_size), vram_art.backdrop_color())
		_draw_bg_lines()
		return
	var th: Dictionary = geo_art.theme
	var top: Color = th["sky_top"]
	var bot: Color = th["sky_bot"]
	var bands := 14 if profile == "enhanced" else 7
	for i in range(bands):
		var t := float(i) / float(bands - 1)
		draw_rect(Rect2(0, view_size.y * float(i) / bands, view_size.x, view_size.y / bands + 1), top.lerp(bot, t))
	# colinas em parallax (procedurais, próprias)
	var hill: Color = th["hill"]
	for layer in range(2):
		var par := 0.1 + 0.15 * layer
		var base_y := view_size.y * (0.62 + 0.12 * layer)
		var pts := PackedVector2Array()
		pts.append(Vector2(0, view_size.y))
		var step := 8.0
		var x := 0.0
		while x <= view_size.x + step:
			var wx := x + cx * par
			var h := sin(wx * 0.013 + layer) * 14.0 + sin(wx * 0.031) * 6.0
			pts.append(Vector2(x, base_y + h))
			x += step
		pts.append(Vector2(view_size.x, view_size.y))
		draw_colored_polygon(pts, hill.lightened(0.15 * (1 - layer)))
	if profile == "enhanced" or geo_art.level.theme == "lab":
		for k in range(6):
			var bx := fposmod(float(k) * 92.0 - cx * 0.08, view_size.x + 48.0) - 24.0
			var bw := 26.0 + float(k % 2) * 10.0
			var bh := 16.0 + float(k % 3) * 12.0
			draw_rect(Rect2(bx, 28.0, bw, bh), th["plat"].darkened(0.25))
			draw_rect(Rect2(bx + 4.0, 32.0, 6.0, 5.0), th["top"])
			draw_rect(Rect2(bx + 14.0, 32.0, 6.0, 5.0), th["top2"])
	if profile == "enhanced":
		for k in range(5):
			var cxp := fposmod(float(k) * 97.0 - cx * 0.05, view_size.x + 60.0) - 30.0
			var cyp := 20.0 + float(k % 3) * 18.0
			draw_circle(Vector2(cxp, cyp), 10.0, Color(1, 1, 1, 0.75))
			draw_circle(Vector2(cxp + 10, cyp + 2), 8.0, Color(1, 1, 1, 0.75))


func _draw_plane(cx: float, cy: float, high: bool) -> void:
	var c0 := int(cx) >> 8
	var r0 := int(cy) >> 8
	for row in range(r0, r0 + 2):
		for col in range(c0, c0 + 3):
			if col < 0 or col >= 0x40:
				continue
			var cid := sim.level.layout_fg(col, row & 7)
			if cid == 0 and vram_art != null:
				continue
			var pos := Vector2(col * 256, row * 256)
			if vram_art != null:
				var tex: Array = vram_art.chunk_textures(cid)
				draw_texture(tex[1] if high else tex[0], pos)
			elif not high:
				var tex2: Array = geo_art.chunk_textures_at(col, row & 7, cid)
				draw_texture_rect(tex2[0], Rect2(pos, Vector2(256, 256)), false)


## Sprite original (mapeamento da ROM) do objeto; false se o tipo ainda não tem mapeamento conhecido.
func _draw_rom_object(o: GameObject) -> bool:
	if rom_sprites == null:
		return false
	var e := ObjectArtTable.lookup(sim.level.zone, o.kind, o.sub)
	var mp: int = o.map_addr if o.map_addr >= 0 else (e[0] if e.size() > 0 else -1)
	var gf: int = o.gfx if o.gfx >= 0 else (e[1] if e.size() > 1 else 0)
	if mp < 0:
		# sem sprite conhecido: no visual original nunca desenhar marcadores próprios
		return o.art == "placeholder" or o.art == ""
	if mp == 0:
		return true  # objeto sem sprite no original (ex.: som da cachoeira)
	return rom_sprites.draw(self, SpritePainter.cam, Vector2(o.x, o.y), mp, o.frame, gf, o.render)


func _draw_rom_player() -> bool:
	var p := sim.player
	if rom_sprites == null:
		return false
	if not p.visible:
		return true
	return rom_sprites.draw(self, SpritePainter.cam, Vector2(p.x, p.y), RomSprites.SONIC_MAP, p.frame,
			RomSprites.SONIC_GFX, p.render & 3, true)


## Plano B com rolagem por linha (BgScroll): agrupa linhas consecutivas de mesmo deslocamento em faixas e desenha
## os recortes dos chunks 256x256 do layout de fundo (colunas com repetição a cada 64 chunks, 8 linhas).
func _draw_bg_lines() -> void:
	var bg: BgScroll = sim.bg
	var vy: int = bg.vscroll_bg
	var l0 := 0
	while l0 < 224:
		var v: int = bg.hscroll_bg[l0]
		var l1 := l0 + 1
		while l1 < 224 and bg.hscroll_bg[l1] == v:
			l1 += 1
		var ly := l0
		while ly < l1:
			var wy := (vy + ly) & 0x7FF
			var row := (wy >> 8) & 7
			var y_in := wy & 0xFF
			var h := mini(l1 - ly, 256 - y_in)
			var wx := -v
			var sx := 0
			while sx < 320:
				var px := (wx + sx) & 0x3FFF
				var col := (px >> 8) & 0x3F
				var x_in := px & 0xFF
				var w := mini(320 - sx, 256 - x_in)
				var cid := sim.level.layout_bg(col, row)
				if cid != 0:
					var tex: Array = vram_art.chunk_textures(cid)
					var src := Rect2(x_in, y_in, w, h)
					draw_texture_rect_region(tex[0], Rect2(sx, ly, w, h), src)
					draw_texture_rect_region(tex[1], Rect2(sx, ly, w, h), src)
				sx += w
			ly += h
		l0 = l1
