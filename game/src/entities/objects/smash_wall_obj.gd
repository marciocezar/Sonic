class_name SmashWallObj
extends GameObject
## Parede quebrável de GHZ (ID 0x3C): sólido 0x1B×0x20; empurrada por jogador rolando com |vx| >= 0x480
## quebra em 8 fragmentos (velocidades medidas em ROM 0xD276/0xD296; gravidade 0x70). ROM 0xD11C.

const FRAG_RIGHT := [[0x400, -0x500], [0x600, -0x100], [0x600, 0x100], [0x400, 0x500],
		[0x600, -0x600], [0x800, -0x200], [0x800, 0x200], [0x600, 0x600]]
const FRAG_LEFT := [[-0x600, -0x600], [-0x800, -0x200], [-0x800, 0x200], [-0x600, 0x600],
		[-0x400, -0x500], [-0x600, -0x100], [-0x600, 0x100], [-0x400, 0x500]]

var saved_xv: int = 0


func init() -> bool:
	art = "smashwall"
	routine = 2
	render |= 4
	act_width = 0x10
	priority = 4
	frame = sub
	return true


func update() -> void:
	if routine == 4:
		_frag_move()
		if not deleted:
			out_of_range_check(true)
		return
	var p: Player = sim.player
	saved_xv = p.xv
	SolidHelpers.solid_object(self, 0x1B, 0x20, 0x20, x)
	if (status & 0x20) == 0:
		out_of_range_check(true)
		return
	if p.anim != Player.AN_ROLL:
		out_of_range_check(true)
		return
	if absi(saved_xv) < 0x480:
		out_of_range_check(true)
		return
	p.xv = saved_xv
	p.x = Fx.u16(p.x + 4)
	var table := FRAG_RIGHT
	if not (Fx.u16(x) < Fx.u16(p.x)):
		p.x = Fx.u16(p.x - 8)
		table = FRAG_LEFT
	p.gs = p.xv
	status &= ~0x20
	p.status &= ~Player.ST_PUSH
	_smash(table)
	_frag_move()
	if not deleted:
		out_of_range_check(true)


func _smash(table: Array) -> void:
	render |= 0x20
	for i in range(8):
		var f: SmashWallObj = self if i == 0 else SmashWallObj.new()
		if i > 0:
			f.respawn_index = -1
			f.kind = kind
			f.inited = true
			f.art = "fragment"
			if sim.objects.place(f, ObjectManager.FIRST_LEVEL_SLOT, true) == null:
				break
		f.routine = 4
		f.render = render
		f.x = x
		f.y = y
		f.priority = priority
		f.act_width = act_width
		f.xv = table[i][0]
		f.yv = table[i][1]
		if i > 0 and f.slot < slot:
			f.speed_to_pos()
			f.yv = Fx.s16(f.yv + 0x70)
	sim.emit_sfx("smash")


func _frag_move() -> void:
	speed_to_pos()
	yv = Fx.s16(yv + 0x70)
	if (render & 0x80) == 0:
		delete()
