"""make qa-matrix — gera docs/qa/build-matrix.md, docs/qa/matriz-mecanicas.md e cobertura de objetos."""
from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

ROWS = [("macOS (.app/.zip)", "macos"), ("Windows (.exe+.pck)", "windows"), ("Web desktop", "web"),
        ("  └ Web desktop (navegador real)", "web-desktop"), ("  └ Web iPhone (Safari iOS)", "web-ios-safari"),
        ("  └ Web Android (Chrome)", "web-android-chrome"), ("Android app (APK debug)", "android"),
        ("Android AAB (release)", "android-aab"), ("iOS (projeto Xcode)", "ios"), ("  └ iOS Simulator", "ios-simulator"),
        ("  └ iOS IPA assinado", "ios-ipa")]


def object_coverage():
    cat = wslib.safe_path("game/src/entities/objects/object_catalog.gd").read_text()
    impl = {int(m, 16) for m in re.findall(r"^\s+0x([0-9A-Fa-f]+):", cat, re.M)}
    counts = Counter()
    packs = wslib.safe_path("private/extracted/levelpacks")
    cache = wslib.safe_path("reports/analysis/object-ids.json")
    if packs.is_dir():
        per = {}
        for d in sorted(packs.iterdir()):
            f = d / "level.json"
            if f.is_file():
                ids = Counter(o["id"] & 0x7F for o in json.loads(f.read_text())["objects"])
                per[d.name] = {f"0x{k:02X}": v for k, v in sorted(ids.items())}
                counts.update(ids)
        wslib.write_json(cache, {"timestamp": wslib.now_iso(), "per_level": per,
                                 "note": "contagens de IDs de objeto por fase (metadado; sem dados protegidos)"})
    elif cache.is_file():
        for lv in json.loads(cache.read_text())["per_level"].values():
            counts.update({int(k, 16): v for k, v in lv.items()})
    return impl, counts


def main():
    st = {}
    p = wslib.safe_path("reports/build/status.json")
    if p.is_file():
        st = json.loads(p.read_text())
    lines = ["# Matriz de builds e testes (gerada por `make qa-matrix`)", "",
             f"Atualizada: {wslib.now_iso()}. Status: NOT_STARTED, BUILT_NOT_TESTED, PASS, FAIL, BLOCKED. "
             "PASS só com execução real registrada.", "",
             "| Destino | Status | Quando | Comando | Artefatos (SHA-256) | Notas |", "|---|---|---|---|---|---|"]
    for label, key in ROWS:
        r = st.get(key, {})
        arts = "<br>".join(f"`{a['path']}` {a['size']:,} B `{a['sha256'][:16]}…`" for a in r.get("artifacts", [])[:3])
        lines.append(f"| {label} | **{r.get('status', 'NOT_STARTED')}** | {r.get('timestamp', '-')} | "
                     f"`{r.get('command', '-')}` | {arts or '-'} | {r.get('notes', '').replace('|', '/')} |")
    wslib.write_text(wslib.safe_path("docs/qa/build-matrix.md"), "\n".join(lines) + "\n")
    mech = json.loads(wslib.safe_path("tooling/mechanics.json").read_text())["items"]
    impl, counts = object_coverage()
    c = Counter(i["status"] for i in mech)
    ml = ["# Matriz de mecânicas, fases e objetos (gerada por `make qa-matrix`)", "",
          f"Atualizada: {wslib.now_iso()}. Resumo: " + ", ".join(f"{k}={v}" for k, v in sorted(c.items())), "",
          "> Código que compila não é jogo completo. VERIFIED exige replay idêntico à referência medida.", "",
          "| Área | Mecânica | Status | Evidência |", "|---|---|---|---|"]
    for i in mech:
        ml.append(f"| {i['area']} | {i['name']} | **{i['status']}** | {i['evidence']} |")
    total = sum(counts.values())
    done = sum(v for k, v in counts.items() if k in impl)
    ml += ["", "## Cobertura de tipos de objeto das fases originais", "",
           f"Instâncias cobertas por objetos implementados: {done}/{total} "
           f"({(100 * done / total) if total else 0:.1f}%). Tipos implementados: {len(impl & set(counts))}/{len(counts)}.", "",
           "| ID | Instâncias nas 19 fases | Implementado |", "|---|---|---|"]
    for k, v in sorted(counts.items()):
        ml.append(f"| 0x{k:02X} | {v} | {'sim' if k in impl else 'não'} |")
    wslib.write_text(wslib.safe_path("docs/qa/matriz-mecanicas.md"), "\n".join(ml) + "\n")
    print(f"qa-matrix: {len(ROWS)} linhas de build; {len(mech)} mecânicas; objetos {done}/{total} instâncias cobertas")
    return 0


if __name__ == "__main__":
    sys.exit(main())
