class_name BgLayer
extends Node2D
## Plano de fundo com deformação por linha, num único draw na GPU (o caminho por faixa travava a Web).

var view: WorldView
var _mat: ShaderMaterial
var _hscroll_img: Image
var _hscroll_tex: ImageTexture
var _bytes: PackedByteArray = PackedByteArray()


class BackdropDraw extends Node2D:
	var fill: Color = Color.BLACK

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 320, 224), fill)


func setup(atlas: Texture2D, layout: Texture2D, cols: int) -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://src/render_modes/bg_deform.gdshader")
	_mat.set_shader_parameter("atlas", atlas)
	_mat.set_shader_parameter("layout_map", layout)
	_mat.set_shader_parameter("atlas_cols", cols)
	_mat.set_shader_parameter("vscroll", 0)
	material = _mat
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_upload(0, PackedInt32Array())


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if view != null and view.sim != null:
		var bg: BgScroll = view.sim.bg
		_upload(bg.vscroll_bg & 0xFFFF, bg.hscroll_bg)
	draw_rect(Rect2(0, 0, 320, 224), Color.WHITE)


func _upload(vscroll: int, hscroll: PackedInt32Array) -> void:
	if _bytes.size() != 224 * 4:
		_bytes.resize(224 * 4)
	for i in range(224):
		var v := 0
		if i < hscroll.size():
			v = int(hscroll[i]) & 0xFFFF
		var o := i * 4
		_bytes[o] = v & 255
		_bytes[o + 1] = (v >> 8) & 255
		_bytes[o + 2] = 0
		_bytes[o + 3] = 255
	if _hscroll_img == null:
		_hscroll_img = Image.create_from_data(224, 1, false, Image.FORMAT_RGBA8, _bytes)
		_hscroll_tex = ImageTexture.create_from_image(_hscroll_img)
	else:
		_hscroll_img.set_data(224, 1, false, Image.FORMAT_RGBA8, _bytes)
		_hscroll_tex.update(_hscroll_img)
	_mat.set_shader_parameter("hscroll_map", _hscroll_tex)
	_mat.set_shader_parameter("vscroll", vscroll)
