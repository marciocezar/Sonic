"""make qa-record TARGET=<alvo> STATUS=<PASS|FAIL|BLOCKED|BUILT_NOT_TESTED> NOTES="..."

Registra o resultado de uma sessão de teste MANUAL/real (dispositivo, navegador) em
reports/build/status.json com timestamp e host. Use apenas após executar o teste de fato.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import godot_tasks  # noqa: E402
import wslib  # noqa: E402

VALID = {"PASS", "FAIL", "BLOCKED", "BUILT_NOT_TESTED", "NOT_STARTED"}

if __name__ == "__main__":
    if len(sys.argv) < 3 or sys.argv[2] not in VALID:
        wslib.die("uso: make qa-record TARGET=x STATUS=PASS|FAIL|BLOCKED|BUILT_NOT_TESTED NOTES=...")
    tgt, st = sys.argv[1], sys.argv[2]
    notes = " ".join(sys.argv[3:])
    prev = godot_tasks.load_status().get(tgt, {})
    godot_tasks.set_status(tgt, st, notes, "manual/qa-record", prev.get("artifacts", []))
    print(f"{tgt}: {st} registrado")
