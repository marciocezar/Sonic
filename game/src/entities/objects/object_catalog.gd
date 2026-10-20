class_name ObjectCatalog
extends RefCounted
## Mapa ID -> classe de objeto implementada. Mantido em sincronia com docs/qa/matriz-mecanicas.md.

const IMPLEMENTED := {
	0x25: "RingObj",
	0x26: "MonitorObj",
	0x40: "MotobugObj",
	0x1F: "CrabmeatObj",
	0x3B: "RockObj",
	0x11: "BridgeObj",
	0x2B: "ChopperObj",
	0x22: "BuzzBomberObj",
	0x23: "MissileObj",
	0x41: "SpringObj",
	0x36: "SpikesObj",
	0x0D: "SignpostObj",
	0x7D: "HiddenBonusObj",
	0x4B: "GiantRingObj",
	0x15: "SwingObj",
	0x42: "NewtronObj",
	0x18: "PlatformObj",
	0x44: "EdgeWallObj",
	0x3C: "SmashWallObj",
	0x17: "HelixObj",
	0x1C: "SceneryObj",
	0x1A: "LedgeObj",
	0x79: "LamppostObj",
}


static func make(id: int) -> GameObject:
	match id:
		0x25:
			return RingObj.new()
		0x26:
			return MonitorObj.new()
		0x40:
			return MotobugObj.new()
		0x1F:
			return CrabmeatObj.new()
		0x3B:
			return RockObj.new()
		0x11:
			return BridgeObj.new()
		0x2B:
			return ChopperObj.new()
		0x22:
			return BuzzBomberObj.new()
		0x41:
			return SpringObj.new()
		0x36:
			return SpikesObj.new()
		0x0D:
			return SignpostObj.new()
		0x7D:
			return HiddenBonusObj.new()
		0x4B:
			return GiantRingObj.new()
		0x15:
			return SwingObj.new()
		0x42:
			return NewtronObj.new()
		0x18:
			return PlatformObj.new()
		0x44:
			return EdgeWallObj.new()
		0x3C:
			return SmashWallObj.new()
		0x17:
			return HelixObj.new()
		0x1C:
			return SceneryObj.new()
		0x1A:
			return LedgeObj.new()
		0x79:
			return LamppostObj.new()
		_:
			return null
