# Makefile por alvo
Fonte da verdade: `make help`. Todos os alvos chamam `tooling/*.py` com `python3 -I -B`.

| Alvo | O que faz | Saídas |
|---|---|---|
| doctor | pré-requisitos por SO | reports/qa/doctor.json |
| security-check | escopo, .gitignore, links, segredos, permissão do original | reports/qa/security-check.json |
| bootstrap | instala Godot/templates/REA/Ghidra(+natives) em tooling/; protege o original (`COMPONENTS=`) | reports/build/bootstrap.json |
| rea-check | REA local + doctor do provider (em sandbox) | reports/analysis/rea-check.json |
| rom-analyze | formato/integridade/tabelas | reports/analysis/rom-integrity.json, ledger |
| ghidra-analyze | Ghidra headless (sandbox) semeado com cobertura | private/extracted/ghidra, reports/analysis/ghidra-summary.json |
| rea-analyze | rom-analyze + tentativas REA + Ghidra | reports/analysis/rea-analyze.json |
| extract-data | fases via interpretador (privado) + validação VDP | private/extracted, reports/analysis/extract-summary.json |
| reference-traces | traces por quadro dos replays (`REPLAY=`) | private/reference-captures, reports/parity/reference-index.json |
| demo-level | fases próprias Lab Zone e Lab Zone 2 | game/data/levels/lab1.json, lab2.json |
| reverse-report | compila evidências | reports/analysis/reverse-report.md |
| assets-check | inventário/proveniência de assets | reports/qa/assets.json |
| test / test-unit / test-parity / test-touch | testes | reports/qa, reports/parity |
| bench | custo por tick | stdout / reports/qa |
| lint / format-check | Python + GDScript | stdout |
| run / run-fidelity / run-enhanced | jogo nativo (`PROFILE=`; `RUN_ARGS=` extra) | — |
| build-macos/windows/web/android/ios | exportações | dist/*, reports/build/status.json |
| build-android-aab | AAB release (bloqueado sem Gradle/keystore) | — |
| web-serve / web-mobile-check / test-web | Web | reports/qa |
| android-install / test-android | requer aparelho (`DEVICE=`) | reports/qa |
| ios-xcode / ios-archive / test-ios | Xcode/Simulator/IPA | reports/build |
| test-macos | executa .app exportado | reports/qa/macos-smoke.png |
| build-supported / build-all | agregados (build-all falha se faltar destino) | reports/build |
| verify-artifacts | estrutura/magic/hash | reports/build/artifacts.json |
| check-no-rom-in-dist | conteúdo privado em dist/game | reports/qa/check-no-rom-in-dist.json |
| qa-record | registra teste real (`TARGET= STATUS= NOTES=`) | reports/build/status.json |
| qa-matrix | matrizes de build e mecânicas | docs/qa/*.md |
| docs | valida documentação obrigatória/links | stdout |
| sbom / license-audit / package-check | conformidade | reports/qa |
| clean | limpa work/ e dist/ (preserva downloads/keys) | — |
