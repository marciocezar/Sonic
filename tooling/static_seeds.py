"""Sementes estáticas para o Ghidra: destinos de tabelas de salto relativas ao PC.

Padrão do 68000 usado pelo jogo para despachar rotinas de objetos/modos:
    move.w (d8,PC,D0.w),D1   (0x323B + extensão)
    jmp    (d8,PC,D1.w)      (0x4EFB + extensão)
A tabela começa em (endereço da extensão + d8) e termina onde começa o primeiro destino.
Saída: lista de endereços (hex), um por linha.
"""
from __future__ import annotations

import struct


def jump_table_targets(rom: bytes) -> set:
    seeds = set()
    n = len(rom)
    for i in range(0x200, n - 8, 2):
        if rom[i:i + 2] != b"\x32\x3b" or rom[i + 4:i + 6] != b"\x4e\xfb":
            continue
        ext = struct.unpack(">H", rom[i + 2:i + 4])[0]
        d8 = ext & 0xFF
        d8 = d8 - 256 if d8 >= 128 else d8
        base = i + 2 + d8
        if not (0 <= base < n - 2):
            continue
        first = None
        p = base
        for _ in range(64):
            if first is not None and p >= first:
                break
            off = struct.unpack(">h", rom[p:p + 2])[0]
            t = base + off
            if not (0x200 <= t < n) or t & 1:
                break
            seeds.add(t)
            first = t if first is None else min(first, t)
            p += 2
    return seeds


def write_seed_file(rom: bytes, coverage_path, out_path) -> int:
    pcs = set()
    if coverage_path.is_file():
        for ln in coverage_path.read_text().split():
            try:
                pcs.add(int(ln, 16))
            except ValueError:
                pass
    st = jump_table_targets(rom)
    allp = sorted(pcs | st)
    out_path.write_text("\n".join(f"{a:06X}" for a in allp) + "\n")
    return len(st)
