"""make docs — valida presença da documentação obrigatória e links relativos em Markdown."""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

REQUIRED = [
    "README.md", "CHANGELOG.md", "LICENSES.md", ".env.example", "CLAUDE.md", "tooling/versions.lock", "docs/STATUS.md",
    "docs/reverse-engineering/01-formato-origem.md", "docs/reverse-engineering/02-metodologia-rea.md",
    "docs/reverse-engineering/03-mapa-funcoes-dados.md", "docs/reverse-engineering/04-evidence-ledger.csv",
    "docs/reverse-engineering/05-paridade.md", "docs/reverse-engineering/06-riscos-e-lacunas.md",
    "docs/gameplay/regras.md", "docs/gameplay/controles.md", "docs/gameplay/progressao.md", "docs/gameplay/objetos.md",
    "docs/gameplay/fisica-e-colisao.md", "docs/gameplay/camera.md", "docs/gameplay/hud-e-estados.md",
    "docs/architecture/c4.md", "docs/architecture/fluxos.md", "docs/architecture/simulacao.md", "docs/architecture/schemas.md",
    "docs/adr/0001-engine-godot-gdscript.md", "docs/adr/0002-rea-e-provedores.md", "docs/adr/0003-formato-recursos.md",
    "docs/adr/0004-renderer-web-mobile.md", "docs/adr/0005-controles-toque.md", "docs/adr/0006-licenciamento-assets.md",
    "docs/adr/0007-seguranca-isolamento.md", "docs/adr/0008-emulador-proprio.md",
    "docs/platforms/macos.md", "docs/platforms/windows.md", "docs/platforms/web-desktop.md", "docs/platforms/web-iphone.md",
    "docs/platforms/web-android.md", "docs/platforms/android.md", "docs/platforms/ios.md",
    "docs/qa/build-matrix.md", "docs/qa/matriz-mecanicas.md", "docs/qa/criterios-paridade.md", "docs/qa/cobertura.md",
    "docs/qa/benchmark.md", "docs/qa/bugs.md",
    "docs/security/riscos.md", "docs/security/isolamento.md", "docs/security/terceiros.md", "docs/security/sbom.md",
    "docs/security/segredos.md", "docs/security/distribuicao-assets.md",
    "docs/operations/makefile.md", "docs/operations/agentes.md", "docs/operations/onboarding.md",
    "docs/operations/instalacao-segura.md", "docs/operations/reproducao.md", "docs/operations/release.md",
    "docs/operations/checklist.md", "docs/operations/manutencao.md", "docs/operations/CONTINUE-CLAUDE.md",
]


def main():
    bad = 0
    for r in REQUIRED:
        p = wslib.safe_path(r)
        if not p.is_file() or p.stat().st_size < 40:
            print("FALTA", r)
            bad += 1
    for md in list(wslib.safe_path("docs").rglob("*.md")) + [wslib.safe_path("README.md")]:
        for target in re.findall(r"\]\(([^)#:\s]+)\)", md.read_text(encoding="utf-8")):
            if not (md.parent / target).exists():
                print(f"LINK quebrado em {wslib.rel(md)}: {target}")
                bad += 1
    print(f"docs: {len(REQUIRED)} obrigatórios verificados; problemas={bad}")
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
