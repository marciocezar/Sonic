class_name RomAnims
extends RefCounted
## Roteiros de animação de objetos lidos da ROM do usuário em execução (tabelas usadas com AnimateSprite 0xA718;
## extraídas/validadas por `tooling/obj_anims.py`). Sem ROM (build público), usa o roteiro de reserva do objeto.
## Comandos convertidos para o formato do ObjAnim: 0xFF=-1, 0xFE=-2, 0xFD=-3, 0xFC=-4, 0xFB=-5, 0xFA=-6.

static var _cache: Dictionary = {}


static func table(sim, addr: int, fallback: Array) -> Array:
	var rom: PackedByteArray = sim.level.rom
	if rom.size() != 0x80000:
		return fallback
	if _cache.has(addr):
		return _cache[addr]
	var first := (rom[addr] << 8) | rom[addr + 1]
	var n := clampi(first / 2, 1, 32)
	var out: Array = []
	for i in range(n):
		var off := (rom[addr + i * 2] << 8) | rom[addr + i * 2 + 1]
		out.append(_script(rom, addr + off))
	_cache[addr] = out
	return out


static func _script(rom: PackedByteArray, a: int) -> Array:
	var out: Array = [rom[a]]
	var p := a + 1
	for _i in range(64):
		var v: int = rom[p]
		if v >= 0xFA:
			out.append(v - 0x100)
			if v == 0xFE or v == 0xFD:
				out.append(rom[p + 1])
			break
		out.append(v)
		p += 1
	return out
