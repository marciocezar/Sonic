extends SceneTree
## Executa um replay na simulação, sem janela, e grava o estado por quadro (JSONL).
## Uso (somente via `make test-parity`):
##   godot --headless --path game --script res://tests/replay_runner.gd -- \
##     --levelpack=<dir> --replay=<json> --init=<trace.jsonl> --out=<jsonl>


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	var level: LevelData = null
	if args.has("levelpack"):
		level = LevelData.load_pack(args["levelpack"])
	elif args.has("level"):
		level = LevelData.load_builtin(args["level"])
	if level == null:
		printerr("ERRO: fase não carregada")
		quit(2)
		return
	if args.has("rom") and FileAccess.file_exists(args["rom"]):
		level.rom = FileAccess.get_file_as_bytes(args["rom"])
	var rp := Replay.load_file(args.get("replay", ""))
	if rp == null:
		printerr("ERRO: replay inválido")
		quit(2)
		return
	if args.has("prestart"):
		GameSim.PRESTART_PASSES = int(args["prestart"])
	var sim := GameSim.new()
	sim.setup(level)
	var lag := {}
	if args.has("init"):
		var f := FileAccess.open(args["init"], FileAccess.READ)
		if f != null:
			var row: Variant = JSON.parse_string(f.get_line())
			if row is Dictionary:
				sim.apply_snapshot(row)
			# quadros de lag medidos na referência: a simulação não modela carga de CPU, então
			# não avança nesses quadros (a entrada desse quadro não é lida pelo jogo de referência)
			while not f.eof_reached():
				var ln := f.get_line()
				if ln.contains("\"lag\":1"):
					var r2: Variant = JSON.parse_string(ln)
					if r2 is Dictionary:
						lag[int(r2["f"])] = true
	var out := FileAccess.open(args.get("out", "user://trace.jsonl"), FileAccess.WRITE)
	if out == null:
		printerr("ERRO: não foi possível gravar saída")
		quit(2)
		return
	var s0 := sim.snapshot()
	s0["f"] = 0
	s0["in"] = ""
	out.store_line(JSON.stringify(s0))
	for fr in range(1, rp.frames + 1):
		var b := rp.input_at(fr)
		if rp.pokes.has(fr):
			var pk: Dictionary = rp.pokes[fr]
			if pk.has("x"):
				sim.player.x = int(pk["x"])
				sim.player.xs = 0
			if pk.has("y"):
				sim.player.y = int(pk["y"])
				sim.player.ys = 0
			sim.player.xv = 0
			sim.player.yv = 0
			sim.player.gs = 0
		if not lag.has(fr):
			sim.tick(b)
		else:
			sim.vblank_only()
		var s := sim.snapshot()
		s["f"] = fr
		s["in"] = Replay.buttons_to_string(b)
		out.store_line(JSON.stringify(s))
	out.close()
	print("replay ok: %d quadros; objetos sem implementação: %s" % [rp.frames, str(ObjectFactory.missing)])
	quit(0)
