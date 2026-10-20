class_name RomHud
extends RefCounted
## Placar original (objeto 0x21, ROM 0x1C548): sprite com mapeamento 0x1C5B4 (arte 0x6CA) em (16,136) na tela,
## quadro 1 piscando com 0 anéis (bit 3 do contador de quadros), 3 com 9 minutos. Os dígitos são escritos numa
## cópia da VRAM como o jogo faz (Hud_Base 0x1C80E; pontos 0x1C8DA; tempo 0x1C9A8/0x1C9B2; anéis 0x1C8D0;
## vidas 0x1CA6E), com as mesmas regras de zeros à esquerda; a arte dos dígitos vem da ROM (0x1CADA, 0x1CDDA).

const MAP := 0x1C5B4
const GFX := 0x6CA
const ART_HUD := 0x1CADA
const ART_LIVES := 0x1CDDA
const BASE_SCORE := 0x1C86A  # 15 caracteres a partir de VRAM 0xDC40
const BASE_RINGS := 0x1C876  # 3 caracteres a partir de VRAM 0xDF40

var rom: PackedByteArray
var vram: PackedByteArray
var sprites: RomSprites
var _last: Array = []
var _last_rings: int = -1


func _init(r: PackedByteArray, level_vram: PackedByteArray, cram: PackedInt32Array) -> void:
	rom = r
	vram = level_vram.duplicate()
	sprites = RomSprites.new(rom, vram, cram)
	_base(BASE_SCORE, 0xDC40, 15)
	_base(BASE_RINGS, 0xDF40, 3)


func _char(dst: int, idx: int, nbytes: int, art: int) -> void:
	for i in range(nbytes):
		vram[dst + i] = rom[art + idx * 32 + i]


func _blank(dst: int, nbytes: int) -> void:
	for i in range(nbytes):
		vram[dst + i] = 0


func _base(table: int, dst: int, count: int) -> void:
	for k in range(count):
		var c: int = rom[table + k]
		if c >= 0x80:
			_blank(dst + k * 64, 64)
		else:
			_char(dst + k * 64, c, 64, ART_HUD)


## Dígitos com 2 tiles; skip_zeros = não escreve zeros à esquerda (mantém o que estava na VRAM).
func _digits(dst: int, value: int, n: int, skip_zeros: bool) -> void:
	var seen := false
	for i in range(n):
		var p := int(pow(10, n - 1 - i))
		var d := (value / p) % 10
		if d != 0:
			seen = true
		if seen or not skip_zeros:
			_char(dst + i * 64, d * 2, 64, ART_HUD)


func _lives(value: int) -> void:
	var dst := 0xFBA0
	var tens := (value / 10) % 10
	var ones := value % 10
	if tens == 0:
		_blank(dst, 32)
	else:
		_char(dst, tens, 32, ART_LIVES)
	# o comando VDP avança 0x40 por dígito (peça desenhada coluna a coluna: dígitos na linha de baixo)
	_char(dst + 64, ones, 32, ART_LIVES)


func update(sim) -> void:
	var state := [sim.score, sim.rings, sim.time_min, sim.time_sec, sim.lives]
	if state == _last:
		return
	if sim.rings < _last_rings or sim.rings == 0 and _last_rings != 0:
		_base(BASE_RINGS, 0xDF40, 3)
	_last_rings = sim.rings
	_digits(0xDC80, sim.score, 6, true)
	_digits(0xDE40, sim.time_min, 1, false)
	_digits(0xDEC0, sim.time_sec, 2, false)
	_digits(0xDF40, sim.rings, 3, true)
	_lives(sim.lives)
	_last = state
	sprites.clear_cache()


func draw(ci: CanvasItem, sim) -> void:
	update(sim)
	var fr := 0
	if sim.rings == 0:
		if (sim.framecount & 8) == 0:
			fr = 1
			if sim.time_min == 9:
				fr = 3
	sprites.draw(ci, Vector2.ZERO, Vector2(0x90 - 0x80, 0x108 - 0x80), MAP, fr, GFX, 0)
