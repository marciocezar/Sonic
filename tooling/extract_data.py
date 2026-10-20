"""make extract-data — extrai dados de fase da ROM do usuário (SAÍDA PRIVADA).

Técnica: o próprio código do jogo, executado no interpretador 68000 do projeto (mdmachine),
descomprime e carrega cada zona/ato; depois copiamos RAM/VRAM/CRAM e tabelas de ROM cujos
endereços foram observados dinamicamente (rastreamento de leituras por PC).

Saída: private/extracted/levelpacks/<id>/level.json (+ vram.bin, cram.json)
       private/extracted/collision.json
Nada disso pode ir para dist/ (verificado por `make check-no-rom-in-dist`).
O resumo sem dados protegidos vai para reports/analysis/extract-summary.json.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import evidence  # noqa: E402
import wslib  # noqa: E402
from mdmachine import MegaDrive, parse_buttons  # noqa: E402

# RAM (offsets em $FF0000) — hipóteses validadas por emulação (ver ledger EV-EXT-*)
RAM_CHUNKS, RAM_CHUNKS_LEN = 0x0000, 0xA400
RAM_LAYOUT = 0xA400
RAM_BLOCKS, RAM_BLOCKS_LEN = 0xB000, 0x1800
RAM_GAMEMODE = 0xF600
RAM_ZONE, RAM_ACT = 0xFE10, 0xFE11
RAM_COLLINDEX_PTR = 0xF796
RAM_OPL_PTR = 0xF770
RAM_LIMITS = 0xF728
RAM_LOOPCHUNKS = 0xF7AC
RAM_WATER = 0xF646
RAM_PLAYER = 0xD000

# ROM — endereços observados por rastreamento dinâmico de leituras (probe em GHZ1)
ROM_ANGLEMAP = 0x62900
ROM_HEIGHTS = 0x62A00
ROM_WIDTHS = 0x63A00

LEVELS = [
    ("ghz1", 0, 0), ("ghz2", 0, 1), ("ghz3", 0, 2),
    ("lz1", 1, 0), ("lz2", 1, 1), ("lz3", 1, 2), ("sbz3", 1, 3),
    ("mz1", 2, 0), ("mz2", 2, 1), ("mz3", 2, 2),
    ("slz1", 3, 0), ("slz2", 3, 1), ("slz3", 3, 2),
    ("syz1", 4, 0), ("syz2", 4, 1), ("syz3", 4, 2),
    ("sbz1", 5, 0), ("sbz2", 5, 1), ("fz", 5, 2),
]
ZONE_NAMES = {0: "Green Hill", 1: "Labyrinth", 2: "Marble", 3: "Star Light", 4: "Spring Yard", 5: "Scrap Brain"}


def boot_to_title(rom: bytes) -> MegaDrive:
    md = MegaDrive(rom)
    for _ in range(330):
        md.step_frame(0)
    for _ in range(5):
        md.step_frame(parse_buttons("S"))
    for _ in range(200):
        md.step_frame(0)
    if md.r8(RAM_GAMEMODE) != 0x04:
        wslib.die(f"tela de título não alcançada (modo {md.r8(RAM_GAMEMODE):02X})")
    return md


COVERAGE: set = set()


def load_level(rom: bytes, title_state, zone: int, act: int):
    md = MegaDrive(rom)
    md.coverage = COVERAGE
    md.load_state(title_state)
    md.ram[RAM_ZONE] = zone
    md.ram[RAM_ACT] = act
    md.watch_writes = {RAM_OPL_PTR: [], RAM_OPL_PTR + 2: []}
    for _ in range(5):
        md.step_frame(parse_buttons("S"))
    for _ in range(400):
        md.step_frame(0)
        if md.r8(RAM_GAMEMODE) == 0x0C:
            break
    else:
        return None, None
    start = {"x": md.r16(RAM_PLAYER + 8), "y": md.r16(RAM_PLAYER + 0xC)}
    for _ in range(60):
        md.step_frame(0)
    return md, start


def first_opl_pointer(md: MegaDrive):
    """Primeiro valor de ponteiro em ROM escrito em v_opl_data (ignora a limpeza de RAM com zeros)."""
    hi = md.watch_writes.get(RAM_OPL_PTR, [])
    lo = md.watch_writes.get(RAM_OPL_PTR + 2, [])
    for (fh, _, _, vh), (fl, _, _, vl) in zip(hi, lo):
        ptr = ((vh & 0xFFFF) << 16) | (vl & 0xFFFF)
        if 0x200 <= ptr < 0x80000:
            return ptr
    return None


def read_objects(rom: bytes, ptr: int):
    out = []
    p = ptr
    while p + 6 <= len(rom) and len(out) < 2000:
        x = (rom[p] << 8) | rom[p + 1]
        if x == 0xFFFF:
            break
        y = (rom[p + 2] << 8) | rom[p + 3]
        out.append({"x": x, "yraw": y, "y": y & 0x0FFF, "flags": y >> 12, "id": rom[p + 4], "sub": rom[p + 5]})
        p += 6
    return out


def cell_from_level(L, wx, wy):
    """Palavra de tile VDP para o pixel de mundo (wx, wy) do plano FG, a partir dos dados extraídos.

    Regras validadas contra a tabela de nomes do VDP: chunk N em (N-1)*0x200 (ID 0 = blocos 0),
    bits 0-9 = bloco, bit 11 = espelho X, bit 12 = espelho Y.
    """
    cid = L["layout_fg"][(wy >> 8) & 7][(wx >> 8) & 0x3F] & 0x7F
    bw = 0 if cid == 0 else L["chunks"][cid - 1][((wy >> 4) & 15) * 16 + ((wx >> 4) & 15)]
    blk = L["blocks"][bw & 0x3FF]
    tx, ty = (wx >> 3) & 1, (wy >> 3) & 1
    if bw & 0x800:
        tx ^= 1
    if bw & 0x1000:
        ty ^= 1
    return blk[ty * 2 + tx] ^ (bw & 0x1800)


def validate_nametable(md, L):
    camx, camy = md.r16(0xF700), md.r16(0xF704)
    base = (md.vdp.reg[2] & 0x38) << 10
    ok = tot = 0
    for cy in range(28):
        for cx in range(40):
            wx, wy = camx + cx * 8, camy + cy * 8
            o = base + (((wy >> 3) & 31) * 64 + ((wx >> 3) & 63)) * 2
            v = (md.vdp.vram[o] << 8) | md.vdp.vram[o + 1]
            tot += 1
            ok += v == cell_from_level(L, wx, wy)
    return ok, tot


def main():
    rom_path = wslib.require_rom()
    rom = rom_path.read_bytes()
    sha = wslib.sha256_file(rom_path)
    ev = evidence.Collector("EV-EXT", sha, "tooling/extract_data.py + mdmachine (interpretador 68000 próprio)")
    outdir = wslib.ensure_dir("private", "extracted", "levelpacks")

    # tabelas globais de colisão
    heights = [b - 256 if b > 127 else b for b in rom[ROM_HEIGHTS:ROM_HEIGHTS + 0x1000]]
    widths = [b - 256 if b > 127 else b for b in rom[ROM_WIDTHS:ROM_WIDTHS + 0x1000]]
    angles = list(rom[ROM_ANGLEMAP:ROM_ANGLEMAP + 0x100])
    # verificação: widths é a rotação de heights?
    rot_ok = 0
    for i in range(256):
        hm = heights[i * 16:(i + 1) * 16]
        calc = []
        for row in range(16):
            # largura = número de colunas cuja altura cobre a linha (contada a partir da base)
            n = 0
            for col in range(16):
                h = hm[col]
                if (h > 0 and h >= 16 - row) or (h < 0 and -h > row):
                    n += 1
            calc.append(n)
        if [abs(w) for w in widths[i * 16:(i + 1) * 16]] == calc:
            rot_ok += 1
    wslib.write_json(wslib.safe_path("private/extracted/collision.json"),
                     {"source_sha256": sha, "heights": heights, "widths": widths, "angles": angles})
    ev.add("colisao", f"ROM 0x{ROM_ANGLEMAP:06X}", "Mapa de ângulos (256 bytes) lido pelo código em PC 0x014A00",
           "CONFIRMADO_EMULACAO", "alta", "rastreamento de leituras de ROM por PC durante GHZ1")
    ev.add("colisao", f"ROM 0x{ROM_HEIGHTS:06X}", "Array de alturas 256x16 (4096 bytes) lido por PC 0x014A2E/0x014AD6",
           "CONFIRMADO_EMULACAO", "alta", "rastreamento de leituras de ROM por PC durante GHZ1")
    ev.add("colisao", f"ROM 0x{ROM_WIDTHS:06X}", f"Array de larguras (rotação das alturas): {rot_ok}/256 mapas conferem com a rotação calculada",
           "CONFIRMADO_BINARIO" if rot_ok > 200 else "INFERIDO", "media", "comparação algorítmica alturas x larguras")

    wslib.info("boot até a tela de título...")
    title = boot_to_title(rom).save_state()
    ev.add("fluxo", "RAM $FFF600", "Modo de jogo 0x00 (SEGA) -> 0x04 (título) após Start; 0x0C = fase",
           "CONFIRMADO_EMULACAO", "alta", "replay: 330 quadros, Start, 200 quadros")
    summary = []
    for lid, zone, act in LEVELS:
        md, start = load_level(rom, title, zone, act)
        if md is None:
            wslib.info(f"{lid}: não carregou")
            summary.append({"id": lid, "loaded": False})
            continue
        lay = md.ram[RAM_LAYOUT:RAM_LAYOUT + 0x400]
        fg = [list(lay[r * 0x80:r * 0x80 + 0x40]) for r in range(8)]
        bg = [list(lay[r * 0x80 + 0x40:r * 0x80 + 0x80]) for r in range(8)]
        maxid = max(b & 0x7F for row in fg + bg for b in row)
        chunks = []
        for c in range(RAM_CHUNKS_LEN // 0x200):
            base = RAM_CHUNKS + c * 0x200
            chunks.append([md.r16(base + i * 2) for i in range(256)])
        blocks = [[md.r16(RAM_BLOCKS + b * 8 + i * 2) for i in range(4)] for b in range(RAM_BLOCKS_LEN // 8)]
        nblocks = 1 + max((w & 0x3FF) for ch in chunks[:min(len(chunks), maxid + 1)] for w in ch)
        cptr = md.r32(RAM_COLLINDEX_PTR) & 0xFFFFFF
        collindex = list(rom[cptr:cptr + nblocks])
        optr = first_opl_pointer(md)
        objs = read_objects(rom, optr) if optr else []
        limits = {"left": md.s16(RAM_LIMITS), "right": md.s16(RAM_LIMITS + 2),
                  "top": md.s16(RAM_LIMITS + 4), "bottom": md.s16(RAM_LIMITS + 6)}
        level = {
            "schema": 1, "id": lid, "zone": zone, "act": act, "zone_name": ZONE_NAMES[zone],
            "source_sha256": sha, "start": start, "limits": limits,
            "layout_fg": fg, "layout_bg": bg, "max_chunk_id": maxid,
            "chunks": chunks, "blocks": blocks[:nblocks],
            "collision_index_rom": f"0x{cptr:06X}", "collision_index": collindex,
            "loop_chunks": [md.r8(RAM_LOOPCHUNKS), md.r8(RAM_LOOPCHUNKS + 1)],
            "roll_chunks": [md.r8(RAM_LOOPCHUNKS + 2), md.r8(RAM_LOOPCHUNKS + 3)],
            "water_level": md.r16(RAM_WATER) if zone == 1 or (zone == 5 and act == 1) else None,
            "objects_rom": f"0x{optr:06X}" if optr else None, "objects": objs,
            "cram": list(md.vdp.cram), "vdp_regs": list(md.vdp.reg),
        }
        ok, tot = validate_nametable(md, level)
        level["nametable_validation"] = {"match": ok, "total": tot}
        d = wslib.ensure_dir("private", "extracted", "levelpacks", lid)
        wslib.write_json(d / "level.json", level)
        (d / "vram.bin").write_bytes(bytes(md.vdp.vram))
        summary.append({"id": lid, "zone": zone, "act": act, "loaded": True, "start": start, "limits": limits,
                        "chunks": len(level["chunks"]), "blocks": nblocks, "nametable_match": f"{ok}/{tot}", "objects": len(objs),
                        "collindex_rom": level["collision_index_rom"], "objects_rom": level["objects_rom"]})
        wslib.info(f"{lid}: início={start} chunks={len(level['chunks'])} blocos={nblocks} objetos={len(objs)} plano A={ok}/{tot}")
        ev.add("formato", f"{lid} VRAM plano A", f"Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: {ok}/{tot} células",
               "CONFIRMADO_EMULACAO" if ok == tot else "INFERIDO", "alta" if ok == tot else "media",
               "comparação célula a célula da área visível 40x28")
        ev.add("fase", f"zona {zone} ato {act}",
               f"{lid}: carregada; início ({start['x']},{start['y']}); limites {limits}; {len(objs)} objetos em ROM {level['objects_rom']}; índice colisão {level['collision_index_rom']}",
               "CONFIRMADO_EMULACAO", "alta", "dump de RAM após modo 0x0C + ponteiro OPL capturado na 1ª escrita")
    cov_path = wslib.safe_path("private/extracted/coverage_pcs.txt")
    wslib.write_text(cov_path, "".join(f"{pc:06X}\n" for pc in sorted(COVERAGE) if pc < 0x80000))
    ev.add("cobertura", "0x000000-0x07FFFF",
           f"{len(COVERAGE)} endereços de instrução executados ao carregar as 19 fases (60 quadros cada)",
           "CONFIRMADO_EMULACAO", "alta", "conjunto de PCs do interpretador; usado para semear o Ghidra")
    wslib.write_json(wslib.safe_path("reports/analysis/extract-summary.json"),
                     {"timestamp": wslib.now_iso(), "rom_sha256": sha, "levels": summary,
                      "private_output": "private/extracted/levelpacks"})
    evidence.replace_source("extract_data", ev.rows)


if __name__ == "__main__":
    main()
