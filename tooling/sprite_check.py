"""make sprite-check — confere o sprite de cada objeto (quadro, espelhamento, arte, mapeamento) contra a referência.

Usa os traces de paridade (private/reference-captures vs work/parity) nos quadros em que os slots coincidem.
Relata, por ID de objeto, quantas amostras divergem em cada campo e o par (referência, simulação) mais frequente.
"""
from __future__ import annotations

import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

FIELDS = ["quadro", "flags", "arte", "mapa"]


def main() -> int:
    stats = defaultdict(lambda: {"amostras": 0, **{f: Counter() for f in FIELDS}})
    for got_path in sorted(wslib.safe_path("work/parity").glob("*.jsonl")):
        ref_path = wslib.safe_path(f"private/reference-captures/{got_path.name}")
        if not ref_path.is_file():
            continue
        ref = [json.loads(line) for line in ref_path.open()]
        got = [json.loads(line) for line in got_path.open()]
        for a, b in zip(ref, got):
            if "ospr" not in a or "ospr" not in b or a.get("partial"):
                continue
            gb = {e[0]: e for e in b["ospr"]}
            for e in a["ospr"]:
                g = gb.get(e[0])
                if g is None or g[1] != e[1] or e[5] == 0 and e[4] == 0 and g[5] != 0:
                    # objeto ainda não inicializado no original (ponteiro 0 no quadro em que foi carregado)
                    continue
                st = stats[e[1]]
                st["amostras"] += 1
                for i, f in enumerate(FIELDS):
                    if e[2 + i] != g[2 + i]:
                        st[f][(hex(e[2 + i]), hex(g[2 + i]) if g[2 + i] >= 0 else "-")] += 1
    rows = []
    bad = 0
    for oid in sorted(stats):
        st = stats[oid]
        errs = {f: sum(st[f].values()) for f in FIELDS}
        ok = not any(errs.values())
        bad += 0 if ok else 1
        top = {f: st[f].most_common(1)[0] for f in FIELDS if st[f]}
        rows.append({"id": hex(oid), "amostras": st["amostras"], "ok": ok, "erros": errs,
                     "exemplo": {f: [list(k), n] for f, (k, n) in top.items()}})
        print(f"0x{oid:02X}: {'OK ' if ok else 'DIF'} amostras={st['amostras']} " +
              " ".join(f"{f}={errs[f]}" for f in FIELDS) + (f"  ex={top}" if not ok else ""))
    wslib.write_json(wslib.safe_path("reports/parity/sprite-check.json"), {"timestamp": wslib.now_iso(), "objetos": rows})
    print(f"objetos com sprite divergente: {bad}/{len(rows)}")
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
