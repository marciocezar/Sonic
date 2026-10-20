class_name Fx
extends RefCounted
## Utilitários de aritmética inteira com largura fixa (8/16/32 bits), para reproduzir
## estouros e sinais do processador de referência de forma determinística.


static func s8(v: int) -> int:
	v &= 0xFF
	return v - 0x100 if v >= 0x80 else v


static func s16(v: int) -> int:
	v &= 0xFFFF
	return v - 0x10000 if v >= 0x8000 else v


static func s32(v: int) -> int:
	v &= 0xFFFFFFFF
	return v - 0x100000000 if v >= 0x80000000 else v


static func u8(v: int) -> int:
	return v & 0xFF


static func u16(v: int) -> int:
	return v & 0xFFFF


## Deslocamento aritmético à direita (equivalente a asr): GDScript >> já é aritmético para negativos.
static func asr(v: int, n: int) -> int:
	return v >> n


## Multiplicação 16x16 com sinal seguida de asr 8 (padrão "muls + asr.l #8").
static func mul_asr8(a: int, b: int) -> int:
	return (s16(a) * s16(b)) >> 8
