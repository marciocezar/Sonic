"""Extrai da ROM os roteiros de animação de cada objeto (tabelas usadas com AnimateSprite 0xA718).

Saída: reports/analysis/obj-anims.json {id: {"tabela": addr, "roteiros": [[dur, quadros..., cmd(, arg)], ...]}}
Comandos convertidos para o formato do ObjAnim: 0xFF=-1, 0xFE=-2, 0xFD=-3, 0xFC=-4, 0xFB=-5, 0xFA=-6.
"""
from __future__ import annotations

import re
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

OBJ_TABLE = 0xD382
ANIMATE_SPRITE = 0xA718
CMDS = {0xFF: -1, 0xFE: -2, 0xFD: -3, 0xFC: -4, 0xFB: -5, 0xFA: -6}


def parse_script(rom: bytes, a: int) -> list:
    out = [rom[a]]
    p = a + 1
    for _ in range(64):
        v = rom[p]
        if v in CMDS:
            out.append(CMDS[v])
            if v in (0xFE, 0xFD):
                out.append(rom[p + 1])
            break
        out.append(v)
        p += 1
    return out


def parse_table(rom: bytes, t: int) -> list:
    offs = []
    first = struct.unpack(">H", rom[t:t + 2])[0]
    n = max(1, min(first // 2, 32))
    for i in range(n):
        o = struct.unpack(">H", rom[t + 2 * i:t + 2 * i + 2])[0]
        offs.append(o)
    return [parse_script(rom, t + o) for o in offs]


def main() -> int:
    rom = wslib.require_rom().read_bytes()
    lines = wslib.safe_path("private/extracted/ghidra/ghidra-listing.txt").read_text().splitlines()
    addr_line = {}
    for i, ln in enumerate(lines):
        m = re.match(r"([0-9A-F]{6})\s", ln)
        if m:
            addr_line[int(m.group(1), 16)] = i
    starts = sorted(set(struct.unpack(">I", rom[OBJ_TABLE + 4 * i:OBJ_TABLE + 4 * i + 4])[0] for i in range(0x8C)))
    out = {}
    for oid in range(1, 0x8D):
        p = struct.unpack(">I", rom[OBJ_TABLE + 4 * (oid - 1):OBJ_TABLE + 4 * oid])[0]
        end = min([s for s in starts if s > p] + [p + 0x1000])
        tables = []
        for a in sorted(k for k in addr_line if p <= k < end):
            ln = lines[addr_line[a]]
            m = re.search(r"lea \((0x[0-9a-f]+)\)\.l,A1", ln)
            if not m:
                continue
            for j in range(1, 4):
                nxt = lines[addr_line[a] + j] if addr_line[a] + j < len(lines) else ""
                if re.search(r"(jsr|bsr\.w|jmp) 0x0000a718", nxt):
                    tables.append(int(m.group(1), 16))
                    break
        if tables:
            out[f"0x{oid:02X}"] = [{"tabela": hex(t), "roteiros": parse_table(rom, t)} for t in dict.fromkeys(tables)]
    wslib.write_json(wslib.safe_path("reports/analysis/obj-anims.json"), out)
    for k, v in out.items():
        print(k, [(t["tabela"], t["roteiros"]) for t in v])
    return 0


if __name__ == "__main__":
    sys.exit(main())
