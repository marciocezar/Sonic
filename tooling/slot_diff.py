"""make slot-diff REPLAY=x — 1º quadro em que a ocupação de slots (slot, id) difere da referência."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

name = sys.argv[1]
ref = [json.loads(l) for l in wslib.safe_path(f"private/reference-captures/{name}.jsonl").read_text().splitlines()]
got = [json.loads(l) for l in wslib.safe_path(f"work/parity/{name}.jsonl").read_text().splitlines()]
for i in range(min(len(ref), len(got))):
    a = {(o[0], o[1]) for o in ref[i]["objs"]}
    b = {(o[0], o[1]) for o in got[i]["objs"]}
    if a != b:
        print("quadro", i, "camx", ref[i]["camx"], "x", ref[i]["x"])
        print("  só REF:", sorted(a - b))
        print("  só GOT:", sorted(b - a))
        ra = {o[0]: o for o in ref[i]["objs"]}
        print("  REF detalhes:", [ra[s] for s, _ in sorted(a - b)])
        if i > 0:
            print("  REF anterior:", [o for o in ref[i - 1]["objs"] if (o[0], o[1]) in (a - b) or o[0] in {s for s, _ in b - a}])
        break
else:
    print("ocupação de slots idêntica")
