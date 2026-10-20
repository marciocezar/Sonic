class_name TouchLogic
extends RefCounted
## Lógica pura do controle virtual (testável sem tela): mapeia ponteiros (IDs de toque) para
## bits de botões. Cada ponteiro é "capturado" pelo controle onde começou (direcional ou botões);
## arrastar dentro da área de botões troca de botão; soltar/cancelar remove o ponteiro.

const BIT_UP := 1
const BIT_DOWN := 2
const BIT_LEFT := 4
const BIT_RIGHT := 8
const BIT_B := 16
const BIT_C := 32
const BIT_A := 64
const BIT_START := 128

var dpad_center: Vector2 = Vector2(150, 560)
var dpad_radius: float = 110.0
var deadzone: float = 0.28
var buttons: Array = []  # [{bit, center: Vector2, radius: float, label}]
var pointers: Dictionary = {}  # id -> {kind: "dpad"|"button"|"none", pos: Vector2}


func layout(view: Vector2, safe: Rect2, size_scale: float, dpad_off: Vector2, btn_off: Vector2) -> void:
	var s := clampf(size_scale, 0.5, 1.8) * clampf(view.y / 720.0, 0.6, 2.5)
	var margin := 24.0 * s
	dpad_radius = 100.0 * s
	dpad_center = Vector2(safe.position.x + margin + dpad_radius,
			safe.end.y - margin - dpad_radius) + dpad_off
	var r := 46.0 * s
	var base := Vector2(safe.end.x - margin - r, safe.end.y - margin - r) + btn_off
	buttons = [
		{"bit": BIT_C, "center": base, "radius": r, "label": "C"},
		{"bit": BIT_B, "center": base + Vector2(-2.3 * r, 0.55 * r), "radius": r, "label": "B"},
		{"bit": BIT_A, "center": base + Vector2(-4.6 * r, 1.1 * r), "radius": r, "label": "A"},
		{"bit": BIT_START, "center": Vector2(safe.get_center().x, safe.position.y + margin + 0.6 * r),
			"radius": 0.6 * r, "label": "START"},
	]


func press(id: int, pos: Vector2) -> void:
	var kind := "none"
	if pos.distance_to(dpad_center) <= dpad_radius * 1.35:
		kind = "dpad"
	elif _button_at(pos) != 0 or _in_button_zone(pos):
		kind = "button"
	pointers[id] = {"kind": kind, "pos": pos}


func drag(id: int, pos: Vector2) -> void:
	if not pointers.has(id):
		press(id, pos)
		return
	pointers[id]["pos"] = pos


func release(id: int) -> void:
	pointers.erase(id)


func cancel_all() -> void:
	pointers.clear()


func bits() -> int:
	var v := 0
	for id in pointers:
		var p: Dictionary = pointers[id]
		if p["kind"] == "dpad":
			v |= _dpad_bits(p["pos"])
		elif p["kind"] == "button":
			v |= _button_at(p["pos"])
	return v


func _dpad_bits(pos: Vector2) -> int:
	var d := (pos - dpad_center) / maxf(dpad_radius, 1.0)
	if d.length() < deadzone:
		return 0
	var v := 0
	var ang := atan2(d.y, d.x)  # 8 direções com setores de 45°
	var sector := int(round(ang / (PI / 4.0))) % 8
	if sector < 0:
		sector += 8
	match sector:
		0:
			v = BIT_RIGHT
		1:
			v = BIT_RIGHT | BIT_DOWN
		2:
			v = BIT_DOWN
		3:
			v = BIT_LEFT | BIT_DOWN
		4:
			v = BIT_LEFT
		5:
			v = BIT_LEFT | BIT_UP
		6:
			v = BIT_UP
		7:
			v = BIT_RIGHT | BIT_UP
	return v


func _button_at(pos: Vector2) -> int:
	var best := 0
	var best_d := INF
	for b in buttons:
		var d: float = pos.distance_to(b["center"])
		if d <= float(b["radius"]) * 1.25 and d < best_d:
			best_d = d
			best = int(b["bit"])
	return best


func _in_button_zone(pos: Vector2) -> bool:
	for b in buttons:
		if int(b["bit"]) == BIT_START:
			continue
		if pos.distance_to(b["center"]) <= float(b["radius"]) * 2.2:
			return true
	return false
