class_name GameObject
extends RefCounted
## Objeto genérico de fase (inimigos, itens, plataformas...). Campos espelham a estrutura de
## estado por objeto observada na referência, para comparar traces campo a campo.

var sim
var kind: int = 0  # ID do objeto na lista da fase
var sub: int = 0  # subtipo
var x: int = 0
var xs: int = 0
var y: int = 0
var ys: int = 0
var xv: int = 0
var yv: int = 0
var routine: int = 0
var routine2: int = 0
var status: int = 0
var render: int = 0  # bit0 espelho X, bit1 espelho Y, bit7 visível na tela
var col_type: int = 0  # tipo de toque (bits 6-7 categoria, 0-5 índice de tamanho)
var col_prop: int = 0
var act_width: int = 8
var height: int = 8
var width: int = 8
var frame: int = 0
var anim: int = 0
var ani_frame: int = 0
var time_frame: int = 0
var priority: int = 3
var respawn_index: int = -1  # índice na tabela de estado de respawn (-1 = não lembrado)
var remember: bool = false
var deleted: bool = false
var timer: int = 0
var parent = null
var vars: Dictionary = {}
var layout_x: int = 0  # posição original (para despawn)
var art: String = ""  # chave visual para os renderizadores
## Mapeamento/arte do sprite definidos pelo próprio objeto (como obMap/obGfx); -1 = usar ObjectArtTable.
var map_addr: int = -1
var gfx: int = -1
var slot: int = 0


var inited: bool = false


## Rotina de inicialização (executada na 1ª vez que o slot do objeto é processado, como na referência).
## Retorne true quando a referência "cai" direto na rotina seguinte no mesmo quadro.
func init() -> bool:
	return false


func update() -> void:
	pass


## Chamado pelo ObjectManager a cada quadro.
func step() -> void:
	if not inited:
		inited = true
		if not init():
			return
	update()


## Reação ao toque do jogador (categoria 0x40 = item). Retorna nada.
func touch_item(_p: Player) -> void:
	pass


## Chamado quando o jogador destrói o objeto (inimigo/monitor).
func on_destroyed(_p: Player) -> void:
	pass


## Exclusão imediata: o slot fica livre já neste quadro (como na referência).
func delete() -> void:
	deleted = true
	if sim != null and sim.objects != null and slot < sim.objects.slots.size() and sim.objects.slots[slot] == self:
		sim.objects.slots[slot] = null


func speed_to_pos() -> void:
	var nx := ((x << 16) | xs) + (xv << 8)
	var ny := ((y << 16) | ys) + (yv << 8)
	x = (nx >> 16) & 0xFFFF
	xs = nx & 0xFFFF
	y = (ny >> 16) & 0xFFFF
	ys = ny & 0xFFFF


func object_fall() -> void:
	var nx := ((x << 16) | xs) + (xv << 8)
	var ny := ((y << 16) | ys) + (yv << 8)
	yv = Fx.s16(yv + 0x38)
	x = (nx >> 16) & 0xFFFF
	xs = nx & 0xFFFF
	y = (ny >> 16) & 0xFFFF
	ys = ny & 0xFFFF


## Saiu da janela de atividade (relativa à câmera, pela posição x atual)? Remove e libera para recarga.
## release=true reproduz "RememberState" (libera recarga); false reproduz exclusão simples.
func out_of_range_check(release: bool = true) -> bool:
	var d0 := (x & 0xFF80) - ((Fx.u16(sim.camera.x) - 0x80) & 0xFF80)
	if Fx.u16(d0) > 0x280:
		if release:
			sim.objects.release(self)
		deleted = true
		return true
	return false


func floor_dist() -> Array:
	return sim.terrain.obj_floor_dist(x, y, height, false)
