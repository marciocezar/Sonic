"""Importação de assets gráficos da ROM (referência Python do importador do jogo).

Descompressores próprios Nemesis (padrões 8x8) e Enigma (mapeamentos), validados contra a VRAM e os blocos 16x16
capturados por emulação (`private/extracted/levelpacks/*`). Uso: make rom-assets-check
"""
from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import evidence  # noqa: E402
import rom_levels  # noqa: E402
import wslib  # noqa: E402

LEVEL_HEADERS = 0x1D5A2
PLC_TABLE = 0x1D612
PAL_TABLE = 0x2168
PLC_COMMON = (0, 1, 16)


class BitReader:
    def __init__(self, data: bytes, pos: int):
        self.d, self.p, self.bit = data, pos, 0

    def read(self, n: int) -> int:
        v = 0
        for _ in range(n):
            v = (v << 1) | ((self.d[self.p] >> (7 - self.bit)) & 1)
            self.bit += 1
            if self.bit == 8:
                self.bit = 0
                self.p += 1
        return v


def nemesis(data: bytes, pos: int) -> bytes:
    hdr = struct.unpack(">H", data[pos:pos + 2])[0]
    xor_mode = bool(hdr & 0x8000)
    tiles = hdr & 0x7FFF
    p = pos + 2
    table = {}
    nib = 0
    b = data[p]
    p += 1
    while b != 0xFF:
        if b & 0x80:
            nib = b & 0x0F
            b = data[p]
            p += 1
            continue
        count = ((b >> 4) & 7) + 1
        length = b & 0x0F
        code = data[p]
        p += 1
        table[(length, code)] = (nib, count)
        b = data[p]
        p += 1
    br = BitReader(data, p)
    out = bytearray()
    rows = tiles * 8
    row = 0
    nibs = 0
    prev = 0
    total = 0
    while total < rows:
        code, length = 0, 0
        while True:
            code = (code << 1) | br.read(1)
            length += 1
            if length == 6 and code == 0x3F:
                count = br.read(3) + 1
                val = br.read(4)
                break
            if (length, code) in table:
                val, count = table[(length, code)]
                break
            if length > 8:
                raise ValueError(f"código Nemesis inválido em 0x{pos:X}")
        for _ in range(count):
            row = (row << 4) | val
            nibs += 1
            if nibs == 8:
                if xor_mode:
                    row ^= prev
                    prev = row
                out += struct.pack(">I", row & 0xFFFFFFFF)
                row, nibs = 0, 0
                total += 1
                if total >= rows:
                    break
    return bytes(out)


def enigma(data: bytes, pos: int, base: int = 0) -> list:
    n_bits = data[pos]
    mask = data[pos + 1]
    inc = (struct.unpack(">H", data[pos + 2:pos + 4])[0] + base) & 0xFFFF
    common = (struct.unpack(">H", data[pos + 4:pos + 6])[0] + base) & 0xFFFF
    br = BitReader(data, pos + 6)
    out = []

    def inline():
        v = 0
        for bit, flag in ((4, 0x8000), (3, 0x4000), (2, 0x2000), (1, 0x1000), (0, 0x0800)):
            if mask & (1 << bit) and br.read(1):
                v |= flag
        return (v | br.read(n_bits)) + base & 0xFFFF

    while True:
        if br.read(1) == 0:
            if br.read(1) == 0:
                c = br.read(4) + 1
                for _ in range(c):
                    out.append(inc)
                    inc = (inc + 1) & 0xFFFF
            else:
                c = br.read(4) + 1
                out += [common] * c
        else:
            mode = br.read(2)
            cnt = br.read(4)
            if mode == 3 and cnt == 0xF:
                break
            c = cnt + 1
            if mode == 0:
                out += [inline()] * c
            elif mode == 1:
                v = inline()
                for _ in range(c):
                    out.append(v)
                    v = (v + 1) & 0xFFFF
            elif mode == 2:
                v = inline()
                for _ in range(c):
                    out.append(v)
                    v = (v - 1) & 0xFFFF
            else:
                for _ in range(c):
                    out.append(inline())
    return out


def level_header(rom: bytes, zone: int) -> dict:
    h = LEVEL_HEADERS + zone * 16
    l0, l1, l2 = (struct.unpack(">I", rom[h + i:h + i + 4])[0] for i in (0, 4, 8))
    return {"plc1": l0 >> 24, "art": l0 & 0xFFFFFF, "plc2": l1 >> 24, "blocks": l1 & 0xFFFFFF,
            "chunks": l2 & 0xFFFFFF, "music": rom[h + 13], "pal": rom[h + 14], "pal2": rom[h + 15]}


def plc(rom: bytes, i: int) -> list:
    s = PLC_TABLE + struct.unpack(">H", rom[PLC_TABLE + 2 * i:PLC_TABLE + 2 * i + 2])[0]
    c = struct.unpack(">H", rom[s:s + 2])[0]
    return [struct.unpack(">IH", rom[s + 2 + 6 * k:s + 8 + 6 * k]) for k in range(c + 1)]


def level_vram(rom: bytes, zone: int) -> bytes:
    hd = level_header(rom, zone)
    vr = bytearray(0x10000)
    for i in (PLC_COMMON[0], PLC_COMMON[1], hd["plc1"], hd["plc2"], PLC_COMMON[2]):
        for ptr, dst in plc(rom, i):
            d = nemesis(rom, ptr)
            vr[dst:dst + len(d)] = d[:0x10000 - dst]
    return bytes(vr)


def palette(rom: bytes, pid: int) -> tuple:
    e = PAL_TABLE + pid * 8
    src, dst, cnt = struct.unpack(">IHH", rom[e:e + 8])
    n = (cnt + 1) * 2
    return (dst - 0xFB00) // 2, [struct.unpack(">H", rom[src + 2 * k:src + 2 * k + 2])[0] for k in range(n)]


def main() -> int:
    rom = wslib.require_rom().read_bytes()
    sha = wslib.sha256_file(wslib.require_rom())
    ev = evidence.Collector("EV-ART", sha, "tooling/rom_assets.py (Nemesis/Enigma próprios) vs VRAM capturada")
    report = {"timestamp": wslib.now_iso(), "zones": {}}
    all_ok = True
    seen = set()
    for lid, z, _a in rom_levels.LEVELS:
        hz = 1 if lid == "sbz3" else z
        if hz in seen:
            continue
        pack = wslib.safe_path(f"private/extracted/levelpacks/{lid}")
        if not (pack / "level.json").is_file():
            continue
        seen.add(hz)
        ref = json.loads((pack / "level.json").read_text())
        vram = (pack / "vram.bin").read_bytes()
        hd = level_header(rom, hz)
        vr = level_vram(rom, hz)
        blocks = enigma(rom, hd["blocks"])
        ref_blocks = [w for b in ref["blocks"] for w in b]
        # só padrões (0x0000-0xBFFF); diferenças restantes = tiles animados e arte dinâmica do Sonic (instante capturado)
        n = 0xC000 // 32
        same = sum(1 for t in range(n) if vr[t * 32:t * 32 + 32] == vram[t * 32:t * 32 + 32])
        off, sp = palette(rom, 3)
        res = {"padroes": n, "padroes_iguais_vram": same, "paleta_sonic_ok": sp == ref["cram"][off:off + len(sp)],
               "blocks": len(blocks) // 4, "blocks_ok": blocks[:len(ref_blocks)] == ref_blocks}
        ok = res["blocks_ok"] and res["paleta_sonic_ok"] and same >= 1380
        all_ok &= ok
        report["zones"][lid[:-1] if lid[-1].isdigit() else lid] = {**res, **{k: hex(v) for k, v in hd.items()}}
        print(f"zona {hz} ({lid}): padrões {same}/{n} = VRAM; paleta Sonic {res['paleta_sonic_ok']}; blocos {res['blocks']} "
              f"{'OK' if res['blocks_ok'] else 'DIF'}; música 0x{hd['music']:02X} paleta {hd['pal']}")
    ev.add("assets-fase", "cabeçalho 0x1D5A2 (+0 PLC1/arte, +4 PLC2/blocos Enigma, +8 chunks, +13 música, +14 paleta); PLC 0x1D612; paletas 0x2168",
           "Arte e blocos 16x16 decodificados da ROM conferem com VRAM/RAM capturadas: "
           + ("sim" if all_ok else "há diferenças"), "CONFIRMADO_BINARIO" if all_ok else "INFERIDO", "alta",
           "comparação com levelpacks privados (make rom-assets-check)")
    evidence.replace_source("rom_assets", ev.rows)
    wslib.write_json(wslib.safe_path("reports/analysis/rom-assets-check.json"), report)
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
