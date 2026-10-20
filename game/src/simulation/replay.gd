class_name Replay
extends RefCounted
## Sequências de entrada por quadro (formato de tests/parity/replays/*.json) e utilidades.
## Letras: U D L R B C A S (cima, baixo, esquerda, direita, B, C, A, Start).

const LETTERS := {"U": 1, "D": 2, "L": 4, "R": 8, "B": 16, "C": 32, "A": 64, "S": 128}

var name: String = ""
var level: String = ""
var frames: int = 0
var inputs: PackedInt32Array = PackedInt32Array()
var pokes: Dictionary = {}  # quadro -> {x, y} (escritas roteirizadas, iguais às da referência)


static func parse_buttons(s: String) -> int:
	var v := 0
	for ch in s:
		v |= int(LETTERS.get(ch, 0))
	return v


static func buttons_to_string(v: int) -> String:
	var out := ""
	for k in ["U", "D", "L", "R", "B", "C", "A", "S"]:
		if v & int(LETTERS[k]):
			out += k
	return out


static func from_dict(d: Dictionary) -> Replay:
	var r := Replay.new()
	r.name = str(d.get("name", ""))
	r.level = str(d.get("level", ""))
	for seg in d.get("inputs", []):
		var n := int(seg[0])
		var b := parse_buttons(str(seg[1]))
		for i in range(n):
			r.inputs.append(b)
	r.frames = int(d.get("frames", r.inputs.size()))
	for pk in d.get("pokes", []):
		r.pokes[int(pk[0])] = pk[1]
	return r


static func load_file(path: String) -> Replay:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (v is Dictionary):
		return null
	return from_dict(v)


func input_at(f: int) -> int:
	# f começa em 1 (quadro após F0)
	var i := f - 1
	return inputs[i] if i >= 0 and i < inputs.size() else 0
