"""Gera a fase PRÓPRIA do projeto (conteúdo original, publicável): game/data/levels/lab1.json.

Nada aqui vem da ROM: o terreno é um perfil matemático desenhado para o projeto; mapas de altura,
larguras e ângulos são calculados a partir dele, no mesmo formato neutro (schema 1) que o motor usa.
Uso: make demo-level
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


def build():
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
                sy = surface(x0 + col + 0.5)
                fill = (y0 + 16) - sy
                hs.append(max(0, min(16, int(math.floor(fill + 0.5)))))
            solid = 0x6000
            if all(h == 0 for h in hs):
                for (a, b, py) in PLATFORMS:
                    if a <= x0 < b and y0 <= py < y0 + 16:
                        top = int(py - y0)
                        hs = [16 - top] * 16
                        solid = 0x2000
                        break
            if all(h == 0 for h in hs):
                continue
            flip = 0
            slope = (surface(x0 + 15.5) - surface(x0 + 0.5)) / 15.0
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
    objects.sort(key=lambda o: o["x"])
    level = {
        "schema": 1, "id": "lab1", "zone": 0x10, "act": 0, "zone_name": "Lab Zone",
        "license": "Conteúdo original do projeto sonic-megadrive (ver LICENSES.md)",
        "start": {"x": 80, "y": int(surface(80)) - 0x13},
        "limits": {"left": 0, "right": width_px - 320, "top": 0, "bottom": 0x300},
        "layout_fg": layout, "layout_bg": [[0] * 0x40 for _ in range(8)],
        "chunks": chunk_list[1:], "blocks": [[0, 0, 0, 0] for _ in blocks],
        "collision_index": [b[0] for b in blocks],
        "loop_chunks": [0x7F, 0x7F], "roll_chunks": [0x7F, 0x7F], "water_level": None,
        "objects": [{"x": o["x"], "y": o["y"], "yraw": o["y"], "id": o["id"], "sub": o["sub"]} for o in objects],
        "collision": {"heights": [h for hs in heights_tab for h in hs],
                      "widths": [w for ws in widths_tab for w in ws], "angles": angle_tab},
        "theme": "lab",
    }
    # chunk 0 implícito (vazio): o formato guarda chunks a partir do ID 1
    return level


def main():
    lvl = build()
    out = wslib.safe_path("game/data/levels/lab1.json")
    wslib.write_text(out, json.dumps(lvl, separators=(",", ":")) + "\n")
    wslib.info(f"fase própria gerada: {wslib.rel(out)} ({len(lvl['chunks'])} chunks, "
               f"{len(lvl['collision_index'])} blocos, {len(lvl['objects'])} objetos)")


if __name__ == "__main__":
    main()
