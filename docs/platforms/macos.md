# macOS
- Requisitos: macOS 11+ (arm64/x86_64 universal), `make bootstrap` (Godot + templates locais).
- Alvos: `make run`, `make build-macos` → `dist/macos/MegadrivePlatformerLab.zip` (.app universal, assinatura ad-hoc),
  `make test-macos` (extrai o .app em `work/`, executa replay de fumaça e captura tela em `reports/qa/macos-smoke.png`).
- Estado: **PASS** no host de desenvolvimento (macOS 27.0.1 arm64) — ver `docs/qa/build-matrix.md`.
- Distribuição pública exige Developer ID + notarização (não feitas). Gatekeeper pode bloquear zips baixados (quarentena).
- Troubleshooting: "template não encontrado" → `make bootstrap COMPONENTS=templates`; erro ETC2/ASTC → já habilitado em project.godot.
