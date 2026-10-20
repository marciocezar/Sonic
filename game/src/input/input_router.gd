extends Node
## Adaptador único de entrada (autoload "InputRouter").
## Teclado, gamepad e toque apenas emitem AÇÕES; a simulação recebe somente um byte de botões
## no formato do controle original de 3 botões (U D L R B C A Start) por quadro.

const ACTIONS := ["move_up", "move_down", "move_left", "move_right", "btn_b", "btn_c", "btn_a", "start"]
const BITS := {"move_up": 1, "move_down": 2, "move_left": 4, "move_right": 8,
		"btn_b": 16, "btn_c": 32, "btn_a": 64, "start": 128}
const DEFAULT_KEYS := {
	"move_up": [KEY_UP, KEY_W], "move_down": [KEY_DOWN, KEY_S],
	"move_left": [KEY_LEFT, KEY_A], "move_right": [KEY_RIGHT, KEY_D],
	"btn_a": [KEY_J, KEY_Z], "btn_b": [KEY_K, KEY_X], "btn_c": [KEY_L, KEY_C, KEY_SPACE],
	"start": [KEY_ENTER, KEY_ESCAPE, KEY_P],
}
const DEFAULT_PAD := {
	"move_up": [JOY_BUTTON_DPAD_UP], "move_down": [JOY_BUTTON_DPAD_DOWN],
	"move_left": [JOY_BUTTON_DPAD_LEFT], "move_right": [JOY_BUTTON_DPAD_RIGHT],
	"btn_a": [JOY_BUTTON_X], "btn_b": [JOY_BUTTON_A], "btn_c": [JOY_BUTTON_B],
	"start": [JOY_BUTTON_START],
}

var touch_bits: int = 0  # escrito pelo overlay de toque
var injected_bits: int = -1  # replay programático (>= 0 substitui a entrada física)
var stick_deadzone: float = 0.4
var latched_bits: int = 0  # pressões mais curtas que um quadro (toque rápido) não se perdem


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	for a in ACTIONS:
		if event.is_action_pressed(a):
			latched_bits |= int(BITS[a])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_bindings()


func apply_bindings() -> void:
	for a in ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
		InputMap.action_erase_events(a)
		var keys: Array = Settings.key_bindings.get(a, DEFAULT_KEYS[a])
		for k in keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = int(k)
			InputMap.action_add_event(a, ev)
		for b in DEFAULT_PAD[a]:
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(a, jb)


func rebind(action: String, keycode: int) -> void:
	Settings.key_bindings[action] = [keycode]
	apply_bindings()
	Settings.save_settings()


func reset_bindings() -> void:
	Settings.key_bindings = {}
	apply_bindings()
	Settings.save_settings()


func key_names(action: String) -> String:
	var keys: Array = Settings.key_bindings.get(action, DEFAULT_KEYS[action])
	var names: PackedStringArray = []
	for k in keys:
		names.append(OS.get_keycode_string(int(k)))
	return ", ".join(names)


## Byte de botões do quadro atual (estado mantido).
func read_bits() -> int:
	if injected_bits >= 0:
		return injected_bits
	var v := 0
	for a in ACTIONS:
		if Input.is_action_pressed(a):
			v |= int(BITS[a])
	# analógico esquerdo como direcional
	for dev in Input.get_connected_joypads():
		var ax := Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
		var ay := Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
		if ax < -stick_deadzone:
			v |= 4
		elif ax > stick_deadzone:
			v |= 8
		if ay < -stick_deadzone:
			v |= 1
		elif ay > stick_deadzone:
			v |= 2
	v |= touch_bits
	v |= latched_bits
	latched_bits = 0
	# direções opostas simultâneas são permitidas no hardware original; mantidas.
	return v & 0xFF


func release_all() -> void:
	for a in ACTIONS:
		Input.action_release(a)
	touch_bits = 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		release_all()
