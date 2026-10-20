class_name ObjectFactory
extends RefCounted
## Cria objetos de fase pelo ID da lista de objetos. IDs sem implementação geram um
## PlaceholderObj (inerte, sem colisão) e são contados em `missing` para a matriz de cobertura.

static var missing: Dictionary = {}

const RING_SPACING := [
	[0x10, 0], [0x18, 0], [0x20, 0], [0, 0x10], [0, 0x18], [0, 0x20], [0x10, 0x10], [0x18, 0x18],
	[0x20, 0x20], [-0x10, 0x10], [-0x18, 0x18], [-0x20, 0x20], [0x10, 8], [0x18, 0x10], [-0x10, 8],
	[-0x18, 0x10],
]  # parâmetro de espaçamento medido (EV-TAB-0003, ROM 0x9B3E)


func create(id: int) -> GameObject:
	var o: GameObject = ObjectCatalog.make(id)
	if o == null:
		missing[id] = int(missing.get(id, 0)) + 1
		o = PlaceholderObj.new()
	o.kind = id
	return o


func make_explosion(px: int, py: int, with_animal: bool) -> GameObject:
	var e := ExplosionObj.new()
	e.x = px
	e.y = py
	e.vars["animal"] = with_animal
	return e
