extends Node
## Áudio próprio (autoload "AudioBus"): efeitos sintetizados em código (onda quadrada/ruído com
## envelopes), disparados por eventos da simulação. Não usa áudio da ROM. Música: laço próprio
## simples opcional. Na Web o contexto de áudio só inicia após gesto do usuário (política do navegador).

const RATE := 22050
var cache: Dictionary = {}
var players: Array = []
var music_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music_player = AudioStreamPlayer.new()
	add_child(music_player)


func play_sfx(name: String) -> void:
	var st: AudioStreamWAV = cache.get(name)
	if st == null:
		st = _make(name)
		if st == null:
			return
		cache[name] = st
	for p in players:
		if not p.playing:
			p.stream = st
			p.volume_db = linear_to_db(maxf(Settings.sfx_volume, 0.0001))
			p.play()
			return
	players[0].stream = st
	players[0].play()


func handle_events(events: Array) -> void:
	for e in events:
		if e.get("type") == "sfx":
			play_sfx(str(e["name"]))


## Especificações próprias de cada efeito: [(freq_inicio, freq_fim, duracao_s, forma, volume)]
func _spec(name: String) -> Array:
	match name:
		"jump":
			return [[320.0, 900.0, 0.16, "square", 0.35]]
		"ring":
			return [[1568.0, 1568.0, 0.06, "square", 0.3], [2093.0, 2093.0, 0.14, "square", 0.25]]
		"skid":
			return [[180.0, 120.0, 0.18, "noise", 0.3]]
		"roll":
			return [[260.0, 520.0, 0.12, "square", 0.25]]
		"hurt", "death":
			return [[700.0, 120.0, 0.35, "square", 0.35]]
		"spikes":
			return [[900.0, 200.0, 0.25, "noise", 0.35]]
		"explode":
			return [[200.0, 40.0, 0.35, "noise", 0.4]]
		"ringloss":
			return [[2000.0, 900.0, 0.5, "square", 0.25]]
		"spring":
			return [[200.0, 1200.0, 0.2, "square", 0.35]]
		"shield":
			return [[400.0, 800.0, 0.3, "square", 0.3]]
		"splash":
			return [[600.0, 100.0, 0.3, "noise", 0.3]]
		"checkpoint":
			return [[880.0, 1760.0, 0.25, "square", 0.3]]
		"signpost":
			return [[523.0, 1046.0, 0.4, "square", 0.3]]
		"bumper", "boss_hit":
			return [[300.0, 600.0, 0.15, "square", 0.35]]
		"select":
			return [[660.0, 660.0, 0.05, "square", 0.25]]
	return []


func _make(name: String) -> AudioStreamWAV:
	var parts := _spec(name)
	if parts.is_empty():
		return null
	var data := PackedByteArray()
	var seed := 12345
	for part in parts:
		var f0: float = part[0]
		var f1: float = part[1]
		var dur: float = part[2]
		var shape: String = part[3]
		var vol: float = part[4]
		var n := int(dur * RATE)
		var phase := 0.0
		for i in range(n):
			var t := float(i) / float(n)
			var f := lerpf(f0, f1, t)
			phase += f / RATE
			var s: float
			if shape == "noise":
				seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
				s = (float(seed % 2000) / 1000.0 - 1.0)
			else:
				s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			var env := (1.0 - t) * minf(1.0, float(i) / 40.0)
			var v := int(clampf(s * vol * env, -1.0, 1.0) * 32767.0)
			data.append(v & 0xFF)
			data.append((v >> 8) & 0xFF)
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = data
	return st
