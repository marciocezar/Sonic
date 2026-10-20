"""make test-parity — compara traces da simulação Godot com traces de referência medidos.

Para cada replay em tests/parity/replays com trace de referência em private/reference-captures:
  1. executa o replay na simulação Godot headless (mesma fase, estado inicial F0 medido);
  2. compara campo a campo, quadro a quadro, com tolerância ZERO nos campos determinísticos;
  3. grava reports/parity/<replay>.json e reports/parity/summary.md.
Sem trace de referência (ROM ausente), o replay é marcado NAO_AVALIADO — nunca "aprovado".
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

FIELDS_STRICT = ["x", "xs", "y", "ys", "xv", "yv", "gs", "ang", "st", "rt", "camx", "camy", "rings", "lives",
                 "score", "time", "look", "yr", "xr", "bgx", "bgy", "bg2x", "bgv", "hsb", "frm"]
FIELDS_SOFT = ["anim", "camys", "lock", "jmp", "inv", "lim", "rng"]


def compare(ref, got, fields):
    first = {}
    mism = {}
    n = min(len(ref), len(got))
    compared = 0
    stop = "fim do replay"
    for i in range(n):
        a, b = ref[i], got[i]
        if a.get("mode", 12) != 12:
            stop = f"quadro {a['f']}: referência recarregando a fase"
            break
        if a.get("anim") == 0x1C:
            stop = f"quadro {a['f']}: entrada no anel gigante (estágio especial não reconstruído)"
            break
        if a.get("partial"):
            continue
        compared += 1
        for f in fields:
            if f not in a or f not in b:
                continue
            if a[f] != b[f]:
                mism[f] = mism.get(f, 0) + 1
                if f not in first:
                    first[f] = {"frame": a["f"], "ref": a[f], "got": b[f], "input": a.get("in", "")}
    return first, mism, compared, stop


def main(argv):
    only = argv[0] if argv and argv[0] else None
    godot = wslib.godot_bin()
    rdir = wslib.safe_path("tests/parity/replays")
    cap = wslib.safe_path("private/reference-captures")
    packs = wslib.safe_path("private/extracted/levelpacks")
    out_dir = wslib.ensure_dir("reports", "parity")
    work = wslib.ensure_dir("work", "parity")
    results = []
    failed = 0
    if godot is not None:
        wslib.godot_refresh(quiet=False)
    for rp in sorted(rdir.glob("*.json")):
        name = rp.stem
        if only and name != only:
            continue
        meta = json.loads(rp.read_text())
        ref_path = cap / f"{name}.jsonl"
        pack = packs / meta["level"]
        if not ref_path.is_file() or not (pack / "level.json").is_file():
            results.append({"replay": name, "status": "NAO_AVALIADO", "reason": "trace de referência ou levelpack ausente (ROM necessária)"})
            continue
        if godot is None:
            results.append({"replay": name, "status": "BLOQUEADO", "reason": "Godot ausente (make bootstrap)"})
            failed += 1
            continue
        got_path = work / f"{name}.jsonl"
        rc = wslib.run([str(godot), "--headless", "--path", str(wslib.safe_path("game")), "--script",
                        "res://tests/replay_runner.gd", "--", f"--levelpack={pack}", f"--replay={rp}",
                        f"--init={ref_path}", f"--out={got_path}", f"--rom={wslib.find_rom()}"], timeout=600)
        if rc != 0 or not got_path.is_file():
            results.append({"replay": name, "status": "FALHA_EXECUCAO", "exit": rc})
            failed += 1
            continue
        ref = [json.loads(l) for l in ref_path.read_text().splitlines()]
        got = [json.loads(l) for l in got_path.read_text().splitlines()]
        first, mism, n, stop = compare(ref, got, FIELDS_STRICT)
        sfirst, smism, _, _ = compare(ref, got, FIELDS_SOFT)
        div = min((v["frame"] for v in first.values()), default=None)
        status = "IDENTICO" if not first and len(got) == len(ref) else "DIVERGE"
        frontier = meta.get("frontier")
        if status != "IDENTICO":
            if frontier:
                status = "DIVERGE_FRONTEIRA"  # replay de fronteira: documenta o que falta, não reprova a regressão
            else:
                failed += 1
        res = {"replay": name, "status": status, "frontier": frontier, "frames_compared": n, "stop": stop, "first_divergence_frame": div,
               "strict_first": first, "strict_mismatch_frames": mism, "soft_first": sfirst,
               "soft_mismatch_frames": smism, "tolerance": 0, "timestamp": wslib.now_iso()}
        wslib.write_json(out_dir / f"{name}.json", res)
        results.append(res)
        print(f"{name}: {status}" + (f" (1ª divergência no quadro {div}: {', '.join(sorted(first, key=lambda k: first[k]['frame'])[:5])})" if div is not None else ""))
    lines = ["# Paridade por replay (gerado por `make test-parity`)", "",
             f"Gerado em {wslib.now_iso()}. Tolerância 0 nos campos estritos: {', '.join(FIELDS_STRICT)}.", "",
             "| Replay | Status | Quadros comparados | Fim | 1ª divergência | Campos |", "|---|---|---|---|---|---|"]
    for r in results:
        fields = ", ".join(sorted(r.get("strict_first", {}), key=lambda k: r["strict_first"][k]["frame"])[:6])
        lines.append(f"| {r['replay']} | {r['status']} | {r.get('frames_compared', '-')} | {r.get('stop', '-')} | {r.get('first_divergence_frame', '-')} | {fields} |")
    wslib.write_text(out_dir / "summary.md", "\n".join(lines) + "\n")
    wslib.write_json(out_dir / "summary.json", {"timestamp": wslib.now_iso(), "results": [
        {k: v for k, v in r.items() if k in ("replay", "status", "frontier", "frames_compared", "stop", "first_divergence_frame", "reason")} for r in results]})
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
