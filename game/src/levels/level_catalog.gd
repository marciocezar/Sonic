class_name LevelCatalog
extends RefCounted
## Fases disponíveis: fases próprias (sempre) + levelpacks privados (somente se o usuário
## informar o diretório local na execução de laboratório; nunca empacotados).

## Ordem de progressão medida (tabela em ROM 0xC6F4, evidência EV-TAB-0005).
const ORIGINAL_ORDER := ["ghz1", "ghz2", "ghz3", "mz1", "mz2", "mz3", "syz1", "syz2", "syz3",
		"lz1", "lz2", "lz3", "slz1", "slz2", "slz3", "sbz1", "sbz2", "sbz3", "fz"]
const BUILTIN := ["lab1", "lab2"]

var packs_dir: String = ""
var entries: Array = []  # [{id, title, source}]
var importer := RomImporter.new()


## Fontes das fases originais (nunca embutidas no build): levelpacks privados de laboratório (desktop) ou
## a ROM do próprio usuário importada em tempo de execução (todas as plataformas).
func scan(dir: String) -> void:
	packs_dir = dir
	entries.clear()
	var own := {"lab1": "LAB ZONE (PROPRIA)", "lab2": "LAB ZONE 2"}
	for b in BUILTIN:
		entries.append({"id": b, "title": own.get(b, b), "source": "builtin"})
	var have_packs := dir != "" and DirAccess.dir_exists_absolute(dir)
	for lid in ORIGINAL_ORDER:
		if have_packs and FileAccess.file_exists(dir.path_join(lid).path_join("level.json")):
			entries.append({"id": lid, "title": _title(lid), "source": "pack"})
		elif importer.is_loaded():
			entries.append({"id": lid, "title": _title(lid), "source": "rom"})


func has_originals() -> bool:
	for e in entries:
		if e["source"] != "builtin":
			return true
	return false


static func _title(lid: String) -> String:
	var names := {"ghz": "GREEN HILL", "mz": "MARBLE", "syz": "SPRING YARD", "lz": "LABYRINTH",
			"slz": "STAR LIGHT", "sbz": "SCRAP BRAIN", "fz": "FINAL"}
	var z := lid.rstrip("0123456789")
	var act := lid.substr(z.length())
	return "%s %s" % [names.get(z, z.to_upper()), ("ATO " + act) if act != "" else ""]


func load_level(lid: String) -> LevelData:
	for e in entries:
		if e["id"] == lid:
			if e["source"] == "builtin":
				return LevelData.load_builtin(lid)
			if e["source"] == "rom":
				return importer.load_level(lid)
			return LevelData.load_pack(packs_dir.path_join(lid))
	return null


func next_of(lid: String) -> String:
	var i := ORIGINAL_ORDER.find(lid)
	if i >= 0 and i + 1 < ORIGINAL_ORDER.size():
		var n: String = ORIGINAL_ORDER[i + 1]
		for e in entries:
			if e["id"] == n:
				return n
	return ""
