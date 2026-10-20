# STATUS — sonic-megadrive (auditável)

Atualizado: 2026-10-18. Fonte única: `Sonic The Hedgehog (USA, Europe).md` (REV00, SHA-256 `46160baa…f2a6`).
Detalhes gerados: `docs/qa/build-matrix.md`, `docs/qa/matriz-mecanicas.md`, `reports/parity/summary.md`,
`reports/analysis/reverse-report.md`.

## Resumo honesto
- **Não** é uma reconstrução integral. A ROM **não** foi totalmente descompilada. Publicação **não** autorizada.
- Verificado com tolerância zero contra a referência medida (9 replays IDÊNTICOS, ~9 300 quadros): física do
  personagem, câmera, tempo, pontuação, anéis, dano/perda de anéis, morte e reinício, carga de objetos por câmera,
  osciladores, e os objetos de Green Hill: Motobug, Crabmeat, Buzz Bomber(+míssil), Chopper, Newtron, molas,
  espinhos (bug REV00), ponte, pedra, plataformas, balanços, paredes de borda/quebráveis, tronco giratório, placa,
  bônus escondido, explosão→animal→pontos. **GHZ1 inteiro (3241 quadros) idêntico até o anel gigante**; GHZ2 e GHZ3
  idênticos nos trechos percorridos pelo bot (ocupação de slots idêntica).
- Fronteira documentada (replays DIVERGE_FRONTEIRA): chefe de GHZ e objetos de Marble Zone.
- Extraídas (privado) e validadas as geometrias das 19 fases. Objetos: 19 tipos da lista implementados de 79 presentes (+5 auxiliares gerados em execução)
  (≈48% das instâncias, ver `docs/qa/matriz-mecanicas.md`).
- **Builds privados** (`make build-private-<alvo>`, `dist-private/`): conteúdo do jogo embutido, perfil Fidelity padrão, 19 atos em
  sequência com arte, sprites e fundos originais lidos da ROM (macOS privado: progressão PASS; Web privado: abre GHZ com visual original).
  Builds públicos (`dist/`) só com LAB ZONE; opção "carregar ROM" removida.
  Chefes/estágios especiais ainda provisórios (ato de chefe avança ao fim da área).
- App jogável (título, opções, pausa, HUD, toque, remapeamento, Fidelity/Enhanced) e exportado para os 5 destinos.

## Atualização 2026-10-18 (lote telas/sprites)
- GHZ: 11 replays IDÊNTICOS incluindo quadro de sprite do Sonic (`frm`), fundo e ocupação de slots; plataforma que
  desmorona e poste reconstruídos; sprites de todos os objetos de GHZ conferidos (`make sprite-check`).
- Telas originais a partir da ROM: placar, cartão de título, resultados do ato. Faltam SEGA, título, menus, game over,
  continue, estágio especial, final, créditos e som.

## Plataformas
| Destino | Build | Teste |
|---|---|---|
| macOS | OK | **PASS** (host) |
| Windows | OK | não testado (sem Windows) |
| Web desktop | OK (+ web.config/staticwebapp; `make package-web-azure`) | **PASS** (navegador real); Azure: não verificado por nós |
| Web iPhone / Android | OK (estrutural) | não testado (sem aparelho) |
| Android APK debug | OK | não testado (emulador suspenso por decisão do usuário) |
| Android AAB | BLOCKED (Gradle + keystore release) | — |
| iOS projeto Xcode | OK; compila para Simulator x86_64 | Simulator iOS 27 rejeita x86_64 → BLOCKED |
| iOS IPA | BLOCKED (Team ID/provisioning) | — |

## Alvos Make executados nesta sessão (exit code)
bootstrap 0 · rom-analyze 0 · rea-check 0 · ghidra-analyze 0 · rea-analyze 0 · extract-data 0 · reference-traces 0 ·
test-parity 0 (9 IDENTICO + 2 DIVERGE_FRONTEIRA) · test-unit 0 · test-touch 0 · bench 0 · lint 0 · format-check 0 · security-check 0 ·
check-no-rom-in-dist 0 · rom-import-check 0 · test-progression 0 · package-web-azure 0 · assets-check 0 · sbom 0 · license-audit 0 · package-check 0 · build-macos 0 · build-windows 0 ·
build-web 0 · build-android 0 (ANDROID_HOME informado) · build-ios 0 · ios-xcode 0 · test-macos 0 · test-web 0 ·
web-mobile-check 0 · verify-artifacts 0 · test-ios 2 (BLOCKED) · qa-matrix 0 · reverse-report 0 · doctor 0.

## Evidências
Ledger: `docs/reverse-engineering/04-evidence-ledger.csv` (ROM, tabelas, RAM, fases, ferramentas). REA: BLOQUEADO (ver ADR 0002).

## Bloqueios que exigem o usuário
1. Autorizar (ou não) REA fora do sandbox. 2. Aparelhos/emuladores para Android/iOS/Web móvel e máquina Windows.
3. Apple Team ID + provisioning (IPA); keystore de release + template Gradle (AAB). 4. Revisão jurídica da política de assets.

## Próximos passos priorizados
1. Chefe de GHZ (0x3D/0x48/0x3F; precisa de bot que acerte o chefe), cápsula 0x3E, poste 0x79, desmoronável 0x1A.
2. Marble Zone (0x2F com mapas de altura em pacote privado, 0x46, 0x31, 0x33, 0x52, 0x54, 0x55, 0x78...), depois
   SYZ, LZ (água dinâmica), SLZ, SBZ e eventos dinâmicos de cada zona.
3. Sprites/animações Fidelity a partir de mapeamentos (privado); deformação de fundo.
4. Estágios especiais e final. 5. Testes em aparelhos reais.

## Pendente do usuário (Web)
- Safari real: seletor de ROM em painel HTML (validado só no Chromium). Azure: publicar `dist/web-azure.zip` e rodar
  `make web-azure-check URL=...`.
