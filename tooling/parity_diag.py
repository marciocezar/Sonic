"""make parity-diag REPLAY=x — contexto da 1ª divergência (diagnóstico local; usa traces privados)."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

name = sys.argv[1]
res = json.loads(wslib.safe_path(f"reports/parity/{name}.json").read_text())
f0 = res.get("first_divergence_frame")
if f0 is None:
    print("sem divergência")
    sys.exit(0)
ref = [json.loads(l) for l in wslib.safe_path(f"private/reference-captures/{name}.jsonl").read_text().splitlines()]
got = [json.loads(l) for l in wslib.safe_path(f"work/parity/{name}.jsonl").read_text().splitlines()]
keys = ["x", "y", "xv", "yv", "gs", "ang", "st", "rt", "anim", "rings", "score", "camx", "camy"]
for i in range(max(0, f0 - 4), min(len(ref), f0 + 3)):
    a, b = ref[i], got[i]
    print(i, a.get("in", ""), "REF", [a[k] for k in keys])
    print(" " * len(str(i)), "    GOT", [b[k] for k in keys])
skip = {0x25}
print("REF objs", [o for o in ref[f0 - 1]["objs"] if o[1] not in skip])
print("GOT objs", [o for o in got[f0 - 1]["objs"] if o[1] not in skip])
