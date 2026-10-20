"""Gera as fases PRÓPRIAS do projeto (conteúdo original, publicável).

Nada aqui vem da ROM: o terreno é um perfil matemático; mapas de altura, larguras e ângulos saem
dele, no formato neutro (schema 1). `make demo-level` regrava lab1.json e lab2.json.

Para pôr um objeto na Lab Zone 2, acrescente um item em `_lab2_objects` e rode `make demo-level`.
Cada item é (x, dy, id, sub): y = chão(x) − dy (y cresce para baixo). id com bit 0x80 lembra
o estado (TV quebrada, vilão derrotado). IDs que o jogo já executa: 0x25 anéis, 0x26 TV,
0x41 mola, 0x36 espinhos, 0x40 Motobug, 0x1F Crabmeat, 0x22 Buzz Bomber, 0x2B Chopper,
0x42 Newtron, 0x0D placa. Subtipo da TV: 2 vida, 3 tênis, 4 escudo, 5 invencível, 6 anéis.
Mola: 0 vermelha para cima, 2 amarela, 0x10 lateral, 0x20 para baixo.
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

W_CHUNKS = 28
H_CHUNKS = 8
BASE = 0x3A0  # altura base do chão (y)


def surface(x: float) -> float:
    """Perfil do terreno principal (y para baixo)."""
    segs = [
        (0, 900, lambda t: BASE),
        (900, 1700, lambda t: BASE - 48 * (1 - math.cos(2 * math.pi * (t - 900) / 800)) / 2),
        (1700, 2100, lambda t: BASE),
        (2100, 2500, lambda t: BASE - (t - 2100) * 0.40),
        (2500, 2900, lambda t: BASE - 160),
        (2900, 3300, lambda t: BASE - 160 + (t - 2900) * 0.40),
        (3300, 3500, lambda t: BASE),
        # vale (meio-tubo) com laterais íngremes
        (3500, 4100, lambda t: BASE + 120 * math.sin(math.pi * (t - 3500) / 600) ** 2),
        (4100, 4600, lambda t: BASE - 30 * math.sin(2 * math.pi * (t - 4100) / 500)),
        (4600, 5200, lambda t: BASE - 96 * (1 - math.cos(math.pi * (t - 4600) / 600)) / 2),
        (5200, 7168, lambda t: BASE - 96),
    ]
    for a, b, f in segs:
        if a <= x < b:
            return f(x)
    return BASE - 96


PLATFORMS = [  # (x0, x1, y) plataformas finas só-topo
    (1150, 1310, BASE - 120),
    (1400, 1560, BASE - 170),
    (3700, 3900, BASE - 40),
    (5600, 5760, BASE - 200),
]


def angle_byte(slope: float) -> int:
    return int(round(math.atan(slope) * 128 / math.pi)) & 0xFF


def _geometry(surf, platforms):
    width_px = W_CHUNKS * 256
    heights_tab = [[0] * 16, [16] * 16]
    angle_tab = [0, 0]
    shape_index = {tuple([0] * 16): 0, tuple([16] * 16): 1}
    blocks = [(0, 0)]  # (heightmap idx, solidity) -> índice de bloco; bloco 0 vazio
    block_index = {(0, 0): 0}
    cells = {}
    for cy in range(H_CHUNKS * 16):
        for cx in range(width_px // 16):
            x0, y0 = cx * 16, cy * 16
            hs = []
            for col in range(16):
                sy = surf(x0 + col + 0.5)
                fill = (y0 + 16) - sy
                hs.append(max(0, min(16, int(math.floor(fill + 0.5)))))
            solid = 0x6000
            if all(h == 0 for h in hs):
                for (a, b, py) in platforms:
                    if a <= x0 < b and y0 <= py < y0 + 16:
                        top = int(py - y0)
                        hs = [16 - top] * 16
                        solid = 0x2000
                        break
            if all(h == 0 for h in hs):
                continue
            flip = 0
            slope = (surf(x0 + 15.5) - surf(x0 + 0.5)) / 15.0
            if solid == 0x6000 and hs[0] > hs[15]:
                # formas mais altas à esquerda são guardadas espelhadas (bit 11), como no formato de referência
                hs = list(reversed(hs))
                flip = 0x800
                slope = -slope
            key = tuple(hs)
            if key not in shape_index:
                shape_index[key] = len(heights_tab)
                heights_tab.append(list(hs))
                angle_tab.append(0 if solid == 0x2000 else angle_byte(slope))
            hidx = shape_index[key]
            bkey = (hidx, solid)
            if bkey not in block_index:
                block_index[bkey] = len(blocks)
                blocks.append(bkey)
            cells[(cx, cy)] = block_index[bkey] | solid | flip
    if len(heights_tab) > 256:
        raise SystemExit(f"mapas de altura demais: {len(heights_tab)}")
    while len(heights_tab) < 256:
        heights_tab.append([0] * 16)
        angle_tab.append(0)
    # larguras = rotação dos mapas de altura (contagem por linha a partir da direita)
    widths_tab = []
    for hs in heights_tab:
        row_w = []
        for row in range(16):
            n = sum(1 for h in hs if h >= 16 - row)
            row_w.append(n)
        widths_tab.append(row_w)
    # chunks
    chunk_list = [[0] * 256]
    chunk_index = {tuple([0] * 256): 0}
    layout = [[0] * 0x40 for _ in range(8)]
    for ky in range(H_CHUNKS):
        for kx in range(W_CHUNKS):
            words = []
            for by in range(16):
                for bx in range(16):
                    words.append(cells.get((kx * 16 + bx, ky * 16 + by), 0))
            key = tuple(words)
            if key not in chunk_index:
                chunk_index[key] = len(chunk_list)
                chunk_list.append(words)
            layout[ky][kx] = chunk_index[key]
    if len(chunk_list) > 0x7F:
        raise SystemExit(f"chunks demais: {len(chunk_list)}")
    return {
        "width_px": width_px,
        "layout": layout,
        "chunks": chunk_list[1:],
        "blocks": blocks,
        "heights_tab": heights_tab,
        "widths_tab": widths_tab,
        "angle_tab": angle_tab,
    }


def _pack(meta: dict, surf, platforms, objects: list) -> dict:
    g = _geometry(surf, platforms)
    objects = sorted(objects, key=lambda o: o["x"])
    level = {
        "schema": 1, "id": meta["id"], "zone": 0x10, "act": meta["act"], "zone_name": meta["zone_name"],
        "license": "Conteúdo original do projeto sonic-megadrive (ver LICENSES.md)",
        "start": {"x": 80, "y": int(surf(80)) - 0x13},
        "limits": {"left": 0, "right": g["width_px"] - 320, "top": 0, "bottom": 0x300},
        "layout_fg": g["layout"], "layout_bg": [[0] * 0x40 for _ in range(8)],
        "chunks": g["chunks"], "blocks": [[0, 0, 0, 0] for _ in g["blocks"]],
        "collision_index": [b[0] for b in g["blocks"]],
        "loop_chunks": [0x7F, 0x7F], "roll_chunks": [0x7F, 0x7F], "water_level": None,
        "objects": [{"x": o["x"], "y": o["y"], "yraw": o["y"], "id": o["id"], "sub": o["sub"]} for o in objects],
        "collision": {"heights": [h for hs in g["heights_tab"] for h in hs],
                      "widths": [w for ws in g["widths_tab"] for w in ws], "angles": g["angle_tab"]},
        "theme": "lab",
    }
    return level


def _ring(surf, x, dy, n, spacing=0):
    return {"x": x, "y": int(surf(x)) - dy, "id": 0x25, "sub": ((spacing & 0xF) << 4) | (n - 1)}


def _at(surf, x, dy, oid, sub=0):
    return {"x": x, "y": int(surf(x)) - dy, "id": oid, "sub": sub}


def build():
    objects = []
    def ring_line(x, y, n, spacing=0):
        objects.append({"x": x, "y": y, "id": 0x25, "sub": ((spacing & 0xF) << 4) | (n - 1)})
    for x in range(300, 800, 120):
        ring_line(x, BASE - 40, 3)
    ring_line(1180, BASE - 150, 5)
    ring_line(1430, BASE - 200, 5)
    ring_line(2600, BASE - 200, 6)
    ring_line(3720, BASE - 70, 5)
    ring_line(4300, BASE - 70, 4)
    ring_line(5000, BASE - 160, 6)
    ring_line(5620, BASE - 230, 5)
    for i, (x, kind) in enumerate([(700, 6), (2700, 3), (4400, 4), (5900, 5), (6200, 2)]):
        objects.append({"x": x, "y": int(surface(x)) - 15, "id": 0x26 | 0x80, "sub": kind})
    return _pack({"id": "lab1", "act": 0, "zone_name": "Lab Zone"}, surface, PLATFORMS, objects)


def surface2(x: float) -> float:
    """Segundo ato: o mesmo tipo de perfil, com um vale no começo e um platô no fim."""
    segs = [
        (0, 800, lambda t: BASE),
        (800, 1500, lambda t: BASE - 64 * (1 - math.cos(2 * math.pi * (t - 800) / 700)) / 2),
        (1500, 1900, lambda t: BASE),
        (1900, 2300, lambda t: BASE - (t - 1900) * 0.45),
        (2300, 2800, lambda t: BASE - 180),
        (2800, 3200, lambda t: BASE - 180 + (t - 2800) * 0.45),
        (3200, 3600, lambda t: BASE),
        (3600, 4300, lambda t: BASE + 100 * math.sin(math.pi * (t - 3600) / 700) ** 2),
        (4300, 5000, lambda t: BASE - 40 * math.sin(2 * math.pi * (t - 4300) / 700)),
        (5000, 5600, lambda t: BASE - 80 * (1 - math.cos(math.pi * (t - 5000) / 600)) / 2),
        (5600, 7168, lambda t: BASE - 80),
    ]
    for a, b, f in segs:
        if a <= x < b:
            return f(x)
    return BASE - 80


PLATFORMS2 = [
    (1000, 1160, BASE - 130),
    (2500, 2680, BASE - 250),
    (4700, 4880, BASE - 140),
    (6000, 6200, BASE - 180),
]


def _lab2_objects():
    """Curso de teste. dy é a folga acima do chão. Ver o comentário no topo do arquivo."""
    s = surface2
    tv = 0x26 | 0x80
    out = [
        _ring(s, 260, 40, 4),
        _ring(s, 420, 40, 4),
        _at(s, 620, 16, tv, 6),
        _at(s, 900, 24, 0x40 | 0x80),
        _at(s, 1100, 16, 0x41),
        _ring(s, 1080, 150, 5),
        _at(s, 1400, 24, 0x1F | 0x80),
        _at(s, 1680, 96, 0x22 | 0x80),
        _at(s, 1750, 16, tv, 2),
        _at(s, 2100, 16, 0x41, 2),
        _at(s, 2400, 16, 0x36),
        _ring(s, 2550, 70, 5),
        _at(s, 2620, 16, 0x41, 0x20),
        _at(s, 3000, 24, 0x40 | 0x80),
        _at(s, 3300, 16, tv, 3),
        _at(s, 3900, 8, 0x2B | 0x80),
        _at(s, 4200, 24, 0x42 | 0x80, 0),
        _at(s, 4550, 16, 0x41, 0x10),
        _at(s, 4800, 16, tv, 4),
        _at(s, 5100, 24, 0x42 | 0x80, 1),
        _at(s, 5400, 24, 0x1F | 0x80),
        _at(s, 5750, 96, 0x22 | 0x80),
        _at(s, 5900, 16, tv, 5),
        _ring(s, 6100, 120, 6),
        _at(s, 6400, 24, 0x40 | 0x80),
        _at(s, 6700, 24, 0x0D | 0x80),
    ]
    return out


def build_lab2():
    return _pack({"id": "lab2", "act": 1, "zone_name": "Lab Zone"}, surface2, PLATFORMS2, _lab2_objects())


def main():
    for name, lvl in (("lab1", build()), ("lab2", build_lab2())):
        out = wslib.safe_path(f"game/data/levels/{name}.json")
        wslib.write_text(out, json.dumps(lvl, separators=(",", ":")) + "\n")
        wslib.info(f"fase própria gerada: {wslib.rel(out)} ({len(lvl['chunks'])} chunks, "
                   f"{len(lvl['collision_index'])} blocos, {len(lvl['objects'])} objetos)")


if __name__ == "__main__":
    main()
