class_name Trig
extends RefCounted
## Trigonometria inteira em 256 passos por volta, gerada matematicamente (sem copiar tabelas da ROM).
##
## Evidência (docs/reverse-engineering/04-evidence-ledger.csv):
##  - seno: truncamento de sin(k·2π/256)·256 reproduz a tabela de referência em 318/320 entradas;
##    as entradas 147 e 237 valem -117 na referência (errata medida, aplicada abaixo).
##  - arco-tangente: arredondamento de atan(k/256)·128/π reproduz 257/257 entradas.

static var _sin: PackedInt32Array = PackedInt32Array()
static var _atan: PackedInt32Array = PackedInt32Array()


static func _ensure() -> void:
	if _sin.size() == 320:
		return
	_sin.resize(320)
	for k in range(320):
		_sin[k] = int(sin(float(k) * TAU / 256.0) * 256.0)
	# errata medida na referência (ver evidência EV-TAB-0001)
	_sin[147] = -117
	_sin[237] = -117
	_atan.resize(257)
	for k in range(257):
		_atan[k] = int(round(atan(float(k) / 256.0) * 128.0 / PI))


## Retorna [seno, cosseno] do ângulo (0..255), em 8.8 com sinal.
static func sincos(angle: int) -> Vector2i:
	_ensure()
	var a := angle & 0xFF
	return Vector2i(_sin[a], _sin[a + 64])


static func sine(angle: int) -> int:
	_ensure()
	return _sin[angle & 0xFF]


static func cosine(angle: int) -> int:
	_ensure()
	return _sin[(angle & 0xFF) + 64]


## Ângulo (0..255) do vetor (x, y) com eixo Y para baixo; (0,0) -> 0x40.
static func angle_of(x: int, y: int) -> int:
	_ensure()
	x = Fx.s16(x)
	y = Fx.s16(y)
	if x == 0 and y == 0:
		return 0x40
	var ax: int = absi(x)
	var ay: int = absi(y)
	var r: int
	if ay < ax:
		r = _atan[(ay << 8) / ax]
	else:
		r = 0x40 - _atan[(ax << 8) / ay]
	if x < 0:
		r = 0x80 - r
	if y < 0:
		r = 0x100 - r
	return r & 0xFF


static func sine_table() -> PackedInt32Array:
	_ensure()
	return _sin


static func atan_table() -> PackedInt32Array:
	_ensure()
	return _atan
