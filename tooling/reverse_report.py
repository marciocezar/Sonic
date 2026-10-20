"""make reverse-report — compila evidências reais em reports/analysis/reverse-report.md (sem bytes da ROM)."""
from __future__ import annotations

import csv
import json
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import evidence  # noqa: E402
import wslib  # noqa: E402


def j(path):
    p = wslib.safe_path(path)
    return json.loads(p.read_text()) if p.is_file() else {}


def main():
    rows = evidence.load()
    integ = j("reports/analysis/rom-integrity.json")
    gh = j("reports/analysis/ghidra-summary.json")
    ex = j("reports/analysis/extract-summary.json")
    par = j("reports/parity/summary.json")
    rea = j("reports/analysis/rea-check.json")
    st = Counter(r["status"] for r in rows)
    out = ["# Relatório de engenharia reversa (gerado por `make reverse-report`)", "",
           f"Gerado em {wslib.now_iso()}. Fonte única: `{wslib.ROM_NAME}`.", "",
           "## Integridade", "",
           f"- Tamanho: {integ.get('size_bytes')} bytes; SHA-256 `{integ.get('sha256')}`",
           f"- Serial/revisão: {integ.get('header', {}).get('serial_revision')}; região declarada {integ.get('header', {}).get('region')}",
           f"- Checksum interno: {integ.get('header', {}).get('checksum_header')} (calculado {integ.get('checksum_calculated')}, confere={integ.get('checksum_match')})",
           f"- Formato: {integ.get('format_detection', {}).get('format')}", "",
           "## Ferramentas", "",
           f"- REA 6.7.0: `inspect-artifact` rejeita ROM bruta; `analyze --target-format raw-binary --architecture m68k` **BLOQUEADO** "
           f"(provider Ghidra sob sandbox: java spawn EPERM; usuário negou execução fora do sandbox). Doctor: "
           f"{', '.join(k for k, v in rea.get('doctor', {}).items() if not v.get('ok')) or 'n/d'} com falha.",
           f"- Ghidra 12.1.4 headless em sandbox, semeado com cobertura dinâmica: {gh.get('functions')} funções, {gh.get('instructions')} instruções (sem descompilação validada).",
           "- Interpretador 68000 próprio (`tooling/m68k.py`/`mdmachine.py`): boot, título, carga das 19 fases, replays por quadro.", "",
           "## Fases extraídas (privado)", "", "| Fase | Início | Limites | Objetos | Plano A |", "|---|---|---|---|---|"]
    for lv in ex.get("levels", []):
        if lv.get("loaded"):
            out.append(f"| {lv['id']} | {lv['start']} | {lv['limits']} | {lv['objects']} | {lv.get('nametable_match', '-')} |")
    out += ["", "## Paridade", ""]
    for r in par.get("results", []):
        out.append(f"- {r['replay']}: **{r['status']}** ({r.get('frames_compared', '-')} quadros; 1ª divergência {r.get('first_divergence_frame')})")
    out += ["", "## Ledger", "", "Contagem por status: " + ", ".join(f"{k}={v}" for k, v in sorted(st.items())), "",
            "| ID | Categoria | Local | Hipótese | Status |", "|---|---|---|---|---|"]
    for r in rows:
        out.append(f"| {r['evidence_id']} | {r['category']} | {r['location']} | {r['hypothesis'][:140].replace('|', '/')} | {r['status']} |")
    out += ["", "## O que NÃO foi feito", "",
            "- A ROM **não** foi descompilada integralmente; não há afirmação de equivalência total.",
            "- Z80/áudio, deformação de fundo por linha, HBlank e a maioria dos objetos/chefes ainda não foram reconstruídos.",
            "- Temporização do interpretador é aproximada (quadros com lag podem divergir do hardware)."]
    wslib.write_text(wslib.safe_path("reports/analysis/reverse-report.md"), "\n".join(out) + "\n")
    print(f"reverse-report: {len(rows)} evidências; relatório em reports/analysis/reverse-report.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
