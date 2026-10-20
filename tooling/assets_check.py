"""make assets-check — audita assets do projeto Godot: só conteúdo próprio/gerado ou com licença declarada."""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

ALLOWED = {
    "game/icon.svg": "próprio (desenhado em SVG para o projeto)",
    "game/data/levels/lab1.json": "próprio (gerado por tooling/gen_demo_level.py)",
    "game/data/levels/lab2.json": "próprio (gerado por tooling/gen_demo_level.py)",
}
BINARY_EXT = {".png", ".jpg", ".wav", ".ogg", ".mp3", ".ttf", ".otf", ".bin", ".vgm", ".tres", ".res"}


def main():
    issues, inv = [], []
    for p in wslib.iter_files(wslib.safe_path("game")):
        if ".godot" in p.parts:
            continue
        rel = wslib.rel(p)
        if p.suffix in (".gd", ".tscn", ".cfg", ".godot", ".uid") or p.name.endswith(".import"):
            continue
        lic = ALLOWED.get(rel)
        inv.append({"path": rel, "size": p.stat().st_size, "license": lic or "NÃO DECLARADA"})
        if lic is None:
            issues.append(f"asset sem proveniência declarada: {rel}")
        if p.suffix in BINARY_EXT and lic is None:
            issues.append(f"binário não auditado: {rel}")
    wslib.write_json(wslib.safe_path("reports/qa/assets.json"), {"timestamp": wslib.now_iso(), "inventory": inv,
                     "issues": issues, "policy": "docs/security/distribuicao-assets.md"})
    for a in inv:
        print(f"{a['path']}: {a['license']}")
    for i in issues:
        print("FALHA", i)
    print("assets-check:", "OK" if not issues else f"{len(issues)} problema(s)")
    return 0 if not issues else 1


if __name__ == "__main__":
    sys.exit(main())
