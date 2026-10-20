"""Ledger de evidências (docs/reverse-engineering/04-evidence-ledger.csv).

Cada conclusão tem: evidence_id, categoria, local (offset/endereço/frame), técnica/ferramenta,
sha256 da referência, hipótese, status, confiança, verificação, timestamp.
Status permitidos: CONFIRMADO_BINARIO, CONFIRMADO_EMULACAO, INFERIDO, DESCONHECIDO, BLOQUEADO.
O ledger é regenerado de forma idempotente pelos scripts de análise: cada script
substitui somente as linhas cujo `source` é ele mesmo.
"""
from __future__ import annotations

import csv
import io
from pathlib import Path
from typing import Dict, List

import wslib

LEDGER = "docs/reverse-engineering/04-evidence-ledger.csv"
FIELDS = ["evidence_id", "category", "location", "technique", "ref_sha256", "hypothesis",
          "status", "confidence", "verification", "timestamp", "source"]
STATUSES = {"CONFIRMADO_BINARIO", "CONFIRMADO_EMULACAO", "INFERIDO", "DESCONHECIDO", "BLOQUEADO"}


def load() -> List[Dict[str, str]]:
    p = wslib.safe_path(LEDGER)
    if not p.is_file():
        return []
    with open(p, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def replace_source(source: str, rows: List[Dict[str, str]]) -> None:
    for r in rows:
        if r["status"] not in STATUSES:
            raise ValueError(f"status inválido {r['status']} em {r['evidence_id']}")
        r["source"] = source
        r.setdefault("timestamp", wslib.now_iso())
    keep = [r for r in load() if r.get("source") != source]
    allrows = keep + rows
    allrows.sort(key=lambda r: r["evidence_id"])
    ids = [r["evidence_id"] for r in allrows]
    dup = {i for i in ids if ids.count(i) > 1}
    if dup:
        raise ValueError(f"evidence_id duplicado: {sorted(dup)}")
    buf = io.StringIO()
    w = csv.DictWriter(buf, fieldnames=FIELDS, lineterminator="\n")
    w.writeheader()
    for r in allrows:
        w.writerow({k: r.get(k, "") for k in FIELDS})
    wslib.write_text(wslib.safe_path(LEDGER), buf.getvalue())


class Collector:
    def __init__(self, prefix: str, ref_sha: str, technique: str):
        self.prefix, self.ref, self.tech = prefix, ref_sha, technique
        self.rows: List[Dict[str, str]] = []
        self.n = 0

    def add(self, category: str, location: str, hypothesis: str, status: str, confidence: str,
            verification: str, technique: str = "") -> str:
        self.n += 1
        eid = f"{self.prefix}-{self.n:04d}"
        self.rows.append({
            "evidence_id": eid, "category": category, "location": location,
            "technique": technique or self.tech, "ref_sha256": self.ref, "hypothesis": hypothesis,
            "status": status, "confidence": confidence, "verification": verification,
            "timestamp": wslib.now_iso(),
        })
        return eid
