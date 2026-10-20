"""Gera traces de referência por quadro executando a ROM no interpretador 68000 do projeto.

Uso (via Makefile): make reference-traces [REPLAY=nome]
Entrada: tests/parity/replays/*.json  (sequências de entrada versionáveis, sem dados da ROM)
Saída:   private/reference-captures/<nome>.jsonl  (estado por quadro; PRIVADO)
         reports/parity/reference-index.json      (hashes/contagens; versionável)

Convenção de quadros: F0 = primeiro quadro, após a carga, em que o modo de jogo é 0x0C.
A entrada do quadro N é aplicada ao pad durante o quadro N e lida no VBlank do fim do quadro N
(o jogo a usa na lógica do quadro N+1) — isto é o comportamento do hardware/jogo, não um ajuste.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402
from extract_data import LEVELS, boot_to_title  # noqa: E402
from mdmachine import MegaDrive, parse_buttons  # noqa: E402

PLAYER = 0xD000


def expand_inputs(spec):
    out = []
    for n, b in spec:
        out += [b] * int(n)
    return out


def rle(vals: list) -> list:
    out = []
    for v in vals:
        if out and out[-1][0] == v:
            out[-1][1] += 1
        else:
            out.append([v, 1])
    return out


def snapshot(md: MegaDrive, frame: int, inp: str) -> dict:
    p = PLAYER
    return {
        "f": frame, "in": inp, "mode": md.r8(0xF600),
        "x": md.r16(p + 0x08), "xs": md.r16(p + 0x0A), "y": md.r16(p + 0x0C), "ys": md.r16(p + 0x0E),
        "xv": md.s16(p + 0x10), "yv": md.s16(p + 0x12), "gs": md.s16(p + 0x14),
        "yr": md.r8(p + 0x16), "xr": md.r8(p + 0x17),
        "anim": md.r8(p + 0x1C), "frm": md.r8(p + 0x1A), "anf": md.r8(p + 0x1B), "ant": md.r8(p + 0x1E),
        "nan": md.r8(p + 0x1D), "rnd": md.r8(p + 0x01), "st": md.r8(p + 0x22), "rt": md.r8(p + 0x24),
        "ang": md.r8(p + 0x26), "lock": md.r16(p + 0x3E), "stick": md.r8(p + 0x38), "jmp": md.r8(p + 0x3C),
        "inv": md.r16(p + 0x30),
        "camx": md.r16(0xF700), "camxs": md.r16(0xF702), "camy": md.r16(0xF704), "camys": md.r16(0xF706),
        "rings": md.r16(0xFE20), "lives": md.r8(0xFE12), "score": md.r32(0xFE26),
        "time": md.r32(0xFE22), "zone": md.r8(0xFE10), "act": md.r8(0xFE11),
        "look": md.r16(0xF73E), "lim": [md.s16(0xF728 + 2 * i) for i in range(4)],
        "rng": md.r32(0xF636), "dle": md.r8(0xF742),
        # plano de fundo: posições ($F708/$F70C/$F710 16.16, $F714), vscroll ($F618) e rolagem por linha ($CC00)
        "bgx": md.r32(0xF708), "bgy": md.r32(0xF70C), "bg2x": md.r32(0xF710), "bg2y": md.r16(0xF714),
        "bgv": md.r16(0xF618), "hsb": rle([md.s16(0xCC00 + 4 * i + 2) for i in range(224)]),
        "objs": [[slot, md.r8(0xD000 + slot * 0x40), md.r16(0xD008 + slot * 0x40), md.r16(0xD00C + slot * 0x40),
                  md.r8(0xD024 + slot * 0x40), md.r8(0xD025 + slot * 0x40), md.r8(0xD022 + slot * 0x40),
                  md.r8(0xD028 + slot * 0x40)]
                 for slot in range(0x20, 0x80) if md.r8(0xD000 + slot * 0x40) != 0],
        # sprite de cada objeto: [slot, id, quadro, flags X/Y, palavra de arte, ponteiro de mapeamento]
        "ospr": [[slot, md.r8(0xD000 + slot * 0x40), md.r8(0xD01A + slot * 0x40), md.r8(0xD001 + slot * 0x40) & 3,
                  md.r16(0xD002 + slot * 0x40), md.r32(0xD004 + slot * 0x40) & 0xFFFFFF]
                 for slot in range(0x20, 0x80) if md.r8(0xD000 + slot * 0x40) != 0],
    }


COVERAGE: set = set()


def run_replay(rom: bytes, title_state, rp: dict) -> list:
    lid = rp["level"]
    zone, act = next((z, a) for (i, z, a) in LEVELS if i == lid)
    md = MegaDrive(rom)
    md.coverage = COVERAGE
    md.load_state(title_state)
    md.ram[0xFE10] = zone
    md.ram[0xFE11] = act
    for _ in range(5):
        md.step_frame(parse_buttons("S"))
    for _ in range(400):
        md.step_frame(0)
        if md.r8(0xF600) == 0x0C:
            break
    else:
        raise RuntimeError("fase não carregou")
    inputs = expand_inputs(rp["inputs"])
    total = int(rp.get("frames", len(inputs)))
    # "pokes": escritas de RAM roteirizadas (posição do jogador), aplicadas igualmente na simulação
    pokes = {int(f): v for f, v in rp.get("pokes", [])}
    rows = [snapshot(md, 0, "")]
    # estado global medido em F0: osciladores ($FE5E, 66 bytes), animação sincronizada ($FEC0..$FEC9), contador de quadros
    rows[0]["osc"] = md.ram[0xFE5E:0xFE5E + 66].hex()
    rows[0]["sync"] = md.ram[0xFEC0:0xFECA].hex()
    rows[0]["fc"] = md.r16(0xFE04)
    rows[0]["vb"] = md.r32(0xFE0C)
    for f in range(1, total + 1):
        b = inputs[f - 1] if f - 1 < len(inputs) else ""
        if f in pokes:
            pk = pokes[f]
            for k, off in (("x", 0x08), ("y", 0x0C)):
                if k in pk:
                    md.ram[0xD000 + off] = (pk[k] >> 8) & 0xFF
                    md.ram[0xD001 + off] = pk[k] & 0xFF
                    md.ram[0xD002 + off] = 0
                    md.ram[0xD003 + off] = 0
            for off in (0x10, 0x12, 0x14):
                md.ram[0xD000 + off] = 0
                md.ram[0xD001 + off] = 0
        md.step_frame(parse_buttons(b))
        row = snapshot(md, f, b)
        # partial: lógica deste quadro não terminou (estado intermediário); lag: VBlank sem leitura de entrada
        row["partial"] = 0 if md.prev_complete else 1
        row["lag"] = 1 if md.lag_vblank else 0
        rows.append(row)
    return rows


def main(argv):
    rom_path = wslib.require_rom()
    rom = rom_path.read_bytes()
    sha = wslib.sha256_file(rom_path)
    rdir = wslib.safe_path("tests/parity/replays")
    names = sorted(p.stem for p in rdir.glob("*.json"))
    if argv and argv[0]:
        names = [n for n in names if n == argv[0]]
        if not names:
            wslib.die(f"replay inexistente: {argv[0]}")
    title = boot_to_title(rom).save_state()
    out = wslib.ensure_dir("private", "reference-captures")
    idx_path = wslib.safe_path("reports/parity/reference-index.json")
    index = json.loads(idx_path.read_text()) if idx_path.is_file() else {}
    index.setdefault("replays", {})
    for n in names:
        rp = json.loads((rdir / f"{n}.json").read_text())
        rows = run_replay(rom, title, rp)
        text = "".join(json.dumps(r, separators=(",", ":")) + "\n" for r in rows)
        (out / f"{n}.jsonl").write_text(text)
        index["replays"][n] = {"frames": len(rows) - 1, "level": rp["level"],
                               "trace_sha256": hashlib.sha256(text.encode()).hexdigest(),
                               "replay_sha256": wslib.sha256_file(rdir / f"{n}.json"),
                               "generated": wslib.now_iso()}
        last = rows[-1]
        wslib.info(f"{n}: {len(rows)-1} quadros; final x={last['x']} y={last['y']} gs={last['gs']} rings={last['rings']}")
    cov = wslib.safe_path("private/extracted/coverage_pcs.txt")
    old = {int(l, 16) for l in cov.read_text().split()} if cov.is_file() else set()
    allpcs = old | {pc for pc in COVERAGE if pc < 0x80000}
    wslib.write_text(cov, "".join(f"{pc:06X}\n" for pc in sorted(allpcs)))
    wslib.info(f"cobertura dinâmica: {len(allpcs)} PCs (antes {len(old)})")
    index["rom_sha256"] = sha
    index["emulator"] = "tooling/mdmachine.py + tooling/m68k.py (interpretador próprio, não cycle-accurate)"
    wslib.write_json(idx_path, index)


if __name__ == "__main__":
    main(sys.argv[1:])
