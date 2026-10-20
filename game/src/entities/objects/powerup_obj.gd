class_name PowerUpObj
extends GameObject
## Conteúdo do monitor: sobe (vy -0x300, desacelera 0x18/quadro); ao parar, aplica o efeito
## e permanece visível por 29 quadros. O sprite é só o ícone (ROM 0xA31A): o mapeamento aponta
## para a primeira peça do quadro (anim+2) de Map_Monitor, com o bit de peça única.


const MAP_MONITOR := 0xA58A


func _init() -> void:
	kind = 0x2E


func init() -> bool:
	kind = 0x2E
	art = "powerup"
	act_width = 8
	priority = 3
	yv = -0x300
	frame = (anim + 2) & 0xFF
	routine = 2
	gfx = 0x680
	render = 0x24
	var rom: PackedByteArray = sim.level.rom
	if rom.size() != 0x80000:
		rom = sim.level.sprite_rom
	if rom.size() == 0x80000:
		var off := MAP_MONITOR + frame * 2
		var rel := Fx.s16((rom[off] << 8) | rom[off + 1])
		map_addr = MAP_MONITOR + rel + 1
	return true


func update() -> void:
	match routine:
		2:
			if yv < 0:
				speed_to_pos()
				yv = Fx.s16(yv + 0x18)
				return
			routine = 4
			var kind_id := anim
			timer = 29
			_apply(kind_id)
		4:
			timer -= 1
			if timer < 0:
				delete()


func _apply(k: int) -> void:
	var p: Player = sim.player
	match k:
		2:
			sim.lives = min(sim.lives + 1, 99)
			sim.hud_dirty = true
			sim.emit_music("extralife")
		3:
			sim.shoes = true
			p.shoe_time = 0x4B0
			sim.speed_max = 0xC00
			sim.speed_acc = 0x18
			sim.speed_dec = 0x80
			sim.emit_music("speedup")
		4:
			sim.shield = true
			sim.emit_sfx("shield")
		5:
			sim.invincible = true
			p.inv_time = 0x4B0
			if not sim.lock_screen:
				sim.emit_music("invincible")
		6:
			sim.add_rings_bonus(10)
		_:
			pass
