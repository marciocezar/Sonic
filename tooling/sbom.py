"""make sbom | license-audit | package-check."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

FORBIDDEN_NAMES = ["sega", "sonic team", "official", "oficial"]


def components():
    lock = wslib.read_lock()
    comps = [
        {"name": "Godot Engine (editor + export templates)", "version": lock["godot.version"], "license": "MIT",
         "source": lock["godot.editor.url"], "hash": "sha512:" + lock["godot.editor.sha512"][:32] + "…", "use": "runtime + build (embutido nos builds)"},
        {"name": "rea-agents (REA)", "version": lock["rea.version"], "license": lock["rea.license"], "source": "npm",
         "hash": lock["rea.integrity"][:40] + "…", "use": "ferramenta de análise local (não distribuída)"},
        {"name": "Ghidra", "version": lock["ghidra.version"], "license": lock["ghidra.license"], "source": lock["ghidra.url"],
         "hash": "sha256:" + lock["ghidra.sha256"], "use": "análise local (não distribuída)"},
        {"name": "Python 3 stdlib", "version": "3.9+", "license": "PSF-2.0", "source": "host", "use": "tooling (não distribuído)"},
    ]
    nm = wslib.safe_path("tooling/rea/node_modules")
    deps = []
    if nm.is_dir():
        for pj in nm.glob("**/package.json"):
            if pj.parent.parent.name not in ("node_modules",) and not pj.parent.parent.name.startswith("@"):
                continue
            try:
                d = json.loads(pj.read_text())
            except Exception:  # noqa: BLE001
                continue
            if "name" in d and "version" in d:
                deps.append({"name": d["name"], "version": d["version"], "license": str(d.get("license", "?"))})
    return comps, deps


def sbom():
    comps, deps = components()
    doc = {"bomFormat": "CycloneDX-like (simplificado)", "specVersion": "1.5", "timestamp": wslib.now_iso(),
           "metadata": {"component": {"name": "sonic-megadrive", "version": "0.1.0"}},
           "components": comps, "tooling_transitive_npm": deps}
    wslib.write_json(wslib.safe_path("reports/qa/sbom.json"), doc)
    print(f"sbom: {len(comps)} componentes diretos, {len(deps)} pacotes npm transitivos (tooling) -> reports/qa/sbom.json")
    return 0


def licenses():
    comps, deps = components()
    bad = [d for d in deps if re.search(r"GPL|AGPL|SSPL", d["license"]) and "LGPL" not in d["license"]]
    for c in comps:
        print(f"{c['name']}: {c['license']} ({c['use']})")
    print(f"npm (tooling, não distribuído): {len(deps)} pacotes; copyleft forte: {len(bad)}")
    for b in bad:
        print("ATENÇÃO", b)
    print("Assets do jogo original: NÃO licenciados para distribuição; ficam em private/ (ver LICENSES.md).")
    wslib.write_json(wslib.safe_path("reports/qa/license-audit.json"), {"timestamp": wslib.now_iso(), "direct": comps,
                     "copyleft_tooling": bad})
    return 0


def package():
    cfg = wslib.safe_path("game/export_presets.cfg").read_text()
    proj = wslib.safe_path("game/project.godot").read_text()
    issues = []
    ids = set(re.findall(r'(?:bundle_identifier|unique_name)="([^"]+)"', cfg))
    if ids != {"org.local.research.soniclike"}:
        issues.append(f"IDs de pacote inesperados: {ids}")
    names = re.findall(r'(?:name|product_name|package/name)="([^"]+)"', cfg) + re.findall(r'config/name="([^"]+)"', proj)
    for n in names:
        if any(f in n.lower() for f in FORBIDDEN_NAMES):
            issues.append(f"nome sugere afiliação oficial: {n}")
    if "Sem afiliação" not in proj and "sem afiliação" not in proj.lower():
        issues.append("aviso de não afiliação ausente em project.godot")
    for i in issues:
        print("FALHA", i)
    print("package-check:", "OK" if not issues else f"{len(issues)} problema(s)", "| IDs:", ", ".join(sorted(ids)))
    return 0 if not issues else 1


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "sbom"
    sys.exit({"sbom": sbom, "licenses": licenses, "package": package}[cmd]())
