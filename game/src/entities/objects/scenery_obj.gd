class_name SceneryObj
extends GameObject
## Objeto 0x1C "cenário" (ROM 0x87CA): subtipo indexa uma tabela de 10 bytes (0x882E): mapeamento (long),
## arte (word), quadro, largura ativa, prioridade, tipo de colisão. Depois só exibe e sai de alcance.

const VALUES := 0x882E


func init() -> bool:
	routine = 2
	var rom: PackedByteArray = sim.level.rom
	if rom.size() == 0x80000:
		var a := VALUES + sub * 10
		map_addr = ((rom[a] << 24) | (rom[a + 1] << 16) | (rom[a + 2] << 8) | rom[a + 3]) & 0xFFFFFF
		gfx = (rom[a + 4] << 8) | rom[a + 5]
		frame = rom[a + 6]
		act_width = rom[a + 7]
		priority = rom[a + 8]
		col_type = rom[a + 9]
	render |= 4
	# a rotina de inicialização segue direto para a verificação de alcance (0x880C)
	return true


func update() -> void:
	out_of_range_check(true)
