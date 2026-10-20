class_name Terrain
extends RefCounted
## Sensores de terreno baseados em mapas de altura 16x16 (comportamento especificado em
## docs/gameplay/fisica-e-colisao.md). Implementação original do projeto.
##
## Convenções:
##  - solid_bit: 13 (sólido por cima) ou 14 (sólido pelos lados/baixo).
##  - flip_eor: 0, 0x800 (busca para a esquerda) ou 0x1000 (busca para cima) — inverte o sentido
##    da altura lida para sensores que "olham" no sentido oposto.
##  - dir: +16 ou -16 (sentido da extensão para o tile vizinho).
##  - Os buffers de ângulo ang_a/ang_b imitam os dois bytes de ângulo do sensor duplo;
##    um ângulo ímpar significa "sem ângulo confiável" (usar o ângulo cardinal).

var level: LevelData
var ang_a: int = 0
var ang_b: int = 0
var _ang: int = 0  # buffer corrente do sensor em execução


func _init(l: LevelData) -> void:
	level = l


func _height_lookup(word: int, x: int, y: int, flip_eor: int) -> int:
	return 0


## Sensor vertical com extensão para o tile vizinho. Retorna a distância (com sinal).
func find_floor(x: int, y: int, solid_bit: int, flip_eor: int, dir: int, alt: bool) -> int:
	var word := level.block_word(x, y, alt)
	var blk := word & 0x7FF
	if blk == 0 or (word & (1 << solid_bit)) == 0:
		return find_floor2(x, y + dir, solid_bit, flip_eor, alt) + 16
	var idx: int = level.collision_index[blk]
	if idx == 0:
		return find_floor2(x, y + dir, solid_bit, flip_eor, alt) + 16
	_ang = level.angles[idx]
	var col := x
	if word & 0x800:
		col = ~col
		_ang = (-_ang) & 0xFF
	if word & 0x1000:
		_ang = (0x80 - _ang) & 0xFF
	var h: int = level.heights[idx * 16 + (col & 15)]
	if (word ^ flip_eor) & 0x1000:
		h = -h
	if h == 0:
		return find_floor2(x, y + dir, solid_bit, flip_eor, alt) + 16
	if h < 0:
		if h + (y & 15) >= 0:
			return find_floor2(x, y + dir, solid_bit, flip_eor, alt) + 16
		return find_floor2(x, y - dir, solid_bit, flip_eor, alt) - 16
	if h == 16:
		return find_floor2(x, y - dir, solid_bit, flip_eor, alt) - 16
	return 15 - (h + (y & 15))


## Sensor vertical de um único tile (sem extensão).
func find_floor2(x: int, y: int, solid_bit: int, flip_eor: int, alt: bool) -> int:
	var word := level.block_word(x, y, alt)
	var blk := word & 0x7FF
	if blk == 0 or (word & (1 << solid_bit)) == 0:
		return 15 - (y & 15)
	var idx: int = level.collision_index[blk]
	if idx == 0:
		return 15 - (y & 15)
	_ang = level.angles[idx]
	var col := x
	if word & 0x800:
		col = ~col
		_ang = (-_ang) & 0xFF
	if word & 0x1000:
		_ang = (0x80 - _ang) & 0xFF
	var h: int = level.heights[idx * 16 + (col & 15)]
	if (word ^ flip_eor) & 0x1000:
		h = -h
	if h == 0:
		return 15 - (y & 15)
	if h < 0:
		if h + (y & 15) >= 0:
			return 15 - (y & 15)
		return -1 - (y & 15)
	return 15 - (h + (y & 15))


## Sensor horizontal com extensão.
func find_wall(x: int, y: int, solid_bit: int, flip_eor: int, dir: int, alt: bool) -> int:
	var word := level.block_word(x, y, alt)
	var blk := word & 0x7FF
	if blk == 0 or (word & (1 << solid_bit)) == 0:
		return find_wall2(x + dir, y, solid_bit, flip_eor, alt) + 16
	var idx: int = level.collision_index[blk]
	if idx == 0:
		return find_wall2(x + dir, y, solid_bit, flip_eor, alt) + 16
	_ang = level.angles[idx]
	var row := y
	if word & 0x1000:
		row = ~row
		_ang = (0x80 - _ang) & 0xFF
	if word & 0x800:
		_ang = (-_ang) & 0xFF
	var w: int = level.widths[idx * 16 + (row & 15)]
	if (word ^ flip_eor) & 0x800:
		w = -w
	if w == 0:
		return find_wall2(x + dir, y, solid_bit, flip_eor, alt) + 16
	if w < 0:
		if w + (x & 15) >= 0:
			return find_wall2(x + dir, y, solid_bit, flip_eor, alt) + 16
		return find_wall2(x - dir, y, solid_bit, flip_eor, alt) - 16
	if w == 16:
		return find_wall2(x - dir, y, solid_bit, flip_eor, alt) - 16
	return 15 - (w + (x & 15))


func find_wall2(x: int, y: int, solid_bit: int, flip_eor: int, alt: bool) -> int:
	var word := level.block_word(x, y, alt)
	var blk := word & 0x7FF
	if blk == 0 or (word & (1 << solid_bit)) == 0:
		return 15 - (x & 15)
	var idx: int = level.collision_index[blk]
	if idx == 0:
		return 15 - (x & 15)
	_ang = level.angles[idx]
	var row := y
	if word & 0x1000:
		row = ~row
		_ang = (0x80 - _ang) & 0xFF
	if word & 0x800:
		_ang = (-_ang) & 0xFF
	var w: int = level.widths[idx * 16 + (row & 15)]
	if (word ^ flip_eor) & 0x800:
		w = -w
	if w == 0:
		return 15 - (x & 15)
	if w < 0:
		if w + (x & 15) >= 0:
			return 15 - (x & 15)
		return -1 - (x & 15)
	return 15 - (w + (x & 15))


# --- sensores compostos -----------------------------------------------------------

## Executa um sensor gravando o ângulo no buffer A ou B. kind: 0 piso, 1 parede.
func _sense(kind: int, buf: int, x: int, y: int, solid_bit: int, flip_eor: int, dir: int, alt: bool) -> int:
	_ang = ang_a if buf == 0 else ang_b
	var d: int
	if kind == 0:
		d = find_floor(x, y, solid_bit, flip_eor, dir, alt)
	else:
		d = find_wall(x, y, solid_bit, flip_eor, dir, alt)
	if buf == 0:
		ang_a = _ang
	else:
		ang_b = _ang
	return d


## Escolha entre dois sensores: menor distância vence; empate favorece o segundo (B).
## Retorna [dist_min, dist_outro, angulo]. Ângulo ímpar -> cardinal.
func pick(d_first: int, d_second: int, cardinal: int) -> Array:
	var a := ang_b
	var dmin := d_second
	var dother := d_first
	if d_second > d_first:
		a = ang_a
		dmin = d_first
		dother = d_second
	if a & 1:
		a = cardinal
	return [dmin, dother, a & 0xFF]


## Ângulo do buffer A ou cardinal se ímpar (sensor simples).
func single_angle(cardinal: int) -> int:
	return cardinal & 0xFF if ang_a & 1 else ang_a


## Dois sensores para baixo nas bordas (x ± xr, y + yr). Sólido-topo.
func hit_floor(x: int, y: int, xr: int, yr: int, alt: bool) -> Array:
	var d1 := _sense(0, 0, x + xr, y + yr, 13, 0, 16, alt)
	var d2 := _sense(0, 1, x - xr, y + yr, 13, 0, 16, alt)
	return pick(d1, d2, 0)


## Dois sensores para cima (teto). Sólido-lados.
func hit_ceiling(x: int, y: int, xr: int, yr: int, alt: bool) -> Array:
	var yy := (y - yr) ^ 0xF
	var d1 := _sense(0, 0, x + xr, yy, 14, 0x1000, -16, alt)
	var d2 := _sense(0, 1, x - xr, yy, 14, 0x1000, -16, alt)
	return pick(d1, d2, 0x80)


## Dois sensores para a direita (parede direita), usados quando o ângulo aponta para lá.
func hit_right_pair(x: int, y: int, xr: int, yr: int, alt: bool) -> Array:
	var d1 := _sense(1, 0, x + yr, y - xr, 14, 0, 16, alt)
	var d2 := _sense(1, 1, x + yr, y + xr, 14, 0, 16, alt)
	return pick(d1, d2, 0xC0)


func hit_left_pair(x: int, y: int, xr: int, yr: int, alt: bool) -> Array:
	var xx := (x - yr) ^ 0xF
	var d1 := _sense(1, 0, xx, y - xr, 14, 0x800, -16, alt)
	var d2 := _sense(1, 1, xx, y + xr, 14, 0x800, -16, alt)
	return pick(d1, d2, 0x40)


## Sensor simples de parede à esquerda a 10 px (ar). Retorna [dist, angulo].
func wall_left_10(x: int, y: int, alt: bool) -> Array:
	var d := _sense(1, 0, (x - 10) ^ 0xF, y, 14, 0x800, -16, alt)
	return [d, single_angle(0x40)]


func wall_right_10(x: int, y: int, alt: bool) -> Array:
	var d := _sense(1, 0, x + 10, y, 14, 0, 16, alt)
	return [d, single_angle(0xC0)]


func floor_10(x: int, y: int, alt: bool) -> Array:
	var d := _sense(0, 0, x, y + 10, 14, 0, 16, alt)
	return [d, single_angle(0)]


func ceiling_10(x: int, y: int, alt: bool) -> Array:
	var d := _sense(0, 0, x, (y - 10) ^ 0xF, 14, 0x1000, -16, alt)
	return [d, single_angle(0x80)]


## Distância do piso sob um objeto (x, y + yr), sólido-topo; ângulo ímpar vira 0.
func obj_floor_dist(x: int, y: int, yr: int, alt: bool) -> Array:
	ang_a = 0
	var d := _sense(0, 0, x, y + yr, 13, 0, 16, alt)
	return [d, 0 if ang_a & 1 else ang_a]
