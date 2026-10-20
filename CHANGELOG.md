# Changelog

## 0.3.0 — 2026-10-18
- Importador de fases em execução a partir da ROM do próprio usuário (REV00 por SHA-256; `user://rom/rom.bin`),
  em todas as plataformas ("CARREGAR ROM"; Web via `<input type=file>`). 19 atos jogáveis em sequência original.
- Atos de chefe avançam ao fim da área (provisório, mensagem na tela); estágio especial conta como fim de ato.
- Web: abre por `file://` (`index.embed.js`); `web.config` e `staticwebapp.config.json` para Azure.
- Web: seletor de ROM em painel HTML (corrige Safari, que bloqueava `input.click()` fora de gesto).
- Novos alvos: `make rom-import-check`, `make test-progression`, `make package-web-azure`, `make web-azure-check URL=`.

## 0.2.0 — 2026-10-18 (mesma sessão)
- Objetos de Green Hill reconstruídos a partir da listagem (Motobug, Crabmeat, Buzz Bomber, Chopper, Newtron, molas,
  espinhos, ponte, pedra, plataformas, balanços, paredes, tronco, placa, bônus, anel gigante, explosão/animal/pontos).
- Carga de objetos por câmera exata (ROM 0xD8F0), slots com exclusão imediata, inicialização no laço de slots.
- Osciladores e animação sincronizada; detecção exata do laço ocioso; "pokes" em replays; bot de replays.
- Paridade: 9 replays IDÊNTICOS (GHZ1 inteiro, GHZ2/GHZ3 parciais) + 2 de fronteira.

## 0.1.0 — 2026-10-18
- Auditoria do workspace; bootstrap local (Godot 4.7.2 + templates, REA 6.7.0, Ghidra 12.1.4 com natives arm64) com hashes verificados.
- Prova de formato da ROM (REV00, checksum 0x264A OK) e ledger de evidências.
- Interpretador 68000 + máquina Mega Drive mínima próprios; boot, título, carga das 19 fases, traces por quadro.
- Extração privada das 19 fases com validação 100% da tabela de nomes do VDP.
- Simulação determinística em GDScript: física, sensores, câmera, eventos de limites GHZ, anéis, monitor.
- Paridade: 5/5 replays GHZ1 idênticos com tolerância zero.
- App: título, opções, pausa, HUD, cartão de título, fim de ato, game over, toque multitoque, remapeamento.
- Perfis Fidelity/Enhanced com a mesma simulação; fase própria publicável Lab Zone.
- Exportações macOS/Windows/Web/Android(APK debug)/iOS(projeto Xcode) + verificação estrutural.
