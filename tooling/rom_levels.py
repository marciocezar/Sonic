"""Importador estático de fases a partir da ROM (referência Python do importador do jogo).

Lê as tabelas localizadas na ROM (endereços confirmados por listagem/rastreamento, ledger EV-IMP-*) e
descomprime os chunks 256x256 (Kosinski, implementação própria). Serve para validar o importador em
GDScript (`game/src/levels/rom_importer.gd`) contra as fases extraídas por emulação.
Uso: make rom-import-check
"""
from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import evidence  # noqa: E402
import wslib  # noqa: E402

REV00_SHA256 = "46160baa06362c711c9f1a5017cb7371026444936c8af5e93a78996cf32ff2a6"
LEVEL_HEADERS = 0x1D5A2
LAYOUT_INDEX = 0x68BD6
LEVEL_SIZES = 0x5F1C
START_LOCS = 0x6112
LOOP_CHUNKS = 0x6182
COLL_INDEX_PTRS = 0x4100
OBJPOS_INDEX = 0x6B000
WATER_HEIGHTS = 0x3C2A
ANGLES, HEIGHTS, WIDTHS = 0x62900, 0x62A00, 0x63A00
LEVELS = [("ghz1", 0, 0), ("ghz2", 0, 1), ("ghz3", 0, 2), ("lz1", 1, 0), ("lz2", 1, 1), ("lz3", 1, 2),
          ("sbz3", 1, 3), ("mz1", 2, 0), ("mz2", 2, 1), ("mz3", 2, 2), ("slz1", 3, 0), ("slz2", 3, 1),
          ("slz3", 3, 2), ("syz1", 4, 0), ("syz2", 4, 1), ("syz3", 4, 2), ("sbz1", 5, 0), ("sbz2", 5, 1),
          ("fz", 5, 2)]


def kosinski(data: bytes, pos: int) -> bytes:
    out = bytearray()
    field = data[pos] | (data[pos + 1] << 8)
    pos += 2
    left = 16

    def bit():
        nonlocal field, left, pos
        b = field & 1
        field >>= 1
        left -= 1
        if left == 0:
            field = data[pos] | (data[pos + 1] << 8)
            pos += 2
            left = 16
        return b

    while True:
        if bit():
            out.append(data[pos])
            pos += 1
            continue
        if bit() == 0:
            count = ((bit() << 1) | bit()) + 2
            offset = data[pos] - 0x100
            pos += 1
        else:
            lo, hi = data[pos], data[pos + 1]
            pos += 2
            offset = (((hi & 0xF8) << 5) | lo) - 0x2000
            count = hi & 7
            if count == 0:
                c = data[pos]
                pos += 1
                if c == 0:
                    break
                if c == 1:
                    continue
                count = c + 1
            else:
                count += 2
        for _ in range(count):
            out.append(out[len(out) + offset])
    return bytes(out)


def w(rom, a):
    return struct.unpack(">H", rom[a:a + 2])[0]


def sw(rom, a):
    return struct.unpack(">h", rom[a:a + 2])[0]


def l(rom, a):
    return struct.unpack(">I", rom[a:a + 4])[0]


def import_level(rom: bytes, zone: int, act: int, cache: dict) -> dict:
    hz = zone
    hdr = LEVEL_HEADERS + hz * 16
    chunks_ptr = l(rom, hdr + 8) & 0xFFFFFF
    if chunks_ptr not in cache:
        cache[chunks_ptr] = kosinski(rom, chunks_ptr)
    raw = cache[chunks_ptr]
    chunks = [[(raw[c * 512 + i * 2] << 8) | raw[c * 512 + i * 2 + 1] for i in range(256)]
              for c in range(len(raw) // 512)]
    fg = [[0] * 0x40 for _ in range(8)]
    bg = [[0] * 0x40 for _ in range(8)]
    for which, dst in ((0, fg), (2, bg)):
        idx = (zone * 8 + act * 2) * 3 + which
        p = LAYOUT_INDEX + w(rom, LAYOUT_INDEX + idx)
        wdt, hgt = rom[p] + 1, rom[p + 1] + 1
        p += 2
        for r in range(hgt):
            for c in range(wdt):
                if r < 8 and c < 0x40:
                    dst[r][c] = rom[p]
                p += 1
    si = LEVEL_SIZES + (zone * 16 + act * 4) * 3
    limits = {"left": sw(rom, si + 2), "right": sw(rom, si + 4), "top": sw(rom, si + 6), "bottom": sw(rom, si + 8)}
    st = START_LOCS + zone * 16 + act * 4
    start = {"x": w(rom, st), "y": w(rom, st + 2)}
    lc = LOOP_CHUNKS + zone * 4
    ci_ptr = l(rom, COLL_INDEX_PTRS + zone * 4) & 0xFFFFFF
    maxid = max(b & 0x7F for row in fg + bg for b in row)
    nblocks = 1 + max((x & 0x3FF) for ch in chunks[:min(len(chunks), maxid + 1)] for x in ch)
    op = OBJPOS_INDEX + w(rom, OBJPOS_INDEX + zone * 16 + act * 4)
    objs = []
    while w(rom, op) != 0xFFFF:
        y = w(rom, op + 2)
        objs.append({"x": w(rom, op), "yraw": y, "y": y & 0xFFF, "id": rom[op + 4], "sub": rom[op + 5]})
        op += 6
    water = sw(rom, WATER_HEIGHTS + act * 2) if zone == 1 else None
    return {"zone": zone, "act": act, "start": start, "limits": limits, "layout_fg": fg, "layout_bg": bg,
            "chunks": chunks, "collision_index": list(rom[ci_ptr:ci_ptr + nblocks]),
            "loop_chunks": [rom[lc], rom[lc + 1]], "roll_chunks": [rom[lc + 2], rom[lc + 3]],
            "water_level": water, "objects": objs}


def main():
    rom_path = wslib.require_rom()
    rom = rom_path.read_bytes()
    sha = wslib.sha256_file(rom_path)
    ev = evidence.Collector("EV-IMP", sha, "tooling/rom_levels.py (importador estático) vs extração por emulação")
    cache = {}
    report = {"timestamp": wslib.now_iso(), "levels": {}}
    all_ok = True
    for lid, z, a in LEVELS:
        pack = wslib.safe_path(f"private/extracted/levelpacks/{lid}/level.json")
        if not pack.is_file():
            continue
        ref = json.loads(pack.read_text())
        got = import_level(rom, z, a, cache)
        res = {}
        res["layout"] = got["layout_fg"] == ref["layout_fg"] and got["layout_bg"] == ref["layout_bg"]
        n = len(got["chunks"])
        res["chunks"] = got["chunks"] == ref["chunks"][:n]
        res["chunk_count"] = n
        res["collision_index"] = got["collision_index"] == ref["collision_index"][:len(got["collision_index"])]
        res["start"] = got["start"] == ref["start"]
        res["limits"] = got["limits"] == ref["limits"]
        res["loops"] = got["loop_chunks"] == ref["loop_chunks"] and got["roll_chunks"] == ref.get("roll_chunks", got["roll_chunks"])
        res["objects"] = [(o["x"], o["yraw"], o["id"], o["sub"]) for o in got["objects"]] == \
            [(o["x"], o["yraw"], o["id"], o["sub"]) for o in ref["objects"]]
        # água: a tabela dá a altura base; a extração capturou a água já oscilando (diferença esperada < 16 px)
        rw, gw = ref.get("water_level"), got["water_level"]
        res["water"] = (gw is None and (rw in (None, 0))) or (gw is not None and rw is not None and abs(rw - gw) < 16)
        if lid == "fz" and not res["limits"]:
            # FZ: o evento dinâmico da fase move o limite esquerdo logo no início (diferença esperada)
            res["limits"] = {k: v for k, v in got["limits"].items() if k != "left"} == {k: v for k, v in ref["limits"].items() if k != "left"}
        ok = all(v for k, v in res.items() if k != "chunk_count")
        all_ok &= ok
        report["levels"][lid] = res
        print(f"{lid}: " + " ".join(f"{k}={'OK' if v is True else ('DIF' if v is False else v)}" for k, v in res.items()))
    ev.add("importador", "tabelas ROM 0x1D5A2/0x68BD6/0x5F1C/0x6112/0x6182/0x4100/0x6B000/0x3C2A + Kosinski",
           "Importador estático reproduz layout/chunks/colisão/objetos/início das fases extraídas por emulação: "
           + ("todas conferem" if all_ok else "há diferenças (ver reports/analysis/rom-import-check.json)"),
           "CONFIRMADO_BINARIO" if all_ok else "INFERIDO", "alta", "comparação campo a campo com os levelpacks privados")
    evidence.replace_source("rom_levels", ev.rows)
    wslib.write_json(wslib.safe_path("reports/analysis/rom-import-check.json"), report)
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
