"""make bot-replay LEVEL=ghz1 FRAMES=3000 — gera um replay por um 'bot' simples executado na REFERÊNCIA.

O bot só decide entradas (segurar direita; saltar quando parado; recuar quando preso) lendo a RAM da
referência. O replay resultante (somente entradas, sem dados da ROM) vai para tests/parity/replays/<fase>_bot.json.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402
from extract_data import LEVELS, boot_to_title  # noqa: E402
from mdmachine import MegaDrive, parse_buttons  # noqa: E402


def apply_poke(md, pk):
    for k, off in (("x", 0x08), ("y", 0x0C)):
        if k in pk:
            md.ram[0xD000 + off] = (pk[k] >> 8) & 0xFF
            md.ram[0xD001 + off] = pk[k] & 0xFF
            md.ram[0xD002 + off] = 0
            md.ram[0xD003 + off] = 0
    for off in (0x10, 0x12, 0x14):
        md.ram[0xD000 + off] = 0
        md.ram[0xD001 + off] = 0


def run_bot(rom, title, zone, act, frames, period, phase, pokes=None):
    md = MegaDrive(rom)
    md.load_state(title)
    md.ram[0xFE10], md.ram[0xFE11] = zone, act
    for _ in range(5):
        md.step_frame(parse_buttons("S"))
    while md.r8(0xF600) != 0x0C:
        md.step_frame(0)
    seq = []
    best_x, stall, plan, retries = 0, 0, [], 0
    for f in range(frames):
        x = md.r16(0xD008)
        rt = md.r8(0xD024)
        if rt >= 6:  # morreu: para
            break
        if x > best_x + 2:
            best_x, stall = x, 0
        if md.r8(0xF600) != 0x0C or md.r8(0xFE11) != act or md.r8(0xFE10) != zone:
            break
        else:
            stall += 1
        if not plan:
            if stall > 240:
                # recua bastante para ganhar velocidade (loops/rampas íngremes) e tenta de novo
                back = 60 + 40 * (retries % 4)
                plan = ["L"] * back + ["R"] * (back + 40) + ["RC"] * 20
                retries += 1
                stall = 0
            elif stall > 25:
                plan = ["RC"] * 22 + ["R"] * 10
            elif (f + phase) % period == 0:
                plan = ["RC"] * 18 + ["R"] * 6  # salto periódico: rolando destrói inimigos
            else:
                plan = ["R"]
        b = plan.pop(0)
        seq.append(b)
        if pokes and (len(seq)) in pokes:
            apply_poke(md, pokes[len(seq)])
            best_x = 0
        md.step_frame(parse_buttons(b))
    progress = md.r16(0xD008) if md.r8(0xD024) < 6 else best_x
    finished = md.r8(0xF600) != 0x0C or md.r8(0xFE11) != act
    return seq, progress, finished, md


def main(argv):
    lid = argv[0] if argv else "ghz1"
    frames = int(argv[1]) if len(argv) > 1 else 3000
    rom = wslib.require_rom().read_bytes()
    zone, act = next((z, a) for (i, z, a) in LEVELS if i == lid)
    title = boot_to_title(rom).save_state()
    pokes = {}
    name_suffix = "bot"
    if len(argv) > 2 and argv[2]:
        f, px, py = argv[2].split(":")
        pokes = {int(f): {"x": int(px), "y": int(py)}}
        name_suffix = argv[3] if len(argv) > 3 and argv[3] else "boss"
    best = None
    for period, phase in [(70, 0), (55, 10), (85, 20), (45, 5), (100, 30), (62, 40)]:
        seq, progress, finished, md = run_bot(rom, title, zone, act, frames, period, phase, pokes)
        wslib.info(f"  tentativa período={period} fase={phase}: x={progress} quadros={len(seq)} fim={finished}")
        key = (finished, progress)
        if best is None or key > best[0]:
            best = (key, seq, md, period, phase)
        if finished:
            break
    (_, seq, md, period, phase) = best
    segs = []
    for b in seq:
        if segs and segs[-1][1] == b:
            segs[-1][0] += 1
        else:
            segs.append([1, b])
    name = f"{lid}_{name_suffix}"
    out = {"name": name, "level": lid, "pokes": [[f, v] for f, v in pokes.items()],
           "description": f"Gerado por bot na referência (período {period}, fase {phase}; {len(seq)} quadros; x final {md.r16(0xD008)}).",
           "inputs": segs, "frames": len(seq)}
    wslib.write_text(wslib.safe_path(f"tests/parity/replays/{name}.json"), json.dumps(out) + "\n")
    wslib.info(f"{name}: {len(seq)} quadros, x final {md.r16(0xD008)}, anéis {md.r16(0xFE20)}, vidas {md.r8(0xFE12)}, rotina {md.r8(0xD024)}")


if __name__ == "__main__":
    main(sys.argv[1:])
