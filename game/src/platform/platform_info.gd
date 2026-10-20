class_name PlatformInfo
extends RefCounted
## Detecção de plataforma e capacidades (sem efeitos colaterais).


static func is_mobile_native() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")


static func is_web() -> bool:
	return OS.has_feature("web")


static func is_web_mobile() -> bool:
	return OS.has_feature("web_android") or OS.has_feature("web_ios")


## Overlay de toque visível por padrão em apps móveis e Web móvel; nunca por padrão no desktop.
static func prefers_touch() -> bool:
	if is_mobile_native() or is_web_mobile():
		return true
	if is_web() and DisplayServer.is_touchscreen_available():
		return true
	return false


static func name() -> String:
	if OS.has_feature("web_ios"):
		return "web-ios"
	if OS.has_feature("web_android"):
		return "web-android"
	if OS.has_feature("web"):
		return "web-desktop"
	return OS.get_name().to_lower()


## Retângulo seguro (notch/barras) em pixels da janela.
static func safe_rect() -> Rect2:
	var win := DisplayServer.window_get_size()
	var sa := DisplayServer.get_display_safe_area()
	if sa.size.x <= 0 or sa.size.y <= 0 or is_web():
		return Rect2(Vector2.ZERO, win)
	var screen_pos := DisplayServer.window_get_position()
	var r := Rect2(sa.position - screen_pos, sa.size)
	return r.intersection(Rect2(Vector2.ZERO, win))
