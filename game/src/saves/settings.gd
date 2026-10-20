extends Node
## Configurações persistidas (autoload "Settings"). Arquivo user://settings.cfg, schema versionado.
## Nada aqui altera a simulação diretamente; é lido pela apresentação e pelo roteador de entrada.

const PATH := "user://settings.cfg"
const SCHEMA := 2

signal changed

var profile: String = "fidelity"  # fidelity (visual original, padrão) | enhanced
var touch_mode: String = "auto"  # auto | on | off
var touch_size: float = 1.0
var touch_opacity: float = 0.55
var touch_dpad_offset: Vector2 = Vector2.ZERO
var touch_buttons_offset: Vector2 = Vector2.ZERO
var touch_deadzone: float = 0.28
var sfx_volume: float = 0.8
var music_volume: float = 0.6
var show_debug: bool = false
var key_bindings: Dictionary = {}  # ação -> Array[int] keycodes físicos
var progress_level: String = ""


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	var schema := int(cf.get_value("meta", "schema", 0))
	if schema != SCHEMA and schema != 1:
		push_warning("settings: schema %d diferente de %d; usando padrões" % [schema, SCHEMA])
		return
	# schema 1 tinha "enhanced" como padrão; na migração o perfil volta ao visual original (fidelity)
	if schema == SCHEMA:
		profile = str(cf.get_value("video", "profile", profile))
	if profile != "fidelity" and profile != "enhanced":
		profile = "fidelity"
	touch_mode = str(cf.get_value("touch", "mode", touch_mode))
	touch_size = clampf(float(cf.get_value("touch", "size", touch_size)), 0.5, 1.8)
	touch_opacity = clampf(float(cf.get_value("touch", "opacity", touch_opacity)), 0.15, 1.0)
	touch_dpad_offset = cf.get_value("touch", "dpad_offset", touch_dpad_offset)
	touch_buttons_offset = cf.get_value("touch", "buttons_offset", touch_buttons_offset)
	touch_deadzone = clampf(float(cf.get_value("touch", "deadzone", touch_deadzone)), 0.05, 0.6)
	sfx_volume = clampf(float(cf.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	music_volume = clampf(float(cf.get_value("audio", "music", music_volume)), 0.0, 1.0)
	show_debug = bool(cf.get_value("debug", "overlay", show_debug))
	var kb: Variant = cf.get_value("input", "bindings", {})
	if kb is Dictionary:
		key_bindings = kb
	progress_level = str(cf.get_value("progress", "level", ""))


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("meta", "schema", SCHEMA)
	cf.set_value("video", "profile", profile)
	cf.set_value("touch", "mode", touch_mode)
	cf.set_value("touch", "size", touch_size)
	cf.set_value("touch", "opacity", touch_opacity)
	cf.set_value("touch", "dpad_offset", touch_dpad_offset)
	cf.set_value("touch", "buttons_offset", touch_buttons_offset)
	cf.set_value("touch", "deadzone", touch_deadzone)
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("audio", "music", music_volume)
	cf.set_value("debug", "overlay", show_debug)
	cf.set_value("input", "bindings", key_bindings)
	cf.set_value("progress", "level", progress_level)
	cf.save(PATH)
	changed.emit()


func touch_enabled() -> bool:
	if touch_mode == "on":
		return true
	if touch_mode == "off":
		return false
	return PlatformInfo.prefers_touch()
