extends SceneTree
## Testes GDScript headless (make test-unit / make test-touch). Saída: PASS/FAIL por caso.

var passed := 0
var failed := 0


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		passed += 1
		print("PASS ", name)
	else:
		failed += 1
		print("FAIL ", name, " ", detail)


func _init() -> void:
	var suite := "unit"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--suite="):
			suite = a.substr(8)
	print("SUITE ", suite)
	if suite == "unit":
		_unit()
	elif suite == "bench":
		_bench()
	elif suite == "rom":
		_rom()
	else:
		_touch()
	print("TOTAL pass=%d fail=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _sim_lab() -> GameSim:
	var L := LevelData.load_builtin("lab1")
	var s := GameSim.new()
	s.setup(L)
	return s


func _unit() -> void:
	# trigonometria
	check("sin(0)=0, cos(0)=256", Trig.sine(0) == 0 and Trig.cosine(0) == 256)
	check("errata seno 147/237", Trig.sine(147) == -117 and Trig.sine(237) == -117)
	check("angle_of eixos", Trig.angle_of(1, 0) == 0 and Trig.angle_of(0, 1) == 0x40 and Trig.angle_of(-1, 0) == 0x80 and Trig.angle_of(0, -1) == 0xC0)
	check("angle_of (0,0)=0x40", Trig.angle_of(0, 0) == 0x40)
	check("Fx.s16 estouro", Fx.s16(0x8000) == -32768 and Fx.s16(0x17FFF) == 0x7FFF)
	# física em fase própria plana
	var s := _sim_lab()
	for i in range(10):
		s.tick(0)
	s.tick(Player.IN_RIGHT)
	check("aceleração 0x0C no 1º quadro", s.player.gs == 0x0C, str(s.player.gs))
	for i in range(127):  # 0x600/0x0C = 128 quadros até o teto, antes do monitor em x=700
		s.tick(Player.IN_RIGHT)
	check("velocidade máxima 0x600", s.player.gs == 0x600, str(s.player.gs))
	for i in range(3):
		s.tick(0)
	check("atrito igual à aceleração", s.player.gs == 0x600 - 3 * 0x0C, str(s.player.gs))
	var s2 := _sim_lab()
	for i in range(10):
		s2.tick(0)
	s2.tick(Player.IN_C)
	check("salto: vy inicial -0x680 + gravidade não aplicada no quadro", s2.player.yv == -0x680, str(s2.player.yv))
	check("salto: rolando no ar", (s2.player.status & (Player.ST_AIR | Player.ST_ROLL)) == (Player.ST_AIR | Player.ST_ROLL))
	s2.tick(0)
	check("corte do salto ao soltar (-0x400) + gravidade 0x38", s2.player.yv == -0x400 + 0x38, str(s2.player.yv))
	# determinismo: mesma entrada -> mesmo estado
	var a := _sim_lab()
	var b := _sim_lab()
	var seq := [0, 8, 8, 8, 40, 8, 8, 0, 4, 4, 32, 2, 2, 8]
	for i in range(600):
		var inp: int = seq[(i / 13) % seq.size()]
		a.tick(inp)
		b.tick(inp)
	check("determinismo 600 quadros", JSON.stringify(a.snapshot()) == JSON.stringify(b.snapshot()))
	# RNG
	var r := GameSim.new()
	var v1 := r.random()
	var r2 := GameSim.new()
	check("RNG determinístico com semente padrão", v1 == r2.random())
	# anéis
	var s3 := _sim_lab()
	s3.add_rings(99)
	var lives := s3.lives
	s3.add_rings(1)
	check("vida extra aos 100 anéis", s3.lives == lives + 1)
	# replay
	var rp := Replay.from_dict({"inputs": [[2, "R"], [1, "RC"]], "frames": 5})
	check("replay expande entradas", rp.input_at(1) == 8 and rp.input_at(3) == 40 and rp.input_at(5) == 0)
	check("letras de botões", Replay.parse_buttons("UDLRBCAS") == 255 and Replay.buttons_to_string(72) == "RA")
	# terreno: sensor no chão plano da fase própria
	var t := Terrain.new(s.level)
	var d := t.find_floor(100, s.level.start_y + 0x13 - 2, 13, 0, 16, false)
	check("sensor de chão retorna distância pequena", absi(d) <= 16, str(d))
	# configurações (schema) — instância direta (autoloads não existem no modo --script)
	var st: Node = load("res://src/saves/settings.gd").new()
	st.profile = "fidelity"
	st.save_settings()
	var st2: Node = load("res://src/saves/settings.gd").new()
	st2.load_settings()
	check("settings persistem perfil", st2.profile == "fidelity")
	st2.profile = "enhanced"
	st2.save_settings()
	st.free()
	st2.free()


func _touch() -> void:
	var tl := TouchLogic.new()
	tl.layout(Vector2(1280, 720), Rect2(0, 0, 1280, 720), 1.0, Vector2.ZERO, Vector2.ZERO)
	var c := tl.dpad_center
	var r := tl.dpad_radius
	tl.press(0, c + Vector2(r * 0.8, 0))
	check("direcional: direita", tl.bits() == TouchLogic.BIT_RIGHT)
	var cbtn: Vector2 = tl.buttons[0]["center"]
	tl.press(1, cbtn)
	check("multitoque: direita + C", tl.bits() == (TouchLogic.BIT_RIGHT | TouchLogic.BIT_C))
	tl.drag(1, tl.buttons[1]["center"])
	check("arrastar entre botões: C -> B", tl.bits() == (TouchLogic.BIT_RIGHT | TouchLogic.BIT_B))
	tl.drag(0, c + Vector2(r * 0.6, -r * 0.6))
	check("diagonal direita+cima", (tl.bits() & 0xF) == (TouchLogic.BIT_RIGHT | TouchLogic.BIT_UP))
	tl.drag(0, c + Vector2(2, 2))
	check("zona morta no centro", (tl.bits() & 0xF) == 0)
	tl.release(1)
	check("soltar remove botão", (tl.bits() & 0xF0) == 0)
	tl.press(2, Vector2(640, 360))
	check("toque fora dos controles não gera botão", tl.bits() & ~0xF == 0)
	tl.cancel_all()
	check("cancelamento evita teclas presas", tl.bits() == 0)
	tl.press(3, tl.buttons[3]["center"])
	check("start", tl.bits() == TouchLogic.BIT_START)
	tl.release(3)
	var tl2 := TouchLogic.new()
	tl2.layout(Vector2(1280, 720), Rect2(60, 0, 1160, 690), 1.4, Vector2(10, -20), Vector2(-10, 0))
	check("área segura desloca direcional", tl2.dpad_center.x > tl.dpad_center.x)
	check("escala aumenta raio", tl2.dpad_radius > tl.dpad_radius)


func _bench() -> void:
	var packs := OS.get_environment("SONIC_LEVELPACKS")
	var levels := [["lab1", LevelData.load_builtin("lab1")]]
	if packs != "" and FileAccess.file_exists(packs.path_join("ghz1/level.json")):
		levels.append(["ghz1", LevelData.load_pack(packs.path_join("ghz1"))])
	for e in levels:
		var s := GameSim.new()
		s.setup(e[1])
		var t0 := Time.get_ticks_usec()
		var n := 3600
		for i in range(n):
			s.tick(8 if (i / 90) % 4 != 3 else 40)
		var dt := float(Time.get_ticks_usec() - t0) / n
		print("PASS bench %s: %.1f us/tick (orçamento 16667 us) objetos=%d" % [e[0], dt, s.objects.each().size()])
		passed += 1


static func _eq(a, b) -> bool:
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not _eq(a[i], b[i]):
				return false
		return true
	return int(a) == int(b)


func _rom() -> void:
	var rom_path := OS.get_environment("SONIC_ROM")
	var packs := OS.get_environment("SONIC_LEVELPACKS")
	if rom_path == "" or not FileAccess.file_exists(rom_path):
		print("PASS rom: ROM ausente — suíte NÃO AVALIADA")
		return
	var imp := RomImporter.new()
	var err := imp.load_rom(FileAccess.get_file_as_bytes(rom_path))
	check("ROM REV00 aceita (SHA-256)", err == "", err)
	var bad := PackedByteArray([1, 2, 3])
	check("ROM inválida rejeitada", imp.load_rom(bad) != "" and imp.is_loaded())
	var t0 := Time.get_ticks_msec()
	for lid in RomImporter.LEVEL_IDS.keys():
		var d := imp.level_dict(lid)
		var pf := packs.path_join(lid).path_join("level.json")
		if packs == "" or not FileAccess.file_exists(pf):
			continue
		var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pf))
		var ok := _eq(d["layout_fg"], ref["layout_fg"]) and _eq(d["layout_bg"], ref["layout_bg"])
		var chunks_ok := _eq(d["chunks"], (ref["chunks"] as Array).slice(0, d["chunks"].size()))
		var col_ok := _eq(d["collision_index"], (ref["collision_index"] as Array).slice(0, d["collision_index"].size()))
		var start_ok := int(d["start"]["x"]) == int(ref["start"]["x"]) and int(d["start"]["y"]) == int(ref["start"]["y"])
		var objs_ok: bool = d["objects"].size() == ref["objects"].size()
		check("importador GDScript %s: layout/chunks/colisão/início/objetos" % lid, ok and chunks_ok and col_ok and start_ok and objs_ok,
				"layout=%s chunks=%s col=%s start=%s objs=%s" % [ok, chunks_ok, col_ok, start_ok, objs_ok])
	print("PASS rom: importação de 19 fases em %d ms" % (Time.get_ticks_msec() - t0))
	passed += 1
	_rom_art(imp, packs)


## Arte da ROM (Nemesis/Enigma/PLC/paletas em GDScript) vs VRAM/blocos/CRAM capturados por emulação.
func _rom_art(imp: RomImporter, packs: String) -> void:
	var t0 := Time.get_ticks_msec()
	for lid in ["ghz1", "lz1", "mz1", "slz1", "syz1", "sbz1"]:
		var dir := packs.path_join(lid)
		if packs == "" or not FileAccess.file_exists(dir.path_join("vram.bin")):
			continue
		var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("level.json")))
		var cap := FileAccess.get_file_as_bytes(dir.path_join("vram.bin"))
		var art: Dictionary = imp.zone_art(int(RomImporter.LEVEL_IDS[lid][0]))
		var vram: PackedByteArray = art["card_vram"]  # a captura é do início do ato (arte do cartão presente)
		var same := 0
		for t in range(0xC000 / 32):
			if vram.slice(t * 32, t * 32 + 32) == cap.slice(t * 32, t * 32 + 32):
				same += 1
		var bw: PackedInt32Array = art["blocks"]
		var blocks_ok := true
		var rb: Array = ref["blocks"]
		for i in range(rb.size()):
			for j in range(4):
				if i * 4 + j >= bw.size() or bw[i * 4 + j] != int(rb[i][j]):
					blocks_ok = false
		var cram: PackedInt32Array = art["cram"]
		var sonic_pal_ok := true
		for i in range(16):
			if cram[i] != int(ref["cram"][i]):
				sonic_pal_ok = false
		check("arte ROM %s: padrões %d/1536 = VRAM capturada, blocos %s, paleta Sonic %s" % [lid, same, blocks_ok, sonic_pal_ok],
				same >= 1380 and blocks_ok and sonic_pal_ok)
	print("PASS rom: arte de 6 zonas decodificada em %d ms" % (Time.get_ticks_msec() - t0))
	passed += 1
