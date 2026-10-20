extends Control
## Controle virtual desenhado no jogo (direcional + A/B/C + Start), multitoque, com área segura,
## tamanho/opacidade/posição ajustáveis. Não abre teclado do sistema: só lê eventos de toque.

var logic := TouchLogic.new()
var font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	Settings.changed.connect(_relayout)
	get_viewport().size_changed.connect(_relayout)
	_relayout()


func _relayout() -> void:
	visible = Settings.touch_enabled()
	logic.deadzone = Settings.touch_deadzone
	var vs := get_viewport_rect().size
	var safe := PlatformInfo.safe_rect()
	# converte a área segura da janela para coordenadas do canvas
	var win := Vector2(DisplayServer.window_get_size())
	var k := vs / win if win.x > 0 and win.y > 0 else Vector2.ONE
	var safe_c := Rect2(safe.position * k, safe.size * k)
	logic.layout(vs, safe_c, Settings.touch_size, Settings.touch_dpad_offset, Settings.touch_buttons_offset)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		var pos := _to_canvas(t.position)
		if t.canceled:
			logic.release(t.index)
		elif t.pressed:
			logic.press(t.index, pos)
		else:
			logic.release(t.index)
		_publish()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		logic.drag(d.index, _to_canvas(d.position))
		_publish()


func _to_canvas(p: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * p


func _publish() -> void:
	InputRouter.touch_bits = logic.bits()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		logic.cancel_all()
		_publish()


func _draw() -> void:
	var a := Settings.touch_opacity
	var bits := logic.bits()
	var c_base := Color(1, 1, 1, 0.18 * a / 0.55)
	var c_line := Color(1, 1, 1, a)
	draw_circle(logic.dpad_center, logic.dpad_radius, c_base)
	draw_arc(logic.dpad_center, logic.dpad_radius, 0, TAU, 48, c_line, 2.0)
	var dirs := {TouchLogic.BIT_UP: Vector2(0, -1), TouchLogic.BIT_DOWN: Vector2(0, 1),
			TouchLogic.BIT_LEFT: Vector2(-1, 0), TouchLogic.BIT_RIGHT: Vector2(1, 0)}
	for b in dirs:
		var dv: Vector2 = dirs[b]
		var on: bool = (bits & int(b)) != 0
		var tip: Vector2 = logic.dpad_center + dv * logic.dpad_radius * 0.75
		var side := Vector2(-dv.y, dv.x) * logic.dpad_radius * 0.22
		var back: Vector2 = logic.dpad_center + dv * logic.dpad_radius * 0.38
		var col := Color(1, 0.85, 0.2, a) if on else c_line
		draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), col)
	for btn in logic.buttons:
		var on2: bool = (bits & int(btn["bit"])) != 0
		var col2 := Color(1, 0.85, 0.2, a) if on2 else c_base
		draw_circle(btn["center"], btn["radius"], col2)
		draw_arc(btn["center"], btn["radius"], 0, TAU, 40, c_line, 2.0)
		var fs := int(float(btn["radius"]) * (0.45 if str(btn["label"]).length() > 1 else 0.8))
		var sz := font.get_string_size(btn["label"], HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, btn["center"] - Vector2(sz.x / 2, -fs / 3.0), btn["label"],
				HORIZONTAL_ALIGNMENT_CENTER, -1, fs, c_line)
