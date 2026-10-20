"""make clean — remove SOMENTE temporários conhecidos em work/ e dist/ (caminho canônico verificado).
Nunca remove a ROM, private/, docs, reports ou ferramentas baixadas."""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

KEEP_IN_WORK = {"downloads", "keys", "rea-home"}  # downloads verificados e keystore de debug são caros/recriáveis
TARGETS = ["work", "dist"]


def main():
    rom = wslib.find_rom()
    removed = 0
    for t in TARGETS:
        base = wslib.safe_path(t)
        if not base.is_dir():
            continue
        for child in base.iterdir():
            if t == "work" and child.name in KEEP_IN_WORK:
                continue
            real = wslib.safe_path(child)
            if rom is not None and real == rom:
                continue
            if real.is_symlink() or real.is_file():
                real.unlink()
            else:
                shutil.rmtree(real)
            removed += 1
    for d in ("macos", "windows", "web", "android", "ios"):
        wslib.ensure_dir("dist", d)
    print(f"clean: {removed} item(ns) removido(s) de work/ e dist/ (preservados: {', '.join(sorted(KEEP_IN_WORK))})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
