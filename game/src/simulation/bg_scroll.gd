class_name BgScroll
extends RefCounted
## Posições do plano de fundo e tabela de rolagem horizontal por linha (deformação), portadas da ROM:
## inicialização 0x61EC (tabela por zona 0x6216), deformação 0x6286 (tabela por zona 0x62DE), auxiliares
## 0x6768/0x67D2 (soma 32 bits em $F708/$F70C), 0x6814 (Y inteiro do fundo), 0x6844 ($F710), tabela SLZ 0x64A8.
## Campos espelham a RAM: bg_x=$F708 bg_y=$F70C (16.16), bg2_x=$F710 (16.16), bg2_y=$F714, bg3_x=$F718.
## Executa só quando a câmera roda (jogador vivo), como DeformLayers no laço da referência.

const LINES := 224

var bg_x: int = 0
var bg_y: int = 0
var bg2_x: int = 0
var bg2_y: int = 0
var bg3_x: int = 0
var vscroll_bg: int = 0  # $F618
## Rolagem horizontal por linha do plano B (valor gravado na tabela: negativo da posição).
var hscroll_bg: PackedInt32Array = PackedInt32Array()
var slz_table: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	hscroll_bg.resize(240)
	slz_table.resize(68)


static func _ext(v: int) -> int:
	return Fx.s16(v & 0xFFFF)


static func _u32(v: int) -> int:
	return v & 0xFFFFFFFF


func _set_hi(field: int, word: int) -> int:
	return ((word & 0xFFFF) << 16) | (field & 0xFFFF)


func bg_y_int() -> int:
	return (bg_y >> 16) & 0xFFFF


## Reinício por poste (0x61EC com $FE30 != 0): mantém as posições salvas e só roda a parte da zona.
func init_zone_only(sim) -> void:
	var cy: int = sim.camera.y & 0xFFFF
	match _zone(sim):
		0, 6:
			deform(sim)
		1:
			bg_y = _set_hi(bg_y, cy >> 1)
		3:
			bg_y = _set_hi(bg_y, (cy >> 1) + 0xC0)
		4:
			var v := (cy * 48) >> 8
			bg_y = _set_hi(bg_y, v)
			bg2_y = v
		5:
			bg_y = _set_hi(bg_y, (cy * 32) >> 8)
	vscroll_bg = bg_y_int()


## Inicialização ao carregar a fase (0x61EC): d0 = câmera Y, d1 = câmera X.
func init(sim) -> void:
	var cy: int = sim.camera.y & 0xFFFF
	var cx: int = sim.camera.x & 0xFFFF
	bg_y = _set_hi(bg_y, cy)
	bg2_y = cy
	bg_x = _set_hi(bg_x, cx)
	bg2_x = _set_hi(bg2_x, cx)
	bg3_x = _set_hi(bg3_x, cx)
	match _zone(sim):
		0, 6:
			deform(sim)
		1:
			bg_y = _set_hi(bg_y, cy >> 1)
		3:
			bg_y = _set_hi(bg_y, (cy >> 1) + 0xC0)
		4:
			var v := (cy * 48) >> 8
			bg_y = _set_hi(bg_y, v)
			bg2_y = v
		5:
			bg_y = _set_hi(bg_y, (cy * 32) >> 8)
	vscroll_bg = bg_y_int()


func _zone(sim) -> int:
	return sim.level.zone if sim.level.theme != "lab" else 0


## 0x6768/0x67D2: soma d4 a $F708 e d5 a $F70C (32 bits).
func _scroll_xy(d4: int, d5: int) -> void:
	bg_x = _u32(bg_x + d4)
	bg_y = _u32(bg_y + d5)


## Deformação do quadro (após câmera e eventos dinâmicos).
func deform(sim) -> void:
	var a := _ext(sim.camera.shift_x)
	var b := _ext(sim.camera.shift_y)
	var camx: int = sim.camera.x & 0xFFFF
	match _zone(sim):
		0, 6:
			_deform_ghz(sim, a, camx)
		1:
			_scroll_xy(a << 7, b << 7)
			_fill(-(bg_x >> 16))
		2:
			_scroll_xy((a << 6) * 3, 0)
			var d0 := 0x200
			var d1: int = Fx.s16((sim.camera.y & 0xFFFF) - 0x1C8)
			if (sim.camera.y & 0xFFFF) >= 0x1C8:
				d0 = Fx.s16(d0 + (Fx.s16(d1 * 3) >> 2))
			bg2_y = d0 & 0xFFFF
			bg_y = _set_hi(bg_y, d0)
			_fill(-(bg_x >> 16))
		3:
			_scroll_xy(a << 7, b << 7)
			_deform_slz(camx)
		4:
			_scroll_xy(a << 6, (b << 4) * 3)
			_fill(-(bg_x >> 16))
		5:
			_scroll_xy(a << 6, b << 5)
			_fill(-(bg_x >> 16))
	vscroll_bg = bg_y_int()


func _fill(v: int) -> void:
	for l in range(LINES):
		hscroll_bg[l] = Fx.s16(v)


func _deform_ghz(sim, a: int, camx: int) -> void:
	_scroll_xy(a * 96, 0)
	bg2_x = _u32(bg2_x + (a << 7))
	var d0 := Fx.s16(0x26 - (((sim.camera.y & 0xFFFF) & 0x7FF) >> 5))
	bg2_y = d0 & 0xFFFF
	var d4 := d0
	bg_y = _set_hi(bg_y, d0)
	var l := 0
	var v1 := Fx.s16(-(bg_x >> 16))
	for _i in range(0x70 - d4):
		hscroll_bg[l] = v1
		l += 1
	var v2 := Fx.s16(-(bg2_x >> 16))
	for _i in range(0x28):
		hscroll_bg[l] = v2
		l += 1
	# gradiente: passo = divs.w ((camx - 0x200 - $F710) << 8) / 0x68, depois << 8
	var x0: int = (bg2_x >> 16) & 0xFFFF
	var num: int = Fx.s16(camx - 0x200 - x0) << 8
	var step := _divs(num, 0x68) << 8
	var acc: int = x0 << 16
	for _i in range(0x48 + d4):
		if l < hscroll_bg.size():
			hscroll_bg[l] = Fx.s16(-((acc >> 16) & 0xFFFF))
		l += 1
		acc = _u32(acc + step)


## divs.w do 68000: quociente de 16 bits com sinal; em estouro o registrador fica inalterado (palavra baixa).
static func _divs(num: int, den: int) -> int:
	var q := int(num / den) if num >= 0 else -int(-num / den)
	if q < -0x8000 or q > 0x7FFF:
		return Fx.s16(num & 0xFFFF)
	return q


func _deform_slz(camx: int) -> void:
	var d2: int = Fx.s16(-camx)
	var d0 := Fx.s16((d2 >> 3) - d2)
	var step := (_divs(d0 << 4, 0x1C) << 4) << 8
	var acc: int = (d2 & 0xFFFF) << 16
	var i := 0
	for _k in range(28):
		slz_table[i] = Fx.s16((acc >> 16) & 0xFFFF)
		i += 1
		acc = _u32(acc + step)
	for _k in range(5):
		slz_table[i] = d2 >> 3
		i += 1
	for _k in range(5):
		slz_table[i] = d2 >> 2
		i += 1
	for _k in range(30):
		slz_table[i] = d2 >> 1
		i += 1
	var by := bg_y_int()
	var idx := (((by - 0xC0) & 0x3F0) >> 3) >> 1
	var r := by & 0xF
	var l := 0
	var v: int = slz_table[mini(idx, 67)]
	idx += 1
	for _k in range(16 - r):
		hscroll_bg[l] = v
		l += 1
	for _blk in range(14):
		v = slz_table[mini(idx, 67)]
		idx += 1
		for _k in range(16):
			if l < hscroll_bg.size():
				hscroll_bg[l] = v
			l += 1


## Tabela de rolagem em pares [valor, repetições] (mesmo formato dos traces de referência).
func hscroll_rle() -> Array:
	var out: Array = []
	for l in range(LINES):
		var v: int = hscroll_bg[l]
		if not out.is_empty() and out[-1][0] == v:
			out[-1][1] += 1
		else:
			out.append([v, 1])
	return out
